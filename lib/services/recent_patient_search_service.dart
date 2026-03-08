import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecentPatientSearchEntry {
  final String id;
  final String title;
  final String subtitle;

  const RecentPatientSearchEntry({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  Map<String, String> toJson() {
    return <String, String>{'id': id, 'title': title, 'subtitle': subtitle};
  }

  static RecentPatientSearchEntry? fromRaw(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final data = Map<String, dynamic>.from(decoded);
      final id = (data['id'] ?? '').toString().trim();
      if (id.isEmpty) return null;

      return RecentPatientSearchEntry(
        id: id,
        title: (data['title'] ?? '').toString().trim(),
        subtitle: (data['subtitle'] ?? '').toString().trim(),
      );
    } catch (_) {
      return null;
    }
  }
}

class RecentPatientSearchService {
  static const String storageKey = 'recent_patient_searches_v1';
  static const int maxEntries = 5;

  Future<List<RecentPatientSearchEntry>> loadRecentPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(storageKey) ?? const <String>[];
    return rawItems
        .map(RecentPatientSearchEntry.fromRaw)
        .whereType<RecentPatientSearchEntry>()
        .take(maxEntries)
        .toList();
  }

  Future<void> rememberPatient(RecentPatientSearchEntry entry) async {
    final id = entry.id.trim();
    if (id.isEmpty) return;

    final current = await loadRecentPatients();
    final updated =
        <RecentPatientSearchEntry>[
          entry,
          ...current.where((item) => item.id != id),
        ].take(maxEntries).toList();

    await replaceRecentPatients(updated);
  }

  Future<void> replaceRecentPatients(
    List<RecentPatientSearchEntry> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final sanitized =
        entries
            .where((entry) => entry.id.trim().isNotEmpty)
            .take(maxEntries)
            .toList();
    await prefs.setStringList(
      storageKey,
      sanitized.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> clearRecentPatients() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
