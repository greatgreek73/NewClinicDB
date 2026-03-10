import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'patient_payment_service.dart';
import 'supabase_client.dart';
import '../utils/patient_name_formatter.dart';

class WaitlistAssignment {
  final int? stageId;
  final int? order;

  const WaitlistAssignment({this.stageId, this.order});

  bool get isOnWaitlist => stageId != null;
}

class WaitlistSchemaCapabilities {
  final bool usesLegacyStageField;
  final bool supportsPersistentOrdering;

  const WaitlistSchemaCapabilities({
    required this.usesLegacyStageField,
    required this.supportsPersistentOrdering,
  });

  bool get needsWaitlistMigration =>
      usesLegacyStageField || !supportsPersistentOrdering;
}

class WaitlistEntry {
  final String id;
  final String title;
  final String subtitle;
  final int? stageId;
  final int? order;
  final DateTime? firstPaymentDate;

  const WaitlistEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.stageId,
    required this.order,
    required this.firstPaymentDate,
  });
}

class WaitlistOrderPatch {
  final String patientId;
  final int order;

  const WaitlistOrderPatch({required this.patientId, required this.order});
}

int? waitlistStageIdFromData(Map<String, dynamic>? data) {
  return _parseNullableInt(data?[WaitlistService.stageField]) ??
      _parseNullableInt(data?[WaitlistService.legacyStageField]);
}

int? waitlistOrderFromData(Map<String, dynamic>? data) {
  return _parseNullableInt(data?[WaitlistService.orderField]);
}

WaitlistAssignment waitlistAssignmentFromData(Map<String, dynamic>? data) {
  return WaitlistAssignment(
    stageId: waitlistStageIdFromData(data),
    order: waitlistOrderFromData(data),
  );
}

WaitlistEntry waitlistEntryFromRow(Map<String, dynamic> data) {
  final id = (data['id'] ?? '').toString().trim();
  final phone = (data['phone'] ?? '').toString().trim();
  final city = (data['city'] ?? '').toString().trim();
  final subtitle = [phone, city].where((v) => v.isNotEmpty).join(' | ');
  final assignment = waitlistAssignmentFromData(data);

  return WaitlistEntry(
    id: id,
    title: formatPatientDisplayName(
      name: data['name'],
      surname: data['surname'],
      fallback: 'Patient $id',
    ),
    subtitle: subtitle.isNotEmpty ? subtitle : 'No contact details',
    stageId: assignment.stageId,
    order: assignment.order,
    firstPaymentDate: firstPaymentDateFromData(data),
  );
}

DateTime? firstPaymentDateFromData(Map<String, dynamic>? data) {
  if (data == null) return null;
  return firstPaymentDateFromPayments(data['payments']);
}

int compareWaitlistEntries(WaitlistEntry a, WaitlistEntry b) {
  final orderCompare = (a.order ?? 1 << 30).compareTo(b.order ?? 1 << 30);
  if (orderCompare != 0) return orderCompare;

  final titleCompare = a.title.compareTo(b.title);
  if (titleCompare != 0) return titleCompare;

  return a.id.compareTo(b.id);
}

int compareWaitlistEntriesByPaymentAgeDesc(WaitlistEntry a, WaitlistEntry b) {
  final aPaymentDate = a.firstPaymentDate;
  final bPaymentDate = b.firstPaymentDate;

  if (aPaymentDate != null && bPaymentDate != null) {
    final paymentCompare = aPaymentDate.compareTo(bPaymentDate);
    if (paymentCompare != 0) return paymentCompare;
  } else if (aPaymentDate != null) {
    return -1;
  } else if (bPaymentDate != null) {
    return 1;
  }

  return compareWaitlistEntries(a, b);
}

List<WaitlistEntry> waitlistEntriesForStage(
  Iterable<Map<String, dynamic>> rows,
  int stageId,
) {
  final entries =
      rows
          .map(waitlistEntryFromRow)
          .where((entry) => entry.stageId == stageId)
          .toList();
  entries.sort(compareWaitlistEntriesByPaymentAgeDesc);
  return entries;
}

List<WaitlistOrderPatch> compactWaitlistStage(List<WaitlistEntry> entries) {
  final sorted = entries.toList()..sort(compareWaitlistEntries);
  final patches = <WaitlistOrderPatch>[];

  for (var index = 0; index < sorted.length; index++) {
    final desiredOrder = index + 1;
    if (sorted[index].order != desiredOrder) {
      patches.add(
        WaitlistOrderPatch(patientId: sorted[index].id, order: desiredOrder),
      );
    }
  }

  return patches;
}

List<WaitlistOrderPatch> buildWaitlistMovePatches(
  List<WaitlistEntry> entries,
  String patientId,
  int delta,
) {
  final sorted = entries.toList()..sort(compareWaitlistEntries);
  final currentIndex = sorted.indexWhere((entry) => entry.id == patientId);
  if (currentIndex == -1) return const <WaitlistOrderPatch>[];

  final targetIndex = currentIndex + delta;
  if (targetIndex < 0 || targetIndex >= sorted.length) {
    return const <WaitlistOrderPatch>[];
  }

  final reordered = sorted.toList();
  final entry = reordered.removeAt(currentIndex);
  reordered.insert(targetIndex, entry);

  final patches = <WaitlistOrderPatch>[];
  for (var index = 0; index < reordered.length; index++) {
    final desiredOrder = index + 1;
    if (reordered[index].order != desiredOrder) {
      patches.add(
        WaitlistOrderPatch(patientId: reordered[index].id, order: desiredOrder),
      );
    }
  }

  return patches;
}

int nextWaitlistOrder(List<WaitlistEntry> entries) {
  return entries.length + 1;
}

class WaitlistService {
  static const patientsTable = 'patients';
  static const legacyStageField = 'priority_bucket';
  static const stageField = 'waitlist_stage';
  static const orderField = 'waitlist_order';
  static final StreamController<void> _refreshController =
      StreamController<void>.broadcast();

  Future<_WaitlistSchema>? _schemaFuture;

  Stream<WaitlistAssignment> watchPatientWaitlist(String patientId) async* {
    final normalizedId = patientId.trim();
    if (maybeSupabaseClient == null || normalizedId.isEmpty) {
      yield const WaitlistAssignment();
      return;
    }

    yield await _loadPatientWaitlist(normalizedId);
    await for (final _ in _watchRefreshSignals()) {
      if (maybeSupabaseClient == null) {
        yield const WaitlistAssignment();
      } else {
        yield await _loadPatientWaitlist(normalizedId);
      }
    }
  }

  Stream<List<WaitlistEntry>> watchPatientsInStage(int stageId) {
    return watchAllWaitlistEntries().map((entries) {
      final stageEntries =
          entries.where((entry) => entry.stageId == stageId).toList()
            ..sort(compareWaitlistEntriesByPaymentAgeDesc);
      if (stageEntries.length > 100) {
        return stageEntries.sublist(0, 100);
      }
      return stageEntries;
    });
  }

  Stream<List<WaitlistEntry>> watchAllWaitlistEntries({
    int maxRows = 500,
  }) async* {
    if (maybeSupabaseClient == null) {
      yield const <WaitlistEntry>[];
      return;
    }

    yield await _loadAssignedWaitlistEntries(maxRows: maxRows);
    await for (final _ in _watchRefreshSignals()) {
      if (maybeSupabaseClient == null) {
        yield const <WaitlistEntry>[];
      } else {
        yield await _loadAssignedWaitlistEntries(maxRows: maxRows);
      }
    }
  }

  Future<WaitlistSchemaCapabilities> getCapabilities() async {
    final schema = await _resolveSchema();
    return WaitlistSchemaCapabilities(
      usesLegacyStageField: schema.usesLegacyStageField,
      supportsPersistentOrdering: schema.supportsPersistentOrdering,
    );
  }

  Future<void> addPatientToWaitlist(String patientId, {int stageId = 1}) async {
    final normalizedId = patientId.trim();
    if (normalizedId.isEmpty) return;

    final schema = await _resolveSchema();
    final entries = await _loadWaitlistEntries();
    final current = _findEntry(entries, normalizedId);
    if (current?.stageId == stageId) {
      return;
    }
    if (current?.stageId != null) {
      await movePatientToStage(normalizedId, stageId);
      return;
    }

    if (!schema.supportsPersistentOrdering) {
      await _updatePatientWaitlist(
        normalizedId,
        schema: schema,
        stageId: stageId,
        order: null,
      );
      _notifyRefresh();
      return;
    }

    final stageEntries =
        entries.where((entry) => entry.stageId == stageId).toList();
    await _applyOrderPatches(
      compactWaitlistStage(stageEntries),
      schema: schema,
    );
    await _updatePatientWaitlist(
      normalizedId,
      schema: schema,
      stageId: stageId,
      order: nextWaitlistOrder(stageEntries),
    );
    _notifyRefresh();
  }

  Future<void> movePatientToStage(String patientId, int stageId) async {
    final normalizedId = patientId.trim();
    if (normalizedId.isEmpty) return;

    final schema = await _resolveSchema();
    final entries = await _loadWaitlistEntries();
    final current = _findEntry(entries, normalizedId);
    if (current == null) {
      await addPatientToWaitlist(normalizedId, stageId: stageId);
      return;
    }
    if (current.stageId == stageId) {
      return;
    }

    if (!schema.supportsPersistentOrdering) {
      await _updatePatientWaitlist(
        normalizedId,
        schema: schema,
        stageId: stageId,
        order: null,
      );
      _notifyRefresh();
      return;
    }

    final sourceStageId = current.stageId;
    if (sourceStageId != null) {
      final sourceEntries =
          entries
              .where(
                (entry) =>
                    entry.stageId == sourceStageId && entry.id != normalizedId,
              )
              .toList();
      await _updatePatientWaitlist(
        normalizedId,
        schema: schema,
        stageId: null,
        order: null,
      );
      await _applyOrderPatches(
        compactWaitlistStage(sourceEntries),
        schema: schema,
      );
    }

    final targetEntries =
        entries
            .where(
              (entry) => entry.stageId == stageId && entry.id != normalizedId,
            )
            .toList();
    await _applyOrderPatches(
      compactWaitlistStage(targetEntries),
      schema: schema,
    );
    await _updatePatientWaitlist(
      normalizedId,
      schema: schema,
      stageId: stageId,
      order: nextWaitlistOrder(targetEntries),
    );
    _notifyRefresh();
  }

  Future<void> movePatientUp(String patientId) async {
    await _movePatient(patientId, -1);
  }

  Future<void> movePatientDown(String patientId) async {
    await _movePatient(patientId, 1);
  }

  Future<void> removeFromWaitlist(String patientId) async {
    final normalizedId = patientId.trim();
    if (normalizedId.isEmpty) return;

    final schema = await _resolveSchema();
    final entries = await _loadWaitlistEntries();
    final current = _findEntry(entries, normalizedId);
    if (current?.stageId == null) return;

    if (!schema.supportsPersistentOrdering) {
      await _updatePatientWaitlist(
        normalizedId,
        schema: schema,
        stageId: null,
        order: null,
      );
      _notifyRefresh();
      return;
    }

    final stageEntries =
        entries
            .where(
              (entry) =>
                  entry.stageId == current!.stageId && entry.id != normalizedId,
            )
            .toList();

    await _updatePatientWaitlist(
      normalizedId,
      schema: schema,
      stageId: null,
      order: null,
    );
    await _applyOrderPatches(
      compactWaitlistStage(stageEntries),
      schema: schema,
    );
    _notifyRefresh();
  }

  Future<void> _movePatient(String patientId, int delta) async {
    final normalizedId = patientId.trim();
    if (normalizedId.isEmpty) return;

    final schema = await _resolveSchema();
    if (!schema.supportsPersistentOrdering) {
      throw UnsupportedError(
        'Queue reordering requires the waitlist migration in Supabase.',
      );
    }

    final entries = await _loadWaitlistEntries();
    final current = _findEntry(entries, normalizedId);
    if (current?.stageId == null) return;

    final stageEntries =
        entries.where((entry) => entry.stageId == current!.stageId).toList();
    final patches = buildWaitlistMovePatches(stageEntries, normalizedId, delta);
    await _applyOrderPatches(patches, schema: schema);
    _notifyRefresh();
  }

  Future<List<WaitlistEntry>> _loadWaitlistEntries() async {
    if (maybeSupabaseClient == null) {
      throw StateError('Supabase is not initialized');
    }

    final schema = await _resolveSchema();
    final rows = await _loadWaitlistRows(schema);
    return rows.map(waitlistEntryFromRow).toList();
  }

  WaitlistEntry? _findEntry(List<WaitlistEntry> entries, String patientId) {
    for (final entry in entries) {
      if (entry.id == patientId) return entry;
    }
    return null;
  }

  Future<void> _applyOrderPatches(
    List<WaitlistOrderPatch> patches, {
    required _WaitlistSchema schema,
  }) async {
    if (patches.isEmpty || !schema.supportsPersistentOrdering) return;
    if (maybeSupabaseClient == null) {
      throw StateError('Supabase is not initialized');
    }

    for (final patch in patches) {
      await supabaseClient
          .from(patientsTable)
          .update({schema.orderField!: patch.order})
          .eq('id', patch.patientId);
    }
  }

  Future<void> _updatePatientWaitlist(
    String patientId, {
    required _WaitlistSchema schema,
    required int? stageId,
    required int? order,
  }) async {
    if (maybeSupabaseClient == null) {
      throw StateError('Supabase is not initialized');
    }

    final payload = <String, dynamic>{schema.stageField: stageId};
    if (schema.orderField != null) {
      payload[schema.orderField!] = order;
    }

    await supabaseClient
        .from(patientsTable)
        .update(payload)
        .eq('id', patientId);
  }

  Future<_WaitlistSchema> _resolveSchema() async {
    final cached = _schemaFuture;
    if (cached != null) {
      return cached;
    }

    final future = _detectSchema();
    _schemaFuture = future;
    try {
      return await future;
    } catch (_) {
      if (identical(_schemaFuture, future)) {
        _schemaFuture = null;
      }
      rethrow;
    }
  }

  Future<_WaitlistSchema> _detectSchema() async {
    final hasWaitlistStage = await _columnExists(stageField);
    if (hasWaitlistStage) {
      final hasWaitlistOrder = await _columnExists(orderField);
      return _WaitlistSchema(
        stageField: stageField,
        orderField: hasWaitlistOrder ? orderField : null,
      );
    }

    final hasLegacyStage = await _columnExists(legacyStageField);
    if (hasLegacyStage) {
      return const _WaitlistSchema(stageField: legacyStageField);
    }

    throw StateError(
      'Patients table is missing waitlist columns. Apply the waitlist migration.',
    );
  }

  Future<bool> _columnExists(String columnName) async {
    if (maybeSupabaseClient == null) {
      throw StateError('Supabase is not initialized');
    }

    try {
      await supabaseClient.from(patientsTable).select(columnName).limit(1);
      return true;
    } catch (error) {
      if (_isMissingColumnError(error, columnName)) {
        return false;
      }
      rethrow;
    }
  }

  Future<WaitlistAssignment> _loadPatientWaitlist(String patientId) async {
    final schema = await _resolveSchema();
    final selectColumns = <String>[
      'id',
      schema.stageField,
      if (schema.orderField != null) schema.orderField!,
    ].join(',');

    final response =
        await supabaseClient
            .from(patientsTable)
            .select(selectColumns)
            .eq('id', patientId)
            .maybeSingle();
    if (response == null) {
      return const WaitlistAssignment();
    }
    return waitlistAssignmentFromData(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<List<WaitlistEntry>> _loadAssignedWaitlistEntries({
    required int maxRows,
  }) async {
    final entries =
        (await _loadWaitlistEntries())
            .where((entry) => entry.stageId != null)
            .toList()
          ..sort(compareWaitlistEntries);

    if (entries.length > maxRows) {
      return entries.sublist(0, maxRows);
    }
    return entries;
  }

  Future<List<Map<String, dynamic>>> _loadWaitlistRows(
    _WaitlistSchema schema,
  ) async {
    const pageSize = 1000;
    final selectColumns = <String>[
      'id',
      'name',
      'surname',
      'phone',
      'city',
      'payments',
      schema.stageField,
      if (schema.orderField != null) schema.orderField!,
    ].join(',');
    final rows = <Map<String, dynamic>>[];

    for (var start = 0; true; start += pageSize) {
      final response = await supabaseClient
          .from(patientsTable)
          .select(selectColumns)
          .range(start, start + pageSize - 1);
      final batch =
          (response as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
      rows.addAll(batch);
      if (batch.length < pageSize) {
        break;
      }
    }

    return rows;
  }

  Stream<void> _watchRefreshSignals() async* {
    while (true) {
      await Future.any<void>([
        _refreshController.stream.first,
        Future<void>.delayed(const Duration(seconds: 30)),
      ]);
      yield null;
    }
  }

  void _notifyRefresh() {
    if (!_refreshController.isClosed) {
      _refreshController.add(null);
    }
  }
}

int? _parseNullableInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

bool _isMissingColumnError(Object error, String columnName) {
  if (error is PostgrestException) {
    if (error.code == '42703') {
      return true;
    }
    final message =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return message.contains('does not exist') &&
        message.contains(columnName.toLowerCase());
  }

  final message = error.toString().toLowerCase();
  return message.contains('does not exist') &&
      message.contains(columnName.toLowerCase());
}

class _WaitlistSchema {
  final String stageField;
  final String? orderField;

  const _WaitlistSchema({required this.stageField, this.orderField});

  bool get usesLegacyStageField =>
      stageField == WaitlistService.legacyStageField;
  bool get supportsPersistentOrdering => orderField != null;
}
