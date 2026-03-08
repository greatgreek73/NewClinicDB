import 'package:aura_pricing_app/services/recent_patient_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores recent patients in most-recent-first order', () async {
    final service = RecentPatientSearchService();

    await service.rememberPatient(
      const RecentPatientSearchEntry(
        id: '1',
        title: 'Alice Adams',
        subtitle: '+1 111',
      ),
    );
    await service.rememberPatient(
      const RecentPatientSearchEntry(
        id: '2',
        title: 'Bob Brown',
        subtitle: '+1 222',
      ),
    );

    final recent = await service.loadRecentPatients();

    expect(recent.map((entry) => entry.id), ['2', '1']);
  });

  test('deduplicates patients and keeps only five entries', () async {
    final service = RecentPatientSearchService();

    for (var index = 0; index < 6; index++) {
      await service.rememberPatient(
        RecentPatientSearchEntry(
          id: '$index',
          title: 'Patient $index',
          subtitle: 'Phone $index',
        ),
      );
    }

    await service.rememberPatient(
      const RecentPatientSearchEntry(
        id: '2',
        title: 'Patient 2',
        subtitle: 'Phone 2',
      ),
    );

    final recent = await service.loadRecentPatients();

    expect(recent.length, 5);
    expect(recent.first.id, '2');
    expect(recent.map((entry) => entry.id), ['2', '5', '4', '3', '1']);
  });

  test('replaceRecentPatients overwrites stored history in order', () async {
    final service = RecentPatientSearchService();

    await service.rememberPatient(
      const RecentPatientSearchEntry(
        id: 'old',
        title: 'Old Patient',
        subtitle: 'Phone old',
      ),
    );

    await service.replaceRecentPatients(const [
      RecentPatientSearchEntry(
        id: '1',
        title: 'Ильев Дмитрий',
        subtitle: '+7 111',
      ),
      RecentPatientSearchEntry(
        id: '2',
        title: 'Петров Иван',
        subtitle: '+7 222',
      ),
    ]);

    final recent = await service.loadRecentPatients();

    expect(recent.map((entry) => entry.id), ['1', '2']);
    expect(recent.map((entry) => entry.title), [
      'Ильев Дмитрий',
      'Петров Иван',
    ]);
  });
}
