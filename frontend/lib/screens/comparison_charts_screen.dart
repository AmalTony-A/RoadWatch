import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/road_network_item.dart';
import '../providers/app_state.dart';

class ComparisonChartsScreen extends StatefulWidget {
  const ComparisonChartsScreen({super.key});

  @override
  State<ComparisonChartsScreen> createState() => _ComparisonChartsScreenState();
}

class _ComparisonChartsScreenState extends State<ComparisonChartsScreen> {
  String _selectedComparison = 'condition'; // condition, type, year
  int _selectedDistrictIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final roads = appState.roadNetwork;

    // Get list of districts from roads
    final districtSet = <String>{};
    for (final road in roads) {
      districtSet.addAll(road.districts);
    }
    final districts = districtSet.toList()..sort();

    // Calculate condition comparison
    final conditionData = _getConditionComparison(roads);
    final typeComparison = _getTypeComparison(roads);
    final yearComparison = _getYearComparison(roads);

    // Get district-specific data
    final selectedDistrict = districts.isNotEmpty ? districts[_selectedDistrictIndex % districts.length] : '';
    final districtRoads = selectedDistrict.isEmpty
        ? roads
        : roads.where((r) => r.districts.contains(selectedDistrict)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Comparison Analysis')),
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
                  'Road Network Comparison',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Analyze road data across different categories and districts',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Overview Cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(
                'Total Roads',
                '${roads.length}',
                Icons.road_rounded,
                AppConfig.deepNavy,
              ),
              _StatCard(
                'Total Length',
                '${roads.fold<int>(0, (sum, r) => sum + r.lengthKm)} km',
                Icons.straighten_rounded,
                AppConfig.skySlate,
              ),
              _StatCard(
                'Districts',
                '${districts.length}',
                Icons.location_on_rounded,
                AppConfig.safeGreen,
              ),
              _StatCard(
                'Avg Length/Road',
                '${(roads.isEmpty ? 0 : roads.fold<int>(0, (sum, r) => sum + r.lengthKm) ~/ roads.length)} km',
                Icons.show_chart_rounded,
                AppConfig.cautionYellow,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Comparison Type Selection
          _SectionCard(
            title: 'Comparison Type',
            child: Row(
              children: [
                _ComparisonButton(
                  label: 'By Condition',
                  isActive: _selectedComparison == 'condition',
                  onTap: () => setState(() => _selectedComparison = 'condition'),
                ),
                const SizedBox(width: 10),
                _ComparisonButton(
                  label: 'By Type',
                  isActive: _selectedComparison == 'type',
                  onTap: () => setState(() => _selectedComparison = 'type'),
                ),
                const SizedBox(width: 10),
                _ComparisonButton(
                  label: 'By Year',
                  isActive: _selectedComparison == 'year',
                  onTap: () => setState(() => _selectedComparison = 'year'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Main Comparison Chart
          _SectionCard(
            title: 'Distribution Analysis',
            child: _selectedComparison == 'condition'
                ? _buildConditionChart(conditionData)
                : _selectedComparison == 'type'
                    ? _buildTypeChart(typeComparison)
                    : _buildYearChart(yearComparison),
          ),
          const SizedBox(height: 20),

          // District Comparison
          if (districts.isNotEmpty)
            _SectionCard(
              title: 'District Breakdown',
              child: Column(
                children: [
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: districts.length,
                      itemBuilder: (context, index) {
                        final district = districts[index];
                        final isSelected = index == _selectedDistrictIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _DistrictChip(
                            label: district,
                            isSelected: isSelected,
                            onTap: () => setState(() => _selectedDistrictIndex = index),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDistrictStats(districtRoads, selectedDistrict),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Budget Distribution
          _SectionCard(
            title: 'Budget Distribution (₹ Crores)',
            child: Column(
              children: [
                ...typeComparison.entries.map((entry) {
                  final totalBudget = roads
                      .where((r) => r.type == entry.key)
                      .fold<int>(0, (sum, r) => sum + r.budgetCrore);
                  final percentage = roads.isEmpty ? 0.0 : (totalBudget / roads.fold<int>(0, (sum, r) => sum + r.budgetCrore)) * 100;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BudgetRow(
                      label: entry.key,
                      amount: totalBudget,
                      percentage: percentage,
                      color: _getTypeColor(entry.key),
                      count: entry.value,
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Key Insights
          _SectionCard(
            title: 'Key Insights',
            child: Column(
              children: [
                _InsightItem(
                  '📊',
                  'Road Condition Status',
                  conditionData['Good'] != null
                      ? '${conditionData['Good']} roads in good condition, ${conditionData['Moderate']} moderate, ${conditionData['Poor']} poor'
                      : 'Condition data not available',
                ),
                const SizedBox(height: 12),
                _InsightItem(
                  '🛣️',
                  'Road Type Distribution',
                  typeComparison.entries
                      .map((e) => '${e.key}: ${e.value} roads')
                      .join(', '),
                ),
                const SizedBox(height: 12),
                _InsightItem(
                  '📍',
                  'Most Developed District',
                  selectedDistrict.isNotEmpty
                      ? '$selectedDistrict has ${districtRoads.length} roads (${((districtRoads.length / roads.length) * 100).toStringAsFixed(1)}% of total)'
                      : 'No district data',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _getConditionComparison(List<RoadNetworkItem> roads) {
    return {
      'Good': roads.where((r) => r.condition == 'Good').length,
      'Moderate': roads.where((r) => r.condition == 'Moderate').length,
      'Poor': roads.where((r) => r.condition == 'Poor').length,
    };
  }

  Map<String, int> _getTypeComparison(List<RoadNetworkItem> roads) {
    return {
      'NH': roads.where((r) => r.type == 'NH').length,
      'SH': roads.where((r) => r.type == 'SH').length,
      'MDR': roads.where((r) => r.type == 'MDR').length,
    };
  }

  Map<String, int> _getYearComparison(List<RoadNetworkItem> roads) {
    final yearMap = <String, int>{};
    for (final road in roads) {
      final decade = '${(road.year ~/ 10) * 10}s';
      yearMap[decade] = (yearMap[decade] ?? 0) + 1;
    }
    return yearMap;
  }

  Widget _buildConditionChart(Map<String, int> data) {
    final total = data.values.fold<int>(0, (sum, val) => sum + val);
    final goodPercentage = total > 0 ? (data['Good'] ?? 0) / total : 0;
    const sectionSpace = 0;

    return SizedBox(
      height: 280,
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: goodPercentage * 100,
                    color: AppConfig.safeGreen,
                    title: '${(goodPercentage * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    radius: 80,
                  ),
                  PieChartSectionData(
                    value: ((data['Moderate'] ?? 0) / total) * 100,
                    color: AppConfig.cautionYellow,
                    title: '${(((data['Moderate'] ?? 0) / total) * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    radius: 80,
                  ),
                  PieChartSectionData(
                    value: ((data['Poor'] ?? 0) / total) * 100,
                    color: AppConfig.dangerRed,
                    title: '${(((data['Poor'] ?? 0) / total) * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    radius: 80,
                  ),
                ],
                sectionsSpace: sectionSpace,
                centerSpaceRadius: 60,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _LegendItem('Good', AppConfig.safeGreen, data['Good'] ?? 0),
              _LegendItem('Moderate', AppConfig.cautionYellow, data['Moderate'] ?? 0),
              _LegendItem('Poor', AppConfig.dangerRed, data['Poor'] ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChart(Map<String, int> data) {
    final total = data.values.fold<int>(0, (sum, val) => sum + val);

    return SizedBox(
      height: 280,
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: ((data['NH'] ?? 0) / total) * 100,
                    color: const Color(0xFF FF6B6B),
                    title: '${(((data['NH'] ?? 0) / total) * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    radius: 80,
                  ),
                  PieChartSectionData(
                    value: ((data['SH'] ?? 0) / total) * 100,
                    color: const Color(0xFF 4ECDC4),
                    title: '${(((data['SH'] ?? 0) / total) * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    radius: 80,
                  ),
                  PieChartSectionData(
                    value: ((data['MDR'] ?? 0) / total) * 100,
                    color: const Color(0xFF 45B7D1),
                    title: '${(((data['MDR'] ?? 0) / total) * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    radius: 80,
                  ),
                ],
                sectionsSpace: 0,
                centerSpaceRadius: 60,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _LegendItem('NH (National)', const Color(0xFFFF6B6B), data['NH'] ?? 0),
              _LegendItem('SH (State)', const Color(0xFF4ECDC4), data['SH'] ?? 0),
              _LegendItem('MDR (Minor)', const Color(0xFF45B7D1), data['MDR'] ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearChart(Map<String, int> data) {
    final sortedYears = data.keys.toList()..sort();
    final maxValue = data.values.fold<int>(0, (max, val) => val > max ? val : max).toDouble();

    return SizedBox(
      height: 280,
      child: BarChart(
        BarChartData(
          maxY: maxValue + 5,
          barGroups: sortedYears.asMap().entries.map((entry) {
            final index = entry.key;
            final year = entry.value;
            final value = data[year]!.toDouble();

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: value,
                  color: AppConfig.deepNavy,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  width: 20,
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final index = value.toInt();
                  if (index < sortedYears.length) {
                    return Text(
                      sortedYears[index],
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
        ),
      ),
    );
  }

  Widget _buildDistrictStats(List<RoadNetworkItem> districtRoads, String districtName) {
    final goodRoads = districtRoads.where((r) => r.condition == 'Good').length;
    final moderateRoads = districtRoads.where((r) => r.condition == 'Moderate').length;
    final poorRoads = districtRoads.where((r) => r.condition == 'Poor').length;
    final totalLength = districtRoads.fold<int>(0, (sum, r) => sum + r.lengthKm);
    final totalBudget = districtRoads.fold<int>(0, (sum, r) => sum + r.budgetCrore);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5ECF5)),
          ),
          child: Column(
            children: [
              Text(
                districtName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _DistrictStatItem('Roads', districtRoads.length.toString()),
                  _DistrictStatItem('Length', '${totalLength} km'),
                  _DistrictStatItem('Budget', '₹${(totalBudget / 100).toStringAsFixed(0)}Cr'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ConditionBar('Good', goodRoads, districtRoads.length, AppConfig.safeGreen),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ConditionBar('Moderate', moderateRoads, districtRoads.length, AppConfig.cautionYellow),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ConditionBar('Poor', poorRoads, districtRoads.length, AppConfig.dangerRed),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBudgetRow(String label, int amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5ECF5)),
      ),
      child: Row(
        children: [
          Container(
            height: 24,
            width: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Container(
                height: 10,
                width: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text('₹${(amount / 100).toStringAsFixed(0)}Cr', style: const TextStyle(fontWeight: FontWeight.w700, color: AppConfig.deepNavy)),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'NH':
        return const Color(0xFFFF6B6B);
      case 'SH':
        return const Color(0xFF4ECDC4);
      case 'MDR':
        return const Color(0xFF45B7D1);
      default:
        return AppConfig.deepNavy;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppConfig.deepNavy.withValues(alpha: 0.04),
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
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppConfig.deepNavy)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: AppConfig.skySlate.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w600)),
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

class _ComparisonButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ComparisonButton({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isActive ? AppConfig.deepNavy : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? AppConfig.deepNavy : const Color(0xFFE5ECF5),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppConfig.deepNavy,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DistrictChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DistrictChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppConfig.deepNavy : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppConfig.deepNavy : const Color(0xFFE5ECF5),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppConfig.deepNavy,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final int count;

  const _LegendItem(this.label, this.color, this.count);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 12,
          width: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text('$label ($count)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final String label;
  final int amount;
  final double percentage;
  final Color color;
  final int count;

  const _BudgetRow({
    required this.label,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5ECF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 20,
                width: 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Container(
                    height: 10,
                    width: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$label Road Network', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    Text('$count roads', style: const TextStyle(fontSize: 10, color: AppConfig.skySlate)),
                  ],
                ),
              ),
              Text('₹${(amount / 100).toStringAsFixed(0)}Cr', style: const TextStyle(fontWeight: FontWeight.w800, color: AppConfig.deepNavy)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text('${percentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10, color: AppConfig.skySlate, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DistrictStatItem extends StatelessWidget {
  final String label;
  final String value;

  const _DistrictStatItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppConfig.deepNavy)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppConfig.skySlate, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ConditionBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _ConditionBar(this.label, this.count, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 24,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppConfig.deepNavy)),
            Text('$count', style: const TextStyle(fontSize: 9, color: AppConfig.skySlate, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _InsightItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;

  const _InsightItem(this.emoji, this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5ECF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(fontSize: 12, color: AppConfig.skySlate, height: 1.4)),
        ],
      ),
    );
  }
}
