import 'package:aura_pricing_app/models/appointment.dart';
import 'package:aura_pricing_app/pages/schedule_page.dart';
import 'package:aura_pricing_app/services/appointment_service.dart';
import 'package:aura_pricing_app/services/patient_lookup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'schedule page renders appointments and supports day navigation',
    (tester) async {
      _setLargeTestSurface(tester);
      final patientLookupService = FakePatientLookupService([
        _patient('patient-1', 'Ivanov Ivan'),
        _patient('patient-2', 'Petrova Anna'),
      ]);
      final appointmentService = FakeAppointmentService(
        patientLookupService: patientLookupService,
        initialAppointments: [
          _appointment(
            id: 'today-1',
            patientId: 'patient-1',
            patientName: 'Ivanov Ivan',
            visitLabel: 'Consultation',
            startAt: _todayAt(9),
            endAt: _todayAt(10),
          ),
          _appointment(
            id: 'tomorrow-1',
            patientId: 'patient-2',
            patientName: 'Petrova Anna',
            visitLabel: 'Hygiene',
            startAt: _tomorrowAt(11),
            endAt: _tomorrowAt(12),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SchedulePage(
            appointmentService: appointmentService,
            patientLookupService: patientLookupService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Consultation'), findsOneWidget);
      expect(find.text('Hygiene'), findsNothing);

      await tester.tap(find.text('Next day'));
      await tester.pumpAndSettle();

      expect(find.text('Consultation'), findsNothing);
      expect(find.text('Hygiene'), findsOneWidget);
    },
  );

  testWidgets(
    'schedule page shows orthopedic and surgical rooms in parallel for overlapping times',
    (tester) async {
      _setLargeTestSurface(tester);
      final patientLookupService = FakePatientLookupService([
        _patient('patient-1', 'Ivanov Ivan'),
        _patient('patient-2', 'Petrova Anna'),
      ]);
      final appointmentService = FakeAppointmentService(
        patientLookupService: patientLookupService,
        initialAppointments: [
          _appointment(
            id: 'orthopedic-1',
            patientId: 'patient-1',
            patientName: 'Ivanov Ivan',
            visitLabel: 'Crown fitting',
            startAt: _todayAt(10),
            endAt: _todayAt(11),
            roomLabel: AppointmentRoomOption.orthopedic.label,
          ),
          _appointment(
            id: 'surgical-1',
            patientId: 'patient-2',
            patientName: 'Petrova Anna',
            visitLabel: 'Implant placement',
            startAt: _todayAt(10),
            endAt: _todayAt(11),
            roomLabel: AppointmentRoomOption.surgical.label,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SchedulePage(
            appointmentService: appointmentService,
            patientLookupService: patientLookupService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Orthopedic room'), findsWidgets);
      expect(find.text('Surgical room'), findsWidgets);
      expect(find.text('Crown fitting'), findsOneWidget);
      expect(find.text('Implant placement'), findsOneWidget);
      expect(find.text('Ivanov Ivan'), findsOneWidget);
      expect(find.text('Petrova Anna'), findsOneWidget);
    },
  );

  testWidgets('schedule page creates appointments through the dialog', (
    tester,
  ) async {
    _setLargeTestSurface(tester);
    final patientLookupService = FakePatientLookupService([
      _patient('patient-1', 'Ivanov Ivan'),
    ]);
    final appointmentService = FakeAppointmentService(
      patientLookupService: patientLookupService,
      initialAppointments: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SchedulePage(
          appointmentService: appointmentService,
          patientLookupService: patientLookupService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add appointment'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Ivanov');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ivanov Ivan').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Implant follow-up');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Surgical room').last);
    await tester.tap(find.text('Surgical room').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Add').last);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add').last);
    await tester.pumpAndSettle();

    expect(appointmentService.lastCreateDraft?.patientId, 'patient-1');
    expect(appointmentService.lastCreateDraft?.visitLabel, 'Implant follow-up');
    expect(
      appointmentService.lastCreateDraft?.roomLabel,
      AppointmentRoomOption.surgical.label,
    );
    expect(find.text('Implant follow-up'), findsOneWidget);
    expect(find.text('Surgical room'), findsWidgets);
  });

  testWidgets(
    'schedule page allows creating an appointment without visit label',
    (tester) async {
      _setLargeTestSurface(tester);
      final patientLookupService = FakePatientLookupService([
        _patient('patient-1', 'Ivanov Ivan'),
      ]);
      final appointmentService = FakeAppointmentService(
        patientLookupService: patientLookupService,
        initialAppointments: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SchedulePage(
            appointmentService: appointmentService,
            patientLookupService: patientLookupService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add appointment'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Ivanov');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ivanov Ivan').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Orthopedic room').last);
      await tester.tap(find.text('Orthopedic room').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Add').last,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add').last);
      await tester.pumpAndSettle();

      expect(appointmentService.lastCreateDraft?.visitLabel, '');
      expect(find.text('No visit label'), findsOneWidget);
    },
  );

  testWidgets('schedule page edits appointment fields and status', (
    tester,
  ) async {
    _setLargeTestSurface(tester);
    final patientLookupService = FakePatientLookupService([
      _patient('patient-1', 'Ivanov Ivan'),
    ]);
    final appointmentService = FakeAppointmentService(
      patientLookupService: patientLookupService,
      initialAppointments: [
        _appointment(
          id: 'future-1',
          patientId: 'patient-1',
          patientName: 'Ivanov Ivan',
          visitLabel: 'Consultation',
          startAt: _todayAt(14),
          endAt: _todayAt(15),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SchedulePage(
          appointmentService: appointmentService,
          patientLookupService: patientLookupService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Consultation'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'Consultation VIP');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Orthopedic room').last);
    await tester.tap(find.text('Orthopedic room').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancelled').last);
    await tester.tap(find.text('Cancelled').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(appointmentService.lastUpdatedId, 'future-1');
    expect(appointmentService.lastUpdateDraft?.visitLabel, 'Consultation VIP');
    expect(
      appointmentService.lastUpdateDraft?.roomLabel,
      AppointmentRoomOption.orthopedic.label,
    );
    expect(appointmentService.lastStatusId, 'future-1');
    expect(appointmentService.lastStatus, AppointmentStatus.cancelled);
    expect(find.text('Consultation VIP'), findsOneWidget);
    expect(find.text('Orthopedic room'), findsWidgets);
  });
}

class FakeAppointmentService extends AppointmentService {
  final FakePatientLookupService patientLookupService;
  final List<Appointment> _appointments;

  AppointmentDraft? lastCreateDraft;
  AppointmentDraft? lastUpdateDraft;
  String? lastUpdatedId;
  AppointmentStatus? lastStatus;
  String? lastStatusId;
  String? lastDeletedId;

  FakeAppointmentService({
    required this.patientLookupService,
    required List<Appointment> initialAppointments,
  }) : _appointments = List<Appointment>.from(initialAppointments),
       super();

  @override
  Future<List<Appointment>> listByDay(DateTime day) async {
    return appointmentsForLocalDate(_appointments, day);
  }

  @override
  Future<void> create(AppointmentDraft draft) async {
    lastCreateDraft = draft;
    final patient = await patientLookupService.loadById(draft.patientId);
    _appointments.add(
      Appointment(
        id: 'appointment-${_appointments.length + 1}',
        patientId: draft.patientId,
        patientName: patient?.title ?? 'Unknown Patient',
        patientSubtitle: patient?.subtitle ?? '',
        startAt: draft.startAt.toUtc(),
        endAt: draft.endAt.toUtc(),
        visitLabel: draft.visitLabel.trim(),
        roomLabel:
            draft.roomLabel?.trim().isEmpty == true ? null : draft.roomLabel,
        notes: draft.notes?.trim().isEmpty == true ? null : draft.notes,
        status: AppointmentStatus.scheduled,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> update(String appointmentId, AppointmentDraft draft) async {
    lastUpdatedId = appointmentId;
    lastUpdateDraft = draft;
    final index = _appointments.indexWhere(
      (appointment) => appointment.id == appointmentId,
    );
    final current = _appointments[index];
    final patient = await patientLookupService.loadById(draft.patientId);
    _appointments[index] = Appointment(
      id: current.id,
      patientId: draft.patientId,
      patientName: patient?.title ?? current.patientName,
      patientSubtitle: patient?.subtitle ?? current.patientSubtitle,
      startAt: draft.startAt.toUtc(),
      endAt: draft.endAt.toUtc(),
      visitLabel: draft.visitLabel.trim(),
      roomLabel:
          draft.roomLabel?.trim().isEmpty == true ? null : draft.roomLabel,
      notes: draft.notes?.trim().isEmpty == true ? null : draft.notes,
      status: current.status,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> setStatus(String appointmentId, AppointmentStatus status) async {
    lastStatusId = appointmentId;
    lastStatus = status;
    final index = _appointments.indexWhere(
      (appointment) => appointment.id == appointmentId,
    );
    final current = _appointments[index];
    _appointments[index] = Appointment(
      id: current.id,
      patientId: current.patientId,
      patientName: current.patientName,
      patientSubtitle: current.patientSubtitle,
      startAt: current.startAt,
      endAt: current.endAt,
      visitLabel: current.visitLabel,
      roomLabel: current.roomLabel,
      notes: current.notes,
      status: status,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> deleteFuture(Appointment appointment, {DateTime? now}) async {
    lastDeletedId = appointment.id;
    _appointments.removeWhere((current) => current.id == appointment.id);
  }
}

class FakePatientLookupService extends PatientLookupService {
  final List<PatientLookupResult> _patients;

  const FakePatientLookupService(this._patients) : super();

  @override
  Future<List<PatientLookupResult>> search(
    String query, {
    int limit = 25,
  }) async {
    final normalized = query.toLowerCase();
    return _patients
        .where(
          (patient) =>
              patient.title.toLowerCase().contains(normalized) ||
              patient.subtitle.toLowerCase().contains(normalized),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<PatientLookupResult?> loadById(String patientId) async {
    for (final patient in _patients) {
      if (patient.id == patientId) return patient;
    }
    return null;
  }
}

PatientLookupResult _patient(String id, String title) {
  return PatientLookupResult(
    id: id,
    title: title,
    subtitle: '+7 999 123-45-67 • Moscow',
    matchType: PatientLookupMatchType.record,
  );
}

Appointment _appointment({
  required String id,
  required String patientId,
  required String patientName,
  required String visitLabel,
  required DateTime startAt,
  required DateTime endAt,
  String? roomLabel,
}) {
  return Appointment(
    id: id,
    patientId: patientId,
    patientName: patientName,
    patientSubtitle: '+7 999 123-45-67 • Moscow',
    startAt: startAt,
    endAt: endAt,
    visitLabel: visitLabel,
    roomLabel: roomLabel ?? AppointmentRoomOption.surgical.label,
    notes: null,
    status: AppointmentStatus.scheduled,
    createdAt: startAt.subtract(const Duration(days: 1)),
    updatedAt: startAt.subtract(const Duration(hours: 2)),
  );
}

DateTime _todayAt(int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour).toUtc();
}

DateTime _tomorrowAt(int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1, hour).toUtc();
}

void _setLargeTestSurface(WidgetTester tester) {
  const logicalSize = Size(1200, 1600);

  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
