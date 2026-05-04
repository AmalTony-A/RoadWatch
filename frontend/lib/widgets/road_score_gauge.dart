import 'package:flutter/material.dart';

import '../config/app_config.dart';

class RoadScoreGauge extends StatelessWidget {
  final int score;
  final String? label;

  const RoadScoreGauge({super.key, required this.score, this.label});

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 100);
    final color = clamped < 50
        ? AppConfig.dangerRed
        : clamped < 75
            ? AppConfig.cautionYellow
            : AppConfig.safeGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label ?? 'Road Health Score',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: clamped / 100,
                    minHeight: 20,
                    backgroundColor: const Color(0xFFE6ECF2),
                    color: color,
                  ),
                ),
              ),
              Text(
                '$clamped/100',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
