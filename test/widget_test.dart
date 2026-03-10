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
  });
}
