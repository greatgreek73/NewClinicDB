import 'package:aura_pricing_app/models/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appointment draft validates required fields and time order', () {
    expect(
      () =>
          AppointmentDraft(
            patientId: '',
            startAt: DateTime(2026, 3, 20, 10),
            endAt: DateTime(2026, 3, 20, 11),
            visitLabel: 'Consultation',
          ).validate(),
      throwsStateError,
    );

    expect(
      () =>
          AppointmentDraft(
            patientId: 'patient-1',
            startAt: DateTime(2026, 3, 20, 10),
            endAt: DateTime(2026, 3, 20, 9, 30),
            visitLabel: 'Consultation',
            roomLabel: AppointmentRoomOption.orthopedic.label,
          ).validate(),
      throwsStateError,
    );

    expect(
      () =>
          AppointmentDraft(
            patientId: 'patient-1',
            startAt: DateTime(2026, 3, 20, 10),
            endAt: DateTime(2026, 3, 20, 11),
            visitLabel: '',
          ).validate(),
      throwsStateError,
    );

    final draft = AppointmentDraft(
      patientId: 'patient-1',
      startAt: DateTime(2026, 3, 20, 10),
      endAt: DateTime(2026, 3, 20, 11),
      visitLabel: 'Consultation',
      roomLabel: AppointmentRoomOption.surgical.label,
      notes: 'VIP',
    );

    final payload = draft.toPayload();
    expect(payload['patient_id'], 'patient-1');
    expect(payload['visit_label'], 'Consultation');
    expect(payload['room_label'], AppointmentRoomOption.surgical.label);
    expect(payload['notes'], 'VIP');
  });

  test('appointment draft allows empty visit label', () {
    final draft = AppointmentDraft(
      patientId: 'patient-1',
      startAt: DateTime(2026, 3, 20, 10),
      endAt: DateTime(2026, 3, 20, 11),
      visitLabel: '',
      roomLabel: AppointmentRoomOption.orthopedic.label,
    );

    expect(() => draft.validate(), returnsNormally);
    expect(draft.toPayload()['visit_label'], '');
  });

  test('appointment day window preserves selected local day', () {
    final window = appointmentDayWindowForLocalDate(DateTime(2026, 3, 20, 15));

    expect(window.endUtc.difference(window.startUtc), const Duration(days: 1));
    expect(window.startUtc.toLocal().year, 2026);
    expect(window.startUtc.toLocal().month, 3);
    expect(window.startUtc.toLocal().day, 20);
    expect(window.endUtc.toLocal().day, 21);
  });

  test('appointments for local date filter and sort by start time', () {
    final appointments = [
      _appointment(
        id: 'late',
        startAt: DateTime(2026, 3, 20, 14).toUtc(),
        endAt: DateTime(2026, 3, 20, 15).toUtc(),
      ),
      _appointment(
        id: 'other-day',
        startAt: DateTime(2026, 3, 21, 9).toUtc(),
        endAt: DateTime(2026, 3, 21, 10).toUtc(),
      ),
      _appointment(
        id: 'early',
        startAt: DateTime(2026, 3, 20, 9).toUtc(),
        endAt: DateTime(2026, 3, 20, 9, 30).toUtc(),
      ),
    ];

    final visible = appointmentsForLocalDate(
      appointments,
      DateTime(2026, 3, 20, 12),
    );

    expect(visible.map((appointment) => appointment.id), ['early', 'late']);
  });

  test('delete policy allows only future scheduled appointments', () {
    final now = DateTime(2026, 3, 20, 10).toUtc();

    expect(
      canDeleteFutureAppointment(
        _appointment(
          id: 'future',
          startAt: DateTime(2026, 3, 20, 12).toUtc(),
          endAt: DateTime(2026, 3, 20, 13).toUtc(),
        ),
        now: now,
      ),
      isTrue,
    );

    expect(
      canDeleteFutureAppointment(
        _appointment(
          id: 'past',
          startAt: DateTime(2026, 3, 20, 8).toUtc(),
          endAt: DateTime(2026, 3, 20, 9).toUtc(),
        ),
        now: now,
      ),
      isFalse,
    );

    expect(
      canDeleteFutureAppointment(
        _appointment(
          id: 'cancelled',
          startAt: DateTime(2026, 3, 20, 12).toUtc(),
          endAt: DateTime(2026, 3, 20, 13).toUtc(),
          status: AppointmentStatus.cancelled,
        ),
        now: now,
      ),
      isFalse,
    );
  });
}

Appointment _appointment({
  required String id,
  required DateTime startAt,
  required DateTime endAt,
  AppointmentStatus status = AppointmentStatus.scheduled,
}) {
  return Appointment(
    id: id,
    patientId: 'patient-1',
    patientName: 'Ivanov Ivan',
    patientSubtitle: '',
    startAt: startAt,
    endAt: endAt,
    visitLabel: 'Consultation',
    roomLabel: AppointmentRoomOption.surgical.label,
    notes: null,
    status: status,
    createdAt: startAt.subtract(const Duration(days: 1)),
    updatedAt: startAt.subtract(const Duration(hours: 2)),
  );
}
