import 'package:flutter/material.dart';

import '../models/waiting_room.dart';
import '../services/waiting_room_reason_service.dart';
import '../services/waiting_room_storage_error.dart';
import '../theme/app_colors.dart';
import '../utils/decorations.dart';
import '../widgets/page_header.dart';
import '../widgets/primary_page_scaffold.dart';

class WaitingRoomReasonSettingsPage extends StatefulWidget {
  static const routeName = '/waiting-room/reasons';

  final WaitingRoomReasonService? reasonService;

  const WaitingRoomReasonSettingsPage({super.key, this.reasonService});

  @override
  State<WaitingRoomReasonSettingsPage> createState() =>
      _WaitingRoomReasonSettingsPageState();
}

class _WaitingRoomReasonSettingsPageState
    extends State<WaitingRoomReasonSettingsPage> {
  late final WaitingRoomReasonService _reasonService;

  @override
  void initState() {
    super.initState();
    _reasonService = widget.reasonService ?? const WaitingRoomReasonService();
  }

  Future<void> _handleAddReason() async {
    final label = await _showReasonLabelDialog(
      context,
      title: 'Add visit reason',
      actionLabel: 'Add',
    );
    if (label == null) return;

    try {
      await _reasonService.addReason(label);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reason added.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add reason: $error')));
    }
  }

  Future<void> _handleRenameReason(WaitingRoomReason reason) async {
    final label = await _showReasonLabelDialog(
      context,
      title: 'Rename visit reason',
      actionLabel: 'Save',
      initialValue: reason.label,
    );
    if (label == null) return;

    try {
      await _reasonService.renameReason(reason.id, label);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reason updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not rename reason: $error')),
      );
    }
  }

  Future<void> _handleDeactivateReason(WaitingRoomReason reason) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Deactivate reason',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              'Reason "${reason.label}" will disappear from active waiting room forms.',
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
                child: const Text('Deactivate'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await _reasonService.deactivateReason(reason.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reason deactivated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not deactivate reason: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryPageScaffold(
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<List<WaitingRoomReason>>(
        stream: _reasonService.watchAllReasons(),
        builder: (context, snapshot) {
          final loadError = snapshot.error;
          final hasLoadError = loadError != null;
          final reasons = snapshot.data ?? const <WaitingRoomReason>[];
          final activeReasons = reasons
              .where((reason) => reason.isActive)
              .toList(growable: false);
          final inactiveReasons = reasons
              .where((reason) => !reason.isActive)
              .toList(growable: false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Visit reasons',
                subtitle:
                    'Maintain the selectable reasons that reception uses when adding patients to the waiting room.',
                actionLabel: 'Back',
                onAction: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hasLoadError
                          ? describeWaitingRoomStorageError(loadError)
                          : activeReasons.isEmpty
                          ? 'No active reasons yet.'
                          : '${activeReasons.length} active reasons available to reception.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted.withOpacity(0.9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: hasLoadError ? null : _handleAddReason,
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
                      side: BorderSide(color: Colors.white.withOpacity(0.18)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add reason'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (hasLoadError)
                _buildStorageErrorCard(loadError)
              else if (activeReasons.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: buildSurfaceCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No active reasons',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add at least one reason before reception can create waiting room entries.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textMuted.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _buildReasonSection(
                  title: 'Active reasons',
                  reasons: activeReasons,
                  allowDeactivate: true,
                ),
              if (inactiveReasons.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildReasonSection(
                  title: 'Inactive reasons',
                  reasons: inactiveReasons,
                  allowDeactivate: false,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildReasonSection({
    required String title,
    required List<WaitingRoomReason> reasons,
    required bool allowDeactivate,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: buildSurfaceCardDecoration(glow: allowDeactivate),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reasons.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final reason = reasons[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reason.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            allowDeactivate
                                ? 'Visible in active waiting room forms.'
                                : 'Hidden from active waiting room forms.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted.withOpacity(0.88),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Rename',
                      onPressed: () => _handleRenameReason(reason),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: AppColors.textPrimary,
                    ),
                    if (allowDeactivate)
                      IconButton(
                        tooltip: 'Deactivate',
                        onPressed: () => _handleDeactivateReason(reason),
                        icon: const Icon(Icons.block_rounded, size: 18),
                        color: Colors.redAccent.withOpacity(0.9),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStorageErrorCard(Object? error) {
    final message = describeWaitingRoomStorageError(
      error ?? StateError('Waiting room storage is unavailable.'),
    );

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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textMuted.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _showReasonLabelDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String initialValue = '',
}) {
  return showDialog<String>(
    context: context,
    builder:
        (context) => _ReasonLabelDialog(
          title: title,
          actionLabel: actionLabel,
          initialValue: initialValue,
        ),
  );
}

class _ReasonLabelDialog extends StatefulWidget {
  final String title;
  final String actionLabel;
  final String initialValue;

  const _ReasonLabelDialog({
    required this.title,
    required this.actionLabel,
    required this.initialValue,
  });

  @override
  State<_ReasonLabelDialog> createState() => _ReasonLabelDialogState();
}

class _ReasonLabelDialogState extends State<_ReasonLabelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        widget.title,
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: buildFormInputDecoration(
          'Reason label',
          hint: 'For example consultation',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final normalized = normalizeWaitingRoomReasonLabel(
              _controller.text,
            );
            if (normalized == null) return;
            Navigator.of(context).pop(normalized);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentStrong,
            foregroundColor: AppColors.bg,
          ),
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
