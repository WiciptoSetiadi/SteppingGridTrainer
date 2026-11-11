class TilePosition {
  final int positionId;
  final int layoutId;
  final String positionCode;
  final String positionLabel;
  final int portNumber;
  final String side; // 'L', 'C', 'R'
  final int gridX;
  final int gridY;

  const TilePosition({
    required this.positionId,
    required this.layoutId,
    required this.positionCode,
    required this.positionLabel,
    required this.portNumber,
    required this.side,
    required this.gridX,
    required this.gridY,
  });

  factory TilePosition.fromJson(Map<String, dynamic> json) {
    return TilePosition(
      positionId: json['position_id'] as int,
      layoutId: json['layout_id'] as int,
      positionCode: json['position_code'] as String,
      positionLabel: json['position_label'] as String,
      portNumber: json['port_number'] as int,
      side: json['side'] as String,
      gridX: json['grid_x'] as int,
      gridY: json['grid_y'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'position_id': positionId,
        'layout_id': layoutId,
        'position_code': positionCode,
        'position_label': positionLabel,
        'port_number': portNumber,
        'side': side,
        'grid_x': gridX,
        'grid_y': gridY,
      };
}
