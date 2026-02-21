import 'supabase_client.dart';

class PatientBucketEntry {
  final String id;
  final String title;
  final String subtitle;

  PatientBucketEntry({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  factory PatientBucketEntry.fromRow(Map<String, dynamic> data) {
    final id = (data['id'] ?? '').toString().trim();
    final name = (data['name'] ?? '').toString().trim();
    final surname = (data['surname'] ?? '').toString().trim();
    final resolvedName = [name, surname].where((v) => v.isNotEmpty).join(' ');

    final phone = (data['phone'] ?? '').toString().trim();
    final city = (data['city'] ?? '').toString().trim();
    final subtitle = [phone, city].where((v) => v.isNotEmpty).join(' | ');

    return PatientBucketEntry(
      id: id,
      title: resolvedName.isNotEmpty ? resolvedName : 'Patient $id',
      subtitle: subtitle.isNotEmpty ? subtitle : 'No contact details',
    );
  }
}

class PatientBucketService {
  static const _patientsCollection = 'patients';
  static const _bucketField = 'priority_bucket';

  Stream<int?> watchPatientBucket(String patientId) {
    final client = maybeSupabaseClient;
    if (client == null) {
      return Stream.value(null);
    }

    return client.from(_patientsCollection).stream(primaryKey: ['id']).map((
      rows,
    ) {
      for (final raw in rows) {
        final data = Map<String, dynamic>.from(raw);
        final id = (data['id'] ?? '').toString().trim();
        if (id == patientId) {
          return _parseBucket(data);
        }
      }
      return null;
    });
  }

  Future<void> setPatientBucket(String patientId, int? bucket) async {
    if (maybeSupabaseClient == null) {
      throw StateError('Supabase is not initialized');
    }
    await supabaseClient
        .from(_patientsCollection)
        .update({_bucketField: bucket})
        .eq('id', patientId);
  }

  Stream<List<PatientBucketEntry>> watchPatientsInBucket(int bucket) {
    final client = maybeSupabaseClient;
    if (client == null) {
      return Stream.value(const <PatientBucketEntry>[]);
    }

    return client.from(_patientsCollection).stream(primaryKey: ['id']).map((
      rows,
    ) {
      final entries =
          rows
              .map((row) => Map<String, dynamic>.from(row))
              .where((row) => _parseBucket(row) == bucket)
              .map(PatientBucketEntry.fromRow)
              .toList();
      entries.sort((a, b) => a.title.compareTo(b.title));
      if (entries.length > 50) {
        return entries.sublist(0, 50);
      }
      return entries;
    });
  }

  static int? bucketFromData(Map<String, dynamic>? data) {
    return _parseBucket(data);
  }

  static int? _parseBucket(Map<String, dynamic>? data) {
    final raw = data?[_bucketField];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }
}
