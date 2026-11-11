class AiPrediction {
  final int predictionId;
  final int sessionId;
  final String modelVersion;
  final double? predictedValue; // estimasi hari ke target
  final String predictionUnit;
  final double confidenceScore;
  final String? notes;
  final DateTime predictedAt;

  const AiPrediction({
    required this.predictionId,
    required this.sessionId,
    required this.modelVersion,
    this.predictedValue,
    required this.predictionUnit,
    required this.confidenceScore,
    this.notes,
    required this.predictedAt,
  });

  factory AiPrediction.fromJson(Map<String, dynamic> json) {
    return AiPrediction(
      predictionId: json['prediction_id'] as int,
      sessionId: json['session_id'] as int,
      modelVersion: json['model_version'] as String? ?? 'linreg-v1',
      predictedValue: (json['predicted_value'] as num?)?.toDouble(),
      predictionUnit: json['prediction_unit'] as String? ?? 'days',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      predictedAt: json['predicted_at'] != null
          ? DateTime.parse(json['predicted_at'] as String)
          : DateTime.now(),
    );
  }
}
