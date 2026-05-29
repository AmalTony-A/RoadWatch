class DetectionBox {
  final String label;
  final double confidence;
  final String severity;
  final List<double> bbox;

  const DetectionBox({
    required this.label,
    required this.confidence,
    required this.severity,
    required this.bbox,
  });

  factory DetectionBox.fromJson(Map<String, dynamic> json) {
    return DetectionBox(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      severity: json['severity'] as String,
      bbox: (json['bbox'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
    );
  }
}

class DetectionScore {
  final int roadHealthScore;
  final String color;
  final Map<String, dynamic> severityBreakdown;

  const DetectionScore({
    required this.roadHealthScore,
    required this.color,
    required this.severityBreakdown,
  });

  factory DetectionScore.fromJson(Map<String, dynamic> json) {
    return DetectionScore(
      roadHealthScore: json['road_health_score'] as int,
      color: json['color'] as String,
      severityBreakdown: json['severity_breakdown'] as Map<String, dynamic>,
    );
  }
}

class DetectionResult {
  final String imageId;
  final String? roadId;
  final bool detected;
  final String? damageType;
  final int confidence;
  final String message;
  final String explanation;
  final List<DetectionBox> detections;
  final String model;
  final int inferenceMs;
  final int imageWidth;
  final int imageHeight;
  final DetectionScore score;
  final String? sceneStatus;
  final String? sceneMessage;
  final bool needsReupload;

  const DetectionResult({
    required this.imageId,
    required this.roadId,
    required this.detected,
    required this.damageType,
    required this.confidence,
    required this.message,
    required this.explanation,
    required this.detections,
    required this.model,
    required this.inferenceMs,
    required this.imageWidth,
    required this.imageHeight,
    required this.score,
    required this.sceneStatus,
    required this.sceneMessage,
    required this.needsReupload,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    List<DetectionBox> parseDetections(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map>()
            .map((e) => DetectionBox.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return const <DetectionBox>[];
    }

    int asInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return DetectionResult(
      imageId: json['image_id'] as String,
      roadId: json['road_id'] as String?,
      detected: json['detected'] as bool? ?? false,
      damageType: json['damageType'] as String? ?? json['damage_type'] as String?,
      confidence: asInt(json['confidence']),
      message: json['message']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
      detections: parseDetections(json['detections']),
      model: json['model'] as String,
      inferenceMs: asInt(json['inference_ms']),
      imageWidth: (json['image_width'] as num?)?.toInt() ?? 640,
      imageHeight: (json['image_height'] as num?)?.toInt() ?? 360,
      score: DetectionScore.fromJson((json['score'] as Map<String, dynamic>?) ?? const <String, dynamic>{
        'road_health_score': 0,
        'color': 'green',
        'severity_breakdown': <String, dynamic>{},
      }),
      sceneStatus: json['scene_status'] as String?,
      sceneMessage: json['scene_message'] as String?,
      needsReupload: json['needs_reupload'] as bool? ?? false,
    );
  }
}
