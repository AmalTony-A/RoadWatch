// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../features/map/map_provider.dart';

import '../config/app_config.dart';
import '../models/road_segment.dart';
import '../models/road_network_item.dart';
import '../providers/app_state.dart';
import '../widgets/hover_road_chip.dart';
import '../widgets/road_health_legend.dart';
import '../widgets/road_score_gauge.dart';
import 'map_fullscreen.dart'; // Importing the full-screen map screen for navigation

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final GlobalKey _scoreSectionKey = GlobalKey();
  static const int _roadRowsStep = 4;
  static const int _scoreScrollMaxAttempts = 4;
  bool _centeredOnLiveLocation = false;
  bool _mapEditingEnabled = false;
  bool _manualDistrictSelection = false;
  bool _manualRoadSelection = false;
  bool _mapRefreshQueued = false;
  bool _syncLiveDistrictQueued = false;
  bool _pendingScoreScroll = false;
  int _scoreScrollAttempts = 0;
  String _selectedDistrict = 'ALL';
  String? _selectedNetworkRoadId;
  int _visibleRoadRows = _roadRowsStep;

  void _resetRoadRows() {
    _visibleRoadRows = _roadRowsStep;
  }

  void _showMoreRoadRows() {
    setState(() {
      _visibleRoadRows += _roadRowsStep;
    });
  }

  Color _roadColor(String color) {
    return AppConfig.healthColorFromText(color);
  }

  void _maybeCenterMap(AppState state) {
    final position = state.currentPosition;
    if (position == null || _centeredOnLiveLocation) {
      return;
    }
    // Try to center the map on the user's live location. Use a few retry
    // attempts with short delays and try/catch to avoid 'used after
    // disposed' exceptions that can occur on web when the FlutterMap
    // controller is recreated during hot reload or navigation.
    final target = LatLng(position.latitude, position.longitude);
    _attemptCenter(target, 15.2);
  }

  void _attemptCenter(LatLng target, double zoom, {int attempts = 3}) {
    if (_centeredOnLiveLocation) return;
    var attempt = 0;
    void tryMove() async {
      if (!mounted) return;
      attempt++;
      try {
        _mapController.move(target, zoom);
        if (mounted) {
          _centeredOnLiveLocation = true;
        }
      } catch (_) {
        if (attempt < attempts && !_centeredOnLiveLocation) {
          await Future.delayed(const Duration(milliseconds: 150));
          tryMove();
        }
      }
    }

    // Start the first attempt on the next microtask so the map has a chance
    // to initialize its controller when the widget tree is still stabilizing.
    Future.microtask(tryMove);
  }

  void _toggleMapEditing() {
    setState(() {
      _mapEditingEnabled = !_mapEditingEnabled;
    });
  }

  Color _healthColor(int score) {
    if (score >= 80) {
      return AppConfig.safeGreen;
    }
    if (score >= 60) {
      return AppConfig.cautionYellow;
    }
    return AppConfig.dangerRed;
  }

  List<RoadNetworkItem> _districtRoads(AppState state) {
    return state.searchRoadsForDistrict(_selectedDistrict, '');
  }

  RoadNetworkItem? _networkRoadByKey(AppState state, String? key) {
    if (key == null) return null;
    for (final item in state.roadNetwork) {
      if (_roadUniqueKey(item) == key) return item;
    }
    return null;
  }

  String _roadUniqueKey(RoadNetworkItem road) {
    final id = (road.id ?? '').trim();
    if (id.isNotEmpty) {
      return '${id}_${road.name.trim()}';
    }
    return '${road.name.trim()}_${road.route.trim()}_${road.districts.join('|')}';
  }

  RoadSegment? _matchingRoadSegment(AppState state, RoadNetworkItem networkRoad) {
    final networkName = networkRoad.name.trim().toLowerCase();
    for (final seg in state.roads) {
      if (seg.name.trim().toLowerCase() == networkName) return seg;
    }
    return null;
  }

  bool _isValidRoadForSelection(RoadNetworkItem road) {
    return road.name.trim().isNotEmpty;
  }

  bool _roadMatchesNetworkRoad(RoadSegment road, RoadNetworkItem networkRoad) {
    final roadName = road.name.trim().toLowerCase();
    final networkName = networkRoad.name.trim().toLowerCase();
    final ward = road.ward.trim().toLowerCase();
    final route = networkRoad.route.trim().toLowerCase();
    return roadName == networkName ||
        roadName.contains(networkName) ||
        networkName.contains(roadName) ||
        ward.contains(route) ||
        route.contains(ward);
  }

  void _queueMapRefresh(BuildContext context, List<RoadSegment> roads) {
    if (_mapRefreshQueued || roads.isEmpty) {
      return;
    }

    _mapRefreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapRefreshQueued = false;
      if (!mounted) {
        return;
      }
      context.read<MapProvider>().updateFromRoads(roads);
    });
  }


  void _selectNetworkRoad(
    AppState state,
    RoadNetworkItem road, {
    required bool manual,
  }) {
    setState(() {
      _selectedNetworkRoadId = _roadUniqueKey(road);
      _manualRoadSelection = manual;
    });

    state.selectRoadNetworkItem(road);

    // Sync matching road segment for score + transparency modules
    final matchingRoad = _matchingRoadSegment(state, road);
    if (matchingRoad != null) {
      state.selectRoad(matchingRoad.id);
    }

    // When user manually selects a road from dropdown/button, ensure the
    // selected road score section is visible so the user sees the result.
    if (manual) {
      _requestScrollToScore();
    }
  }

  void _requestScrollToScore() {
    _pendingScoreScroll = true;
    _scoreScrollAttempts = 0;
    _tryScrollToScore();
  }

  void _tryScrollToScore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pendingScoreScroll) return;
      final ctx = _scoreSectionKey.currentContext;
      if (ctx != null) {
        _pendingScoreScroll = false;
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeInOut,
        );
        return;
      }

      if (_scoreScrollAttempts < _scoreScrollMaxAttempts) {
        _scoreScrollAttempts++;
        _tryScrollToScore();
      } else {
        _pendingScoreScroll = false;
      }
    });
  }

  String? _districtFromNearestRoad(AppState state) {
    final nearestRoad = state.nearestRoadFromCurrentPosition;
    if (nearestRoad == null) {
      return null;
    }

    final haystack = '${nearestRoad.name} ${nearestRoad.ward}'.toLowerCase();
    for (final district in state.roadNetworkDistricts) {
      if (haystack.contains(district.toLowerCase())) {
        return district;
      }
    }
    return null;
  }

  RoadNetworkItem _bestNetworkRoadForLiveLocation(
    AppState state,
    List<RoadNetworkItem> roads,
  ) {
    final nearestRoad = state.nearestRoadFromCurrentPosition;
    if (nearestRoad == null) {
      return roads.first;
    }

    final nearestName = nearestRoad.name.toLowerCase();
    final nearestWard = nearestRoad.ward.toLowerCase();
    for (final road in roads) {
      final name = road.name.toLowerCase();
      final route = road.route.toLowerCase();
      if (nearestName.contains(name) ||
          name.contains(nearestName) ||
          nearestWard.contains(route) ||
          route.contains(nearestWard)) {
        return road;
      }
    }
    return roads.first;
  }

  int _districtCityScore(List<RoadNetworkItem> roads) {
    if (roads.isEmpty) {
      return 0;
    }
    final total = roads.fold<int>(0, (sum, road) => sum + road.healthScore);
    return (total / roads.length).round();
  }

  int _districtRedRoads(List<RoadNetworkItem> roads) {
    return roads.where((road) => road.healthScore < 60).length;
  }

  int _districtLiveComplaints(List<RoadNetworkItem> roads) {
    return roads.fold<int>(0, (sum, road) => sum + road.issues.length);
  }

  void _syncLiveDistrict(AppState state) {
    if (_syncLiveDistrictQueued) {
      return;
    }
    _syncLiveDistrictQueued = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncLiveDistrictQueued = false;
      if (!mounted) return;
      
      final suggested = state.liveSuggestedDistrict ?? _districtFromNearestRoad(state);
      if (suggested == null || _manualDistrictSelection) {
        return;
      }

      final roadsInSuggested = state.searchRoadsForDistrict(suggested, '');
      final selected = _networkRoadByKey(state, _selectedNetworkRoadId) ?? state.selectedRoadNetwork;
      final selectedInSuggested =
          selected != null && roadsInSuggested.any((item) => _roadUniqueKey(item) == _roadUniqueKey(selected));

      if (_selectedDistrict == suggested &&
          (_manualRoadSelection || selectedInSuggested || roadsInSuggested.isEmpty)) {
        return;
      }

      if (!mounted || _manualDistrictSelection) {
        return;
      }

      setState(() {
        _selectedDistrict = suggested;
        _resetRoadRows();
      });

      final nearestRoad = state.nearestRoadFromCurrentPosition;
      if (nearestRoad != null) {
        state.selectRoad(nearestRoad.id);
      }

      if (roadsInSuggested.isNotEmpty && !_manualRoadSelection) {
        final liveRoad = _bestNetworkRoadForLiveLocation(state, roadsInSuggested);

        setState(() {
          _selectedNetworkRoadId = _roadUniqueKey(liveRoad);
        });

        state.selectRoadNetworkItem(liveRoad);

        final matchingRoad = _matchingRoadSegment(state, liveRoad);
        if (matchingRoad != null) {
          state.selectRoad(matchingRoad.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mapProvider = context.watch<MapProvider>();
    // Ensure provider has up-to-date cache for current roads
    // Prevent repeated heavy updates during rebuilds
    if (mapProvider.polylines.isEmpty || mapProvider.markers.isEmpty) {
      _queueMapRefresh(context, state.roads);
    }
    final selectedNetworkRoad =
      _networkRoadByKey(state, _selectedNetworkRoadId) ??
      state.selectedRoadNetwork;

    // Only treat selectedRoad as authoritative when it matches the selected network road.
    final selectedRoad = state.selectedRoad;
    final displayedSelectedRoad =
      selectedRoad != null &&
        selectedNetworkRoad != null &&
        !_roadMatchesNetworkRoad(selectedRoad, selectedNetworkRoad)
      ? null
      : selectedRoad;
    final theme = Theme.of(context);
    
    // Early returns to prevent heavy recalculations on every rebuild
    _maybeCenterMap(state);
    _syncLiveDistrict(state);

    final districtOptions = ['ALL', ...state.roadNetworkDistricts];
    final filteredNetworkRoads = state.searchRoadsForDistrict(_selectedDistrict, '');
    final uniqueRoadDropdownItems = <String, RoadNetworkItem>{
      for (final road in filteredNetworkRoads)
        if (_isValidRoadForSelection(road))
          _roadUniqueKey(road): road,
    };
    final uniqueFilteredNetworkRoads = uniqueRoadDropdownItems.values.toList(growable: false);
    final visibleNetworkRoads = _selectedDistrict == 'ALL'
      ? uniqueFilteredNetworkRoads.take(_visibleRoadRows).toList(growable: false)
      : uniqueFilteredNetworkRoads;
    final canShowMoreRoads =
      _selectedDistrict == 'ALL' && uniqueFilteredNetworkRoads.length > visibleNetworkRoads.length;
    final selectedNetworkRoadInDistrict =
        _selectedNetworkRoadId != null && uniqueRoadDropdownItems.containsKey(_selectedNetworkRoadId);
    final roadDropdownValue = selectedNetworkRoadInDistrict ? _selectedNetworkRoadId : null;
    
    // Cache district roads - only compute once per selected district
    late final List<RoadNetworkItem> districtRoads;
    late final int districtCityScore;
    late final int districtRedRoads;
    late final int districtLiveComplaints;
    
    // Only compute if we actually need these values (when rendering metric cards)
    if (state.roadNetwork.isNotEmpty) {
      districtRoads = _districtRoads(state);
      districtCityScore = _districtCityScore(districtRoads);
      districtRedRoads = _districtRedRoads(districtRoads);
      districtLiveComplaints = _districtLiveComplaints(districtRoads);
    } else {
      districtRoads = [];
      districtCityScore = 0;
      districtRedRoads = 0;
      districtLiveComplaints = 0;
    }

    return RefreshIndicator(
      onRefresh: state.refreshData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          _HeroBanner(state: state, onSync: state.syncOfflineData),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Live Location',
            child: Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: AppConfig.deepNavy.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    state.isLocationLoading ? Icons.gps_fixed_rounded : Icons.my_location_rounded,
                    color: AppConfig.deepNavy,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.currentPosition == null ? 'Location permission is needed' : 'Live location enabled',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.currentPosition == null
                            ? 'Allow the browser to use your live location so the map can center on you.'
                            : '${state.currentPosition!.latitude.toStringAsFixed(5)}, ${state.currentPosition!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(color: AppConfig.skySlate),
                      ),
                      if (state.locationStatus != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          state.locationStatus!,
                          style: TextStyle(
                            color: state.currentPosition == null ? AppConfig.cautionYellow : AppConfig.safeGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (state.currentPosition != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Accuracy: ${state.currentPosition!.accuracy.toStringAsFixed(1)} m',
                          style: const TextStyle(color: AppConfig.skySlate),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: state.isLocationLoading ? null : () => _onRequestLiveLocation(state),
                  icon: const Icon(Icons.location_searching_rounded),
                  label: Text(state.currentPosition == null ? 'Enable location' : 'Refresh location'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Metric cards (moved above District Road Explorer)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                title: 'City Score',
                value: districtRoads.isEmpty ? '-' : '$districtCityScore',
                subtitle: _selectedDistrict == 'ALL' ? 'All districts' : 'District: $_selectedDistrict',
                icon: Icons.analytics_rounded,
                color: AppConfig.deepNavy,
              ),
              _MetricCard(
                title: 'Red Roads',
                value: '$districtRedRoads',
                subtitle: districtRoads.isEmpty ? 'No district selected' : 'Low health roads',
                icon: Icons.warning_amber_rounded,
                color: AppConfig.dangerRed,
              ),
              _MetricCard(
                title: 'Live Complaints',
                value: '$districtLiveComplaints',
                subtitle: districtRoads.isEmpty ? 'No district selected' : 'Issue reports from road data',
                icon: Icons.report_problem_rounded,
                color: AppConfig.cautionYellow,
              ),
              _MetricCard(
                title: 'Realtime',
                value: state.realtimeStatusLabel,
                subtitle: state.lastRealtimeEvent == null ? 'Waiting for updates' : 'Latest: ${state.lastRealtimeEvent}',
                icon: Icons.wifi_tethering_rounded,
                color: AppConfig.safeGreen,
              ),
              _MetricCard(
                title: 'Live Location',
                value: state.locationStatus ?? 'Waiting for permission',
                subtitle: state.currentPosition == null
                    ? 'Use browser location to place you on the map'
                    : '${state.currentPosition!.latitude.toStringAsFixed(5)}, ${state.currentPosition!.longitude.toStringAsFixed(5)}',
                icon: state.isLocationLoading ? Icons.gps_fixed_rounded : Icons.my_location_rounded,
                color: AppConfig.deepNavy,
              ),
            ],
          ),

          const SizedBox(height: 18),

          if (state.roadNetwork.isNotEmpty)
            _SectionCard(
              title: 'District Road Explorer',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDistrict,
                          decoration: InputDecoration(
                            labelText: 'District',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: districtOptions
                              .map(
                                (district) => DropdownMenuItem<String>(
                                  value: district,
                                  child: Text(district == 'ALL' ? 'All districts' : district),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            final nextRoads = state.searchRoadsForDistrict(value, '');
                            final uniqueNextRoads = <String, RoadNetworkItem>{
                              for (final road in nextRoads)
                                if (_isValidRoadForSelection(road))
                                  _roadUniqueKey(road): road,
                            }.values.toList(growable: false);
                            setState(() {
                              _selectedDistrict = value;
                              _selectedNetworkRoadId = uniqueNextRoads.isEmpty
                                  ? null
                                  : _roadUniqueKey(uniqueNextRoads.first);
                              _manualDistrictSelection =
                                  value != 'ALL' && value != state.liveSuggestedDistrict;
                              _manualRoadSelection = false;
                              _resetRoadRows();
                            });
                            if (uniqueNextRoads.isNotEmpty) {
                              final firstRoad = uniqueNextRoads.first;

                              state.selectRoadNetworkItem(firstRoad);

                              final matchingRoad =
                                  _matchingRoadSegment(state, firstRoad);

                              if (matchingRoad != null) {
                                state.selectRoad(matchingRoad.id);
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: roadDropdownValue,
                          decoration: InputDecoration(
                            labelText: 'Road',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: filteredNetworkRoads
                              .where(_isValidRoadForSelection)
                              .map(
                                (road) => DropdownMenuItem<String>(
                                  value: _roadUniqueKey(road),
                                  child: Text(road.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            final selected = uniqueRoadDropdownItems[value];
                            if (selected != null) {
                              _selectNetworkRoad(state, selected, manual: true);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedDistrict == 'ALL')
                    const Text(
                      'All roads are shown below. Pick a district to narrow the list.',
                      style: TextStyle(color: AppConfig.skySlate),
                    ),
                  const SizedBox(height: 12),
                  if (uniqueFilteredNetworkRoads.isEmpty)
                    const Text(
                      'No roads match your search in this district.',
                      style: TextStyle(color: AppConfig.skySlate),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(builder: (context, constraints) {
                          final spacing = 12.0;
                          final itemWidth = (constraints.maxWidth - spacing) / 2;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: visibleNetworkRoads
                                .map(
                                  (road) => SizedBox(
                                    width: itemWidth,
                                    child: HoverRoadChip(
                                      label: road.name,
                                      selected: roadDropdownValue == _roadUniqueKey(road),
                                      onTap: () => _selectNetworkRoad(state, road, manual: true),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        }),
                        if (canShowMoreRoads)
                          TextButton.icon(
                            onPressed: _showMoreRoadRows,
                            icon: const Icon(Icons.expand_more_rounded),
                            label: Text('Show more roads (${uniqueFilteredNetworkRoads.length - visibleNetworkRoads.length} left)'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          if (displayedSelectedRoad != null)
            _SectionCard(
              key: _scoreSectionKey,
              title: 'Selected Road Score',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayedSelectedRoad.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppConfig.deepNavy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayedSelectedRoad.ward,
                              style: const TextStyle(color: AppConfig.skySlate),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _roadColor(displayedSelectedRoad.color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${displayedSelectedRoad.roadHealthScore}/100',
                          style: TextStyle(
                            color: _roadColor(displayedSelectedRoad.color),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RoadScoreGauge(
                    score: displayedSelectedRoad.roadHealthScore,
                    label: '${displayedSelectedRoad.name} Health Score',
                  ),
                ],
              ),
            )
          else if (selectedNetworkRoad != null)
            _SectionCard(
              key: _scoreSectionKey,
              title: 'Selected Road Score',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedNetworkRoad.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppConfig.deepNavy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selectedNetworkRoad.route,
                              style: const TextStyle(color: AppConfig.skySlate),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _healthColor(selectedNetworkRoad.healthScore).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${selectedNetworkRoad.healthScore}/100',
                          style: TextStyle(
                            color: _healthColor(selectedNetworkRoad.healthScore),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 16,
                      value: selectedNetworkRoad.healthScore / 100,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(_healthColor(selectedNetworkRoad.healthScore)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    selectedNetworkRoad.condition,
                    style: TextStyle(
                      color: _healthColor(selectedNetworkRoad.healthScore),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (displayedSelectedRoad == null && selectedNetworkRoad == null)
            _SectionCard(
              key: _scoreSectionKey,
              title: 'Selected Road Score',
              child: const Text(
                'Choose a road from the dropdown or search to see its score here.',
                style: TextStyle(color: AppConfig.skySlate),
              ),
            ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Live Road Map',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _mapEditingEnabled
                            ? 'Map editing is enabled. You can drag and zoom the map.'
                            : 'Map is locked to your live location. Tap the button to edit the map.',
                        style: const TextStyle(color: AppConfig.skySlate),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _toggleMapEditing,
                      icon: Icon(_mapEditingEnabled ? Icons.lock_open_rounded : Icons.lock_rounded),
                      label: Text(_mapEditingEnabled ? 'Lock map' : 'Open map'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 520,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: state.currentPosition == null
                                ? const LatLng(12.9919, 80.2338)
                                : LatLng(state.currentPosition!.latitude, state.currentPosition!.longitude),
                            initialZoom: state.currentPosition == null ? 12.4 : 15.2,
                            interactionOptions: InteractionOptions(
                              flags: _mapEditingEnabled ? InteractiveFlag.all : InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.roadwatch.ai',
                            ),
                            PolylineLayer(polylines: mapProvider.polylines),
                            MarkerLayer(
                              markers: [
                                ...mapProvider.markers,
                                if (state.currentPosition != null)
                                  _liveLocationMarker(state.currentPosition!),
                              ],
                            ),
                          ],
                        ),
                        if (!_mapEditingEnabled)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 14,
                          bottom: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: AppConfig.deepNavy.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                FilledButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MapFullScreen()));
                                  },
                                  icon: const Icon(Icons.open_in_full, size: 14),
                                  label: const Text('Enter map'),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '© OpenStreetMap contributors',
                                  style: TextStyle(fontSize: 10, color: AppConfig.skySlate),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const RoadHealthLegend(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (state.lastMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: AppConfig.deepNavy.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: AppConfig.safeGreen.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: AppConfig.safeGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.lastMessage!)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onRequestLiveLocation(AppState state) async {
    await state.requestLiveLocation();
    final pos = state.currentPosition;
    if (pos != null) {
      _attemptCenter(LatLng(pos.latitude, pos.longitude), 15.2);
    }
  }

  List<Marker> _markers(List<RoadSegment> roads) {
    return roads
        .where((road) => road.polyline.isNotEmpty)
        .map(
          (road) => Marker(
            point: road.polyline.isEmpty
                ? const LatLng(0, 0)
                : LatLng(road.polyline.first.lat, road.polyline.first.lng),
            width: 36,
            height: 36,
            child: Tooltip(
              message:
                  '${road.name}\nScore ${road.roadHealthScore} | Issues ${road.nearbyIssues} | Complaints ${road.recentComplaints}',
              child: Icon(
                Icons.location_on,
                color: _roadColor(road.color),
                size: 30,
              ),
            ),
          ),
        )
        .toList();
  }

  List<Polyline> _polylines(List<RoadSegment> roads) {
    return roads
        .where((road) => road.polyline.isNotEmpty)
        .map(
          (road) => Polyline(
            points: road.polyline.map((e) => LatLng(e.lat, e.lng)).toList(),
            strokeWidth: 5,
            color: _roadColor(road.color),
          ),
        )
        .toList();
  }

  Marker _liveLocationMarker(Position position) {
    return Marker(
      point: LatLng(position.latitude, position.longitude),
      width: 48,
      height: 48,
      child: Tooltip(
        message: 'Your live location',
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppConfig.deepNavy.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.my_location_rounded, color: AppConfig.safeGreen, size: 28),
        ),
      ),
    );
  }


  @override
  void dispose() {
    super.dispose();
  }
}

class _RoadPicker extends StatelessWidget {
  final List<RoadSegment> roads;
  final String? selectedRoadId;
  final ValueChanged<String> onSelect;

  const _RoadPicker({
    required this.roads,
    required this.selectedRoadId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (roads.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5EF)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedRoadId ?? roads.first.id,
          isExpanded: true,
          items: roads
              .map(
                (road) => DropdownMenuItem<String>(
                  value: road.id,
                  child: Text('${road.name} (${road.ward})'),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onSelect(value);
            }
          },
        ),
      ),
    );
  }
}

class _ChennaiRoadHealthList extends StatelessWidget {
  final List<RoadNetworkItem> roads;

  const _ChennaiRoadHealthList({required this.roads});

  @override
  Widget build(BuildContext context) {
    final chennaiRoads = roads.where((item) => item.isChennaiRoad).toList();

    if (chennaiRoads.isEmpty) {
      return const Text(
        'No Chennai roads are available yet.',
        style: TextStyle(color: AppConfig.skySlate),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1100
            ? 2
            : constraints.maxWidth > 700
                ? 2
                : 1;
        final spacing = 12.0;
        final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: chennaiRoads
              .map(
                (road) => SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                road.name,
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _healthColor(road.healthScore).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${road.healthScore}/100',
                                style: TextStyle(
                                  color: _healthColor(road.healthScore),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          road.route,
                          style: const TextStyle(color: AppConfig.skySlate, height: 1.35),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _tag('Condition: ${road.condition}', _healthColor(road.healthScore)),
                            _tag('Type: ${road.type}', AppConfig.deepNavy),
                            _tag(road.healthLabel, _healthColor(road.healthScore)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          road.issues.join(' • '),
                          style: const TextStyle(fontSize: 12, color: AppConfig.skySlate),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  Color _healthColor(int score) {
    if (score >= 80) {
      return AppConfig.safeGreen;
    }
    if (score >= 60) {
      return AppConfig.cautionYellow;
    }
    return AppConfig.dangerRed;
  }
}

class _ChennaiRoadSnapshot extends StatelessWidget {
  final List<RoadNetworkItem> roads;

  const _ChennaiRoadSnapshot({required this.roads});

  @override
  Widget build(BuildContext context) {
    final chennaiRoads = roads.where((item) => item.isChennaiRoad).toList();
    final healthy = chennaiRoads.where((item) => item.healthScore >= 80).length;
    final watch = chennaiRoads.where((item) => item.healthScore >= 60 && item.healthScore < 80).length;
    final critical = chennaiRoads.where((item) => item.healthScore < 60).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${chennaiRoads.length} Chennai-linked roads loaded from the imported network.',
          style: const TextStyle(color: AppConfig.skySlate),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _miniStat('Healthy', healthy, AppConfig.safeGreen),
            _miniStat('Watch', watch, AppConfig.cautionYellow),
            _miniStat('Critical', critical, AppConfig.dangerRed),
          ],
        ),
        const SizedBox(height: 12),
        ...chennaiRoads.take(3).map(
              (road) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              road.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              road.route,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppConfig.skySlate),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _healthColor(road.healthScore).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${road.healthScore}/100',
                          style: TextStyle(
                            color: _healthColor(road.healthScore),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _healthColor(int score) {
    if (score >= 80) {
      return AppConfig.safeGreen;
    }
    if (score >= 60) {
      return AppConfig.cautionYellow;
    }
    return AppConfig.dangerRed;
  }
}

class _OverviewChips extends StatelessWidget {
  final Map<String, dynamic> overview;

  const _OverviewChips({required this.overview});

  @override
  Widget build(BuildContext context) {
    final overall = overview['overall_score'] ?? '-';
    final red = overview['red_roads'] ?? 0;
    final yellow = overview['yellow_roads'] ?? 0;
    final green = overview['green_roads'] ?? 0;

    return Row(
      children: [
        _statCard('City Score', '$overall', AppConfig.deepNavy),
        const SizedBox(width: 8),
        _statCard('Red', '$red', AppConfig.dangerRed),
        const SizedBox(width: 8),
        _statCard('Yellow', '$yellow', AppConfig.cautionYellow),
        const SizedBox(width: 8),
        _statCard('Green', '$green', AppConfig.safeGreen),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 18)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final AppState state;
  final Future<void> Function() onSync;

  const _HeroBanner({required this.state, required this.onSync});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A43), Color(0xFF1D4E89), Color(0xFF2B6CB0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppConfig.deepNavy.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -8,
            child: Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.traffic_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RoadWatch AI',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Professional civic dashboard for real-time road intelligence',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.82), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: onSync,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Sync now'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroPill(label: state.realtimeStatusLabel, icon: Icons.wifi_tethering_rounded),
                  _HeroPill(label: state.isOnline ? 'Online' : 'Offline', icon: Icons.cloud_done_rounded),
                  _HeroPill(
                    label: state.lastUpdatedAt == null ? 'Waiting for first refresh' : 'Updated ${DateFormat.Hm().format(state.lastUpdatedAt!.toLocal())}',
                    icon: Icons.schedule_rounded,
                  ),
                  if (state.lastRealtimeEvent != null)
                    _HeroPill(
                      label: 'Event: ${state.lastRealtimeEvent}',
                      icon: Icons.bolt_rounded,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _HeroPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(color: AppConfig.skySlate.withValues(alpha: 0.75), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppConfig.skySlate)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({Key? key, required this.title, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppConfig.deepNavy.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConfig.deepNavy)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

