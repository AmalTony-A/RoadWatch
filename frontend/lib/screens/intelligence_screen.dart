import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';
import '../widgets/risk_badge.dart';
import '../widgets/trend_chart.dart';

class IntelligenceScreen extends StatelessWidget {
  const IntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final trends = state.intelligence['damage_trends'] as List<dynamic>? ?? [];
    final budgetVsCondition = state.intelligence['budget_vs_condition'] as List<dynamic>? ?? [];
    final repairFrequency = state.intelligence['repair_frequency'] as List<dynamic>? ?? [];
    final predictionText = state.intelligence['prediction_text'] as String? ??
        'This road may deteriorate in 21 days based on complaint and weather trends.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF102A43), Color(0xFF1D4E89)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppConfig.deepNavy.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Road Intelligence Panel',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Use trend signals, repair history, and AI predictions to prioritize intervention.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
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
              const Text('Damage Trend (Monthly)', style: TextStyle(fontWeight: FontWeight.w800, color: AppConfig.deepNavy)),
              const SizedBox(height: 12),
              TrendChart(points: trends),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF102A43), Color(0xFF1D4E89)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppConfig.deepNavy.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Prediction Engine',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(predictionText, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), height: 1.4)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.cautionYellow,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: state.runRiskPrediction,
                    icon: const Icon(Icons.auto_graph_rounded),
                    label: const Text('Run Risk Prediction'),
                  ),
                  if (state.lastRiskPrediction != null) RiskBadge(level: state.lastRiskPrediction!.riskLevel),
                ],
              ),
              if (state.lastRiskPrediction != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Risk ${state.lastRiskPrediction!.probabilityOfDeterioration} | Decline in ${state.lastRiskPrediction!.predictedDaysToDecline} days',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
                )
              ]
            ],
          ),
        ),
        const SizedBox(height: 12),
        _tableBlock(
          title: 'Budget vs Condition',
          headers: const ['Road', 'Allocated (INR)', 'Score'],
          rows: budgetVsCondition
              .map((row) => [
                    row['road_id'].toString(),
                    NumberFormat.decimalPattern('en_IN').format(row['allocated_inr']),
                    row['score'].toString(),
                  ])
              .toList(),
        ),
        const SizedBox(height: 12),
        _tableBlock(
          title: 'Repair Frequency (12 months)',
          headers: const ['Road', 'Repairs'],
          rows: repairFrequency
              .map((row) => [row['road_id'].toString(), row['repairs_last_12m'].toString()])
              .toList(),
        ),
      ],
    );
  }

  Widget _tableBlock({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppConfig.deepNavy)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
              rows: rows
                  .map(
                    (row) => DataRow(
                      cells: row.map((c) => DataCell(Text(c))).toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
