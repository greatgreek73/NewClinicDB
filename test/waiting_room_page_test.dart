import 'dart:async';

import 'package:aura_pricing_app/models/waiting_room.dart';
import 'package:aura_pricing_app/pages/waiting_room_page.dart';
import 'package:aura_pricing_app/pages/waiting_room_reason_settings_page.dart';
import 'package:aura_pricing_app/services/patient_lookup_service.dart';
import 'package:aura_pricing_app/services/waiting_room_reason_service.dart';
import 'package:aura_pricing_app/services/waiting_room_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('waiting room renders both columns and current entries', (
    tester,
  ) async {
    _setLargeTestSurface(tester);
    final reasonService = FakeWaitingRoomReasonService(
      initialReasons: [_reason('reason-1', 'Консультация')],
    );
    final waitingRoomService = FakeWaitingRoomService(
      reasonService: reasonService,
      patientLookupService: FakePatientLookupService(const []),
      initialEntries: [
        _entry(
          id: 'entry-1',
          lane: WaitingRoomLane.scheduled,
          displayName: 'Ivanov Ivan',
        ),
        _entry(
          id: 'entry-2',
          lane: WaitingRoomLane.unscheduled,
          displayName: 'Petrov Petr',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WaitingRoomPage(
          waitingRoomService: waitingRoomService,
          reasonService: reasonService,
          patientLookupService: FakePatientLookupService(const []),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Live Patient Arrival Board'), findsOneWidget);
    expect(find.text('Waiting now'), findsOneWidget);
    expect(find.text('Average wait today'), findsOneWidget);
    expect(find.text('Max wait now'), findsOneWidget);
    expect(find.text('Ivanov'), findsOneWidget);
    expect(find.text('By appointment'), findsOneWidget);
    expect(find.text('Walk-In'), findsOneWidget);
    expect(find.text('Ivanov Ivan'), findsOneWidget);
    expect(find.text('Petrov Petr'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('By appointment')).dx,
      lessThan(tester.getTopLeft(find.text('Walk-In')).dx),
    );
  });

  testWidgets('manual add creates a temporary waiting room entry', (
    tester,
  ) async {
    _setLargeTestSurface(tester);
    final reasonService = FakeWaitingRoomReasonService(
      initialReasons: [_reason('reason-1', 'Консультация')],
    );
    final patientLookupService = FakePatientLookupService(const []);
    final waitingRoomService = FakeWaitingRoomService(
      reasonService: reasonService,
      patientLookupService: patientLookupService,
      initialEntries: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WaitingRoomPage(
          waitingRoomService: waitingRoomService,
          reasonService: reasonService,
          patientLookupService: patientLookupService,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Add patient'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual surname'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ivanov');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    expect(waitingRoomService.lastCreateDraft?.manualSurname, 'Ivanov');
    expect(find.text('Ivanov'), findsWidgets);
  });

  testWidgets('selecting a searched patient hides the search results list', (
    tester,
  ) async {
    _setLargeTestSurface(tester);
    final reasonService = FakeWaitingRoomReasonService(
      initialReasons: [_reason('reason-1', 'Консультация')],
    );
    final patientLookupService = FakePatientLookupService([
      _patient('patient-1', 'Ivanov Ivan'),
    ]);
    final waitingRoomService = FakeWaitingRoomService(
      reasonService: reasonService,
      patientLookupService: patientLookupService,
      initialEntries: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WaitingRoomPage(
          waitingRoomService: waitingRoomService,
          reasonService: reasonService,
          patientLookupService: patientLookupService,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Add patient'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ivan');
    await tester.pumpAndSettle();

    expect(find.text('Patient record'), findsOneWidget);

    await tester.tap(find.text('Ivanov Ivan').last);
    await tester.pumpAndSettle();

    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Patient record'), findsNothing);
    expect(find.text('Ivanov Ivan'), findsOneWidget);
  });

  testWidgets('editing an entry updates its lane and reason', (tester) async {
    _setLargeTestSurface(tester);
    final reasonService = FakeWaitingRoomReasonService(
      initialReasons: [
        _reason('reason-1', 'Консультация'),
        _reason('reason-2', 'швы'),
      ],
    );
    final waitingRoomService = FakeWaitingRoomService(
      reasonService: reasonService,
      patientLookupService: FakePatientLookupService(const []),
      initialEntries: [
        _entry(
          id: 'entry-1',
          lane: WaitingRoomLane.scheduled,
          displayName: 'Ivanov Ivan',
          reasonId: 'reason-1',
          reasonLabelSnapshot: 'Консультация',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WaitingRoomPage(
          waitingRoomService: waitingRoomService,
          reasonService: reasonService,
          patientLookupService: FakePatientLookupService(const []),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byIcon(Icons.more_vert_rounded).first);
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ChoiceChip).last);
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('швы').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      waitingRoomService.lastUpdateDraft?.lane,
      WaitingRoomLane.unscheduled,
    );
    expect(waitingRoomService.lastUpdateDraft?.reasonId, 'reason-2');
    expect(find.textContaining('швы'), findsOneWidget);
  });

  testWidgets('removing an entry deletes it from the list', (tester) async {
    _setLargeTestSurface(tester);
    final reasonService = FakeWaitingRoomReasonService(
      initialReasons: [_reason('reason-1', 'Консультация')],
    );
    final waitingRoomService = FakeWaitingRoomService(
      reasonService: reasonService,
      patientLookupService: FakePatientLookupService(const []),
      initialEntries: [
        _entry(
          id: 'entry-1',
          lane: WaitingRoomLane.scheduled,
          displayName: 'Ivanov Ivan',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WaitingRoomPage(
          waitingRoomService: waitingRoomService,
          reasonService: reasonService,
          patientLookupService: FakePatientLookupService(const []),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byIcon(Icons.more_vert_rounded).first);
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    expect(waitingRoomService.deletedEntryId, 'entry-1');
    expect(find.text('Ivanov Ivan'), findsNothing);
  });

  testWidgets('empty reasons block creation and allow opening settings', (
    tester,
  ) async {
    _setLargeTestSurface(tester);
    final reasonService = FakeWaitingRoomReasonService(
      initialReasons: const [],
    );
    final waitingRoomService = FakeWaitingRoomService(
      reasonService: reasonService,
      patientLookupService: FakePatientLookupService(const []),
      initialEntries: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WaitingRoomPage(
          waitingRoomService: waitingRoomService,
          reasonService: reasonService,
          patientLookupService: FakePatientLookupService(const []),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No active visit reasons'), findsOneWidget);
    await tester.tap(find.text('Manage reasons').first);
    await tester.pumpAndSettle();

    expect(find.text('Visit reasons'), findsOneWidget);
  });

  testWidgets('reason settings can add, rename, and deactivate reasons', (
    tester,
  ) async {
    _setLargeTestSurface(tester);
    final reasonService = FakeWaitingRoomReasonService(
      initialReasons: [_reason('reason-1', 'Консультация')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WaitingRoomReasonSettingsPage(reasonService: reasonService),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Add reason'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'осмотр');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('осмотр'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Консультация VIP');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Консультация VIP'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.block_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate').last);
    await tester.pumpAndSettle();

    expect(find.text('Inactive reasons'), findsOneWidget);
    expect(
      reasonService.currentReasons.where((reason) => reason.isActive),
      hasLength(1),
    );
  });
}

class FakeWaitingRoomService extends WaitingRoomService {
  final FakeWaitingRoomReasonService reasonService;
  final FakePatientLookupService patientLookupService;
  final StreamController<List<WaitingRoomEntry>> _controller =
      StreamController<List<WaitingRoomEntry>>.broadcast();
  final DateTime now;
  final List<WaitingRoomEntry> _entries;

  CreateWaitingRoomEntryDraft? lastCreateDraft;
  UpdateWaitingRoomEntryDraft? lastUpdateDraft;
  String? deletedEntryId;

  FakeWaitingRoomService({
    required this.reasonService,
    required this.patientLookupService,
    required List<WaitingRoomEntry> initialEntries,
    DateTime? now,
  }) : now = now ?? DateTime.parse('2026-03-16T09:00:00Z'),
       _entries = List<WaitingRoomEntry>.from(initialEntries),
       super(
         reasonService: reasonService,
         patientLookupService: patientLookupService,
       ) {
    _emit();
  }

  @override
  Stream<List<WaitingRoomEntry>> watchTodayEntries() async* {
    yield List<WaitingRoomEntry>.unmodifiable(_entries);
    yield* _controller.stream;
  }

  @override
  Future<void> createEntry(CreateWaitingRoomEntryDraft draft) async {
    lastCreateDraft = draft;
    final reason = await reasonService.loadReason(draft.reasonId);
    final displayName =
        draft.patientId != null
            ? (await patientLookupService.loadById(draft.patientId!))?.title ??
                'Unknown Patient'
            : draft.manualSurname!;
    _entries.insert(
      0,
      WaitingRoomEntry(
        id: 'entry-${_entries.length + 1}',
        entryDate: waitingRoomEntryDateFor(now),
        createdAt: now,
        updatedAt: now,
        lane: draft.lane,
        sourceType:
            draft.patientId != null
                ? WaitingRoomEntrySourceType.patient
                : WaitingRoomEntrySourceType.manual,
        patientId: draft.patientId,
        displayName: displayName,
        manualSurname: draft.manualSurname,
        reasonId: draft.reasonId,
        reasonLabelSnapshot: reason?.label ?? 'Unknown reason',
      ),
    );
    _emit();
  }

  @override
  Future<void> updateEntry(
    String entryId,
    UpdateWaitingRoomEntryDraft draft,
  ) async {
    lastUpdateDraft = draft;
    final index = _entries.indexWhere((entry) => entry.id == entryId);
    final current = _entries[index];
    final reason = await reasonService.loadReason(draft.reasonId);
    _entries[index] = WaitingRoomEntry(
      id: current.id,
      entryDate: current.entryDate,
      createdAt: current.createdAt,
      updatedAt: now,
      lane: draft.lane,
      sourceType: current.sourceType,
      patientId: current.patientId,
      displayName: current.displayName,
      manualSurname: current.manualSurname,
      reasonId: draft.reasonId,
      reasonLabelSnapshot: reason?.label ?? current.reasonLabelSnapshot,
    );
    _emit();
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    deletedEntryId = entryId;
    _entries.removeWhere((entry) => entry.id == entryId);
    _emit();
  }

  void _emit() {
    _controller.add(List<WaitingRoomEntry>.unmodifiable(_entries));
  }
}

class FakeWaitingRoomReasonService extends WaitingRoomReasonService {
  final StreamController<List<WaitingRoomReason>> _controller =
      StreamController<List<WaitingRoomReason>>.broadcast();
  final List<WaitingRoomReason> _reasons;

  FakeWaitingRoomReasonService({
    required List<WaitingRoomReason> initialReasons,
  }) : _reasons = List<WaitingRoomReason>.from(initialReasons),
       super() {
    _emit();
  }

  List<WaitingRoomReason> get currentReasons =>
      List<WaitingRoomReason>.unmodifiable(_reasons);

  @override
  Stream<List<WaitingRoomReason>> watchActiveReasons() {
    return watchAllReasons().map(
      (reasons) => reasons.where((reason) => reason.isActive).toList(),
    );
  }

  @override
  Stream<List<WaitingRoomReason>> watchAllReasons() async* {
    yield List<WaitingRoomReason>.unmodifiable(_reasons);
    yield* _controller.stream;
  }

  @override
  Future<WaitingRoomReason?> loadReason(String reasonId) async {
    for (final reason in _reasons) {
      if (reason.id == reasonId) return reason;
    }
    return null;
  }

  @override
  Future<void> addReason(String label) async {
    _reasons.add(
      WaitingRoomReason(
        id: 'reason-${_reasons.length + 1}',
        label: label,
        sortOrder: _reasons.length + 1,
        isActive: true,
        createdAt: DateTime.parse('2026-03-16T09:00:00Z'),
        updatedAt: DateTime.parse('2026-03-16T09:00:00Z'),
      ),
    );
    _emit();
  }

  @override
  Future<void> renameReason(String id, String label) async {
    final index = _reasons.indexWhere((reason) => reason.id == id);
    final current = _reasons[index];
    _reasons[index] = WaitingRoomReason(
      id: current.id,
      label: label,
      sortOrder: current.sortOrder,
      isActive: current.isActive,
      createdAt: current.createdAt,
      updatedAt: DateTime.parse('2026-03-16T10:00:00Z'),
    );
    _emit();
  }

  @override
  Future<void> deactivateReason(String id) async {
    final index = _reasons.indexWhere((reason) => reason.id == id);
    final current = _reasons[index];
    _reasons[index] = WaitingRoomReason(
      id: current.id,
      label: current.label,
      sortOrder: current.sortOrder,
      isActive: false,
      createdAt: current.createdAt,
      updatedAt: DateTime.parse('2026-03-16T10:00:00Z'),
    );
    _emit();
  }

  void _emit() {
    _controller.add(List<WaitingRoomReason>.unmodifiable(_reasons));
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

WaitingRoomReason _reason(String id, String label) {
  return WaitingRoomReason(
    id: id,
    label: label,
    sortOrder: 1,
    isActive: true,
    createdAt: DateTime.parse('2026-03-16T09:00:00Z'),
    updatedAt: DateTime.parse('2026-03-16T09:00:00Z'),
  );
}

WaitingRoomEntry _entry({
  required String id,
  required WaitingRoomLane lane,
  required String displayName,
  String reasonId = 'reason-1',
  String reasonLabelSnapshot = 'Консультация',
}) {
  return WaitingRoomEntry(
    id: id,
    entryDate: '2026-03-16',
    createdAt: DateTime.parse('2026-03-16T09:00:00Z'),
    updatedAt: DateTime.parse('2026-03-16T09:00:00Z'),
    lane: lane,
    sourceType: WaitingRoomEntrySourceType.manual,
    patientId: null,
    displayName: displayName,
    manualSurname: displayName,
    reasonId: reasonId,
    reasonLabelSnapshot: reasonLabelSnapshot,
  );
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
