import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/system_ui.dart';
import '../utils/decorations.dart';
import 'add_patient_page.dart';
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
