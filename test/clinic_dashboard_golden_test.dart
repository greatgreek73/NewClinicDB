import 'package:aura_pricing_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Clinic dashboard renders correctly', (tester) async {
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

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/clinic_dashboard.png'),
    );
  });
}
