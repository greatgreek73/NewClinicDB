import 'package:flutter/material.dart';

import '../models/waitlist_stage.dart';
import '../models/tooth_condition.dart';
import '../models/treatment_palette.dart';
import '../services/dental_chart_repository.dart';
import '../services/id_generator.dart';
import '../services/patient_payment_service.dart';
import '../services/supabase_client.dart';
import '../services/treatment_data_service.dart';
import '../services/waitlist_service.dart';
import '../theme/app_colors.dart';
import '../utils/decorations.dart';
import '../utils/patient_name_formatter.dart';
import 'treatment_timeline_utils.dart';
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

    return PrimaryPageScaffold(child: _PatientDetailsContent(args: args));
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
  final WaitlistService _waitlistService = WaitlistService();

  ToothCondition? _selectedCondition;
  Stream<Map<String, ToothCondition>>? _chartStream;
  Stream<Map<String, List<String>>>? _treatmentsStream;
  final TreatmentPalette _treatmentPalette = TreatmentPalette();
  String? _selectedTreatmentType;
  bool _isSavingWaitlist = false;
  bool _isSavingPayments = false;

  @override
  void initState() {
    super.initState();
    final patientId = widget.args?.patientId;
    if (patientId != null) {
      _rebuildTreatmentStreams(patientId);
    }
  }

  void _rebuildTreatmentStreams(String patientId) {
    _chartStream = _chartRepository.watchChart(patientId);
    _treatmentsStream = _chartRepository.watchTreatmentsByTooth(patientId);
  }

  void _handleTreatmentsChanged() {
    final patientId = widget.args?.patientId.trim() ?? '';
    if (patientId.isEmpty || !mounted) return;

    setState(() {
      _rebuildTreatmentStreams(patientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final patientId = widget.args?.patientId;
    final fallbackName = widget.args?.displayName ?? 'Patient';

    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadPatient(patientId),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final resolvedName = _resolvePatientName(data, fallbackName);
        final isLoadingName =
            patientId != null &&
            snapshot.connectionState == ConnectionState.waiting;
        final initialWaitlist = waitlistAssignmentFromData(data);
        final paymentStats = _computePaymentStats(data);
        final payments = parsePatientPayments(data?['payments']);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 820;

            final infoCard = _InfoCard(
              resolvedName: resolvedName,
              isLoadingName: isLoadingName,
              patientId: patientId,
              initialWaitlist: initialWaitlist,
              isSavingWaitlist: _isSavingWaitlist,
              waitlistService: _waitlistService,
              onAddToWaitlist: _handleAddToWaitlist,
              onStageSelect: _handleStageSelect,
              onRemoveFromWaitlist: _handleRemoveFromWaitlist,
              totalCostText: _formatMoney(paymentStats.totalCost),
              paidTotalText: _formatMoney(paymentStats.totalPaid),
              payments: payments,
              isSavingPayments: _isSavingPayments,
              onAddPayment:
                  patientId == null
                      ? null
                      : () => _handleAddPayment(patientId, data),
              onEditPayment:
                  patientId == null
                      ? null
                      : (payment) =>
                          _handleEditPayment(patientId, data, payment),
              onDeletePayment:
                  patientId == null
                      ? null
                      : (payment) =>
                          _handleDeletePayment(patientId, data, payment),
            );

            final scheduleCard = _ScheduleCard(
              patientId: patientId,
              onTreatmentsChanged: _handleTreatmentsChanged,
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
                _buildWaitlistSummary(patientId, initialWaitlist),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _loadPatient(String? patientId) async {
    if (patientId == null || patientId.isEmpty) return null;
    final client = maybeSupabaseClient;
    if (client == null) return null;

    final response =
        await client
            .from('patients')
            .select()
            .eq('id', patientId)
            .maybeSingle();
    if (response == null) return null;
    return Map<String, dynamic>.from(response as Map);
  }

  Widget _buildWaitlistSummary(
    String? patientId,
    WaitlistAssignment initialWaitlist,
  ) {
    final resolvedId = patientId;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: buildSurfaceCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waiting list status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                StreamBuilder<WaitlistAssignment>(
                  stream:
                      resolvedId == null
                          ? Stream.value(initialWaitlist)
                          : _waitlistService.watchPatientWaitlist(resolvedId),
                  initialData: initialWaitlist,
                  builder: (context, snapshot) {
                    final assignment = snapshot.data ?? initialWaitlist;
                    final stage =
                        assignment.stageId != null
                            ? waitlistStageById(assignment.stageId!)
                            : null;
                    final title = stage?.title ?? 'Not on waiting list';
                    final desc =
                        stage?.description ??
                        'Add this patient to the waiting list from the card above.';
                    final queueLine =
                        assignment.order != null
                            ? ' Queue position #${assignment.order}.'
                            : assignment.isOnWaitlist
                            ? ' Queue order will appear after the database migration is applied.'
                            : '';
                    return Text(
                      '$title — $desc$queueLine',
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
          StreamBuilder<WaitlistAssignment>(
            stream:
                resolvedId == null
                    ? Stream.value(initialWaitlist)
                    : _waitlistService.watchPatientWaitlist(resolvedId),
            initialData: initialWaitlist,
            builder: (context, snapshot) {
              final assignment = snapshot.data ?? initialWaitlist;
              return _WaitlistStageRow(
                activeStageId: assignment.stageId,
                enabled: false,
                isSaving: false,
                onTap: null,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddToWaitlist(String patientId) async {
    if (_isSavingWaitlist) return;
    setState(() {
      _isSavingWaitlist = true;
    });

    try {
      await _waitlistService.addPatientToWaitlist(patientId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to waiting list: New.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add to waiting list: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingWaitlist = false;
        });
      }
    }
  }

  Future<void> _handleStageSelect(
    String patientId,
    int stageId,
    WaitlistAssignment currentAssignment,
  ) async {
    if (_isSavingWaitlist || currentAssignment.stageId == stageId) return;
    setState(() {
      _isSavingWaitlist = true;
    });

    try {
      if (currentAssignment.isOnWaitlist) {
        await _waitlistService.movePatientToStage(patientId, stageId);
      } else {
        await _waitlistService.addPatientToWaitlist(
          patientId,
          stageId: stageId,
        );
      }
      if (!mounted) return;
      final stageTitle = waitlistStageById(stageId)?.title ?? 'stage $stageId';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Moved to $stageTitle.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update waiting list: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingWaitlist = false;
        });
      }
    }
  }

  Future<void> _handleRemoveFromWaitlist(String patientId) async {
    if (_isSavingWaitlist) return;
    setState(() {
      _isSavingWaitlist = true;
    });

    try {
      await _waitlistService.removeFromWaitlist(patientId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from waiting list.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove from waiting list: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingWaitlist = false;
        });
      }
    }
  }

  Future<void> _handleAddPayment(
    String patientId,
    Map<String, dynamic>? data,
  ) async {
    if (_isSavingPayments) return;

    final draft = await showDialog<_PaymentDraft>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _EditPaymentDialog(),
    );
    if (draft == null) return;

    await _savePayments(
      patientId,
      data,
      (payments) => payments..add(draft.toPayload()),
      successMessage: 'Payment added.',
    );
  }

  Future<void> _handleEditPayment(
    String patientId,
    Map<String, dynamic>? data,
    PatientPayment payment,
  ) async {
    if (_isSavingPayments) return;

    final draft = await showDialog<_PaymentDraft>(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => _EditPaymentDialog(
            initialAmount: payment.amount,
            initialDate: payment.date,
          ),
    );
    if (draft == null) return;

    await _savePayments(patientId, data, (payments) {
      if (payment.storageIndex < 0 || payment.storageIndex >= payments.length) {
        throw StateError(
          'Payment entry is out of sync. Please reopen the patient card.',
        );
      }
      payments[payment.storageIndex] = draft.toPayload();
      return payments;
    }, successMessage: 'Payment updated.');
  }

  Future<void> _handleDeletePayment(
    String patientId,
    Map<String, dynamic>? data,
    PatientPayment payment,
  ) async {
    if (_isSavingPayments) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Delete payment',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              'Delete payment of ${_formatMoney(payment.amount)} dated ${_formatDateLabel(payment.date)}?',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    await _savePayments(patientId, data, (payments) {
      if (payment.storageIndex < 0 || payment.storageIndex >= payments.length) {
        throw StateError(
          'Payment entry is out of sync. Please reopen the patient card.',
        );
      }
      payments.removeAt(payment.storageIndex);
      return payments;
    }, successMessage: 'Payment deleted.');
  }

  Future<void> _savePayments(
    String patientId,
    Map<String, dynamic>? data,
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>> payments)
    transform, {
    required String successMessage,
  }) async {
    if (_isSavingPayments) return;

    final client = maybeSupabaseClient;
    if (client == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase is not configured.')),
      );
      return;
    }

    setState(() {
      _isSavingPayments = true;
    });

    try {
      final currentPayments = clonePatientPaymentsPayload(data?['payments']);
      final nextPayments = transform(currentPayments);

      await client
          .from('patients')
          .update({
            'payments': nextPayments,
            'last_updated': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', patientId);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update payments: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPayments = false;
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
                    ? snapshot.error?.toString() ??
                        'Unable to load dental chart'
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
    return formatPatientDisplayName(
      name: data['name'],
      surname: data['surname'],
      fallback: fallbackName,
    );
  }

  PaymentStats _computePaymentStats(Map<String, dynamic>? data) {
    if (data == null) return PaymentStats.empty();

    final priceValue = data['price'];
    final totalCost = priceValue is num ? priceValue.toDouble() : null;
    final totalPaid = totalPaidFromPayments(data['payments']);

    return PaymentStats(totalCost: totalCost, totalPaid: totalPaid);
  }
}

class PaymentStats {
  final double? totalCost;
  final double totalPaid;

  const PaymentStats({required this.totalCost, required this.totalPaid});

  factory PaymentStats.empty() =>
      const PaymentStats(totalCost: null, totalPaid: 0);
}

String _formatMoney(double? amount) {
  if (amount == null) return '--';
  final isInt = amount % 1 == 0;
  final formatted =
      isInt ? amount.toInt().toString() : amount.toStringAsFixed(2);
  return '\$$formatted';
}

String _formatDateLabel(DateTime date) {
  const monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final localDate = date.toLocal();
  final day = localDate.day.toString().padLeft(2, '0');
  final month = monthLabels[localDate.month - 1];
  return '$day $month ${localDate.year}';
}

class _InlineWaitlistControls extends StatelessWidget {
  final String? patientId;
  final WaitlistAssignment initialWaitlist;
  final bool isSaving;
  final WaitlistService waitlistService;
  final Future<void> Function(String patientId)? onAdd;
  final Future<void> Function(
    String patientId,
    int stageId,
    WaitlistAssignment currentAssignment,
  )?
  onStageSelect;
  final Future<void> Function(String patientId)? onRemove;

  const _InlineWaitlistControls({
    required this.patientId,
    required this.initialWaitlist,
    required this.isSaving,
    required this.waitlistService,
    required this.onAdd,
    required this.onStageSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (patientId == null) {
      return _WaitlistStageRow(
        activeStageId: initialWaitlist.stageId,
        enabled: false,
        isSaving: false,
        onTap: null,
      );
    }

    final resolvedId = patientId!;
    return StreamBuilder<WaitlistAssignment>(
      stream: waitlistService.watchPatientWaitlist(resolvedId),
      initialData: initialWaitlist,
      builder: (context, snapshot) {
        final assignment = snapshot.data ?? initialWaitlist;
        final isStreamLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            assignment.stageId == null;
        final isBusy = isSaving || isStreamLoading;

        if (!assignment.isOnWaitlist) {
          return OutlinedButton.icon(
            onPressed: isBusy ? null : () => onAdd?.call(resolvedId),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: Colors.white.withOpacity(0.18)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon:
                isBusy
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.accent),
                      ),
                    )
                    : const Icon(Icons.playlist_add_rounded, size: 18),
            label: const Text('Add to waiting list'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WaitlistStageRow(
              activeStageId: assignment.stageId,
              enabled: !isBusy,
              isSaving: isBusy,
              onTap:
                  (stageId) =>
                      onStageSelect?.call(resolvedId, stageId, assignment),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    'Queue #${assignment.order ?? '—'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted.withOpacity(0.9),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: isBusy ? null : () => onRemove?.call(resolvedId),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent.withOpacity(0.95),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Remove'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _WaitlistStageRow extends StatelessWidget {
  final int? activeStageId;
  final bool enabled;
  final bool isSaving;
  final ValueChanged<int>? onTap;

  const _WaitlistStageRow({
    required this.activeStageId,
    required this.enabled,
    required this.isSaving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...waitlistStages.map((stage) {
          final isActive = stage.id == activeStageId;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _WaitlistStageIcon(
              stage: stage,
              isActive: isActive,
              enabled: enabled,
              onTap: onTap == null ? null : () => onTap!(stage.id),
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

class _WaitlistStageIcon extends StatelessWidget {
  final WaitlistStageDefinition stage;
  final bool isActive;
  final bool enabled;
  final VoidCallback? onTap;

  const _WaitlistStageIcon({
    required this.stage,
    required this.isActive,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = stage.color;
    final bg =
        isActive ? color.withOpacity(0.35) : Colors.white.withOpacity(0.08);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Tooltip(
        message: '${stage.title} (stage ${stage.id})',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  isActive
                      ? color.withOpacity(0.9)
                      : Colors.white.withOpacity(0.12),
            ),
            boxShadow:
                isActive
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
            stage.icon,
            size: 18,
            color:
                enabled
                    ? (isActive
                        ? AppColors.textPrimary
                        : Colors.white.withOpacity(0.9))
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
  final WaitlistAssignment initialWaitlist;
  final bool isSavingWaitlist;
  final WaitlistService waitlistService;
  final Future<void> Function(String patientId)? onAddToWaitlist;
  final Future<void> Function(
    String patientId,
    int stageId,
    WaitlistAssignment currentAssignment,
  )?
  onStageSelect;
  final Future<void> Function(String patientId)? onRemoveFromWaitlist;
  final String totalCostText;
  final String paidTotalText;
  final List<PatientPayment> payments;
  final bool isSavingPayments;
  final Future<void> Function()? onAddPayment;
  final Future<void> Function(PatientPayment payment)? onEditPayment;
  final Future<void> Function(PatientPayment payment)? onDeletePayment;

  const _InfoCard({
    required this.resolvedName,
    required this.isLoadingName,
    required this.patientId,
    required this.initialWaitlist,
    required this.isSavingWaitlist,
    required this.waitlistService,
    required this.onAddToWaitlist,
    required this.onStageSelect,
    required this.onRemoveFromWaitlist,
    required this.totalCostText,
    required this.paidTotalText,
    required this.payments,
    required this.isSavingPayments,
    required this.onAddPayment,
    required this.onEditPayment,
    required this.onDeletePayment,
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
                    _InlineWaitlistControls(
                      patientId: patientId,
                      initialWaitlist: initialWaitlist,
                      isSaving: isSavingWaitlist,
                      waitlistService: waitlistService,
                      onAdd: onAddToWaitlist,
                      onStageSelect: onStageSelect,
                      onRemove: onRemoveFromWaitlist,
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
          _PaymentsSection(
            payments: payments,
            isSaving: isSavingPayments,
            onAddPayment: onAddPayment,
            onEditPayment: onEditPayment,
            onDeletePayment: onDeletePayment,
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

class _PaymentsSection extends StatelessWidget {
  final List<PatientPayment> payments;
  final bool isSaving;
  final Future<void> Function()? onAddPayment;
  final Future<void> Function(PatientPayment payment)? onEditPayment;
  final Future<void> Function(PatientPayment payment)? onDeletePayment;

  const _PaymentsSection({
    required this.payments,
    required this.isSaving,
    required this.onAddPayment,
    required this.onEditPayment,
    required this.onDeletePayment,
  });

  @override
  Widget build(BuildContext context) {
    final firstPayment = payments.isEmpty ? null : payments.first;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: buildSurfaceCardDecoration(),
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
                    const Text(
                      'Payments',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      firstPayment == null
                          ? 'No payments recorded yet.'
                          : 'First payment: ${_formatDateLabel(firstPayment.date)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: isSaving ? null : onAddPayment,
                icon:
                    isSaving
                        ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add payment'),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (payments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Text(
                'Add the patient payments here. The waiting list will automatically use the earliest payment date.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textMuted.withOpacity(0.9),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < payments.length; index++) ...[
                  _PaymentRow(
                    payment: payments[index],
                    isFirstPayment: index == 0,
                    isSaving: isSaving,
                    onEdit:
                        onEditPayment == null
                            ? null
                            : () => onEditPayment!(payments[index]),
                    onDelete:
                        onDeletePayment == null
                            ? null
                            : () => onDeletePayment!(payments[index]),
                  ),
                  if (index != payments.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final PatientPayment payment;
  final bool isFirstPayment;
  final bool isSaving;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _PaymentRow({
    required this.payment,
    required this.isFirstPayment,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payments_outlined,
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatMoney(payment.amount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (isFirstPayment) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.accent.withOpacity(0.28),
                          ),
                        ),
                        child: const Text(
                          'First payment',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateLabel(payment.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isSaving ? null : onEdit,
            tooltip: 'Edit payment',
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppColors.textPrimary,
          ),
          IconButton(
            onPressed: isSaving ? null : onDelete,
            tooltip: 'Delete payment',
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: Colors.redAccent.withOpacity(0.9),
          ),
        ],
      ),
    );
  }
}

class _PaymentDraft {
  final double amount;
  final DateTime date;

  const _PaymentDraft({required this.amount, required this.date});

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      'amount': amount,
      'date': date.toUtc().toIso8601String(),
    };
  }
}

class _EditPaymentDialog extends StatefulWidget {
  final double? initialAmount;
  final DateTime? initialDate;

  const _EditPaymentDialog({this.initialAmount, this.initialDate});

  @override
  State<_EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends State<_EditPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text:
          widget.initialAmount == null
              ? ''
              : widget.initialAmount! % 1 == 0
              ? widget.initialAmount!.toInt().toString()
              : widget.initialAmount!.toStringAsFixed(2),
    );
    _selectedDate = (widget.initialDate ?? DateTime.now()).toLocal();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 15),
      lastDate: DateTime(now.year + 15),
      helpText: 'Select payment date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDate.hour,
        _selectedDate.minute,
      );
    });
  }

  void _save() {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    setState(() {
      _isSaving = true;
    });
    Navigator.of(
      context,
    ).pop(_PaymentDraft(amount: amount, date: _selectedDate));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing =
        widget.initialAmount != null || widget.initialDate != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isEditing ? 'Edit payment' : 'Add payment',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed:
                              _isSaving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: buildFormInputDecoration(
                        'Amount',
                        hint: 'For example 1500',
                      ),
                      validator: (value) {
                        final normalized =
                            value?.trim().replaceAll(',', '.') ?? '';
                        final amount = double.tryParse(normalized);
                        if (amount == null || amount <= 0) {
                          return 'Enter a valid amount greater than 0.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _isSaving ? null : _pickDate,
                      borderRadius: BorderRadius.circular(18),
                      child: InputDecorator(
                        decoration: buildFormInputDecoration('Payment date'),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatDateLabel(_selectedDate),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _isSaving ? null : _pickDate,
                              child: const Text('Change'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed:
                              _isSaving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentStrong,
                            foregroundColor: AppColors.bg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: Text(
                            isEditing ? 'Save changes' : 'Add payment',
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
      ),
    );
  }
}

class _ScheduleCard extends StatefulWidget {
  final String? patientId;
  final VoidCallback? onTreatmentsChanged;

  const _ScheduleCard({Key? key, this.patientId, this.onTreatmentsChanged})
    : super(key: key);

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  final TreatmentDataService _treatmentStore = TreatmentDataService();
  late Future<List<Map<String, dynamic>>> _timelineFuture;

  @override
  void initState() {
    super.initState();
    _timelineFuture = _loadTimeline();
  }

  @override
  void didUpdateWidget(covariant _ScheduleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) {
      _timelineFuture = _loadTimeline();
    }
  }

  Future<List<Map<String, dynamic>>> _loadTimeline() async {
    final patientId = widget.patientId?.trim();
    if (patientId == null || patientId.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    return _treatmentStore.fetchByPatient(patientId, limit: 120);
  }

  void _refreshTimeline() {
    if (!mounted) return;
    setState(() {
      _timelineFuture = _loadTimeline();
    });
  }

  void _handleTreatmentsChanged() {
    _refreshTimeline();
    widget.onTreatmentsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final patientId = widget.patientId;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: buildSurfaceCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Completed treatments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                    patientId == null
                        ? null
                        : () async {
                          final created = await showDialog<bool>(
                            context: context,
                            barrierDismissible: true,
                            builder:
                                (ctx) =>
                                    _AddTreatmentDialog(patientId: patientId),
                          );
                          if (created == true) {
                            _handleTreatmentsChanged();
                          }
                        },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _timelineFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return LinearProgressIndicator(
                  minHeight: 4,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  backgroundColor: Colors.white.withOpacity(0.08),
                );
              }

              if (snapshot.hasError) {
                return Text(
                  'Failed to load timeline: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                );
              }

              final docs = snapshot.data ?? const <Map<String, dynamic>>[];
              final grouped = buildTreatedTimelineGroups(
                docs,
                maxDays: 3,
                maxEntriesPerDay: 2,
              );

              if (grouped.isEmpty) {
                return Text(
                  'No completed treatments yet for this patient.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted.withOpacity(0.9),
                  ),
                );
              }

              return Column(
                children: List.generate(grouped.length, (index) {
                  final dayGroup = grouped[index];
                  final bottomSpacing =
                      index == grouped.length - 1 ? 0.0 : 14.0;

                  return Padding(
                    padding: EdgeInsets.only(bottom: bottomSpacing),
                    child: _TimelineDaySection(
                      group: dayGroup,
                      compact: true,
                      showActions: false,
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              if (patientId == null) return;
              await showDialog(
                context: context,
                barrierDismissible: true,
                builder:
                    (ctx) => _TreatmentTimelineDialog(
                      patientId: patientId,
                      onChanged: _handleTreatmentsChanged,
                    ),
              );
              _refreshTimeline();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.08),
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            icon: const Icon(Icons.timeline),
            label: const Text('Open full timeline'),
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
  final Set<String> selectedTeeth;

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
    this.selectedTeeth = const {},
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
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
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
            selectedTeeth: selectedTeeth,
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
            selectedTeeth: selectedTeeth,
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
  final Set<String> selectedTeeth;

  const _ToothRow({
    required this.labels,
    required this.plan,
    required this.toothTreatments,
    required this.palette,
    this.selectedTreatmentType,
    this.onToothTap,
    this.inverted = false,
    this.selectedTeeth = const {},
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
                    isSelected: selectedTeeth.contains(label),
                    onTap: onToothTap != null ? () => onToothTap!(label) : null,
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
    final conditions =
        (availableConditions.isEmpty
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
          onSelected:
              onTreatmentTypeChange == null
                  ? null
                  : (_) => onTreatmentTypeChange!(isSelected ? null : type),
        );
      }),
      if (extraCount > 0)
        ChoiceChip(
          label: Text('+$extraCount'),
          selected: false,
          backgroundColor: Colors.white.withOpacity(0.08),
          labelStyle: const TextStyle(
            fontSize: 10,
            color: AppColors.textPrimary,
          ),
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
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
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
                          children:
                              treatmentTypes.map((type) {
                                final isSelected =
                                    selectedTreatmentType == type;
                                final color = palette.colorFor(type);
                                return ChoiceChip(
                                  label: Text(type),
                                  selected: isSelected,
                                  selectedColor: color,
                                  backgroundColor: color.withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isSelected
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
  final bool isSelected;

  const _ToothTile({
    required this.label,
    required this.condition,
    required this.inverted,
    required this.treatments,
    required this.palette,
    this.selectedTreatmentType,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          if (inverted) _ToothShape(condition: condition, selected: isSelected),
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
          if (!inverted)
            _ToothShape(condition: condition, selected: isSelected),
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
    final isSelected =
        selectedTreatmentType == null ? true : selectedTreatmentType == type;

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
  final bool selected;

  const _ToothShape({required this.condition, this.selected = false});

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
        border: Border.all(
          color:
              selected
                  ? AppColors.accent.withOpacity(0.9)
                  : Colors.white.withOpacity(0.15),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                selected
                    ? AppColors.accent.withOpacity(0.35)
                    : Colors.black.withOpacity(0.25),
            blurRadius: selected ? 18 : 14,
            spreadRadius: selected ? 6 : 4,
          ),
        ],
      ),
    );
  }
}

class _AddTreatmentDialog extends StatefulWidget {
  final String patientId;

  const _AddTreatmentDialog({Key? key, required this.patientId})
    : super(key: key);

  @override
  State<_AddTreatmentDialog> createState() => _AddTreatmentDialogState();
}

class _AddTreatmentDialogState extends State<_AddTreatmentDialog> {
  final DentalChartRepository _repo = DentalChartRepository();
  final TreatmentDataService _treatmentStore = TreatmentDataService();
  final TreatmentPalette _palette = TreatmentPalette();
  static const List<String> _fallbackTypes = [
    'Кариес',
    'Имплантация',
    'Удаление',
    'Сканирование',
    'Эндо',
    'Формирователь',
    'РММА',
    'Коронка',
    'Абатмент',
    'Сдача РММА',
    'Сдача коронка',
    'Сдача абатмент',
    'Удаление импланта',
  ];

  final Set<String> _selectedTeeth = {};
  String? _selectedType;
  bool _saving = false;

  bool _typesLoading = true;
  String? _typesError;
  List<String> _types = [];

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    setState(() {
      _typesLoading = true;
      _typesError = null;
    });
    try {
      final set = await _repo.loadTreatmentTypes(patientId: widget.patientId);
      final withFallback = <String>{...set, ..._fallbackTypes};
      final items = withFallback.toList()..sort();
      setState(() {
        _types = items;
        if (_selectedType == null && items.isNotEmpty) {
          _selectedType = items.first;
        }
      });
    } catch (e) {
      setState(() {
        _typesError = 'Failed to load types: $e';
        _types = _fallbackTypes.toList()..sort();
        if (_selectedType == null && _types.isNotEmpty) {
          _selectedType = _types.first;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _typesLoading = false;
        });
      }
    }
  }

  void _toggleTooth(String tooth) {
    setState(() {
      if (_selectedTeeth.contains(tooth)) {
        _selectedTeeth.remove(tooth);
      } else {
        _selectedTeeth.add(tooth);
      }
    });
  }

  Future<void> _save() async {
    if (_selectedType == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a treatment type first.')),
      );
      return;
    }
    if (_selectedTeeth.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _treatmentStore.insert({
        'id': generateTextId('treatment'),
        'patient_id': widget.patientId,
        'treatment_type': _selectedType,
        'tooth_number': _selectedTeeth.toList()..sort(),
        'status': 'treated',
        'date': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'source': 'add-dialog',
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
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
                        'Add treatment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed:
                            _saving ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTypeSelector(),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 520,
                    child: _DentalChartSection(
                      // Empty chart: do not reflect patient's current statuses
                      plan: const <String, ToothCondition>{},
                      selectedCondition: null,
                      // Passing only treated hides condition chips in legend
                      availableConditions: const [ToothCondition.treated],
                      onConditionChange: (_) {},
                      onToothTap: (t) => _toggleTooth(t),
                      isLoading: false,
                      error: null,
                      treatmentsByTooth: const {},
                      treatmentTypes: _types,
                      selectedTreatmentType: _selectedType,
                      onTreatmentTypeChange:
                          (t) => setState(() {
                            _selectedType = t;
                          }),
                      palette: _palette,
                      selectedTeeth: _selectedTeeth,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedTeeth.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final list = _selectedTeeth.toList()..sort();
                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              list
                                  .map(
                                    (t) => Chip(
                                      label: Text('Tooth $t'),
                                      deleteIcon: const Icon(
                                        Icons.close,
                                        size: 16,
                                      ),
                                      onDeleted:
                                          _saving
                                              ? null
                                              : () => _toggleTooth(t),
                                    ),
                                  )
                                  .toList(),
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedType == null
                              ? 'Select a treatment type'
                              : 'Type: ${_selectedType!}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted.withOpacity(0.9),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed:
                            _saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed:
                            _saving ||
                                    _selectedType == null ||
                                    _selectedTeeth.isEmpty
                                ? null
                                : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.bg,
                        ),
                        icon:
                            _saving
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      AppColors.bg,
                                    ),
                                  ),
                                )
                                : const Icon(Icons.check),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    if (_typesLoading) {
      return LinearProgressIndicator(
        minHeight: 4,
        valueColor: const AlwaysStoppedAnimation(AppColors.accent),
        backgroundColor: Colors.white.withOpacity(0.08),
      );
    }
    final warning = _typesError;
    if (_types.isEmpty) {
      return Text(
        'No treatment types found. Add new via database.',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textMuted.withOpacity(0.9),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (warning != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '$warning\nUsing fallback types.',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _types.map((type) {
                final isSelected = _selectedType == type;
                final color = _palette.colorFor(type);
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: color,
                  backgroundColor: color.withOpacity(0.25),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.bg : AppColors.textPrimary,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedType = isSelected ? null : type;
                    });
                  },
                );
              }).toList(),
        ),
      ],
    );
  }
}

class _TreatmentTimelineDialog extends StatefulWidget {
  final String patientId;
  final VoidCallback? onChanged;

  const _TreatmentTimelineDialog({
    Key? key,
    required this.patientId,
    this.onChanged,
  }) : super(key: key);

  @override
  State<_TreatmentTimelineDialog> createState() =>
      _TreatmentTimelineDialogState();
}

class _TreatmentTimelineDialogState extends State<_TreatmentTimelineDialog> {
  final TreatmentDataService _treatmentStore = TreatmentDataService();
  late Stream<List<Map<String, dynamic>>> _query;

  @override
  void initState() {
    super.initState();
    _query = _buildQuery();
  }

  Stream<List<Map<String, dynamic>>> _buildQuery() {
    return _treatmentStore.watchByPatient(widget.patientId, maxRows: 200);
  }

  void _refreshTimeline() {
    if (!mounted) return;
    setState(() {
      _query = _buildQuery();
    });
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
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
                children: [
                  Row(
                    children: [
                      const Text(
                        'Treatment timeline',
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
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _query,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const LinearProgressIndicator(
                            minHeight: 4,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.accent,
                            ),
                            backgroundColor: Colors.transparent,
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Failed to load treatments: ${snapshot.error}',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }

                        final docs = (snapshot.data ?? <Map<String, dynamic>>[])
                            .toList(growable: false);
                        final grouped = buildTreatedTimelineGroups(docs);

                        if (grouped.isEmpty) {
                          return Center(
                            child: Text(
                              'No completed treatments yet for this patient.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted.withOpacity(0.9),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final group = grouped[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == grouped.length - 1 ? 0 : 18,
                              ),
                              child: _TimelineDaySection(
                                group: group,
                                compact: false,
                                showActions: true,
                                onDelete: (entry) {
                                  final treatmentId = entry.id;
                                  if (treatmentId == null) return;
                                  _confirmAndDelete(context, treatmentId);
                                },
                                onEdit: (entry) async {
                                  final treatmentId = entry.id;
                                  if (treatmentId == null) return;
                                  final updated = await showDialog<bool>(
                                    context: context,
                                    barrierDismissible: true,
                                    builder:
                                        (_) => _EditTreatmentDialog(
                                          treatmentId: treatmentId,
                                          initialData: entry.source,
                                        ),
                                  );
                                  if (updated == true) {
                                    _refreshTimeline();
                                  }
                                },
                              ),
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

  Future<void> _confirmAndDelete(
    BuildContext context,
    dynamic treatmentId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Text(
            'Delete treatment?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'This action cannot be undone.',
            style: TextStyle(
              color: AppColors.textMuted.withOpacity(0.95),
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      await _treatmentStore.deleteById(treatmentId);
      _refreshTimeline();
      if (!context.mounted) return;
      // Feedback
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted treatment')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }
}

class _EditTreatmentDialog extends StatefulWidget {
  final dynamic treatmentId;
  final Map<String, dynamic> initialData;

  const _EditTreatmentDialog({
    Key? key,
    required this.treatmentId,
    required this.initialData,
  }) : super(key: key);

  @override
  State<_EditTreatmentDialog> createState() => _EditTreatmentDialogState();
}

class _EditTreatmentDialogState extends State<_EditTreatmentDialog> {
  final TreatmentPalette _palette = TreatmentPalette();
  final DentalChartRepository _repo = DentalChartRepository();
  final TreatmentDataService _treatmentStore = TreatmentDataService();

  static const List<String> _fallbackTypes = [
    'Кариес',
    'Имплантация',
    'Удаление',
    'Сканирование',
    'Эндо',
    'Формирователь',
    'РММА',
    'Коронка',
    'Абатмент',
    'Сдача РММА',
    'Сдача коронка',
    'Сдача абатмент',
    'Удаление импланта',
  ];
  static const List<String> _statuses = ['planned', 'inProgress', 'treated'];

  bool _loading = false;
  bool _typesLoading = true;
  String? _typesError;
  List<String> _types = [];

  final Set<String> _selectedTeeth = {};
  String? _selectedType;
  String _selectedStatus = 'treated';
  DateTime _selectedDateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeFromData();
    _loadTypes();
  }

  void _initializeFromData() {
    final data = widget.initialData;
    _selectedType =
        (data['treatmentType'] ?? data['type'] ?? data['treatment_type'])
            ?.toString();
    final parsedDate = parseTimelineDate(data['date']);
    if (parsedDate != null) {
      _selectedDateTime = parsedDate.toLocal();
    }
    final teeth = _parseTeeth(data['toothNumber'] ?? data['tooth_number']);
    _selectedTeeth.addAll(teeth);
    final status = data['status']?.toString();
    if (status != null && status.isNotEmpty) {
      _selectedStatus = status;
    }
  }

  Future<void> _loadTypes() async {
    setState(() {
      _typesLoading = true;
      _typesError = null;
    });
    try {
      // Try global and patient-scoped types
      final set = await _repo.loadTreatmentTypes();
      final items = {...set, ..._fallbackTypes}.toList()..sort();
      setState(() {
        _types = items;
        if (_selectedType == null && items.isNotEmpty) {
          _selectedType = items.first;
        }
      });
    } catch (e) {
      setState(() {
        _typesError = 'Failed to load types: $e';
        _types = _fallbackTypes.toList()..sort();
        if (_selectedType == null && _types.isNotEmpty) {
          _selectedType = _types.first;
        }
      });
    } finally {
      if (mounted) setState(() => _typesLoading = false);
    }
  }

  static List<String> _parseTeeth(dynamic raw) {
    if (raw is Iterable) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw == null) return const [];
    final s = raw.toString();
    return s.isEmpty ? const [] : [s];
  }

  void _toggleTooth(String tooth) {
    setState(() {
      if (_selectedTeeth.contains(tooth)) {
        _selectedTeeth.remove(tooth);
      } else {
        _selectedTeeth.add(tooth);
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(now.year - 15),
      lastDate: DateTime(now.year + 15),
      helpText: 'Select treatment date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      helpText: 'Select treatment time',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_selectedType == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a treatment type first.')),
      );
      return;
    }
    if (_selectedTeeth.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _treatmentStore.updateById(widget.treatmentId, {
        'treatment_type': _selectedType,
        'tooth_number': _selectedTeeth.toList()..sort(),
        'status': _selectedStatus,
        'date': _selectedDateTime.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
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
                        'Edit treatment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed:
                            _loading ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTypeSelector(),
                  const SizedBox(height: 12),
                  _buildStatusSelector(),
                  const SizedBox(height: 12),
                  _buildDateTimeSelector(),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 520,
                    child: _DentalChartSection(
                      plan: const <String, ToothCondition>{},
                      selectedCondition: null,
                      availableConditions: const [ToothCondition.treated],
                      onConditionChange: (_) {},
                      onToothTap: _toggleTooth,
                      isLoading: false,
                      error: null,
                      treatmentsByTooth: const {},
                      treatmentTypes: _types,
                      selectedTreatmentType: _selectedType,
                      onTreatmentTypeChange:
                          (t) => setState(() => _selectedType = t),
                      palette: _palette,
                      selectedTeeth: _selectedTeeth,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedTeeth.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final list = _selectedTeeth.toList()..sort();
                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              list
                                  .map(
                                    (t) => Chip(
                                      label: Text('Tooth $t'),
                                      deleteIcon: const Icon(
                                        Icons.close,
                                        size: 16,
                                      ),
                                      onDeleted:
                                          _loading
                                              ? null
                                              : () => _toggleTooth(t),
                                    ),
                                  )
                                  .toList(),
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedType == null
                              ? 'Select a treatment type'
                              : 'Type: ${_selectedType!}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted.withOpacity(0.9),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed:
                            _loading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed:
                            _loading ||
                                    _selectedType == null ||
                                    _selectedTeeth.isEmpty
                                ? null
                                : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.bg,
                        ),
                        icon:
                            _loading
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      AppColors.bg,
                                    ),
                                  ),
                                )
                                : const Icon(Icons.check),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    if (_typesLoading) {
      return LinearProgressIndicator(
        minHeight: 4,
        valueColor: const AlwaysStoppedAnimation(AppColors.accent),
        backgroundColor: Colors.white.withOpacity(0.08),
      );
    }
    final warning = _typesError;
    if (_types.isEmpty) {
      return Text(
        'No treatment types found. Add new via database.',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textMuted.withOpacity(0.9),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (warning != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '$warning\nUsing fallback types.',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _types.map((type) {
                final isSelected = _selectedType == type;
                final color = _palette.colorFor(type);
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: color,
                  backgroundColor: color.withOpacity(0.25),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.bg : AppColors.textPrimary,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedType = isSelected ? null : type;
                    });
                  },
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatusSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          _statuses.map((s) {
            final isSel = _selectedStatus == s;
            return ChoiceChip(
              label: Text(s),
              selected: isSel,
              selectedColor: AppColors.accent,
              backgroundColor: Colors.white.withOpacity(0.08),
              labelStyle: TextStyle(
                color: isSel ? AppColors.bg : AppColors.textPrimary,
              ),
              onSelected: (_) => setState(() => _selectedStatus = s),
            );
          }).toList(),
    );
  }

  Widget _buildDateTimeSelector() {
    final dateLabel = formatTimelineDateTimeLabel(_selectedDateTime);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Date: $dateLabel',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted.withOpacity(0.95),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _loading ? null : _pickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: const Text('Date'),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _loading ? null : _pickTime,
            icon: const Icon(Icons.access_time_rounded, size: 16),
            label: const Text('Time'),
          ),
        ],
      ),
    );
  }
}

class _TimelineDaySection extends StatelessWidget {
  final TimelineDayGroupVm group;
  final bool compact;
  final bool showActions;
  final ValueChanged<TimelineEntryVm>? onDelete;
  final ValueChanged<TimelineEntryVm>? onEdit;

  const _TimelineDaySection({
    required this.group,
    required this.compact,
    required this.showActions,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final dayLabel = formatTimelineDayLabel(group.day);
    final itemCount = group.totalEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.9),
                    AppColors.accentStrong.withOpacity(0.95),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentStrong.withOpacity(0.28),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.bg,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$itemCount',
                      style: TextStyle(
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.bg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withOpacity(0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.only(left: 10),
          padding: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AppColors.accent.withOpacity(0.16),
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: List.generate(group.entries.length, (index) {
              final entry = group.entries[index];
              final bottomSpacing =
                  index == group.entries.length - 1 ? 0.0 : 9.0;
              return Padding(
                padding: EdgeInsets.only(bottom: bottomSpacing),
                child: _TimelineEntryCard(
                  entry: entry,
                  compact: compact,
                  showActions: showActions,
                  onDelete: onDelete == null ? null : () => onDelete!(entry),
                  onEdit: onEdit == null ? null : () => onEdit!(entry),
                ),
              );
            }),
          ),
        ),
        if (compact && group.hiddenEntries > 0) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              '+${group.hiddenEntries} more completed treatments',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimelineEntryCard extends StatelessWidget {
  final TimelineEntryVm entry;
  final bool compact;
  final bool showActions;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _TimelineEntryCard({
    required this.entry,
    required this.compact,
    required this.showActions,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final teethText = entry.teeth.isEmpty ? '—' : entry.teeth.join(', ');
    final entriesSuffix =
        entry.entriesCount > 1 ? ' • Entries: ${entry.entriesCount}' : '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -21,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: entry.badge.dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: entry.badge.dotColor.withOpacity(0.45),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 16,
            vertical: compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(12),
          ),
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
                          entry.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: compact ? 14 : 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Teeth: $teethText$entriesSuffix',
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            color: AppColors.textMuted.withOpacity(0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (entry.timeLabel != null)
                        Text(
                          entry.timeLabel!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted.withOpacity(0.8),
                          ),
                        ),
                      if (showActions &&
                          entry.entriesCount == 1 &&
                          (onEdit != null || onDelete != null))
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onEdit != null)
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: onEdit,
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: AppColors.accent,
                                visualDensity: VisualDensity.compact,
                              ),
                            if (onDelete != null)
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: onDelete,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                color: Colors.redAccent.withOpacity(0.9),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
