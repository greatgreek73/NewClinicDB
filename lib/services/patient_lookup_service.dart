import '../utils/patient_name_formatter.dart';
import 'supabase_client.dart';

enum PatientLookupMatchType { record, phone }

class PatientLookupResult {
  final String id;
  final String title;
  final String subtitle;
  final PatientLookupMatchType matchType;

  const PatientLookupResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.matchType,
  });
}

class PatientLookupService {
  const PatientLookupService();

  Future<List<PatientLookupResult>> search(
    String query, {
    int limit = 25,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const <PatientLookupResult>[];

    final normalized = cleanQuery.toLowerCase();
    final tokens =
        normalized
            .split(RegExp(r'\s+'))
            .where((token) => token.isNotEmpty)
            .toList();
    final searchTerm = tokens.isNotEmpty ? tokens.first : normalized;
    final additionalTokens = tokens.skip(1).toList();
    final phoneDigits = cleanQuery.replaceAll(RegExp(r'[^0-9]'), '');

    final pending = <Future<List<PatientLookupResult>>>[];
    if (searchTerm.isNotEmpty) {
      pending.add(_searchByName(searchTerm, additionalTokens, limit: limit));
    }
    if (phoneDigits.length >= 3) {
      pending.add(_searchByPhone(phoneDigits, limit: limit));
    }

    if (pending.isEmpty) return const <PatientLookupResult>[];

    final responses = await Future.wait(pending);
    final merged = <String, PatientLookupResult>{};
    for (final list in responses) {
      for (final result in list) {
        merged.putIfAbsent(result.id, () => result);
      }
    }
    return merged.values.toList();
  }

  Future<PatientLookupResult?> loadById(String patientId) async {
    final client = maybeSupabaseClient;
    final normalizedId = patientId.trim();
    if (client == null || normalizedId.isEmpty) {
      return null;
    }

    try {
      final response =
          await client
              .from('patients')
              .select('id, name, surname, phone, city')
              .eq('id', normalizedId)
              .maybeSingle();
      if (response is! Map) return null;
      return _buildResultFromRow(
        Map<String, dynamic>.from(response as Map),
        matchType: PatientLookupMatchType.record,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<PatientLookupResult>> _searchByName(
    String searchTerm,
    List<String> additionalTokens, {
    required int limit,
  }) async {
    final rows = await _queryPatientsByPrefix(
      primaryField: 'search_key',
      fallbackField: 'surname',
      prefix: searchTerm,
      limit: limit,
    );

    final loweredTokens = additionalTokens
        .where((token) => token.isNotEmpty)
        .map((token) => token.toLowerCase());
    final results = <PatientLookupResult>[];
    for (final row in rows) {
      final searchable = _collectSearchableText(row);
      final matchesFilters = loweredTokens.every(searchable.contains);
      if (!matchesFilters) continue;

      final result = _buildResultFromRow(
        row,
        matchType: PatientLookupMatchType.record,
      );
      if (result.id.isEmpty) continue;
      results.add(result);
    }
    return results;
  }

  Future<List<PatientLookupResult>> _searchByPhone(
    String digits, {
    required int limit,
  }) async {
    final normalizedDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalizedDigits.length < 3) return const <PatientLookupResult>[];

    final prefixes = <String>{normalizedDigits, '+$normalizedDigits'};
    final results = <PatientLookupResult>[];
    for (final prefix in prefixes) {
      if (prefix.isEmpty) continue;

      final rows = await _queryPatientsByPrefix(
        primaryField: 'phone',
        fallbackField: 'phone',
        prefix: prefix,
        limit: limit,
      );
      for (final row in rows) {
        final docDigits = _normalizePhone(row['phone']);
        if (!docDigits.contains(normalizedDigits)) continue;

        final result = _buildResultFromRow(
          row,
          matchType: PatientLookupMatchType.phone,
        );
        if (result.id.isEmpty) continue;
        results.add(result);
      }
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _queryPatientsByPrefix({
    required String primaryField,
    required String fallbackField,
    required String prefix,
    required int limit,
  }) async {
    final client = maybeSupabaseClient;
    if (client == null) return const <Map<String, dynamic>>[];

    final pattern = '$prefix%';
    try {
      final response = await client
          .from('patients')
          .select()
          .ilike(primaryField, pattern)
          .limit(limit);
      return (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {}

    try {
      final response = await client
          .from('patients')
          .select()
          .ilike(fallbackField, pattern)
          .limit(limit);
      return (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {}

    final response = await client.from('patients').select().limit(250);
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  PatientLookupResult _buildResultFromRow(
    Map<String, dynamic> data, {
    required PatientLookupMatchType matchType,
  }) {
    final id = (data['id'] ?? '').toString().trim();
    final phone = data['phone']?.toString().trim() ?? '';
    final city = data['city']?.toString().trim() ?? '';
    final subtitle = [
      phone,
      city,
    ].where((value) => value.isNotEmpty).join(' • ');
    return PatientLookupResult(
      id: id,
      title: formatPatientDisplayName(
        name: data['name'],
        surname: data['surname'],
        fallback: 'Unknown Patient',
      ),
      subtitle: subtitle.isNotEmpty ? subtitle : 'No details',
      matchType: matchType,
    );
  }

  String _normalizePhone(dynamic value) {
    if (value == null) return '';
    return value.toString().replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _collectSearchableText(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    final fields = [
      data['name'],
      data['surname'],
      data['phone'],
      data['city'],
      data['email'],
    ];
    for (final field in fields) {
      if (field == null) continue;
      buffer.write(field.toString().toLowerCase());
      buffer.write(' ');
    }
    return buffer.toString();
  }
}
