import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/road_network_item.dart';
import '../providers/app_state.dart';

class TransparencyScreen extends StatefulWidget {
  const TransparencyScreen({super.key});

  @override
  State<TransparencyScreen> createState() => _TransparencyScreenState();
}

class _TransparencyScreenState extends State<TransparencyScreen> {
  static const int _roadRowsStep = 4;
  final GlobalKey _scoreSectionKey = GlobalKey();
  String _selectedDistrict = 'ALL';
  String _roadSearchQuery = '';
  String? _selectedRoadId;
  bool _showDetails = false;
  int _visibleRoadRows = _roadRowsStep;

  void _resetRoadRows() {
    _visibleRoadRows = _roadRowsStep;
  }

  void _showMoreRoadRows() {
    setState(() {
      _visibleRoadRows += _roadRowsStep;
    });
  }

  String _roadUniqueKey(RoadNetworkItem road) {
    final id = road.id.trim();
    if (id.isNotEmpty) {
      return id + '_' + road.name.trim();
    }
    return '${road.name.trim()}_${road.route.trim()}_${road.districts.join('|')}';
  }

  List<RoadNetworkItem> _uniqueRoadsById(Iterable<RoadNetworkItem> roads) {
    final seenKeys = <String>{};
    final uniqueRoads = <RoadNetworkItem>[];

    for (final road in roads) {
      final key = _roadUniqueKey(road);
      if (seenKeys.add(key)) {
        uniqueRoads.add(road);
      }
    }

    return uniqueRoads;
  }

  void _autoSelectDistrict(AppState appState) {
    final suggestedDistrict = appState.liveSuggestedDistrict;
    if (suggestedDistrict == null || _selectedDistrict != 'ALL') {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedDistrict != 'ALL') {
        return;
      }
      final suggestedRoads = appState.roadsForDistrict(suggestedDistrict);
      setState(() {
        _selectedDistrict = suggestedDistrict;
        _roadSearchQuery = '';
        _selectedRoadId = suggestedRoads.isNotEmpty ? _roadUniqueKey(suggestedRoads.first) : null;
        _showDetails = suggestedRoads.isNotEmpty;
        _resetRoadRows();
      });
      if (suggestedRoads.isNotEmpty) {
        appState.selectRoadNetworkItem(suggestedRoads.first);
      }
    });
  }

  RoadNetworkItem? _selectedRoad(List<RoadNetworkItem> roads) {
    if (_selectedRoadId == null) {
      return null;
    }
    for (final road in roads) {
      if (_roadUniqueKey(road) == _selectedRoadId) {
        return road;
      }
    }
    return null;
  }

  void _pickRoad(AppState appState, RoadNetworkItem road, {required bool showDetails}) {
    setState(() {
      _selectedRoadId = _roadUniqueKey(road);
      _showDetails = showDetails;
    });
    appState.selectRoadNetworkItem(road);
    // Scroll the detail card into view for the selected road
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _scoreSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 360), curve: Curves.easeInOut);
      }
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    _autoSelectDistrict(appState);

    final districtOptions = ['ALL', ...appState.roadNetworkDistricts];
    final filteredRoads = _uniqueRoadsById(appState.searchRoadsForDistrict(_selectedDistrict, _roadSearchQuery));
    final visibleRoads = _selectedDistrict == 'ALL'
      ? filteredRoads.take(_visibleRoadRows).toList(growable: false)
      : filteredRoads;
    final canShowMoreRoads =
      _selectedDistrict == 'ALL' && filteredRoads.length > visibleRoads.length;
    final selectedRoad = _selectedRoad(filteredRoads);
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: 'INR ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Public Spending Transparency')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF102A43), Color(0xFF1D4E89), Color(0xFF2B6CB0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppConfig.deepNavy.withValues(alpha: 0.16),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Public Spending Transparency',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a district first, then choose a road. Tap a road card to open the complete road details.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'District Road Explorer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedDistrict,
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
                          final nextRoads = appState.roadsForDistrict(value);
                          setState(() {
                            _selectedDistrict = value;
                            _roadSearchQuery = '';
                            _selectedRoadId = nextRoads.isNotEmpty ? nextRoads.first.id : null;
                            _showDetails = nextRoads.isNotEmpty;
                            _resetRoadRows();
                          });
                          if (nextRoads.isNotEmpty) {
                            appState.selectRoadNetworkItem(nextRoads.first);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _roadSearchQuery = value;
                            _showDetails = false;
                            _selectedRoadId = null;
                            _resetRoadRows();
                          });
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          labelText: 'Search road name',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (appState.liveSuggestedDistrict != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConfig.safeGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppConfig.safeGreen.withValues(alpha: 0.18)),
                    ),
                    child: Text(
                      'Live location suggests ${appState.liveSuggestedDistrict}. The road list is filtered automatically.',
                      style: const TextStyle(color: AppConfig.deepNavy, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_selectedDistrict == 'ALL')
                  const Text(
                    'All roads are shown below. Pick a district to narrow the list.',
                    style: TextStyle(color: AppConfig.skySlate),
                  ),
                const SizedBox(height: 12),
                if (filteredRoads.isEmpty)
                  const Text(
                    'No roads match your search in this district.',
                    style: TextStyle(color: AppConfig.skySlate),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedRoad == null ? null : _roadUniqueKey(selectedRoad),
                    decoration: InputDecoration(
                      labelText: _selectedDistrict == 'ALL' ? 'All roads' : 'Roads in $_selectedDistrict',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: filteredRoads
                        .map(
                          (road) => DropdownMenuItem<String>(
                            value: _roadUniqueKey(road),
                            child: Text(road.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final road = filteredRoads.firstWhere((r) => _roadUniqueKey(r) == value);
                        _pickRoad(appState, road, showDetails: true);
                      }
                    },
                  ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...visibleRoads.map(
                      (road) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => _pickRoad(appState, road, showDetails: true),
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            child: Text(
                              road.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (canShowMoreRoads)
                      TextButton.icon(
                        onPressed: _showMoreRoadRows,
                        icon: const Icon(Icons.expand_more_rounded),
                        label: Text('Show more roads (${filteredRoads.length - visibleRoads.length} left)'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_showDetails && selectedRoad != null)
            Container(key: _scoreSectionKey, child: _RoadDetailCard(road: selectedRoad, formatter: formatter, healthColor: _healthColor)),
          if (!_showDetails)
            const Text(
              'Tap a road card below to open the complete road details.',
              style: TextStyle(color: AppConfig.skySlate),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(label: 'Roads', value: '${appState.roadNetwork.length}', icon: Icons.route_rounded, color: AppConfig.deepNavy),
              _StatCard(label: 'Districts', value: '${appState.roadNetworkDistricts.length}', icon: Icons.location_city_rounded, color: AppConfig.safeGreen),
              _StatCard(label: 'Live district', value: appState.liveSuggestedDistrict ?? '-', icon: Icons.my_location_rounded, color: AppConfig.cautionYellow),
            ],
          ),
          if (filteredRoads.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 1200
                    ? 3
                    : constraints.maxWidth > 760
                        ? 2
                        : 1;
                final spacing = 12.0;
                final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: visibleRoads
                      .map(
                        (road) => SizedBox(
                          width: cardWidth,
                          child: _RoadNetworkCard(
                            road: road,
                            isActive: _selectedRoadId == road.id,
                            onTap: () => _pickRoad(appState, road, showDetails: true),
                            healthColor: _healthColor,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          if (canShowMoreRoads)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _showMoreRoadRows,
                icon: const Icon(Icons.expand_more_rounded),
                label: Text('Show more roads (${filteredRoads.length - visibleRoads.length} left)'),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoadDetailCard extends StatelessWidget {
  final RoadNetworkItem road;
  final NumberFormat formatter;
  final Color Function(int score) healthColor;

  const _RoadDetailCard({required this.road, required this.formatter, required this.healthColor});

  @override
  Widget build(BuildContext context) {
    final score = road.healthScore;
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      road.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
                    ),
                    const SizedBox(height: 4),
                    Text(road.route, style: const TextStyle(color: AppConfig.skySlate)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: healthColor(score).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$score/100',
                  style: TextStyle(color: healthColor(score), fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 14,
              value: score / 100,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(healthColor(score)),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag('Type: ${road.type}', AppConfig.deepNavy),
              _tag('Condition: ${road.condition}', healthColor(score)),
              _tag('Year: ${road.year}', AppConfig.skySlate),
              _tag('Length: ${road.lengthKm} km', AppConfig.skySlate),
            ],
          ),
          const SizedBox(height: 14),
          Text('Districts: ${road.districts.join(', ')}'),
          Text('Contractor: ${road.contractor}'),
          Text('Budget: ${formatter.format(road.budgetCrore * 10000000)}'),
          const SizedBox(height: 8),
          Text('Issues: ${road.issues.join(' • ')}', style: const TextStyle(color: AppConfig.skySlate)),
          const SizedBox(height: 8),
          Text(road.summary, style: const TextStyle(color: AppConfig.skySlate, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

class _RoadNetworkCard extends StatefulWidget {
  final RoadNetworkItem road;
  final bool isActive;
  final VoidCallback onTap;
  final Color Function(int score) healthColor;

  const _RoadNetworkCard({required this.road, required this.isActive, required this.onTap, required this.healthColor});

  @override
  State<_RoadNetworkCard> createState() => _RoadNetworkCardState();
}

class _RoadNetworkCardState extends State<_RoadNetworkCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.road.healthScore;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
    final budgetPerKm = widget.road.lengthKm > 0 ? (widget.road.budgetCrore * 10000000 / widget.road.lengthKm).toInt() : 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _toggleExpand,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.isActive || _expanded ? widget.healthColor(score).withValues(alpha: 0.35) : const Color(0xFFE5ECF5), width: widget.isActive || _expanded ? 1.5 : 1),
            boxShadow: [
              BoxShadow(
                color: AppConfig.deepNavy.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
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
                          widget.road.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.road.route,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppConfig.skySlate),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.healthColor(score).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$score/100',
                          style: TextStyle(color: widget.healthColor(score), fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 6),
                      RotationTransition(
                        turns: Tween(begin: 0.0, end: 0.5).animate(_animationController),
                        child: const Icon(Icons.expand_more_rounded, size: 20, color: AppConfig.skySlate),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Districts: ${widget.road.districts.join(', ')}', style: const TextStyle(color: AppConfig.skySlate)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                minHeight: 10,
                value: score / 100,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(widget.healthColor(score)),
              ),
              if (_expanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _InfoColumn('Length', '${widget.road.lengthKm} km'),
                    _InfoColumn('Year', '${widget.road.year}'),
                    _InfoColumn('Type', widget.road.type),
                    _InfoColumn('Condition', widget.road.condition),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailRow('Contractor:', widget.road.contractor),
                const SizedBox(height: 8),
                _DetailRow('Budget:', formatter.format(widget.road.budgetCrore * 10000000)),
                const SizedBox(height: 8),
                _DetailRow('Budget/km:', formatter.format(budgetPerKm)),
                const SizedBox(height: 12),
                const Text('Issues:', style: TextStyle(fontWeight: FontWeight.w700, color: AppConfig.deepNavy)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.road.issues
                      .map(
                        (issue) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: widget.healthColor(score).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(issue, style: TextStyle(color: widget.healthColor(score), fontWeight: FontWeight.w600, fontSize: 11)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5ECF5)),
                  ),
                  child: Text(
                    widget.road.summary,
                    style: const TextStyle(color: AppConfig.skySlate, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;

  const _InfoColumn(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: AppConfig.skySlate, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppConfig.deepNavy, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: AppConfig.skySlate, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(color: AppConfig.deepNavy, fontWeight: FontWeight.w700))),
      ],
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppConfig.deepNavy)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: AppConfig.skySlate.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
