import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';

class TrendChart extends StatelessWidget {
  final List<dynamic> points;

  const TrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No trend data available')),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final row = points[i] as Map<String, dynamic>;
      final value = (row['issues'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), value));
    }

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final label = (points[idx] as Map<String, dynamic>)['month'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(label, style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xFFDAE3ED)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: AppConfig.deepNavy,
              barWidth: 3,
              isCurved: true,
              belowBarData: BarAreaData(show: true, color: AppConfig.deepNavy.withOpacity(0.1)),
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}
