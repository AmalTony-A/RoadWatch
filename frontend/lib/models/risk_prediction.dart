class RiskPrediction {
  final String roadId;
  final String riskLevel;
  final double probabilityOfDeterioration;
  final int predictedDaysToDecline;

  const RiskPrediction({
    required this.roadId,
    required this.riskLevel,
    required this.probabilityOfDeterioration,
    required this.predictedDaysToDecline,
  });

  factory RiskPrediction.fromJson(Map<String, dynamic> json) {
    return RiskPrediction(
      roadId: json['road_id'] as String,
      riskLevel: json['risk_level'] as String,
      probabilityOfDeterioration: (json['probability_of_deterioration'] as num).toDouble(),
      predictedDaysToDecline: json['predicted_days_to_decline'] as int,
    );
  }
}
