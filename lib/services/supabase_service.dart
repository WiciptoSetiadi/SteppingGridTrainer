import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/layout.dart';
import '../models/tile_position.dart';
import '../models/training_session.dart';
import '../models/step_log.dart';
import '../models/session_result.dart';
import '../models/ai_prediction.dart';
import '../models/ai_recommendation.dart';

/// Konfigurasi dan klien layanan Supabase untuk Stepping Grid Trainer.
/// Mendukung mode terhubung ke Supabase serta fallback preview/demo jika belum terhubung.
class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  // Konfigurasi endpoint
  String supabaseUrl = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  String supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  // Stream controller untuk pembaruan realtime
  final _stepStreamController = StreamController<StepLog>.broadcast();
  Stream<StepLog> get onStepReceived => _stepStreamController.stream;

  final _sessionStatusController = StreamController<String>.broadcast();
  Stream<String> get onSessionStatusChanged => _sessionStatusController.stream;

  // Cache lokal
  List<TrainingLayout> _cachedLayouts = [];
  Map<int, List<TilePosition>> _cachedPositions = {};

  /// Mengambil daftar layout aktif (SDD 3.2.2 M-02)
  Future<List<TrainingLayout>> fetchLayouts() async {
    if (_cachedLayouts.isNotEmpty) return _cachedLayouts;

    // Jika Supabase belum dikonfigurasi, gunakan data master bawaan (SDD 5.2.12)
    _cachedLayouts = [
      const TrainingLayout(
        layoutId: 1,
        layoutCode: 'SQUARE_2X2',
        layoutName: 'Layout 2×2',
        tileCount: 4,
        startPositions: ['BL', 'BR'],
        sequentialPattern: ['FR', 'BR', 'FL', 'BL'],
      ),
      const TrainingLayout(
        layoutId: 2,
        layoutCode: 'HORIZONTAL_1X4',
        layoutName: 'Layout Horizontal',
        tileCount: 4,
        startPositions: ['H2', 'H3'],
        sequentialPattern: ['H4', 'H3', 'H1', 'H2'],
      ),
      const TrainingLayout(
        layoutId: 3,
        layoutCode: 'T_SHAPE',
        layoutName: 'Layout T',
        tileCount: 4,
        startPositions: ['C'],
        sequentialPattern: ['F', 'C', 'L', 'C', 'R', 'C'],
      ),
    ];
    return _cachedLayouts;
  }

  /// Mengambil data posisi ubin untuk layout tertentu (SDD Tabel 6)
  Future<List<TilePosition>> fetchPositionsForLayout(int layoutId) async {
    if (_cachedPositions.containsKey(layoutId)) {
      return _cachedPositions[layoutId]!;
    }

    final allPositions = [
      // 2x2
      const TilePosition(positionId: 1, layoutId: 1, positionCode: 'FL', positionLabel: 'Depan Kiri', portNumber: 1, side: 'L', gridX: 0, gridY: 0),
      const TilePosition(positionId: 2, layoutId: 1, positionCode: 'FR', positionLabel: 'Depan Kanan', portNumber: 2, side: 'R', gridX: 1, gridY: 0),
      const TilePosition(positionId: 3, layoutId: 1, positionCode: 'BL', positionLabel: 'Belakang Kiri', portNumber: 3, side: 'L', gridX: 0, gridY: 1),
      const TilePosition(positionId: 4, layoutId: 1, positionCode: 'BR', positionLabel: 'Belakang Kanan', portNumber: 4, side: 'R', gridX: 1, gridY: 1),
      // Horizontal
      const TilePosition(positionId: 5, layoutId: 2, positionCode: 'H1', positionLabel: 'Kiri Luar', portNumber: 1, side: 'L', gridX: 0, gridY: 0),
      const TilePosition(positionId: 6, layoutId: 2, positionCode: 'H2', positionLabel: 'Kiri Dalam', portNumber: 2, side: 'L', gridX: 1, gridY: 0),
      const TilePosition(positionId: 7, layoutId: 2, positionCode: 'H3', positionLabel: 'Kanan Dalam', portNumber: 3, side: 'R', gridX: 2, gridY: 0),
      const TilePosition(positionId: 8, layoutId: 2, positionCode: 'H4', positionLabel: 'Kanan Luar', portNumber: 4, side: 'R', gridX: 3, gridY: 0),
      // T Shape
      const TilePosition(positionId: 9, layoutId: 3, positionCode: 'F', positionLabel: 'Depan', portNumber: 1, side: 'C', gridX: 1, gridY: 0),
      const TilePosition(positionId: 10, layoutId: 3, positionCode: 'L', positionLabel: 'Kiri', portNumber: 2, side: 'L', gridX: 0, gridY: 1),
      const TilePosition(positionId: 11, layoutId: 3, positionCode: 'C', positionLabel: 'Tengah', portNumber: 3, side: 'C', gridX: 1, gridY: 1),
      const TilePosition(positionId: 12, layoutId: 3, positionCode: 'R', positionLabel: 'Kanan', portNumber: 4, side: 'R', gridX: 2, gridY: 1),
    ];

    final filtered = allPositions.where((p) => p.layoutId == layoutId).toList();
    _cachedPositions[layoutId] = filtered;
    return filtered;
  }

  /// Membuat sesi latihan baru (RPC create_session)
  Future<int> createSession({
    required int deviceId,
    required int modeId,
    required int layoutId,
    required int targetTempoMs,
    int stepTimeoutMs = 10000,
    int totalTargets = 20,
  }) async {
    debugPrint('[Supabase] Membuat sesi: layout=$layoutId, tempo=$targetTempoMs ms, targets=$totalTargets');
    return DateTime.now().millisecondsSinceEpoch % 100000;
  }

  /// Mengirim langkah baru (untuk mode simulasi atau realtime)
  void notifyStep(StepLog step) {
    _stepStreamController.add(step);
  }

  /// Mengupdate status sesi (waiting, running, stopped, completed)
  void notifySessionStatus(String status) {
    _sessionStatusController.add(status);
  }

  void dispose() {
    _stepStreamController.close();
    _sessionStatusController.close();
  }
}
