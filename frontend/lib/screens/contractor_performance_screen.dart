import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../config/app_config.dart';
import '../models/road_segment.dart';
import '../providers/app_state.dart';

class ContractorPerformanceScreen extends StatefulWidget {
  const ContractorPerformanceScreen({super.key});

  @override
  State<ContractorPerformanceScreen> createState() => _ContractorPerformanceScreenState();
}

class _ContractorPerformanceScreenState extends State<ContractorPerformanceScreen> {
  String _sortBy = 'Performance Score';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              '⭐ Contractor Performance Dashboard',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppConfig.deepNavy,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rate and track contractor performance metrics',
              style: TextStyle(color: AppConfig.skySlate.withValues(alpha: 0.8), fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Overall Performance Overview
            _buildPerformanceOverview(context),
            const SizedBox(height: 24),

            // Performance Distribution Chart
            _buildPerformanceChart(context),
            const SizedBox(height: 24),

            // Contractor Rankings
            Consumer<AppState>(builder: (context, appState, _) {
              final contractorStats = _calculateContractorStats(appState.roads);
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Contractor Rankings',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppConfig.deepNavy,
                            ),
                      ),
                      DropdownButton<String>(
                        value: _sortBy,
                        onChanged: (String? newValue) {
                          if (newValue != null) setState(() => _sortBy = newValue);
                        },
                        items: const [
                          DropdownMenuItem(value: 'Performance Score', child: Text('Performance Score')),
                          DropdownMenuItem(value: 'Projects Completed', child: Text('Projects Completed')),
                          DropdownMenuItem(value: 'Customer Rating', child: Text('Customer Rating')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...contractorStats.entries.toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final contractor = entry.value.key;
                    final stats = entry.value.value;
                    return _ContractorCard(
                      rank: index + 1,
                      name: contractor,
                      performanceScore: (stats['score'] as num).toDouble(),
                      projectsCompleted: stats['projects'] as int,
                      avgRating: (stats['rating'] as num).toDouble(),
                      onTimeDelivery: stats['onTime'] as double,
                      qualityScore: stats['quality'] as double,
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceOverview(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _PerformanceCard(
            title: 'Average Rating',
            value: '4.2',
            subtitle: 'out of 5.0',
            icon: Icons.star,
            color: AppConfig.cautionYellow,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _PerformanceCard(
            title: 'On-Time Delivery',
            value: '87%',
            subtitle: 'Last 6 months',
            icon: Icons.schedule,
            color: AppConfig.safeGreen,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _PerformanceCard(
            title: 'Quality Score',
            value: '4.1',
            subtitle: 'Average rating',
            icon: Icons.verified_rounded,
            color: AppConfig.deepNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceChart(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Distribution',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppConfig.deepNavy,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: 100,
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                      return Text('${value.toInt()}%', style: const TextStyle(fontSize: 10));
                    }),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const titles = ['Excellent', 'Good', 'Average', 'Below Avg'];
                        return Text(titles[value.toInt()], style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 45, color: AppConfig.safeGreen)]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 35, color: AppConfig.deepNavy)]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 15, color: AppConfig.cautionYellow)]),
                  BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 5, color: Colors.red.withValues(alpha: 0.7))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, Map<String, dynamic>> _calculateContractorStats(List<RoadSegment> roads) {
    final stats = <String, Map<String, dynamic>>{};

    for (final road in roads) {
      final contractor = 'Ward ${road.ward} Contractor';
      if (!stats.containsKey(contractor)) {
        stats[contractor] = {
          'projects': 0,
          'score': 0.0,
          'rating': 0.0,
          'onTime': 0.0,
          'quality': 0.0,
        };
      }

      stats[contractor]!['projects'] = stats[contractor]!['projects']! + 1;
      stats[contractor]!['score'] = (road.roadHealthScore / 20).clamp(3.0, 5.0);
      stats[contractor]!['rating'] = (4.0 - (road.nearbyIssues / 50)).clamp(3.0, 5.0);
      stats[contractor]!['onTime'] = (95.0 - (road.recentComplaints * 2)).clamp(60.0, 98.0);
      stats[contractor]!['quality'] = (4.5 - (road.nearbyIssues / 60)).clamp(3.5, 5.0);
    }

    // Sort by score
    final sortedStats = stats.entries.toList()
      ..sort((a, b) => (b.value['score'] as num).compareTo(a.value['score'] as num));

    return Map.fromEntries(sortedStats.take(10));
  }
}

class _PerformanceCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _PerformanceCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppConfig.deepNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: AppConfig.skySlate.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractorCard extends StatefulWidget {
  final int rank;
  final String name;
  final double performanceScore;
  final int projectsCompleted;
  final double avgRating;
  final double onTimeDelivery;
  final double qualityScore;

  const _ContractorCard({
    required this.rank,
    required this.name,
    required this.performanceScore,
    required this.projectsCompleted,
    required this.avgRating,
    required this.onTimeDelivery,
    required this.qualityScore,
  });

  @override
  State<_ContractorCard> createState() => _ContractorCardState();
}

class _ContractorCardState extends State<_ContractorCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.rank == 1
                        ? Colors.amber[200]
                        : widget.rank == 2
                            ? Colors.grey[300]
                            : widget.rank == 3
                                ? Colors.orange[200]
                                : AppConfig.deepNavy.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#${widget.rank}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: widget.rank <= 3 ? Colors.black : AppConfig.deepNavy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _RatingBadge('Score', widget.performanceScore, AppConfig.deepNavy),
                          const SizedBox(width: 8),
                          _RatingBadge('Rating', widget.avgRating, AppConfig.cautionYellow),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _MetricRow('Projects Completed', '${widget.projectsCompleted}', AppConfig.safeGreen),
                  const SizedBox(height: 8),
                  _MetricRow('On-Time Delivery', '${widget.onTimeDelivery.toStringAsFixed(0)}%', AppConfig.deepNavy),
                  const SizedBox(height: 8),
                  _MetricRow('Quality Score', '${widget.qualityScore.toStringAsFixed(1)}/5.0', AppConfig.cautionYellow),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('View Detailed Report'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _RatingBadge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(1)}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppConfig.skySlate.withValues(alpha: 0.7))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ),
      ],
    );
  }
}
