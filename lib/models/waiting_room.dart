import 'package:flutter/foundation.dart';

enum WaitingRoomLane { scheduled, unscheduled }

enum WaitingRoomEntrySourceType { patient, manual }

extension WaitingRoomLaneValue on WaitingRoomLane {
  String get value {
    switch (this) {
      case WaitingRoomLane.scheduled:
        return 'scheduled';
      case WaitingRoomLane.unscheduled:
        return 'unscheduled';
    }
  }

  String get title {
    switch (this) {
      case WaitingRoomLane.scheduled:
        return 'By appointment';
      case WaitingRoomLane.unscheduled:
        return 'Walk-in';
    }
  }

  static WaitingRoomLane fromRaw(dynamic raw) {
    switch ((raw ?? '').toString().trim().toLowerCase()) {
      case 'scheduled':
        return WaitingRoomLane.scheduled;
      case 'unscheduled':
      default:
        return WaitingRoomLane.unscheduled;
    }
  }
}

extension WaitingRoomEntrySourceTypeValue on WaitingRoomEntrySourceType {
  String get value {
    switch (this) {
      case WaitingRoomEntrySourceType.patient:
        return 'patient';
      case WaitingRoomEntrySourceType.manual:
        return 'manual';
    }
  }

  String get title {
    switch (this) {
      case WaitingRoomEntrySourceType.patient:
        return 'Patient card';
      case WaitingRoomEntrySourceType.manual:
        return 'Manual entry';
    }
  }

  static WaitingRoomEntrySourceType fromRaw(dynamic raw) {
    switch ((raw ?? '').toString().trim().toLowerCase()) {
      case 'patient':
        return WaitingRoomEntrySourceType.patient;
      case 'manual':
      default:
        return WaitingRoomEntrySourceType.manual;
    }
  }
}

@immutable
class WaitingRoomReason {
  final String id;
  final String label;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WaitingRoomReason({
    required this.id,
    required this.label,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WaitingRoomReason.fromRow(Map<String, dynamic> row) {
    return WaitingRoomReason(
      id: (row['id'] ?? '').toString().trim(),
      label: (row['label'] ?? '').toString().trim(),
      sortOrder: _parseNullableInt(row['sort_order']) ?? 0,
      isActive: _parseBool(row['is_active']) ?? true,
      createdAt:
          _parseDateTime(row['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parseDateTime(row['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

@immutable
class WaitingRoomEntry {
  final String id;
  final String entryDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final WaitingRoomLane lane;
  final WaitingRoomEntrySourceType sourceType;
  final String? patientId;
  final String displayName;
  final String? manualSurname;
  final String? reasonId;
  final String reasonLabelSnapshot;

  const WaitingRoomEntry({
    required this.id,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
    required this.lane,
    required this.sourceType,
    required this.patientId,
    required this.displayName,
    required this.manualSurname,
    required this.reasonId,
    required this.reasonLabelSnapshot,
  });

  factory WaitingRoomEntry.fromRow(Map<String, dynamic> row) {
    return WaitingRoomEntry(
      id: (row['id'] ?? '').toString().trim(),
      entryDate: (row['entry_date'] ?? '').toString().trim(),
      createdAt:
          _parseDateTime(row['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parseDateTime(row['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lane: WaitingRoomLaneValue.fromRaw(row['lane']),
      sourceType: WaitingRoomEntrySourceTypeValue.fromRaw(row['source_type']),
      patientId: _readNullableString(row['patient_id']),
      displayName: (row['display_name'] ?? '').toString().trim(),
      manualSurname: _readNullableString(row['manual_surname']),
      reasonId: _readNullableString(row['reason_id']),
      reasonLabelSnapshot:
          (row['reason_label_snapshot'] ?? '').toString().trim(),
    );
  }

  String resolveReasonLabel(Map<String, WaitingRoomReason> reasonsById) {
    final reason = reasonId == null ? null : reasonsById[reasonId];
    final label = reason?.label.trim() ?? '';
    if (label.isNotEmpty) return label;
    return reasonLabelSnapshot;
  }
}

@immutable
class CreateWaitingRoomEntryDraft {
  final WaitingRoomLane lane;
  final String reasonId;
  final String? patientId;
  final String? manualSurname;

  const CreateWaitingRoomEntryDraft({
    required this.lane,
    required this.reasonId,
    this.patientId,
    this.manualSurname,
  });

  bool get isPatientSource => _hasValue(patientId);
  bool get isManualSource => _hasValue(manualSurname);

  void validate() {
    final hasPatient = isPatientSource;
    final hasManual = isManualSource;
    if (reasonId.trim().isEmpty) {
      throw StateError('Waiting room reason is required.');
    }
    if (hasPatient == hasManual) {
      throw StateError(
        'Provide either patientId or manualSurname for a waiting room entry.',
      );
    }
  }
}

@immutable
class UpdateWaitingRoomEntryDraft {
  final WaitingRoomLane lane;
  final String reasonId;

  const UpdateWaitingRoomEntryDraft({
    required this.lane,
    required this.reasonId,
  });

  void validate() {
    if (reasonId.trim().isEmpty) {
      throw StateError('Waiting room reason is required.');
    }
  }
}

String waitingRoomEntryDateFor(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

List<WaitingRoomEntry> waitingRoomEntriesForDate(
  Iterable<WaitingRoomEntry> entries,
  String entryDate,
) {
  return entries.where((entry) => entry.entryDate == entryDate).toList();
}

List<WaitingRoomEntry> sortWaitingRoomEntriesDescending(
  Iterable<WaitingRoomEntry> entries,
) {
  final sorted =
      entries.toList()..sort((left, right) {
        final createdCompare = right.createdAt.compareTo(left.createdAt);
        if (createdCompare != 0) return createdCompare;
        return right.id.compareTo(left.id);
      });
  return sorted;
}

Duration averageWaitingRoomDuration(
  Iterable<WaitingRoomEntry> entries,
  DateTime now,
) {
  var count = 0;
  var totalSeconds = 0;

  for (final entry in entries) {
    final wait = now.difference(entry.createdAt);
    totalSeconds += wait.isNegative ? 0 : wait.inSeconds;
    count += 1;
  }

  if (count == 0) {
    return Duration.zero;
  }

  return Duration(seconds: totalSeconds ~/ count);
}

Duration maxWaitingRoomDuration(
  Iterable<WaitingRoomEntry> entries,
  DateTime now,
) {
  final entry = maxWaitingRoomEntry(entries, now);
  if (entry == null) {
    return Duration.zero;
  }

  final wait = now.difference(entry.createdAt);
  final safeSeconds = wait.isNegative ? 0 : wait.inSeconds;
  return Duration(seconds: safeSeconds);
}

WaitingRoomEntry? maxWaitingRoomEntry(
  Iterable<WaitingRoomEntry> entries,
  DateTime now,
) {
  WaitingRoomEntry? currentMaxEntry;
  var currentMaxSeconds = -1;

  for (final entry in entries) {
    final wait = now.difference(entry.createdAt);
    final safeSeconds = wait.isNegative ? 0 : wait.inSeconds;
    if (safeSeconds > currentMaxSeconds) {
      currentMaxSeconds = safeSeconds;
      currentMaxEntry = entry;
    }
  }

  return currentMaxEntry;
}

String formatWaitingRoomDuration(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final totalHours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60);
  final seconds = safe.inSeconds.remainder(60);

  if (totalHours <= 0) {
    final totalMinutes = safe.inMinutes;
    return '${totalMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  return '$totalHours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String formatWaitingRoomStatDuration(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final totalHours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60);
  final seconds = safe.inSeconds.remainder(60);

  if (totalHours <= 0) {
    final totalMinutes = safe.inMinutes;
    return '${totalMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  return '${totalHours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
}

String? normalizeWaitingRoomReasonLabel(String label) {
  final normalized = label
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .join(' ');
  return normalized.isEmpty ? null : normalized;
}

String? _readNullableString(dynamic raw) {
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

bool _hasValue(String? value) => value?.trim().isNotEmpty == true;

DateTime? _parseDateTime(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

int? _parseNullableInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

bool? _parseBool(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final normalized = raw?.toString().trim().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return null;
}
