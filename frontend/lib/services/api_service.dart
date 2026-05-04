import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../models/budget_record.dart';
import '../models/chat.dart';
import '../models/complaint.dart';
import '../models/detection.dart';
import '../models/risk_prediction.dart';
import '../models/road_network_item.dart';
import 'demo_data_service.dart';

class ApiService {
  final http.Client _client;
  static const Duration _apiTimeout = Duration(seconds: 20);
  static const String _roadNetworkFallbackUrl =
      'https://raw.githubusercontent.com/AmalTony-A/RoadWatch/main/backend/app/data/road_network_data.json';

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> getRoadData() async {
    try {
      final res = await _client.get(_uri('/get-road-data'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return DemoDataService.roadPayload();
  }

  Future<List<BudgetRecord>> getBudgetData() async {
    try {
      final res = await _client.get(_uri('/get-budget-data'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        return data.map((e) => BudgetRecord.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    return DemoDataService.budgetPayload().map(BudgetRecord.fromJson).toList();
  }

  Future<List<RoadNetworkItem>> getRoadNetworkData() async {
    try {
      final res = await _client.get(_uri('/get-road-network-data'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        return data.map((e) => RoadNetworkItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    try {
      final res = await _client.get(Uri.parse(_roadNetworkFallbackUrl)).timeout(_apiTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        return data.map((e) => RoadNetworkItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    return DemoDataService.roadNetworkPayload()
        .map((e) => RoadNetworkItem.fromJson(e))
        .toList(growable: false);
  }

  Future<RoadNetworkItem> getRoadNetworkItem(String itemId) async {
    final res = await _client.get(_uri('/get-road-network-data/$itemId'));
    if (res.statusCode != 200) {
      throw Exception('Road network item not found: $itemId');
    }
    return RoadNetworkItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<String> uploadImage(
    Uint8List imageBytes, {
    required String fileName,
    String? roadId,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/upload-image', {
      if (roadId != null) 'road_id': roadId,
    }));
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
        contentType: _contentTypeFor(fileName),
      ),
    );
    final streamed = await request.send().timeout(_apiTimeout);
    final body = await streamed.stream.bytesToString().timeout(_apiTimeout);
    if (streamed.statusCode != 200) {
      throw Exception('Failed to upload image: $body');
    }
    final payload = jsonDecode(body) as Map<String, dynamic>;
    return payload['image_id'] as String;
  }

  Future<DetectionResult> detectDamage({required String imageId, String? roadId}) async {
    try {
      final res = await _client
          .post(
        _uri('/detect-damage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_id': imageId, 'road_id': roadId}),
      )
          .timeout(_apiTimeout);
      if (res.statusCode == 200) {
        return DetectionResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
      throw Exception(res.body);
    } catch (_) {
      return DetectionResult.fromJson({
        'image_id': imageId,
        'road_id': roadId,
        'model': 'demo-mock-detector',
        'inference_ms': 510,
        'image_width': 640,
        'image_height': 360,
        'detections': [
          {
            'label': 'pothole',
            'confidence': 0.92,
            'severity': 'high',
            'bbox': [102, 188, 254, 318]
          },
          {
            'label': 'crack',
            'confidence': 0.79,
            'severity': 'medium',
            'bbox': [320, 214, 470, 284]
          }
        ],
        'score': {
          'road_health_score': 76,
          'color': 'yellow',
          'severity_breakdown': {'low': 0, 'medium': 1, 'high': 1}
        },
        'scene_status': 'issue_detected',
        'scene_message': 'Road damage detected.',
        'needs_reupload': false,
      });
    }
  }

  Future<ComplaintItem> generateComplaint({
    required String roadId,
    required String description,
    required double lat,
    required double lng,
    String? imageRef,
  }) async {
    final res = await _client
        .post(
      _uri('/generate-complaint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'road_id': roadId,
        'description': description,
        'image_ref': imageRef,
        'location': {'lat': lat, 'lng': lng}
      }),
    )
        .timeout(_apiTimeout);
    if (res.statusCode != 200) {
      throw Exception('Complaint generation failed: ${res.body}');
    }
    return ComplaintItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ComplaintItem> sendComplaintToAuthority(String complaintId) async {
    final res = await _client.post(_uri('/complaints/$complaintId/send')).timeout(_apiTimeout);
    if (res.statusCode != 200) {
      throw Exception('Failed to send complaint: ${res.body}');
    }
    return ComplaintItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ComplaintItem> markComplaintAsRead(String complaintId) async {
    final res = await _client.post(_uri('/complaints/$complaintId/read')).timeout(_apiTimeout);
    if (res.statusCode != 200) {
      throw Exception('Failed to update complaint tracking: ${res.body}');
    }
    return ComplaintItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<ComplaintItem>> getComplaints({String? roadId}) async {
    try {
      final res = await _client.get(
        _uri('/complaints', {if (roadId != null) 'road_id': roadId}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        return data.map((e) => ComplaintItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    final fallback = DemoDataService.roadPayload()['recent_complaints'] as List<dynamic>;
    return fallback
        .map((e) => ComplaintItem.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<RiskPrediction> predictRisk({
    required String roadId,
    required double weatherIndex,
    required double trafficIndex,
    required int complaintCount30d,
  }) async {
    try {
      final res = await _client
          .post(
        _uri('/predict-risk'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'road_id': roadId,
          'weather_index': weatherIndex,
          'traffic_index': trafficIndex,
          'complaint_count_30d': complaintCount30d,
        }),
      )
          .timeout(_apiTimeout);
      if (res.statusCode == 200) {
        return RiskPrediction.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}

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
    required List<ChatItem> history,
  }) async {
    try {
      final res = await _client
          .post(
        _uri('/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'road_id': roadId,
          'history': history.map((e) => e.toJson()).toList(),
        }),
      )
          .timeout(_apiTimeout);
      if (res.statusCode == 200) {
        return ChatResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}

    return const ChatResponse(
      answer:
          'Road score is currently low because repeated potholes were detected and complaint volume is rising. I recommend filing a complaint now for rapid escalation.',
      citedData: {
        'road_name': 'Sardar Patel Road',
        'road_score': 38,
        'allocated_budget': 5000000,
      },
    );
  }

  Future<int> syncOfflineComplaints(List<Map<String, dynamic>> pending) async {
    if (pending.isEmpty) {
      return 0;
    }
    final res = await _client
        .post(
      _uri('/sync-offline'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(pending),
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
}
