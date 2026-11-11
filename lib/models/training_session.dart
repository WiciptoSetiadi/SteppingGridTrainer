class TrainingSession {
  final int sessionId;
  final int userId;
  final int deviceId;
  final int modeId;
  final String sessionStatus; // 'waiting', 'running', 'stopped', 'completed'
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final int? layoutId;
  final int? targetTempoMs;
  final int? totalTargets;

  const TrainingSession({
    required this.sessionId,
    required this.userId,
    required this.deviceId,
    required this.modeId,
    required this.sessionStatus,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
    this.layoutId,
    this.targetTempoMs,
    this.totalTargets,
  });

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    final config = json['session_config'] as Map<String, dynamic>?;
    return TrainingSession(
      sessionId: json['session_id'] as int,
      userId: json['user_id'] as int,
      deviceId: json['device_id'] as int,
      modeId: json['mode_id'] as int,
      sessionStatus: json['session_status'] as String? ?? 'waiting',
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      layoutId: config?['layout_id'] as int?,
      targetTempoMs: config?['target_tempo_ms'] as int?,
      totalTargets: config?['total_targets'] as int?,
    );
  }
}
