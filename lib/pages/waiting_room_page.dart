import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../models/waiting_room.dart';
import '../services/patient_lookup_service.dart';
import '../services/waiting_room_reason_service.dart';
import '../services/waiting_room_service.dart';
import '../services/waiting_room_storage_error.dart';
import '../theme/app_colors.dart';
import '../utils/decorations.dart';
import '../widgets/primary_page_scaffold.dart';
import 'waiting_room_reason_settings_page.dart';

const bool _kWaitingRoomIsFlutterTest = bool.fromEnvironment('FLUTTER_TEST');

class WaitingRoomPage extends StatefulWidget {
  static const routeName = '/waiting-room';

  final WaitingRoomService? waitingRoomService;
  final WaitingRoomReasonService? reasonService;
  final PatientLookupService? patientLookupService;

  const WaitingRoomPage({
    super.key,
    this.waitingRoomService,
    this.reasonService,
    this.patientLookupService,
  });

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  late final WaitingRoomService _waitingRoomService;
  late final WaitingRoomReasonService _reasonService;
  late final PatientLookupService _patientLookupService;

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _reasonService = widget.reasonService ?? const WaitingRoomReasonService();
    _patientLookupService =
        widget.patientLookupService ?? const PatientLookupService();
    _waitingRoomService =
        widget.waitingRoomService ??
        WaitingRoomService(
          reasonService: _reasonService,
          patientLookupService: _patientLookupService,
        );

    if (!_kWaitingRoomIsFlutterTest) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _openReasonSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => WaitingRoomReasonSettingsPage(reasonService: _reasonService),
      ),
    );
  }

  Future<void> _handleCreateEntry(List<WaitingRoomReason> reasons) async {
    if (reasons.isEmpty) return;

    final draft = await showDialog<CreateWaitingRoomEntryDraft>(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => _AddWaitingRoomEntryDialog(
            reasons: reasons,
            patientLookupService: _patientLookupService,
          ),
    );
    if (draft == null) return;

    try {
      await _waitingRoomService.createEntry(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient added to waiting room.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add waiting room entry: $error')),
      );
    }
  }

  Future<void> _handleEditEntry(
    WaitingRoomEntry entry,
    List<WaitingRoomReason> reasons,
  ) async {
    if (reasons.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add an active reason before editing waiting room entries.',
          ),
        ),
      );
      return;
    }

    final draft = await showDialog<UpdateWaitingRoomEntryDraft>(
      context: context,
      barrierDismissible: true,
      builder:
          (context) =>
              _EditWaitingRoomEntryDialog(entry: entry, reasons: reasons),
    );
    if (draft == null) return;

    try {
      await _waitingRoomService.updateEntry(entry.id, draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting room entry updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update waiting room entry: $error')),
      );
    }
  }

  Future<void> _handleDeleteEntry(WaitingRoomEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Remove patient',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              'Remove ${entry.displayName} from the active waiting room list?',
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
                child: const Text('Remove'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await _waitingRoomService.deleteEntry(entry.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient removed.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove patient: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryPageScaffold(
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<List<WaitingRoomReason>>(
        stream: _reasonService.watchActiveReasons(),
        builder: (context, reasonSnapshot) {
          final reasonError = reasonSnapshot.error;
          final reasons = reasonSnapshot.data ?? const <WaitingRoomReason>[];
          final reasonsById = <String, WaitingRoomReason>{
            for (final reason in reasons) reason.id: reason,
          };

          return StreamBuilder<List<WaitingRoomEntry>>(
            stream: _waitingRoomService.watchTodayEntries(),
            builder: (context, entrySnapshot) {
              final entryError = entrySnapshot.error;
              final storageError = reasonError ?? entryError;
              final entries = entrySnapshot.data ?? const <WaitingRoomEntry>[];
              final now = DateTime.now();
              final averageWaitToday = averageWaitingRoomDuration(entries, now);
              final maxWaitEntry = maxWaitingRoomEntry(entries, now);
              final maxWaitNow = maxWaitingRoomDuration(entries, now);
              final scheduled = entries
                  .where((entry) => entry.lane == WaitingRoomLane.scheduled)
                  .toList(growable: false);
              final unscheduled = entries
                  .where((entry) => entry.lane == WaitingRoomLane.unscheduled)
                  .toList(growable: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWaitingRoomHeader(),
                  const SizedBox(height: 18),
                  _WaitingRoomOverviewStats(
                    activeCount: entries.length,
                    averageWaitToday: averageWaitToday,
                    maxWaitPatientName:
                        maxWaitEntry == null
                            ? null
                            : _waitingRoomLeadSurname(maxWaitEntry.displayName),
                    maxWaitNow: maxWaitNow,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _openReasonSettings,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: const Text('Manage reasons'),
                      ),
                      ElevatedButton.icon(
                        onPressed:
                            storageError != null || reasons.isEmpty
                                ? null
                                : () => _handleCreateEntry(reasons),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentStrong,
                          foregroundColor: AppColors.bg,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add patient'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (storageError != null)
                    _buildStorageErrorCard(storageError)
                  else if (reasons.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: buildSurfaceCardDecoration(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'No active visit reasons',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Add at least one active visit reason before reception can create waiting room entries.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: AppColors.textMuted.withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _openReasonSettings,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.accent,
                                  ),
                                  icon: const Icon(
                                    Icons.settings_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Manage reasons'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _WaitingRoomColumn(
                          title: 'By appointment',
                          subtitle: 'Patients reception marked as expected.',
                          entries: scheduled,
                          reasonsById: reasonsById,
                          now: now,
                          accentColor: AppColors.accentStrong,
                          onEdit: (entry) => _handleEditEntry(entry, reasons),
                          onDelete: _handleDeleteEntry,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _WaitingRoomColumn(
                          title: 'Walk-In',
                          subtitle:
                              'Patients who arrived outside the schedule.',
                          entries: unscheduled,
                          reasonsById: reasonsById,
                          now: now,
                          accentColor: const Color(0xFF78A0FF),
                          onEdit: (entry) => _handleEditEntry(entry, reasons),
                          onDelete: _handleDeleteEntry,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWaitingRoomHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Live Patient Arrival Board',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: Colors.white.withOpacity(0.06),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 1.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accentStrong.withOpacity(0.9),
                Colors.white.withOpacity(0.34),
                Colors.white.withOpacity(0.12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStorageErrorCard(Object error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: buildSurfaceCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.storage_rounded, color: Colors.amberAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waiting room storage is unavailable',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  describeWaitingRoomStorageError(error),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textMuted.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _openReasonSettings,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Manage reasons'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingRoomOverviewStats extends StatelessWidget {
  final int activeCount;
  final Duration averageWaitToday;
  final Duration maxWaitNow;
  final String? maxWaitPatientName;

  const _WaitingRoomOverviewStats({
    required this.activeCount,
    required this.averageWaitToday,
    required this.maxWaitNow,
    required this.maxWaitPatientName,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _WaitingRoomStatCard(
        icon: Icons.groups_rounded,
        title: 'Waiting now',
        value: '$activeCount',
        caption: 'Active patients currently in today\'s waiting room.',
        accentColor: AppColors.accentStrong,
      ),
      _WaitingRoomStatCard(
        icon: Icons.hourglass_top_rounded,
        title: 'Average wait today',
        value: formatWaitingRoomStatDuration(averageWaitToday),
        caption: 'Average live waiting time across all active patients.',
        accentColor: const Color(0xFF78A0FF),
      ),
      _WaitingRoomStatCard(
        icon: Icons.timer_outlined,
        title: 'Max wait now',
        value: formatWaitingRoomStatDuration(maxWaitNow),
        emphasisLabel: maxWaitPatientName,
        caption: 'Longest current wait',
        accentColor: const Color(0xFFF59E0B),
      ),
    ];

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 14),
        Expanded(child: cards[1]),
        const SizedBox(width: 14),
        Expanded(child: cards[2]),
      ],
    );
  }
}

class _WaitingRoomStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? emphasisLabel;
  final String caption;
  final Color accentColor;

  const _WaitingRoomStatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.emphasisLabel,
    required this.caption,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedEmphasis = (emphasisLabel ?? '').trim();
    final normalizedCaption = caption.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: buildSurfaceCardDecoration(glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted.withOpacity(0.92),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                height: 62,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 0.95,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 20,
            child: Center(
              child:
                  normalizedEmphasis.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                        normalizedEmphasis,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 36,
            child: Center(
              child:
                  normalizedCaption.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                        normalizedCaption,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.textMuted.withOpacity(0.88),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

String _waitingRoomLeadSurname(String displayName) {
  final normalized = displayName.trim();
  if (normalized.isEmpty) {
    return 'No patient';
  }
  return normalized.split(RegExp(r'\s+')).first;
}

class _WaitingRoomColumn extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<WaitingRoomEntry> entries;
  final Map<String, WaitingRoomReason> reasonsById;
  final DateTime now;
  final Color accentColor;
  final ValueChanged<WaitingRoomEntry> onEdit;
  final ValueChanged<WaitingRoomEntry> onDelete;

  const _WaitingRoomColumn({
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.reasonsById,
    required this.now,
    required this.accentColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: buildSurfaceCardDecoration(glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted.withOpacity(0.88),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  '${entries.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      color: AppColors.textMuted.withOpacity(0.8),
                      size: 24,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No patients in this list right now.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                ...List.generate(entries.length, (index) {
                  final entry = entries[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == entries.length - 1 ? 0 : 6,
                    ),
                    child: _WaitingRoomEntryCard(
                      entry: entry,
                      reasonsById: reasonsById,
                      now: now,
                      accentColor: accentColor,
                      onEdit: () => onEdit(entry),
                      onDelete: () => onDelete(entry),
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}

enum _WaitingRoomEntryAction { edit, remove }

class _WaitingRoomEntryCard extends StatelessWidget {
  final WaitingRoomEntry entry;
  final Map<String, WaitingRoomReason> reasonsById;
  final DateTime now;
  final Color accentColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WaitingRoomEntryCard({
    required this.entry,
    required this.reasonsById,
    required this.now,
    required this.accentColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final waitingDuration = now.difference(entry.createdAt.toLocal());
    final addedTime = TimeOfDay.fromDateTime(
      entry.createdAt.toLocal(),
    ).format(context);
    final reasonLabel = entry.resolveReasonLabel(reasonsById);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  addedTime,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  entry.sourceType == WaitingRoomEntrySourceType.patient
                      ? 'Appt'
                      : 'Walk',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.textMuted.withOpacity(0.84),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _waitingRoomSecondaryLine(
                    reasonLabel: reasonLabel,
                    sourceLabel: entry.sourceType.title,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            child: Text(
              formatWaitingRoomDuration(waitingDuration),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(width: 2),
          PopupMenuButton<_WaitingRoomEntryAction>(
            tooltip: 'Entry actions',
            onSelected: (action) {
              switch (action) {
                case _WaitingRoomEntryAction.edit:
                  onEdit();
                  break;
                case _WaitingRoomEntryAction.remove:
                  onDelete();
                  break;
              }
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem<_WaitingRoomEntryAction>(
                    value: _WaitingRoomEntryAction.edit,
                    child: Text('Edit'),
                  ),
                  PopupMenuItem<_WaitingRoomEntryAction>(
                    value: _WaitingRoomEntryAction.remove,
                    child: Text('Remove'),
                  ),
                ],
            color: AppColors.surfaceDark,
            icon: Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
        ],
      ),
    );
  }
}

String _waitingRoomSecondaryLine({
  required String reasonLabel,
  required String sourceLabel,
}) {
  final parts = <String>[
    if (reasonLabel.trim().isNotEmpty) reasonLabel.trim(),
    if (sourceLabel.trim().isNotEmpty) sourceLabel.trim(),
  ];
  if (parts.isEmpty) {
    return 'Waiting room entry';
  }
  return parts.join(' • ');
}

enum _AddEntryMode { patient, manual }

class _AddWaitingRoomEntryDialog extends StatefulWidget {
  final List<WaitingRoomReason> reasons;
  final PatientLookupService patientLookupService;

  const _AddWaitingRoomEntryDialog({
    required this.reasons,
    required this.patientLookupService,
  });

  @override
  State<_AddWaitingRoomEntryDialog> createState() =>
      _AddWaitingRoomEntryDialogState();
}

class _AddWaitingRoomEntryDialogState
    extends State<_AddWaitingRoomEntryDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualSurnameController =
      TextEditingController();

  _AddEntryMode _mode = _AddEntryMode.patient;
  WaitingRoomLane _lane = WaitingRoomLane.scheduled;
  String? _reasonId;
  bool _isSearching = false;
  int _searchRevision = 0;
  List<PatientLookupResult> _results = const [];
  PatientLookupResult? _selectedPatient;

  @override
  void initState() {
    super.initState();
    _reasonId = widget.reasons.isEmpty ? null : widget.reasons.first.id;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _manualSurnameController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (_mode != _AddEntryMode.patient) return;
    final cleanQuery = query.trim();
    final revision = ++_searchRevision;

    if (cleanQuery.isEmpty) {
      setState(() {
        _results = const [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = await widget.patientLookupService.search(cleanQuery);
    if (!mounted || revision != _searchRevision) return;

    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  void _save() {
    final reasonId = _reasonId;
    if (reasonId == null || reasonId.trim().isEmpty) return;

    if (_mode == _AddEntryMode.patient) {
      final patient = _selectedPatient;
      if (patient == null) return;
      Navigator.of(context).pop(
        CreateWaitingRoomEntryDraft(
          lane: _lane,
          reasonId: reasonId,
          patientId: patient.id,
        ),
      );
      return;
    }

    final surname = _manualSurnameController.text.trim();
    if (surname.isEmpty) return;
    Navigator.of(context).pop(
      CreateWaitingRoomEntryDraft(
        lane: _lane,
        reasonId: reasonId,
        manualSurname: surname,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        _reasonId != null &&
        ((_mode == _AddEntryMode.patient && _selectedPatient != null) ||
            (_mode == _AddEntryMode.manual &&
                _manualSurnameController.text.trim().isNotEmpty));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withOpacity(0.35),
                AppColors.accentStrong.withOpacity(0.45),
              ],
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
                        'Add waiting room patient',
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Existing patient'),
                        selected: _mode == _AddEntryMode.patient,
                        selectedColor: AppColors.accent,
                        labelStyle: TextStyle(
                          color:
                              _mode == _AddEntryMode.patient
                                  ? AppColors.bg
                                  : AppColors.textPrimary,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _mode = _AddEntryMode.patient;
                          });
                          _performSearch(_searchController.text);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Manual surname'),
                        selected: _mode == _AddEntryMode.manual,
                        selectedColor: AppColors.accent,
                        labelStyle: TextStyle(
                          color:
                              _mode == _AddEntryMode.manual
                                  ? AppColors.bg
                                  : AppColors.textPrimary,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _mode = _AddEntryMode.manual;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _reasonId,
                    decoration: buildFormInputDecoration('Visit reason'),
                    dropdownColor: AppColors.surfaceDark,
                    items:
                        widget.reasons
                            .map(
                              (reason) => DropdownMenuItem<String>(
                                value: reason.id,
                                child: Text(
                                  reason.label,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      setState(() {
                        _reasonId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        WaitingRoomLane.values.map((lane) {
                          final isSelected = lane == _lane;
                          return ChoiceChip(
                            label: Text(lane.title),
                            selected: isSelected,
                            selectedColor: AppColors.accentStrong,
                            labelStyle: TextStyle(
                              color:
                                  isSelected
                                      ? AppColors.bg
                                      : AppColors.textPrimary,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _lane = lane;
                              });
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (_mode == _AddEntryMode.patient) ...[
                    TextField(
                      controller: _searchController,
                      onChanged: _performSearch,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: buildFormInputDecoration(
                        'Search patient',
                        hint: 'Surname or phone',
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_selectedPatient != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.accent.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedPatient!.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (_selectedPatient!
                                      .subtitle
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedPatient!.subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted.withOpacity(
                                          0.9,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedPatient = null;
                                });
                              },
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      ),
                    if (_selectedPatient != null) const SizedBox(height: 14),
                    if (_isSearching)
                      LinearProgressIndicator(
                        minHeight: 4,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.accent,
                        ),
                        backgroundColor: Colors.white.withOpacity(0.08),
                      )
                    else if (_results.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _results.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final result = _results[index];
                            return InkWell(
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  _selectedPatient = result;
                                  _results = const <PatientLookupResult>[];
                                  _isSearching = false;
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        _selectedPatient?.id == result.id
                                            ? AppColors.accent.withOpacity(0.4)
                                            : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            result.title,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (result.subtitle.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              result.subtitle,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textMuted
                                                    .withOpacity(0.9),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      result.matchType ==
                                              PatientLookupMatchType.phone
                                          ? 'Phone match'
                                          : 'Patient record',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted.withOpacity(
                                          0.85,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Text(
                        _searchController.text.trim().isEmpty
                            ? 'Start typing to search the patient database.'
                            : 'No patients found for this search.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted.withOpacity(0.88),
                        ),
                      ),
                  ] else ...[
                    TextField(
                      controller: _manualSurnameController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: buildFormInputDecoration(
                        'Surname',
                        hint: 'For example Ivanov',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Manual entries are kept as temporary waiting room visitors without a linked patient card.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted.withOpacity(0.88),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: canSave ? _save : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentStrong,
                          foregroundColor: AppColors.bg,
                        ),
                        child: const Text('Add'),
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
}

class _EditWaitingRoomEntryDialog extends StatefulWidget {
  final WaitingRoomEntry entry;
  final List<WaitingRoomReason> reasons;

  const _EditWaitingRoomEntryDialog({
    required this.entry,
    required this.reasons,
  });

  @override
  State<_EditWaitingRoomEntryDialog> createState() =>
      _EditWaitingRoomEntryDialogState();
}

class _EditWaitingRoomEntryDialogState
    extends State<_EditWaitingRoomEntryDialog> {
  late WaitingRoomLane _lane;
  late String _reasonId;

  @override
  void initState() {
    super.initState();
    _lane = widget.entry.lane;
    _reasonId =
        widget.reasons.any((reason) => reason.id == widget.entry.reasonId)
            ? widget.entry.reasonId!
            : widget.reasons.first.id;
  }

  void _save() {
    Navigator.of(
      context,
    ).pop(UpdateWaitingRoomEntryDraft(lane: _lane, reasonId: _reasonId));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withOpacity(0.35),
                AppColors.accentStrong.withOpacity(0.45),
              ],
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
                        'Edit waiting room entry',
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
                  const SizedBox(height: 10),
                  Text(
                    widget.entry.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _reasonId,
                    decoration: buildFormInputDecoration('Visit reason'),
                    dropdownColor: AppColors.surfaceDark,
                    items:
                        widget.reasons
                            .map(
                              (reason) => DropdownMenuItem<String>(
                                value: reason.id,
                                child: Text(
                                  reason.label,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _reasonId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        WaitingRoomLane.values.map((lane) {
                          final isSelected = lane == _lane;
                          return ChoiceChip(
                            label: Text(lane.title),
                            selected: isSelected,
                            selectedColor: AppColors.accentStrong,
                            labelStyle: TextStyle(
                              color:
                                  isSelected
                                      ? AppColors.bg
                                      : AppColors.textPrimary,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _lane = lane;
                              });
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentStrong,
                          foregroundColor: AppColors.bg,
                        ),
                        child: const Text('Save'),
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
}
