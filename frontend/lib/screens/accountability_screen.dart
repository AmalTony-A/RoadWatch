import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/road_network_item.dart';
import '../providers/app_state.dart';

class AccountabilityScreen extends StatefulWidget {
  const AccountabilityScreen({super.key});

  @override
  State<AccountabilityScreen> createState() => _AccountabilityScreenState();
}

class _AccountabilityScreenState extends State<AccountabilityScreen> {
  String _selectedSort = 'budget'; // budget, issues, efficiency

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final roads = appState.roadNetwork;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Calculate efficiency metrics
    final roadsWithBudgetAndIssues = roads
        .map((road) => {
          'road': road,
          'budgetCrore': road.budgetCrore,
          'issueCount': road.issues.length,
          'efficiency': road.budgetCrore > 0 ? road.issues.length / (road.budgetCrore / 10) : 0.0,
          'budgetPerKm': road.lengthKm > 0 ? (road.budgetCrore * 10000000 / road.lengthKm) : 0,
        })
        .toList();

    // Sort by selected metric
    switch (_selectedSort) {
      case 'budget':
        roadsWithBudgetAndIssues.sort((a, b) => (b['budgetCrore'] as int).compareTo(a['budgetCrore'] as int));
      case 'issues':
        roadsWithBudgetAndIssues.sort((a, b) => (b['issueCount'] as int).compareTo(a['issueCount'] as int));
      case 'efficiency':
        roadsWithBudgetAndIssues.sort((a, b) => (b['efficiency'] as double).compareTo(a['efficiency'] as double));
    }

    final totalBudget = roads.fold<int>(0, (sum, road) => sum + road.budgetCrore);
    final avgIssuesPerRoad = roads.isEmpty ? 0 : roads.fold<int>(0, (sum, road) => sum + road.issues.length) ~/ roads.length;
    final roadsWithIssues = roads.where((r) => r.issues.isNotEmpty).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Public Accountability')),
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
                  'Government Accountability',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Budget allocation vs road issues transparency',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Key Accountability Metrics
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                'Total Budget',
                '₹${(totalBudget / 100).toStringAsFixed(0)}Cr',
                Icons.attach_money_rounded,
                AppConfig.deepNavy,
              ),
              _MetricCard(
                'Roads with Issues',
                '$roadsWithIssues',
                Icons.warning_rounded,
                AppConfig.dangerRed,
              ),
              _MetricCard(
                'Avg Issues/Road',
                '$avgIssuesPerRoad',
                Icons.report_problem_rounded,
                AppConfig.cautionYellow,
              ),
              _MetricCard(
                'Problem Rate',
                '${((roadsWithIssues / roads.length) * 100).toStringAsFixed(1)}%',
                Icons.trending_down_rounded,
                AppConfig.safeGreen,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Budget vs Issues Analysis
          _SectionCard(
            title: 'Budget Allocation Analysis',
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5ECF5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_rounded, size: 16, color: AppConfig.skySlate),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This shows how budget is distributed against reported issues. Higher budget allocation to problem roads indicates better resource planning.',
                              style: TextStyle(fontSize: 12, color: AppConfig.skySlate, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...roadsWithBudgetAndIssues.take(15).map((item) {
                  final road = item['road'] as RoadNetworkItem;
                  final budget = item['budgetCrore'] as int;
                  final issueCount = item['issueCount'] as int;
                  final efficiency = item['efficiency'] as double;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BudgetIssueRow(
                      roadName: road.name,
                      budget: budget,
                      issues: issueCount,
                      efficiency: efficiency,
                      condition: road.condition,
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sort Controls
          _SectionCard(
            title: 'Filter & Sort',
            child: Row(
              children: [
                Expanded(
                  child: _SortButton(
                    label: 'By Budget',
                    isActive: _selectedSort == 'budget',
                    onTap: () => setState(() => _selectedSort = 'budget'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SortButton(
                    label: 'By Issues',
                    isActive: _selectedSort == 'issues',
                    onTap: () => setState(() => _selectedSort = 'issues'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SortButton(
                    label: 'By Efficiency',
                    isActive: _selectedSort == 'efficiency',
                    onTap: () => setState(() => _selectedSort = 'efficiency'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Issue Distribution by Contractor
          _SectionCard(
            title: 'Issues by Contractor (Top 10)',
            child: Column(
              children: [
                ...roadsWithBudgetAndIssues
                    .where((item) => (item['issueCount'] as int) > 0)
                    .take(10)
                    .map((item) {
                  final road = item['road'] as RoadNetworkItem;
                  final issues = item['issueCount'] as int;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
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
                                    road.contractor,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    road.name,
                                    style: const TextStyle(fontSize: 11, color: AppConfig.skySlate),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppConfig.dangerRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$issues issues',
                                style: const TextStyle(
                                  color: AppConfig.dangerRed,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // Transparency Insights
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Key Insights',
            child: Column(
              children: [
                _InsightItem(
                  '🏗️',
                  'High Budget Roads',
                  'Roads receiving >₹100Cr show mixed issue rates, suggesting budget alone doesn\'t determine road quality.',
                ),
                const SizedBox(height: 12),
                _InsightItem(
                  '⚠️',
                  'Problem Concentration',
                  '$roadsWithIssues roads (${((roadsWithIssues / roads.length) * 100).toStringAsFixed(1)}%) have reported issues needing urgent attention.',
                ),
                const SizedBox(height: 12),
                _InsightItem(
                  '💰',
                  'Budget Efficiency',
                  'Average budget allocation is ₹${((totalBudget * 10000000) / roads.fold<int>(0, (sum, r) => sum + r.lengthKm)).toStringAsFixed(0)}/km across all roads.',
                ),
              ],
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

class _BudgetIssueRow extends StatelessWidget {
  final String roadName;
  final int budget;
  final int issues;
  final double efficiency;
  final String condition;

  const _BudgetIssueRow({
    required this.roadName,
    required this.budget,
    required this.issues,
    required this.efficiency,
    required this.condition,
  });

  Color _getEfficiencyColor() {
    if (efficiency > 0.5) return AppConfig.dangerRed;
    if (efficiency > 0.2) return AppConfig.cautionYellow;
    return AppConfig.safeGreen;
  }

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roadName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      condition,
                      style: TextStyle(
                        fontSize: 11,
                        color: condition == 'Good'
                            ? AppConfig.safeGreen
                            : condition == 'Moderate'
                                ? AppConfig.cautionYellow
                                : AppConfig.dangerRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getEfficiencyColor().withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${efficiency.toStringAsFixed(2)} e-ratio',
                  style: TextStyle(
                    color: _getEfficiencyColor(),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.attach_money_rounded, size: 14, color: AppConfig.skySlate),
                  const SizedBox(width: 4),
                  Text('₹${(budget / 100).toStringAsFixed(1)}Cr', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.warning_rounded, size: 14, color: AppConfig.skySlate),
                  const SizedBox(width: 4),
                  Text('$issues issues', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SortButton({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
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
