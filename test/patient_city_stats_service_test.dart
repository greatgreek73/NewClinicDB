import 'package:aura_pricing_app/services/patient_city_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'buildPatientCityStatsSnapshot groups cities and counts missing data',
    () {
      final snapshot = buildPatientCityStatsSnapshot([
        {'city': 'Athens'},
        {'city': ' athens '},
        {'city': 'Patra'},
        {'city': ''},
        {'city': null},
        {'city': 'New   York'},
      ]);

      expect(snapshot.totalPatients, 6);
      expect(snapshot.patientsWithCity, 4);
      expect(snapshot.patientsWithoutCity, 2);
      expect(snapshot.uniqueCities, 3);
      expect(snapshot.cityStats[0].city, 'Athens');
      expect(snapshot.cityStats[0].patientCount, 2);
      expect(snapshot.cityStats[1].city, 'New York');
      expect(snapshot.cityStats[1].patientCount, 1);
      expect(snapshot.cityStats[2].city, 'Patra');
      expect(snapshot.cityStats[2].patientCount, 1);
    },
  );

  test('normalizePatientCity trims and collapses whitespace', () {
    expect(normalizePatientCity('  Saint   Petersburg  '), 'Saint Petersburg');
    expect(normalizePatientCity(''), isNull);
    expect(normalizePatientCity(null), isNull);
  });
}
