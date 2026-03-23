import 'package:flutter/material.dart';

import '../services/patient_lookup_service.dart';
import '../services/recent_patient_search_service.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import '../widgets/primary_page_scaffold.dart';
import 'patient_details_page.dart';

class SearchPage extends StatelessWidget {
  static const routeName = '/search';

  final PatientLookupService patientLookupService;

  const SearchPage({super.key, PatientLookupService? patientLookupService})
    : patientLookupService =
          patientLookupService ?? const PatientLookupService();

  @override
  Widget build(BuildContext context) {
    return PrimaryPageScaffold(
      child: _SearchContent(patientLookupService: patientLookupService),
    );
  }
}

class _SearchContent extends StatefulWidget {
  final PatientLookupService patientLookupService;

  const _SearchContent({required this.patientLookupService});

  @override
  State<_SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<_SearchContent> {
  final TextEditingController _searchController = TextEditingController();
  final RecentPatientSearchService _recentSearchService =
      RecentPatientSearchService();

  List<_SearchResult> _results = [];
  List<_SearchResult> _recentResults = [];
  bool _isLoading = false;
  bool _isLoadingRecent = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecentPatients();
  }

  Future<void> _loadRecentPatients() async {
    try {
      final recentEntries = await _recentSearchService.loadRecentPatients();
      final hydratedEntries = await _hydrateRecentPatients(recentEntries);
      await _recentSearchService.replaceRecentPatients(hydratedEntries);
      if (!mounted) return;
      setState(() {
        _recentResults = _mapRecentEntriesToResults(hydratedEntries);
        _isLoadingRecent = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recentResults = [];
        _isLoadingRecent = false;
      });
    }
  }

  Future<List<RecentPatientSearchEntry>> _hydrateRecentPatients(
    List<RecentPatientSearchEntry> entries,
  ) async {
    if (entries.isEmpty) return entries;

    final hydrated = await Future.wait(
      entries.map((entry) async {
        try {
          final loaded = await widget.patientLookupService.loadById(entry.id);
          if (loaded == null) return entry;

          return RecentPatientSearchEntry(
            id: entry.id,
            title: loaded.title.isNotEmpty ? loaded.title : entry.title,
            subtitle:
                loaded.subtitle.isNotEmpty ? loaded.subtitle : entry.subtitle,
          );
        } catch (_) {
          return entry;
        }
      }),
    );

    return hydrated;
  }

  List<_SearchResult> _mapRecentEntriesToResults(
    List<RecentPatientSearchEntry> entries,
  ) {
    return entries
        .map(
          (entry) => _SearchResult(
            id: entry.id,
            title: entry.title,
            subtitle: entry.subtitle.isNotEmpty ? entry.subtitle : 'No details',
            meta: 'Recent',
            icon: Icons.history_rounded,
          ),
        )
        .toList();
  }

  Future<void> _clearRecentPatients() async {
    await _recentSearchService.clearRecentPatients();
    if (!mounted) return;
    setState(() {
      _recentResults = [];
      _isLoadingRecent = false;
    });
  }

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

    final phoneDigits = cleanQuery.replaceAll(RegExp(r'[^0-9]'), '');
    final normalized = cleanQuery.toLowerCase();
    final tokens =
        normalized
            .split(RegExp(r'\s+'))
            .where((token) => token.isNotEmpty)
            .toList();
    final searchTerm = tokens.isNotEmpty ? tokens.first : normalized;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (searchTerm.isEmpty && phoneDigits.length < 3) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
        return;
      }

      final results = await widget.patientLookupService.search(cleanQuery);
      if (!mounted) return;
      setState(() {
        _results = results.map(_mapLookupResult).toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _openPatient(_SearchResult result) async {
    await _recentSearchService.rememberPatient(
      RecentPatientSearchEntry(
        id: result.id,
        title: result.title,
        subtitle: result.subtitle,
      ),
    );
    await _loadRecentPatients();
    if (!mounted) return;
    Navigator.of(context).pushNamed(
      PatientDetailsPage.routeName,
      arguments: PatientDetailsArgs(
        patientId: result.id,
        displayName: result.title,
      ),
    );
  }

  _SearchResult _mapLookupResult(PatientLookupResult result) {
    return _SearchResult(
      id: result.id,
      title: result.title,
      subtitle: result.subtitle.isNotEmpty ? result.subtitle : 'No details',
      meta:
          result.matchType == PatientLookupMatchType.phone
              ? 'Phone match'
              : 'Patient record',
      icon: Icons.person_outline,
    );
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
        TextField(
          controller: _searchController,
          style: const TextStyle(color: AppColors.textPrimary),
          onChanged: _performSearch,
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
        if (_searchController.text.isEmpty) ...[
          if (_isLoadingRecent)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                minHeight: 4,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                backgroundColor: Colors.white.withOpacity(0.08),
              ),
            )
          else if (_recentResults.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Recent patients',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted.withOpacity(0.9),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _clearRecentPatients,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._recentResults.map(
              (result) => _SearchResultTile(
                result: result,
                onTap: () => _openPatient(result),
              ),
            ),
          ] else ...[
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
                  ].map(_buildFilterChip).toList(),
            ),
          ],
        ] else ...[
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
                    style: const TextStyle(
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
            (result) => _SearchResultTile(
              result: result,
              onTap: () => _openPatient(result),
            ),
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

  const _SearchResultTile({required this.result, this.onTap});

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;
            final leading = Container(
              padding: EdgeInsets.all(isCompact ? 10 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentStrong.withOpacity(0.9),
                    AppColors.accent.withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Icon(
                result.icon,
                size: isCompact ? 20 : 24,
                color: AppColors.bg,
              ),
            );

            final textBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.subtitle,
                  maxLines: isCompact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leading,
                      const SizedBox(width: 12),
                      Expanded(child: textBlock),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMetaBadge(),
                ],
              );
            }

            return Row(
              children: [
                leading,
                const SizedBox(width: 16),
                Expanded(child: textBlock),
                const SizedBox(width: 12),
                _buildMetaBadge(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetaBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        result.meta,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textMuted.withOpacity(0.9),
        ),
      ),
    );
  }
}
