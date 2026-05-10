import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/budget_record.dart';
import '../screens/transparency_screen.dart';
import '../models/road_segment.dart';
import '../providers/app_state.dart';

class BudgetForecastingScreen extends StatefulWidget {
  const BudgetForecastingScreen({super.key});

  @override
  State<BudgetForecastingScreen> createState() => _BudgetForecastingScreenState();
}

class _BudgetForecastingScreenState extends State<BudgetForecastingScreen> {
  String _selectedPeriod = '12 Months';
  String _selectedCategory = 'All';

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
              'ðŸ’° Budget Forecasting',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppConfig.deepNavy,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Predict budget requirements and spending trends',
              style: TextStyle(color: AppConfig.skySlate.withValues(alpha: 0.8), fontSize: 14),
            ),
            const SizedBox(height: 24),

            Consumer<AppState>(
              builder: (context, appState, _) {
                return _BudgetTransparencyCard(appState: appState);
              },
            ),
            const SizedBox(height: 24),

            // Controls
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedPeriod,
                    onChanged: (String? newValue) {
                      if (newValue != null) setState(() => _selectedPeriod = newValue);
                    },
                    items: const [
                      DropdownMenuItem(value: '6 Months', child: Text('6 Months')),
                      DropdownMenuItem(value: '12 Months', child: Text('12 Months')),
                      DropdownMenuItem(value: '24 Months', child: Text('24 Months')),
                      DropdownMenuItem(value: '5 Years', child: Text('5 Years')),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    onChanged: (String? newValue) {
                      if (newValue != null) setState(() => _selectedCategory = newValue);
                    },
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Categories')),
                      DropdownMenuItem(value: 'NH', child: Text('National Highways')),
                      DropdownMenuItem(value: 'SH', child: Text('State Highways')),
                      DropdownMenuItem(value: 'MDR', child: Text('Major District Roads')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Summary Cards
            _buildForecastSummary(context),
            const SizedBox(height: 24),

            // Spending Trend Chart
            _buildSpendingTrendChart(context),
            const SizedBox(height: 24),

            // Category Breakdown
            Consumer<AppState>(builder: (context, appState, _) {
              return _buildCategoryBreakdown(context, appState.roads);
            }),
            const SizedBox(height: 24),

            // Budget Recommendations
            _buildRecommendations(context),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastSummary(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: _ForecastCard(
            title: 'Projected Spend',
            value: 'â‚¹450,000 Cr',
            subtitle: 'Next 12 months',
            icon: Icons.trending_up,
            color: AppConfig.cautionYellow,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: _ForecastCard(
            title: 'Required Budget',
            value: 'â‚¹380,000 Cr',
            subtitle: 'Maintenance only',
            icon: Icons.calculate,
            color: AppConfig.deepNavy,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ForecastCard(
            title: 'Budget Gap',
            value: 'â‚¹70,000 Cr',
            subtitle: 'Allocation needed',
            icon: Icons.warning,
            color: Colors.red.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingTrendChart(BuildContext context) {
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
            'Budget Spending Forecast',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppConfig.deepNavy,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                maxY: 50000,
                gridData: const FlGridData(show: true, horizontalInterval: 10000),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${(value / 1000).toInt()}K', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                        return Text(months[value.toInt()], style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 30000),
                      const FlSpot(1, 32000),
                      const FlSpot(2, 31500),
                      const FlSpot(3, 35000),
                      const FlSpot(4, 38000),
                      const FlSpot(5, 40000),
                      const FlSpot(6, 42000),
                      const FlSpot(7, 41000),
                      const FlSpot(8, 43000),
                      const FlSpot(9, 45000),
                      const FlSpot(10, 46000),
                      const FlSpot(11, 48000),
                    ],
                    isCurved: true,
                    color: AppConfig.deepNavy,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppConfig.deepNavy.withValues(alpha: 0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 25000),
                      const FlSpot(1, 26000),
                      const FlSpot(2, 27000),
                      const FlSpot(3, 28000),
                      const FlSpot(4, 29000),
                      const FlSpot(5, 30000),
                      const FlSpot(6, 31000),
                      const FlSpot(7, 32000),
                      const FlSpot(8, 33000),
                      const FlSpot(9, 34000),
                      const FlSpot(10, 35000),
                      const FlSpot(11, 36000),
                    ],
                    isCurved: true,
                    color: AppConfig.safeGreen,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppConfig.safeGreen.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              _LegendItem('Projected Spending', AppConfig.deepNavy),
              SizedBox(width: 24),
              _LegendItem('Safe Budget Range', AppConfig.safeGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(BuildContext context, List<RoadSegment> roads) {
    final categories = {'Good': 0, 'Attention Needed': 0, 'Critical': 0};
    for (final road in roads) {
      if (road.roadHealthScore >= 70) {
        categories['Good'] = categories['Good']! + 1;
      } else if (road.roadHealthScore >= 45) {
        categories['Attention Needed'] = categories['Attention Needed']! + 1;
      } else {
        categories['Critical'] = categories['Critical']! + 1;
      }
    }

    final total = categories.values.fold<int>(0, (a, b) => a + b);

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
            'Budget by Road Health',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppConfig.deepNavy,
                ),
          ),
          const SizedBox(height: 16),
          ...categories.entries.map((entry) {
            final percentage = total > 0 ? ((entry.value / total) * 100) : 0.0;
            return _BudgetCategoryBar(
              label: entry.key,
              amount: '${entry.value} roads',
              percentage: percentage,
              color: entry.key == 'Good'
                    ? AppConfig.deepNavy
                  : entry.key == 'Attention Needed'
                      ? AppConfig.cautionYellow
                      : AppConfig.safeGreen,
            );
          }),
          const SizedBox(height: 12),
          Text('Total Roads: $total', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConfig.deepNavy.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConfig.deepNavy.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: AppConfig.deepNavy, size: 24),
              const SizedBox(width: 12),
              Text(
                'Budget Recommendations',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppConfig.deepNavy,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _RecommendationItem(
            'Increase SH maintenance budget by 15%',
            'Current trend shows higher deterioration in State Highways',
          ),
          const SizedBox(height: 8),
          _RecommendationItem(
            'Allocate emergency fund for poor-condition roads',
            '${(564 * 0.15).toInt()} roads in poor condition need immediate attention',
          ),
          const SizedBox(height: 8),
          const _RecommendationItem(
            'Plan preventive maintenance for good-condition roads',
            'Reduces future emergency costs by 30-40%',
          ),
        ],
      ),
    );
  }
}

class _BudgetTransparencyCard extends StatelessWidget {
  final AppState appState;

  const _BudgetTransparencyCard({required this.appState});

  @override
  Widget build(BuildContext context) {
    final selectedRoad = appState.selectedRoad;
    final matchingBudgets = selectedRoad == null
      ? const <BudgetRecord>[]
      : appState.budgets.where((item) => item.roadId == selectedRoad.id).toList(growable: false);
    final BudgetRecord? budget = matchingBudgets.isEmpty ? null : matchingBudgets.first;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: 'INR ', decimalDigits: 0);
    final isLinked = budget != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2747), Color(0xFF112D4E), Color(0xFF173A63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).cardTheme.shadowColor ?? Colors.black.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transparency Indicator',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLinked
                          ? '${formatter.format(budget.allocatedInr)} allocated | Score ${budget.actualScore}/100'
                          : 'No budget data for selected road.',
                      style: const TextStyle(color: Color(0xFFE1E8F2), fontSize: 14, height: 1.25),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isLinked ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12) : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isLinked ? 'Linked' : 'Select Road',
                  style: TextStyle(
                    color: isLinked ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.tertiary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            budget?.transparencyNote ?? 'Select a road to inspect allocation and outcomes.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFFBCCCDC), fontSize: 13.5, height: 1.3),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const TransparencyScreen()),
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text(
                'Open Full Transparency Module',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ForecastCard({
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
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
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

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _BudgetCategoryBar extends StatelessWidget {
  final String label;
  final String amount;
  final double percentage;
  final Color color;

  const _BudgetCategoryBar({
    required this.label,
    required this.amount,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            Text('$percentage%', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(amount, style: TextStyle(fontSize: 11, color: AppConfig.skySlate.withValues(alpha: 0.7))),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _RecommendationItem extends StatelessWidget {
  final String title;
  final String description;

  const _RecommendationItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: AppConfig.deepNavy, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 2),
              Text(description, style: TextStyle(fontSize: 11, color: AppConfig.skySlate.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ],
    );
  }
}
