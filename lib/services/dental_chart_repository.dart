import '../models/tooth_condition.dart';
import 'id_generator.dart';
import 'treatment_data_service.dart';

class DentalChartRepository {
  DentalChartRepository({TreatmentDataService? treatments})
    : _treatments = treatments ?? TreatmentDataService();

  final TreatmentDataService _treatments;

  Stream<Map<String, ToothCondition>> watchChart(String patientId) {
    return _treatments
        .watchByPatient(patientId, maxRows: 4000)
        .map(_buildPlanFromTreatments);
  }

  Future<Map<String, ToothCondition>> loadChart(String patientId) async {
    final rows = await _treatments.fetchByPatient(patientId, limit: 4000);
    return _buildPlanFromTreatments(rows);
  }

  Future<void> setToothStatus(
    String patientId,
    String toothNumber,
    ToothCondition condition, {
    String? updatedBy,
  }) async {
    final normalizedTooth = toothNumber.trim();
    if (normalizedTooth.isEmpty) return;

    final payload = <String, dynamic>{
      'id': generateTextId('treatment'),
      'patient_id': patientId,
      'tooth_number': [normalizedTooth],
      'status': toothConditionToString(condition),
      'source': 'patient-details',
      'date': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (updatedBy != null && updatedBy.isNotEmpty) 'updated_by': updatedBy,
    };

    await _treatments.insert(payload);
  }

  Future<void> setBulk(
    String patientId,
    Map<String, ToothCondition> plan, {
    String? updatedBy,
    String source = 'bulk-set',
  }) async {
    if (plan.isEmpty) return;

    for (final entry in plan.entries) {
      final tooth = entry.key.trim();
      if (tooth.isEmpty) continue;

      await _treatments.insert({
        'id': generateTextId('treatment'),
        'patient_id': patientId,
        'tooth_number': [tooth],
        'status': toothConditionToString(entry.value),
        'source': source,
        'date': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (updatedBy != null && updatedBy.isNotEmpty) 'updated_by': updatedBy,
      });
    }
  }

  Stream<Map<String, List<String>>> watchTreatmentsByTooth(
    String patientId, {
    int limit = 500,
  }) {
    return _treatments.watchByPatient(patientId, maxRows: limit * 4).map((
      rows,
    ) {
      final patientRows = _latestRows(rows, limit);
      final Map<String, Set<String>> aggregated = {};

      for (final row in patientRows) {
        if (!_isCompletedTreatmentRow(row)) continue;

        final types = _extractTreatmentTypes(row);
        if (types.isEmpty) continue;

        final teeth = _extractToothNumbers(row);
        for (final tooth in teeth) {
          aggregated.putIfAbsent(tooth, () => <String>{}).addAll(types);
        }
      }

      return aggregated.map(
        (key, value) => MapEntry(key, value.toList()..sort()),
      );
    });
  }

  Future<Set<String>> loadTreatmentTypes({
    String? patientId,
    int limit = 800,
  }) async {
    final rows =
        patientId == null
            ? await _treatments.fetchAll(limit: limit * 2)
            : await _treatments.fetchByPatient(patientId, limit: limit * 2);

    final types = <String>{};
    for (final row in rows) {
      types.addAll(_extractTreatmentTypes(row));
    }
    return types;
  }

  List<Map<String, dynamic>> _latestRows(
    List<Map<String, dynamic>> rows,
    int limit,
  ) {
    rows.sort((a, b) => _asDate(b['date']).compareTo(_asDate(a['date'])));
    if (rows.length > limit) {
      return rows.sublist(0, limit);
    }
    return rows;
  }

  Map<String, ToothCondition> _buildPlanFromTreatments(
    List<Map<String, dynamic>> rows,
  ) {
    final plan = <String, ToothCondition>{};
    final ordered =
        rows.toList()
          ..sort((a, b) => _asDate(a['date']).compareTo(_asDate(b['date'])));

    for (final row in ordered) {
      final status = _resolveChartCondition(row);
      final teeth = _extractToothNumbers(row);
      for (final tooth in teeth) {
        if (status == ToothCondition.healthy) {
          plan.remove(tooth);
        } else {
          plan[tooth] = status;
        }
      }
    }
    return plan;
  }

  ToothCondition _resolveChartCondition(Map<String, dynamic> row) {
    final rawStatus = row['status']?.toString().trim();
    if ((rawStatus == null || rawStatus.isEmpty) &&
        _extractTreatmentTypes(row).isNotEmpty) {
      return ToothCondition.treated;
    }
    return toothConditionFromString(rawStatus);
  }

  bool _isCompletedTreatmentRow(Map<String, dynamic> row) {
    return _resolveChartCondition(row) == ToothCondition.treated;
  }

  List<String> _extractToothNumbers(Map<String, dynamic> data) {
    final raw = data['toothNumber'] ?? data['tooth_number'];
    if (raw is Iterable) {
      return raw
          .map((e) => e?.toString().trim())
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is Map) {
      return raw.keys
          .map((key) => key.toString().trim())
          .where((key) => key.isNotEmpty)
          .toList();
    }
    if (raw == null) return const [];
    final value = raw.toString().trim();
    return value.isEmpty ? const [] : [value];
  }

  List<String> _extractTreatmentTypes(Map<String, dynamic> data) {
    final raw = data['treatmentType'] ?? data['type'] ?? data['treatment_type'];
    if (raw == null) return const [];
    if (raw is Iterable) {
      return raw
          .map((e) => e?.toString().trim())
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final value = raw.toString().trim();
    if (value.isEmpty) return const [];
    return [value];
  }

  DateTime _asDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime(1970);
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    return DateTime(1970);
  }
}
