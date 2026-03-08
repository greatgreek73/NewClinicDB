import 'dart:convert';

import 'package:aura_pricing_app/pages/search_page.dart';
import 'package:aura_pricing_app/services/recent_patient_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Search page shows recent patients when query is empty', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      RecentPatientSearchService.storageKey: <String>[
        jsonEncode({
          'id': 'patient-1',
          'title': 'Alice Adams',
          'subtitle': '+1 555 0100 • Boston',
        }),
      ],
    });

    await tester.pumpWidget(const MaterialApp(home: SearchPage()));
    await tester.pumpAndSettle();

    expect(find.text('Recent patients'), findsOneWidget);
    expect(find.text('Alice Adams'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
  });

  testWidgets('Search page clears recent patients history', (tester) async {
    SharedPreferences.setMockInitialValues({
      RecentPatientSearchService.storageKey: <String>[
        jsonEncode({
          'id': 'patient-1',
          'title': 'Alice Adams',
          'subtitle': '+1 555 0100 • Boston',
        }),
      ],
    });

    await tester.pumpWidget(const MaterialApp(home: SearchPage()));
    await tester.pumpAndSettle();

    expect(find.text('Recent patients'), findsOneWidget);
    expect(find.text('Alice Adams'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Recent patients'), findsNothing);
    expect(find.text('Alice Adams'), findsNothing);
    expect(find.text('Suggested filters'), findsOneWidget);
  });
}
