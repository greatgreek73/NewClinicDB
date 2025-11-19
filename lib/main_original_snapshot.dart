import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(kClinicOverlayStyle);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        AddPatientPage.routeName: (context) => const AddPatientPage(),
        PatientDetailsPage.routeName: (context) => const PatientDetailsPage(),
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
  bool _isLoadingPatients = false;
  int? _todayPatientsCount;
  String? _patientsError;

  @override
  void initState() {
    super.initState();
    _loadTodayPatientsCount();
  }

  Future<void> _loadTodayPatientsCount() async {
    setState(() {
      _isLoadingPatients = true;
      _patientsError = null;
    });

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final query = FirebaseFirestore.instance
          .collection('treatments')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'date',
            isLessThan: Timestamp.fromDate(endOfDay),
          );

      final snapshot = await query.get();

      final uniquePatients = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawId = data['patientId'] ?? data['patient_id'];
        final id = rawId?.toString().trim();
        uniquePatients.add(id?.isNotEmpty == true ? id! : doc.id);
      }

      setState(() {
        _todayPatientsCount = uniquePatients.length;
        _patientsError = null;
      });
    } catch (error) {
      setState(() {
        _patientsError = 'Unable to load';
        _todayPatientsCount = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPatients = false;
        });
      }
    }
  }

  String get _patientsCardValue {
    if (_isLoadingPatients) return '…';
    if (_patientsError != null) return '--';
    return (_todayPatientsCount ?? 0).toString();
  }

  String get _patientsCardSubtitle {
    if (_isLoadingPatients) {
      return 'Loading today\'s data…';
    }
    if (_patientsError != null) {
      return 'Check appointments data';
    }
    return 'Any treatment logged today';
  }

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
        const SizedBox(height: 20),
        _buildPrimaryActions(context),
        const SizedBox(height: 24),
        _buildStatsGrid(),
      ],
    );
  }

  Widget _buildPrimaryActions(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildActionButton(
          context: context,
          label: 'Search',
          icon: Icons.search_rounded,
          onPressed: () =>
              Navigator.of(context).pushNamed(SearchPage.routeName),
        ),
        _buildActionButton(
          context: context,
          label: 'Add patient',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: () =>
              Navigator.of(context).pushNamed(AddPatientPage.routeName),
        ),
        _buildActionButton(
          context: context,
          label: 'Patient profile',
          icon: Icons.badge_outlined,
          onPressed: () =>
              Navigator.of(context).pushNamed(PatientDetailsPage.routeName),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.08),
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: Colors.white.withOpacity(0.15),
            ),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
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
          value: _patientsCardValue,
          subtitle: _patientsCardSubtitle,
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
    return PrimaryPageScaffold(
      maxWidth: 1100,
      child: const _SearchContent(),
    );
  }
}

class AddPatientPage extends StatelessWidget {
  static const routeName = '/add-patient';

  const AddPatientPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PrimaryPageScaffold(
      maxWidth: 960,
      child: const _AddPatientContent(),
    );
  }
}

class PatientDetailsPage extends StatelessWidget {
  static const routeName = '/patient-details';

  const PatientDetailsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PrimaryPageScaffold(
      maxWidth: 1100,
      child: const _PatientDetailsContent(),
    );
  }
}

class _SearchContent extends StatelessWidget {
  final List<_SearchResult> results = const [
    _SearchResult(
      title: 'Anna Petrova',
      subtitle: 'Patient · Last visit 14 Nov · Hygiene',
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
        _PageHeader(
          title: 'Search the clinic knowledge base',
          subtitle:
              'Find patients, procedures, invoices or documents instantly.',
          actionLabel: 'Back to dashboard',
          onAction: () => Navigator.of(context).pop(),
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

class _AddPatientContent extends StatelessWidget {
  const _AddPatientContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;

        final leftCard = _buildFormCard(
          title: 'Patient details',
          children: [
            TextField(decoration: buildFormInputDecoration('Full name')),
            const SizedBox(height: 16),
            TextField(
              decoration:
                  buildFormInputDecoration('Date of birth', hint: 'DD/MM/YYYY'),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: buildFormInputDecoration('Preferred doctor'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: buildFormInputDecoration('Primary concern'),
              dropdownColor: AppColors.surfaceDark,
              style: const TextStyle(color: AppColors.textPrimary),
              items: const [
                DropdownMenuItem(value: 'Implant', child: Text('Implants')),
                DropdownMenuItem(value: 'Hygiene', child: Text('Hygiene')),
                DropdownMenuItem(value: 'Whitening', child: Text('Whitening')),
              ],
              onChanged: (_) {},
            ),
          ],
        );

        final rightCard = _buildFormCard(
          title: 'Contact & notes',
          children: [
            TextField(decoration: buildFormInputDecoration('Phone number')),
            const SizedBox(height: 16),
            TextField(decoration: buildFormInputDecoration('Email')),
            const SizedBox(height: 16),
            TextField(
              maxLines: 4,
              decoration: buildFormInputDecoration(
                'Notes for care team',
                hint: 'Allergies, previous procedures, reminders...',
              ),
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              title: 'Add new patient',
              subtitle: 'Create a profile and assign the first visit to keep the team aligned.',
              actionLabel: 'Back to dashboard',
              onAction: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 28),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: leftCard),
                  const SizedBox(width: 24),
                  Expanded(child: rightCard),
                ],
              )
            else ...[
              leftCard,
              const SizedBox(height: 24),
              rightCard,
            ],
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentStrong,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.save_rounded),
                label: const Text(
                  'Save patient',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: buildSurfaceCardDecoration(glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.5,
              color: AppColors.textMuted.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _PatientDetailsContent extends StatelessWidget {
  const _PatientDetailsContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 820;

        final infoCard = Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: buildSurfaceCardDecoration(glow: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.accent.withOpacity(0.2),
                      child: const Icon(
                        Icons.person,
                        size: 32,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Anna Petrova',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Member since 2019 · VIP Plan',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildInfoChip('Last visit', '14 Nov · Hygiene'),
                    const SizedBox(width: 12),
                    _buildInfoChip('Assigned doctor', 'Dr. Emily Ross'),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 20),
                Text(
                  'Contact & preferences',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                _buildContactRow(Icons.phone, '+1 202 555 0124'),
                const SizedBox(height: 8),
                _buildContactRow(Icons.email_outlined, 'anna.petrova@email.com'),
                const SizedBox(height: 8),
                _buildContactRow(Icons.location_on_outlined, 'Downtown branch · Room 2'),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: buildSurfaceCardDecoration(),
                  child: const Text(
                    'Notes: Prefers morning appointments. Allergic to penicillin. Interested in implant upgrade in Q1.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final scheduleCard = Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: buildSurfaceCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upcoming treatments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ...[
                  _AppointmentRow(
                    date: '20 Nov',
                    title: 'Implant planning session',
                    meta: 'Dr. Emily Ross · Room 4',
                    highlight: true,
                  ),
                  _AppointmentRow(
                    date: '04 Dec',
                    title: 'Crown placement & hygiene',
                    meta: 'Dr. Gomez · Room 1',
                  ),
                  _AppointmentRow(
                    date: '11 Jan',
                    title: 'Follow-up & whitening',
                    meta: 'Dr. Emily Ross · Room 2',
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.08),
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Schedule new appointment'),
                ),
              ],
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              title: 'Patient overview',
              subtitle: 'Track history, update notes and schedule new visits for your patients.',
              actionLabel: 'Back to dashboard',
              onAction: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 28),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  infoCard,
                  const SizedBox(width: 24),
                  scheduleCard,
                ],
              )
            else ...[
              infoCard,
              const SizedBox(height: 24),
              scheduleCard,
            ],
          ],
        );
      },
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: buildSurfaceCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              color: AppColors.textMuted.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  final String date;
  final String title;
  final String meta;
  final bool highlight;

  const _AppointmentRow({
    Key? key,
    required this.date,
    required this.title,
    required this.meta,
    this.highlight = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: buildSurfaceCardDecoration(glow: highlight),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.bgMid,
                  AppColors.bg,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: Text(
              date,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          if (highlight)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentStrong,
                    AppColors.accent,
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'High priority',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.bg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
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

class PrimaryPageScaffold extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  const PrimaryPageScaffold({
    Key? key,
    required this.child,
    this.maxWidth = 1100,
    this.padding = const EdgeInsets.all(36),
  }) : super(key: key);

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
                        maxWidth: maxWidth,
                        minHeight: constraints.maxHeight,
                      ),
                      child: Container(
                        decoration: buildPrimaryPanelDecoration(),
                        child: Padding(
                          padding: padding,
                          child: child,
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

BoxDecoration buildSurfaceCardDecoration({bool glow = false}) {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        AppColors.surface.withOpacity(glow ? 0.98 : 0.93),
        AppColors.surfaceDark.withOpacity(0.96),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(
      color: Colors.white.withOpacity(glow ? 0.14 : 0.08),
    ),
    boxShadow: glow
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 50,
              spreadRadius: 18,
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 32,
              spreadRadius: 10,
            ),
          ],
  );
}

InputDecoration buildFormInputDecoration(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: TextStyle(
      color: AppColors.textMuted.withOpacity(0.9),
    ),
    hintStyle: TextStyle(
      color: AppColors.textMuted.withOpacity(0.6),
    ),
    filled: true,
    fillColor: AppColors.surface.withOpacity(0.9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: Colors.white.withOpacity(0.12),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: Colors.white.withOpacity(0.08),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: AppColors.accent.withOpacity(0.8),
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  );
}

class _PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _PageHeader({
    Key? key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textMuted.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              backgroundColor: Colors.white.withOpacity(0.06),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              side: BorderSide(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            icon: const Icon(Icons.arrow_back),
            label: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
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


