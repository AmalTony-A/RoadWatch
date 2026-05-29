import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/road_network_item.dart';
import '../providers/app_state.dart';

class RoadNetworkBrowser extends StatefulWidget {
  const RoadNetworkBrowser({super.key});

  @override
  State<RoadNetworkBrowser> createState() => _RoadNetworkBrowserState();
}

class _RoadNetworkBrowserState extends State<RoadNetworkBrowser> {
  String _query = '';
  String _debouncedQuery = '';
  Timer? _debounce;
  String _selectedType = 'ALL';
  String _selectedCondition = 'ALL';
  int _visibleRoadCount = 10;

  @override
  Widget build(BuildContext context) {
    final roads = context.watch<AppState>().roadNetwork;
    // Use debounced query to avoid rebuilding on every keystroke
    final filtered = roads.where((r) => _matchesFiltersWithQuery(r, _debouncedQuery)).toList();
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: 'INR ', decimalDigits: 0);
    final totalKm = roads.fold<int>(0, (sum, item) => sum + item.lengthKm);
    final nhCount = roads.where((item) => item.isNationalHighway).length;
    final shCount = roads.where((item) => item.isStateHighway).length;
    final mdrCount = roads.where((item) => item.isDistrictRoad).length;

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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF102A43), Color(0xFF1D4E89)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.route_rounded, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tamil Nadu Road Network',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Browse the imported NH, SH, and MDR dataset with search, filters, and readable summaries.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.82), height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(label: 'Roads', value: '${roads.length}', icon: Icons.route_rounded, color: AppConfig.deepNavy),
              _StatCard(label: 'NH', value: '$nhCount', icon: Icons.local_shipping_rounded, color: AppConfig.deepNavy),
              _StatCard(label: 'SH', value: '$shCount', icon: Icons.alt_route_rounded, color: AppConfig.safeGreen),
              _StatCard(label: 'MDR', value: '$mdrCount', icon: Icons.map_rounded, color: AppConfig.cautionYellow),
              _StatCard(label: 'Total km', value: '$totalKm', icon: Icons.straight_rounded, color: AppConfig.dangerRed),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5ECF5)),
            ),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => _onQueryChanged(value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Search by road, district, route, contractor, or issue',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FilterRow(
                  title: 'Type',
                  options: const ['ALL', 'NH', 'SH', 'MDR'],
                  selected: _selectedType,
                  onChanged: (value) => setState(() => _selectedType = value),
                ),
                const SizedBox(height: 10),
                _FilterRow(
                  title: 'Condition',
                  options: const ['ALL', 'Good', 'Moderate', 'Poor'],
                  selected: _selectedCondition,
                  onChanged: (value) => setState(() => _selectedCondition = value),
                ),
                if (_query.isNotEmpty || _selectedType != 'ALL' || _selectedCondition != 'ALL') ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        _debounce?.cancel();
                        setState(() {
                          _query = '';
                          _debouncedQuery = '';
                          _selectedType = 'ALL';
                          _selectedCondition = 'ALL';
                          _visibleRoadCount = 10;
                        });
                      },
                      icon: const Icon(Icons.clear_all_rounded),
                      label: const Text('Clear filters'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5ECF5)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 44, color: AppConfig.skySlate),
                  SizedBox(height: 10),
                  Text(
                    'No roads match your search.',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppConfig.deepNavy),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Try another road name, district, or reset the filters.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppConfig.skySlate),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 1280
                    ? 3
                    : constraints.maxWidth > 860
                        ? 2
                        : 1;
                final spacing = 12.0;
                final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                final itemCount = filtered.length > _visibleRoadCount ? _visibleRoadCount : filtered.length;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: cardWidth / 160,
                  ),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _RoadCard(
                      item: item,
                      formatter: formatter,
                      onTap: () => _showRoadDetail(context, item.id),
                    );
                  },
                );
              },
            ),
          if (filtered.length > _visibleRoadCount)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _visibleRoadCount += 10;
                    });
                  },
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('Show More'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showRoadDetail(BuildContext context, String itemId) async {
    final api = context.read<AppState>().api;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: 'INR ', decimalDigits: 0);

    if (!context.mounted) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: FutureBuilder<RoadNetworkItem>(
                future: api.getRoadNetworkItem(itemId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: AppConfig.dangerRed),
                          const SizedBox(height: 12),
                          const Text(
                            'Could not load road details.',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error?.toString() ?? 'Unknown error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppConfig.skySlate),
                          ),
                        ],
                      ),
                    );
                  }

                  final item = snapshot.data!;
                  final typeColor = switch (item.type) {
                    'NH' => const Color(0xFF1D4ED8),
                    'SH' => const Color(0xFF7C3AED),
                    _ => const Color(0xFF0891B2),
                  };
                  final conditionColor = switch (item.condition) {
                    'Good' => AppConfig.safeGreen,
                    'Poor' => AppConfig.dangerRed,
                    _ => AppConfig.cautionYellow,
                  };

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF102A43), Color(0xFF1D4E89)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 52,
                              width: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.route_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.route,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.82), height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _Pill(text: item.type, color: typeColor),
                          _Pill(text: item.condition, color: conditionColor),
                          _Pill(text: '${item.lengthKm} km', color: AppConfig.deepNavy),
                          _Pill(text: '${item.year}', color: AppConfig.skySlate),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DetailBlock(
                        title: 'Districts',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: item.districts
                              .map(
                                (district) => Chip(
                                  label: Text(district),
                                  backgroundColor: const Color(0xFFF5F7FA),
                                  side: BorderSide.none,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DetailBlock(
                        title: 'Contractor and Budget',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoRow(label: 'Contractor', value: item.contractor),
                            const SizedBox(height: 8),
                            _InfoRow(label: 'Budget', value: formatter.format(item.budgetCrore * 10000000)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DetailBlock(
                        title: 'Issues',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: item.issues
                              .map(
                                (issue) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(issue, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Close'),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  bool _matchesFiltersWithQuery(RoadNetworkItem item, String query) {
    final q = query.trim().toLowerCase();
    final matchesQuery = q.isEmpty ||
        item.name.toLowerCase().contains(q) ||
        item.route.toLowerCase().contains(q) ||
        item.contractor.toLowerCase().contains(q) ||
        item.condition.toLowerCase().contains(q) ||
        item.districts.any((district) => district.toLowerCase().contains(q)) ||
        item.issues.any((issue) => issue.toLowerCase().contains(q));

    final matchesType = _selectedType == 'ALL' || item.type == _selectedType;
    final matchesCondition = _selectedCondition == 'ALL' || item.condition == _selectedCondition;
    return matchesQuery && matchesType && matchesCondition;
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _debouncedQuery = _query;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
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

class _FilterRow extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _FilterRow({required this.title, required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppConfig.deepNavy),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (option) => ChoiceChip(
                    label: Text(option),
                    selected: selected == option,
                    onSelected: (_) => onChanged(option),
                    selectedColor: AppConfig.deepNavy.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: selected == option ? AppConfig.deepNavy : AppConfig.skySlate,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _RoadCard extends StatelessWidget {
  final RoadNetworkItem item;
  final NumberFormat formatter;
  final VoidCallback onTap;

  const _RoadCard({required this.item, required this.formatter, required this.onTap});

  Color _typeColor() {
    switch (item.type) {
      case 'NH':
        return const Color(0xFF1D4ED8);
      case 'SH':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF0891B2);
    }
  }

  Color _conditionColor() {
    switch (item.condition) {
      case 'Good':
        return AppConfig.safeGreen;
      case 'Poor':
        return AppConfig.dangerRed;
      default:
        return AppConfig.cautionYellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5ECF5)),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConfig.deepNavy),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.summary,
                      style: const TextStyle(color: AppConfig.skySlate, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _typeColor().withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.type,
                  style: TextStyle(color: _typeColor(), fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.route,
            style: const TextStyle(height: 1.45, color: AppConfig.deepNavy),
          ),
          const SizedBox(height: 12),
          const Text(
            'Districts',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: AppConfig.skySlate),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: item.districts
                .map(
                  (district) => Chip(
                    label: Text(district),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    backgroundColor: const Color(0xFFF5F7FA),
                    side: BorderSide.none,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MetaItem(label: 'Length', value: '${item.lengthKm} km')),
              Expanded(child: _MetaItem(label: 'Year', value: '${item.year}')),
              Expanded(child: _MetaItem(label: 'Budget', value: formatter.format(item.budgetCrore * 10000000))),
            ],
          ),
          const SizedBox(height: 10),
          _MetaItem(label: 'Contractor', value: item.contractor),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _conditionColor().withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.condition,
                  style: TextStyle(
                    color: _conditionColor(),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.issues.join(' • '),
                  style: const TextStyle(fontSize: 11.5, color: AppConfig.skySlate),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailBlock({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5ECF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppConfig.deepNavy)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppConfig.skySlate),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppConfig.deepNavy),
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  final String label;
  final String value;

  const _MetaItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppConfig.skySlate,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppConfig.deepNavy),
          ),
        ],
      ),
    );
  }
}
