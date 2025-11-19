import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import '../widgets/primary_page_scaffold.dart';
import 'patient_details_page.dart';

class SearchPage extends StatelessWidget {
  static const routeName = '/search';
  const SearchPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return PrimaryPageScaffold(
      maxWidth: 1100,
      padding: const EdgeInsets.all(36),
      child: const _SearchContent(),
    );
  }
}

class _SearchContent extends StatefulWidget {
  const _SearchContent({Key? key}) : super(key: key);
  @override
  State<_SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<_SearchContent> {
  final TextEditingController _searchController = TextEditingController();
  List<_SearchResult> _results = [];
  bool _isLoading = false;
  String? _error;
  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _error = null;
      });
      return;
    }
    final normalized = cleanQuery.toLowerCase();
    final tokens =
        normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final searchTerm = tokens.isNotEmpty ? tokens.first : normalized;
    final additionalTokens = tokens.skip(1).toList();
    final phoneDigits = cleanQuery.replaceAll(RegExp(r'[^0-9]'), '');
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<Future<List<_SearchResult>>> pending = [];
      if (searchTerm.isNotEmpty) {
        pending.add(_searchByName(searchTerm, additionalTokens));
      }
      if (phoneDigits.length >= 3) {
        pending.add(_searchByPhone(phoneDigits));
      }
      if (pending.isEmpty) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
        return;
      }
      final responses = await Future.wait(pending);
      final Map<String, _SearchResult> merged = {};
      for (final list in responses) {
        for (final result in list) {
          merged.putIfAbsent(result.id, () => result);
        }
      }
      setState(() {
        _results = merged.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _openPatient(_SearchResult result) {
    Navigator.of(context).pushNamed(
      PatientDetailsPage.routeName,
      arguments: PatientDetailsArgs(
        patientId: result.id,
        displayName: result.title,
      ),
    );
  }

  Future<List<_SearchResult>> _searchByName(
    String searchTerm,
    List<String> additionalTokens,
  ) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('patients')
            .where('searchKey', isGreaterThanOrEqualTo: searchTerm)
            .where('searchKey', isLessThan: '$searchTerm\uf8ff')
            .limit(15)
            .get();
    final loweredTokens = additionalTokens
        .where((t) => t.isNotEmpty)
        .map((t) => t.toLowerCase());
    final List<_SearchResult> results = [];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final searchable = _collectSearchableText(data);
      final matchesFilters = loweredTokens.every(searchable.contains);
      if (!matchesFilters) continue;
      results.add(_buildResultFromDoc(doc, data, meta: 'Patient record'));
    }
    return results;
  }

  Future<List<_SearchResult>> _searchByPhone(String digits) async {
    final normalizedDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalizedDigits.length < 3) return [];
    final prefixes = <String>{normalizedDigits, '+$normalizedDigits'};
    final List<_SearchResult> results = [];
    for (final prefix in prefixes) {
      if (prefix.isEmpty) continue;
      final snapshot =
          await FirebaseFirestore.instance
              .collection('patients')
              .where('phone', isGreaterThanOrEqualTo: prefix)
              .where('phone', isLessThan: '$prefix\uf8ff')
              .limit(15)
              .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docDigits = _normalizePhone(data['phone']);
        if (!docDigits.contains(normalizedDigits)) continue;
        results.add(_buildResultFromDoc(doc, data, meta: 'Phone match'));
      }
    }
    return results;
  }

  _SearchResult _buildResultFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data, {
    required String meta,
  }) {
    final name = data['name']?.toString().trim() ?? '';
    final surname = data['surname']?.toString().trim() ?? '';
    final fullName = '$name $surname'.trim();
    final phone = data['phone']?.toString().trim() ?? '';
    final city = data['city']?.toString().trim() ?? '';
    final subtitle = [phone, city].where((e) => e.isNotEmpty).join(' • ');
    return _SearchResult(
      id: doc.id,
      title: fullName.isNotEmpty ? fullName : 'Unknown Patient',
      subtitle: subtitle.isNotEmpty ? subtitle : 'No details',
      meta: meta,
      icon: Icons.person_outline,
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Search patients',
          subtitle: 'Find patients by surname or phone number.',
          actionLabel: 'Back to dashboard',
          onAction: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 32),
        // РџРѕР»Рµ РІРІРѕРґР° РїРѕРёСЃРєР°
        TextField(
          controller: _searchController,
          style: const TextStyle(color: AppColors.textPrimary),
          onChanged: (value) {
            _performSearch(value);
          },
          decoration: InputDecoration(
            hintText: 'Enter surname or phone...',
            hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.8)),
            prefixIcon:
                _isLoading
                    ? Transform.scale(
                      scale: 0.4,
                      child: const CircularProgressIndicator(
                        color: AppColors.accent,
                      ),
                    )
                    : const Icon(Icons.search, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceDark.withOpacity(0.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: AppColors.textMuted.withOpacity(0.25),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: AppColors.textMuted.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.accent.withOpacity(0.8)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        const SizedBox(height: 28),
        // РљРѕРЅС‚РµРЅС‚ РїРѕРґ СЃС‚СЂРѕРєРѕР№ РїРѕРёСЃРєР°
        if (_searchController.text.isEmpty) ...[
          Text(
            'Suggested filters',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                [
                  'Patients',
                  'Treatments',
                  'Invoices',
                  'Notes',
                  'Upcoming',
                ].map((label) => _buildFilterChip(label)).toList(),
          ),
        ] else ...[
          // Р РµР·СѓР»СЊС‚Р°С‚С‹ РїРѕРёСЃРєР°
          Row(
            children: [
              Text(
                'Results',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted.withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 12),
              if (!_isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withOpacity(0.25),
                        AppColors.accentStrong.withOpacity(0.35),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.accentSoft.withOpacity(0.6),
                    ),
                  ),
                  child: Text(
                    '${_results.length} found',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.bg,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          if (_results.isEmpty && !_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                'No patients found for this name or phone.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ..._results.map(
            (r) => _SearchResultTile(result: r, onTap: () => _openPatient(r)),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface.withOpacity(0.95),
            AppColors.surfaceDark.withOpacity(0.98),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      ),
    );
  }
}

class _SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;

  _SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.icon,
  });
}

class _SearchResultTile extends StatelessWidget {
  final _SearchResult result;
  final VoidCallback? onTap;

  const _SearchResultTile({super.key, required this.result, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surfaceDark.withOpacity(0.98),
              AppColors.surface.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              spreadRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentStrong.withOpacity(0.9),
                    AppColors.accent.withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Icon(result.icon, size: 24, color: AppColors.bg),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.subtitle,
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              result.meta,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
