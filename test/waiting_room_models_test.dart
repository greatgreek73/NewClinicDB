import 'package:aura_pricing_app/models/waiting_room.dart';
import 'package:aura_pricing_app/services/waiting_room_storage_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('WaitingRoomReason and WaitingRoomEntry map from rows', () {
    final reason = WaitingRoomReason.fromRow({
      'id': 'reason-1',
      'label': 'Consultation',
      'sort_order': 3,
      'is_active': true,
      'created_at': '2026-03-16T09:00:00Z',
      'updated_at': '2026-03-16T09:15:00Z',
    });
    final entry = WaitingRoomEntry.fromRow({
      'id': 'entry-1',
      'entry_date': '2026-03-16',
      'created_at': '2026-03-16T09:00:00Z',
      'updated_at': '2026-03-16T09:15:00Z',
      'lane': 'scheduled',
      'source_type': 'patient',
      'patient_id': 'patient-1',
      'display_name': 'Ivanov Ivan',
      'manual_surname': null,
      'reason_id': 'reason-1',
      'reason_label_snapshot': 'Consultation',
    });

    expect(reason.label, 'Consultation');
    expect(reason.sortOrder, 3);
    expect(entry.displayName, 'Ivanov Ivan');
    expect(entry.lane, WaitingRoomLane.scheduled);
    expect(entry.sourceType, WaitingRoomEntrySourceType.patient);
  });

  test('waiting room filters by entry date and sorts newest first', () {
    final entries = [
      WaitingRoomEntry(
        id: 'entry-1',
        entryDate: '2026-03-16',
        createdAt: DateTime.parse('2026-03-16T08:00:00Z'),
        updatedAt: DateTime.parse('2026-03-16T08:00:00Z'),
        lane: WaitingRoomLane.scheduled,
        sourceType: WaitingRoomEntrySourceType.manual,
        patientId: null,
        displayName: 'Older',
        manualSurname: 'Older',
        reasonId: 'reason-1',
        reasonLabelSnapshot: 'Consultation',
      ),
      WaitingRoomEntry(
        id: 'entry-2',
        entryDate: '2026-03-16',
        createdAt: DateTime.parse('2026-03-16T10:00:00Z'),
        updatedAt: DateTime.parse('2026-03-16T10:00:00Z'),
        lane: WaitingRoomLane.unscheduled,
        sourceType: WaitingRoomEntrySourceType.manual,
        patientId: null,
        displayName: 'Newer',
        manualSurname: 'Newer',
        reasonId: 'reason-1',
        reasonLabelSnapshot: 'Consultation',
      ),
      WaitingRoomEntry(
        id: 'entry-3',
        entryDate: '2026-03-15',
        createdAt: DateTime.parse('2026-03-15T10:00:00Z'),
        updatedAt: DateTime.parse('2026-03-15T10:00:00Z'),
        lane: WaitingRoomLane.unscheduled,
        sourceType: WaitingRoomEntrySourceType.manual,
        patientId: null,
        displayName: 'Yesterday',
        manualSurname: 'Yesterday',
        reasonId: 'reason-1',
        reasonLabelSnapshot: 'Consultation',
      ),
    ];

    final filtered = waitingRoomEntriesForDate(entries, '2026-03-16');
    final sorted = sortWaitingRoomEntriesDescending(filtered);

    expect(filtered.length, 2);
    expect(sorted.first.displayName, 'Newer');
    expect(sorted.last.displayName, 'Older');
  });

  test(
    'reason label falls back to snapshot when active reason is unavailable',
    () {
      final entry = WaitingRoomEntry(
        id: 'entry-1',
        entryDate: '2026-03-16',
        createdAt: DateTime.parse('2026-03-16T09:00:00Z'),
        updatedAt: DateTime.parse('2026-03-16T09:00:00Z'),
        lane: WaitingRoomLane.scheduled,
        sourceType: WaitingRoomEntrySourceType.manual,
        patientId: null,
        displayName: 'Ivanov',
        manualSurname: 'Ivanov',
        reasonId: 'missing',
        reasonLabelSnapshot: 'Snapshot reason',
      );

      expect(
        entry.resolveReasonLabel(const <String, WaitingRoomReason>{}),
        'Snapshot reason',
      );
    },
  );

  test('waiting room duration formatting covers minutes and hours', () {
    expect(
      formatWaitingRoomDuration(const Duration(minutes: 7, seconds: 5)),
      '07:05',
    );
    expect(
      formatWaitingRoomDuration(
        const Duration(hours: 1, minutes: 7, seconds: 5),
      ),
      '1:07:05',
    );
    expect(
      formatWaitingRoomStatDuration(const Duration(minutes: 7, seconds: 5)),
      '07:05',
    );
    expect(
      formatWaitingRoomStatDuration(
        const Duration(hours: 1, minutes: 7, seconds: 5),
      ),
      '01:07',
    );
  });

  test('waiting room average duration uses active entries', () {
    final now = DateTime.parse('2026-03-16T10:00:00Z');
    final entries = [
      WaitingRoomEntry(
        id: 'entry-1',
        entryDate: '2026-03-16',
        createdAt: DateTime.parse('2026-03-16T09:00:00Z'),
        updatedAt: DateTime.parse('2026-03-16T09:00:00Z'),
        lane: WaitingRoomLane.scheduled,
        sourceType: WaitingRoomEntrySourceType.manual,
        patientId: null,
        displayName: 'Ivanov',
        manualSurname: 'Ivanov',
        reasonId: 'reason-1',
        reasonLabelSnapshot: 'Consultation',
      ),
      WaitingRoomEntry(
        id: 'entry-2',
        entryDate: '2026-03-16',
        createdAt: DateTime.parse('2026-03-16T09:30:00Z'),
        updatedAt: DateTime.parse('2026-03-16T09:30:00Z'),
        lane: WaitingRoomLane.unscheduled,
        sourceType: WaitingRoomEntrySourceType.manual,
        patientId: null,
        displayName: 'Petrov',
        manualSurname: 'Petrov',
        reasonId: 'reason-1',
        reasonLabelSnapshot: 'Consultation',
      ),
    ];

    final average = averageWaitingRoomDuration(entries, now);

    expect(average, const Duration(minutes: 45));
    expect(formatWaitingRoomDuration(average), '45:00');
  });

  test('waiting room create and update drafts validate scenarios', () {
    expect(
      () =>
          const CreateWaitingRoomEntryDraft(
            lane: WaitingRoomLane.scheduled,
            reasonId: 'reason-1',
            patientId: 'patient-1',
          ).validate(),
      returnsNormally,
    );
    expect(
      () =>
          const CreateWaitingRoomEntryDraft(
            lane: WaitingRoomLane.unscheduled,
            reasonId: 'reason-1',
            manualSurname: 'Ivanov',
          ).validate(),
      returnsNormally,
    );
    expect(
      () =>
          const CreateWaitingRoomEntryDraft(
            lane: WaitingRoomLane.unscheduled,
            reasonId: 'reason-1',
          ).validate(),
      throwsStateError,
    );
    expect(
      () =>
          const CreateWaitingRoomEntryDraft(
            lane: WaitingRoomLane.unscheduled,
            reasonId: 'reason-1',
            patientId: 'patient-1',
            manualSurname: 'Ivanov',
          ).validate(),
      throwsStateError,
    );
    expect(
      () =>
          const UpdateWaitingRoomEntryDraft(
            lane: WaitingRoomLane.scheduled,
            reasonId: 'reason-1',
          ).validate(),
      returnsNormally,
    );
  });

  test('waiting room storage error describes missing migration clearly', () {
    const error = PostgrestException(
      message: 'Could not find the table public.waiting_room_reasons',
      code: 'PGRST205',
    );

    expect(
      describeWaitingRoomStorageError(error),
      contains('Apply migration 20260316_waiting_room_v1.sql'),
    );
  });

  test('waiting room storage error describes permission issues clearly', () {
    const error = PostgrestException(
      message: 'permission denied for table waiting_room_reasons',
      code: '42501',
    );

    expect(
      describeWaitingRoomStorageError(error),
      contains('Check table permissions or Row Level Security policies'),
    );
  });
}
