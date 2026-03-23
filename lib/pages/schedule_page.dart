import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../services/appointment_service.dart';
import '../services/patient_lookup_service.dart';
import '../theme/app_colors.dart';
import '../utils/decorations.dart';
import '../widgets/page_header.dart';
import '../widgets/primary_page_scaffold.dart';

class SchedulePage extends StatefulWidget {
  static const routeName = '/schedule';

  final AppointmentService? appointmentService;
  final PatientLookupService? patientLookupService;

  const SchedulePage({
    super.key,
    this.appointmentService,
    this.patientLookupService,
  });

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late final AppointmentService _appointmentService;
  late final PatientLookupService _patientLookupService;

  DateTime _selectedDay = DateTime.now();
  bool _isLoading = false;
  String? _error;
  List<Appointment> _appointments = const <Appointment>[];

  @override
  void initState() {
    super.initState();
    _appointmentService =
        widget.appointmentService ?? const AppointmentService();
    _patientLookupService =
        widget.patientLookupService ?? const PatientLookupService();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final appointments = await _appointmentService.listByDay(_selectedDay);
      if (!mounted) return;
      setState(() {
        _appointments = appointments;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _appointments = const <Appointment>[];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changeDay(int deltaDays) async {
    setState(() {
      _selectedDay = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day + deltaDays,
      );
    });
    await _loadAppointments();
  }

  Future<void> _goToToday() async {
    setState(() {
      _selectedDay = DateTime.now();
    });
    await _loadAppointments();
  }

  Future<void> _handleCreateAppointment() async {
    final result = await showDialog<_AppointmentEditorResult>(
      context: context,
      barrierDismissible: true,
      builder:
          (_) => _AppointmentEditorDialog(
            patientLookupService: _patientLookupService,
          ),
    );
    if (result == null || result.action != _AppointmentEditorAction.save) {
      return;
    }

    try {
      await _appointmentService.create(result.draft!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Appointment created.')));
      await _loadAppointments();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create appointment: $error')),
      );
    }
  }

  Future<void> _handleEditAppointment(Appointment appointment) async {
    final result = await showDialog<_AppointmentEditorResult>(
      context: context,
      barrierDismissible: true,
      builder:
          (_) => _AppointmentEditorDialog(
            patientLookupService: _patientLookupService,
            appointment: appointment,
          ),
    );
    if (result == null) return;

    try {
      switch (result.action) {
        case _AppointmentEditorAction.save:
          await _appointmentService.update(appointment.id, result.draft!);
          if (result.status != null && result.status != appointment.status) {
            await _appointmentService.setStatus(appointment.id, result.status!);
          }
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Appointment updated.')));
          await _loadAppointments();
          return;
        case _AppointmentEditorAction.delete:
          await _appointmentService.deleteFuture(appointment);
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Appointment deleted.')));
          await _loadAppointments();
          return;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update appointment: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryPageScaffold(
      scrollable: false,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Schedule',
            subtitle:
                'Manage both treatment rooms on one screen and allow time overlaps between cabinets.',
            actionLabel: 'Back to dashboard',
            onAction: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 16),
          _buildToolbar(),
          const SizedBox(height: 14),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Align(
        alignment: Alignment.topLeft,
        child: _buildMessageCard(
          icon: Icons.cloud_off_rounded,
          title: 'Schedule unavailable',
          message: _error!,
        ),
      );
    }

    if (_isLoading && _appointments.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: _buildMessageCard(
          icon: Icons.calendar_today_outlined,
          title: 'Loading schedule',
          message: 'Collecting appointments for the selected day.',
        ),
      );
    }

    if (_appointments.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: _buildMessageCard(
          icon: Icons.event_busy_outlined,
          title: 'No appointments',
          message:
              'This day is empty. Add the first appointment to start using the schedule as a reliable visit source.',
        ),
      );
    }

    if (_isLoading) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              backgroundColor: Colors.white.withOpacity(0.08),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildAppointmentsBoard()),
        ],
      );
    }

    return _buildAppointmentsBoard();
  }

  Widget _buildToolbar() {
    final totalAppointments = _appointments.length;
    final scheduledCount =
        _appointments
            .where(
              (appointment) =>
                  appointment.status == AppointmentStatus.scheduled,
            )
            .length;
    final orthopedicCount =
        _appointmentsForRoom(AppointmentRoomOption.orthopedic.label).length;
    final surgicalCount =
        _appointmentsForRoom(AppointmentRoomOption.surgical.label).length;
    final reviewCount = _needsReviewCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: buildSurfaceCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDayControl(
                  icon: Icons.chevron_left_rounded,
                  label: 'Prev day',
                  onPressed: () => _changeDay(-1),
                ),
                const SizedBox(width: 8),
                _buildDayChip(_selectedDay),
                const SizedBox(width: 8),
                _buildDayControl(
                  icon: Icons.chevron_right_rounded,
                  label: 'Next day',
                  onPressed: () => _changeDay(1),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _goToToday,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    side: BorderSide(color: Colors.white.withOpacity(0.14)),
                  ),
                  icon: const Icon(Icons.today_outlined, size: 16),
                  label: const Text('Today'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _handleCreateAppointment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentStrong,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Add appointment',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildToolbarStatChip(
                label: 'Total',
                value:
                    totalAppointments == 0
                        ? 'No visits'
                        : '$totalAppointments visits',
              ),
              _buildToolbarStatChip(
                label: 'Scheduled',
                value: '$scheduledCount active',
              ),
              _buildToolbarStatChip(
                label: AppointmentRoomOption.orthopedic.label,
                value: '$orthopedicCount booked',
              ),
              _buildToolbarStatChip(
                label: AppointmentRoomOption.surgical.label,
                value: '$surgicalCount booked',
              ),
              if (reviewCount > 0)
                _buildToolbarStatChip(
                  label: 'Needs review',
                  value: '$reviewCount legacy',
                  accentColor: const Color(0xFFF59E0B),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayControl({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(color: Colors.white.withOpacity(0.16)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
      ),
    );
  }

  Widget _buildDayChip(DateTime day) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 14,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            _formatDayLabel(day),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarStatChip({
    required String label,
    required String value,
    Color? accentColor,
  }) {
    final foreground = accentColor ?? AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (accentColor ?? Colors.white).withOpacity(
            accentColor == null ? 0.08 : 0.28,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foreground.withOpacity(accentColor == null ? 0.9 : 1),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: buildSurfaceCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textMuted.withOpacity(0.92),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsBoard() {
    final orthopedicAppointments = _appointmentsForRoom(
      AppointmentRoomOption.orthopedic.label,
    );
    final surgicalAppointments = _appointmentsForRoom(
      AppointmentRoomOption.surgical.label,
    );
    final reviewCount = _needsReviewCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: buildSurfaceCardDecoration(glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reviewCount > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.24),
                ),
              ),
              child: Text(
                '$reviewCount appointments still use legacy or empty room labels. They are excluded from the two-cabinet board until corrected.',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _RoomBoardColumn(
                    room: AppointmentRoomOption.orthopedic,
                    appointments: orthopedicAppointments,
                    onTapAppointment: _handleEditAppointment,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RoomBoardColumn(
                    room: AppointmentRoomOption.surgical,
                    appointments: surgicalAppointments,
                    onTapAppointment: _handleEditAppointment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Appointment> _appointmentsForRoom(String roomLabel) {
    return sortAppointmentsByStartTime(
      _appointments.where((appointment) => appointment.roomLabel == roomLabel),
    );
  }

  int get _needsReviewCount {
    return _appointments
        .where(
          (appointment) =>
              (appointment.roomLabel ?? '').isEmpty ||
              !isKnownAppointmentRoomLabel(appointment.roomLabel),
        )
        .length;
  }
}

class _RoomBoardColumn extends StatelessWidget {
  final AppointmentRoomOption room;
  final List<Appointment> appointments;
  final ValueChanged<Appointment> onTapAppointment;

  const _RoomBoardColumn({
    required this.room,
    required this.appointments,
    required this.onTapAppointment,
  });

  @override
  Widget build(BuildContext context) {
    final scheduledCount =
        appointments
            .where(
              (appointment) =>
                  appointment.status == AppointmentStatus.scheduled,
            )
            .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  room.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  '${appointments.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$scheduledCount active • ${room.description}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child:
                appointments.isEmpty
                    ? _EmptyRoomColumn(room: room)
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        final count = appointments.length;
                        final spacing = count > 10 ? 3.0 : 5.0;
                        final slotHeight =
                            ((constraints.maxHeight - (spacing * (count - 1))) /
                                        count)
                                    .clamp(20.0, 76.0)
                                as double;
                        final usedHeight =
                            (slotHeight * count) + (spacing * (count - 1));
                        final fillerHeight = constraints.maxHeight - usedHeight;

                        return Column(
                          children: [
                            ...List.generate(count, (index) {
                              final appointment = appointments[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == count - 1 ? 0 : spacing,
                                ),
                                child: SizedBox(
                                  height: slotHeight,
                                  child: _CompactAppointmentTile(
                                    appointment: appointment,
                                    slotHeight: slotHeight,
                                    onTap: () => onTapAppointment(appointment),
                                  ),
                                ),
                              );
                            }),
                            if (fillerHeight > 0)
                              SizedBox(height: fillerHeight),
                          ],
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _CompactAppointmentTile extends StatelessWidget {
  final Appointment appointment;
  final double slotHeight;
  final VoidCallback onTap;

  const _CompactAppointmentTile({
    required this.appointment,
    required this.slotHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyleFor(appointment.status);
    final isUltraCompact = slotHeight <= 28;
    final isCompact = slotHeight <= 40;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isUltraCompact ? 8 : 10,
          vertical: isUltraCompact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusStyle.borderColor.withOpacity(0.36)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: isUltraCompact ? 52 : 58,
              padding: EdgeInsets.symmetric(
                horizontal: isUltraCompact ? 6 : 8,
                vertical: isUltraCompact ? 2 : 4,
              ),
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
                    _formatTime(appointment.startAt),
                    style: TextStyle(
                      fontSize: isUltraCompact ? 9.5 : 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appointment.patientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isUltraCompact ? 11 : 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (!isUltraCompact)
                    Text(
                      _displayVisitLabel(appointment.visitLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isCompact ? 10.5 : 11,
                        color: AppColors.textMuted.withOpacity(0.9),
                      ),
                    ),
                  if (!isCompact && (appointment.notes ?? '').isNotEmpty)
                    Text(
                      appointment.notes!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted.withOpacity(0.72),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (!isUltraCompact)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 7 : 8,
                  vertical: isCompact ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: statusStyle.backgroundColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusStyle.borderColor),
                ),
                child: Text(
                  appointment.status.label,
                  style: TextStyle(
                    fontSize: isCompact ? 9 : 10,
                    fontWeight: FontWeight.w700,
                    color: statusStyle.textColor,
                  ),
                ),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusStyle.textColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRoomColumn extends StatelessWidget {
  final AppointmentRoomOption room;

  const _EmptyRoomColumn({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
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
                'No visits in ${room.label.toLowerCase()}',
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
      ),
    );
  }
}

enum _AppointmentEditorAction { save, delete }

class _AppointmentEditorResult {
  final _AppointmentEditorAction action;
  final AppointmentDraft? draft;
  final AppointmentStatus? status;

  const _AppointmentEditorResult._({
    required this.action,
    this.draft,
    this.status,
  });

  const _AppointmentEditorResult.save(
    AppointmentDraft draft,
    AppointmentStatus status,
  ) : this._(
        action: _AppointmentEditorAction.save,
        draft: draft,
        status: status,
      );

  const _AppointmentEditorResult.delete()
    : this._(action: _AppointmentEditorAction.delete);
}

class _AppointmentEditorDialog extends StatefulWidget {
  final PatientLookupService patientLookupService;
  final Appointment? appointment;

  const _AppointmentEditorDialog({
    required this.patientLookupService,
    this.appointment,
  });

  @override
  State<_AppointmentEditorDialog> createState() =>
      _AppointmentEditorDialogState();
}

class _AppointmentEditorDialogState extends State<_AppointmentEditorDialog> {
  late final TextEditingController _searchController;
  late final TextEditingController _visitLabelController;
  late final TextEditingController _notesController;

  PatientLookupResult? _selectedPatient;
  List<PatientLookupResult> _results = const <PatientLookupResult>[];
  bool _isSearching = false;
  late DateTime _startAt;
  late DateTime _endAt;
  late AppointmentStatus _status;
  String? _selectedRoomLabel;

  bool get _isEditing => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    final appointment = widget.appointment;
    _searchController = TextEditingController();
    _visitLabelController = TextEditingController(
      text: appointment?.visitLabel ?? '',
    );
    _notesController = TextEditingController(text: appointment?.notes ?? '');
    _startAt =
        appointment?.startAt.toLocal() ??
        roundToNextHalfHour(DateTime.now().add(const Duration(minutes: 30)));
    _endAt =
        appointment?.endAt.toLocal() ??
        _startAt.add(const Duration(minutes: 30));
    _status = appointment?.status ?? AppointmentStatus.scheduled;
    _selectedRoomLabel = appointment?.roomLabel;

    if (appointment != null) {
      _selectedPatient = PatientLookupResult(
        id: appointment.patientId,
        title: appointment.patientName,
        subtitle: appointment.patientSubtitle,
        matchType: PatientLookupMatchType.record,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _visitLabelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = const <PatientLookupResult>[];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await widget.patientLookupService.search(cleanQuery);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const <PatientLookupResult>[];
        _isSearching = false;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Select appointment date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _startAt.hour,
        _startAt.minute,
      );
      if (!_endAt.isAfter(_startAt)) {
        _endAt = _startAt.add(const Duration(minutes: 30));
      }
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
      helpText: 'Select appointment start time',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startAt = DateTime(
        _startAt.year,
        _startAt.month,
        _startAt.day,
        picked.hour,
        picked.minute,
      );
      if (!_endAt.isAfter(_startAt)) {
        _endAt = _startAt.add(const Duration(minutes: 30));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endAt,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Select appointment end date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _endAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _endAt.hour,
        _endAt.minute,
      );
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endAt),
      helpText: 'Select appointment end time',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _endAt = DateTime(
        _endAt.year,
        _endAt.month,
        _endAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _save() {
    final patient = _selectedPatient;
    if (patient == null) {
      _showError('Select an existing patient first.');
      return;
    }

    try {
      final draft = AppointmentDraft(
        patientId: patient.id,
        startAt: _startAt,
        endAt: _endAt,
        visitLabel: _visitLabelController.text,
        roomLabel: _selectedRoomLabel,
        notes: _notesController.text,
      );
      draft.validate();
      Navigator.of(context).pop(_AppointmentEditorResult.save(draft, _status));
    } catch (error) {
      _showError(error.toString());
    }
  }

  void _delete() {
    Navigator.of(context).pop(const _AppointmentEditorResult.delete());
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Bad state: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDelete =
        widget.appointment != null &&
        canDeleteFutureAppointment(widget.appointment!, now: DateTime.now());

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _isEditing ? 'Edit appointment' : 'Add appointment',
                          style: const TextStyle(
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
                      )
                    else if (_isSearching)
                      LinearProgressIndicator(
                        minHeight: 4,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.accent,
                        ),
                        backgroundColor: Colors.white.withOpacity(0.08),
                      )
                    else if (_results.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _results.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final result = _results[index];
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedPatient = result;
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            );
                          },
                        ),
                      )
                    else
                      Text(
                        _searchController.text.trim().isEmpty
                            ? 'Search to attach an existing patient card.'
                            : 'No patients found for this search.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted.withOpacity(0.88),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _visitLabelController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: buildFormInputDecoration(
                        'Visit label (optional)',
                        hint: 'Consultation, hygiene, implant follow-up',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _DateTimeButton(
                            label: 'Start date',
                            value: _formatShortDate(_startAt),
                            onPressed: _pickStartDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DateTimeButton(
                            label: 'Start time',
                            value: _formatTime(_startAt),
                            onPressed: _pickStartTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _DateTimeButton(
                            label: 'End date',
                            value: _formatShortDate(_endAt),
                            onPressed: _pickEndDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DateTimeButton(
                            label: 'End time',
                            value: _formatTime(_endAt),
                            onPressed: _pickEndTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildRoomSelector(),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      minLines: 2,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: buildFormInputDecoration(
                        'Notes',
                        hint: 'Optional context for reception or doctor',
                      ),
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            AppointmentStatus.values.map((status) {
                              final isSelected = status == _status;
                              return ChoiceChip(
                                label: Text(status.label),
                                selected: isSelected,
                                selectedColor:
                                    status == AppointmentStatus.scheduled
                                        ? AppColors.accentStrong
                                        : _statusStyleFor(
                                          status,
                                        ).backgroundColor,
                                labelStyle: TextStyle(
                                  color:
                                      isSelected
                                          ? AppColors.bg
                                          : AppColors.textPrimary,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    _status = status;
                                  });
                                },
                              );
                            }).toList(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (canDelete)
                          TextButton(
                            onPressed: _delete,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                            ),
                            child: const Text('Delete future visit'),
                          ),
                        if (canDelete) const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed:
                              _selectedPatient != null &&
                                      (_selectedRoomLabel ?? '')
                                          .trim()
                                          .isNotEmpty
                                  ? _save
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentStrong,
                            foregroundColor: AppColors.bg,
                          ),
                          child: Text(_isEditing ? 'Save' : 'Add'),
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

  Widget _buildRoomSelector() {
    final hasLegacyRoom =
        (_selectedRoomLabel ?? '').isNotEmpty &&
        !isKnownAppointmentRoomLabel(_selectedRoomLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Room',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose where the procedure will happen so the schedule is split correctly between the two cabinets.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted.withOpacity(0.88),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              AppointmentRoomOption.values.map((option) {
                final isSelected = option.label == _selectedRoomLabel;
                return ChoiceChip(
                  label: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(option.label),
                      Text(
                        option.description,
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isSelected
                                  ? AppColors.bg.withOpacity(0.8)
                                  : AppColors.textMuted.withOpacity(0.84),
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.accentStrong,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.bg : AppColors.textPrimary,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedRoomLabel = option.label;
                    });
                  },
                );
              }).toList(),
        ),
        if (hasLegacyRoom) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withOpacity(0.25)),
            ),
            child: Text(
              'This appointment still uses a legacy room label: $_selectedRoomLabel. Pick one of the standard rooms above if you want to normalize it.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onPressed;

  const _DateTimeButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        side: BorderSide(color: Colors.white.withOpacity(0.14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surfaceDark.withOpacity(0.96),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted.withOpacity(0.86),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentStatusStyle {
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const _AppointmentStatusStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });
}

_AppointmentStatusStyle _statusStyleFor(AppointmentStatus status) {
  switch (status) {
    case AppointmentStatus.scheduled:
      return _AppointmentStatusStyle(
        backgroundColor: AppColors.accent.withOpacity(0.18),
        borderColor: AppColors.accent.withOpacity(0.35),
        textColor: AppColors.accentSoft,
      );
    case AppointmentStatus.cancelled:
      return const _AppointmentStatusStyle(
        backgroundColor: Color(0x33F97316),
        borderColor: Color(0x66F97316),
        textColor: Color(0xFFF97316),
      );
    case AppointmentStatus.noShow:
      return const _AppointmentStatusStyle(
        backgroundColor: Color(0x33EF4444),
        borderColor: Color(0x66EF4444),
        textColor: Color(0xFFEF4444),
      );
  }
}

String _formatDayLabel(DateTime value) {
  final local = DateTime(value.year, value.month, value.day);
  final today = DateTime.now();
  final todayLocal = DateTime(today.year, today.month, today.day);
  final diffDays = local.difference(todayLocal).inDays;

  if (diffDays == 0) {
    return 'Today, ${_formatMonthDayYear(local)}';
  }
  if (diffDays == 1) {
    return 'Tomorrow, ${_formatMonthDayYear(local)}';
  }
  if (diffDays == -1) {
    return 'Yesterday, ${_formatMonthDayYear(local)}';
  }
  return _formatMonthDayYear(local);
}

String _formatMonthDayYear(DateTime value) {
  return '${_monthName(value.month)} ${value.day}, ${value.year}';
}

String _formatShortDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _displayVisitLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return 'No visit label';
  }
  return normalized;
}

String _formatTimeRange(DateTime start, DateTime end) {
  return '${_formatTime(start)} - ${_formatTime(end)}';
}

String _formatDuration(DateTime start, DateTime end) {
  final safeDuration = end.difference(start);
  final totalMinutes = safeDuration.isNegative ? 0 : safeDuration.inMinutes;
  if (totalMinutes < 60) {
    return '$totalMinutes min';
  }
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${minutes}m';
}

String _monthName(int month) {
  switch (month) {
    case 1:
      return 'January';
    case 2:
      return 'February';
    case 3:
      return 'March';
    case 4:
      return 'April';
    case 5:
      return 'May';
    case 6:
      return 'June';
    case 7:
      return 'July';
    case 8:
      return 'August';
    case 9:
      return 'September';
    case 10:
      return 'October';
    case 11:
      return 'November';
    case 12:
    default:
      return 'December';
  }
}
