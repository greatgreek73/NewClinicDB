import 'package:aura_pricing_app/pages/add_patient_page.dart';
import 'package:aura_pricing_app/pages/patient_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Patient details shows waitlist controls and payments', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute:
              (_) => MaterialPageRoute<void>(
                settings: const RouteSettings(
                  arguments: PatientDetailsArgs(
                    patientId: 'patient-1',
                    displayName: 'Test Patient',
                  ),
                ),
                builder: (_) => const PatientDetailsPage(),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Patient overview'), findsOneWidget);
    expect(find.textContaining('Not on waiting list'), findsOneWidget);
    expect(find.textContaining('Tap a stage icon above'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Add payment'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Delete patient'), findsOneWidget);
    expect(find.text('Add note'), findsOneWidget);

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.text('Edit patient profile'), findsOneWidget);
    expect(find.text('Save profile'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();

    expect(find.text('Add patient notes'), findsOneWidget);
    expect(find.text('Save notes'), findsOneWidget);
    expect(find.text('Notes'), findsWidgets);
  });

  testWidgets('Add patient page includes notes field', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddPatientPage()));
    await tester.pumpAndSettle();

    expect(find.text('Add new patient'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
  });
}
