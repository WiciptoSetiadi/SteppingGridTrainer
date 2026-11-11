class AiRecommendation {
  final int recommendationId;
  final int sessionId;
  final String recommendedMode;
  final int recommendedTempoMs;
  final String recommendationText;
  final DateTime createdAt;

  const AiRecommendation({
    required this.recommendationId,
    required this.sessionId,
    required this.recommendedMode,
    required this.recommendedTempoMs,
    required this.recommendationText,
    required this.createdAt,
  });

  factory AiRecommendation.fromJson(Map<String, dynamic> json) {
    return AiRecommendation(
      recommendationId: json['recommendation_id'] as int,
      sessionId: json['session_id'] as int,
      recommendedMode: json['recommended_mode'] as String? ?? 'Sekuensial',
      recommendedTempoMs: json['recommended_tempo_ms'] as int? ?? 1500,
      recommendationText: json['recommendation_text'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
