import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/decorations.dart';
import '../widgets/page_header.dart';
import '../widgets/primary_page_scaffold.dart';

class PatientDetailsArgs {
  final String patientId;
  final String? displayName;

  const PatientDetailsArgs({required this.patientId, this.displayName});
}

class PatientDetailsPage extends StatelessWidget {
  static const routeName = '/patient-details';

  const PatientDetailsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as PatientDetailsArgs?;

    return PrimaryPageScaffold(
      maxWidth: 1100,
      child: _PatientDetailsContent(args: args),
    );
  }
}

class _PatientDetailsContent extends StatelessWidget {
  final PatientDetailsArgs? args;

  const _PatientDetailsContent({Key? key, this.args}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final patientId = args?.patientId;
    final fallbackName = args?.displayName ?? 'Patient';

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          patientId != null
              ? FirebaseFirestore.instance
                  .collection('patients')
                  .doc(patientId)
                  .get()
              : null,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final resolvedName = _resolvePatientName(data, fallbackName);
        final isLoadingName =
            patientId != null &&
            snapshot.connectionState == ConnectionState.waiting;

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
                            Text(
                              resolvedName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isLoadingName
                                  ? 'Loading patient profile...'
                                  : 'Member since 2019 - VIP Plan',
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
                        _buildInfoChip('Last visit', '14 Nov - Hygiene'),
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
                    _buildContactRow(
                      Icons.email_outlined,
                      'anna.petrova@email.com',
                    ),
                    const SizedBox(height: 8),
                    _buildContactRow(
                      Icons.location_on_outlined,
                      'Downtown branch - Room 2',
                    ),
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
                        meta: 'Dr. Emily Ross - Room 4',
                        highlight: true,
                      ),
                      _AppointmentRow(
                        date: '04 Dec',
                        title: 'Crown placement & hygiene',
                        meta: 'Dr. Gomez - Room 1',
                      ),
                      _AppointmentRow(
                        date: '11 Jan',
                        title: 'Follow-up & whitening',
                        meta: 'Dr. Emily Ross - Room 2',
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
                PageHeader(
                  title: 'Patient overview',
                  subtitle:
                      'Track history, update notes and schedule new visits for your patients.',
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
                const SizedBox(height: 28),
                const _DentalChartSection(),
              ],
            );
          },
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
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  String _resolvePatientName(Map<String, dynamic>? data, String fallbackName) {
    if (data == null) return fallbackName;
    final first = data['name']?.toString().trim() ?? '';
    final last = data['surname']?.toString().trim() ?? '';
    final combined = (first + ' ' + last).trim();
    if (combined.isNotEmpty) return combined;
    if (last.isNotEmpty) return last;
    if (first.isNotEmpty) return first;
    return fallbackName;
  }
}

class _DentalChartSection extends StatelessWidget {
  const _DentalChartSection();

  @override
  Widget build(BuildContext context) {
    final themeText = Theme.of(context).textTheme;
    final upperJaw = [
      '18',
      '17',
      '16',
      '15',
      '14',
      '13',
      '12',
      '11',
      '21',
      '22',
      '23',
      '24',
      '25',
      '26',
      '27',
      '28',
    ];
    final lowerJaw = [
      '48',
      '47',
      '46',
      '45',
      '44',
      '43',
      '42',
      '41',
      '31',
      '32',
      '33',
      '34',
      '35',
      '36',
      '37',
      '38',
    ];

    final Map<String, _ToothCondition> plan = {
      '26': _ToothCondition.planned,
      '13': _ToothCondition.treated,
      '46': _ToothCondition.inProgress,
      '37': _ToothCondition.inProgress,
      '31': _ToothCondition.treated,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: buildSurfaceCardDecoration(glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dental chart',
                    style: themeText.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap a tooth to document treatment progress.',
                    style: themeText.bodySmall?.copyWith(
                      color: AppColors.textMuted.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              _DentalLegend(),
            ],
          ),
          const SizedBox(height: 24),
          _ToothRow(labels: upperJaw, plan: plan),
          const SizedBox(height: 16),
          _ToothRow(labels: lowerJaw, plan: plan, inverted: true),
        ],
      ),
    );
  }
}

class _ToothRow extends StatelessWidget {
  final List<String> labels;
  final Map<String, _ToothCondition> plan;
  final bool inverted;

  const _ToothRow({
    required this.labels,
    required this.plan,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children:
          labels
              .map(
                (label) => Expanded(
                  child: _ToothTile(
                    label: label,
                    condition: plan[label] ?? _ToothCondition.healthy,
                    inverted: inverted,
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _DentalLegend extends StatelessWidget {
  const _DentalLegend();

  @override
  Widget build(BuildContext context) {
    final entries = [
      _LegendEntry(color: _ToothCondition.healthy.color, label: 'Healthy'),
      _LegendEntry(color: _ToothCondition.treated.color, label: 'Treated'),
      _LegendEntry(
        color: _ToothCondition.inProgress.color,
        label: 'In progress',
      ),
      _LegendEntry(color: _ToothCondition.planned.color, label: 'Planned'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          entries
              .map(
                (entry) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: entry.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
    );
  }
}

class _LegendEntry {
  final Color color;
  final String label;

  _LegendEntry({required this.color, required this.label});
}

class _ToothTile extends StatelessWidget {
  final String label;
  final _ToothCondition condition;
  final bool inverted;

  const _ToothTile({
    required this.label,
    required this.condition,
    required this.inverted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (inverted) _ToothShape(condition: condition),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: AppColors.textMuted.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 8),
        if (!inverted) _ToothShape(condition: condition),
      ],
    );
  }
}

class _ToothShape extends StatelessWidget {
  final _ToothCondition condition;

  const _ToothShape({required this.condition});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            condition.color.withOpacity(0.85),
            condition.color.withOpacity(0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            spreadRadius: 4,
          ),
        ],
      ),
    );
  }
}

enum _ToothCondition { healthy, treated, inProgress, planned }

extension on _ToothCondition {
  Color get color {
    switch (this) {
      case _ToothCondition.healthy:
        return AppColors.surfaceDark.withOpacity(0.9);
      case _ToothCondition.treated:
        return AppColors.accent.withOpacity(0.9);
      case _ToothCondition.inProgress:
        return Colors.pinkAccent.withOpacity(0.9);
      case _ToothCondition.planned:
        return Colors.tealAccent.withOpacity(0.9);
    }
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
              gradient: LinearGradient(colors: [AppColors.bgMid, AppColors.bg]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                  colors: [AppColors.accentStrong, AppColors.accent],
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
