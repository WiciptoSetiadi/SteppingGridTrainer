class SessionResult {
  final int sessionId;
  final int totalSteps;
  final int correctSteps;
  final int incorrectSteps;
  final double accuracyPercent;
  final int totalDurationMs;
  final double averageReactionMs;
  final double? leftRightRatio;
  final DateTime calculatedAt;

  const SessionResult({
    required this.sessionId,
    required this.totalSteps,
    required this.correctSteps,
    required this.incorrectSteps,
    required this.accuracyPercent,
    required this.totalDurationMs,
    required this.averageReactionMs,
    this.leftRightRatio,
    required this.calculatedAt,
  });

  factory SessionResult.fromJson(Map<String, dynamic> json) {
    return SessionResult(
      sessionId: json['session_id'] as int,
      totalSteps: json['total_steps'] as int? ?? 0,
      correctSteps: json['correct_steps'] as int? ?? 0,
      incorrectSteps: json['incorrect_steps'] as int? ?? 0,
      accuracyPercent: (json['accuracy_percent'] as num?)?.toDouble() ?? 0.0,
      totalDurationMs: json['total_duration_ms'] as int? ?? 0,
      averageReactionMs: (json['average_reaction_ms'] as num?)?.toDouble() ?? 0.0,
      leftRightRatio: (json['left_right_ratio'] as num?)?.toDouble(),
      calculatedAt: json['calculated_at'] != null
          ? DateTime.parse(json['calculated_at'] as String)
          : DateTime.now(),
    );
  }
}
