class TrainingLayout {
  final int layoutId;
  final String layoutCode;
  final String layoutName;
  final int tileCount;
  final List<String> startPositions;
  final List<String> sequentialPattern;
  final bool isActive;

  const TrainingLayout({
    required this.layoutId,
    required this.layoutCode,
    required this.layoutName,
    required this.tileCount,
    required this.startPositions,
    required this.sequentialPattern,
    this.isActive = true,
  });

  factory TrainingLayout.fromJson(Map<String, dynamic> json) {
    return TrainingLayout(
      layoutId: json['layout_id'] as int,
      layoutCode: json['layout_code'] as String,
      layoutName: json['layout_name'] as String,
      tileCount: json['tile_count'] as int? ?? 4,
      startPositions: (json['start_positions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      sequentialPattern: (json['sequential_pattern'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'layout_id': layoutId,
        'layout_code': layoutCode,
        'layout_name': layoutName,
        'tile_count': tileCount,
        'start_positions': startPositions,
        'sequential_pattern': sequentialPattern,
        'is_active': isActive,
      };
}
