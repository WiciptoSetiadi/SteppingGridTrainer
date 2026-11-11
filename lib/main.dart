import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
}

class SteppingGridApp extends StatefulWidget {
  const SteppingGridApp({super.key});

  @override
  State<SteppingGridApp> createState() => _SteppingGridAppState();
}

class _SteppingGridAppState extends State<SteppingGridApp> {
  int _selectedTab = 0;
  bool _showTraining = false;
  bool _wifiPreviewConnected = false;
  int _period = 0;
  int _periodOffset = 0;
  final Map<String, bool> _preferences = {
    'contrast': true,
    'reminders': false,
    'audio': true,
    'vibration': true,
  };

  void _openWifiSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _WifiPreviewSheet(
        initiallyConnected: _wifiPreviewConnected,
        onConnectionChanged: (connected) {
          setState(() => _wifiPreviewConnected = connected);
        },
      ),
    );
  }

  void _showInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: AppColors.forest)),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.muted, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Mengerti',
              style: TextStyle(color: AppColors.green),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Keluar dari pratinjau?'),
        content: const Text(
          'Belum ada akun yang terhubung. Anda akan kembali ke Beranda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kembali'),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) {
      setState(() {
        _selectedTab = 0;
        _showTraining = false;
      });
    }
  }

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
      home: Scaffold(
        body: SafeArea(
          bottom: false,
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
                          ? TrainingPage(
                              connected: _wifiPreviewConnected,
                              onBack: () =>
                                  setState(() => _showTraining = false),
                            )
                          : IndexedStack(
                              key: ValueKey(_selectedTab),
                              index: _selectedTab,
                              children: [
                                HomePage(
                                  connected: _wifiPreviewConnected,
                                  onManageMat: _openWifiSheet,
                                  onStartTraining: () =>
                                      setState(() => _showTraining = true),
                                  onShowHistory: () =>
                                      setState(() => _selectedTab = 1),
                                ),
                                HistoryPage(
                                  period: _period,
                                  offset: _periodOffset,
                                  onPeriodChanged: (value) => setState(() {
                                    _period = value;
                                    _periodOffset = 0;
                                  }),
                                  onOffsetChanged: (value) =>
                                      setState(() => _periodOffset = value),
                                ),
                                SettingsPage(
                                  connected: _wifiPreviewConnected,
                                  preferences: _preferences,
                                  onPreferenceChanged: (key, value) =>
                                      setState(() => _preferences[key] = value),
                                  onManageMat: _openWifiSheet,
                                  onShowInfo: _showInfo,
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
      ),
    );
  }
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.selected,
    required this.onSelected,
    super.key,
  });
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['Beranda', 'Riwayat', 'Pengaturan'];
    const assets = [
      'assets/figma/home_House.svg',
      'assets/figma/home_History.svg',
      'assets/figma/home_Settings.svg',
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index == selected;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelected(index),
              child: SizedBox(
                height: 60,
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 36,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.softGreen
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        assets[index],
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          active ? AppColors.green : AppColors.muted,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? AppColors.green : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 3),
            Container(
              width: 8,
              height: 23,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
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
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(100),
        ),
        child: const Text(
          'Pratinjau',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({required this.title, required this.subtitle, super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const BrandHeader(),
      const SizedBox(height: 24),
      Text(
        title,
        style: const TextStyle(
          color: AppColors.forest,
          fontSize: 34,
          height: 1.2,
          letterSpacing: -1,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.forest,
          fontSize: 17,
          height: 1.45,
        ),
      ),
    ],
  );
}

class HomePage extends StatelessWidget {
  const HomePage({
    required this.connected,
    required this.onManageMat,
    required this.onStartTraining,
    required this.onShowHistory,
    super.key,
  });
  final bool connected;
  final VoidCallback onManageMat;
  final VoidCallback onStartTraining;
  final VoidCallback onShowHistory;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SingleChildScrollView(
      key: const PageStorageKey('home'),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandHeader(),
          const SizedBox(height: 24),
          Text(
            '${_weekday(now.weekday)}, ${now.day} ${_month(now.month)} ${now.year}',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Halo, Budi!',
            style: TextStyle(
              color: AppColors.forest,
              fontSize: 34,
              height: 1.2,
              letterSpacing: -1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Selangkah lagi, bersama-sama.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 16,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: onManageMat,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_rounded,
                    color: AppColors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Matras terhubung via Wi-Fi',
                          style: const TextStyle(
                            color: AppColors.forest,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SGT-01 · Siap digunakan',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    connected
                        ? Icons.check_circle_outline
                        : Icons.chevron_right,
                    color: AppColors.green,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const DailySummaryCard(),
          const SizedBox(height: 24),
          _RecommendationCard(onStart: onStartTraining),
          const SizedBox(height: 14),
          const SafetyNote(),
          const SizedBox(height: 24),
          _WeeklyProgressCard(onShowHistory: onShowHistory),
          const SizedBox(height: 24),
          _RecentSessions(onShowHistory: onShowHistory),
        ],
      ),
    );
  }
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
                      fontWeight: FontWeight.w600,
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
                icon: 'assets/figma/home_Target.svg',
                value: '84%',
                label: 'Akurasi langkah',
                caption: '+2 poin dari sesi lalu',
              ),
            ),
            Container(width: 1, height: 116, color: AppColors.border),
            const SizedBox(width: 20),
            const Expanded(
              child: _MetricItem(
                icon: 'assets/figma/home_Timer.svg',
                value: '1,8 dtk',
                label: 'Rata-rata reaksi',
                caption: 'Waktu mulai langkah',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Target harian tercapai',
              style: TextStyle(
                color: AppColors.forest,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '10 / 10 menit',
              style: TextStyle(
                color: AppColors.forest,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: const LinearProgressIndicator(
            value: 1.0,
            minHeight: 8,
            backgroundColor: AppColors.soft,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Usaha kecil hari ini tetap berarti.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45),
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
  final String icon;
  final String value;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SvgPicture.asset(icon, width: 23, height: 23),
      const SizedBox(height: 10),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.forest,
          fontSize: 32,
          height: 1,
          letterSpacing: -1,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        label,
        style: const TextStyle(
          color: AppColors.forest,
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        caption,
        style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
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
      color: AppColors.deepGreen,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(
              'assets/figma/home_Sparkles.svg',
              width: 18,
              height: 18,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Saran AI · Sesi berikutnya',
                style: TextStyle(
                  color: AppColors.lime,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _MiniMat(),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Sekuensial',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            height: 1.2,
            letterSpacing: -0.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '40 langkah/menit · 10 menit',
          style: TextStyle(
            color: AppColors.lime,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Pertahankan ritme yang nyaman. Coba Zigzag setelah berdiskusi dengan fisioterapis.',
          style: TextStyle(
            color: Color(0xFFF1F5F9),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: onStart,
            icon: SvgPicture.asset(
              'assets/figma/home_Play.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.deepGreen,
                BlendMode.srcIn,
              ),
            ),
            label: const Text(
              'Mulai Latihan',
              style: TextStyle(
                color: AppColors.deepGreen,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.lime,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MiniMat extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .25), borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 3),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(3))),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .25), borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 3),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .25), borderRadius: BorderRadius.circular(3))),
          ],
        ),
      ],
    ),
  );
}

class SafetyNote extends StatelessWidget {
  const SafetyNote({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 20, color: AppColors.muted),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Berlatih bersama fisioterapis atau gunakan pegangan yang stabil.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Langkah makin tepat',
              style: TextStyle(
                color: AppColors.forest,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SvgPicture.asset(
            'assets/figma/home_TrendingUp.svg',
            width: 23,
            height: 23,
          ),
        ],
      ),
      const SizedBox(height: 14),
      AppCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Akurasi per sesi',
                  style: TextStyle(
                    color: AppColors.forest,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '26 Okt – 1 Nov',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Naik 10 poin dalam 4 sesi minggu ini',
              style: TextStyle(
                color: AppColors.green,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            const _FigmaChart(),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/figma/home_Sparkles.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          AppColors.green,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Estimasi AI · Target akurasi 90%',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sekitar 3 sesi lagi',
                    style: TextStyle(
                      color: AppColors.forest,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Jika kenaikan 2 poin per sesi berlanjut.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Perkiraan dapat berubah, bukan janji pemulihan klinis.',
                    style: TextStyle(color: Color(0xFF8E9E98), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _FigmaChart extends StatelessWidget {
  const _FigmaChart();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 150,
    child: CustomPaint(
      painter: _FigmaChartPainter(),
      size: Size.infinite,
    ),
  );
}

class _FigmaChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = const TextStyle(color: AppColors.muted, fontSize: 10);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Grid lines & labels
    final yLabels = ['90', '80', '70'];
    final yVals = [20.0, 60.0, 100.0];
    final linePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;

    for (var i = 0; i < 3; i++) {
      textPainter.text = TextSpan(text: yLabels[i], style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, yVals[i] - 6));
      canvas.drawLine(Offset(24, yVals[i]), Offset(size.width, yVals[i]), linePaint);
    }

    // Target 90 dashed line
    final dashPaint = Paint()
      ..color = AppColors.green
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    double startX = 24;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 20), Offset(startX + 4, 20), dashPaint);
      startX += 8;
    }

    textPainter.text = const TextSpan(
      text: 'Target 90%',
      style: TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - textPainter.width, 4));

    // Data points (26 Okt -> 74%, 28 Okt -> 78%, 30 Okt -> 82%, 1 Nov -> 84%)
    final points = [
      Offset(40, 88),
      Offset(120, 72),
      Offset(200, 56),
      Offset(size.width - 24, 48),
    ];
    final labels = ['74%', '78%', '82%', '84%'];
    final xDates = ['26 Okt', '28 Okt', '30 Okt', '1 Nov'];

    // Area fill
    final areaPath = Path()..moveTo(points[0].dx, size.height - 20);
    for (final p in points) {
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(points.last.dx, size.height - 20);
    areaPath.close();

    final areaPaint = Paint()
      ..color = AppColors.green.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawPath(areaPath, areaPaint);

    // Line
    final linePath = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    final strokePaint = Paint()
      ..color = AppColors.green
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, strokePaint);

    // Points and labels
    final dotPaint = Paint()..color = AppColors.green;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4, dotPaint);

      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: AppColors.forest, fontSize: 11, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(points[i].dx - textPainter.width / 2, points[i].dy - 16));

      textPainter.text = TextSpan(text: xDates[i], style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(points[i].dx - textPainter.width / 2, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RecentSessions extends StatelessWidget {
  const _RecentSessions({required this.onShowHistory});
  final VoidCallback onShowHistory;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Latihan terakhir',
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
      const SizedBox(height: 14),
      _RecentItem(
        title: 'Hari ini, 08.30',
        subtitle: 'Sekuensial · 10 menit',
        acc: '84%',
        reaction: '1,8 dtk',
      ),
      const SizedBox(height: 10),
      _RecentItem(
        title: '30 Okt, 08.45',
        subtitle: 'Sekuensial · 10 menit',
        acc: '82%',
        reaction: '2,0 dtk',
      ),
      const SizedBox(height: 10),
      _RecentItem(
        title: '28 Okt, 09.00',
        subtitle: 'Sekuensial · 10 menit',
        acc: '78%',
        reaction: '2,2 dtk',
      ),
    ],
  );
}

class _RecentItem extends StatelessWidget {
  const _RecentItem({
    required this.title,
    required this.subtitle,
    required this.acc,
    required this.reaction,
  });
  final String title;
  final String subtitle;
  final String acc;
  final String reaction;

  @override
  Widget build(BuildContext context) => AppCard(
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
          child: const Icon(Icons.directions_walk, color: AppColors.green, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.forest,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              acc,
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              reaction,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ],
    ),
  );
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({
    required this.period,
    required this.offset,
    required this.onPeriodChanged,
    required this.onOffsetChanged,
    super.key,
  });
  final int period;
  final int offset;
  final ValueChanged<int> onPeriodChanged;
  final ValueChanged<int> onOffsetChanged;

  String _periodLabel() {
    final today = DateTime.now();
    if (period == 0) {
      final monday = today.subtract(
        Duration(days: today.weekday - 1 + offset * 7),
      );
      final sunday = monday.add(const Duration(days: 6));
      return '${monday.day} ${_monthShort(monday.month)} – ${sunday.day} ${_monthShort(sunday.month)} ${sunday.year}';
    }
    if (period == 1) {
      final month = DateTime(today.year, today.month + offset, 1);
      return '${_month(month.month)} ${month.year}';
    }
    return 'Semua riwayat';
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const PageStorageKey('history'),
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ScreenHeader(
          title: 'Riwayat latihan',
          subtitle: 'Setiap langkah punya cerita kemajuan.',
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.soft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: List.generate(3, (index) {
              const names = ['Minggu ini', 'Bulan ini', 'Semua'];
              final active = index == period;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onPeriodChanged(index),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? AppColors.green : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      names[index],
                      style: TextStyle(
                        color: active ? Colors.white : AppColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _PeriodButton(
              icon: SvgPicture.asset(
                'assets/figma/history_ChevronLeft.svg',
                width: 20,
                height: 20,
              ),
              onTap: () => onOffsetChanged(offset - 1),
              disabled: period == 2,
            ),
            Expanded(
              child: Center(
                child: Text(
                  _periodLabel(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _PeriodButton(
              icon: SvgPicture.asset(
                'assets/figma/history_ChevronLeft.svg',
                width: 20,
                height: 20,
              ),
              forward: true,
              disabled: offset == 0 || period == 2,
              onTap: () {
                if (offset < 0 && period != 2) onOffsetChanged(offset + 1);
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ringkasan periode',
                      style: TextStyle(
                        color: AppColors.forest,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softGreen,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      '0 sesi',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(
                    child: _PeriodMetric(value: '—', label: 'Total latihan'),
                  ),
                  SizedBox(
                    height: 62,
                    child: VerticalDivider(color: AppColors.border, width: 1),
                  ),
                  Expanded(
                    child: _PeriodMetric(
                      value: '—',
                      label: 'Rata-rata akurasi',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perkembangan',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Ringkasan muncul setelah sesi latihan tersedia.',
                      style: TextStyle(
                        color: AppColors.forest,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Sesi latihan',
                style: TextStyle(
                  color: AppColors.forest,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Text(
              'Terbaru dahulu',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: const EmptyMessage(
            icon: Icons.history_rounded,
            title: 'Belum ada riwayat',
            subtitle:
                'Sesi latihan akan muncul di sini setelah fitur pencatatan tersedia.',
          ),
        ),
      ],
    ),
  );
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.icon,
    required this.onTap,
    this.disabled = false,
    this.forward = false,
  });
  final Widget icon;
  final VoidCallback onTap;
  final bool disabled;
  final bool forward;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 48,
    child: OutlinedButton(
      onPressed: disabled ? null : onTap,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: AppColors.border),
        foregroundColor: AppColors.forest,
        backgroundColor: disabled ? AppColors.soft : Colors.transparent,
      ),
      child: forward ? RotatedBox(quarterTurns: 2, child: icon) : icon,
    ),
  );
}

class _PeriodMetric extends StatelessWidget {
  const _PeriodMetric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: AppColors.forest,
          fontSize: 30,
          height: 1.1,
          letterSpacing: -1,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    ],
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.connected,
    required this.preferences,
    required this.onPreferenceChanged,
    required this.onManageMat,
    required this.onShowInfo,
    required this.onSignOut,
    super.key,
  });
  final bool connected;
  final Map<String, bool> preferences;
  final void Function(String, bool) onPreferenceChanged;
  final VoidCallback onManageMat;
  final void Function(String, String) onShowInfo;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const PageStorageKey('settings'),
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ScreenHeader(
          title: 'Pengaturan',
          subtitle: 'Atur kenyamanan latihan Anda.',
        ),
        const SizedBox(height: 24),
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => onShowInfo(
            'Profil pasien',
            'Pengaturan profil akan tersedia saat akun Supabase disiapkan. Tidak ada informasi profil yang disimpan pada pratinjau ini.',
          ),
          child: AppCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.softGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: AppColors.green,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profil pasien',
                        style: TextStyle(
                          color: AppColors.forest,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Belum diatur',
                        style: TextStyle(color: AppColors.muted, fontSize: 14),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Lihat pengaturan profil',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Matras saya'),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.softGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.wifi_rounded,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Perangkat Stepping Grid',
                          style: TextStyle(
                            color: AppColors.forest,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          connected
                              ? 'Terhubung · simulasi UI'
                              : 'Belum terhubung',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    connected
                        ? Icons.check_circle_outline
                        : Icons.circle_outlined,
                    color: AppColors.green,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                connected
                    ? 'Status simulasi. Perangkat belum berkomunikasi melalui Wi-Fi.'
                    : 'Hubungkan matras melalui jaringan Wi-Fi saat integrasi perangkat tersedia.',
                style: const TextStyle(
                  color: AppColors.forest,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),
              const _InfoLine(label: 'Versi firmware', value: '—'),
              const SizedBox(height: 14),
              const _InfoLine(
                label: 'Kalibrasi terakhir',
                value: 'Belum tersedia',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onManageMat,
                  icon: const Icon(Icons.wifi_find_rounded, size: 19),
                  label: Text(
                    connected ? 'Kelola koneksi Wi-Fi' : 'Atur koneksi Wi-Fi',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.green,
                    side: const BorderSide(color: AppColors.green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Tampilan aplikasi'),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            children: [
              _PreferenceTile(
                icon: SvgPicture.asset(
                  'assets/figma/settings_Type.svg',
                  width: 22,
                  height: 22,
                ),
                title: 'Ukuran teks',
                subtitle: 'Nyaman dibaca',
                trailing: const Text(
                  'Standar  ›',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                onTap: () => onShowInfo(
                  'Ukuran teks',
                  'Pilihan ukuran teks akan tersedia pada pengaturan tampilan.',
                ),
              ),
              const _TileDivider(),
              _PreferenceTile(
                icon: SvgPicture.asset(
                  'assets/figma/settings_Contrast.svg',
                  width: 22,
                  height: 22,
                ),
                title: 'Kontras tinggi',
                subtitle: 'Memperjelas elemen layar',
                value: preferences['contrast'] ?? true,
                onChanged: (value) => onPreferenceChanged('contrast', value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Pengingat ponsel'),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            children: [
              _PreferenceTile(
                icon: SvgPicture.asset(
                  'assets/figma/settings_Bell.svg',
                  width: 22,
                  height: 22,
                ),
                title: 'Pengingat latihan',
                subtitle: 'Notifikasi harian',
                value: preferences['reminders'] ?? false,
                onChanged: (value) => onPreferenceChanged('reminders', value),
              ),
              const _TileDivider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Text(
                  'Pengingat hanya mengubah tampilan pratinjau dan belum menjadwalkan notifikasi.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Umpan balik latihan'),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            children: [
              _PreferenceTile(
                icon: SvgPicture.asset(
                  'assets/figma/settings_Volume2.svg',
                  width: 22,
                  height: 22,
                ),
                title: 'Suara panduan',
                subtitle: 'Petunjuk audio saat latihan',
                value: preferences['audio'] ?? true,
                onChanged: (value) => onPreferenceChanged('audio', value),
              ),
              const _TileDivider(),
              _PreferenceTile(
                icon: SvgPicture.asset(
                  'assets/figma/settings_Lightbulb.svg',
                  width: 22,
                  height: 22,
                ),
                title: 'Petunjuk visual',
                subtitle: 'Isyarat visual di layar',
                value: preferences['vibration'] ?? true,
                onChanged: (value) => onPreferenceChanged('vibration', value),
              ),
              const _TileDivider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Text(
                  'Preferensi berlaku selama pratinjau terbuka dan akan kembali ke pengaturan awal saat aplikasi ditutup.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Bantuan dan akun'),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            children: [
              _PreferenceTile(
                icon: SvgPicture.asset(
                  'assets/figma/settings_CircleHelp.svg',
                  width: 22,
                  height: 22,
                ),
                title: 'Pusat bantuan',
                subtitle: 'Panduan penggunaan aplikasi',
                onTap: () => onShowInfo(
                  'Pusat bantuan',
                  'Panduan penggunaan akan ditambahkan pada tahap berikutnya.',
                ),
              ),
              const _TileDivider(),
              _PreferenceTile(
                icon: SvgPicture.asset(
                  'assets/figma/settings_ShieldCheck.svg',
                  width: 22,
                  height: 22,
                ),
                title: 'Keamanan latihan',
                subtitle: 'Informasi penggunaan dengan aman',
                onTap: () => onShowInfo(
                  'Keamanan latihan',
                  'Gunakan matras di permukaan yang rata. Untuk latihan rehabilitasi, ikuti arahan tenaga kesehatan Anda.',
                ),
              ),
              const _TileDivider(),
              _PreferenceTile(
                icon: SvgPicture.asset(
                  'assets/figma/settings_LockKeyhole.svg',
                  width: 22,
                  height: 22,
                ),
                title: 'Privasi dan data',
                subtitle: 'Informasi pengelolaan data',
                onTap: () => onShowInfo(
                  'Privasi dan data',
                  'Kebijakan privasi belum ditetapkan. Pratinjau ini tidak mengirim atau menyimpan data pasien maupun sesi latihan.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: onSignOut,
            icon: SvgPicture.asset(
              'assets/figma/settings_LogOut.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.muted,
                BlendMode.srcIn,
              ),
            ),
            label: const Text(
              'Keluar dari pratinjau',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'Stepping Grid Trainer · Pratinjau frontend',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.forest,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.value,
    this.onChanged,
    this.trailing,
    this.onTap,
  });
  final Widget icon;
  final String title;
  final String subtitle;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          SizedBox(width: 40, child: Center(child: icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (value case final switchValue?)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onChanged?.call(!switchValue),
              child: Semantics(
                toggled: switchValue,
                label: title,
                child: SvgPicture.asset(
                  switchValue
                      ? 'assets/figma/settings_SakelarAktif.svg'
                      : 'assets/figma/settings_SakelarNonaktif.svg',
                  width: 48,
                  height: 28,
                ),
              ),
            ),
          if (trailing case final trailingWidget?)
            trailingWidget
          else if (value case null)
            const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
        ],
      ),
    );
    if (onTap != null) return InkWell(onTap: onTap, child: content);
    return content;
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20),
    child: Divider(height: 1, color: AppColors.border),
  );
}

class _WifiPreviewSheet extends StatefulWidget {
  const _WifiPreviewSheet({
    required this.initiallyConnected,
    required this.onConnectionChanged,
  });
  final bool initiallyConnected;
  final ValueChanged<bool> onConnectionChanged;
  @override
  State<_WifiPreviewSheet> createState() => _WifiPreviewSheetState();
}

class _WifiPreviewSheetState extends State<_WifiPreviewSheet> {
  final _ssidController = TextEditingController();
  bool _simulated = false;
  @override
  void initState() {
    super.initState();
    _simulated = widget.initiallyConnected;
  }

  @override
  void dispose() {
    _ssidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Koneksi Wi-Fi matras',
            style: TextStyle(
              color: AppColors.forest,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Simulasi tampilan saja. Belum ada koneksi jaringan atau data yang disimpan.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _ssidController,
            decoration: InputDecoration(
              labelText: 'Nama jaringan Wi-Fi (opsional)',
              prefixIcon: const Icon(Icons.wifi_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () {
                final next = !_simulated;
                setState(() => _simulated = next);
                widget.onConnectionChanged(next);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                _simulated
                    ? 'Putuskan simulasi'
                    : 'Simulasikan status terhubung',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _simulated
                  ? 'Status UI: terhubung (simulasi)'
                  : 'Status UI: belum terhubung',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}

class TrainingPage extends StatelessWidget {
  const TrainingPage({
    required this.connected,
    required this.onBack,
    super.key,
  });
  final bool connected;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(width: 4),
            const BrandHeader(),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          'Latihan',
          style: TextStyle(
            color: AppColors.forest,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tampilan sesi latihan pratinjau.',
          style: TextStyle(color: AppColors.muted, fontSize: 16),
        ),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: AppColors.softGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: AppColors.green,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                connected
                    ? 'Status koneksi simulasi aktif'
                    : 'Matras belum terhubung',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.forest,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Layar ini belum memulai latihan sungguhan dan tidak merekam data. Koneksi Wi-Fi perangkat akan ditambahkan pada tahap integrasi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.green,
                    side: const BorderSide(color: AppColors.green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('Kembali ke Beranda'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: AppColors.forest,
      fontSize: 22,
      fontWeight: FontWeight.w700,
    ),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(0),
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.green, size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.forest,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _weekday(int day) => const [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
][day - 1];
String _month(int month) => const [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
][month - 1];
String _monthShort(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
][month - 1];
