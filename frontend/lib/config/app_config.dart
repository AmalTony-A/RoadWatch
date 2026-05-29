import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = 'RoadWatch AI';
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://roadwatch-1-8gha.onrender.com',
  );

  static const Color dangerRed = Color(0xFFD64045);
  static const Color cautionYellow = Color(0xFFF0A202);
  static const Color safeGreen = Color(0xFF2A9D8F);
  static const Color deepNavy = Color(0xFF102A43);
  static const Color skySlate = Color(0xFF243B53);
  static const Color paper = Color(0xFFF8FAFC);

  static Color healthColorFromText(String color) {
    switch (color.toLowerCase()) {
      case 'red':
        return dangerRed;
      case 'yellow':
        return cautionYellow;
      case 'green':
        return safeGreen;
      default:
        return Colors.grey;
    }
  }
}
