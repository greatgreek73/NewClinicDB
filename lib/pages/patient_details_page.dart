import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/patient_bucket.dart';
import '../models/tooth_condition.dart';
import '../models/treatment_palette.dart';
import '../services/dental_chart_repository.dart';
import '../services/patient_bucket_service.dart';
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

class _PatientDetailsContent extends StatefulWidget {
  final PatientDetailsArgs? args;

  const _PatientDetailsContent({Key? key, this.args}) : super(key: key);

  @override
  State<_PatientDetailsContent> createState() => _PatientDetailsContentState();
}

class _PatientDetailsContentState extends State<_PatientDetailsContent> {
  final DentalChartRepository _chartRepository = DentalChartRepository();
  final PatientBucketService _bucketService = PatientBucketService();

  ToothCondition? _selectedCondition;
  Stream<Map<String, ToothCondition>>? _chartStream;
  Stream<Map<String, List<String>>>? _treatmentsStream;
  final TreatmentPalette _treatmentPalette = TreatmentPalette();
  String? _selectedTreatmentType;
  bool _isSavingBucket = false;

  @override
  void initState() {
    super.initState();
    final patientId = widget.args?.patientId;
    if (patientId != null) {
      _chartStream = _chartRepository.watchChart(patientId);
      _treatmentsStream = _chartRepository.watchTreatmentsByTooth(patientId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientId = widget.args?.patientId;
    final fallbackName = widget.args?.displayName ?? 'Patient';

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
        final initialBucket = PatientBucketService.bucketFromData(data);
        final paymentStats = _computePaymentStats(data);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 820;

            final infoCard = _InfoCard(
              resolvedName: resolvedName,
              isLoadingName: isLoadingName,
              patientId: patientId,
              initialBucket: initialBucket,
              isSavingBucket: _isSavingBucket,
              bucketService: _bucketService,
              onBucketSelect: _handleBucketSelect,
              totalCostText: _formatMoney(paymentStats.totalCost),
              paidTotalText: _formatMoney(paymentStats.totalPaid),
            );

            final scheduleCard = _ScheduleCard();

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
                const SizedBox(height: 20),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: infoCard),
                      const SizedBox(width: 24),
                      Expanded(child: scheduleCard),
                    ],
                  )
                else ...[
                  infoCard,
                  const SizedBox(height: 24),
                  scheduleCard,
                ],
                const SizedBox(height: 28),
                _buildDentalChart(patientId),
                const SizedBox(height: 16),
                _buildBucketSummary(patientId, initialBucket),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBucketSummary(String? patientId, int? initialBucket) {
    final resolvedId = patientId;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: buildSurfaceCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Priority basket status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                StreamBuilder<int?>(
                  stream: resolvedId == null
                      ? const Stream.empty()
                      : _bucketService.watchPatientBucket(resolvedId),
                  initialData: initialBucket,
                  builder: (context, snapshot) {
                    final bucketId = snapshot.data ?? initialBucket;
                    final bucket = bucketId != null ? bucketById(bucketId) : null;
                    final title = bucket?.title ?? 'No basket selected';
                    final desc =
                        bucket?.description ?? 'Choose a basket at the top near the name.';
                    return Text(
                      '$title — $desc',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted.withOpacity(0.9),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _BucketIconRow(
            activeBucket: initialBucket,
            enabled: false,
            isSaving: false,
            onTap: null,
          ),
        ],
      ),
    );
  }

  Future<void> _handleBucketSelect(
    String patientId,
    int bucketId,
    int? currentBucket,
  ) async {
    if (_isSavingBucket || currentBucket == bucketId) return;
    setState(() {
      _isSavingBucket = true;
    });

    try {
      await _bucketService.setPatientBucket(patientId, bucketId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Assigned to ${bucketById(bucketId)?.title ?? 'bucket $bucketId'}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update bucket: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingBucket = false;
        });
      }
    }
  }

  Widget _buildDentalChart(String? patientId) {
    if (patientId == null) {
      final plan = _buildFallbackTreatmentPlan();
      return _DentalChartSection(
        plan: plan,
        selectedCondition: _selectedCondition,
        availableConditions: _availableConditionsFrom(plan),
        onConditionChange: _handleConditionChange,
        readOnly: true,
        treatmentsByTooth: const {},
        treatmentTypes: const [],
        palette: _treatmentPalette,
      );
    }

    _chartStream ??= _chartRepository.watchChart(patientId);
    final chartStream = _chartStream!;

    _treatmentsStream ??= _chartRepository.watchTreatmentsByTooth(patientId);
    final treatmentsStream = _treatmentsStream!;

    return StreamBuilder<Map<String, List<String>>>(
      stream: treatmentsStream,
      builder: (context, treatmentSnapshot) {
        final treatmentsByTooth =
            treatmentSnapshot.data ?? <String, List<String>>{};
        final treatmentTypes = _mergeTreatmentTypes(treatmentsByTooth);

        return StreamBuilder<Map<String, ToothCondition>>(
          stream: chartStream,
          builder: (context, snapshot) {
            final plan = snapshot.data ?? <String, ToothCondition>{};
            final available = _availableConditionsFrom(plan);
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final errorMessage =
                snapshot.hasError
                    ? snapshot.error?.toString() ?? 'Unable to load dental chart'
                    : null;

            return _DentalChartSection(
              plan: plan,
              selectedCondition: _selectedCondition,
              availableConditions: available,
              onConditionChange: _handleConditionChange,
              onToothTap: (tooth) => _handleToothTap(patientId, tooth),
              isLoading: isLoading,
              error: errorMessage,
              treatmentsByTooth: treatmentsByTooth,
              treatmentTypes: treatmentTypes,
              selectedTreatmentType: _selectedTreatmentType,
              onTreatmentTypeChange: _handleTreatmentTypeChange,
              palette: _treatmentPalette,
            );
          },
        );
      },
    );
  }

  void _handleConditionChange(ToothCondition? condition) {
    setState(() {
      _selectedCondition = condition;
    });
  }

  void _handleTreatmentTypeChange(String? type) {
    setState(() {
      _selectedTreatmentType = type == _selectedTreatmentType ? null : type;
    });
  }

  Future<void> _handleToothTap(String patientId, String tooth) async {
    final condition = _selectedCondition;
    if (condition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a status first to apply to the tooth.'),
        ),
      );
      return;
    }

    try {
      await _chartRepository.setToothStatus(patientId, tooth, condition);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save tooth status: $error')),
      );
    }
  }

  Map<String, ToothCondition> _buildFallbackTreatmentPlan() {
    return {
      '26': ToothCondition.planned,
      '13': ToothCondition.treated,
      '46': ToothCondition.inProgress,
      '45': ToothCondition.treated,
      '37': ToothCondition.inProgress,
      '31': ToothCondition.treated,
    };
  }

  List<ToothCondition> _availableConditionsFrom(
    Map<String, ToothCondition> plan,
  ) {
    final unique = <ToothCondition>{};
    unique.addAll(plan.values);
    unique.remove(ToothCondition.healthy);
    return unique.isEmpty ? ToothCondition.values.toList() : unique.toList();
  }

  List<String> _mergeTreatmentTypes(
    Map<String, List<String>> treatmentsByTooth,
  ) {
    final merged = <String>{};
    for (final list in treatmentsByTooth.values) {
      merged.addAll(list);
    }
    final sorted = merged.toList()..sort((a, b) => a.compareTo(b));
    return sorted;
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

  PaymentStats _computePaymentStats(Map<String, dynamic>? data) {
    if (data == null) return PaymentStats.empty();

    final priceValue = data['price'];
    final totalCost = priceValue is num ? priceValue.toDouble() : null;

    double totalPaid = 0;
    final paymentsRaw = data['payments'];
    if (paymentsRaw is List) {
      for (final p in paymentsRaw) {
        if (p is Map) {
          final amount = p['amount'];
          if (amount is num) {
            totalPaid += amount.toDouble();
          }
        }
      }
    }

    return PaymentStats(totalCost: totalCost, totalPaid: totalPaid);
  }

  String _formatMoney(double? amount) {
    if (amount == null) return '--';
    final isInt = amount % 1 == 0;
    final formatted = isInt ? amount.toInt().toString() : amount.toStringAsFixed(2);
    return '\$$formatted';
  }
}

class PaymentStats {
  final double? totalCost;
  final double totalPaid;

  const PaymentStats({
    required this.totalCost,
    required this.totalPaid,
  });

  factory PaymentStats.empty() => const PaymentStats(totalCost: null, totalPaid: 0);
}

class _InlineBucketSelector extends StatelessWidget {
  final String? patientId;
  final int? initialBucket;
  final bool isSaving;
  final PatientBucketService bucketService;
  final void Function(int bucketId, int? currentBucket)? onSelect;

  const _InlineBucketSelector({
    required this.patientId,
    required this.initialBucket,
    required this.isSaving,
    required this.bucketService,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final hasPatient = patientId != null;
    if (!hasPatient) {
      return _BucketIconRow(
        activeBucket: initialBucket,
        enabled: false,
        isSaving: false,
        onTap: null,
      );
    }

    final resolvedId = patientId!;
    return StreamBuilder<int?>(
      stream: bucketService.watchPatientBucket(resolvedId),
      initialData: initialBucket,
      builder: (context, snapshot) {
        final activeBucket = snapshot.data ?? initialBucket;
        final isStreamLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            activeBucket == null;

        return _BucketIconRow(
          activeBucket: activeBucket,
          enabled: !isSaving && !isStreamLoading,
          isSaving: isSaving || isStreamLoading,
          onTap: (bucketId) => onSelect?.call(bucketId, activeBucket),
        );
      },
    );
  }
}

class _BucketIconRow extends StatelessWidget {
  final int? activeBucket;
  final bool enabled;
  final bool isSaving;
  final ValueChanged<int>? onTap;

  const _BucketIconRow({
    required this.activeBucket,
    required this.enabled,
    required this.isSaving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...patientBuckets.map((bucket) {
          final isActive = bucket.id == activeBucket;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _BucketMiniIcon(
              bucket: bucket,
              isActive: isActive,
              enabled: enabled,
              onTap: onTap == null ? null : () => onTap!(bucket.id),
            ),
          );
        }),
        if (isSaving)
          const SizedBox(
            width: 18,
            height: 18,
            child: Padding(
              padding: EdgeInsets.only(left: 4),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
      ],
    );
  }
}

class _BucketMiniIcon extends StatelessWidget {
  final PatientBucketDefinition bucket;
  final bool isActive;
  final bool enabled;
  final VoidCallback? onTap;

  const _BucketMiniIcon({
    required this.bucket,
    required this.isActive,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = bucket.color;
    final bg = isActive ? color.withOpacity(0.35) : Colors.white.withOpacity(0.08);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Tooltip(
        message: '${bucket.title} (basket ${bucket.id})',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? color.withOpacity(0.9) : Colors.white.withOpacity(0.12),
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 18,
                      spreadRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: Icon(
            Icons.shopping_basket_rounded,
            size: 18,
            color: enabled
                ? (isActive ? AppColors.textPrimary : Colors.white.withOpacity(0.9))
                : Colors.white.withOpacity(0.35),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String resolvedName;
  final bool isLoadingName;
  final String? patientId;
  final int? initialBucket;
  final bool isSavingBucket;
  final PatientBucketService bucketService;
  final Future<void> Function(String patientId, int bucketId, int? currentBucket)?
      onBucketSelect;
  final String totalCostText;
  final String paidTotalText;

  const _InfoCard({
    required this.resolvedName,
    required this.isLoadingName,
    required this.patientId,
    required this.initialBucket,
    required this.isSavingBucket,
    required this.bucketService,
    required this.onBucketSelect,
    required this.totalCostText,
    required this.paidTotalText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolvedName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    const SizedBox(height: 8),
                    _InlineBucketSelector(
                      patientId: patientId,
                      initialBucket: initialBucket,
                      isSaving: isSavingBucket,
                      bucketService: bucketService,
                      onSelect: (bucketId, currentBucket) {
                        if (patientId == null || onBucketSelect == null) return;
                        onBucketSelect!(patientId!, bucketId, currentBucket);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildInfoChip('Total cost', totalCostText),
              const SizedBox(width: 12),
              _buildInfoChip('Paid to date', paidTotalText),
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
}

class _ScheduleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
class _DentalChartSection extends StatelessWidget {
  final Map<String, ToothCondition> plan;
  final ToothCondition? selectedCondition;
  final List<ToothCondition> availableConditions;
  final ValueChanged<ToothCondition?> onConditionChange;
  final ValueChanged<String>? onToothTap;
  final bool isLoading;
  final String? error;
  final bool readOnly;
  final Map<String, List<String>> treatmentsByTooth;
  final List<String> treatmentTypes;
  final String? selectedTreatmentType;
  final ValueChanged<String?>? onTreatmentTypeChange;
  final TreatmentPalette palette;

  const _DentalChartSection({
    required this.plan,
    required this.selectedCondition,
    required this.availableConditions,
    required this.onConditionChange,
    this.onToothTap,
    this.isLoading = false,
    this.error,
    this.readOnly = false,
    this.treatmentsByTooth = const {},
    this.treatmentTypes = const [],
    this.selectedTreatmentType,
    this.onTreatmentTypeChange,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    const upperJaw = [
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
    const lowerJaw = [
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
    final displayPlan = _buildDisplayPlan([...upperJaw, ...lowerJaw]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: buildSurfaceCardDecoration(glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dental chart',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap a status to highlight specific treatments.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _DentalLegend(
                    availableConditions: availableConditions,
                    selectedCondition: selectedCondition,
                    onChanged: onConditionChange,
                    treatmentTypes: treatmentTypes,
                    selectedTreatmentType: selectedTreatmentType,
                    onTreatmentTypeChange: onTreatmentTypeChange,
                    palette: palette,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Select a patient to enable chart editing.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted.withOpacity(0.85),
                ),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ),
          if (isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                minHeight: 4,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                backgroundColor: Colors.white.withOpacity(0.08),
              ),
            ),
          const SizedBox(height: 24),
          _ToothRow(
            labels: upperJaw,
            plan: displayPlan,
            toothTreatments: treatmentsByTooth,
            palette: palette,
            selectedTreatmentType: selectedTreatmentType,
            onToothTap: readOnly ? null : onToothTap,
          ),
          const SizedBox(height: 16),
          _ToothRow(
            labels: lowerJaw,
            plan: displayPlan,
            inverted: true,
            toothTreatments: treatmentsByTooth,
            palette: palette,
            selectedTreatmentType: selectedTreatmentType,
            onToothTap: readOnly ? null : onToothTap,
          ),
        ],
      ),
    );
  }

  Map<String, ToothCondition> _buildDisplayPlan(List<String> teeth) {
    final result = <String, ToothCondition>{};
    for (final tooth in teeth) {
      final condition = plan[tooth] ?? ToothCondition.healthy;
      final matchesCondition =
          selectedCondition == null || selectedCondition == condition;
      final matchesTreatment =
          selectedTreatmentType == null ||
          (treatmentsByTooth[tooth]?.contains(selectedTreatmentType) ?? false);
      result[tooth] =
          matchesCondition && matchesTreatment
              ? condition
              : ToothCondition.healthy;
    }
    return result;
  }
}

class _ToothRow extends StatelessWidget {
  final List<String> labels;
  final Map<String, ToothCondition> plan;
  final bool inverted;
  final ValueChanged<String>? onToothTap;
  final Map<String, List<String>> toothTreatments;
  final TreatmentPalette palette;
  final String? selectedTreatmentType;

  const _ToothRow({
    required this.labels,
    required this.plan,
    required this.toothTreatments,
    required this.palette,
    this.selectedTreatmentType,
    this.onToothTap,
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
                    condition: plan[label] ?? ToothCondition.healthy,
                    inverted: inverted,
                    treatments: toothTreatments[label] ?? const [],
                    selectedTreatmentType: selectedTreatmentType,
                    palette: palette,
                    onTap:
                        onToothTap != null ? () => onToothTap!(label) : null,
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _DentalLegend extends StatelessWidget {
  final List<ToothCondition> availableConditions;
  final ToothCondition? selectedCondition;
  final ValueChanged<ToothCondition?> onChanged;
  final List<String> treatmentTypes;
  final String? selectedTreatmentType;
  final ValueChanged<String?>? onTreatmentTypeChange;
  final TreatmentPalette palette;

  const _DentalLegend({
    required this.availableConditions,
    required this.selectedCondition,
    required this.onChanged,
    required this.treatmentTypes,
    required this.selectedTreatmentType,
    required this.onTreatmentTypeChange,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    const chipPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final chipBorder = BorderSide(color: Colors.white.withOpacity(0.12));
    final conditions = (availableConditions.isEmpty
            ? ToothCondition.values
            : availableConditions)
        .where((c) => c != ToothCondition.treated)
        .toList();

    const maxVisibleTypes = 4;
    final visibleTypes = treatmentTypes.take(maxVisibleTypes).toList();
    final extraCount = treatmentTypes.length - visibleTypes.length;

    final chips = <Widget>[
      ...visibleTypes.map((type) {
        final isSelected = selectedTreatmentType == type;
        final color = palette.colorFor(type);
        return ChoiceChip(
          label: Text(type),
          selected: isSelected,
          selectedColor: color,
          backgroundColor: color.withOpacity(0.2),
          labelStyle: TextStyle(
            fontSize: 10,
            color: isSelected ? AppColors.bg : AppColors.textPrimary,
          ),
          labelPadding: chipPadding,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: chipBorder,
          onSelected: onTreatmentTypeChange == null
              ? null
              : (_) => onTreatmentTypeChange!(
                    isSelected ? null : type,
                  ),
        );
      }),
      if (extraCount > 0)
        ChoiceChip(
          label: Text('+$extraCount'),
          selected: false,
          backgroundColor: Colors.white.withOpacity(0.08),
          labelStyle:
              const TextStyle(fontSize: 10, color: AppColors.textPrimary),
          labelPadding: chipPadding,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: chipBorder,
          onSelected:
              onTreatmentTypeChange == null
                  ? null
                  : (_) => _showTreatmentPicker(context),
        ),
      ...conditions.map((condition) {
        final isSelected = selectedCondition == condition;
        return ChoiceChip(
          label: Text(condition.label),
          avatar: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: condition.color,
              shape: BoxShape.circle,
            ),
          ),
          selected: isSelected,
          selectedColor: condition.color,
          backgroundColor: Colors.white.withOpacity(0.06),
          labelStyle: TextStyle(
            fontSize: 10,
            color: isSelected ? AppColors.bg : AppColors.textMuted,
          ),
          labelPadding: chipPadding,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: chipBorder,
          onSelected: (_) => onChanged(isSelected ? null : condition),
        );
      }),
    ];

    final spacedChips = <Widget>[];
    for (var i = 0; i < chips.length; i++) {
      spacedChips.add(chips[i]);
      if (i != chips.length - 1) {
        spacedChips.add(const SizedBox(width: 4));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: spacedChips,
      ),
    );
  }

  void _showTreatmentPicker(BuildContext context) {
    if (onTreatmentTypeChange == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.4),
                    AppColors.accentStrong.withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.98),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.7),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Treatment types',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                onTreatmentTypeChange!(null);
                                Navigator.of(ctx).pop();
                              },
                              child: const Text(
                                'All types',
                                style: TextStyle(color: AppColors.accent),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: treatmentTypes.map((type) {
                            final isSelected = selectedTreatmentType == type;
                            final color = palette.colorFor(type);
                            return ChoiceChip(
                              label: Text(type),
                              selected: isSelected,
                              selectedColor: color,
                              backgroundColor: color.withOpacity(0.2),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? AppColors.bg
                                    : AppColors.textPrimary,
                              ),
                              onSelected: (_) {
                                onTreatmentTypeChange!(
                                  isSelected ? null : type,
                                );
                                Navigator.of(ctx).pop();
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToothTile extends StatelessWidget {
  final String label;
  final ToothCondition condition;
  final bool inverted;
  final VoidCallback? onTap;
  final List<String> treatments;
  final String? selectedTreatmentType;
  final TreatmentPalette palette;

  const _ToothTile({
    required this.label,
    required this.condition,
    required this.inverted,
    required this.treatments,
    required this.palette,
    this.selectedTreatmentType,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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
          if (treatments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _TreatmentDots(
                treatments: treatments,
                palette: palette,
                selectedTreatmentType: selectedTreatmentType,
              ),
            ),
        ],
      ),
    );
  }
}

class _TreatmentDots extends StatelessWidget {
  final List<String> treatments;
  final TreatmentPalette palette;
  final String? selectedTreatmentType;

  const _TreatmentDots({
    required this.treatments,
    required this.palette,
    this.selectedTreatmentType,
  });

  @override
  Widget build(BuildContext context) {
    final unique = {...treatments}.toList()..sort();
    final visible = unique.take(4).toList();
    final rest = unique.length - visible.length;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        ...visible.map(_buildDot),
        if (rest > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '+$rest',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textMuted.withOpacity(0.9),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDot(String type) {
    final color = palette.colorFor(type);
    final isSelected = selectedTreatmentType == null
        ? true
        : selectedTreatmentType == type;

    return Tooltip(
      message: type,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.85) : color.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Text(
          type.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(isSelected ? 0.95 : 0.7),
          ),
        ),
      ),
    );
  }
}

class _ToothShape extends StatelessWidget {
  final ToothCondition condition;

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
        border: Border.all(color: Colors.white.withOpacity(0.15)),
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
