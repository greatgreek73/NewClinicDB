import 'package:aura_pricing_app/models/tooth_condition.dart';
import 'package:aura_pricing_app/services/dental_chart_repository.dart';
import 'package:aura_pricing_app/services/treatment_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTreatmentDataService extends TreatmentDataService {
  _FakeTreatmentDataService(this.rows);

  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> fetchByPatient(
    String patientId, {
    int limit = 2000,
  }) async {
    return rows
        .take(limit)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchByPatient(
    String patientId, {
    int maxRows = 2000,
  }) {
    final data =
        rows
            .take(maxRows)
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
    return Stream.value(data);
  }
}

void main() {
  test(
    'legacy treatments without status are shown as treated in chart plan',
    () async {
      final repository = DentalChartRepository(
        treatments: _FakeTreatmentDataService([
          {
            'id': 'legacy-1',
            'patient_id': 'patient-1',
            'treatment_type': 'Implant',
            'tooth_number': ['14'],
            'status': null,
            'date': '2026-02-21T10:10:00Z',
          },
        ]),
      );

      final plan = await repository.loadChart('patient-1');

      expect(plan['14'], ToothCondition.treated);
    },
  );

  test(
    'dental chart aggregates all completed treatment types per tooth and ignores non-completed rows',
    () async {
      final repository = DentalChartRepository(
        treatments: _FakeTreatmentDataService([
          {
            'id': 'completed-1',
            'patient_id': 'patient-1',
            'treatment_type': 'Implant',
            'tooth_number': ['14', '26'],
            'status': null,
            'date': '2026-02-21T10:10:00Z',
          },
          {
            'id': 'completed-2',
            'patient_id': 'patient-1',
            'treatment_type': 'Removal',
            'tooth_number': ['14'],
            'status': null,
            'date': '2026-02-20T10:10:00Z',
          },
          {
            'id': 'completed-3',
            'patient_id': 'patient-1',
            'treatment_type': 'Graft',
            'tooth_number': ['26'],
            'status': null,
            'date': '2026-02-21T10:10:00Z',
          },
          {
            'id': 'planned-1',
            'patient_id': 'patient-1',
            'treatment_type': 'Scan',
            'tooth_number': ['26'],
            'status': 'planned',
            'date': '2026-02-22T10:10:00Z',
          },
        ]),
      );

      final treatments =
          await repository.watchTreatmentsByTooth('patient-1').first;

      expect(treatments['14'], ['Implant', 'Removal']);
      expect(treatments['26'], ['Graft', 'Implant']);
    },
  );
}
