import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/waitlist_stage.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../theme/system_ui.dart';
import '../utils/decorations.dart';
import '../services/waitlist_service.dart';
import 'add_patient_page.dart';
import 'patient_3d_graph_page.dart';
import 'patient_details_page.dart';
import 'search_page.dart';

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
  final WaitlistService _waitlistService = WaitlistService();

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
      final client = maybeSupabaseClient;
      if (client == null) {
        setState(() {
          _patientsError = 'Supabase is not configured';
          _todayPatientsCount = null;
        });
        return;
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await client
          .from('treatments')
          .select('id,patient_id,date')
          .gte('date', startOfDay.toUtc().toIso8601String())
          .lt('date', endOfDay.toUtc().toIso8601String());

      final uniquePatients = <String>{};
      for (final item in (snapshot as List)) {
        final data = Map<String, dynamic>.from(item as Map);
        final rawId = data['patient_id'];
        final id = rawId?.toString().trim();
        final fallbackId = (data['id'] ?? '').toString().trim();
        uniquePatients.add(id?.isNotEmpty == true ? id! : fallbackId);
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Container(
                    width: double.infinity,
                    decoration: buildPrimaryPanelDecoration(),
                    child: SafeArea(
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
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 11, child: _buildLeftColumn(context)),
          const SizedBox(width: 32),
          Expanded(flex: 10, child: _buildRightColumn()),
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
        const SizedBox(height: 20),
        _buildWaitlistPanel(),
      ],
    );
  }

  Widget _buildPrimaryActions(BuildContext context) {
    const isFlutterTest = bool.fromEnvironment('FLUTTER_TEST');
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildActionButton(
          context: context,
          label: 'Search',
          icon: Icons.search_rounded,
          onPressed:
              () => Navigator.of(context).pushNamed(SearchPage.routeName),
        ),
        _buildActionButton(
          context: context,
          label: 'Add patient',
          icon: Icons.person_add_alt_1_rounded,
          onPressed:
              () => Navigator.of(context).pushNamed(AddPatientPage.routeName),
        ),
        _buildActionButton(
          context: context,
          label: 'Patient profile',
          icon: Icons.badge_outlined,
          onPressed:
              () =>
                  Navigator.of(context).pushNamed(PatientDetailsPage.routeName),
        ),
        if (!isFlutterTest)
          _buildActionButton(
            context: context,
            label: '3D map',
            icon: Icons.view_in_ar_rounded,
            onPressed:
                () => Navigator.of(
                  context,
                ).pushNamed(Patient3DGraphPage.routeName),
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
            side: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
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
          gradient:
              selected
                  ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accentStrong, AppColors.accent],
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
        _buildStatCard(title: 'Canceled', value: '2', subtitle: 'No-shows: 1'),
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
          gradient:
              highlighted
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
          boxShadow:
              highlighted
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
                color:
                    highlighted
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
                color:
                    highlighted
                        ? AppColors.bg.withOpacity(0.85)
                        : AppColors.textMuted.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitlistPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface.withOpacity(0.96),
            AppColors.surfaceDark.withOpacity(0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 30,
            spreadRadius: 12,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.playlist_add_check_rounded,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              const Text(
                'Waiting list',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Text(
                  '4 stages',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a stage to open the queue. Reorder patients there and move them between waiting list stages.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<WaitlistEntry>>(
            stream: _waitlistService.watchAllWaitlistEntries(),
            builder: (context, snapshot) {
              final allEntries = snapshot.data ?? const <WaitlistEntry>[];
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;

              return LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 12.0;
                  final maxWidth = constraints.maxWidth;
                  final columns = maxWidth >= 760 ? 4 : 2;
                  final itemWidth =
                      (maxWidth - spacing * (columns - 1)) / columns;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children:
                        waitlistStages.map((stage) {
                          final patients =
                              allEntries
                                  .where((entry) => entry.stageId == stage.id)
                                  .toList()
                                ..sort(compareWaitlistEntries);

                          return SizedBox(
                            width: itemWidth,
                            child: _DashboardWaitlistCard(
                              stage: stage,
                              patients: patients,
                              isLoading: isLoading,
                              onTap: () => _openWaitlistStage(stage),
                            ),
                          );
                        }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _openWaitlistStage(WaitlistStageDefinition stage) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return _WaitlistPatientsSheet(stage: stage, service: _waitlistService);
      },
    );
  }

  Widget _buildRightColumn() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surface, AppColors.surfaceDark],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
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
            border: Border.all(color: Colors.white.withOpacity(0.18)),
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
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
        border: Border.all(color: Colors.white.withOpacity(0.14)),
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
          Divider(color: Colors.white.withOpacity(0.12)),
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
          colors:
              important
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
          color:
              important
                  ? AppColors.accentSoft.withOpacity(0.9)
                  : Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.bgMid, AppColors.bg]),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
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
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              if (important) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
                    style: TextStyle(fontSize: 11, color: AppColors.bg),
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

class _DashboardWaitlistCard extends StatelessWidget {
  final WaitlistStageDefinition stage;
  final List<WaitlistEntry> patients;
  final bool isLoading;
  final VoidCallback onTap;

  const _DashboardWaitlistCard({
    required this.stage,
    required this.patients,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = stage.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              baseColor.withOpacity(0.2),
              AppColors.surfaceDark.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: baseColor.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.4),
              blurRadius: 28,
              spreadRadius: 8,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(stage.icon, size: 22, color: baseColor),
                ),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  child: Center(
                    child:
                        isLoading
                            ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(baseColor),
                              ),
                            )
                            : Text(
                              '${patients.length}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              stage.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stage.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textMuted.withOpacity(0.88),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitlistPatientsSheet extends StatelessWidget {
  final WaitlistStageDefinition stage;
  final WaitlistService service;

  const _WaitlistPatientsSheet({required this.stage, required this.service});

  @override
  Widget build(BuildContext context) {
    void openPatientProfile(WaitlistEntry patient) {
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.pushNamed(
        PatientDetailsPage.routeName,
        arguments: PatientDetailsArgs(
          patientId: patient.id,
          displayName: patient.title,
        ),
      );
    }

    Future<void> runAction(
      Future<void> Function() action, {
      String? successMessage,
    }) async {
      try {
        await action();
        if (!context.mounted) return;
        if (successMessage != null && successMessage.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(successMessage)));
        }
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update waiting list: $error')),
        );
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, minHeight: 320),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withOpacity(0.35),
                AppColors.accentStrong.withOpacity(0.45),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.98),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Waiting list',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FutureBuilder<WaitlistSchemaCapabilities>(
                      future: service.getCapabilities(),
                      builder: (context, capabilitiesSnapshot) {
                        final capabilities = capabilitiesSnapshot.data;
                        final supportsOrdering =
                            capabilities?.supportsPersistentOrdering ?? true;

                        return StreamBuilder<List<WaitlistEntry>>(
                          stream: service.watchPatientsInStage(stage.id),
                          builder: (context, snapshot) {
                            final patients =
                                snapshot.data ?? const <WaitlistEntry>[];
                            final isLoading =
                                snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                      ),
                                      child: Icon(
                                        stage.icon,
                                        color: stage.color,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stage.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Queue for stage ${stage.id}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted
                                                .withOpacity(0.85),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: stage.color.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: stage.color.withOpacity(0.35),
                                        ),
                                      ),
                                      child: Text(
                                        '${patients.length}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: stage.color.withOpacity(0.9),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (capabilities?.needsWaitlistMigration ??
                                    false) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.08),
                                      ),
                                    ),
                                    child: Text(
                                      supportsOrdering
                                          ? 'This project is still using the legacy waitlist field. Apply the Supabase migration to finish the schema update.'
                                          : 'Queue order is read-only until the Supabase waitlist migration is applied.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted.withOpacity(
                                          0.9,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: stage.color.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: stage.color.withOpacity(0.18),
                                    ),
                                  ),
                                  child: Text(
                                    'Patients are sorted by days since first payment, from longest-waiting to newest.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted.withOpacity(
                                        0.92,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Expanded(
                                  child:
                                      isLoading
                                          ? Align(
                                            alignment: Alignment.topCenter,
                                            child: LinearProgressIndicator(
                                              minHeight: 4,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    stage.color,
                                                  ),
                                              backgroundColor: Colors.white
                                                  .withOpacity(0.08),
                                            ),
                                          )
                                          : patients.isEmpty
                                          ? Center(
                                            child: Text(
                                              'No patients are in this waiting list stage yet.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textMuted
                                                    .withOpacity(0.85),
                                              ),
                                            ),
                                          )
                                          : ListView.separated(
                                            physics:
                                                const BouncingScrollPhysics(),
                                            itemBuilder: (context, index) {
                                              final patient = patients[index];
                                              final hasPrevStage = stage.id > 1;
                                              final hasNextStage =
                                                  stage.id <
                                                  waitlistStages.length;

                                              return _WaitlistPatientTile(
                                                accentColor: stage.color,
                                                queueNumber: index + 1,
                                                title: patient.title,
                                                subtitle: patient.subtitle,
                                                firstPaymentDate:
                                                    patient.firstPaymentDate,
                                                onOpenPatient:
                                                    () => openPatientProfile(
                                                      patient,
                                                    ),
                                                onMoveUp: null,
                                                onMoveDown: null,
                                                onMovePrevStage:
                                                    !hasPrevStage
                                                        ? null
                                                        : () => runAction(
                                                          () => service
                                                              .movePatientToStage(
                                                                patient.id,
                                                                stage.id - 1,
                                                              ),
                                                          successMessage:
                                                              'Moved ${patient.title} to ${waitlistStageById(stage.id - 1)?.title ?? 'stage ${stage.id - 1}'}.',
                                                        ),
                                                onMoveNextStage:
                                                    !hasNextStage
                                                        ? null
                                                        : () => runAction(
                                                          () => service
                                                              .movePatientToStage(
                                                                patient.id,
                                                                stage.id + 1,
                                                              ),
                                                          successMessage:
                                                              'Moved ${patient.title} to ${waitlistStageById(stage.id + 1)?.title ?? 'stage ${stage.id + 1}'}.',
                                                        ),
                                                onRemove:
                                                    () => runAction(
                                                      () => service
                                                          .removeFromWaitlist(
                                                            patient.id,
                                                          ),
                                                      successMessage:
                                                          'Removed ${patient.title} from waiting list.',
                                                    ),
                                              );
                                            },
                                            separatorBuilder:
                                                (_, __) =>
                                                    const SizedBox(height: 10),
                                            itemCount: patients.length,
                                          ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitlistPatientTile extends StatefulWidget {
  final Color accentColor;
  final int queueNumber;
  final String title;
  final String subtitle;
  final DateTime? firstPaymentDate;
  final VoidCallback onOpenPatient;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onMovePrevStage;
  final VoidCallback? onMoveNextStage;
  final VoidCallback onRemove;

  const _WaitlistPatientTile({
    required this.accentColor,
    required this.queueNumber,
    required this.title,
    required this.subtitle,
    required this.firstPaymentDate,
    required this.onOpenPatient,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onMovePrevStage,
    required this.onMoveNextStage,
    required this.onRemove,
  });

  @override
  State<_WaitlistPatientTile> createState() => _WaitlistPatientTileState();
}

class _WaitlistPatientTileState extends State<_WaitlistPatientTile> {
  bool _isPulsing = false;
  bool _isBusy = false;

  Future<void> _handleOpenPatient() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
      _isPulsing = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    widget.onOpenPatient();

    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    setState(() {
      _isBusy = false;
      _isPulsing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            _isPulsing
                ? widget.accentColor.withOpacity(0.08)
                : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              _isPulsing
                  ? widget.accentColor.withOpacity(0.46)
                  : Colors.white.withOpacity(0.08),
        ),
        boxShadow:
            _isPulsing
                ? [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.28),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ]
                : const [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: widget.accentColor.withOpacity(0.15),
            child: Text(
              '${widget.queueNumber}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _WaitlistPatientInfoButton(
              accentColor: widget.accentColor,
              title: widget.title,
              queueLabel: 'Queue #${widget.queueNumber}',
              subtitle: widget.subtitle,
              firstPaymentDate: widget.firstPaymentDate,
              onTap: _handleOpenPatient,
            ),
          ),
          if (widget.onMoveUp != null || widget.onMoveDown != null) ...[
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Move up',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onMoveUp,
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                  color: AppColors.textPrimary,
                ),
                IconButton(
                  tooltip: 'Move down',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onMoveDown,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ],
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Move to previous stage',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onMovePrevStage,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                color: AppColors.textPrimary,
              ),
              IconButton(
                tooltip: 'Move to next stage',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onMoveNextStage,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                color: AppColors.textPrimary,
              ),
            ],
          ),
          IconButton(
            tooltip: 'Remove from waiting list',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: Colors.redAccent.withOpacity(0.9),
          ),
        ],
      ),
    );
  }
}

class _WaitlistPatientInfoButton extends StatelessWidget {
  final Color accentColor;
  final String title;
  final String queueLabel;
  final String subtitle;
  final DateTime? firstPaymentDate;
  final VoidCallback onTap;

  const _WaitlistPatientInfoButton({
    required this.accentColor,
    required this.title,
    required this.queueLabel,
    required this.subtitle,
    required this.firstPaymentDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final paymentBadge = _paymentAgeBadgeData(firstPaymentDate);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (paymentBadge != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: paymentBadge.backgroundColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: paymentBadge.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.08),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      paymentBadge.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: paymentBadge.textColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (paymentBadge != null) const SizedBox(height: 6),
            Text(
              queueLabel,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted.withOpacity(0.82),
              ),
            ),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted.withOpacity(0.85),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

_PaymentAgeBadgeData? _paymentAgeBadgeData(DateTime? firstPaymentDate) {
  final days = _daysSinceFirstPayment(firstPaymentDate);
  if (days == null) return null;

  if (days >= 8) {
    return _PaymentAgeBadgeData(
      label: 'Paid ${days}d ago',
      backgroundColor: const Color(0x26FF6B6B),
      borderColor: const Color(0x66FF6B6B),
      textColor: const Color(0xFFFFB3B3),
    );
  }

  if (days >= 3) {
    return _PaymentAgeBadgeData(
      label: 'Paid ${days}d ago',
      backgroundColor: const Color(0x26FFB347),
      borderColor: const Color(0x66FFB347),
      textColor: const Color(0xFFFFD59A),
    );
  }

  return _PaymentAgeBadgeData(
    label: 'Paid ${days}d ago',
    backgroundColor: Colors.white.withOpacity(0.05),
    borderColor: Colors.white.withOpacity(0.10),
    textColor: AppColors.textMuted.withOpacity(0.95),
  );
}

int? _daysSinceFirstPayment(DateTime? firstPaymentDate, {DateTime? now}) {
  if (firstPaymentDate == null) return null;

  final localNow = (now ?? DateTime.now()).toLocal();
  final localPaymentDate = firstPaymentDate.toLocal();
  final startOfToday = DateTime(localNow.year, localNow.month, localNow.day);
  final startOfPaymentDay = DateTime(
    localPaymentDate.year,
    localPaymentDate.month,
    localPaymentDate.day,
  );

  final difference = startOfToday.difference(startOfPaymentDay).inDays;
  return difference < 0 ? 0 : difference;
}

class _PaymentAgeBadgeData {
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const _PaymentAgeBadgeData({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });
}
