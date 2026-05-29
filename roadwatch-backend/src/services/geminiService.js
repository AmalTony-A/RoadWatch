const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const AiUsage = require('../models/AiUsage');
const AppError = require('../utils/AppError');

const GEMINI_MODEL = 'gemini-2.5-flash';
const GEMINI_FALLBACK_MODELS = ['gemini-2.5-flash-lite', 'gemini-3.1-flash-lite'];
const IMAGE_LIMIT = 10;
const CHAT_LIMIT = 20;
const WINDOW_MS = 60 * 60 * 1000;
const CACHE_TTL_MS = 12 * 60 * 60 * 1000;
const RETRY_DELAY_MS = 2000;
const REQUEST_COOLDOWN_MS = 2500;
const REQUEST_TIMEOUT_MS = 20000;
const activeRequests = new Map();
const lastRequestAt = new Map();

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function normalizeText(value) {
  return `${value || ''}`.trim().replace(/\s+/g, ' ').toLowerCase();
}

function ownerKeyFromRequest(req) {
  const userId = req.user?._id?.toString?.();
  if (userId) {
    return `user:${userId}`;
  }
  return `ip:${req.ip || req.connection?.remoteAddress || 'unknown'}`;
}

function stripJson(text) {
  const raw = `${text || ''}`.trim();
  if (!raw) {
    return raw;
  }

  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced && fenced[1]) {
    return fenced[1].trim();
  }

  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start >= 0 && end > start) {
    return raw.slice(start, end + 1);
  }

  return raw;
}

function parseJsonResponse(text) {
  const cleaned = stripJson(text);
  return JSON.parse(cleaned);
}

function temporaryAiError() {
  const error = new AppError('AI service temporarily busy', 503);
  error.temporary = true;
  return error;
}

function geminiError(message, statusCode, temporary = false) {
  const error = temporary ? temporaryAiError() : new AppError(message, statusCode);
  error.geminiStatusCode = statusCode;
  return error;
}

function isTemporaryGeminiFailure(error) {
  const status = Number(error.statusCode || error.status || error.code || 0);
  const text = `${error.message || error}`.toLowerCase();
  return status === 429
    || status === 503
    || status === 504
    || text.includes('429')
    || text.includes('too many requests')
    || text.includes('quota')
    || text.includes('overload')
    || text.includes('unavailable')
    || text.includes('timeout')
    || text.includes('aborted');
}

async function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function runSingleFlight(key, factory) {
  if (activeRequests.has(key)) {
    return activeRequests.get(key);
  }

  const lastAt = lastRequestAt.get(key) || 0;
  const waitMs = REQUEST_COOLDOWN_MS - (Date.now() - lastAt);
  const promise = (async () => {
    if (waitMs > 0) {
      await delay(waitMs);
    }
    lastRequestAt.set(key, Date.now());
    return factory();
  })().finally(() => {
    activeRequests.delete(key);
  });

  activeRequests.set(key, promise);
  return promise;
}

function readImageBytes(file) {
  if (!file) {
    throw new AppError('Image file is required', 400);
  }

  if (file.buffer) {
    return file.buffer;
  }

  if (file.path && fs.existsSync(file.path)) {
    return fs.readFileSync(file.path);
  }

  throw new AppError('Uploaded image could not be read', 400);
}

function imageMimeType(file) {
  if (file.mimetype) {
    return file.mimetype;
  }
  const ext = path.extname(file.originalname || '').toLowerCase();
  if (ext === '.png') return 'image/png';
  if (ext === '.webp') return 'image/webp';
  return 'image/jpeg';
}

async function enforceQuota({ category, ownerKey, cacheKey, responseFactory, limit }) {
  const existing = await AiUsage.findOne({ cacheKey }).lean();
  if (existing && existing.expiresAt && new Date(existing.expiresAt).getTime() > Date.now()) {
    // Validate cached chat responses — discard stale fallback answers
    if (category === 'chat') {
      const cachedAnswer = `${existing.response?.answer || ''}`.trim();
      const isStale = !cachedAnswer
        || cachedAnswer.includes("I'm designed to assist")
        || cachedAnswer.includes('I can only assist')
        || cachedAnswer.includes('I cannot provide')
        || cachedAnswer.length < 5;
      if (!isStale) {
        return { response: existing.response, cached: true };
      }
      // Stale cached response — invalidate and regenerate
      console.log('[RoadWatch] Discarding stale cached chat response, regenerating...');
    } else {
      return { response: existing.response, cached: true };
    }
  }

  const windowStart = new Date(Date.now() - WINDOW_MS);
  const used = await AiUsage.countDocuments({ category, ownerKey, createdAt: { $gte: windowStart } });
  if (used >= limit) {
    throw temporaryAiError();
  }

  const response = await responseFactory();
  await AiUsage.findOneAndUpdate(
    { cacheKey },
    {
      category,
      ownerKey,
      cacheKey,
      response,
      expiresAt: new Date(Date.now() + CACHE_TTL_MS),
    },
    { upsert: true, new: true, setDefaultsOnInsert: true },
  );

  return { response, cached: false };
}

async function callGeminiOnce({ apiKey, model, systemInstruction, prompt, imageBytes, mimeType }) {
  if (!apiKey) {
    throw new AppError('GEMINI_API_KEY is required for AI features', 500);
  }

  const body = {
    systemInstruction: {
      parts: [{ text: systemInstruction }],
    },
    contents: [
      {
        role: 'user',
        parts: imageBytes
          ? [
              { text: prompt },
              {
                inlineData: {
                  mimeType,
                  data: imageBytes.toString('base64'),
                },
              },
            ]
          : [{ text: prompt }],
      },
    ],
    generationConfig: {
      temperature: 0.2,
      topP: 0.95,
      maxOutputTokens: 512,
      responseMimeType: 'application/json',
    },
  };

  let response;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
    response = await fetch(`${endpoint}?key=${encodeURIComponent(apiKey)}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (error) {
    if (isTemporaryGeminiFailure(error)) {
      await delay(RETRY_DELAY_MS);
      throw temporaryAiError();
    }
    throw geminiError('AI analysis failed', 502);
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    const errorText = await response.text();
    console.error('Gemini request failed:', {
      status: response.status,
      model,
      reason: errorText.includes('"message"') ? errorText.match(/"message":\s*"([^"]+)"/)?.[1] : 'Gemini request failed',
    });
    if ([429, 503, 504].includes(response.status)) {
      await delay(RETRY_DELAY_MS);
      throw geminiError('AI service temporarily busy', response.status, true);
    }
    throw geminiError('AI analysis failed', response.status === 404 ? 502 : response.status);
  }

  const payload = await response.json();
  const text = payload?.candidates?.[0]?.content?.parts?.map((part) => part.text || '').join('') || '';
  if (!text) {
    console.error('Gemini returned empty payload:', JSON.stringify(payload).slice(0, 500));
    throw geminiError('Gemini returned an empty response', 502);
  }

  try {
    return { ...parseJsonResponse(text), __model: model };
  } catch (error) {
    console.error('Gemini JSON parse failed:', {
      model,
      text: text.slice(0, 500),
      error: error.message,
    });
    throw geminiError('AI response could not be parsed', 502);
  }
}

async function callGemini(args) {
  const models = [GEMINI_MODEL, ...GEMINI_FALLBACK_MODELS];
  let lastError = null;

  for (const model of models) {
    try {
      return await callGeminiOnce({ ...args, model });
    } catch (error) {
      lastError = error;
      const status = Number(error.geminiStatusCode || error.statusCode || 0);
      if (![429, 503, 504, 502].includes(status)) {
        throw error;
      }
      console.warn('Gemini model failed, trying next model:', {
        model,
        status,
        temporary: Boolean(error.temporary),
      });
    }
  }

  throw lastError || temporaryAiError();
}

function buildDamagePrompt() {
  return [
    'Analyze this road image.',
    'Determine:',
    '1. Is road damage present?',
    '2. Damage type: pothole, road crack, waterlogging, damaged road',
    '3. Confidence score',
    '4. Short explanation',
    'Return JSON only with keys: detected (boolean), damageType (string or null), confidence (number 0-100), message (string), explanation (string).',
    'If the image is normal or uncertain, return detected false and damageType null.',
    'Do not guess. Prefer false negatives over false positives.',
  ].join(' ');
}

function buildChatPrompt({ query, history, roadContext }) {
  const lastMessages = (history || []).slice(-10).map((item) => `${item.role}: ${item.content}`).join('\n');
  return [
    'You are RoadWatch Assistant, a smart civic road intelligence assistant for public infrastructure and local governance.',
    'Help with road conditions, potholes, maintenance reasoning, contractors, project oversight, budgets, complaints, civic infrastructure, route guidance, and practical public-safety context.',
    'Answer analytically, contextually, and with practical suggestions when possible.',
    'Do not use canned refusal phrases such as "I can only assist...", "I cannot provide...", or "I cannot help with..." for civic topics.',
    'Only refuse or redirect requests involving illegal content, abuse, harmful instructions, or unsafe wrongdoing.',
    'Use the conversation history for context and keep the answer concise but useful.',
    'Return JSON only with keys: answer (string), allowed (boolean), topic (string), historySummary (string).',
    `Road context: ${roadContext || 'none'}`,
    `Conversation history:\n${lastMessages || 'none'}`,
    `User query: ${query}`,
  ].join('\n');
}

function isSafetyRestrictedQuery(query) {
  const normalized = normalizeText(query);
  return /(illegal|crime|weapon|explosive|harm|hurt|abuse|harass|attack|bypass|steal|fraud|fake document|forg[e|ery]|malware|virus|phishing|suicide|self[- ]harm|kill|poison|drugs?|hack|payload|exploit|password theft|money laundering)/.test(normalized);
}

function deriveCivicTopic(query, roadContext) {
  const normalized = normalizeText(query);
  if (/(complaint|report|file|ticket|grievance|escalat(e|ion)|who handles|how to file)/.test(normalized)) {
    return 'complaint';
  }
  if (/(budget|allocated|allocation|spent|fund|cost|money)/.test(normalized)) {
    return 'budget';
  }
  if (/(contractor|contractors|vendor|builder|agency)/.test(normalized)) {
    return 'contractor';
  }
  if (/(pothole|crack|waterlog|waterlogging|damage|damaged|repair)/.test(normalized)) {
    return 'road-condition';
  }
  if (/(maintenance|maintain|maintenance reasoning|why.*occur|cause|reason|deterioration|wear|drainage|monsoon|rain)/.test(normalized)) {
    return 'maintenance';
  }
  if (/(who maintains|which department|authority|municipality|panchayat|highways|public works|pwd|corporation)/.test(normalized)) {
    return 'authority';
  }
  if (/(hi|hello|hey|greetings)/.test(normalized)) {
    return 'greeting';
  }
  if (/(route|nearby|traffic|detour|navigation|access|connectivity)/.test(normalized)) {
    return 'route-help';
  }
  if (roadContext && `${roadContext}`.trim()) {
    return 'civic-infrastructure';
  }
  return 'civic-infrastructure';
}

function normalizeDamageResponse(raw, fallbackMessage) {
  const detectedCandidate = Boolean(raw.detected);
  const confidence = Math.max(0, Math.min(100, Number(raw.confidence ?? 0) || 0));
  const damageType = raw.damageType || raw.damage_type ? `${raw.damageType || raw.damage_type}` : null;
  const detected = detectedCandidate && confidence >= 85 && Boolean(damageType);
  const explanation = `${raw.explanation || fallbackMessage || raw.message || ''}`.trim();
  const message = detected ? `${raw.message || 'Road damage detected.'}` : 'No road damage detected';
  const roadHealthScore = Math.max(0, Math.min(100, detected ? 100 - confidence : 100));

  return {
    detected,
    damageType,
    confidence,
    message,
    explanation,
    image_id: raw.image_id || '',
    road_id: raw.road_id || null,
    model: raw.__model || GEMINI_MODEL,
    inference_ms: raw.inference_ms || 0,
    image_width: raw.image_width || 0,
    image_height: raw.image_height || 0,
    detections: [],
    score: {
      road_health_score: roadHealthScore,
      color: detected ? 'red' : 'green',
      severity_breakdown: detected ? { low: confidence < 50 ? 0 : 1, medium: confidence >= 50 && confidence < 80 ? 1 : 0, high: confidence >= 80 ? 1 : 0 } : { low: 0, medium: 0, high: 0 },
    },
    scene_status: detected ? 'issue_detected' : 'no_issue',
    scene_message: message,
    needs_reupload: false,
  };
}

async function analyzeRoadImage({ req, file, roadId, apiKey }) {
  if (!apiKey) {
    console.warn('[RoadWatch] GEMINI_API_KEY not set — returning unconfigured response for image analysis');
    return normalizeDamageResponse(
      { detected: false, confidence: 0, damageType: null, message: 'AI analysis requires GEMINI_API_KEY to be configured.', explanation: 'Please add your Gemini API key to the backend .env file to enable road damage detection.' },
      'AI not configured',
    );
  }

  const ownerKey = ownerKeyFromRequest(req);
  const bytes = readImageBytes(file);
  const cacheKey = sha256(`image:${sha256(bytes)}:${roadId || ''}`);

  const { response } = await runSingleFlight(`image:${cacheKey}`, () => enforceQuota({
    category: 'image',
    ownerKey,
    cacheKey,
    limit: IMAGE_LIMIT,
    responseFactory: async () => {
      const raw = await callGemini({
        apiKey,
        systemInstruction: 'You analyze road damage in images and respond only with valid JSON.',
        prompt: buildDamagePrompt(),
        imageBytes: bytes,
        mimeType: imageMimeType(file),
      });
      return normalizeDamageResponse({ ...raw, image_id: file.filename || file.originalname || '', road_id: roadId || null }, 'Road damage analysis completed.');
    },
  }));

  return response;
}

async function generateRoadChat({ req, query, history, roadContext, apiKey }) {
  const ownerKey = ownerKeyFromRequest(req);
  const normalizedHistory = Array.isArray(history) ? history.slice(-10) : [];
  const cacheKey = sha256(
    `chat:${normalizeText(query)}:${normalizeText(roadContext)}:${sha256(JSON.stringify(normalizedHistory))}`,
  );

  // Graceful fallback when Gemini API key is not configured
  if (!apiKey) {
    console.warn('[RoadWatch] GEMINI_API_KEY not set — returning configuration guidance');
    const topic = deriveCivicTopic(query, roadContext);
    return {
      answer: `I'm RoadWatch Assistant. To enable AI-powered responses, please configure the GEMINI_API_KEY in the backend .env file. Your question about "${query}" is a valid civic topic (${topic}). Once configured, I can provide detailed road intelligence answers.`,
      allowed: true,
      topic,
      history: normalizedHistory,
      historySummary: '',
    };
  }

  const { response } = await runSingleFlight(`chat:${cacheKey}`, () => enforceQuota({
    category: 'chat',
    ownerKey,
    cacheKey,
    limit: CHAT_LIMIT,
    responseFactory: async () => {
      const raw = await callGemini({
        apiKey,
        systemInstruction: 'You are RoadWatch Assistant, a smart civic road intelligence assistant. Answer civic infrastructure questions directly and only refuse illegal, abusive, or harmful requests.',
        prompt: buildChatPrompt({ query, history: normalizedHistory, roadContext }),
      });
      console.log('[RoadWatch][Gemini chat raw]', {
        model: raw.__model || GEMINI_MODEL,
        allowed: raw.allowed,
        topic: raw.topic,
        answer: (raw.answer || '').substring(0, 120),
        historySummary: raw.historySummary,
      });

      const allowed = isSafetyRestrictedQuery(query) ? false : true;
      const answer = `${raw.answer || raw.message || ''}`.trim();
      if (!answer) {
        throw new AppError('Gemini returned an empty chat answer', 502);
      }

      const response = {
        answer,
        allowed,
        topic: `${raw.topic || deriveCivicTopic(query, roadContext)}`,
        history: normalizedHistory,
        historySummary: `${raw.historySummary || ''}`.trim(),
      };

      console.log('[RoadWatch][Gemini chat final]', {
        allowed: response.allowed,
        topic: response.topic,
        answer: response.answer.substring(0, 120),
      });

      return response;
    },
  }));

  return response;
}

module.exports = {
  analyzeRoadImage,
  generateRoadChat,
};
