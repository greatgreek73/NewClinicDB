import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(kClinicOverlayStyle);

  runApp(const MyApp());
}

const SystemUiOverlayStyle kClinicOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  systemNavigationBarIconBrightness: Brightness.light,
);

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dental Clinic Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        // Заработает, если подключишь Inter в pubspec.yaml
        fontFamily: 'Inter',
      ),
      routes: {
        SearchPage.routeName: (context) => const SearchPage(),
      },
      home: const ClinicDashboardPage(),
    );
  }
}

class ClinicDashboardPage extends StatefulWidget {
  const ClinicDashboardPage({Key? key}) : super(key: key);

  @override
  State<ClinicDashboardPage> createState() => _ClinicDashboardPageState();
}

class _ClinicDashboardPageState extends State<ClinicDashboardPage> {
  bool isToday = true;

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.of(context).viewPadding;
    final contentPadding = EdgeInsets.only(
      left: 24 + viewPadding.left,
      right: 24 + viewPadding.right,
      top: 24 + viewPadding.top,
      bottom: 24 + viewPadding.bottom,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kClinicOverlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.4,
              colors: [
                AppColors.accentStrong.withOpacity(0.25),
                AppColors.bgMid,
                AppColors.bg,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
          child: Padding(
            padding: contentPadding,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 1200,
                        minHeight: constraints.maxHeight,
                      ),
                      child: Container(
                        decoration: buildPrimaryPanelDecoration(),
                        child: LayoutBuilder(
                          builder: (context, innerConstraints) {
                            if (innerConstraints.maxWidth > 900) {
                              return _buildDesktopLayout(context);
                            } else {
                              return _buildMobileLayout(context);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 11,
            child: _buildLeftColumn(context),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 10,
            child: _buildRightColumn(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildLeftColumn(context),
          const SizedBox(height: 24),
          _buildRightColumn(),
        ],
      ),
    );
  }

  // LEFT COLUMN - title, toggle, KPIs
  Widget _buildLeftColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dental clinic dashboard\nthat grows with your practice',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Quick overview of today\'s schedule, patients and revenue.\n'
          'Made for modern dental teams.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textMuted.withOpacity(0.9),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        _buildPeriodToggle(),
        const SizedBox(height: 16),
        _buildSearchButton(context),
        const SizedBox(height: 24),
        _buildStatsGrid(),
      ],
    );
  }

  Widget _buildSearchButton(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).pushNamed(SearchPage.routeName);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.08),
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: Colors.white.withOpacity(0.15),
            ),
          ),
        ),
        icon: const Icon(Icons.search_rounded),
        label: const Text(
          'Go to search',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton('Today', isToday),
          _buildToggleButton('This week', !isToday),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isToday = label == 'Today';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accentStrong,
                    AppColors.accent,
                  ],
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.bg : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard(
          title: 'Patients today',
          value: '18',
          subtitle: '6 new patients',
          highlighted: true,
        ),
        _buildStatCard(
          title: 'Completed',
          value: '12',
          subtitle: '3 in progress',
        ),
        _buildStatCard(
          title: 'Canceled',
          value: '2',
          subtitle: 'No-shows: 1',
        ),
        _buildStatCard(
          title: 'Revenue today',
          value: '\$4,380',
          subtitle: 'Avg. per visit: \$240',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    bool highlighted = false,
  }) {
    return SizedBox(
      width: 230,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: highlighted
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accentStrong.withOpacity(0.95),
                    AppColors.accent.withOpacity(0.85),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surface.withOpacity(0.95),
                    AppColors.surfaceDark.withOpacity(0.98),
                  ],
                ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(highlighted ? 0.22 : 0.12),
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: AppColors.accentStrong.withOpacity(0.6),
                    blurRadius: 40,
                    spreadRadius: 12,
                    offset: const Offset(0, 18),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.7),
                    blurRadius: 30,
                    spreadRadius: 10,
                    offset: const Offset(0, 18),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.6,
                color: highlighted
                    ? AppColors.bg.withOpacity(0.86)
                    : AppColors.textMuted.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: highlighted ? AppColors.bg : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: highlighted
                    ? AppColors.bg.withOpacity(0.85)
                    : AppColors.textMuted.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // RIGHT COLUMN – appointments list
  Widget _buildRightColumn() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surface,
            AppColors.surfaceDark,
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.9),
            blurRadius: 90,
            spreadRadius: 32,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glow in the corner
          Positioned(
            top: -120,
            right: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentStrong.withOpacity(0.55),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRightHeader(),
                const SizedBox(height: 24),
                _buildAppointmentCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TODAY\'S SCHEDULE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Next patients',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'Today, 09:00–18:00',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _buildAppointmentItem(
            time: '09:00',
            name: 'John Smith',
            procedure: 'Implant consultation',
            room: 'Room 2',
            important: true,
          ),
          const SizedBox(height: 12),
          _buildAppointmentItem(
            time: '10:30',
            name: 'Anna Petrova',
            procedure: 'Routine check-up & hygiene',
            room: 'Room 1',
          ),
          const SizedBox(height: 12),
          _buildAppointmentItem(
            time: '12:00',
            name: 'Mark Ivanov',
            procedure: 'Root canal treatment',
            room: 'Room 3',
          ),
          const SizedBox(height: 18),
          Divider(
            color: Colors.white.withOpacity(0.12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'View full schedule in clinic system',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted.withOpacity(0.9),
                  ),
                ),
              ),
              Text(
                'Open calendar',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.accent,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentItem({
    required String time,
    required String name,
    required String procedure,
    required String room,
    bool important = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: important
              ? [
                  AppColors.surface.withOpacity(0.98),
                  AppColors.surfaceDark.withOpacity(0.95),
                ]
              : [
                  AppColors.surfaceDark.withOpacity(0.94),
                  AppColors.surfaceDark.withOpacity(0.98),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: important
              ? AppColors.accentSoft.withOpacity(0.9)
              : Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.bgMid,
                  AppColors.bg,
                ],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withOpacity(0.22),
              ),
            ),
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  procedure,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                room,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              if (important) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentStrong.withOpacity(0.9),
                        AppColors.accent.withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'New patient',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.bg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class SearchPage extends StatelessWidget {
  static const routeName = '/search';

  const SearchPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.of(context).viewPadding;
    final contentPadding = EdgeInsets.only(
      left: 24 + viewPadding.left,
      right: 24 + viewPadding.right,
      top: 24 + viewPadding.top,
      bottom: 24 + viewPadding.bottom,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kClinicOverlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.4,
              colors: [
                AppColors.accentStrong.withOpacity(0.25),
                AppColors.bgMid,
                AppColors.bg,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
          child: Padding(
            padding: contentPadding,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 1100,
                        minHeight: constraints.maxHeight,
                      ),
                      child: Container(
                        decoration: buildPrimaryPanelDecoration(),
                        child: Padding(
                          padding: const EdgeInsets.all(36),
                          child: _SearchContent(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchContent extends StatelessWidget {
  final List<_SearchResult> results = const [
    _SearchResult(
      title: 'Anna Petrova',
      subtitle: 'Patient • Last visit 14 Nov · Hygiene',
      meta: '4 upcoming appointments',
      icon: Icons.person_outline,
    ),
    _SearchResult(
      title: 'Dental implant planning',
      subtitle: 'Treatment protocol · 6 associated patients',
      meta: 'Updated 2 days ago',
      icon: Icons.medical_information_outlined,
    ),
    _SearchResult(
      title: 'Invoice #D-1428',
      subtitle: 'Issued to Mark Ivanov · \$2,950 outstanding',
      meta: 'Created 09 Nov',
      icon: Icons.receipt_long_outlined,
    ),
  ];

  const _SearchContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search the clinic knowledge base',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find patients, procedures, invoices or documents instantly.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textMuted.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: Colors.white.withOpacity(0.06),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to dashboard'),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _SearchField(),
        const SizedBox(height: 28),
        Text(
          'Suggested filters',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            'Patients',
            'Treatments',
            'Invoices',
            'Notes',
            'Upcoming',
            'New leads',
          ].map(
            (label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.surface.withOpacity(0.95),
                    AppColors.surfaceDark.withOpacity(0.98),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 20,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ).toList(),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Text(
              'Results',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 1.2,
                color: AppColors.textMuted.withOpacity(0.8),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.25),
                    AppColors.accentStrong.withOpacity(0.35),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.accentSoft.withOpacity(0.6),
                ),
              ),
              child: Text(
                '${results.length} suggestions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.bg,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...results.map((r) => _SearchResultTile(result: r)),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextField(
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search patients, invoices, notes...',
        hintStyle: TextStyle(
          color: AppColors.textMuted.withOpacity(0.8),
        ),
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surfaceDark.withOpacity(0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: AppColors.textMuted.withOpacity(0.25),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: AppColors.textMuted.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: AppColors.accent.withOpacity(0.8),
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _SearchResult {
  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;

  const _SearchResult({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.icon,
  });
}

class _SearchResultTile extends StatelessWidget {
  final _SearchResult result;

  const _SearchResultTile({Key? key, required this.result}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceDark.withOpacity(0.98),
            AppColors.surface.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 40,
            spreadRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentStrong.withOpacity(0.9),
                  AppColors.accent.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: Icon(
              result.icon,
              size: 24,
              color: AppColors.bg,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            result.meta,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration buildPrimaryPanelDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(32),
    gradient: RadialGradient(
      center: Alignment.topCenter,
      radius: 1.4,
      colors: [
        AppColors.accentStrong.withOpacity(0.35),
        AppColors.bgMid,
        AppColors.bg,
      ],
      stops: const [0.0, 0.4, 1.0],
    ),
    border: Border.all(
      color: Colors.white.withOpacity(0.05),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.95),
        blurRadius: 140,
        spreadRadius: 50,
      ),
    ],
  );
}

class AppColors {
  static const Color bg = Color(0xFF050308);
  static const Color bgMid = Color(0xFF10060B);

  static const Color surface = Color(0xFF1C1017);
  static const Color surfaceDark = Color(0xFF130A0F);

  static const Color accentStrong = Color(0xFFFF7A1A);
  static const Color accent = Color(0xFFFFB347);
  static const Color accentSoft = Color(0x33FFB347);

  static const Color textPrimary = Color(0xFFFDFDFD);
  static const Color textMuted = Color(0xFFB9A8C0);
}

