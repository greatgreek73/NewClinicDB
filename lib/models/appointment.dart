import '../utils/patient_name_formatter.dart';

enum AppointmentStatus { scheduled, cancelled, noShow }

class AppointmentRoomOption {
  final String label;
  final String description;

  const AppointmentRoomOption._({
    required this.label,
    required this.description,
  });

  static const AppointmentRoomOption orthopedic = AppointmentRoomOption._(
    label: 'Orthopedic room',
    description: 'Prosthetics and restorative visits',
  );

  static const AppointmentRoomOption surgical = AppointmentRoomOption._(
    label: 'Surgical room',
    description: 'Implantation and surgery visits',
  );

  static const List<AppointmentRoomOption> values = <AppointmentRoomOption>[
    orthopedic,
    surgical,
  ];
}

extension AppointmentStatusValue on AppointmentStatus {
  String get value {
    switch (this) {
      case AppointmentStatus.scheduled:
        return 'scheduled';
      case AppointmentStatus.cancelled:
        return 'cancelled';
      case AppointmentStatus.noShow:
        return 'no_show';
    }
  }

  String get label {
    switch (this) {
      case AppointmentStatus.scheduled:
        return 'Scheduled';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.noShow:
        return 'No-show';
    }
  }

  static AppointmentStatus fromRaw(dynamic raw) {
    switch ((raw ?? '').toString().trim().toLowerCase()) {
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'no_show':
      case 'noshow':
      case 'no-show':
        return AppointmentStatus.noShow;
      case 'scheduled':
      default:
        return AppointmentStatus.scheduled;
    }
  }
}

class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String patientSubtitle;
  final DateTime startAt;
  final DateTime endAt;
  final String visitLabel;
  final String? roomLabel;
  final String? notes;
  final AppointmentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientSubtitle,
    required this.startAt,
    required this.endAt,
    required this.visitLabel,
    required this.roomLabel,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Appointment.fromRow(Map<String, dynamic> row) {
    final patientData =
        row['patient'] is Map
            ? Map<String, dynamic>.from(row['patient'] as Map)
            : <String, dynamic>{};
    final patientName = formatPatientDisplayName(
      name: patientData['name'],
      surname: patientData['surname'],
      fallback: 'Patient ${(row['patient_id'] ?? '').toString().trim()}',
    );
    final phone = (patientData['phone'] ?? '').toString().trim();
    final city = (patientData['city'] ?? '').toString().trim();
    final subtitle = [
      phone,
      city,
    ].where((value) => value.isNotEmpty).join(' • ');

    return Appointment(
      id: (row['id'] ?? '').toString().trim(),
      patientId: (row['patient_id'] ?? '').toString().trim(),
      patientName: patientName,
      patientSubtitle: subtitle,
      startAt:
          _parseDateTime(row['start_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endAt:
          _parseDateTime(row['end_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      visitLabel: (row['visit_label'] ?? '').toString().trim(),
      roomLabel: normalizeAppointmentRoomLabel(row['room_label']),
      notes: _readNullableString(row['notes']),
      status: AppointmentStatusValue.fromRaw(row['status']),
      createdAt:
          _parseDateTime(row['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parseDateTime(row['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AppointmentDraft {
  final String patientId;
  final DateTime startAt;
  final DateTime endAt;
  final String visitLabel;
  final String? roomLabel;
  final String? notes;

  const AppointmentDraft({
    required this.patientId,
    required this.startAt,
    required this.endAt,
    required this.visitLabel,
    this.roomLabel,
    this.notes,
  });

  void validate() {
    if (patientId.trim().isEmpty) {
      throw StateError('Appointment patient is required.');
    }
    if (_normalizeOptionalText(roomLabel) == null) {
      throw StateError('Appointment room is required.');
    }
    if (!endAt.isAfter(startAt)) {
      throw StateError('Appointment end time must be after start time.');
    }
  }

  Map<String, dynamic> toPayload() {
    validate();
    return <String, dynamic>{
      'patient_id': patientId.trim(),
      'start_at': startAt.toUtc().toIso8601String(),
      'end_at': endAt.toUtc().toIso8601String(),
      'visit_label': visitLabel.trim(),
      'room_label': normalizeAppointmentRoomLabel(roomLabel),
      'notes': _normalizeOptionalText(notes),
    };
  }
}

class AppointmentDayWindow {
  final DateTime startUtc;
  final DateTime endUtc;

  const AppointmentDayWindow({required this.startUtc, required this.endUtc});
}

AppointmentDayWindow appointmentDayWindowForLocalDate(DateTime value) {
  final startLocal = DateTime(value.year, value.month, value.day);
  final endLocal = startLocal.add(const Duration(days: 1));
  return AppointmentDayWindow(
    startUtc: startLocal.toUtc(),
    endUtc: endLocal.toUtc(),
  );
}

List<Appointment> sortAppointmentsByStartTime(
  Iterable<Appointment> appointments,
) {
  final sorted =
      appointments.toList()..sort((left, right) {
        final startCompare = left.startAt.compareTo(right.startAt);
        if (startCompare != 0) return startCompare;
        final endCompare = left.endAt.compareTo(right.endAt);
        if (endCompare != 0) return endCompare;
        return left.id.compareTo(right.id);
      });
  return sorted;
}

List<Appointment> appointmentsForLocalDate(
  Iterable<Appointment> appointments,
  DateTime value,
) {
  final startLocal = DateTime(value.year, value.month, value.day);
  final endLocal = startLocal.add(const Duration(days: 1));
  return sortAppointmentsByStartTime(
    appointments.where((appointment) {
      final localStart = appointment.startAt.toLocal();
      return !localStart.isBefore(startLocal) && localStart.isBefore(endLocal);
    }),
  );
}

bool canDeleteFutureAppointment(Appointment appointment, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  return appointment.status == AppointmentStatus.scheduled &&
      appointment.startAt.isAfter(reference);
}

DateTime roundToNextHalfHour(DateTime value) {
  final local = value.toLocal();
  final truncated = DateTime(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
  );
  if (truncated.minute == 0 || truncated.minute == 30) {
    return truncated;
  }
  final minuteBlock = truncated.minute < 30 ? 30 : 60;
  return DateTime(
    truncated.year,
    truncated.month,
    truncated.day,
    truncated.hour,
    minuteBlock == 60 ? 0 : minuteBlock,
  ).add(minuteBlock == 60 ? const Duration(hours: 1) : Duration.zero);
}

String? normalizeAppointmentRoomLabel(dynamic raw) {
  final normalized = _normalizeOptionalText(raw?.toString());
  if (normalized == null) {
    return null;
  }

  for (final option in AppointmentRoomOption.values) {
    if (normalized.toLowerCase() == option.label.toLowerCase()) {
      return option.label;
    }
  }

  return normalized;
}

bool isKnownAppointmentRoomLabel(String? value) {
  final normalized = normalizeAppointmentRoomLabel(value);
  if (normalized == null) return false;
  return AppointmentRoomOption.values.any(
    (option) => option.label == normalized,
  );
}

String? _normalizeOptionalText(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String? _readNullableString(dynamic raw) {
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

DateTime? _parseDateTime(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}
