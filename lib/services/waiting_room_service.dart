import '../models/waiting_room.dart';
import 'id_generator.dart';
import 'patient_lookup_service.dart';
import 'supabase_client.dart';
import 'waiting_room_reason_service.dart';
import 'waiting_room_storage_error.dart';

class WaitingRoomService {
  static const entriesTable = 'waiting_room_entries';

  const WaitingRoomService({
    WaitingRoomReasonService? reasonService,
    PatientLookupService? patientLookupService,
  }) : _reasonService = reasonService,
       _patientLookupService = patientLookupService;

  final WaitingRoomReasonService? _reasonService;
  final PatientLookupService? _patientLookupService;

  WaitingRoomReasonService get _resolvedReasonService =>
      _reasonService ?? const WaitingRoomReasonService();

  PatientLookupService get _resolvedPatientLookupService =>
      _patientLookupService ?? const PatientLookupService();

  Stream<List<WaitingRoomEntry>> watchTodayEntries() {
    final client = maybeSupabaseClient;
    if (client == null) {
      return Stream.value(const <WaitingRoomEntry>[]);
    }

    return client.from(entriesTable).stream(primaryKey: ['id']).map((rows) {
      final allEntries =
          rows
              .map(
                (row) =>
                    WaitingRoomEntry.fromRow(Map<String, dynamic>.from(row)),
              )
              .toList();
      final todayEntries = waitingRoomEntriesForDate(
        allEntries,
        waitingRoomEntryDateFor(DateTime.now()),
      );
      return sortWaitingRoomEntriesDescending(todayEntries);
    });
  }

  Future<void> createEntry(CreateWaitingRoomEntryDraft draft) async {
    try {
      draft.validate();

      final client = maybeSupabaseClient;
      if (client == null) {
        throw StateError('Supabase is not initialized');
      }

      final reason = await _resolvedReasonService.loadReason(draft.reasonId);
      if (reason == null || !reason.isActive) {
        throw StateError('Selected reason is not available.');
      }

      final now = DateTime.now();
      final displayName = await _resolveDisplayName(draft);
      final manualSurname =
          draft.manualSurname?.trim().isEmpty == true
              ? null
              : draft.manualSurname?.trim();

      await client.from(entriesTable).insert({
        'id': generateTextId('waiting_entry'),
        'entry_date': waitingRoomEntryDateFor(now),
        'created_at': now.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
        'lane': draft.lane.value,
        'source_type':
            draft.isPatientSource
                ? WaitingRoomEntrySourceType.patient.value
                : WaitingRoomEntrySourceType.manual.value,
        'patient_id': draft.patientId?.trim(),
        'display_name': displayName,
        'manual_surname': manualSurname,
        'reason_id': reason.id,
        'reason_label_snapshot': reason.label,
      });
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError(describeWaitingRoomStorageError(error));
    }
  }

  Future<void> updateEntry(
    String entryId,
    UpdateWaitingRoomEntryDraft draft,
  ) async {
    try {
      draft.validate();

      final client = maybeSupabaseClient;
      final normalizedId = entryId.trim();
      if (client == null) {
        throw StateError('Supabase is not initialized');
      }
      if (normalizedId.isEmpty) {
        throw StateError('Waiting room entry id is required.');
      }

      final reason = await _resolvedReasonService.loadReason(draft.reasonId);
      if (reason == null || !reason.isActive) {
        throw StateError('Selected reason is not available.');
      }

      await client
          .from(entriesTable)
          .update({
            'lane': draft.lane.value,
            'reason_id': reason.id,
            'reason_label_snapshot': reason.label,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', normalizedId);
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError(describeWaitingRoomStorageError(error));
    }
  }

  Future<void> deleteEntry(String entryId) async {
    try {
      final client = maybeSupabaseClient;
      final normalizedId = entryId.trim();
      if (client == null) {
        throw StateError('Supabase is not initialized');
      }
      if (normalizedId.isEmpty) {
        throw StateError('Waiting room entry id is required.');
      }

      await client.from(entriesTable).delete().eq('id', normalizedId);
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError(describeWaitingRoomStorageError(error));
    }
  }

  Future<String> _resolveDisplayName(CreateWaitingRoomEntryDraft draft) async {
    if (draft.isManualSource) {
      final surname = draft.manualSurname?.trim() ?? '';
      if (surname.isEmpty) {
        throw StateError('Manual waiting room entry requires a surname.');
      }
      return surname;
    }

    final patientId = draft.patientId?.trim() ?? '';
    final patient = await _resolvedPatientLookupService.loadById(patientId);
    if (patient == null) {
      throw StateError('Could not load patient card for waiting room entry.');
    }
    return patient.title;
  }
}
