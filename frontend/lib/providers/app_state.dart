import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';

import '../models/budget_record.dart';
import '../models/chat.dart';
import '../models/complaint.dart';
import '../models/contractor.dart';
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
  List<String> _roadNetworkDistricts = [];
  final Map<String, List<RoadNetworkItem>> _roadsByDistrict = {};
  final Map<String, List<RoadNetworkItem>> _districtRoadCache = {};
  final Map<String, int> _districtRoadPages = {};
  final Map<String, bool> _districtRoadHasMore = {};
  final Set<String> _loadingDistrictRoads = {};
  final Map<String, Timer?> _districtDebounceTimers = {};
  final Map<String, List<Completer<List<RoadNetworkItem>>>> _districtPendingCompleters = {};
  // Cached aggregates for road network to avoid heavy recalculation in UI builds
  int _roadNetworkTotalLength = 0;
  int _roadNetworkTotalHealth = 0;
  final Map<String, int> _roadNetworkConditionCounts = {};
  final Map<String, int> _roadNetworkTypeCounts = {};
  final Map<String, int> _roadNetworkYearCounts = {};
  final Map<String, List<RoadNetworkItem>> _roadNetworkByType = {};
  final Map<String, RoadNetworkItem> _roadNetworkByUniqueKey = {};
  List<ComplaintItem> complaints = [];
  List<Contractor> contractors = [];
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
  bool isDarkMode = false;
  // ── Auth ─────────────────────────────────────────────────────────────────
  bool isAuthenticated = false;
  Map<String, dynamic>? currentUser;
  String? selectedRoadId;
  String? selectedRoadNetworkId;
  RoadNetworkItem? _currentRoadContext;
  String? lastMessage;
  String? locationStatus;
  String? _liveSuggestedDistrict;
  // Debug: request counters per district
  final Map<String, int> _requestCount = {};
  // Optional per-district debug info (last fetched page etc.)
  // Gamification state (local only)
  int userPoints = 0;
  List<String> userBadges = [];

  final List<ChatItem> chatHistory = [];
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _refreshTimer;
  Timer? _healthTimer;
  Timer? _realtimeStatusDebounceTimer;

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

  RoadNetworkItem? get selectedAssistantRoad {
    return _currentRoadContext ?? selectedRoadNetwork;
  }

  String? get selectedAssistantRoadName => selectedAssistantRoad?.name;

  String? get selectedAssistantRoadId {
    final road = selectedAssistantRoad;
    if (road == null) {
      return null;
    }
    if (road.id.trim().isNotEmpty) {
      return road.id.trim();
    }
    return selectedRoadNetworkId?.trim().isNotEmpty == true ? selectedRoadNetworkId!.trim() : null;
  }

  String? get selectedAssistantRoadDistrict {
    final road = selectedAssistantRoad;
    if (road == null) {
      return null;
    }
    for (final district in road.districts) {
      final trimmed = district.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  String _normalizeRoadToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _roadNetworkUniqueKey(RoadNetworkItem item) {
    final id = item.id.trim();
    if (id.isNotEmpty) {
      return '${id}_${item.name.trim()}';
    }
    return '${item.name.trim()}_${item.route.trim()}_${item.districts.join('|')}';
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

    // Pre-populate all districts from bundled JSON BEFORE the API call so
    // the dropdown immediately shows all Tamil Nadu districts on first render.
    unawaited(_preloadBundledDistricts());

    await refreshData();

    try {
      realtime.connect((event) {
        if (isOnline && !isLoading) {
          unawaited(_handleRealtimeUpdate(event));
        }
      }, onStatusChanged: (connected) {
        // Debounce transient false states so UI doesn't flicker.
        _realtimeStatusDebounceTimer?.cancel();
        if (connected) {
          // Immediate when connected.
          isRealtimeConnected = true;
          notifyListeners();
        } else {
          // Delay reporting disconnected to avoid rapid flip.
          _realtimeStatusDebounceTimer = Timer(const Duration(milliseconds: 900), () {
            isRealtimeConnected = false;
            notifyListeners();
          });
        }
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

  /// Eagerly loads all districts from the bundled complete_road_data.json
  /// and pre-populates [_roadNetworkDistricts], [_roadsByDistrict], and
  /// [_districtRoadCache] so the district dropdown immediately shows all
  /// Tamil Nadu districts even before the backend API responds.
  ///
  /// Never overwrites data that already exists (API data takes precedence).
  Future<void> _preloadBundledDistricts() async {
    try {
      final bundled = await _loadBundledRoadNetwork();
      if (bundled.isEmpty) return;

      final allDistricts = <String>{};
      final byDistrict = <String, List<RoadNetworkItem>>{};

      for (final item in bundled) {
        for (final rawDistrict in item.districts) {
          // Normalise alias (e.g. Thiruvallur → Tiruvallur) and clean the name.
          final canonical = _resolveDistrictAlias(_cleanDistrictCandidate(rawDistrict));
          if (canonical.trim().isEmpty) continue;
          allDistricts.add(canonical.trim());
          final key = canonical.trim().toLowerCase();
          byDistrict.putIfAbsent(key, () => <RoadNetworkItem>[]).add(item);
        }
      }

      // Merge district names — preserve any existing entries.
      final combined = <String>{..._roadNetworkDistricts, ...allDistricts}.toList()..sort();
      _roadNetworkDistricts = combined;

      // Populate _roadsByDistrict and _districtRoadCache only where not yet set
      // by API data, so live backend data always takes precedence.
      for (final entry in byDistrict.entries) {
        final key = entry.key;
        if (!_roadsByDistrict.containsKey(key) || (_roadsByDistrict[key]?.isEmpty ?? true)) {
          _roadsByDistrict[key] = entry.value;
        }
        if (!_districtRoadCache.containsKey(key) || (_districtRoadCache[key]?.isEmpty ?? true)) {
          _districtRoadCache[key] = entry.value;
        }
      }

      if (kDebugMode) {
        print('[RoadWatch] _preloadBundledDistricts DistrictCount=${_roadNetworkDistricts.length}');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[RoadWatch] _preloadBundledDistricts failed Error=$e');
      }
    }
  }

  /// Checks SharedPreferences for a stored [rw_token].
  /// Updates [isAuthenticated] and [currentUser] accordingly.
  /// Returns true if a valid token is present.
  Future<bool> checkAuth() async {
    final token = await localStorage.getToken();
    final user = await localStorage.getUser();
    isAuthenticated = token != null && token.isNotEmpty;
    currentUser = isAuthenticated ? user : null;
    if (kDebugMode) {
      print('[RoadWatch] checkAuth isAuthenticated=$isAuthenticated');
    }
    if (isAuthenticated) {
      await _hydratePersistedState();
    }
    notifyListeners();
    return isAuthenticated;
  }

  /// Calls backend login, persists token + user, sets [isAuthenticated].
  Future<void> login(String email, String password) async {
    final payload = await api.login(email: email, password: password);
    final token = payload['token'] as String? ?? '';
    final user = payload['user'] as Map<String, dynamic>? ?? {};
    await localStorage.saveToken(token);
    await localStorage.saveUser(user);
    isAuthenticated = token.isNotEmpty;
    currentUser = user;
    if (kDebugMode) {
      print('[RoadWatch] login success user=${user["email"]}');
    }
    if (isAuthenticated) {
      await _hydratePersistedState();
    }
    notifyListeners();
  }

  /// Calls backend signup, persists token + user, sets [isAuthenticated].
  Future<void> signup(String name, String email, String password) async {
    final payload = await api.signup(name: name, email: email, password: password);
    final token = payload['token'] as String? ?? '';
    final user = payload['user'] as Map<String, dynamic>? ?? {};
    await localStorage.saveToken(token);
    await localStorage.saveUser(user);
    isAuthenticated = token.isNotEmpty;
    currentUser = user;
    if (kDebugMode) {
      print('[RoadWatch] signup success user=${user["email"]}');
    }
    if (isAuthenticated) {
      await _hydratePersistedState();
    }
    notifyListeners();
  }

  /// Clears stored token and user, marks as unauthenticated.
  Future<void> logout() async {
    await localStorage.clearAuth();
    isAuthenticated = false;
    currentUser = null;
    if (kDebugMode) {
      print('[RoadWatch] logout complete');
    }
    notifyListeners();
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
    _rebuildRoadNetworkIndexes();
    complaints = await api.getComplaints();
    contractors = await api.getContractors();
    _ensureDefaultSelections();
    lastUpdatedAt = DateTime.now();

    isLoading = false;
    notifyListeners();
  }

  Future<void> _hydratePersistedState() async {
    await refreshData();

    if (!isOnline) {
      return;
    }

    final pendingComplaints = await localStorage.getPendingComplaints();
    final pendingDetections = await localStorage.getPendingDetections();
    if (pendingComplaints.isEmpty && pendingDetections.isEmpty) {
      return;
    }

    try {
      await syncOfflineData();
    } catch (error) {
      if (kDebugMode) {
        print('[RoadWatch] _hydratePersistedState sync failed Error=$error');
      }
    }
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
    final uniqueMatch = _roadNetworkByUniqueKey[selectedRoadNetworkId!];
    if (uniqueMatch != null) {
      return uniqueMatch;
    }
    for (final item in roadNetwork) {
      if (item.id == selectedRoadNetworkId) {
        return item;
      }
    }
    return null;
  }

  List<String> get roadNetworkDistricts {
    final unique = _roadNetworkDistricts.toSet().toList()..sort();
    return unique;
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

  String _cleanDistrictCandidate(String value) {
    var text = value.trim();
    text = text.replaceAll(RegExp(r'\bdistrict\b', caseSensitive: false), '').trim();
    text = text.replaceAll(RegExp(r'\btaluk\b', caseSensitive: false), '').trim();
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text;
  }
  
  String _resolveDistrictAlias(String district) {
    final target = _normalizeDistrictToken(district);
    for (final known in _roadNetworkDistricts) {
      if (_normalizeDistrictToken(known) == target) {
        return known;
      }
    }
    return district;
  }

  // Aggregates cached for UI to avoid recomputing in build()
  int get roadNetworkTotalLengthKm => _roadNetworkTotalLength;
  Map<String, int> get roadNetworkConditionCounts => Map.unmodifiable(_roadNetworkConditionCounts);
  Map<String, int> get roadNetworkTypeCounts => Map.unmodifiable(_roadNetworkTypeCounts);
  Map<String, int> get roadNetworkYearCounts => Map.unmodifiable(_roadNetworkYearCounts);
  int get roadNetworkAvgHealthScore => roadNetwork.isEmpty ? 0 : (_roadNetworkTotalHealth ~/ roadNetwork.length);
  List<RoadNetworkItem> roadsByType(String type) => List.unmodifiable(_roadNetworkByType[type] ?? <RoadNetworkItem>[]);
  // Accountability caches
  int _roadNetworkTotalBudget = 0;
  int _roadNetworkRoadsWithIssues = 0;
  int _roadNetworkAvgIssuesPerRoad = 0;
  List<Map<String, dynamic>> _roadsByBudget = [];
  List<Map<String, dynamic>> _roadsByIssues = [];
  List<Map<String, dynamic>> _roadsByEfficiency = [];

  int get roadNetworkTotalBudget => _roadNetworkTotalBudget;
  int get roadNetworkRoadsWithIssues => _roadNetworkRoadsWithIssues;
  int get roadNetworkAvgIssuesPerRoad => _roadNetworkAvgIssuesPerRoad;
  List<Map<String, dynamic>> topRoadsByBudget([int limit = 15]) => _roadsByBudget.take(limit).toList(growable: false);
  List<Map<String, dynamic>> topRoadsByIssues([int limit = 15]) => _roadsByIssues.take(limit).toList(growable: false);
  List<Map<String, dynamic>> topRoadsByEfficiency([int limit = 15]) => _roadsByEfficiency.take(limit).toList(growable: false);

  String? get liveSuggestedDistrict {
    return _liveSuggestedDistrict;
  }

  RoadSegment? get nearestRoadFromCurrentPosition {
    final position = currentPosition;
    if (position == null || roads.isEmpty) {
      return null;
    }

    RoadSegment? nearestRoad;
    var nearestDistance = double.infinity;

    for (final road in roads) {
      for (final point in road.polyline) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          point.lat,
          point.lng,
        );
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestRoad = road;
        }
      }
    }

    return nearestRoad;
  }

  List<RoadNetworkItem> roadsForDistrict(String district) {
    if (district == 'ALL') {
      return roadNetwork;
    }
    final canonical = _resolveDistrictAlias(_cleanDistrictCandidate(district));
    final normalized = canonical.trim().toLowerCase();
    final combined = <RoadNetworkItem>[];
    final keys = <String>{
      normalized,
      canonical,
      district.trim(),
    }..removeWhere((value) => value.isEmpty);

    for (final key in keys) {
      combined.addAll(_districtRoadCache[key] ?? const <RoadNetworkItem>[]);
      combined.addAll(_roadsByDistrict[key] ?? const <RoadNetworkItem>[]);
    }

    if (combined.isEmpty) {
      combined.addAll(_localRoadsForDistrict(district));
    }

    final fallback = _dedupeRoadNetworkItems(combined);
    if (kDebugMode) {
      print('[RoadWatch] district=$district roads=${fallback.length}');
    }
    return fallback;
  }

  RoadNetworkItem? networkRoadByUniqueKey(String key) {
    if (key.isEmpty) return null;
    // Try direct lookup first
    final direct = _roadNetworkByUniqueKey[key];
    if (direct != null) return direct;

    // Fallback: attempt to compute unique key from existing network items
    for (final item in roadNetwork) {
      final id = item.id.trim();
      final computed = id.isNotEmpty ? '${id}_${item.name.trim()}' : '${item.name.trim()}_${item.route.trim()}_${item.districts.join('|')}';
      if (computed == key) {
        // cache and return
        _roadNetworkByUniqueKey[key] = item;
        return item;
      }
    }

    return null;
  }

  String? getDistrictForNearestRoad() {
    final nearestRoad = nearestRoadFromCurrentPosition;
    if (nearestRoad == null) return null;

    // First try to match by name/ward against per-district lists to avoid scanning entire network
    final haystack = '${nearestRoad.name} ${nearestRoad.ward}'.toLowerCase();
    for (final entry in _roadsByDistrict.entries) {
      final district = entry.key;
      final list = entry.value;
      for (final item in list) {
        final name = item.name.toLowerCase();
        final route = item.route.toLowerCase();
        if (haystack.contains(name) || haystack.contains(route) || name.contains(haystack) || route.contains(haystack)) {
          return district;
        }
      }
    }

    // fallback to simple district name scan
    for (final district in _roadNetworkDistricts) {
      if (haystack.contains(district.toLowerCase())) return district;
    }
    return null;
  }

  bool hasMoreRoadsForDistrict(String district) {
    final canonical = _resolveDistrictAlias(_cleanDistrictCandidate(district));
    final normalized = canonical.trim().toLowerCase();
    return _districtRoadHasMore[normalized] ?? false;
  }

  Future<List<RoadNetworkItem>> loadRoadsForDistrict(String district) async {
    final normalized = _resolveDistrictAlias(_cleanDistrictCandidate(district)).trim();
    if (kDebugMode) {
      print('[RoadWatch] loadRoadsForDistrict called');
      print('[RoadWatch] District=$district');
    }
    if (normalized.isEmpty || normalized == 'ALL') {
      return roadNetwork;
    }

    if (normalized == 'AUTO') {
      // If we have a live suggested district, load that instead; otherwise avoid loading.
      final suggested = _liveSuggestedDistrict;
      if (kDebugMode) {
        print('[RoadWatch] loadRoadsForDistrict AUTO -> suggested=$suggested');
      }
      if (suggested == null || suggested.trim().isEmpty) {
        return const <RoadNetworkItem>[];
      }
      return _enqueueDistrictLoad(suggested, reset: true);
    }

    // Seed UI immediately from local index/cache to reduce selector render lag.
    final key = normalized.toLowerCase();
    final seeded = _localRoadsForDistrict(normalized);
    if (kDebugMode) {
      print('[RoadWatch] District=$district SeededCount=${seeded.length}');
    }
    if (seeded.length > 1) {
      final existing = roadsForDistrict(district);
      final mergedSeed = _dedupeRoadNetworkItems([...existing, ...seeded]);
      _districtRoadCache[key] = mergedSeed;
      _roadsByDistrict[key] = mergedSeed;
      _roadsByDistrict[district] = mergedSeed;
      _autoSelectFirstRoadForDistrict(mergedSeed);
      notifyListeners();
      return _enqueueDistrictLoad(normalized, reset: true);
    }

    return _enqueueDistrictLoad(normalized, reset: true);
  }

  Future<List<RoadNetworkItem>> loadMoreRoadsForDistrict(String district) async {
    final normalized = _resolveDistrictAlias(_cleanDistrictCandidate(district)).trim();
    if (kDebugMode) {
      print('[RoadWatch] loadMoreRoadsForDistrict called');
      print('[RoadWatch] District=$district');
    }
    if (normalized.isEmpty || normalized == 'ALL') {
      return roadNetwork;
    }

    if (normalized == 'AUTO') {
      final suggested = _liveSuggestedDistrict;
      if (kDebugMode) {
        print('[RoadWatch] loadMoreRoadsForDistrict AUTO -> suggested=$suggested');
      }
      if (suggested == null || suggested.trim().isEmpty) {
        return const <RoadNetworkItem>[];
      }
      // delegate to suggested district
      return loadMoreRoadsForDistrict(suggested);
    }

    final key = normalized.toLowerCase();
    if (!(_districtRoadHasMore[key] ?? false)) {
      return _districtRoadCache[key] ?? const <RoadNetworkItem>[];
    }
    return _enqueueDistrictLoad(normalized, reset: false);
  }

  Future<List<RoadNetworkItem>> _enqueueDistrictLoad(String district, {required bool reset}) {
    final key = district.toLowerCase();
    final completer = Completer<List<RoadNetworkItem>>();
    final pending = _districtPendingCompleters.putIfAbsent(key, () => <Completer<List<RoadNetworkItem>>>[]);
    if (pending.isNotEmpty) {
      // There's already a pending load for this district; return the existing pending future to avoid duplicate work.
      if (kDebugMode) {
        print('[RoadWatch] Reusing pending request for district=$district');
      }
      return pending.first.future;
    }
    pending.add(completer);

    // debounce multiple requests for the same district
    _districtDebounceTimers[key]?.cancel();
    _districtDebounceTimers[key] = Timer(const Duration(milliseconds: 120), () async {
      try {
        final result = await _loadDistrictRoadPage(district, reset: reset);
        final pending = _districtPendingCompleters.remove(key) ?? [];
        for (final p in pending) {
          if (!p.isCompleted) p.complete(result);
        }
      } catch (e, st) {
        final pending = _districtPendingCompleters.remove(key) ?? [];
        for (final p in pending) {
          if (!p.isCompleted) p.completeError(e, st);
        }
      } finally {
        _districtDebounceTimers.remove(key)?.cancel();
      }
    });

    return completer.future;
  }

  Future<List<RoadNetworkItem>> _loadDistrictRoadPage(String district, {required bool reset}) async {
    final key = district.toLowerCase();
    if (_loadingDistrictRoads.contains(key)) {
      return _districtRoadCache[key] ?? const <RoadNetworkItem>[];
    }

    _loadingDistrictRoads.add(key);
    try {
      final page = reset ? 1 : (_districtRoadPages[key] ?? 1) + 1;
      final start = DateTime.now();
      if (kDebugMode) {
        _requestCount[key] = (_requestCount[key] ?? 0) + 1;
        print('[RoadWatch] FetchStart');
        print('[RoadWatch] District=$district');
        print('[RoadWatch] Page=$page');
        print('[RoadWatch] Loading=true');
        print('[RoadWatch] ReusedPending=false');
        print('[RoadWatch] Count=${_requestCount[key]}');
      }

      final localRoads = roadsForDistrict(district);
      if (localRoads.length > 1) {
        final startIndex = reset ? 0 : (_districtRoadCache[key]?.length ?? 0);
        final endIndex = (startIndex + 10).clamp(0, localRoads.length);
        final slice = localRoads.sublist(startIndex, endIndex);
        final existing = List<RoadNetworkItem>.from(_districtRoadCache[key] ?? _roadsByDistrict[key] ?? const <RoadNetworkItem>[]);
        final merged = _dedupeRoadNetworkItems([...existing, ...slice]);
        _districtRoadCache[key] = merged;
        _roadsByDistrict[key] = merged;
        _roadsByDistrict[district] = merged;
        _districtRoadPages[key] = page;
        _districtRoadHasMore[key] = endIndex < localRoads.length;
        final districtSet = {..._roadNetworkDistricts, district};
        _roadNetworkDistricts = districtSet.toList()..sort();
        if (kDebugMode) {
          final fetchMs = DateTime.now().difference(start).inMilliseconds;
          print('[RoadWatch] FetchDone');
          print('[RoadWatch] District=$district');
          print('[RoadWatch] Page=$page');
          print('[RoadWatch] Loading=false');
          print('[RoadWatch] RoadsReturned=${slice.length}');
          print('[RoadWatch] District=$district RoadCount=${merged.length}');
          print('[RoadWatch] District=$district MergedCount=${merged.length}');
          print('[RoadWatch] CachedCount=${_roadsByDistrict[district]?.length ?? 0}');
          print('[RoadWatch] FetchTime=${fetchMs}ms');
          print('[RoadWatch] Count=${_requestCount[key]}');
        }
        notifyListeners();
        return merged;
      }

        final payload = await api.getRoadNetworkPageForDistrict(district, page: page, limit: 10);
      final existing = reset ? <RoadNetworkItem>[] : List<RoadNetworkItem>.from(_districtRoadCache[key] ?? const <RoadNetworkItem>[]);
          final districtToken = _normalizeDistrictToken(district);
            var fetchedRoads = payload.roads.isNotEmpty
              ? payload.roads
              : roadNetwork
                .where(
                (item) =>
                  item.districts.any((value) => _normalizeDistrictToken(value) == districtToken) ||
                  _normalizeDistrictToken(item.name).contains(districtToken) ||
                  _normalizeDistrictToken(item.route).contains(districtToken),
                )
                .toList(growable: false);
            if (fetchedRoads.length <= 1) {
              final bundled = await _loadBundledRoadNetwork();
              if (bundled.isNotEmpty) {
                final bundledDistrictRoads = bundled.where((item) {
                  return item.districts.any((value) => _normalizeDistrictToken(value) == districtToken) ||
                      _normalizeDistrictToken(item.name).contains(districtToken) ||
                      _normalizeDistrictToken(item.route).contains(districtToken);
                }).toList(growable: false);
                if (bundledDistrictRoads.isNotEmpty) {
                  fetchedRoads = _dedupeRoadNetworkItems([...fetchedRoads, ...bundledDistrictRoads]);
                }
              }
            }
        final combined = [...existing, ...fetchedRoads];
      // Dedupe by unique key while preserving order
      final seen = <String>{};
      final merged = <RoadNetworkItem>[];
      String makeKey(RoadNetworkItem item) {
        final id = item.id.trim();
        if (id.isNotEmpty) return '${id}_${item.name.trim()}';
        return '${item.name.trim()}_${item.route.trim()}_${item.districts.join('|')}';
      }
      for (final item in combined) {
        final k = makeKey(item);
        if (seen.add(k)) {
          merged.add(item);
        }
      }
      _districtRoadCache[key] = merged;
      // store by normalized key and also by original district for compatibility
      _roadsByDistrict[key] = merged;
      _roadsByDistrict[district] = merged;
      _autoSelectFirstRoadForDistrict(merged);
      _districtRoadPages[key] = payload.page;
      _districtRoadHasMore[key] = payload.roads.isNotEmpty ? payload.hasMore : false;
      final districtSet = {..._roadNetworkDistricts, district};
      _roadNetworkDistricts = districtSet.toList()..sort();
      if (kDebugMode) {
        final fetchMs = DateTime.now().difference(start).inMilliseconds;
        print('[RoadWatch] FetchDone');
        print('[RoadWatch] District=$district');
        print('[RoadWatch] Page=${payload.page}');
        print('[RoadWatch] Loading=false');
        print('[RoadWatch] RoadsReturned=${fetchedRoads.length}');
        print('[RoadWatch] District=$district RoadCount=${merged.length}');
        print('[RoadWatch] District=$district MergedCount=${merged.length}');
        print('[RoadWatch] CachedCount=${_roadsByDistrict[district]?.length ?? 0}');
        print('[RoadWatch] FetchTime=${fetchMs}ms');
        print('[RoadWatch] Count=${_requestCount[key]}');
        if ((_requestCount[key] ?? 0) > 1) {
          print('[RoadWatch] Duplicate requests detected:');
          print('[RoadWatch] District=$district');
          print('[RoadWatch] Count=${_requestCount[key]}');
        }
      }
      notifyListeners();
      return merged;
    } finally {
      _loadingDistrictRoads.remove(key);
    }
  }

  /// Diagnostics: return debug information for a district.
  /// Keys: loadedCount, page, hasMore, requestCount, isLoading
  Map<String, dynamic> districtDebugInfo(String district) {
    final key = district.trim().toLowerCase();
    return {
      'loadedCount': (_districtRoadCache[key]?.length ?? 0),
      'page': _districtRoadPages[key] ?? 0,
      'hasMore': _districtRoadHasMore[key] ?? false,
      'requestCount': _requestCount[key] ?? 0,
      'isLoading': _loadingDistrictRoads.contains(key),
    };
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

  List<RoadSegment> roadsForComplaintDistrict(String district) {
    if (district == 'ALL') {
      return roads;
    }

    if (district == 'AUTO') {
      final suggestedDistrict = liveSuggestedDistrict;
      if (suggestedDistrict == null) {
        return roads;
      }
      return roadsForComplaintDistrict(suggestedDistrict);
    }

    final canonical = _resolveDistrictAlias(district);
    final normalizedDistrict = canonical.trim().toLowerCase();
    final normalizedToken = _normalizeDistrictToken(canonical);
    return roads
        .where(
          (road) =>
              road.ward.toLowerCase().contains(normalizedDistrict) ||
              road.name.toLowerCase().contains(normalizedDistrict) ||
              _normalizeDistrictToken(road.ward).contains(normalizedToken) ||
              _normalizeDistrictToken(road.name).contains(normalizedToken),
        )
        .toList(growable: false);
  }

  String? _heuristicDistrictFromPosition(Position position) {
    final lat = position.latitude;
    final lng = position.longitude;
    if (lat >= 12.7 && lat <= 13.35 && lng >= 79.9 && lng <= 80.55) {
      return 'Chennai';
    }
    return null;
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
      // Logging GPS coordinates for debugging (debug-only)
      try {
        if (kDebugMode) {
          print('GPS coordinates:');
          print(currentPosition?.latitude);
          print(currentPosition?.longitude);
        }
      } catch (_) {}
        final detectedDistrict = await location.reverseGeocodeDistrict(currentPosition!);
        _liveSuggestedDistrict = detectedDistrict == null
          ? null
          : _resolveDistrictAlias(_cleanDistrictCandidate(detectedDistrict));
      // Log detected district (debug-only)
      try {
        if (kDebugMode) {
          print('Detected district:');
          print(_liveSuggestedDistrict);
        }
      } catch (_) {}
      _liveSuggestedDistrict ??= _heuristicDistrictFromPosition(currentPosition!);

      // Update status and notify listeners before fetching roads so UI can
      // update its local `selectedDistrict` and render a loading state.
      locationStatus = _liveSuggestedDistrict == null
          ? 'Live location active, but district could not be resolved.'
          : 'Live location active in $_liveSuggestedDistrict';
      if (kDebugMode) {
        print('[RoadWatch] requestLiveLocation');
        print('[RoadWatch] District=${_liveSuggestedDistrict ?? 'null'}');
      }
      notifyListeners();

      // Small delay to allow UI to process the district change and set local
      // selection state before we start loading roads for that district.
      await Future.delayed(const Duration(milliseconds: 100));

      if (_liveSuggestedDistrict != null) {
        final loaded = await loadRoadsForDistrict(_liveSuggestedDistrict!);
        if (loaded.isEmpty) {
          // If reverse geocoding gave a nearby but wrong district, prefer nearest-road district evidence.
          final nearestDistrict = getDistrictForNearestRoad();
          if (nearestDistrict != null && nearestDistrict.trim().isNotEmpty) {
            final canonicalNearest = _resolveDistrictAlias(_cleanDistrictCandidate(nearestDistrict));
            if (canonicalNearest != _liveSuggestedDistrict) {
              _liveSuggestedDistrict = canonicalNearest;
              await loadRoadsForDistrict(_liveSuggestedDistrict!);
              if (kDebugMode) {
                print('[RoadWatch] District corrected from reverse geocode using nearest road evidence');
                print('[RoadWatch] District=$_liveSuggestedDistrict');
              }
            }
          }
        }
      }

      // After obtaining live coordinates and loading roads, try to
      // auto-select the nearest road and its network item.
      _autoSelectNearestRoad();
    } catch (error) {
      currentPosition = null;
      _liveSuggestedDistrict = null;
      final text = error.toString();
      if (text.contains('Location services are disabled')) {
        locationStatus = 'Turn on location services to auto-detect your district.';
      } else if (text.contains('Location permission denied')) {
        locationStatus = 'Allow location permission so RoadWatch can detect your district.';
      } else {
        locationStatus = 'Could not detect your district automatically. Please select it manually.';
      }
    }

    isLocationLoading = false;
    notifyListeners();
  }

  void _autoSelectNearestRoad() {
    final nearest = nearestRoadFromCurrentPosition;
    if (nearest == null) return;

    // Select the nearest RoadSegment by id
    selectedRoadId = nearest.id;

    // Try to find a best matching RoadNetworkItem by name/route similarity
    final match = roadNetwork.cast<RoadNetworkItem?>().firstWhere(
      (item) {
        final candidate = item;
        if (candidate == null) return false;
        return nearest.name.toLowerCase().contains(candidate.name.toLowerCase()) ||
            candidate.name.toLowerCase().contains(nearest.name.toLowerCase()) ||
            nearest.ward.toLowerCase().contains(candidate.route.toLowerCase()) ||
            candidate.route.toLowerCase().contains(nearest.ward.toLowerCase());
      },
      orElse: () => null,
    );

    if (match != null) {
      selectedRoadNetworkId = match.id;
    }
  }

  bool isLoadingRoadsForDistrict(String district) {
    final key = district.trim().toLowerCase();
    return _loadingDistrictRoads.contains(key);
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

  Future<void> _refreshComplaintData() async {
    complaints = await api.getComplaints();
    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  void _ensureDefaultSelections() {
    if (selectedRoadId == null && roads.isNotEmpty) {
      selectedRoadId = roads.first.id;
    }
    if (selectedRoadNetworkId == null && roadNetwork.isNotEmpty) {
      selectedRoadNetworkId = roadNetwork.first.id;
    }
  }

  void _rebuildRoadNetworkIndexes() {
    final districts = <String>{};
    final roadsByDistrict = <String, List<RoadNetworkItem>>{};

    // reset aggregates
    _roadNetworkTotalLength = 0;
    _roadNetworkConditionCounts.clear();
    _roadNetworkTypeCounts.clear();
    _roadNetworkYearCounts.clear();
    _roadNetworkByType.clear();
    _roadNetworkByUniqueKey.clear();

    for (final item in roadNetwork) {
      // districts
      for (final district in item.districts) {
        districts.add(district);
        roadsByDistrict.putIfAbsent(district, () => <RoadNetworkItem>[]).add(item);
      }
      // total length
      _roadNetworkTotalLength += item.lengthKm;
      // total health score (derived from condition)
      _roadNetworkTotalHealth += item.healthScore;
      // condition counts
      _roadNetworkConditionCounts[item.condition] = (_roadNetworkConditionCounts[item.condition] ?? 0) + 1;
      // type counts and grouping
      _roadNetworkTypeCounts[item.type] = (_roadNetworkTypeCounts[item.type] ?? 0) + 1;
      _roadNetworkByType.putIfAbsent(item.type, () => <RoadNetworkItem>[]).add(item);
      // year grouping (decade)
      final decade = '${(item.year ~/ 10) * 10}s';
      _roadNetworkYearCounts[decade] = (_roadNetworkYearCounts[decade] ?? 0) + 1;
      // unique key mapping
      final id = item.id.trim();
      final uniqueKey = id.isNotEmpty ? '${id}_${item.name.trim()}' : '${item.name.trim()}_${item.route.trim()}_${item.districts.join('|')}';
      _roadNetworkByUniqueKey[uniqueKey] = item;
    }

    _roadNetworkDistricts = districts.toList()..sort();
    _roadsByDistrict
      ..clear()
      ..addAll(roadsByDistrict);

    // Also merge districts from the bundled road dataset asynchronously
    unawaited(() async {
      try {
        final bundled = await _loadBundledRoadNetwork();
        if (bundled.isEmpty) return;
        final bundledSet = <String>{};
        for (final item in bundled) {
          for (final d in item.districts) {
            final token = _resolveDistrictAlias(d);
            if (token.trim().isNotEmpty) bundledSet.add(token.trim());
          }
        }
        final combined = {..._roadNetworkDistricts, ...bundledSet}.toList()..sort();
        _roadNetworkDistricts = combined;
        if (kDebugMode) {
          print('[RoadWatch] Bundled districts merged Count=${_roadNetworkDistricts.length}');
        }
        notifyListeners();
      } catch (_) {}
    }());

    // Accountability caches: precompute budgets, issues and efficiency lists
    final baseList = roadNetwork
        .map((item) => {
              'road': item,
              'budgetCrore': item.budgetCrore,
              'issueCount': item.issues.length,
              'efficiency': item.budgetCrore > 0 ? item.issues.length / (item.budgetCrore / 10) : 0.0,
              'budgetPerKm': item.lengthKm > 0 ? (item.budgetCrore * 10000000 / item.lengthKm) : 0,
            })
        .toList(growable: false);

    _roadNetworkTotalBudget = baseList.fold<int>(0, (s, e) => s + (e['budgetCrore'] as int));
    _roadsByBudget = List<Map<String, dynamic>>.from(baseList)..sort((a, b) => (b['budgetCrore'] as int).compareTo(a['budgetCrore'] as int));
    _roadsByIssues = List<Map<String, dynamic>>.from(baseList)..sort((a, b) => (b['issueCount'] as int).compareTo(a['issueCount'] as int));
    _roadsByEfficiency = List<Map<String, dynamic>>.from(baseList)..sort((a, b) => (b['efficiency'] as double).compareTo(a['efficiency'] as double));
    _roadNetworkRoadsWithIssues = baseList.where((e) => (e['issueCount'] as int) > 0).length;
    _roadNetworkAvgIssuesPerRoad = roadNetwork.isEmpty ? 0 : baseList.fold<int>(0, (sum, e) => sum + (e['issueCount'] as int)) ~/ roadNetwork.length;
    // notifyListeners is called by caller refreshData which calls this method
  }

  List<RoadNetworkItem> _localRoadsForDistrict(String district) {
    final canonical = _resolveDistrictAlias(_cleanDistrictCandidate(district)).trim();
    if (canonical.isEmpty || canonical == 'ALL') {
      return List<RoadNetworkItem>.from(roadNetwork);
    }

    final normalized = _normalizeDistrictToken(canonical);
    final source = roadNetwork;
    return source
        .where(
          (item) =>
              item.districts.any((value) => _normalizeDistrictToken(value) == normalized) ||
              _normalizeDistrictToken(item.name).contains(normalized) ||
              _normalizeDistrictToken(item.route).contains(normalized),
        )
        .toList(growable: false);
  }

  List<RoadNetworkItem> _dedupeRoadNetworkItems(List<RoadNetworkItem> items) {
    final seen = <String>{};
    final merged = <RoadNetworkItem>[];
    for (final item in items) {
      final id = item.id.trim();
      final key = id.isNotEmpty ? '${id}_${item.name.trim()}' : '${item.name.trim()}_${item.route.trim()}_${item.districts.join('|')}';
      if (seen.add(key)) {
        merged.add(item);
      }
    }
    return merged;
  }

  RoadSegment? _matchingRoadSegmentForNetworkRoad(RoadNetworkItem networkRoad) {
    final networkName = _normalizeRoadToken(networkRoad.name);
    final networkRoute = _normalizeRoadToken(networkRoad.route);
    RoadSegment? bestMatch;
    var bestScore = 0;

    for (final road in roads) {
      final roadName = _normalizeRoadToken(road.name);
      final ward = _normalizeRoadToken(road.ward);
      var score = 0;

      if (roadName.isNotEmpty && roadName == networkName) {
        score += 6;
      } else if (roadName.isNotEmpty && (roadName.contains(networkName) || networkName.contains(roadName))) {
        score += 4;
      }

      if (ward.isNotEmpty && ward == networkRoute) {
        score += 4;
      } else if (ward.isNotEmpty && (ward.contains(networkRoute) || networkRoute.contains(ward))) {
        score += 2;
      }

      if (networkRoute.isNotEmpty && roadName.contains(networkRoute)) {
        score += 1;
      }
      if (networkName.isNotEmpty && ward.contains(networkName)) {
        score += 1;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = road;
      }
    }

    return bestScore > 0 ? bestMatch : null;
  }

  RoadNetworkItem? _matchingRoadNetworkForSegment(RoadSegment road) {
    final roadName = _normalizeRoadToken(road.name);
    final roadWard = _normalizeRoadToken(road.ward);
    RoadNetworkItem? bestMatch;
    var bestScore = 0;

    for (final networkRoad in roadNetwork) {
      final networkName = _normalizeRoadToken(networkRoad.name);
      final networkRoute = _normalizeRoadToken(networkRoad.route);
      var score = 0;

      if (roadName.isNotEmpty && roadName == networkName) {
        score += 6;
      } else if (roadName.isNotEmpty && (roadName.contains(networkName) || networkName.contains(roadName))) {
        score += 4;
      }

      if (roadWard.isNotEmpty && roadWard == networkRoute) {
        score += 4;
      } else if (roadWard.isNotEmpty && (roadWard.contains(networkRoute) || networkRoute.contains(roadWard))) {
        score += 2;
      }

      if (networkRoute.isNotEmpty && roadName.contains(networkRoute)) {
        score += 1;
      }
      if (networkName.isNotEmpty && roadWard.contains(networkName)) {
        score += 1;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = networkRoad;
      }
    }

    return bestScore > 0 ? bestMatch : null;
  }

  bool _selectedRoadNetworkMatchesDistrict(List<RoadNetworkItem> roadsForDistrict) {
    final selected = selectedRoadNetwork;
    if (selected == null) {
      return false;
    }
    final selectedKey = _roadNetworkUniqueKey(selected);
    for (final road in roadsForDistrict) {
      if (_roadNetworkUniqueKey(road) == selectedKey) {
        return true;
      }
    }
    return false;
  }

  void _autoSelectFirstRoadForDistrict(List<RoadNetworkItem> roadsForDistrict) {
    if (roadsForDistrict.isEmpty || _selectedRoadNetworkMatchesDistrict(roadsForDistrict)) {
      return;
    }

    final firstValidRoad = roadsForDistrict.firstWhere(
      (road) => road.name.trim().isNotEmpty,
      orElse: () => roadsForDistrict.first,
    );
    final key = _roadNetworkUniqueKey(firstValidRoad);
    selectedRoadNetworkId = key;
    _roadNetworkByUniqueKey[key] = firstValidRoad;
    _currentRoadContext = firstValidRoad;

    final matchingRoad = _matchingRoadSegmentForNetworkRoad(firstValidRoad);
    if (matchingRoad != null) {
      selectedRoadId = matchingRoad.id;
    } else {
      selectedRoadId = null;
    }
  }

  Future<List<RoadNetworkItem>> _loadBundledRoadNetwork() async {
    try {
      final jsonText = await rootBundle.loadString('assets/complete_road_data.json');
      final data = jsonDecode(jsonText) as List<dynamic>;
      return data
          .map((e) => RoadNetworkItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (e) {
      if (kDebugMode) {
        print('[RoadWatch] AppState bundled road load failed Error=$e');
      }
      return const <RoadNetworkItem>[];
    }
  }

  void selectRoad(String roadId) {
    selectedRoadId = roadId;
    for (final road in roads) {
      if (road.id == roadId) {
        final match = _matchingRoadNetworkForSegment(road);
        if (match != null) {
          _syncSelectedRoadNetwork(match);
          _currentRoadContext = match;
        } else {
          selectedRoadNetworkId = null;
          _currentRoadContext = null;
        }
        notifyListeners();
        return;
      }
    }
    selectedRoadNetworkId = null;
    _currentRoadContext = null;
    notifyListeners();
  }

  void setSelectedRoad(RoadSegment road) {
    selectedRoadId = road.id;
    final match = _matchingRoadNetworkForSegment(road);
    if (match != null) {
      _syncSelectedRoadNetwork(match);
      _currentRoadContext = match;
    } else {
      selectedRoadNetworkId = null;
      _currentRoadContext = null;
    }
    notifyListeners();
  }

  void selectRoadNetwork(String roadNetworkId) {
    selectedRoadNetworkId = roadNetworkId;
    notifyListeners();
  }

  void setSelectedRoadNetwork(RoadNetworkItem roadNetwork) {
    selectRoadNetworkItem(roadNetwork);
  }

  void _syncSelectedRoadNetwork(RoadNetworkItem roadNetwork) {
    final key = _roadNetworkUniqueKey(roadNetwork);
    selectedRoadNetworkId = key;
    _roadNetworkByUniqueKey[key] = roadNetwork;
    _currentRoadContext = roadNetwork;

    final match = _matchingRoadSegmentForNetworkRoad(roadNetwork);
    if (match != null) {
      selectedRoadId = match.id;
    } else {
      selectedRoadId = null;
    }
  }

  void selectRoadNetworkItem(RoadNetworkItem item) {
    _syncSelectedRoadNetwork(item);
    notifyListeners();
  }

  /// Move the complaint with [complaintId] to the top of the list so it
  /// becomes the `latestComplaint`. This is used by the UI when a user
  /// explicitly selects a complaint to view its live tracking.
  void promoteComplaintToTop(String complaintId) {
    final idx = complaints.indexWhere((c) => c.id == complaintId);
    if (idx > 0) {
      final item = complaints.removeAt(idx);
      complaints.insert(0, item);
      notifyListeners();
    }
  }

  // Gamification helpers
  void addPoints(int pts) {
    if (pts <= 0) return;
    userPoints += pts;
    notifyListeners();
  }

  bool claimReward(String rewardId, int cost) {
    if (userPoints >= cost) {
      userPoints -= cost;
      if (!userBadges.contains(rewardId)) {
        userBadges.add(rewardId);
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  void unlockBadge(String badgeId) {
    if (badgeId.isEmpty) return;
    if (!userBadges.contains(badgeId)) {
      userBadges.add(badgeId);
      notifyListeners();
    }
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
      lastDetection = await api.detectDamage(
        imageBytes: imageBytes,
        fileName: fileName,
        roadId: roadId,
      );
      await refreshData();
      lastMessage = 'Detection complete in ${lastDetection?.inferenceMs ?? 0} ms.';
    } catch (error) {
      lastDetection = null;
      final message = error.toString();
      lastMessage = message.contains('AI service temporarily busy')
          ? 'AI service temporarily busy. Please retry shortly.'
          : 'AI detection failed. Please try again shortly.';
    }
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
      lastDetection = await api.detectDamage(
        imageBytes: imageBytes,
        fileName: fileName,
        roadId: roadId,
      );
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
    if (chatHistory.length > 10) {
      chatHistory.removeRange(0, chatHistory.length - 10);
    }
    notifyListeners();

    try {
      final selectedRoad = selectedAssistantRoad;
      final selectedRoadName = selectedRoad?.name;
      final selectedRoadDistrict = selectedAssistantRoadDistrict;
      final response = await api.askChat(
        query: query,
        roadId: selectedAssistantRoadId,
        roadName: selectedRoadName,
        district: selectedRoadDistrict,
        roadContext: selectedRoadName,
        history: chatHistory,
      );
      chatHistory.add(ChatItem(role: 'assistant', content: response.answer));
      if (chatHistory.length > 10) {
        chatHistory.removeRange(0, chatHistory.length - 10);
      }
    } catch (error) {
      if (kDebugMode) {
        print('[RoadWatch] askAssistant failed Error=$error');
      }
      final message = error.toString().contains('AI service temporarily busy')
          ? 'AI service temporarily busy. Please retry shortly.'
          : 'RoadWatch assistant is temporarily unavailable right now.';
      chatHistory.add(
        ChatItem(
          role: 'assistant',
          content: message,
        ),
      );
      if (chatHistory.length > 10) {
        chatHistory.removeRange(0, chatHistory.length - 10);
      }
    }
    notifyListeners();
  }

  // Contractor methods
  Contractor? getContractorById(String contractorId) {
    for (final contractor in contractors) {
      if (contractor.id == contractorId) {
        return contractor;
      }
    }
    return null;
  }

  List<Contractor> searchContractors(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return contractors;
    }
    return contractors
        .where(
          (c) =>
              c.name.toLowerCase().contains(normalized) ||
              c.company.toLowerCase().contains(normalized),
        )
        .toList();
  }

  List<Contractor> getContractorsSortedBy(String sortBy) {
    final sorted = List<Contractor>.from(contractors);
    switch (sortBy) {
      case 'highest_rated':
        sorted.sort((a, b) => b.overallRating.compareTo(a.overallRating));
        break;
      case 'most_complaints':
        sorted.sort((a, b) => b.complaintCount.compareTo(a.complaintCount));
        break;
      case 'recently_reviewed':
        // Sort by most recent review timestamp
        sorted.sort((a, b) {
          final aTime = a.reviews.isNotEmpty ? a.reviews.first.timestamp : '';
          final bTime = b.reviews.isNotEmpty ? b.reviews.first.timestamp : '';
          return bTime.compareTo(aTime);
        });
        break;
      case 'trusted_badge':
        const badgeOrder = {'gold': 0, 'silver': 1, 'bronze': 2, '': 3};
        sorted.sort((a, b) =>
            (badgeOrder[a.trustedBadge] ?? 3).compareTo(badgeOrder[b.trustedBadge] ?? 3));
        break;
    }
    return sorted;
  }

  Contractor? getContractorForRoad(String roadId) {
    for (final contractor in contractors) {
      if (contractor.roadsManaged.contains(roadId)) {
        return contractor;
      }
    }
    return null;
  }

  void submitContractorReview(String contractorId, ContractorReview review) {
    // Find the contractor and add the review
    for (var i = 0; i < contractors.length; i++) {
      if (contractors[i].id == contractorId) {
        final updatedReviews = List<ContractorReview>.from(contractors[i].reviews)..insert(0, review);
        
        // Calculate new overall rating
        final totalRating = updatedReviews.fold<int>(0, (sum, r) => sum + r.rating);
        final newOverallRating = totalRating / updatedReviews.length;
        
        // Create updated contractor
        final updatedContractor = Contractor(
          id: contractors[i].id,
          name: contractors[i].name,
          company: contractors[i].company,
          projectStatus: contractors[i].projectStatus,
          overallRating: newOverallRating,
          totalReviews: updatedReviews.length,
          reviews: updatedReviews,
          trustedBadge: contractors[i].trustedBadge,
          publicTransparencyScore: contractors[i].publicTransparencyScore,
          complaintCount: contractors[i].complaintCount,
          roadsManaged: contractors[i].roadsManaged,
          profileImageUrl: contractors[i].profileImageUrl,
        );
        
        contractors[i] = updatedContractor;
        notifyListeners();
        break;
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _healthTimer?.cancel();
    _connectivitySubscription?.cancel();
    _realtimeStatusDebounceTimer?.cancel();
    unawaited(realtime.disconnect());
    super.dispose();
  }
}
