import 'package:flutter/material.dart';

class TimelineStatusBadgeVm {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final Color dotColor;

  const TimelineStatusBadgeVm({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.dotColor,
  });
}

class TimelineEntryVm {
  final dynamic id;
  final String title;
  final String status;
  final List<String> teeth;
  final int entriesCount;
  final DateTime dateTime;
  final String? timeLabel;
  final TimelineStatusBadgeVm badge;
  final Map<String, dynamic> source;

  const TimelineEntryVm({
    required this.id,
    required this.title,
    required this.status,
    required this.teeth,
    this.entriesCount = 1,
    required this.dateTime,
    required this.timeLabel,
    required this.badge,
    required this.source,
  });
}

class TimelineDayGroupVm {
  final DateTime day;
  final String dayKey;
  final List<TimelineEntryVm> entries;
  final int totalEntries;

  const TimelineDayGroupVm({
    required this.day,
    required this.dayKey,
    required this.entries,
    required this.totalEntries,
  });

  int get hiddenEntries {
    final value = totalEntries - entries.length;
    return value > 0 ? value : 0;
  }
}

DateTime? parseTimelineDate(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  if (raw is num) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    } catch (_) {
      return null;
    }
  }
  return null;
}

String normalizeTimelineStatus(dynamic raw) {
  final value = (raw ?? '').toString().trim();
  return value.isEmpty ? 'treated' : value;
}

bool isTreatedStatus(String status) {
  return status.toLowerCase() == 'treated';
}

String resolveTimelineType(Map<String, dynamic> row) {
  final value =
      (row['treatmentType'] ?? row['type'] ?? row['treatment_type'] ?? '')
          .toString()
          .trim();
  return value.isEmpty ? 'Treatment' : value;
}

List<String> parseTimelineTeeth(dynamic raw) {
  if (raw is Iterable) {
    return raw
        .map((e) => e?.toString().trim())
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
  }
  if (raw is Map) {
    return raw.keys
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  if (raw == null) return const <String>[];

  final value = raw.toString().trim();
  if (value.isEmpty) return const <String>[];
  if (value.contains(',')) {
    return value
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return <String>[value];
}

String timelineDayKey(DateTime dateTime) {
  String two(int v) => v < 10 ? '0$v' : '$v';
  return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}';
}

String formatTimelineDayLabel(DateTime day, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toLocal();
  final today = DateTime(reference.year, reference.month, reference.day);
  final target = DateTime(day.year, day.month, day.day);
  final diffDays = today.difference(target).inDays;

  if (diffDays == 0) return 'Today';
  if (diffDays == 1) return 'Yesterday';

  return '${_monthName(day.month)} ${day.day}, ${day.year}';
}

String? formatTimelineTimeLabel(DateTime? value, {bool hideMidnight = true}) {
  if (value == null) return null;
  if (hideMidnight && value.hour == 0 && value.minute == 0) return null;
  String two(int v) => v < 10 ? '0$v' : '$v';
  return '${two(value.hour)}:${two(value.minute)}';
}

String formatTimelineDateTimeLabel(DateTime value) {
  final day = '${_monthName(value.month)} ${value.day}, ${value.year}';
  final time = formatTimelineTimeLabel(value, hideMidnight: false);
  if (time == null) return day;
  return '$day, $time';
}

TimelineStatusBadgeVm resolveTimelineStatusBadge(String status) {
  switch (status.toLowerCase()) {
    case 'treated':
      return const TimelineStatusBadgeVm(
        text: 'Completed',
        backgroundColor: Color(0x338ABA8A),
        textColor: Color(0xFF8ABA8A),
        dotColor: Color(0xFF8ABA8A),
      );
    case 'inprogress':
      return const TimelineStatusBadgeVm(
        text: 'In progress',
        backgroundColor: Color(0x33D4A04A),
        textColor: Color(0xFFD4A04A),
        dotColor: Color(0xFFD4A04A),
      );
    case 'planned':
      return const TimelineStatusBadgeVm(
        text: 'Planned',
        backgroundColor: Color(0x33E8564A),
        textColor: Color(0xFFE8564A),
        dotColor: Color(0xFFE8564A),
      );
    default:
      return const TimelineStatusBadgeVm(
        text: 'Unknown',
        backgroundColor: Color(0x33A8A8A8),
        textColor: Color(0xFFD0D0D0),
        dotColor: Color(0xFFD0D0D0),
      );
  }
}

List<TimelineDayGroupVm> buildTreatedTimelineGroups(
  List<Map<String, dynamic>> rows, {
  int? maxDays,
  int? maxEntriesPerDay,
}) {
  final entries = <TimelineEntryVm>[];
  for (final row in rows) {
    final status = normalizeTimelineStatus(row['status']);
    if (!isTreatedStatus(status)) continue;

    final parsedDate = parseTimelineDate(row['date']);
    if (parsedDate == null) continue;

    final localDate = parsedDate.toLocal();
    final badge = resolveTimelineStatusBadge(status);

    entries.add(
      TimelineEntryVm(
        id: row['id'],
        title: resolveTimelineType(row),
        status: status,
        teeth: parseTimelineTeeth(row['toothNumber'] ?? row['tooth_number']),
        dateTime: localDate,
        timeLabel: formatTimelineTimeLabel(localDate),
        badge: badge,
        source: row,
      ),
    );
  }

  entries.sort((a, b) => b.dateTime.compareTo(a.dateTime));

  final grouped = <String, List<TimelineEntryVm>>{};
  for (final entry in entries) {
    final key = timelineDayKey(entry.dateTime);
    grouped.putIfAbsent(key, () => <TimelineEntryVm>[]).add(entry);
  }

  var orderedDayKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  if (maxDays != null && maxDays > 0 && orderedDayKeys.length > maxDays) {
    orderedDayKeys = orderedDayKeys.sublist(0, maxDays);
  }

  final result = <TimelineDayGroupVm>[];
  for (final dayKey in orderedDayKeys) {
    final dayEntries = grouped[dayKey]!;
    final mergedEntries = _mergeSameTreatmentWithinDay(dayEntries);
    var visibleEntries = mergedEntries;
    if (maxEntriesPerDay != null &&
        maxEntriesPerDay > 0 &&
        mergedEntries.length > maxEntriesPerDay) {
      visibleEntries = mergedEntries.sublist(0, maxEntriesPerDay);
    }

    final anchor = mergedEntries.first.dateTime;
    final day = DateTime(anchor.year, anchor.month, anchor.day);

    result.add(
      TimelineDayGroupVm(
        day: day,
        dayKey: dayKey,
        entries: visibleEntries,
        totalEntries: mergedEntries.length,
      ),
    );
  }

  return result;
}

List<TimelineEntryVm> _mergeSameTreatmentWithinDay(
  List<TimelineEntryVm> entries,
) {
  if (entries.length <= 1) return entries;

  final grouped = <String, _TimelineEntryAccumulator>{};
  for (final entry in entries) {
    final key = '${entry.title.toLowerCase()}|${entry.status.toLowerCase()}';
    final bucket = grouped.putIfAbsent(
      key,
      () => _TimelineEntryAccumulator(entry),
    );
    bucket.add(entry);
  }

  final merged = grouped.values.map((e) => e.toEntry()).toList();
  merged.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  return merged;
}

String _monthName(int month) {
  const names = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  if (month < 1 || month > 12) return 'Unknown';
  return names[month - 1];
}

class _TimelineEntryAccumulator {
  TimelineEntryVm _representative;
  final Set<String> _teeth = <String>{};
  int _entriesCount = 0;

  _TimelineEntryAccumulator(this._representative) {
    _teeth.addAll(_representative.teeth);
  }

  void add(TimelineEntryVm next) {
    _entriesCount += 1;
    _teeth.addAll(next.teeth);

    if (next.dateTime.isAfter(_representative.dateTime)) {
      _representative = next;
    }
  }

  TimelineEntryVm toEntry() {
    final mergedTeeth = _teeth.toList()..sort();
    return TimelineEntryVm(
      id: _representative.id,
      title: _representative.title,
      status: _representative.status,
      teeth: mergedTeeth,
      entriesCount: _entriesCount,
      dateTime: _representative.dateTime,
      timeLabel: _representative.timeLabel,
      badge: _representative.badge,
      source: _representative.source,
    );
  }
}
