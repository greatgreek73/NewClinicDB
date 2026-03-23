import 'package:flutter/foundation.dart';

import 'supabase_client.dart';

@immutable
class PatientCityStat {
  final String city;
  final int patientCount;

  const PatientCityStat({required this.city, required this.patientCount});
}

@immutable
class PatientCityStatsSnapshot {
  final int totalPatients;
  final int patientsWithCity;
  final int patientsWithoutCity;
  final List<PatientCityStat> cityStats;

  const PatientCityStatsSnapshot({
    required this.totalPatients,
    required this.patientsWithCity,
    required this.patientsWithoutCity,
    required this.cityStats,
  });

  int get uniqueCities => cityStats.length;
}

class PatientCityStatsService {
  static const _pageSize = 1000;

  Future<PatientCityStatsSnapshot> loadCityStats() async {
    final client = maybeSupabaseClient;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }

    final rows = <Map<String, dynamic>>[];
    for (var start = 0; true; start += _pageSize) {
      final batch = await client
          .from('patients')
          .select('city')
          .range(start, start + _pageSize - 1);
      final batchRows =
          (batch as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
      rows.addAll(batchRows);
      if (batchRows.length < _pageSize) {
        break;
      }
    }

    return buildPatientCityStatsSnapshot(rows);
  }
}

PatientCityStatsSnapshot buildPatientCityStatsSnapshot(
  List<Map<String, dynamic>> rows,
) {
  var patientsWithoutCity = 0;
  final cityBuckets = <String, _CityBucket>{};

  for (final row in rows) {
    final normalizedCity = normalizePatientCity(row['city']);
    if (normalizedCity == null) {
      patientsWithoutCity += 1;
      continue;
    }

    final key = normalizedCity.toLowerCase();
    final existing = cityBuckets[key];
    if (existing == null) {
      cityBuckets[key] = _CityBucket(
        displayCity: normalizedCity,
        patientCount: 1,
      );
      continue;
    }

    cityBuckets[key] = _CityBucket(
      displayCity: existing.displayCity,
      patientCount: existing.patientCount + 1,
    );
  }

  final cityStats =
      cityBuckets.values
          .map(
            (bucket) => PatientCityStat(
              city: bucket.displayCity,
              patientCount: bucket.patientCount,
            ),
          )
          .toList()
        ..sort((left, right) {
          final countCompare = right.patientCount.compareTo(left.patientCount);
          if (countCompare != 0) {
            return countCompare;
          }
          return left.city.toLowerCase().compareTo(right.city.toLowerCase());
        });

  return PatientCityStatsSnapshot(
    totalPatients: rows.length,
    patientsWithCity: rows.length - patientsWithoutCity,
    patientsWithoutCity: patientsWithoutCity,
    cityStats: cityStats,
  );
}

String? normalizePatientCity(dynamic rawCity) {
  final value = rawCity?.toString().trim() ?? '';
  if (value.isEmpty) {
    return null;
  }

  return value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).join(' ');
}

@immutable
class _CityBucket {
  final String displayCity;
  final int patientCount;

  const _CityBucket({required this.displayCity, required this.patientCount});
}
