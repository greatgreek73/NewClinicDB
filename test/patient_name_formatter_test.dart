import 'package:aura_pricing_app/utils/patient_name_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats patient name as surname first name without patronymic', () {
    final result = formatPatientDisplayName(
      name: 'Дмитрий Дмитриевич',
      surname: 'Ильев',
    );

    expect(result, 'Ильев Дмитрий');
  });

  test('falls back gracefully when one of the parts is missing', () {
    expect(
      formatPatientDisplayName(name: 'Ольга Васильевна', surname: ''),
      'Ольга',
    );
    expect(formatPatientDisplayName(name: '', surname: 'Ильев'), 'Ильев');
  });
}
