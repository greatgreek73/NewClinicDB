import 'supabase_client.dart';

class TreatmentDataService {
  static const _table = 'treatments';

  Stream<List<Map<String, dynamic>>> watchAll({int maxRows = 2000}) {
    final client = maybeSupabaseClient;
    if (client == null) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }

    return client.from(_table).stream(primaryKey: ['id']).map((rows) {
      final mapped = rows.map((row) => Map<String, dynamic>.from(row)).toList();
      if (mapped.length <= maxRows) return mapped;
      return mapped.sublist(mapped.length - maxRows);
    });
  }

  Future<List<Map<String, dynamic>>> fetchAll({int limit = 2000}) async {
    final client = maybeSupabaseClient;
    if (client == null) return const [];

    final response = await client.from(_table).select().limit(limit);
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> insert(Map<String, dynamic> payload) async {
    await _runWithSchemaFallback((row) async {
      await supabaseClient.from(_table).insert(row);
    }, payload);
  }

  Future<void> updateById(dynamic id, Map<String, dynamic> payload) async {
    await _runWithSchemaFallback((row) async {
      await supabaseClient.from(_table).update(row).eq('id', id);
    }, payload);
  }

  Future<void> deleteById(dynamic id) async {
    if (maybeSupabaseClient == null) {
      throw StateError('Supabase is not initialized');
    }
    await supabaseClient.from(_table).delete().eq('id', id);
  }

  Future<void> _runWithSchemaFallback(
    Future<void> Function(Map<String, dynamic> row) action,
    Map<String, dynamic> payload,
  ) async {
    if (maybeSupabaseClient == null) {
      throw StateError('Supabase is not initialized');
    }

    Object? lastError;
    final variants = <Map<String, dynamic>>[
      payload,
      _toSnakeCasePayload(payload),
    ];

    for (final variant in variants) {
      try {
        await action(variant);
        return;
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
  }

  Map<String, dynamic> _toSnakeCasePayload(Map<String, dynamic> payload) {
    final mapped = <String, dynamic>{};
    payload.forEach((key, value) {
      switch (key) {
        case 'patientId':
          mapped['patient_id'] = value;
          break;
        case 'treatmentType':
          mapped['treatment_type'] = value;
          break;
        case 'toothNumber':
          mapped['tooth_number'] = value;
          break;
        case 'updatedAt':
          mapped['updated_at'] = value;
          break;
        case 'updatedBy':
          mapped['updated_by'] = value;
          break;
        default:
          mapped[key] = value;
      }
    });
    return mapped;
  }
}
