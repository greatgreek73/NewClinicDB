import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tooth_condition.dart';

class DentalChartRepository {
  DentalChartRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Set<String> _initializedPatients = {};

  DocumentReference<Map<String, dynamic>> _chartDoc(String patientId) {
    return _firestore
        .collection('patients')
        .doc(patientId)
        .collection('dentalChart')
        .doc('current');
  }

  CollectionReference<Map<String, dynamic>> _historyCollection(
    String patientId,
  ) {
    return _chartDoc(patientId).collection('history');
  }

  Stream<Map<String, ToothCondition>> watchChart(String patientId) async* {
    await _ensureChartDoc(patientId);
    yield* _chartDoc(patientId).snapshots().map(_mapSnapshotToPlan);
  }

  Future<Map<String, ToothCondition>> loadChart(String patientId) async {
    await _ensureChartDoc(patientId);
    final snapshot = await _chartDoc(patientId).get();
    return _mapSnapshotToPlan(snapshot);
  }

  Future<void> setToothStatus(
    String patientId,
    String toothNumber,
    ToothCondition condition, {
    String? updatedBy,
  }) async {
    final normalizedTooth = toothNumber.trim();
    if (normalizedTooth.isEmpty) return;

    final payload = <String, Object?>{
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'patient-details',
    };

    final path = 'teeth.$normalizedTooth';
    if (condition == ToothCondition.healthy) {
      payload[path] = FieldValue.delete();
    } else {
      payload[path] = toothConditionToString(condition);
    }

    if (updatedBy != null && updatedBy.isNotEmpty) {
      payload['updatedBy'] = updatedBy;
    }

    await _chartDoc(patientId).set(payload, SetOptions(merge: true));
    await _writeHistory(
      patientId: patientId,
      payload: {
        'toothNumber': normalizedTooth,
        'status': toothConditionToString(condition),
        'updatedAt': FieldValue.serverTimestamp(),
        if (updatedBy != null && updatedBy.isNotEmpty) 'updatedBy': updatedBy,
        'source': 'patient-details',
      },
    );
  }

  Future<void> setBulk(
    String patientId,
    Map<String, ToothCondition> plan, {
    String? updatedBy,
    String source = 'bulk-set',
  }) async {
    final mapped = plan.map(
      (key, value) => MapEntry(key, toothConditionToString(value)),
    );

    final payload = <String, Object?>{
      'teeth': mapped,
      'updatedAt': FieldValue.serverTimestamp(),
      'source': source,
    };

    if (updatedBy != null && updatedBy.isNotEmpty) {
      payload['updatedBy'] = updatedBy;
    }

    await _chartDoc(patientId).set(payload, SetOptions(merge: true));
    await _writeHistory(
      patientId: patientId,
      payload: {
        'status': 'bulk',
        'teeth': mapped,
        'updatedAt': FieldValue.serverTimestamp(),
        if (updatedBy != null && updatedBy.isNotEmpty) 'updatedBy': updatedBy,
        'source': source,
      },
    );
  }

  Future<void> _ensureChartDoc(String patientId) async {
    if (_initializedPatients.contains(patientId)) return;

    final snapshot = await _chartDoc(patientId).get();
    if (!snapshot.exists || snapshot.data()?['teeth'] == null) {
      await _seedFromTreatments(patientId);
    }

    _initializedPatients.add(patientId);
  }

  Map<String, ToothCondition> _mapSnapshotToPlan(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final rawTeeth = data?['teeth'];
    if (rawTeeth is! Map<String, dynamic>) return {};

    final Map<String, ToothCondition> plan = {};
    rawTeeth.forEach((key, value) {
      final parsed = toothConditionFromString(value?.toString());
      if (parsed != ToothCondition.healthy) {
        plan[key] = parsed;
      }
    });
    return plan;
  }

  Future<void> _writeHistory({
    required String patientId,
    required Map<String, Object?> payload,
  }) async {
    try {
      await _historyCollection(patientId).add(payload);
    } catch (_) {
      // Do not break main flow if history cannot be written.
    }
  }

  Future<Map<String, ToothCondition>> _seedFromTreatments(
    String patientId,
  ) async {
    final Map<String, ToothCondition> collected = {};

    final futures = await Future.wait([
      _firestore
          .collection('treatments')
          .where('patientId', isEqualTo: patientId)
          .limit(200)
          .get(),
      _firestore
          .collection('treatments')
          .where('patient_id', isEqualTo: patientId)
          .limit(200)
          .get(),
    ]);

    for (final snapshot in futures) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawStatus = data['status']?.toString();
        final unevaluatedStatus =
            rawStatus != null ? toothConditionFromString(rawStatus) : null;
        final status =
            unevaluatedStatus == null || rawStatus == null
                ? ToothCondition.treated
                : unevaluatedStatus;

        final rawTeeth = data['toothNumber'];
        if (rawTeeth is Iterable) {
          for (final tooth in rawTeeth) {
            final toothKey = tooth?.toString().trim();
            if (toothKey == null || toothKey.isEmpty) continue;
            collected[toothKey] = status;
          }
        } else if (rawTeeth != null) {
          final toothKey = rawTeeth.toString().trim();
          if (toothKey.isNotEmpty) {
            collected[toothKey] = status;
          }
        }
      }
    }

    final doc = _chartDoc(patientId);
    if (collected.isEmpty) {
      await doc.set(
        {
          'teeth': {},
          'updatedAt': FieldValue.serverTimestamp(),
          'source': 'init-empty',
        },
        SetOptions(merge: true),
      );
      return {};
    }

    final mapped = collected.map(
      (key, value) => MapEntry(key, toothConditionToString(value)),
    );

    await doc.set(
      {
        'teeth': mapped,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'seed',
        'source': 'treatments-import',
      },
      SetOptions(merge: true),
    );

    await _writeHistory(
      patientId: patientId,
      payload: {
        'status': 'seed',
        'teeth': mapped,
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'treatments-import',
      },
    );

    return collected;
  }

  /// Stream: для конкретного пациента возвращает карту зуб -> список типов лечения.
  Stream<Map<String, List<String>>> watchTreatmentsByTooth(
    String patientId, {
    int limit = 500,
  }) {
    final query = _firestore
        .collection('treatments')
        .where('patientId', isEqualTo: patientId)
        .limit(limit);

    return query.snapshots().map((snapshot) {
      final Map<String, Set<String>> aggregated = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final types = _extractTreatmentTypes(data);
        if (types.isEmpty) continue;

        final rawTeeth = data['toothNumber'];
        if (rawTeeth is Iterable) {
          for (final tooth in rawTeeth) {
            final key = tooth?.toString().trim();
            if (key == null || key.isEmpty) continue;
            aggregated.putIfAbsent(key, () => <String>{}).addAll(types);
          }
        } else if (rawTeeth != null) {
          final key = rawTeeth.toString().trim();
          if (key.isNotEmpty) {
            aggregated.putIfAbsent(key, () => <String>{}).addAll(types);
          }
        }
      }

      return aggregated.map(
        (key, value) => MapEntry(key, value.toList()..sort()),
      );
    });
  }

  /// Загружает уникальные типы лечения из коллекции treatments (опционально для пациента).
  Future<Set<String>> loadTreatmentTypes({
    String? patientId,
    int limit = 800,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection('treatments');
    if (patientId != null) {
      query = query.where('patientId', isEqualTo: patientId);
    }
    query = query.limit(limit);

    final snapshot = await query.get();
    final types = <String>{};
    for (final doc in snapshot.docs) {
      types.addAll(_extractTreatmentTypes(doc.data()));
    }
    return types;
  }

  List<String> _extractTreatmentTypes(Map<String, dynamic> data) {
    final raw = data['treatmentType'] ?? data['type'] ?? data['treatment_type'];
    if (raw == null) return const [];
    if (raw is Iterable) {
      return raw
          .map((e) => e?.toString().trim())
          .where((e) => e != null && e!.isNotEmpty)
          .map((e) => e!)
          .toList();
    }
    final value = raw.toString().trim();
    if (value.isEmpty) return const [];
    return [value];
  }
}
