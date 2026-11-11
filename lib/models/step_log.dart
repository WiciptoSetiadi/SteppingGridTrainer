class StepLog {
  final int? stepLogId;
  final int sessionId;
  final int positionId;
  final int stepNumber;
  final String eventType; // 'target_hit', 'wrong_step', 'timeout'
  final bool isCorrect;
  final int? reactionTimeMs;
  final DateTime eventAt;
  final String? positionCode;
  final String? side;

  const StepLog({
    this.stepLogId,
    required this.sessionId,
    required this.positionId,
    required this.stepNumber,
    required this.eventType,
    required this.isCorrect,
    this.reactionTimeMs,
    required this.eventAt,
    this.positionCode,
    this.side,
  });

  factory StepLog.fromJson(Map<String, dynamic> json) {
    final tile = json['tile_position'] as Map<String, dynamic>?;
    return StepLog(
      stepLogId: json['step_log_id'] as int?,
      sessionId: json['session_id'] as int,
      positionId: json['position_id'] as int,
      stepNumber: json['step_number'] as int,
      eventType: json['event_type'] as String,
      isCorrect: json['is_correct'] as bool,
      reactionTimeMs: json['reaction_time_ms'] as int?,
      eventAt: DateTime.parse(json['event_at'] as String),
      positionCode: tile?['position_code'] as String?,
      side: tile?['side'] as String?,
    );
  }
}
