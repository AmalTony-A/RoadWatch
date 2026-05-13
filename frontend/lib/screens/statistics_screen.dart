import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final roads = appState.roadNetwork;
    final theme = Theme.of(context);

    // Calculate statistics
    final goodRoads = roads.where((r) => r.condition == 'Good').length;
    final moderateRoads = roads.where((r) => r.condition == 'Moderate').length;
    final poorRoads = roads.where((r) => r.condition == 'Poor').length;

    final nhRoads = roads.where((r) => r.type == 'NH').length;
    final shRoads = roads.where((r) => r.type == 'SH').length;
    final mdrRoads = roads.where((r) => r.type == 'MDR').length;

    final totalBudget = roads.fold<int>(0, (sum, road) => sum + road.budgetCrore);
    final totalKm = roads.fold<int>(0, (sum, road) => sum + road.lengthKm);
    final avgScore = roads.isEmpty ? 0 : roads.fold<int>(0, (sum, road) => sum + road.healthScore) ~/ roads.length;

    final nhBudget = roads.where((r) => r.type == 'NH').fold<int>(0, (sum, road) => sum + road.budgetCrore);
    final shBudget = roads.where((r) => r.type == 'SH').fold<int>(0, (sum, road) => sum + road.budgetCrore);
    final mdrBudget = roads.where((r) => r.type == 'MDR').fold<int>(0, (sum, road) => sum + road.budgetCrore);

    // District breakdown
    final districtStats = <String, Map<String, int>>{};
    for (final road in roads) {
      for (final district in road.districts) {
        if (!districtStats.containsKey(district)) {
          districtStats[district] = {'count': 0, 'budget': 0, 'good': 0, 'moderate': 0, 'poor': 0};
        }
        districtStats[district]!['count'] = districtStats[district]!['count']! + 1;
        districtStats[district]!['budget'] = districtStats[district]!['budget']! + road.budgetCrore;
        if (road.condition == 'Good') {
          districtStats[district]!['good'] = districtStats[district]!['good']! + 1;
        } else if (road.condition == 'Moderate') {
          districtStats[district]!['moderate'] = districtStats[district]!['moderate']! + 1;
        } else {
          districtStats[district]!['poor'] = districtStats[district]!['poor']! + 1;
        }
      }
    }

    final topDistricts = districtStats.entries.toList()
      ..sort((a, b) => (b.value['budget'] as int).compareTo(a.value['budget'] as int));

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics & Analytics')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          // Hero Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF102A43), Color(0xFF1D4E89), Color(0xFF2B6CB0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tamil Nadu Road Network',
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Comprehensive analytics and metrics across all districts',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Key Metrics
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard('Total Roads', '${roads.length}', Icons.route_rounded, AppConfig.deepNavy),
              _MetricCard('Total km', '$totalKm', Icons.straighten_rounded, AppConfig.safeGreen),
              _MetricCard('Avg Health', '$avgScore/100', Icons.favorite_rounded, AppConfig.cautionYellow),
              _MetricCard('Budget', '\u20B9${(totalBudget / 100).toStringAsFixed(0)}Cr', Icons.attach_money_rounded, AppConfig.dangerRed),
            ],
          ),
          const SizedBox(height: 20),

          // Road Condition Breakdown
          _SectionCard(
            title: 'Road Condition Distribution',
            child: Column(
              children: [
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: goodRoads.toDouble(),
                          color: AppConfig.safeGreen,
                          title: '$goodRoads\nGood',
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          radius: 60,
                        ),
                        PieChartSectionData(
                          value: moderateRoads.toDouble(),
                          color: AppConfig.cautionYellow,
                          title: '$moderateRoads\nModerate',
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          radius: 60,
                        ),
                        PieChartSectionData(
                          value: poorRoads.toDouble(),
                          color: AppConfig.dangerRed,
                          title: '$poorRoads\nPoor',
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          radius: 60,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _LegendItem('Good', AppConfig.safeGreen),
                    _LegendItem('Moderate', AppConfig.cautionYellow),
                    _LegendItem('Poor', AppConfig.dangerRed),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Road Type Distribution
          _SectionCard(
            title: 'Road Type Breakdown',
            child: Column(
              children: [
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: nhRoads.toDouble(),
                          color: const Color(0xFF3B82F6),
                          title: '$nhRoads\nNH',
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          radius: 60,
                        ),
                        PieChartSectionData(
                          value: shRoads.toDouble(),
                          color: const Color(0xFFA855F7),
                          title: '$shRoads\nSH',
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          radius: 60,
                        ),
                        PieChartSectionData(
                          value: mdrRoads.toDouble(),
                          color: const Color(0xFF06B6D4),
                          title: '$mdrRoads\nMDR',
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          radius: 60,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _LegendItem('National Hwy', Color(0xFF3B82F6)),
                    _LegendItem('State Hwy', Color(0xFFA855F7)),
                    _LegendItem('District Road', Color(0xFF06B6D4)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Budget Distribution by Type
          _SectionCard(
            title: 'Budget Allocation by Road Type',
            child: Column(
              children: [
                _BudgetBar('National Highways (NH)', nhBudget, totalBudget, const Color(0xFF3B82F6)),
                const SizedBox(height: 12),
                _BudgetBar('State Highways (SH)', shBudget, totalBudget, const Color(0xFFA855F7)),
                const SizedBox(height: 12),
                _BudgetBar('District Roads (MDR)', mdrBudget, totalBudget, const Color(0xFF06B6D4)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Total Budget', style: TextStyle(color: AppConfig.skySlate, fontSize: 11)),
                          Text('\u20B9${(totalBudget / 100).toStringAsFixed(1)}Cr', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Budget/km', style: TextStyle(color: AppConfig.skySlate, fontSize: 11)),
                          Text('\u20B9${((totalBudget * 10000000) / totalKm).toStringAsFixed(0)}/km', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Top Districts by Budget
          _SectionCard(
            title: 'Top 10 Districts by Budget Allocation',
            child: Column(
              children: topDistricts.take(10).map((entry) {
                final district = entry.key;
                final stats = entry.value;
                final pct = (stats['budget'] as int) / totalBudget;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(district, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Text('${(pct * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w700, color: AppConfig.deepNavy)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: pct,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            pct > 0.15 ? AppConfig.dangerRed : pct > 0.08 ? AppConfig.cautionYellow : AppConfig.safeGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\u20B9${((stats['budget'] as int) / 100).toStringAsFixed(1)}Cr | ${stats['count']} roads',
                        style: const TextStyle(fontSize: 11, color: AppConfig.skySlate),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: theme.cardTheme.shadowColor ?? Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w600)),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.cardTheme.shadowColor ?? Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _BudgetBar extends StatelessWidget {
  final String label;
  final int budget;
  final int total;
  final Color color;

  const _BudgetBar(this.label, this.budget, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = budget / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
            Text('\u20B9${(budget / 100).toStringAsFixed(1)}Cr', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 12,
            value: pct,
            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
