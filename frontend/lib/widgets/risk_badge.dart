import 'package:flutter/material.dart';

import '../config/app_config.dart';

class RiskBadge extends StatelessWidget {
  final String level;

  const RiskBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final normalized = level.toLowerCase();
    final color = normalized == 'high'
        ? AppConfig.dangerRed
        : normalized == 'medium'
            ? AppConfig.cautionYellow
            : AppConfig.safeGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        level,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
