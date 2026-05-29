function parseCookies(header = '') {
  return header.split(';').reduce((acc, entry) => {
    const [name, ...rest] = entry.trim().split('=');
    if (!name) return acc;
    acc[name] = decodeURIComponent(rest.join('='));
    return acc;
  }, {});
}

function serializeCookie(name, value, options = {}) {
  const parts = [`${name}=${encodeURIComponent(value)}`];
  if (options.maxAge !== undefined) parts.push(`Max-Age=${Math.floor(options.maxAge)}`);
  if (options.domain) parts.push(`Domain=${options.domain}`);
  if (options.path) parts.push(`Path=${options.path}`);
  if (options.expires) parts.push(`Expires=${options.expires.toUTCString()}`);
  if (options.httpOnly) parts.push('HttpOnly');
  if (options.secure) parts.push('Secure');
  if (options.sameSite) parts.push(`SameSite=${options.sameSite}`);
  return parts.join('; ');
}

function cookieOptions({ maxAgeDays, httpOnly = false, sameSite = 'Lax', secure = false, domain }) {
  const options = { path: '/', sameSite, secure, domain };
  if (httpOnly) options.httpOnly = true;
  if (maxAgeDays) options.maxAge = maxAgeDays * 24 * 60 * 60;
  return options;
}

module.exports = { parseCookies, serializeCookie, cookieOptions };