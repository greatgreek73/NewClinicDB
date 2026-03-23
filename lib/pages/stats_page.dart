import 'package:flutter/material.dart';

import '../services/patient_city_stats_service.dart';
import '../theme/app_colors.dart';
import '../utils/decorations.dart';
import '../widgets/page_header.dart';
import '../widgets/primary_page_scaffold.dart';

class StatsPage extends StatelessWidget {
  static const routeName = '/statistics';

  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrimaryPageScaffold(
      padding: EdgeInsets.all(24),
      child: _StatsContent(),
    );
  }
}

class _StatsContent extends StatefulWidget {
  const _StatsContent();

  @override
  State<_StatsContent> createState() => _StatsContentState();
}

class _StatsContentState extends State<_StatsContent> {
  final PatientCityStatsService _statsService = PatientCityStatsService();

  bool _isLoading = false;
  String? _error;
  PatientCityStatsSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _loadCityStats();
  }

  Future<void> _loadCityStats() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final snapshot = await _statsService.loadCityStats();
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Could not load patient city statistics';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Statistics',
          subtitle:
              'Start with patient distribution by city to see where your patient base is concentrated.',
          actionLabel: 'Back to dashboard',
          onAction: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                _isLoading
                    ? 'Loading patient city statistics...'
                    : 'Patient city coverage across your database',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted.withOpacity(0.9),
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _isLoading ? null : _loadCityStats,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: Colors.white.withOpacity(0.06),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                side: BorderSide(color: Colors.white.withOpacity(0.18)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_error != null)
          _buildMessageCard(
            icon: Icons.cloud_off_rounded,
            title: 'Statistics unavailable',
            message: _error!,
          )
        else if (_isLoading && snapshot == null)
          _buildMessageCard(
            icon: Icons.analytics_outlined,
            title: 'Loading statistics',
            message: 'Collecting patient city data from Supabase.',
          )
        else if (snapshot == null)
          _buildMessageCard(
            icon: Icons.analytics_outlined,
            title: 'No statistics yet',
            message: 'Patient city data will appear here once records load.',
          )
        else
          _buildStatsBody(context, snapshot),
      ],
    );
  }

  Widget _buildStatsBody(
    BuildContext context,
    PatientCityStatsSnapshot snapshot,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final summary = _buildSummaryGrid(snapshot, isWide: isWide);
        final cityList = _buildCityListCard(snapshot);

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [summary, const SizedBox(height: 20), cityList],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 320, child: summary),
            const SizedBox(width: 20),
            Expanded(child: cityList),
          ],
        );
      },
    );
  }

  Widget _buildSummaryGrid(
    PatientCityStatsSnapshot snapshot, {
    required bool isWide,
  }) {
    final cards = [
      _StatsSummaryCardData(
        title: 'Patients',
        value: snapshot.totalPatients.toString(),
        subtitle: 'All patient profiles in the database',
        highlighted: true,
      ),
      _StatsSummaryCardData(
        title: 'Cities',
        value: snapshot.uniqueCities.toString(),
        subtitle: 'Unique cities with at least one patient',
      ),
      _StatsSummaryCardData(
        title: 'Missing city',
        value: snapshot.patientsWithoutCity.toString(),
        subtitle: 'Profiles that still need city data',
      ),
    ];

    if (!isWide) {
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children:
            cards
                .map(
                  (card) =>
                      SizedBox(width: 230, child: _buildSummaryCard(card)),
                )
                .toList(),
      );
    }

    return Column(
      children:
          cards
              .map(
                (card) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildSummaryCard(card),
                ),
              )
              .toList(),
    );
  }

  Widget _buildSummaryCard(_StatsSummaryCardData card) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
            card.highlighted
                ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accentStrong.withOpacity(0.95),
                    AppColors.accent.withOpacity(0.85),
                  ],
                )
                : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surface.withOpacity(0.95),
                    AppColors.surfaceDark.withOpacity(0.98),
                  ],
                ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(card.highlighted ? 0.22 : 0.12),
        ),
        boxShadow:
            card.highlighted
                ? [
                  BoxShadow(
                    color: AppColors.accentStrong.withOpacity(0.6),
                    blurRadius: 40,
                    spreadRadius: 12,
                    offset: const Offset(0, 18),
                  ),
                ]
                : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.7),
                    blurRadius: 30,
                    spreadRadius: 10,
                    offset: const Offset(0, 18),
                  ),
                ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.6,
              color:
                  card.highlighted
                      ? AppColors.bg.withOpacity(0.86)
                      : AppColors.textMuted.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              color: card.highlighted ? AppColors.bg : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.subtitle,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color:
                  card.highlighted
                      ? AppColors.bg.withOpacity(0.85)
                      : AppColors.textMuted.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityListCard(PatientCityStatsSnapshot snapshot) {
    final stats = snapshot.cityStats;
    final topCount = stats.isEmpty ? 0 : stats.first.patientCount;

    return Container(
      decoration: buildSurfaceCardDecoration(glow: true),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_city_rounded, color: AppColors.accent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Patients by city',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Text(
                  '${snapshot.uniqueCities} cities',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sorted by patient volume so the biggest city clusters stay at the top.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 18),
          if (stats.isEmpty)
            _buildMessageCard(
              icon: Icons.location_off_rounded,
              title: 'No city data yet',
              message:
                  'Add city values to patient profiles to see distribution here.',
              compact: true,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final stat = stats[index];
                final share =
                    topCount == 0 ? 0.0 : stat.patientCount / topCount;
                return _CityStatTile(
                  rank: index + 1,
                  city: stat.city,
                  count: stat.patientCount,
                  share: share,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String message,
    bool compact = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: buildSurfaceCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textMuted.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSummaryCardData {
  final String title;
  final String value;
  final String subtitle;
  final bool highlighted;

  const _StatsSummaryCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    this.highlighted = false,
  });
}

class _CityStatTile extends StatelessWidget {
  final int rank;
  final String city;
  final int count;
  final double share;

  const _CityStatTile({
    required this.rank,
    required this.city,
    required this.count,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentStrong.withOpacity(0.92),
                  AppColors.accent.withOpacity(0.86),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.bg,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        city,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: share.clamp(0, 1),
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
