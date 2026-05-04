import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/road_segment.dart';
import '../models/road_network_item.dart';
import '../providers/app_state.dart';
import '../widgets/road_health_legend.dart';
import '../widgets/road_score_gauge.dart';
import 'transparency_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  bool _centeredOnLiveLocation = false;
  bool _mapEditingEnabled = false;
  String _selectedDistrict = 'ALL';
  String _roadSearchQuery = '';

  Color _roadColor(String color) {
    return AppConfig.healthColorFromText(color);
  }

  void _maybeCenterMap(AppState state) {
    final position = state.currentPosition;
    if (position == null || _centeredOnLiveLocation) {
      return;
    }

    _centeredOnLiveLocation = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _mapController.move(LatLng(position.latitude, position.longitude), 15.2);
    });
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selectedRoad = state.selectedRoad;
    final selectedNetworkRoad = state.selectedRoadNetwork;
    final theme = Theme.of(context);
    _maybeCenterMap(state);

    final districtOptions = ['ALL', ...state.roadNetworkDistricts];
    final filteredNetworkRoads = state.searchRoadsForDistrict(_selectedDistrict, _roadSearchQuery);
    final districtRoads = _districtRoads(state);
    final districtCityScore = _districtCityScore(districtRoads);
    final districtRedRoads = _districtRedRoads(districtRoads);
    final districtLiveComplaints = _districtLiveComplaints(districtRoads);

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
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: state.isLocationLoading ? null : state.requestLiveLocation,
                  icon: const Icon(Icons.location_searching_rounded),
                  label: Text(state.currentPosition == null ? 'Enable location' : 'Refresh location'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
                value: '${districtRedRoads}',
                subtitle: districtRoads.isEmpty ? 'No district selected' : 'Low health roads',
                icon: Icons.warning_amber_rounded,
                color: AppConfig.dangerRed,
              ),
              _MetricCard(
                title: 'Live Complaints',
                value: '${districtLiveComplaints}',
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
                            setState(() {
                              _selectedDistrict = value;
                              _roadSearchQuery = '';
                            });
                            if (nextRoads.isNotEmpty) {
                              state.selectRoadNetworkItem(nextRoads.first);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Search road name',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _roadSearchQuery = value;
                            });
                            final matches = state.searchRoadsForDistrict(_selectedDistrict, value);
                            if (matches.length == 1 || value.trim().length >= 3 && matches.isNotEmpty) {
                              state.selectRoadNetworkItem(matches.first);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (state.liveSuggestedDistrict != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConfig.safeGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppConfig.safeGreen.withValues(alpha: 0.18)),
                      ),
                      child: Text(
                        'Nearby roads detected from live location: ${state.liveSuggestedDistrict}. Pick it from the district dropdown to filter the road list.',
                        style: const TextStyle(color: AppConfig.deepNavy, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (_selectedDistrict == 'ALL')
                    const Text(
                      'Choose a district first to load the roads in that district.',
                      style: TextStyle(color: AppConfig.skySlate),
                    )
                  else ...[
                    DropdownButtonFormField<RoadNetworkItem>(
                      value: selectedNetworkRoad != null && filteredNetworkRoads.any((item) => item.id == selectedNetworkRoad.id)
                          ? selectedNetworkRoad
                          : (filteredNetworkRoads.isNotEmpty ? filteredNetworkRoads.first : null),
                      decoration: InputDecoration(
                        labelText: 'Roads in $_selectedDistrict',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: filteredNetworkRoads
                          .map(
                            (road) => DropdownMenuItem<RoadNetworkItem>(
                              value: road,
                              child: Text(road.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          state.selectRoadNetworkItem(value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (filteredNetworkRoads.isEmpty)
                      const Text(
                        'No roads match your search in this district.',
                        style: TextStyle(color: AppConfig.skySlate),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: filteredNetworkRoads
                            .map(
                              (road) => ActionChip(
                                label: Text(road.name),
                                onPressed: () => state.selectRoadNetworkItem(road),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 12),
                    if (selectedNetworkRoad != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
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
                                    selectedNetworkRoad.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _healthColor(selectedNetworkRoad.healthScore).withValues(alpha: 0.14),
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
                            const SizedBox(height: 8),
                            Text(selectedNetworkRoad.route, style: const TextStyle(color: AppConfig.skySlate)),
                            const SizedBox(height: 8),
                            Text('Districts: ${selectedNetworkRoad.districts.join(', ')}'),
                            Text('Type: ${selectedNetworkRoad.type}'),
                            Text('Condition: ${selectedNetworkRoad.condition}'),
                            Text('Contractor: ${selectedNetworkRoad.contractor}'),
                            Text('Budget: INR ${selectedNetworkRoad.budgetCrore} crore'),
                            const SizedBox(height: 8),
                            Text(selectedNetworkRoad.issues.join(' • '), style: const TextStyle(color: AppConfig.skySlate)),
                          ],
                        ),
                      ),
                    if (selectedNetworkRoad == null)
                      const Text(
                        'Pick a district and road to show that road\'s score and details here.',
                        style: TextStyle(color: AppConfig.skySlate),
                      ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 14),
          if (selectedRoad != null)
            _SectionCard(
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
                              selectedRoad.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppConfig.deepNavy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selectedRoad.ward,
                              style: const TextStyle(color: AppConfig.skySlate),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _roadColor(selectedRoad.color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${selectedRoad.roadHealthScore}/100',
                          style: TextStyle(
                            color: _roadColor(selectedRoad.color),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  RoadScoreGauge(
                    score: selectedRoad.roadHealthScore,
                    label: '${selectedRoad.name} Health Score',
                  ),
                ],
              ),
            )
          else if (selectedNetworkRoad != null)
            _SectionCard(
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
          if (selectedRoad == null && selectedNetworkRoad == null)
            _SectionCard(
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
                  height: 340,
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
                            PolylineLayer(polylines: _polylines(state.roads)),
                            MarkerLayer(
                              markers: [
                                ..._markers(state.roads),
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
                            child: const Text(
                              '© OpenStreetMap contributors',
                              style: TextStyle(fontSize: 10, color: AppConfig.skySlate),
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
          _SectionCard(
            title: 'Transparency Snapshot',
            child: _TransparencyHighlight(selectedRoad: selectedRoad, appState: state),
          ),
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

  List<Marker> _markers(List<RoadSegment> roads) {
    return roads
        .map(
          (road) => Marker(
            point: LatLng(road.polyline.first.lat, road.polyline.first.lng),
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

  const _SectionCard({required this.title, required this.child});

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

class _TransparencyHighlight extends StatelessWidget {
  final RoadSegment? selectedRoad;
  final AppState appState;

  const _TransparencyHighlight({required this.selectedRoad, required this.appState});

  @override
  Widget build(BuildContext context) {
    final matchingBudgets =
        appState.budgets.where((item) => item.roadId == selectedRoad?.id).toList();
    final budget = matchingBudgets.isEmpty ? null : matchingBudgets.first;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: 'INR ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF112D4E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transparency Indicator',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            budget == null
                ? 'No budget data for selected road.'
                : '${formatter.format(budget.allocatedInr)} allocated - current score ${budget.actualScore}/100',
            style: const TextStyle(color: Color(0xFFE1E8F2), fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            budget?.transparencyNote ?? 'Select a road to inspect allocation and outcomes.',
            style: const TextStyle(color: Color(0xFFBCCCDC)),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppConfig.deepNavy,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TransparencyScreen()),
              );
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Full Transparency Module'),
          ),
        ],
      ),
    );
  }
}

