import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DeviceService {
  static const _channel = MethodChannel('com.steppinggrid.trainer/device');

  static Future<void> openWifiSettings() async {
    try {
      await _channel.invokeMethod('openWifiSettings');
    } catch (_) {}
  }

  static Future<void> openWifiPanel() async {
    try {
      await _channel.invokeMethod('openWifiPanel');
    } catch (_) {
      await openWifiSettings();
    }
  }

  static Future<bool> enableWifi() async {
    try {
      final res = await _channel.invokeMethod<bool>('enableWifi');
      return res ?? false;
    } catch (_) {
      await openWifiSettings();
      return false;
    }
  }

  static Future<bool> isWifiEnabled() async {
    try {
      final res = await _channel.invokeMethod<bool>('isWifiEnabled');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> vibrate({int durationMs = 100, bool enabled = true}) async {
    if (!enabled) return;
    try {
      HapticFeedback.mediumImpact();
      await _channel.invokeMethod('vibrateDevice', {'duration': durationMs});
    } catch (_) {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  static void playAudioFeedback({bool enabled = true}) {
    if (!enabled) return;
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}

void main() => runApp(const SteppingGridApp());

abstract final class AppColors {
  static const canvas = Color(0xFFF7F7F1);
  static const forest = Color(0xFF193A35);
  static const green = Color(0xFF126C5B);
  static const deepGreen = Color(0xFF104D42);
  static const lime = Color(0xFFD9EDB5);
  static const softGreen = Color(0xFFE8F2E9);
  static const muted = Color(0xFF586D66);
  static const border = Color(0xFFDFE7DD);
  static const soft = Color(0xFFF0F3EB);
  static const amberBg = Color(0xFFFFF7ED);
  static const amberBorder = Color(0xFFFED7AA);
  static const amberText = Color(0xFFC2410C);
}

class SessionRecord {
  final String id;
  final String modeName;
  final String dateText;
  final String durationText;
  final int totalSteps;
  final int accuracyPercent;
  final double avgReactionSeconds;
  final int bilateralSymmetry; // 50 means 50% left / 50% right
  final String clinicalNote;

  const SessionRecord({
    required this.id,
    required this.modeName,
    required this.dateText,
    required this.durationText,
    required this.totalSteps,
    required this.accuracyPercent,
    required this.avgReactionSeconds,
    this.bilateralSymmetry = 50,
    required this.clinicalNote,
  });
}

class SteppingGridApp extends StatelessWidget {
  const SteppingGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stepping Grid Trainer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
        ).copyWith(primary: AppColors.green, surface: AppColors.canvas),
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.forest),
          bodyMedium: TextStyle(color: AppColors.forest),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedTab = 0;
  bool _showTraining = false;
  bool _matrasConnected = false;
  bool _isCheckingCloud = false;
  double _fontScale = 1.0;
  String _selectedTextSizeLabel = 'Standar';

  // Profil Pasien
  String _patientName = 'Budi Santoso';
  String _patientAge = '58 tahun';
  String _patientCondition = 'Pasca-Stroke Hemiparesis Kiri';
  String _patientTherapist = 'dr. Ratna, Sp.KFR';
  int _dailyTargetMinutes = 10;
  String _reminderTime = '08:30 WIB';

  int _period = 0; // 0: Minggu ini, 1: Bulan ini, 2: Semua
  int _periodOffset = 0;
  String _activeHistoryFilter = 'Semua';

  final Map<String, bool> _preferences = {
    'contrast': false, // Mode normal standar secara default agar UX enak dan nyaman
    'reminders': false,
    'audio': true,
    'vibration': true,
  };

  // Riwayat Sesi Latihan Realistis
  final List<SessionRecord> _sessions = [
    const SessionRecord(
      id: 'SES-101',
      modeName: 'FSST 2x2',
      dateText: 'Hari ini, 08.30',
      durationText: '10 menit',
      totalSteps: 20,
      accuracyPercent: 85,
      avgReactionSeconds: 1.8,
      bilateralSymmetry: 50,
      clinicalNote:
          'Keseimbangan dinamis baik saat melangkah maju dan lateral. Ritme terjaga stabil.',
    ),
    const SessionRecord(
      id: 'SES-100',
      modeName: 'Lateral 1x4',
      dateText: 'Kemarin, 08.45',
      durationText: '10 menit',
      totalSteps: 28,
      accuracyPercent: 82,
      avgReactionSeconds: 2.0,
      bilateralSymmetry: 49,
      clinicalNote:
          'Langkah menyamping menunjukkan penambahan beban pada tungkai paretik sesuai target Hollands et al.',
    ),
    const SessionRecord(
      id: 'SES-099',
      modeName: 'Reactive T-Shape',
      dateText: '28 Okt, 09.00',
      durationText: '8 menit',
      totalSteps: 15,
      accuracyPercent: 80,
      avgReactionSeconds: 2.2,
      bilateralSymmetry: 48,
      clinicalNote:
          'Waktu reaksi responsif terhadap stimulus lampu acak ubin target.',
    ),
  ];

  // Periksa Status Matras SGT-01 ke Supabase REST API
  Future<void> _checkSupabaseDeviceStatus() async {
    setState(() => _isCheckingCloud = true);
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(
        Uri.parse(
          'https://rtvtralxxvzxitdqjrco.supabase.co/rest/v1/device?device_code=eq.SGT-01&select=*',
        ),
      );
      request.headers.set(
        'apikey',
        'sb_publishable_9Z8VFKtqUnlXfWyzXgMi3g_udj5JQ5r',
      );
      request.headers.set(
        'Authorization',
        'Bearer sb_publishable_9Z8VFKtqUnlXfWyzXgMi3g_udj5JQ5r',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final list = jsonDecode(body) as List<dynamic>;
        if (list.isNotEmpty) {
          final dev = list.first as Map<String, dynamic>;
          final lastSeen = DateTime.tryParse(dev['last_seen_at'] ?? '');
          final isRecent =
              lastSeen != null &&
              DateTime.now().difference(lastSeen).inMinutes < 5;
          setState(() {
            _matrasConnected = isRecent || dev['status'] == 'online';
            _isCheckingCloud = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _matrasConnected
                      ? 'Matras SGT-01 terdeteksi Online di Cloud Supabase!'
                      : 'Matras terdaftar di Cloud, namun saat ini sedang offline (Nyalakan matras).',
                ),
                backgroundColor:
                    _matrasConnected ? AppColors.green : Colors.orange.shade800,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
    } catch (_) {}
    setState(() => _isCheckingCloud = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak dapat menghubungi Cloud saat ini. Mengaktifkan Mode Matras Virtual.',
          ),
          backgroundColor: AppColors.green,
          duration: Duration(seconds: 3),
        ),
      );
      setState(() => _matrasConnected = true);
    }
  }

  void _openDeviceConnectionSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _DeviceConnectionSheet(
        isConnected: _matrasConnected,
        isCheckingCloud: _isCheckingCloud,
        onCheckCloud: _checkSupabaseDeviceStatus,
        onConnectDirect: () {
          setState(() => _matrasConnected = true);
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Matras SGT-01 Berhasil Terhubung ke ADVAN MF01-83405B!',
              ),
              backgroundColor: AppColors.green,
              duration: Duration(seconds: 3),
            ),
          );
        },
        onDisconnect: () {
          setState(() => _matrasConnected = false);
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Koneksi Matras Diputuskan'),
              backgroundColor: Colors.blueGrey,
              duration: Duration(seconds: 2),
            ),
          );
        },
        onToggleVirtual: (connected) {
          setState(() => _matrasConnected = connected);
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                connected
                    ? 'Mode Uji Coba Virtual Aktif (Matras Terhubung)'
                    : 'Mode Matras Dinonaktifkan',
              ),
              backgroundColor: connected ? AppColors.green : Colors.grey.shade700,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _showSessionDetail(SessionRecord session) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _SessionDetailDialog(session: session),
    );
  }

  void _openPatientProfileDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _PatientProfileDialog(
        currentName: _patientName,
        currentAge: _patientAge,
        currentCondition: _patientCondition,
        currentTherapist: _patientTherapist,
        currentTargetMinutes: _dailyTargetMinutes,
        onSave: (name, age, condition, therapist, target) {
          setState(() {
            _patientName = name;
            _patientAge = age;
            _patientCondition = condition;
            _patientTherapist = therapist;
            _dailyTargetMinutes = target;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil pasien berhasil diperbarui'),
              backgroundColor: AppColors.green,
            ),
          );
        },
      ),
    );
  }

  void _openTextSizeDialog() {
    double tempScale = _fontScale;
    String tempLabel = _selectedTextSizeLabel;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.format_size_rounded, color: AppColors.green),
              SizedBox(width: 10),
              Text(
                'Ukuran Teks',
                style: TextStyle(
                  color: AppColors.forest,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.soft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pratinjau Keterbacaan:',
                        style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Latihan langkah mandiri dengan matras interaktif untuk pemulihan stroke.',
                        style: TextStyle(
                          fontSize: 13 * tempScale,
                          color: AppColors.forest,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RadioListTile<double>(
                  title: const Text('Standar (100%)'),
                  subtitle: const Text('Ukuran teks normal bawaan'),
                  value: 1.0,
                  groupValue: tempScale,
                  activeColor: AppColors.green,
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        tempScale = val;
                        tempLabel = 'Standar';
                      });
                    }
                  },
                ),
                RadioListTile<double>(
                  title: const Text('Sedang (120%)'),
                  subtitle: const Text('Teks sedikit lebih besar'),
                  value: 1.20,
                  groupValue: tempScale,
                  activeColor: AppColors.green,
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        tempScale = val;
                        tempLabel = 'Sedang';
                      });
                    }
                  },
                ),
                RadioListTile<double>(
                  title: const Text('Besar (145%)'),
                  subtitle: const Text('Sangat jelas untuk lansia'),
                  value: 1.45,
                  groupValue: tempScale,
                  activeColor: AppColors.green,
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        tempScale = val;
                        tempLabel = 'Besar';
                      });
                    }
                  },
                ),
                RadioListTile<double>(
                  title: const Text('Sangat Besar (170%)'),
                  subtitle: const Text('Keterbacaan ekstra maksimal'),
                  value: 1.70,
                  groupValue: tempScale,
                  activeColor: AppColors.green,
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        tempScale = val;
                        tempLabel = 'Sangat Besar';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _fontScale = tempScale;
                  _selectedTextSizeLabel = tempLabel;
                });
                DeviceService.vibrate(durationMs: 80, enabled: _preferences['vibration'] ?? true);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ukuran teks diubah ke: $tempLabel (${(tempScale * 100).toInt()}%)'),
                    backgroundColor: AppColors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              child: const Text('Terapkan'),
            ),
          ],
        ),
      ),
    );
  }

  void _openReminderDialog() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
      helpText: 'PILIH JAM PENGINGAT LATIHAN HARIAN',
      confirmText: 'SIMPAN',
      cancelText: 'BATAL',
    );
    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minStr = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _reminderTime = '$hourStr:$minStr WIB';
        _preferences['reminders'] = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pengingat latihan disetel pukul $_reminderTime'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
  }

  void _showHelpCenter() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => const _HelpCenterDialog(),
    );
  }

  void _showSafetyGuidelines() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => const _SafetyGuidelinesDialog(),
    );
  }

  void _showPrivacyInfo() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => const _PrivacyInfoDialog(),
    );
  }

  Future<void> _confirmSignOut() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Keluar dari Akun?',
          style: TextStyle(
            color: AppColors.forest,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Data sesi latihan Anda telah tersinkronisasi aman ke Cloud Supabase.',
          style: TextStyle(color: AppColors.muted, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) {
      setState(() {
        _selectedTab = 0;
        _showTraining = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil keluar dari akun'),
          backgroundColor: AppColors.deepGreen,
        ),
      );
    }
  }

  void _handleSessionCompleted(SessionRecord newRecord) {
    setState(() {
      _sessions.insert(0, newRecord);
      _showTraining = false;
      _selectedTab = 1; // Beralih langsung ke tab Riwayat
    });

    // Kirim secara asinkron ke Supabase Cloud
    _uploadSessionToSupabase(newRecord);
  }

  Future<void> _uploadSessionToSupabase(SessionRecord rec) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final req = await client.postUrl(
        Uri.parse(
          'https://rtvtralxxvzxitdqjrco.supabase.co/rest/v1/training_session',
        ),
      );
      req.headers.set('Content-Type', 'application/json');
      req.headers.set(
        'apikey',
        'sb_publishable_9Z8VFKtqUnlXfWyzXgMi3g_udj5JQ5r',
      );
      req.headers.set(
        'Authorization',
        'Bearer sb_publishable_9Z8VFKtqUnlXfWyzXgMi3g_udj5JQ5r',
      );
      req.headers.set('Prefer', 'return=minimal');

      final modeId = rec.modeName.contains('FSST')
          ? 1
          : (rec.modeName.contains('Lateral') ? 2 : 3);

      req.write(
        jsonEncode({
          'user_id': 1,
          'device_id': 1,
          'mode_id': modeId,
          'session_status': 'completed',
        }),
      );
      await req.close().timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  void _handlePreferenceChanged(String key, bool value) {
    setState(() => _preferences[key] = value);
    if (key == 'contrast') {
      DeviceService.vibrate(durationMs: 80, enabled: _preferences['vibration'] ?? true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Mode Kontras Tinggi Diaktifkan (Visual Layar Dipertajam)'
                : 'Mode Kontras Standar Diaktifkan',
          ),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (key == 'vibration') {
      if (value) {
        DeviceService.vibrate(durationMs: 250, enabled: true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Getaran Aktif: HP akan bergetar saat ubin diinjak & tombol ditekan'
                : 'Getaran Dinonaktifkan',
          ),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (key == 'audio') {
      if (value) {
        DeviceService.playAudioFeedback(enabled: true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Audio Aba-aba Aktif: Nada umpan balik akan berbunyi saat latihan'
                : 'Audio Aba-aba Dinonaktifkan',
          ),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHC = _preferences['contrast'] ?? false;
    final scaffold = Scaffold(
      backgroundColor: isHC ? const Color(0xFF0F172A) : AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (isHC)
              Container(
                width: double.infinity,
                color: const Color(0xFFFFD600),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                child: const Center(
                  child: Text(
                    '👁️ MODE KONTRAS TINGGI AKTIF (VISUAL DIPERTAJAM)',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: SizedBox(
                            width: double.infinity,
                            height: constraints.maxHeight,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: _showTraining
                                  ? InteractiveTrainingScreen(
                                      isConnected: _matrasConnected,
                                      audioEnabled: _preferences['audio'] ?? true,
                                      vibrationEnabled: _preferences['vibration'] ?? true,
                                      onBack: () =>
                                          setState(() => _showTraining = false),
                                      onSessionFinished: _handleSessionCompleted,
                                    )
                                  : IndexedStack(
                                      key: ValueKey(_selectedTab),
                                      index: _selectedTab,
                                      children: [
                                        HomePage(
                                          patientName: _patientName,
                                          connected: _matrasConnected,
                                          onManageMat: _openDeviceConnectionSheet,
                                          onStartTraining: () =>
                                              setState(() => _showTraining = true),
                                          onShowHistory: () =>
                                              setState(() => _selectedTab = 1),
                                          recentSessions: _sessions.take(3).toList(),
                                          onSelectSession: _showSessionDetail,
                                        ),
                                        HistoryPage(
                                          period: _period,
                                          offset: _periodOffset,
                                          activeFilter: _activeHistoryFilter,
                                          sessions: _sessions,
                                          onFilterChanged: (filter) => setState(
                                            () => _activeHistoryFilter = filter,
                                          ),
                                          onPeriodChanged: (value) => setState(() {
                                            _period = value;
                                            _periodOffset = 0;
                                          }),
                                          onOffsetChanged: (value) =>
                                              setState(() => _periodOffset = value),
                                          onSelectSession: _showSessionDetail,
                                        ),
                                        SettingsPage(
                                          patientName: _patientName,
                                          patientCondition: _patientCondition,
                                          connected: _matrasConnected,
                                          textSizeLabel: _selectedTextSizeLabel,
                                          reminderTime: _reminderTime,
                                          preferences: _preferences,
                                          onEditProfile: _openPatientProfileDialog,
                                          onSelectTextSize: _openTextSizeDialog,
                                          onSetReminderTime: _openReminderDialog,
                                          onPreferenceChanged: _handlePreferenceChanged,
                                          onManageMat: _openDeviceConnectionSheet,
                                          onShowHelp: _showHelpCenter,
                                          onShowSafety: _showSafetyGuidelines,
                                          onShowPrivacy: _showPrivacyInfo,
                                          onSignOut: _confirmSignOut,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        bottomNavigationBar: _showTraining
            ? null
            : LayoutBuilder(
                builder: (context, _) {
                  return Align(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SizedBox(
                        width: double.infinity,
                        child: SafeArea(
                          top: false,
                          child: AppBottomNavigation(
                            selected: _selectedTab,
                            onSelected: (index) =>
                                setState(() => _selectedTab = index),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(_fontScale),
      ),
      child: isHC
          ? ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                1.35, 0, 0, 0, -25,
                0, 1.35, 0, 0, -25,
                0, 0, 1.35, 0, -25,
                0, 0, 0, 1, 0,
              ]),
              child: scaffold,
            )
          : scaffold,
    );
  }
}

// ==============================================================================
// BOTTOM NAVIGATION
// ==============================================================================
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.border, width: 1)),
    ),
    child: Row(
      children: [
        Expanded(
          child: _NavTab(
            label: 'Beranda',
            icon: 'assets/figma/home_House.svg',
            active: selected == 0,
            onTap: () => onSelected(0),
          ),
        ),
        Expanded(
          child: _NavTab(
            label: 'Riwayat',
            icon: 'assets/figma/home_History.svg',
            active: selected == 1,
            onTap: () => onSelected(1),
          ),
        ),
        Expanded(
          child: _NavTab(
            label: 'Pengaturan',
            icon: 'assets/figma/home_Settings.svg',
            active: selected == 2,
            onTap: () => onSelected(2),
          ),
        ),
      ],
    ),
  );
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green : AppColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              icon,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// COMMON REUSABLE COMPONENTS
// ==============================================================================
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.backgroundColor = Colors.white,
    this.borderColor = AppColors.border,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor),
    ),
    child: child,
  );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.grid_view_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
      const SizedBox(width: 10),
      const Expanded(
        child: Text(
          'Stepping Grid\nTrainer',
          style: TextStyle(
            color: AppColors.forest,
            fontSize: 16,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.softGreen,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 14, color: AppColors.green),
            SizedBox(width: 4),
            Text(
              'v1.0 Produksi',
              style: TextStyle(
                color: AppColors.green,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ==============================================================================
// BERANDA (HOME PAGE)
// ==============================================================================
class HomePage extends StatelessWidget {
  const HomePage({
    required this.patientName,
    required this.connected,
    required this.onManageMat,
    required this.onStartTraining,
    required this.onShowHistory,
    required this.recentSessions,
    required this.onSelectSession,
    super.key,
  });

  final String patientName;
  final bool connected;
  final VoidCallback onManageMat;
  final VoidCallback onStartTraining;
  final VoidCallback onShowHistory;
  final List<SessionRecord> recentSessions;
  final ValueChanged<SessionRecord> onSelectSession;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandHeader(),
        const SizedBox(height: 24),
        const Text(
          'Minggu, 1 November 2026',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Halo, $patientName!',
          style: const TextStyle(
            color: AppColors.forest,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Selangkah lagi, bersama-sama.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 16,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),

        // BANNER STATUS MATRAS YANG REAKTIF (KLIK UNTUK BUKA PANDUAN KONEKSI)
        InkWell(
          onTap: onManageMat,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: connected ? AppColors.softGreen : AppColors.amberBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: connected
                    ? AppColors.green.withValues(alpha: 0.3)
                    : AppColors.amberBorder,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: connected ? Colors.white : const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: connected ? AppColors.green : AppColors.amberText,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connected
                            ? 'Matras SGT-01 Terhubung'
                            : 'Matras Belum Terhubung',
                        style: TextStyle(
                          color: connected
                              ? AppColors.forest
                              : AppColors.amberText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        connected
                            ? 'ADVAN MF01-83405B · Siap digunakan'
                            : 'SGT-01 · Ketuk untuk hubungkan via Wi-Fi',
                        style: TextStyle(
                          color: connected
                              ? AppColors.muted
                              : const Color(0xFF9A3412),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: connected ? AppColors.green : AppColors.amberText,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        connected ? 'Siap' : 'Hubungkan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        connected
                            ? Icons.check
                            : Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 22),
        InkWell(
          onTap: onShowHistory,
          borderRadius: BorderRadius.circular(22),
          child: const DailySummaryCard(),
        ),
        const SizedBox(height: 22),
        _RecommendationCard(onStart: onStartTraining),
        const SizedBox(height: 22),
        _WeeklyProgressCard(onShowHistory: onShowHistory),
        const SizedBox(height: 22),
        _RecentSessions(
          sessions: recentSessions,
          onShowHistory: onShowHistory,
          onSelectSession: onSelectSession,
        ),
      ],
    ),
  );
}

class DailySummaryCard extends StatelessWidget {
  const DailySummaryCard({super.key});

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Hari ini',
                style: TextStyle(
                  color: AppColors.forest,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: AppColors.green),
                  SizedBox(width: 5),
                  Text(
                    '1 sesi selesai',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: _MetricItem(
                icon: Icons.track_changes_rounded,
                value: '85%',
                label: 'Akurasi langkah',
                caption: '+3 poin dari sesi lalu',
              ),
            ),
            Container(width: 1, height: 90, color: AppColors.border),
            const SizedBox(width: 16),
            const Expanded(
              child: _MetricItem(
                icon: Icons.timer_outlined,
                value: '1,8 dtk',
                label: 'Rata-rata reaksi',
                caption: 'Waktu respons langkah',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 14),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Target harian tercapai',
              style: TextStyle(
                color: AppColors.forest,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '10 / 10 menit',
              style: TextStyle(
                color: AppColors.forest,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: const LinearProgressIndicator(
            value: 1.0,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
          ),
        ),
      ],
    ),
  );
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final String value;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.green, size: 22),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.forest,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          color: AppColors.forest,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        caption,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF134E4A), Color(0xFF0F766E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.lime, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Rekomendasi Terapi AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'FSST 2x2 (Four Square Step)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '40 langkah/menit · 10 menit latihan',
          style: TextStyle(
            color: AppColors.lime,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Melatih koordinasi langkah multi-arah dan pemindahan beban seimbang sesuai protokol klinis.',
          style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(
              Icons.play_arrow_rounded,
              color: AppColors.deepGreen,
              size: 26,
            ),
            label: const Text(
              'Mulai Latihan Sekarang',
              style: TextStyle(
                color: AppColors.deepGreen,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.lime,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({required this.onShowHistory});
  final VoidCallback onShowHistory;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Perkembangan Minggu Ini',
              style: TextStyle(
                color: AppColors.forest,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            InkWell(
              onTap: onShowHistory,
              child: const Text(
                'Detail >',
                style: TextStyle(
                  color: AppColors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            _DayCol(day: 'Sen', completed: true),
            _DayCol(day: 'Sel', completed: true),
            _DayCol(day: 'Rab', completed: true),
            _DayCol(day: 'Kam', completed: false),
            _DayCol(day: 'Jum', completed: true),
            _DayCol(day: 'Sab', completed: true),
            _DayCol(day: 'Min', completed: true, isToday: true),
          ],
        ),
      ],
    ),
  );
}

class _DayCol extends StatelessWidget {
  const _DayCol({
    required this.day,
    required this.completed,
    this.isToday = false,
  });

  final String day;
  final bool completed;
  final bool isToday;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: completed
              ? AppColors.green
              : (isToday ? AppColors.softGreen : const Color(0xFFF1F5F9)),
          shape: BoxShape.circle,
          border: isToday ? Border.all(color: AppColors.green, width: 2) : null,
        ),
        alignment: Alignment.center,
        child: completed
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                isToday ? '•' : '',
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
      const SizedBox(height: 6),
      Text(
        day,
        style: TextStyle(
          color: isToday ? AppColors.green : AppColors.muted,
          fontSize: 12,
          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    ],
  );
}

class _RecentSessions extends StatelessWidget {
  const _RecentSessions({
    required this.sessions,
    required this.onShowHistory,
    required this.onSelectSession,
  });

  final List<SessionRecord> sessions;
  final VoidCallback onShowHistory;
  final ValueChanged<SessionRecord> onSelectSession;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Latihan Terakhir',
            style: TextStyle(
              color: AppColors.forest,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          InkWell(
            onTap: onShowHistory,
            child: const Text(
              'Semua >',
              style: TextStyle(
                color: AppColors.green,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ...sessions.map(
        (s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => onSelectSession(s),
            borderRadius: BorderRadius.circular(16),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.softGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.directions_walk_rounded,
                      color: AppColors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.modeName,
                          style: const TextStyle(
                            color: AppColors.forest,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.dateText} · ${s.totalSteps} langkah',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${s.accuracyPercent}%',
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${s.avgReactionSeconds}s',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

// ==============================================================================
// RIWAYAT LATIHAN (HISTORY PAGE)
// ==============================================================================
class HistoryPage extends StatelessWidget {
  const HistoryPage({
    required this.period,
    required this.offset,
    required this.activeFilter,
    required this.sessions,
    required this.onFilterChanged,
    required this.onPeriodChanged,
    required this.onOffsetChanged,
    required this.onSelectSession,
    super.key,
  });

  final int period;
  final int offset;
  final String activeFilter;
  final List<SessionRecord> sessions;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<int> onPeriodChanged;
  final ValueChanged<int> onOffsetChanged;
  final ValueChanged<SessionRecord> onSelectSession;

  @override
  Widget build(BuildContext context) {
    final filteredList = activeFilter == 'Semua'
        ? sessions
        : sessions.where((s) => s.modeName.contains(activeFilter)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandHeader(),
          const SizedBox(height: 24),
          const Text(
            'Riwayat Latihan',
            style: TextStyle(
              color: AppColors.forest,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Rekam jejak latihan motorik dan keseimbangan Anda.',
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
          const SizedBox(height: 20),

          // Pilihan Periode
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _PeriodTab(
                  label: 'Minggu ini',
                  active: period == 0,
                  onTap: () => onPeriodChanged(0),
                ),
                _PeriodTab(
                  label: 'Bulan ini',
                  active: period == 1,
                  onTap: () => onPeriodChanged(1),
                ),
                _PeriodTab(
                  label: 'Semua',
                  active: period == 2,
                  onTap: () => onPeriodChanged(2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ringkasan Periode
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ringkasan Periode',
                      style: TextStyle(
                        color: AppColors.forest,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.softGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${filteredList.length} sesi',
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryStat(
                        label: 'Total Langkah',
                        val:
                            '${filteredList.fold(0, (acc, s) => acc + s.totalSteps)}',
                      ),
                    ),
                    Container(width: 1, height: 40, color: AppColors.border),
                    Expanded(
                      child: _SummaryStat(
                        label: 'Rata-rata Akurasi',
                        val: filteredList.isEmpty
                            ? '0%'
                            : '${(filteredList.fold(0, (acc, s) => acc + s.accuracyPercent) / filteredList.length).round()}%',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Filter Mode Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Semua',
                  active: activeFilter == 'Semua',
                  onTap: () => onFilterChanged('Semua'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'FSST 2x2',
                  active: activeFilter == 'FSST',
                  onTap: () => onFilterChanged('FSST'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Lateral 1x4',
                  active: activeFilter == 'Lateral',
                  onTap: () => onFilterChanged('Lateral'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Reactive T',
                  active: activeFilter == 'Reactive',
                  onTap: () => onFilterChanged('Reactive'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Daftar Sesi
          if (filteredList.isEmpty)
            const AppCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 40,
                        color: AppColors.muted,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Belum ada riwayat pada kategori ini',
                        style: TextStyle(color: AppColors.muted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...filteredList.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => onSelectSession(s),
                  borderRadius: BorderRadius.circular(18),
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.softGreen,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.directions_walk_rounded,
                                    color: AppColors.green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.modeName,
                                      style: const TextStyle(
                                        color: AppColors.forest,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      s.dateText,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.softGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${s.accuracyPercent}% Akurasi',
                                style: const TextStyle(
                                  color: AppColors.green,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Langkah: ${s.totalSteps}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Reaksi: ${s.avgReactionSeconds}s',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Simetri: ${s.bilateralSymmetry}%',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                            const Text(
                              'Detail ›',
                              style: TextStyle(
                                color: AppColors.green,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.forest : AppColors.muted,
            fontSize: 13,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.val});
  final String label;
  final String val;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        val,
        style: const TextStyle(
          color: AppColors.forest,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        label,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: active ? AppColors.green : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppColors.green : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : AppColors.forest,
          fontSize: 13,
          fontWeight: active ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    ),
  );
}

// ==============================================================================
// PENGATURAN (SETTINGS PAGE)
// ==============================================================================
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.patientName,
    required this.patientCondition,
    required this.connected,
    required this.textSizeLabel,
    required this.reminderTime,
    required this.preferences,
    required this.onEditProfile,
    required this.onSelectTextSize,
    required this.onSetReminderTime,
    required this.onPreferenceChanged,
    required this.onManageMat,
    required this.onShowHelp,
    required this.onShowSafety,
    required this.onShowPrivacy,
    required this.onSignOut,
    super.key,
  });

  final String patientName;
  final String patientCondition;
  final bool connected;
  final String textSizeLabel;
  final String reminderTime;
  final Map<String, bool> preferences;
  final VoidCallback onEditProfile;
  final VoidCallback onSelectTextSize;
  final VoidCallback onSetReminderTime;
  final void Function(String, bool) onPreferenceChanged;
  final VoidCallback onManageMat;
  final VoidCallback onShowHelp;
  final VoidCallback onShowSafety;
  final VoidCallback onShowPrivacy;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandHeader(),
        const SizedBox(height: 24),
        const Text(
          'Pengaturan',
          style: TextStyle(
            color: AppColors.forest,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Atur preferensi latihan dan integrasi perangkat Anda.',
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
        const SizedBox(height: 20),

        // Profil Pasien Card
        InkWell(
          onTap: onEditProfile,
          borderRadius: BorderRadius.circular(20),
          child: AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          color: AppColors.forest,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        patientCondition,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.edit_outlined,
                  color: AppColors.green,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        const Text(
          'Matras IoT',
          style: TextStyle(
            color: AppColors.forest,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          connected ? AppColors.softGreen : AppColors.amberBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      color: connected ? AppColors.green : AppColors.amberText,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Matras Stepping Grid (SGT-01)',
                          style: TextStyle(
                            color: AppColors.forest,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          connected
                              ? 'Terhubung ke ADVAN MF01-83405B'
                              : 'Belum terhubung ke Wi-Fi MiFi',
                          style: TextStyle(
                            color: connected
                                ? AppColors.green
                                : AppColors.amberText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Firmware',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  Text(
                    'v1.0.0 (ESP32 DevKit)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Gateway MiFi',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  Text(
                    '192.168.0.1',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onManageMat,
                  icon: const Icon(
                    Icons.settings_input_antenna_rounded,
                    size: 18,
                  ),
                  label: Text(
                    connected
                        ? 'Kelola Koneksi Wi-Fi'
                        : 'Atur Koneksi Wi-Fi Matras',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.green,
                    side: const BorderSide(color: AppColors.green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Text(
          'Tampilan & Kenyamanan',
          style: TextStyle(
            color: AppColors.forest,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.format_size_rounded,
                  color: AppColors.green,
                ),
                title: const Text(
                  'Ukuran Teks',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Sesuaikan kenyamanan membaca lansia'),
                trailing: Text(
                  '$textSizeLabel ›',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: onSelectTextSize,
              ),
              const Divider(color: AppColors.border, height: 1),
              SwitchListTile(
                secondary: const Icon(
                  Icons.contrast_rounded,
                  color: AppColors.green,
                ),
                title: const Text(
                  'Kontras Tinggi',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Pertajam kontras elemen visual layar'),
                value: preferences['contrast'] ?? false,
                activeColor: AppColors.green,
                onChanged: (val) => onPreferenceChanged('contrast', val),
              ),
              const Divider(color: AppColors.border, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.alarm_rounded,
                  color: AppColors.green,
                ),
                title: const Text(
                  'Pengingat Latihan Harian',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('Jadwal: $reminderTime'),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.muted,
                ),
                onTap: onSetReminderTime,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Text(
          'Umpan Balik Latihan',
          style: TextStyle(
            color: AppColors.forest,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(
                  Icons.volume_up_rounded,
                  color: AppColors.green,
                ),
                title: const Text(
                  'Suara Aba-aba (Audio Umpan Balik)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Bunyi nada saat injakan benar & selesai'),
                value: preferences['audio'] ?? true,
                activeColor: AppColors.green,
                onChanged: (val) => onPreferenceChanged('audio', val),
              ),
              const Divider(color: AppColors.border, height: 1),
              SwitchListTile(
                secondary: const Icon(
                  Icons.vibration_rounded,
                  color: AppColors.green,
                ),
                title: const Text(
                  'Getaran Perangkat HP (Haptic)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('HP bergetar di tangan saat ubin diinjak & ditekan'),
                value: preferences['vibration'] ?? true,
                activeColor: AppColors.green,
                onChanged: (val) => onPreferenceChanged('vibration', val),
              ),
              const Divider(color: AppColors.border, height: 1),
              SwitchListTile(
                secondary: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppColors.green,
                ),
                title: const Text(
                  'Petunjuk Lampu LED Matras (74HC595)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle:
                    const Text('Pola LED menyala pada ubin target matras fisik'),
                value: preferences['led'] ?? true,
                activeColor: AppColors.green,
                onChanged: (val) => onPreferenceChanged('led', val),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Text(
          'Informasi & Bantuan',
          style: TextStyle(
            color: AppColors.forest,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.help_outline_rounded,
                  color: AppColors.green,
                ),
                title: const Text(
                  'Pusat Bantuan & Panduan Matras',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.muted,
                ),
                onTap: onShowHelp,
              ),
              const Divider(color: AppColors.border, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.health_and_safety_rounded,
                  color: AppColors.green,
                ),
                title: const Text(
                  'Protokol Keamanan Rehabilitasi',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.muted,
                ),
                onTap: onShowSafety,
              ),
              const Divider(color: AppColors.border, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.security_rounded,
                  color: AppColors.green,
                ),
                title: const Text(
                  'Keamanan Data Medis (Supabase)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.muted,
                ),
                onTap: onShowPrivacy,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            label: const Text(
              'Keluar dari Akun',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Stepping Grid Trainer · Versi 1.0.0 (Produksi)',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

// ==============================================================================
// MODAL BOTTOM SHEET: KONEKSI WI-FI & ESP32 MATRAS
// ==============================================================================
class _DeviceConnectionSheet extends StatefulWidget {
  const _DeviceConnectionSheet({
    required this.isConnected,
    required this.isCheckingCloud,
    required this.onCheckCloud,
    required this.onConnectDirect,
    required this.onDisconnect,
    required this.onToggleVirtual,
  });

  final bool isConnected;
  final bool isCheckingCloud;
  final VoidCallback onCheckCloud;
  final VoidCallback onConnectDirect;
  final VoidCallback onDisconnect;
  final ValueChanged<bool> onToggleVirtual;

  @override
  State<_DeviceConnectionSheet> createState() => _DeviceConnectionSheetState();
}

class _DeviceConnectionSheetState extends State<_DeviceConnectionSheet> {
  bool _isWifiOn = true;
  bool _isCheckingDevice = true;

  @override
  void initState() {
    super.initState();
    _checkDeviceWifiState();
  }

  Future<void> _checkDeviceWifiState() async {
    final enabled = await DeviceService.isWifiEnabled();
    if (mounted) {
      setState(() {
        _isWifiOn = enabled;
        _isCheckingDevice = false;
      });
    }
  }

  void _copyPassword() {
    Clipboard.setData(const ClipboardData(text: '085848719373'));
    DeviceService.vibrate(durationMs: 80, enabled: true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kata sandi "085848719373" berhasil disalin ke clipboard!'),
        backgroundColor: AppColors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openDeviceWifiPanel() async {
    await Clipboard.setData(const ClipboardData(text: '085848719373'));
    await DeviceService.vibrate(durationMs: 100, enabled: true);
    await DeviceService.enableWifi();
    await DeviceService.openWifiPanel();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Membuka panel Wi-Fi HP... Sandi (085848719373) otomatis disalin! Silakan pilih "ADVAN MF01-83405B".',
          ),
          backgroundColor: AppColors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }
    await Future.delayed(const Duration(seconds: 2));
    _checkDeviceWifiState();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Koneksi Matras IoT',
                style: TextStyle(
                  color: AppColors.forest,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isConnected ? AppColors.softGreen : AppColors.amberBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.isConnected ? 'Matras Online' : 'Matras Offline',
                  style: TextStyle(
                    color: widget.isConnected ? AppColors.green : AppColors.amberText,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status Hardware Wi-Fi HP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _isWifiOn ? AppColors.softGreen : AppColors.amberBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isWifiOn ? AppColors.green : AppColors.amberBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isWifiOn ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: _isWifiOn ? AppColors.green : AppColors.amberText,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCheckingDevice
                            ? 'Memeriksa Wi-Fi HP...'
                            : (_isWifiOn ? 'Wi-Fi HP: Aktif / Menyala' : 'Wi-Fi HP: Mati / Nonaktif'),
                        style: TextStyle(
                          color: _isWifiOn ? AppColors.forest : AppColors.amberText,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _isWifiOn
                            ? 'Siap tersambung ke router ADVAN MF01'
                            : 'Nyalakan Wi-Fi untuk menghubungkan ke matras',
                        style: const TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _openDeviceWifiPanel,
                  child: const Text('Buka', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Informasi Jaringan MiFi ADVAN MF01
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.soft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const _WifiInfoRow(
                  label: 'Nama SSID (MiFi)',
                  value: 'ADVAN MF01-83405B',
                  icon: Icons.wifi,
                ),
                const SizedBox(height: 8),
                _WifiInfoRow(
                  label: 'Kata Sandi',
                  value: '085848719373',
                  icon: Icons.key_rounded,
                  isCopyable: true,
                ),
                const SizedBox(height: 8),
                const _WifiInfoRow(
                  label: 'IP Gateway Router',
                  value: '192.168.0.1',
                  icon: Icons.router_rounded,
                ),
                const SizedBox(height: 8),
                const _WifiInfoRow(
                  label: 'ID Perangkat',
                  value: 'SGT-01 (ESP32 DevKit)',
                  icon: Icons.memory_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tombol 1: Nyalakan Wi-Fi & Buka Sambungan HP (Akses Nyata Hardware)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _openDeviceWifiPanel,
              icon: const Icon(Icons.wifi_find_rounded, size: 20),
              label: const Text(
                '⚡ Nyalakan & Buka Menu Wi-Fi HP',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Tombol 2: Hubungkan / Putuskan Matras
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: widget.isConnected ? widget.onDisconnect : widget.onConnectDirect,
              icon: Icon(
                widget.isConnected ? Icons.link_off_rounded : Icons.link_rounded,
                size: 20,
              ),
              label: Text(
                widget.isConnected
                    ? 'Putuskan Koneksi Matras'
                    : 'Hubungkan ke Matras (ADVAN MF01)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    widget.isConnected ? Colors.blueGrey : AppColors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Tombol 3: Salin Kata Sandi Wi-Fi
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _copyPassword,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text(
                'Salin Kata Sandi (085848719373)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Tombol 4: Cek Status Cloud
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: widget.isCheckingCloud ? null : widget.onCheckCloud,
              icon: widget.isCheckingCloud
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync_rounded, size: 20),
              label: Text(
                widget.isCheckingCloud
                    ? 'Memeriksa Cloud Supabase...'
                    : 'Periksa Status Matras di Cloud',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.green,
                side: const BorderSide(color: AppColors.green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Mode Uji Coba Virtual
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.isConnected ? AppColors.softGreen : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode Uji Coba Virtual',
                        style: TextStyle(
                          color: AppColors.forest,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Uji latihan langsung di layar tanpa matras fisik',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: widget.isConnected,
                  activeColor: AppColors.green,
                  onChanged: (val) {
                    widget.onToggleVirtual(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Panduan Sambungan 3 Langkah:',
            style: TextStyle(
              color: AppColors.forest,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Nyalakan MiFi ADVAN MF01 Anda.\n'
            '2. Pastikan HP dan Matras ESP32 terhubung ke Wi-Fi ADVAN MF01-83405B.\n'
            '3. Tekan "Hubungkan ke Matras" di atas untuk menghubungkan aplikasi.',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Tutup',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WifiInfoRow extends StatelessWidget {
  const _WifiInfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.isCopyable = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isCopyable;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.green),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      const Spacer(),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.forest,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      if (isCopyable) ...[
        const SizedBox(width: 6),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            DeviceService.vibrate(durationMs: 60, enabled: true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label ($value) disalin!'),
                duration: const Duration(seconds: 2),
                backgroundColor: AppColors.green,
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.copy_rounded, size: 16, color: AppColors.green),
          ),
        ),
      ],
    ],
  );
}

// ==============================================================================
// LAYAR LATIHAN INTERAKTIF (TRAINING SCREEN DENGAN SENSOR/UBIN SIMULASI)
// ==============================================================================
class InteractiveTrainingScreen extends StatefulWidget {
  const InteractiveTrainingScreen({
    required this.isConnected,
    this.audioEnabled = true,
    this.vibrationEnabled = true,
    required this.onBack,
    required this.onSessionFinished,
    super.key,
  });

  final bool isConnected;
  final bool audioEnabled;
  final bool vibrationEnabled;
  final VoidCallback onBack;
  final ValueChanged<SessionRecord> onSessionFinished;

  @override
  State<InteractiveTrainingScreen> createState() =>
      _InteractiveTrainingScreenState();
}

class _InteractiveTrainingScreenState extends State<InteractiveTrainingScreen>
    with SingleTickerProviderStateMixin {
  int _selectedModeIndex = 0; // 0: FSST 2x2, 1: Lateral 1x4, 2: Reactive T
  bool _isRunning = false;
  int _currentStep = 0;
  int _totalSteps = 5;
  int _targetTile = 1; // 1, 2, 3, atau 4
  int _correctHits = 0;
  int _wrongHits = 0;

  Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  double _elapsedSeconds = 0.0;

  // Reactive Mode specific
  bool _isWaitingForHome = true;
  int _reactiveRound = 0;
  final int _maxReactiveRounds = 5;
  DateTime? _roundStartTime;
  double _totalReactionSeconds = 0.0;

  final List<int> _fsstSequence = [1, 2, 4, 3, 1];
  final List<int> _lateralSequence = [1, 2, 3, 4, 3, 2, 1];

  // Animasi Panduan Langkah (Demo) & Pulsing Glow
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  bool _isDemoActive = false;
  int _demoStepIndex = 0;
  Timer? _demoTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _demoTimer?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _onSelectMode(int index) {
    if (_isRunning) return;
    setState(() {
      _selectedModeIndex = index;
      _demoStepIndex = 0;
      if (index == 0) {
        _targetTile = _fsstSequence[0];
        _totalSteps = _fsstSequence.length;
      } else if (index == 1) {
        _targetTile = _lateralSequence[0];
        _totalSteps = _lateralSequence.length;
      } else {
        _targetTile = 1;
        _totalSteps = _maxReactiveRounds;
        _isWaitingForHome = true;
      }
    });
    DeviceService.vibrate(
      durationMs: 60,
      enabled: widget.vibrationEnabled,
    );
  }

  void _toggleDemoAnimation() {
    if (_isRunning) return;
    setState(() {
      _isDemoActive = !_isDemoActive;
      _demoStepIndex = 0;
    });

    if (_isDemoActive) {
      DeviceService.vibrate(durationMs: 40, enabled: widget.vibrationEnabled);
      _demoTimer?.cancel();
      _demoTimer = Timer.periodic(const Duration(milliseconds: 950), (t) {
        if (!mounted) return;
        setState(() {
          if (_selectedModeIndex == 0) {
            _demoStepIndex = (_demoStepIndex + 1) % _fsstSequence.length;
          } else if (_selectedModeIndex == 1) {
            _demoStepIndex = (_demoStepIndex + 1) % _lateralSequence.length;
          } else {
            _demoStepIndex = (_demoStepIndex + 1) % 2;
          }
        });
        DeviceService.vibrate(durationMs: 30, enabled: widget.vibrationEnabled);
        DeviceService.playAudioFeedback(enabled: widget.audioEnabled);
      });
    } else {
      _demoTimer?.cancel();
    }
  }

  int get _activeHighlightedTile {
    if (_isRunning) {
      if (_selectedModeIndex == 2 && _isWaitingForHome) {
        return 1;
      }
      return _targetTile;
    }
    if (_isDemoActive) {
      if (_selectedModeIndex == 0) {
        return _fsstSequence[_demoStepIndex];
      } else if (_selectedModeIndex == 1) {
        return _lateralSequence[_demoStepIndex];
      } else {
        return _demoStepIndex == 0 ? 1 : 3;
      }
    }
    return _targetTile;
  }

  void _startTraining() {
    if (_isDemoActive) {
      _demoTimer?.cancel();
      _isDemoActive = false;
    }
    setState(() {
      _isRunning = true;
      _currentStep = 0;
      _correctHits = 0;
      _wrongHits = 0;
      _elapsedSeconds = 0.0;
      _reactiveRound = 0;
      _totalReactionSeconds = 0.0;
      _isWaitingForHome = true;

      if (_selectedModeIndex == 0) {
        _totalSteps = _fsstSequence.length;
        _targetTile = _fsstSequence[0];
      } else if (_selectedModeIndex == 1) {
        _totalSteps = _lateralSequence.length;
        _targetTile = _lateralSequence[0];
      } else {
        _totalSteps = _maxReactiveRounds;
        _targetTile = 1; // Standby di Ubin 1
      }
    });

    DeviceService.vibrate(durationMs: 150, enabled: widget.vibrationEnabled);
    DeviceService.playAudioFeedback(enabled: widget.audioEnabled);

    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds = _stopwatch.elapsedMilliseconds / 1000.0;
      });
    });
  }

  void _onTileStepped(int tileNumber) {
    if (!_isRunning) return;

    if (_selectedModeIndex == 0 || _selectedModeIndex == 1) {
      // Sekuensial FSST atau Lateral
      if (tileNumber == _targetTile) {
        DeviceService.vibrate(durationMs: 80, enabled: widget.vibrationEnabled);
        DeviceService.playAudioFeedback(enabled: widget.audioEnabled);
        _correctHits++;
        final nextStep = _currentStep + 1;
        if ((_selectedModeIndex == 0 && nextStep >= _fsstSequence.length) ||
            (_selectedModeIndex == 1 && nextStep >= _lateralSequence.length)) {
          DeviceService.vibrate(durationMs: 350, enabled: widget.vibrationEnabled);
          _finishTraining();
        } else {
          setState(() {
            _currentStep = nextStep;
            _targetTile = _selectedModeIndex == 0
                ? _fsstSequence[_currentStep]
                : _lateralSequence[_currentStep];
          });
        }
      } else {
        DeviceService.vibrate(durationMs: 220, enabled: widget.vibrationEnabled);
        setState(() => _wrongHits++);
      }
    } else {
      // Reactive T-Shape Mode
      if (_isWaitingForHome) {
        if (tileNumber == 1) {
          DeviceService.vibrate(durationMs: 80, enabled: widget.vibrationEnabled);
          DeviceService.playAudioFeedback(enabled: widget.audioEnabled);
          final randTarget = Random().nextInt(3) + 2; // Acak ubin 2, 3, atau 4
          setState(() {
            _isWaitingForHome = false;
            _targetTile = randTarget;
            _roundStartTime = DateTime.now();
          });
        }
      } else {
        if (tileNumber == _targetTile) {
          DeviceService.vibrate(durationMs: 80, enabled: widget.vibrationEnabled);
          DeviceService.playAudioFeedback(enabled: widget.audioEnabled);
          final rt =
              DateTime.now().difference(_roundStartTime!).inMilliseconds /
              1000.0;
          _totalReactionSeconds += rt;
          _correctHits++;
          final nextRound = _reactiveRound + 1;

          if (nextRound >= _maxReactiveRounds) {
            DeviceService.vibrate(durationMs: 350, enabled: widget.vibrationEnabled);
            _finishTraining();
          } else {
            setState(() {
              _reactiveRound = nextRound;
              _isWaitingForHome = true;
              _targetTile = 1;
            });
          }
        } else {
          DeviceService.vibrate(durationMs: 220, enabled: widget.vibrationEnabled);
          setState(() => _wrongHits++);
        }
      }
    }
  }

  void _finishTraining() {
    _stopwatch.stop();
    _timer?.cancel();
    setState(() => _isRunning = false);

    final totalAttempts = _correctHits + _wrongHits;
    final accuracy = totalAttempts > 0
        ? ((_correctHits / totalAttempts) * 100).round()
        : 100;
    final avgRt = _selectedModeIndex == 2
        ? (_totalReactionSeconds / _maxReactiveRounds)
        : (_elapsedSeconds / (_totalSteps > 0 ? _totalSteps : 1));

    final modeNames = ['FSST 2x2', 'Lateral 1x4', 'Reactive T-Shape'];
    final sessionRecord = SessionRecord(
      id: 'SES-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      modeName: modeNames[_selectedModeIndex],
      dateText: 'Hari ini, ${TimeOfDay.now().format(context)}',
      durationText: '${_elapsedSeconds.toStringAsFixed(1)} detik',
      totalSteps: _selectedModeIndex == 2 ? _maxReactiveRounds : _totalSteps,
      accuracyPercent: accuracy,
      avgReactionSeconds: double.parse(avgRt.toStringAsFixed(2)),
      bilateralSymmetry: 50,
      clinicalNote: _selectedModeIndex == 2
          ? 'Respons refleks terhadap stimulus acak: ${avgRt.toStringAsFixed(2)} detik per target.'
          : 'Sesi latihan sekuensial berhasil diselesaikan dengan akurasi $accuracy%.',
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.green, size: 28),
            SizedBox(width: 10),
            Text(
              'Latihan Selesai!',
              style: TextStyle(
                color: AppColors.forest,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selamat! Anda telah menyelesaikan protokol latihan ${modeNames[_selectedModeIndex]}.',
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.soft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Waktu:', style: TextStyle(color: AppColors.muted)),
                      Text(
                        '${_elapsedSeconds.toStringAsFixed(1)} dtk',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Akurasi Langkah:', style: TextStyle(color: AppColors.muted)),
                      Text(
                        '$accuracy%',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedModeIndex == 2 ? 'Rata-rata Waktu Reaksi:' : 'Waktu / Langkah:',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      Text(
                        '${avgRt.toStringAsFixed(2)} dtk',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.cloud_done_rounded,
                    color: AppColors.green,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tersimpan aman & sinkronisasi ke Supabase',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onSessionFinished(sessionRecord);
            },
            child: const Text('Lihat di Riwayat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeNames = ['FSST 2×2', 'Lateral 1×4', 'Reactive T'];
    final modeIcons = [
      Icons.grid_view_rounded,
      Icons.view_column_rounded,
      Icons.gamepad_rounded,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Latihan Matras',
                style: TextStyle(
                  color: AppColors.forest,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pilihan Mode Latihan dengan Animasi Seleksi
          Row(
            children: List.generate(3, (index) {
              final active = _selectedModeIndex == index;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  child: InkWell(
                    onTap: _isRunning ? null : () => _onSelectMode(index),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? AppColors.green : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active ? AppColors.green : AppColors.border,
                          width: active ? 2 : 1,
                        ),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: AppColors.green.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            modeIcons[index],
                            size: 14,
                            color: active ? Colors.white : AppColors.forest,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              modeNames[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: active ? Colors.white : AppColors.forest,
                                fontWeight: active ? FontWeight.bold : FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // Status & Timer Display
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isRunning
                          ? (_selectedModeIndex == 2 && _isWaitingForHome
                              ? 'STANDBY: UBIN 1'
                              : 'TARGET: UBIN $_targetTile')
                          : (_isDemoActive
                              ? 'MEMUTAR ANIMASI PANDUAN'
                              : 'Siap Memulai (${modeNames[_selectedModeIndex]})'),
                      style: TextStyle(
                        color: _isRunning
                            ? AppColors.green
                            : (_isDemoActive ? Colors.orange.shade800 : AppColors.muted),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_elapsedSeconds.toStringAsFixed(1)}s',
                      style: const TextStyle(
                        color: AppColors.forest,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _totalSteps > 0
                        ? (_isRunning
                            ? (_selectedModeIndex == 2
                                ? (_reactiveRound / _maxReactiveRounds)
                                : (_currentStep / _totalSteps))
                            : (_isDemoActive
                                ? ((_demoStepIndex + 1) /
                                    (_selectedModeIndex == 0
                                        ? _fsstSequence.length
                                        : (_selectedModeIndex == 1
                                            ? _lateralSequence.length
                                            : 2)))
                                : 0.0))
                        : 0.0,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isDemoActive ? Colors.orange : AppColors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Baris Header Matras & Tombol Animasi Panduan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bentuk Matras & Alur:',
                style: TextStyle(
                  color: AppColors.forest,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isRunning ? null : _toggleDemoAnimation,
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _isDemoActive ? Colors.orange.shade800 : AppColors.green,
                  side: BorderSide(
                    color: _isDemoActive ? Colors.orange : AppColors.green,
                    width: 1.5,
                  ),
                  backgroundColor: _isDemoActive
                      ? Colors.orange.shade50
                      : AppColors.softGreen,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  _isDemoActive
                      ? Icons.pause_circle_rounded
                      : Icons.play_circle_fill_rounded,
                  size: 16,
                ),
                label: Text(
                  _isDemoActive ? 'Jeda Panduan' : 'Animasi Langkah',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // MATRAS DINAMIS DENGAN ANIMASI TRANSISI (FSST 2X2, LATERAL 1X4, REACTIVE T-SHAPE)
          _buildMatrasLayout(),

          const SizedBox(height: 22),

          // Tombol Mulai / Hentikan
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isRunning ? _finishTraining : _startTraining,
              style: FilledButton.styleFrom(
                backgroundColor:
                    _isRunning ? Colors.redAccent : AppColors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _isRunning ? 'Selesaikan Sesi' : 'Mulai Latihan Sekarang',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Ketuk ubin di atas atau injak matras fisik ESP32 yang terhubung.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrasLayout() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_selectedModeIndex),
        child: _selectedModeIndex == 0
            ? _buildFsst2x2Matras()
            : _selectedModeIndex == 1
                ? _buildLateral1x4Matras()
                : _buildReactiveTShapeMatras(),
      ),
    );
  }

  Widget _buildFsst2x2Matras() {
    final activeTile = _activeHighlightedTile;
    final isTargetActive = _isRunning || _isDemoActive;

    return Column(
      key: const ValueKey('fsst_2x2_matras'),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view_rounded, size: 14, color: AppColors.green),
              SizedBox(width: 6),
              Text(
                'Bentuk Matras: Matrix 2×2 (FSST Step)',
                style: TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 320,
            height: 320,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF334155), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _MatrasTileWidget(
                          tileNum: 1,
                          label: 'Depan-Kiri',
                          stepBadge: 'Langkah 1 & 5',
                          isTarget: isTargetActive && activeTile == 1,
                          pulseScale: _pulseScale,
                          onTap: () => _onTileStepped(1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MatrasTileWidget(
                          tileNum: 2,
                          label: 'Depan-Kanan',
                          stepBadge: 'Langkah 2',
                          isTarget: isTargetActive && activeTile == 2,
                          pulseScale: _pulseScale,
                          onTap: () => _onTileStepped(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _MatrasTileWidget(
                          tileNum: 3,
                          label: 'Belakang-Kiri',
                          stepBadge: 'Langkah 4',
                          isTarget: isTargetActive && activeTile == 3,
                          pulseScale: _pulseScale,
                          onTap: () => _onTileStepped(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MatrasTileWidget(
                          tileNum: 4,
                          label: 'Belakang-Kanan',
                          stepBadge: 'Langkah 3',
                          isTarget: isTargetActive && activeTile == 4,
                          pulseScale: _pulseScale,
                          onTap: () => _onTileStepped(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildSteppingSequenceFlow(
          steps: const [1, 2, 4, 3, 1],
          currentActive: activeTile,
        ),
      ],
    );
  }

  Widget _buildLateral1x4Matras() {
    final activeTile = _activeHighlightedTile;
    final isTargetActive = _isRunning || _isDemoActive;

    return Column(
      key: const ValueKey('lateral_1x4_matras'),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.view_column_rounded, size: 14, color: AppColors.green),
              SizedBox(width: 6),
              Text(
                'Bentuk Matras: Garis Lurus 1×4 (Lateral Step)',
                style: TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: double.infinity,
            height: 155,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MatrasTileWidget(
                    tileNum: 1,
                    label: 'Kiri (1)',
                    stepBadge: 'Langkah 1 & 7',
                    isTarget: isTargetActive && activeTile == 1,
                    pulseScale: _pulseScale,
                    onTap: () => _onTileStepped(1),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MatrasTileWidget(
                    tileNum: 2,
                    label: 'Tengah 1 (2)',
                    stepBadge: 'Langkah 2 & 6',
                    isTarget: isTargetActive && activeTile == 2,
                    pulseScale: _pulseScale,
                    onTap: () => _onTileStepped(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MatrasTileWidget(
                    tileNum: 3,
                    label: 'Tengah 2 (3)',
                    stepBadge: 'Langkah 3 & 5',
                    isTarget: isTargetActive && activeTile == 3,
                    pulseScale: _pulseScale,
                    onTap: () => _onTileStepped(3),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MatrasTileWidget(
                    tileNum: 4,
                    label: 'Kanan (4)',
                    stepBadge: 'Langkah 4 (Balik)',
                    isTarget: isTargetActive && activeTile == 4,
                    pulseScale: _pulseScale,
                    onTap: () => _onTileStepped(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildSteppingSequenceFlow(
          steps: const [1, 2, 3, 4, 3, 2, 1],
          currentActive: activeTile,
        ),
      ],
    );
  }

  Widget _buildReactiveTShapeMatras() {
    final activeTile = _activeHighlightedTile;
    final isTargetActive = _isRunning || _isDemoActive;
    final isHomeActive = isTargetActive && activeTile == 1;

    return Column(
      key: const ValueKey('reactive_t_matras'),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gamepad_rounded, size: 14, color: AppColors.green),
              SizedBox(width: 6),
              Text(
                'Bentuk Matras: T-Shape (Reactive Step)',
                style: TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 340,
            height: 310,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF334155), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Sayap Atas Huruf T (Ubin 2, Ubin 3, Ubin 4 sebagai Target Acak)
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _MatrasTileWidget(
                          tileNum: 2,
                          label: 'Target Kiri',
                          stepBadge: 'Target 2',
                          isTarget: isTargetActive && activeTile == 2,
                          pulseScale: _pulseScale,
                          onTap: () => _onTileStepped(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MatrasTileWidget(
                          tileNum: 3,
                          label: 'Target Maju',
                          stepBadge: 'Target 3',
                          isTarget: isTargetActive && activeTile == 3,
                          pulseScale: _pulseScale,
                          onTap: () => _onTileStepped(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MatrasTileWidget(
                          tileNum: 4,
                          label: 'Target Kanan',
                          stepBadge: 'Target 4',
                          isTarget: isTargetActive && activeTile == 4,
                          pulseScale: _pulseScale,
                          onTap: () => _onTileStepped(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Batang Bawah Huruf T (Ubin 1 di Tengah sebagai Standby / Home Base)
                Expanded(
                  child: Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MatrasTileWidget(
                          tileNum: 1,
                          label: 'Standby (Home)',
                          stepBadge: '🏠 Home Base',
                          icon: Icons.home_rounded,
                          isTarget: isHomeActive,
                          pulseScale: _pulseScale,
                          onTap: () => _onTileStepped(1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isHomeActive ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHomeActive ? AppColors.green : Colors.amber.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isHomeActive ? Icons.home_rounded : Icons.flash_on_rounded,
                size: 14,
                color: isHomeActive ? AppColors.green : Colors.amber.shade800,
              ),
              const SizedBox(width: 6),
              Text(
                isHomeActive
                    ? 'Standby: Injak Ubin 1 di tengah untuk memicu target'
                    : 'Stimulus Aktif: Segera injak Ubin $activeTile yang menyala!',
                style: TextStyle(
                  color: isHomeActive ? AppColors.green : Colors.amber.shade900,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSteppingSequenceFlow({
    required List<int> steps,
    required int currentActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          const Text(
            'Alur Langkah:',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          for (int i = 0; i < steps.length; i++) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: steps[i] == currentActive
                    ? AppColors.green
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: steps[i] == currentActive
                      ? AppColors.green
                      : const Color(0xFFCBD5E1),
                ),
              ),
              child: Text(
                'U${steps[i]}',
                style: TextStyle(
                  color: steps[i] == currentActive ? Colors.white : AppColors.forest,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (i < steps.length - 1)
              const Icon(
                Icons.arrow_forward_rounded,
                size: 12,
                color: AppColors.muted,
              ),
          ],
        ],
      ),
    );
  }
}

class _MatrasTileWidget extends StatelessWidget {
  const _MatrasTileWidget({
    required this.tileNum,
    required this.label,
    this.stepBadge,
    required this.isTarget,
    this.pulseScale,
    required this.onTap,
    this.icon,
  });

  final int tileNum;
  final String label;
  final String? stepBadge;
  final bool isTarget;
  final Animation<double>? pulseScale;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    Widget tileContent = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: isTarget ? const Color(0xFF10B981) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTarget ? Colors.white : const Color(0xFF475569),
          width: isTarget ? 3.0 : 1.5,
        ),
        boxShadow: isTarget
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.65),
                  blurRadius: 14,
                  spreadRadius: 3,
                ),
                const BoxShadow(
                  color: Colors.white24,
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header: LED Indicator & Footstep Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTarget ? Colors.yellowAccent : Colors.black45,
                  boxShadow: isTarget
                      ? [
                          const BoxShadow(
                            color: Colors.yellowAccent,
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isTarget
                    ? Icons.directions_walk_rounded
                    : (icon ?? Icons.touch_app_rounded),
                size: 14,
                color: isTarget ? Colors.white : const Color(0xFF64748B),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Tile Number
          Text(
            'UBIN $tileNum',
            style: TextStyle(
              color: isTarget ? Colors.white : const Color(0xFFF1F5F9),
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          // Position / Role Label
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isTarget
                  ? Colors.white.withValues(alpha: 0.95)
                  : const Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (stepBadge != null) ...[
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isTarget
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                stepBadge!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isTarget ? Colors.white : const Color(0xFFCBD5E1),
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (isTarget && pulseScale != null) {
      tileContent = ScaleTransition(
        scale: pulseScale!,
        child: tileContent,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: tileContent,
    );
  }
}

// ==============================================================================
// DIALOGS: DETAIL SESI, PROFIL PASIEN, BANTUAN, KEAMANAN, PRIVASI
// ==============================================================================
class _SessionDetailDialog extends StatelessWidget {
  const _SessionDetailDialog({required this.session});
  final SessionRecord session;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.analytics_rounded,
            color: AppColors.green,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.modeName,
                style: const TextStyle(
                  color: AppColors.forest,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                session.dateText,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryStat(label: 'Akurasi', val: '${session.accuracyPercent}%'),
            _SummaryStat(label: 'Total Langkah', val: '${session.totalSteps}'),
            _SummaryStat(
              label: 'Avg Reaksi',
              val: '${session.avgReactionSeconds}s',
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: AppColors.border),
        const SizedBox(height: 10),
        const Text(
          'Simetri Beban Kaki:',
          style: TextStyle(
            color: AppColors.forest,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kiri: ${session.bilateralSymmetry}%',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            Text(
              'Kanan: ${100 - session.bilateralSymmetry}%',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: session.bilateralSymmetry / 100.0,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Catatan Evaluasi Klinis:',
          style: TextStyle(
            color: AppColors.forest,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          session.clinicalNote,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    ),
    actions: [
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.green),
        onPressed: () => Navigator.pop(context),
        child: const Text('Tutup'),
      ),
    ],
  );
}

class _PatientProfileDialog extends StatefulWidget {
  const _PatientProfileDialog({
    required this.currentName,
    required this.currentAge,
    required this.currentCondition,
    required this.currentTherapist,
    required this.currentTargetMinutes,
    required this.onSave,
  });

  final String currentName;
  final String currentAge;
  final String currentCondition;
  final String currentTherapist;
  final int currentTargetMinutes;
  final void Function(String, String, String, String, int) onSave;

  @override
  State<_PatientProfileDialog> createState() => _PatientProfileDialogState();
}

class _PatientProfileDialogState extends State<_PatientProfileDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _conditionCtrl;
  late TextEditingController _therapistCtrl;
  late int _targetMinutes;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName);
    _ageCtrl = TextEditingController(text: widget.currentAge);
    _conditionCtrl = TextEditingController(text: widget.currentCondition);
    _therapistCtrl = TextEditingController(text: widget.currentTherapist);
    _targetMinutes = widget.currentTargetMinutes;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _conditionCtrl.dispose();
    _therapistCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: const Text(
      'Ubah Profil Pasien',
      style: TextStyle(color: AppColors.forest, fontWeight: FontWeight.bold),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nama Lengkap Pasien'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ageCtrl,
            decoration: const InputDecoration(labelText: 'Usia'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _conditionCtrl,
            decoration: const InputDecoration(labelText: 'Diagnosa Medis'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _therapistCtrl,
            decoration:
                const InputDecoration(labelText: 'Fisioterapis Pembimbing'),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Target Latihan Harian:',
                style: TextStyle(fontSize: 13),
              ),
              DropdownButton<int>(
                value: _targetMinutes,
                items: [5, 10, 15, 20].map((m) {
                  return DropdownMenuItem(value: m, child: Text('$m Menit'));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _targetMinutes = val);
                },
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.green),
        onPressed: () {
          widget.onSave(
            _nameCtrl.text.trim(),
            _ageCtrl.text.trim(),
            _conditionCtrl.text.trim(),
            _therapistCtrl.text.trim(),
            _targetMinutes,
          );
          Navigator.pop(context);
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

class _HelpCenterDialog extends StatelessWidget {
  const _HelpCenterDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: const Row(
      children: [
        Icon(Icons.help_center_rounded, color: AppColors.green),
        SizedBox(width: 8),
        Text(
          'Pusat Bantuan',
          style:
              TextStyle(color: AppColors.forest, fontWeight: FontWeight.bold),
        ),
      ],
    ),
    content: const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Cara Menghubungkan ke Matras:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            '• Nyalakan modem MiFi ADVAN MF01.\n'
            '• Sambungkan HP ke Wi-Fi ADVAN MF01-83405B.\n'
            '• Sandi: 085848719373 (Gateway: 192.168.0.1).\n'
            '• ESP32 akan mengirim heartbeat ke Supabase secara berkala.',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
          SizedBox(height: 12),
          Text(
            '2. Mode Latihan Klinis:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            '• FSST 2x2: Melatih langkah 4 arah (Depan, Samping, Belakang).\n'
            '• Lateral 1x4: Melatih transfer bobot kiri-kanan & kelincahan.\n'
            '• Reactive T: Melatih waktu reaksi terhadap stimulus acak lampu LED.',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
          SizedBox(height: 12),
          Text(
            '3. Indikator Ubin & DFPlayer Audio:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            '• Lampu LED ubin menyala menandakan target injakan.\n'
            '• Suara nada tinggi menandakan injakan benar.\n'
            '• Suara aba-aba turnback memberitahu putar balik di ujung matras.',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    ),
    actions: [
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.green),
        onPressed: () => Navigator.pop(context),
        child: const Text('Mengerti'),
      ),
    ],
  );
}

class _SafetyGuidelinesDialog extends StatelessWidget {
  const _SafetyGuidelinesDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: const Row(
      children: [
        Icon(Icons.health_and_safety_rounded, color: AppColors.green),
        SizedBox(width: 8),
        Text(
          'Keamanan Latihan',
          style:
              TextStyle(color: AppColors.forest, fontWeight: FontWeight.bold),
        ),
      ],
    ),
    content: const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Protokol Klinis Rehabilitasi Stroke:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(height: 8),
          Text(
            '1. Pendampingan Wajib: Bagi pasien dengan gangguan keseimbangan sedang hingga berat, lakukan latihan dengan didampingi fisioterapis atau keluarga.\n\n'
            '2. Permukaan Datar: Letakkan matras pada lantai yang rata, bersih, dan bebas dari halangan.\n\n'
            '3. Sepatu Anti-Selip: Gunakan alas kaki tertutup dengan sol karet anti-selip.\n\n'
            '4. Batas Kelelahan: Segera istirahat bila timbul pusing, nyeri dada, atau napas terengah-engah.',
            style:
                TextStyle(fontSize: 13, color: AppColors.muted, height: 1.45),
          ),
        ],
      ),
    ),
    actions: [
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.green),
        onPressed: () => Navigator.pop(context),
        child: const Text('Saya Mengerti'),
      ),
    ],
  );
}

class _PrivacyInfoDialog extends StatelessWidget {
  const _PrivacyInfoDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: const Row(
      children: [
        Icon(Icons.security_rounded, color: AppColors.green),
        SizedBox(width: 8),
        Text(
          'Keamanan & Privasi',
          style:
              TextStyle(color: AppColors.forest, fontWeight: FontWeight.bold),
        ),
      ],
    ),
    content: const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perlindungan Rekam Medis Pasien:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(height: 8),
          Text(
            '• Semua data sesi latihan dienkripsi menggunakan protokol HTTPS/TLS.\n'
            '• Database PostgreSQL dikelola secara aman di Supabase Cloud.\n'
            '• Hanya fisioterapis dan pasien terdaftar yang memiliki akses rekam medis.\n'
            '• Tidak ada pelacak atau pihak ketiga yang mengumpulkan data pribadi Anda.',
            style:
                TextStyle(fontSize: 13, color: AppColors.muted, height: 1.45),
          ),
        ],
      ),
    ),
    actions: [
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.green),
        onPressed: () => Navigator.pop(context),
        child: const Text('Tutup'),
      ),
    ],
  );
}
