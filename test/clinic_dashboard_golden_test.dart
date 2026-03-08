import 'package:aura_pricing_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Clinic dashboard renders waiting list stages', (tester) async {
    const logicalSize = Size(1024, 1366);

    tester.binding
      ..window.physicalSizeTestValue = logicalSize
      ..window.devicePixelRatioTestValue = 1.0;

    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Waiting list'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Contact'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Deferred'), findsOneWidget);
  });
}
