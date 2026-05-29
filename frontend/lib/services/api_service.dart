import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/budget_record.dart';
import '../models/chat.dart';
import '../models/complaint.dart';
import '../models/contractor.dart';
import '../models/detection.dart';
import '../models/risk_prediction.dart';
import '../models/road_network_item.dart';

class ApiService {
  final http.Client _client;
  static const Duration _apiTimeout = Duration(seconds: 10);
  static const Duration _retryTimeout = Duration(seconds: 5);
  static const Duration _chatTimeout = Duration(seconds: 15);
  static const Duration _aiCooldown = Duration(milliseconds: 2500);
  Future<DetectionResult>? _activeDetectionRequest;
  Future<ChatResponse>? _activeChatRequest;
  DateTime? _lastDetectionAt;
  DateTime? _lastChatAt;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: query);
  }

  void _log(String message, {Object? error}) {
    developer.log(message, name: 'ApiService', error: error);
  }

  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('rw_token');
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  String _normalizeDistrictToken(String value) {
    var normalized = value.trim().toLowerCase();
    normalized = normalized.replaceAll('&', 'and');
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
    normalized = normalized.replaceAll('thiru', 'tiru');
    const alias = {
      'kancheepuram': 'kanchipuram',
      'kanceepuram': 'kanchipuram',
      'thiruvallur': 'tiruvallur',
      'thiruvannamalai': 'tiruvannamalai',
    };
    normalized = alias[normalized] ?? normalized;
    return normalized;
  }

  Future<List<RoadNetworkItem>> _loadBundledRoadNetwork() async {
    try {
      final jsonText = await rootBundle.loadString('assets/complete_road_data.json');
      final data = jsonDecode(jsonText) as List<dynamic>;
      return data
          .map((e) => RoadNetworkItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (e) {
      _log('Bundled road network load failed', error: e);
      return const <RoadNetworkItem>[];
    }
  }

  Future<http.Response> _retryRequest(
    Future<http.Response> Function() request, {
    int maxRetries = 1,
    Duration timeout = _retryTimeout,
  }) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final res = await request().timeout(timeout);
        if (res.statusCode < 500) {
          return res;
        }
        _log('Server error ${res.statusCode}, attempt $attempt');
      } catch (e) {
        _log('Request failed, attempt $attempt', error: e);
      }
      if (attempt < maxRetries) {
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
    throw Exception('Request failed after $maxRetries retries');
  }

  Future<bool> checkHealth() async {
    try {
      final res = await _client.get(_uri('/health')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      _log('Health check failed', error: e);
      return false;
    }
  }

  /// Authenticates user. Returns {token, user} map on success.
  /// Throws Exception with server message on failure.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final loginUri = _uri('/api/auth/login');
    _log('Login request: $loginUri', error: {'email': email});
    final res = await _client
        .post(
          loginUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_apiTimeout);
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) {
      _log('Login successful: ${res.statusCode}');
      return body as Map<String, dynamic>;
    }
    _log('Login failed: ${res.statusCode}', error: body);
    throw Exception((body as Map)['message'] ?? 'Login failed');
  }

  /// Registers a new user. Returns {token, user} map on success.
  /// Throws Exception with server message on failure.
  Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _client
        .post(
          _uri('/api/auth/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'email': email, 'password': password}),
        )
        .timeout(_apiTimeout);
    final body = jsonDecode(res.body);
    if (res.statusCode == 201) {
      return body as Map<String, dynamic>;
    }
    throw Exception((body as Map)['message'] ?? 'Signup failed');
  }

  Future<Map<String, dynamic>> getRoadData() async {
    try {
      final res = await _retryRequest(() => _client.get(_uri('/get-road-data')));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      _log('getRoadData returned status ${res.statusCode}');
    } catch (e) {
      _log('getRoadData failed', error: e);
    }
    return {
      'overview': const <String, dynamic>{},
      'roads': const <dynamic>[],
      'recent_complaints': const <dynamic>[],
      'intelligence': const <String, dynamic>{},
    };
  }

  Future<List<BudgetRecord>> getBudgetData() async {
    try {
      final res = await _retryRequest(() => _client.get(_uri('/get-budget-data')));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        return data.map((e) => BudgetRecord.fromJson(e as Map<String, dynamic>)).toList();
      }
      _log('getBudgetData returned status ${res.statusCode}');
    } catch (e) {
      _log('getBudgetData failed', error: e);
    }

    return const <BudgetRecord>[];
  }

  Future<List<RoadNetworkItem>> getRoadNetworkData() async {
    try {
      final res = await _retryRequest(() => _client.get(_uri('/get-road-network-data')));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        if (data.isNotEmpty) {
          return data.map((e) => RoadNetworkItem.fromJson(e as Map<String, dynamic>)).toList(growable: false);
        }
      }
      _log('getRoadNetworkData returned status ${res.statusCode}');
    } catch (e) {
      _log('getRoadNetworkData failed', error: e);
    }

    final bundled = await _loadBundledRoadNetwork();
    if (bundled.isNotEmpty) {
      return bundled;
    }

    return const <RoadNetworkItem>[];
  }

  Future<({List<RoadNetworkItem> roads, bool hasMore, int page})> getRoadNetworkPageForDistrict(
    String? district, {
    int page = 1,
    int limit = 10,
  }) async {
    String roadKey(RoadNetworkItem road) {
      final id = road.id.trim();
      if (id.isNotEmpty) {
        return 'id:$id';
      }
      final districts = road.districts.map(_normalizeDistrictToken).toList()..sort();
      return 'name:${_normalizeDistrictToken(road.name)}|route:${_normalizeDistrictToken(road.route)}|districts:${districts.join(',')}';
    }

    try {
      final res = await _retryRequest(
        () => _client.get(
          _uri('/api/roads', {
            if (district != null && district.trim().isNotEmpty) 'district': district.trim(),
            'page': '$page',
            'limit': '$limit',
          }),
        ),
      );
      if (res.statusCode == 200) {
        final payload = jsonDecode(res.body) as Map<String, dynamic>;
        var data = (payload['roads'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => RoadNetworkItem.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
        // Merge in bundled road data for the district so offline/bundled entries
        // that are not yet present in the backend are still shown to users.
        if (page == 1) {
          try {
            final bundled = await _loadBundledRoadNetwork();
            if (bundled.isNotEmpty && district != null && district.trim().isNotEmpty && district.trim() != 'ALL') {
              final normalized = _normalizeDistrictToken(district);
              final matchingBundled = bundled.where((item) {
                return item.districts.any((value) => _normalizeDistrictToken(value) == normalized) ||
                    _normalizeDistrictToken(item.name).contains(normalized) ||
                    _normalizeDistrictToken(item.route).contains(normalized);
              }).toList(growable: false);
              final existingKeys = data.map(roadKey).toSet();
              final extras = matchingBundled.where((b) => !existingKeys.contains(roadKey(b))).toList(growable: false);
              if (extras.isNotEmpty) {
                data = [...data, ...extras];
              }
            }
          } catch (_) {
            // ignore bundled load failures
          }
        }
        if (data.isEmpty && district != null && district.trim().isNotEmpty && district.trim() != 'ALL') {
          final normalized = _normalizeDistrictToken(district);
          final localRoads = (await _loadBundledRoadNetwork())
              .where((item) {
                return item.districts.any((value) => _normalizeDistrictToken(value) == normalized) ||
                    _normalizeDistrictToken(item.name).contains(normalized) ||
                    _normalizeDistrictToken(item.route).contains(normalized);
              })
              .toList(growable: false);
          final start = ((page - 1) * limit).clamp(0, localRoads.length);
          final end = (start + limit).clamp(0, localRoads.length);
          final slice = localRoads.sublist(start, end);
          return (
            roads: slice,
            hasMore: end < localRoads.length,
            page: (payload['page'] as num?)?.toInt() ?? page,
          );
        }
        return (
          roads: data,
          hasMore: payload['hasMore'] as bool? ?? false,
          page: (payload['page'] as num?)?.toInt() ?? page,
        );
      }
      _log('getRoadNetworkDataForDistrict returned status ${res.statusCode}');
    } catch (e) {
      _log('getRoadNetworkDataForDistrict failed', error: e);
    }

    final bundledRoads = await _loadBundledRoadNetwork();
    if (bundledRoads.isNotEmpty) {
      final matchingBundled = bundledRoads.where((item) {
        if (district == null || district.trim().isEmpty || district == 'ALL') {
          return true;
        }
        final normalized = _normalizeDistrictToken(district);
        return item.districts.any((value) => _normalizeDistrictToken(value) == normalized) ||
            _normalizeDistrictToken(item.name).contains(normalized) ||
            _normalizeDistrictToken(item.route).contains(normalized);
      }).toList(growable: false);
      final start = ((page - 1) * limit).clamp(0, matchingBundled.length);
      final end = (start + limit).clamp(0, matchingBundled.length);
      final slice = matchingBundled.sublist(start, end);
      return (roads: slice, hasMore: end < matchingBundled.length, page: page);
    }

    return (roads: const <RoadNetworkItem>[], hasMore: false, page: page);
  }

  Future<List<RoadNetworkItem>> getRoadNetworkDataForDistrict(
    String? district, {
    int page = 1,
    int limit = 10,
  }) async {
    final payload = await getRoadNetworkPageForDistrict(district, page: page, limit: limit);
    return payload.roads;
  }

  Future<RoadNetworkItem> getRoadNetworkItem(String itemId) async {
    final res = await _client.get(_uri('/get-road-network-data/$itemId')).timeout(_apiTimeout);
    if (res.statusCode != 200) {
      throw Exception('Road network item not found: $itemId');
    }
    return RoadNetworkItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<DetectionResult> detectDamage({
    required Uint8List imageBytes,
    required String fileName,
    String? roadId,
  }) async {
    final active = _activeDetectionRequest;
    if (active != null) {
      return active;
    }

    final wait = _cooldownDelay(_lastDetectionAt);
    final request = () async {
      if (wait > Duration.zero) {
        await Future.delayed(wait);
      }
      _lastDetectionAt = DateTime.now();
      return _detectDamageRequest(
        imageBytes: imageBytes,
        fileName: fileName,
        roadId: roadId,
      );
    }();

    _activeDetectionRequest = request;
    try {
      return await request;
    } finally {
      _activeDetectionRequest = null;
    }
  }

  Future<DetectionResult> _detectDamageRequest({
    required Uint8List imageBytes,
    required String fileName,
    String? roadId,
  }) async {
    try {
      if (imageBytes.lengthInBytes > 5 * 1024 * 1024) {
        throw Exception('Image must be under 5MB');
      }
      final uploadBytes = await _resizeImageForUpload(imageBytes);
      final request = http.MultipartRequest('POST', _uri('/api/detect-road-damage'));
      request.fields['road_id'] = roadId ?? '';
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          uploadBytes,
          filename: fileName,
          contentType: _contentTypeFor(fileName),
        ),
      );
      final streamed = await request.send().timeout(_apiTimeout);
      final body = await streamed.stream.bytesToString().timeout(_apiTimeout);
      if (streamed.statusCode == 200) {
        return DetectionResult.fromJson(jsonDecode(body) as Map<String, dynamic>);
      }
      if (_isTemporaryAiResponse(streamed.statusCode, body)) {
        throw Exception('AI service temporarily busy. Please retry shortly.');
      }
      throw Exception('detectDamage returned status ${streamed.statusCode}: $body');
    } catch (e) {
      _log('detectDamage failed', error: e);
      rethrow;
    }
  }

  Future<ComplaintItem> generateComplaint({
    required String roadId,
    required String description,
    required double lat,
    required double lng,
    String? imageRef,
    String? title,
    String? category,
    String? address,
  }) async {
    final res = await _client
        .post(
      _uri('/api/complaints'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'title': (title ?? description.trim().split('\n').first).trim().isEmpty
            ? 'Road issue report'
            : (title ?? description.trim().split('\n').first).trim(),
        'road_id': roadId,
        'description': description,
        'category': category ?? 'Other',
        'image': imageRef ?? '',
        'lat': lat,
        'lng': lng,
        'address': address ?? '',
      }),
    )
        .timeout(_apiTimeout);
    if (res.statusCode == 201 || res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final complaint = decoded['report'] is Map<String, dynamic>
          ? decoded['report'] as Map<String, dynamic>
          : decoded;
      return ComplaintItem.fromJson(complaint);
    }
    throw Exception('Complaint creation failed (${res.statusCode}): ${res.body}');
  }

  Future<ComplaintItem> sendComplaintToAuthority(String complaintId) async {
    final res = await _client.post(
      _uri('/api/complaints/$complaintId/send'),
      headers: await _authHeaders(),
    ).timeout(_apiTimeout);
    if (res.statusCode != 200) {
      throw Exception('Failed to send complaint: ${res.body}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final complaint = decoded['report'] is Map<String, dynamic>
        ? decoded['report'] as Map<String, dynamic>
        : decoded;
    return ComplaintItem.fromJson(complaint);
  }

  Future<ComplaintItem> markComplaintAsRead(String complaintId) async {
    final res = await _client.post(
      _uri('/api/complaints/$complaintId/read'),
      headers: await _authHeaders(),
    ).timeout(_apiTimeout);
    if (res.statusCode != 200) {
      throw Exception('Failed to update complaint tracking: ${res.body}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final complaint = decoded['report'] is Map<String, dynamic>
        ? decoded['report'] as Map<String, dynamic>
        : decoded;
    return ComplaintItem.fromJson(complaint);
  }

  Future<ComplaintItem> updateComplaint({
    required String complaintId,
    required String description,
    required double lat,
    required double lng,
    String? imageRef,
  }) async {
    final res = await _client
        .put(
      _uri('/api/complaints/$complaintId'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({
        'description': description,
        'image': imageRef,
        'lat': lat,
        'lng': lng,
      }),
    )
        .timeout(_apiTimeout);
    if (res.statusCode != 200) {
      throw Exception('Failed to update complaint: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final complaint = body['report'] is Map<String, dynamic>
        ? body['report'] as Map<String, dynamic>
        : body;
    return ComplaintItem.fromJson(complaint);
  }

  Future<List<ComplaintItem>> getComplaints({String? roadId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('rw_token');
      final hasToken = token != null && token.isNotEmpty;

      if (hasToken) {
        final protectedResponse = await _retryRequest(
          () async => _client.get(
            _uri('/api/complaints', {if (roadId != null) 'road_id': roadId}),
            headers: await _authHeaders(),
          ),
        );
        if (protectedResponse.statusCode == 200) {
          final decoded = jsonDecode(protectedResponse.body);
          final data = decoded is List<dynamic>
              ? decoded
              : (decoded as Map<String, dynamic>)['reports'] as List<dynamic>? ?? const <dynamic>[];
          return data.map((e) => ComplaintItem.fromJson(e as Map<String, dynamic>)).toList();
        }
        if (protectedResponse.statusCode != 401 && protectedResponse.statusCode != 403) {
          _log('getComplaints returned status ${protectedResponse.statusCode}');
        }
      }
    } catch (e) {
      _log('getComplaints failed', error: e);
    }

    try {
      final publicResponse = await _retryRequest(
        () async => _client.get(
          _uri('/complaints', {if (roadId != null) 'road_id': roadId}),
        ),
      );
      if (publicResponse.statusCode == 200) {
        final decoded = jsonDecode(publicResponse.body);
        final data = decoded is List<dynamic>
            ? decoded
            : (decoded as Map<String, dynamic>)['reports'] as List<dynamic>? ?? const <dynamic>[];
        return data.map((e) => ComplaintItem.fromJson(e as Map<String, dynamic>)).toList();
      }
      _log('public getComplaints returned status ${publicResponse.statusCode}');
    } catch (e) {
      _log('public getComplaints failed', error: e);
    }

    return const <ComplaintItem>[];
  }

  Future<List<Contractor>> getContractors() async {
    try {
      final res = await _retryRequest(() => _client.get(_uri('/contractors')));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        return data.map((e) => Contractor.fromJson(e as Map<String, dynamic>)).toList();
      }
      _log('getContractors returned status ${res.statusCode}');
    } catch (e) {
      _log('getContractors failed', error: e);
    }

    return const <Contractor>[];
  }

  Future<RiskPrediction> predictRisk({
    required String roadId,
    required double weatherIndex,
    required double trafficIndex,
    required int complaintCount30d,
  }) async {
    try {
      final res = await _retryRequest(
        () => _client.post(
          _uri('/predict-risk'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'road_id': roadId,
            'weather_index': weatherIndex,
            'traffic_index': trafficIndex,
            'complaint_count_30d': complaintCount30d,
          }),
        ),
      );
      if (res.statusCode == 200) {
        return RiskPrediction.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      _log('predictRisk returned status ${res.statusCode}');
    } catch (e) {
      _log('predictRisk failed', error: e);
    }

    return RiskPrediction.fromJson({
      'road_id': roadId,
      'risk_level': 'High',
      'probability_of_deterioration': 0.82,
      'predicted_days_to_decline': 19,
    });
  }

  Future<ChatResponse> askChat({
    required String query,
    required String? roadId,
    String? roadName,
    String? district,
    String? roadContext,
    required List<ChatItem> history,
  }) async {
    final active = _activeChatRequest;
    if (active != null) {
      return active;
    }

    final wait = _cooldownDelay(_lastChatAt);
    final request = () async {
      if (wait > Duration.zero) {
        await Future.delayed(wait);
      }
      _lastChatAt = DateTime.now();
      return _askChatRequest(query: query, roadId: roadId, roadContext: roadContext, history: history);
    }();

    _activeChatRequest = request;
    try {
      return await request;
    } finally {
      _activeChatRequest = null;
    }
  }

  Future<ChatResponse> _askChatRequest({
    required String query,
    required String? roadId,
    String? roadName,
    String? district,
    String? roadContext,
    required List<ChatItem> history,
  }) async {
    try {
      final chatUrl = _uri('/api/chat');
      _log('Outgoing chat request: $chatUrl');
      final res = await _retryRequest(() => _client.post(
            chatUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'road_id': roadId,
              if (roadName != null && roadName.trim().isNotEmpty) 'road_name': roadName,
              if (district != null && district.trim().isNotEmpty) 'district': district,
              if (roadContext != null && roadContext.trim().isNotEmpty) 'road_context': roadContext,
              'history': history.take(10).map((e) => e.toJson()).toList(),
            }),
          ), timeout: _chatTimeout);
      _log('Chat response status=${res.statusCode} body=${res.body.substring(0, res.body.length > 240 ? 240 : res.body.length)}');
      if (res.statusCode == 200) {
        return ChatResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      if (_isTemporaryAiResponse(res.statusCode, res.body)) {
        throw Exception('AI service temporarily busy. Please retry shortly.');
      }
      throw Exception('askChat returned status ${res.statusCode}: ${res.body}');
    } catch (e) {
      _log('askChat failed', error: e);
      rethrow;
    }
  }

  Future<int> syncOfflineComplaints(List<Map<String, dynamic>> pending) async {
    if (pending.isEmpty) {
      return 0;
    }
    final res = await _client
        .post(
      _uri('/sync-offline'),
      headers: await _authHeaders(json: true),
      body: jsonEncode({'complaints': pending}),
    )
        .timeout(_apiTimeout);
    if (res.statusCode != 200) {
      throw Exception('Sync failed: ${res.body}');
    }
    final payload = jsonDecode(res.body) as Map<String, dynamic>;
    return payload['synced'] as int;
  }

  MediaType _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return MediaType('image', 'jpeg');
  }

  Duration _cooldownDelay(DateTime? lastAt) {
    if (lastAt == null) {
      return Duration.zero;
    }
    final elapsed = DateTime.now().difference(lastAt);
    return elapsed >= _aiCooldown ? Duration.zero : _aiCooldown - elapsed;
  }

  bool _isTemporaryAiResponse(int statusCode, String body) {
    if (statusCode == 429 || statusCode == 503 || statusCode == 504) {
      return true;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['temporary'] == true ||
            decoded['message']?.toString() == 'AI service temporarily busy';
      }
    } catch (_) {}
    return false;
  }

  Future<Uint8List> _resizeImageForUpload(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final longest = width > height ? width : height;
    if (longest <= 1024) {
      return bytes;
    }

    final scale = 1024 / longest;
    final targetWidth = (width * scale).round().clamp(1, 1024);
    final targetHeight = (height * scale).round().clamp(1, 1024);
    final resizedCodec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final resizedFrame = await resizedCodec.getNextFrame();
    final data = await resizedFrame.image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List() ?? bytes;
  }

  Future<Map<String, dynamic>?> get(String path, [Map<String, String>? query]) async {
    try {
      final res = await _retryRequest(() => _client.get(_uri(path, query)));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      _log('GET $path returned status ${res.statusCode}', error: res.body);
    } catch (e) {
      _log('GET $path failed', error: e);
    }
    return null;
  }
}
