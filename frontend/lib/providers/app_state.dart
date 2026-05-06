import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/budget_record.dart';
import '../models/chat.dart';
import '../models/complaint.dart';
import '../models/detection.dart';
import '../models/risk_prediction.dart';
import '../models/road_network_item.dart';
import '../models/road_segment.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_storage_service.dart';
import '../services/location_service.dart';
import '../services/realtime_service.dart';

class AppState extends ChangeNotifier {
  final ApiService api;
  final ConnectivityService connectivity;
  final LocalStorageService localStorage;
  final LocationService location;
  final RealtimeService realtime;

  AppState({
    required this.api,
    required this.connectivity,
    required this.localStorage,
    required this.location,
    RealtimeService? realtime,
  }) : realtime = realtime ?? RealtimeService();

  List<RoadSegment> roads = [];
  List<BudgetRecord> budgets = [];
  List<RoadNetworkItem> roadNetwork = [];
  List<ComplaintItem> complaints = [];
  Position? currentPosition;
  Map<String, dynamic> overview = {};
  Map<String, dynamic> intelligence = {};
  DetectionResult? lastDetection;
  RiskPrediction? lastRiskPrediction;
  DateTime? lastUpdatedAt;
  String? lastRealtimeEvent;
  DateTime? lastRealtimeEventAt;

  bool isLoading = false;
  bool isOnline = true;
  bool isBackendReachable = true;
  bool isRealtimeConnected = false;
  bool isLocationLoading = false;
  String? selectedRoadId;
  String? selectedRoadNetworkId;
  String? lastMessage;
  String? locationStatus;

  final List<ChatItem> chatHistory = [];
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _refreshTimer;
  Timer? _healthTimer;

  static const Duration _refreshInterval = Duration(seconds: 15);
  static const Duration _healthInterval = Duration(seconds: 30);

  RoadSegment? get selectedRoad {
    if (selectedRoadId == null) {
      return null;
    }
    for (final road in roads) {
      if (road.id == selectedRoadId) {
        return road;
      }
    }
    return null;
  }

  Future<void> initialize() async {
    isOnline = await connectivity.isOnline();
    _connectivitySubscription = connectivity.onlineStream().listen((value) {
      final wasOffline = !isOnline;
      isOnline = value;
      notifyListeners();
      if (wasOffline && value) {
        unawaited(syncOfflineData());
      }
    });

    await refreshData();

    try {
      realtime.connect((event) {
        if (isOnline && !isLoading) {
          unawaited(_handleRealtimeUpdate(event));
        }
      }, onStatusChanged: (connected) {
        isRealtimeConnected = connected;
        notifyListeners();
      });
    } catch (_) {
      // Keep the app usable even if realtime sockets are unavailable.
    }

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (isOnline && isBackendReachable && !isLoading) {
        unawaited(refreshData());
      }
    });

    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(_healthInterval, (_) {
      unawaited(_checkBackendHealth());
    });
    unawaited(_checkBackendHealth());
  }

  Future<void> _checkBackendHealth() async {
    final reachable = await api.checkHealth();
    if (isBackendReachable != reachable) {
      isBackendReachable = reachable;
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    isLoading = true;
    notifyListeners();

    final payload = await api.getRoadData();
    roads = (payload['roads'] as List<dynamic>)
        .map((e) => RoadSegment.fromJson(e as Map<String, dynamic>))
        .toList();
    overview = payload['overview'] as Map<String, dynamic>? ?? {};
    intelligence = payload['intelligence'] as Map<String, dynamic>? ?? {};

    budgets = await api.getBudgetData();
    roadNetwork = await api.getRoadNetworkData();
    complaints = await api.getComplaints();
    lastUpdatedAt = DateTime.now();

    isLoading = false;
    notifyListeners();
  }

  String get realtimeStatusLabel {
    if (!isOnline) {
      return 'Offline';
    }
    return isRealtimeConnected ? 'Realtime connected' : 'Realtime reconnecting';
  }

  ComplaintItem? get latestComplaint => complaints.isNotEmpty ? complaints.first : null;

  RoadNetworkItem? get selectedRoadNetwork {
    if (selectedRoadNetworkId == null) {
      return null;
    }
    for (final item in roadNetwork) {
      if (item.id == selectedRoadNetworkId) {
        return item;
      }
    }
    return null;
  }

  List<String> get roadNetworkDistricts {
    final districts = <String>{};
    for (final item in roadNetwork) {
      districts.addAll(item.districts);
    }
    final sorted = districts.toList()..sort();
    return sorted;
  }

  String? get liveSuggestedDistrict {
    final position = currentPosition;
    if (position == null) {
      return null;
    }

    final lat = position.latitude;
    final lng = position.longitude;
    if (lat >= 12.7 && lat <= 13.35 && lng >= 79.9 && lng <= 80.55) {
      return 'Chennai';
    }
    return null;
  }

  List<RoadNetworkItem> roadsForDistrict(String district) {
    if (district == 'ALL') {
      return roadNetwork;
    }
    return roadNetwork.where((item) => item.districts.contains(district)).toList();
  }

  List<RoadNetworkItem> searchRoadsForDistrict(String district, String query) {
    final base = roadsForDistrict(district);
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return base;
    }
    return base
        .where(
          (item) =>
              item.name.toLowerCase().contains(normalizedQuery) ||
              item.route.toLowerCase().contains(normalizedQuery) ||
              item.contractor.toLowerCase().contains(normalizedQuery) ||
              item.issues.any((issue) => issue.toLowerCase().contains(normalizedQuery)),
        )
        .toList();
  }

  Future<void> _handleRealtimeUpdate(Map<String, dynamic> event) async {
    final eventName = event['event']?.toString();
    lastRealtimeEvent = eventName ?? 'update';
    lastRealtimeEventAt = DateTime.tryParse(event['timestamp']?.toString() ?? '') ?? DateTime.now();
    notifyListeners();

    switch (eventName) {
      case 'detect-damage':
        _applyRoadSnapshot(event['road'] as Map<String, dynamic>?);
        _applyScoreSnapshot(event['score'] as Map<String, dynamic>?);
        if (event['road'] == null) {
          await _refreshRoadData();
        }
        if (event['score'] == null) {
          await _refreshBudgetData();
        }
        break;
      case 'generate-complaint-preview':
        _upsertComplaintSnapshot(
          event['complaint'] as Map<String, dynamic>?,
          replaceId: event['preview_id']?.toString(),
        );
        break;
      case 'generate-complaint':
        _applyRoadSnapshot(event['road'] as Map<String, dynamic>?);
        _upsertComplaintSnapshot(
          event['complaint'] as Map<String, dynamic>?,
          replaceId: event['preview_id']?.toString(),
        );
        if (event['road'] == null || event['complaint'] == null) {
          await _refreshRoadData();
          await _refreshComplaintData();
        }
        break;
      case 'sync-offline':
        final roadList = event['roads'];
        if (roadList is List) {
          roads = roadList
              .whereType<Map>()
              .map((e) => RoadSegment.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        final items = event['items'];
        if (items is List) {
          complaints = items
              .whereType<Map>()
              .map((e) => ComplaintItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        if (roadList == null || items == null) {
          await _refreshRoadData();
          await _refreshComplaintData();
        }
        lastUpdatedAt = DateTime.now();
        notifyListeners();
        break;
      default:
        await refreshData();
        break;
    }
  }

  Future<void> requestLiveLocation() async {
    if (isLocationLoading) {
      return;
    }

    isLocationLoading = true;
    locationStatus = 'Requesting live location...';
    notifyListeners();

    try {
      currentPosition = await location.getCurrentPosition();
      locationStatus = 'Live location active';
    } catch (error) {
      currentPosition = null;
      locationStatus = error.toString().replaceFirst('Exception: ', '');
    }

    isLocationLoading = false;
    notifyListeners();
  }

  void _applyRoadSnapshot(Map<String, dynamic>? roadData) {
    if (roadData == null || roadData.isEmpty) {
      return;
    }
    final updatedRoad = RoadSegment.fromJson(roadData);
    final index = roads.indexWhere((road) => road.id == updatedRoad.id);
    if (index >= 0) {
      roads[index] = updatedRoad;
    }
    if (selectedRoadId == updatedRoad.id) {
      notifyListeners();
    }
    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  void _applyScoreSnapshot(Map<String, dynamic>? scoreData) {
    if (scoreData == null || scoreData.isEmpty || selectedRoadId == null) {
      return;
    }
    final roadIndex = roads.indexWhere((road) => road.id == selectedRoadId);
    if (roadIndex >= 0) {
      final current = roads[roadIndex];
      roads[roadIndex] = RoadSegment(
        id: current.id,
        name: current.name,
        ward: current.ward,
        polyline: current.polyline,
        roadHealthScore: scoreData['road_health_score'] as int? ?? current.roadHealthScore,
        color: scoreData['color'] as String? ?? current.color,
        nearbyIssues: current.nearbyIssues,
        recentComplaints: current.recentComplaints,
      );
      lastUpdatedAt = DateTime.now();
      notifyListeners();
    }
  }

  void _upsertComplaintSnapshot(
    Map<String, dynamic>? complaintData, {
    String? replaceId,
  }) {
    if (complaintData == null || complaintData.isEmpty) {
      return;
    }
    final complaint = ComplaintItem.fromJson(complaintData);
    final targetIndex = complaints.indexWhere(
      (item) => item.id == complaint.id || (replaceId != null && item.id == replaceId),
    );
    if (targetIndex >= 0) {
      complaints[targetIndex] = complaint;
    } else {
      complaints.insert(0, complaint);
    }
    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  Future<void> _refreshRoadData() async {
    final payload = await api.getRoadData();
    roads = (payload['roads'] as List<dynamic>)
        .map((e) => RoadSegment.fromJson(e as Map<String, dynamic>))
        .toList();
    overview = payload['overview'] as Map<String, dynamic>? ?? {};
    intelligence = payload['intelligence'] as Map<String, dynamic>? ?? {};

    if (selectedRoadId == null && roads.isNotEmpty) {
      selectedRoadId = roads.first.id;
    }

    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  Future<void> _refreshBudgetData() async {
    budgets = await api.getBudgetData();
    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  Future<void> _refreshRoadNetwork() async {
    roadNetwork = await api.getRoadNetworkData();
    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  Future<void> _refreshComplaintData() async {
    complaints = await api.getComplaints();
    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  void selectRoad(String roadId) {
    selectedRoadId = roadId;
    notifyListeners();
  }

  void selectRoadNetwork(String roadNetworkId) {
    selectedRoadNetworkId = roadNetworkId;
    notifyListeners();
  }

  void selectRoadNetworkItem(RoadNetworkItem item) {
    selectedRoadNetworkId = item.id;
    final match = roads.cast<RoadSegment?>().firstWhere(
      (road) =>
          road != null &&
          (road.name.toLowerCase().contains(item.name.toLowerCase()) ||
              item.name.toLowerCase().contains(road.name.toLowerCase()) ||
              road.ward.toLowerCase().contains(item.route.toLowerCase()) ||
              item.route.toLowerCase().contains(road.ward.toLowerCase())),
      orElse: () => null,
    );
    if (match != null) {
      selectedRoadId = match.id;
    }
    notifyListeners();
  }

  Future<void> runDetection({required Uint8List imageBytes, required String fileName}) async {
    final roadId = selectedRoadId;
    if (!isOnline) {
      await localStorage.addPendingDetection({
        'road_id': roadId,
        'file_name': fileName,
        'image_base64': base64Encode(imageBytes),
        'created_at': DateTime.now().toIso8601String(),
      });
      lastMessage = 'Offline mode: detection request queued for sync.';
      notifyListeners();
      return;
    }

    try {
      final imageId = await api.uploadImage(
        imageBytes,
        fileName: fileName,
        roadId: roadId,
      );
      lastDetection = await api.detectDamage(imageId: imageId, roadId: roadId);
      await refreshData();
      lastMessage = 'Detection complete in ${lastDetection?.inferenceMs ?? 0} ms.';
    } catch (_) {
      // Fall back to demo detection with one of the known demo images
      // This ensures the backend can find the demo detections
      final demoImageId = fileName.toLowerCase().contains('crack')
          ? 'demo_crack_2.svg'
          : fileName.toLowerCase().contains('good') || fileName.toLowerCase().contains('clear')
              ? 'demo_good_road.svg'
              : 'demo_pothole_1.svg';
      lastDetection = await api.detectDamage(
        imageId: demoImageId,
        roadId: roadId,
      );
      lastMessage = 'Backend unavailable. Using demo detection for "$fileName".';
    }
    notifyListeners();
  }

  Future<void> runDemoDetection(String demoImageId) async {
    final roadId = selectedRoadId;
    lastDetection = await api.detectDamage(imageId: demoImageId, roadId: roadId);
    await refreshData();
    lastMessage = 'Demo detection complete.';
    notifyListeners();
  }

  Future<void> fileComplaint({
    required String description,
    String? imageRef,
  }) async {
    final roadId = selectedRoadId;
    if (roadId == null) {
      lastMessage = 'Select a road before filing complaint.';
      notifyListeners();
      return;
    }

    final position = await _quickPosition();
    final lat = position?.latitude ?? 12.9946;
    final lng = position?.longitude ?? 80.2371;

    final complaintPayload = {
      'road_id': roadId,
      'description': description,
      'image_ref': imageRef,
      'location': {'lat': lat, 'lng': lng},
    };

    if (!isOnline) {
      await localStorage.addPendingComplaint(complaintPayload);
      lastMessage = 'Offline mode: complaint saved locally and will sync automatically.';
      notifyListeners();
      return;
    }

    final created = await api.generateComplaint(
      roadId: roadId,
      description: description,
      lat: lat,
      lng: lng,
      imageRef: imageRef,
    );
    complaints.insert(0, created);
    lastMessage = 'Complaint ${created.id} filed successfully.';
    notifyListeners();
  }

  Future<void> sendLatestComplaint() async {
    final complaint = latestComplaint;
    if (complaint == null) {
      return;
    }

    final updated = await api.sendComplaintToAuthority(complaint.id);
    final index = complaints.indexWhere((item) => item.id == updated.id);
    if (index >= 0) {
      complaints[index] = updated;
    }
    lastMessage = 'Complaint sent to ${updated.recommendedDepartment}.';
    notifyListeners();
  }

  Future<void> markLatestComplaintRead() async {
    final complaint = latestComplaint;
    if (complaint == null) {
      return;
    }

    final updated = await api.markComplaintAsRead(complaint.id);
    final index = complaints.indexWhere((item) => item.id == updated.id);
    if (index >= 0) {
      complaints[index] = updated;
    }
    lastMessage = 'Authority read the complaint letter.';
    notifyListeners();
  }

  Future<Position?> _quickPosition() async {
    try {
      final lastKnown = await location.getCurrentPosition().timeout(const Duration(seconds: 1));
      return lastKnown;
    } catch (_) {
      return null;
    }
  }

  Future<void> syncOfflineData() async {
    if (!isOnline) {
      lastMessage = 'Sync unavailable while offline.';
      notifyListeners();
      return;
    }

    final pendingComplaints = await localStorage.getPendingComplaints();
    final pendingDetections = await localStorage.getPendingDetections();

    int syncedComplaints = 0;
    if (pendingComplaints.isNotEmpty) {
      syncedComplaints = await api.syncOfflineComplaints(pendingComplaints);
      await localStorage.clearPendingComplaints();
    }

    for (final item in pendingDetections) {
      final roadId = item['road_id'] as String?;
      final imageBase64 = item['image_base64'] as String?;
      final fileName = item['file_name'] as String?;
      if (imageBase64 == null || fileName == null) {
        continue;
      }

      final imageBytes = base64Decode(imageBase64);

      final imageId = await api.uploadImage(
        imageBytes,
        fileName: fileName,
        roadId: roadId,
      );
      lastDetection = await api.detectDamage(imageId: imageId, roadId: roadId);
    }
    if (pendingDetections.isNotEmpty) {
      await localStorage.clearPendingDetections();
    }

    await refreshData();
    lastMessage =
        'Sync complete: $syncedComplaints complaints and ${pendingDetections.length} detections uploaded.';
    notifyListeners();
  }

  Future<void> runRiskPrediction() async {
    final road = selectedRoad;
    if (road == null) {
      return;
    }
    lastRiskPrediction = await api.predictRisk(
      roadId: road.id,
      weatherIndex: 0.71,
      trafficIndex: 0.84,
      complaintCount30d: road.recentComplaints,
    );
    notifyListeners();
  }

  Future<void> askAssistant(String query) async {
    if (query.trim().isEmpty) {
      return;
    }

    chatHistory.add(ChatItem(role: 'user', content: query));
    notifyListeners();

    try {
      final response = await api.askChat(
        query: query,
        roadId: selectedRoadId,
        history: chatHistory,
      );
      chatHistory.add(ChatItem(role: 'assistant', content: response.answer));
    } catch (_) {
      chatHistory.add(
        const ChatItem(
          role: 'assistant',
          content:
              'Assistant is temporarily unavailable from the backend. Please try again in a moment, or continue in demo mode.',
        ),
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _healthTimer?.cancel();
    _connectivitySubscription?.cancel();
    unawaited(realtime.disconnect());
    super.dispose();
  }
}
