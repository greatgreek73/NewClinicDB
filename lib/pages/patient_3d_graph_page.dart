import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math' as math;

import '../models/waitlist_stage.dart';
import '../services/supabase_client.dart';
import '../services/waitlist_service.dart';
import '../theme/app_colors.dart';
import '../utils/patient_name_formatter.dart';
import '../utils/decorations.dart';
import '../widgets/page_header.dart';
import '../widgets/patient_3d_graph_canvas.dart';
import '../widgets/primary_page_scaffold.dart';
import 'patient_details_page.dart';

class Patient3DGraphPage extends StatefulWidget {
  static const routeName = '/patient-3d-graph';

  const Patient3DGraphPage({super.key});

  @override
  State<Patient3DGraphPage> createState() => _Patient3DGraphPageState();
}

class _Patient3DGraphPageState extends State<Patient3DGraphPage> {
  bool _isLoading = false;
  String? _error;
  List<Patient3DFamily> _families = const [];
  double _autoRotateSpeed = kIsWeb ? 0.0 : 0.18;

  static const Map<Patient3DStatus, String> _statusLabels = {
    Patient3DStatus.scheduled: 'Scheduled',
    Patient3DStatus.urgent: 'Urgent',
    Patient3DStatus.debt: 'Debt',
    Patient3DStatus.ok: 'OK',
    Patient3DStatus.missed: 'Missed',
  };

  static const Map<Patient3DStatus, Color> _statusColors = {
    Patient3DStatus.scheduled: Color(0xFF3B82F6),
    Patient3DStatus.urgent: Color(0xFFEF4444),
    Patient3DStatus.debt: Color(0xFFF97316),
    Patient3DStatus.ok: Color(0xFF22C55E),
    Patient3DStatus.missed: Color(0xFFEAB308),
  };

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final scheduledIds = await _loadScheduledPatientIdsForToday();
      final families = await _loadStageFamilies(scheduledIds);

      setState(() {
        _families = families;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _families = const [];
        _isLoading = false;
      });
    }
  }

  Future<Set<String>> _loadScheduledPatientIdsForToday() async {
    final client = maybeSupabaseClient;
    if (client == null) return const <String>{};

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await client
        .from('treatments')
        .select('patient_id,date')
        .gte('date', startOfDay.toUtc().toIso8601String())
        .lt('date', endOfDay.toUtc().toIso8601String());

    final ids = <String>{};
    for (final row in (snapshot as List)) {
      final data = Map<String, dynamic>.from(row as Map);
      final rawId = data['patient_id'];
      final id = rawId?.toString().trim();
      if (id != null && id.isNotEmpty) {
        ids.add(id);
      }
    }
    return ids;
  }

  Future<List<Patient3DFamily>> _loadStageFamilies(
    Set<String> scheduledIds,
  ) async {
    final client = maybeSupabaseClient;
    if (client == null) return const <Patient3DFamily>[];

    const maxPatientsPerStage = 20;
    final families = <Patient3DFamily>[];
    final familyPositions = <vm.Vector3>[
      vm.Vector3(-3, 0, 0),
      vm.Vector3(3, 1, 0),
      vm.Vector3(0, -2.5, 1),
      vm.Vector3(0, 2.5, -1),
    ];

    final response = await client.from('patients').select();
    final patientRows =
        (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

    for (var i = 0; i < waitlistStages.length; i++) {
      final stage = waitlistStages[i];
      final docs =
          patientRows.where((row) {
            return waitlistStageIdFromData(row) == stage.id;
          }).toList();
      final total = docs.length;

      final patients = <Patient3DNode>[];
      for (var index = 0; index < docs.length; index++) {
        if (index >= maxPatientsPerStage) break;
        final data = docs[index];
        final rowId = (data['id'] ?? '').toString().trim();
        if (rowId.isEmpty) continue;
        final phone = (data['phone'] ?? '').toString().trim();
        final city = (data['city'] ?? '').toString().trim();
        final subtitle = [phone, city].where((v) => v.isNotEmpty).join(' | ');

        final isDebt = _hasDebt(data);
        final status =
            scheduledIds.contains(rowId)
                ? Patient3DStatus.scheduled
                : stage.id == 1
                ? Patient3DStatus.urgent
                : isDebt
                ? Patient3DStatus.debt
                : Patient3DStatus.ok;

        patients.add(
          Patient3DNode(
            id: rowId,
            name: formatPatientDisplayName(
              name: data['name'],
              surname: data['surname'],
              fallback: 'Patient $rowId',
            ),
            subtitle: subtitle.isNotEmpty ? subtitle : null,
            status: status,
            offset: _computePatientOffset(index, total),
          ),
        );
      }

      families.add(
        Patient3DFamily(
          id: 'stage-${stage.id}',
          name: stage.title,
          color: stage.color,
          position: familyPositions[i % familyPositions.length],
          patients: patients,
        ),
      );
    }

    return families;
  }

  vm.Vector3 _computePatientOffset(int index, int total) {
    final safeTotal = total <= 0 ? 1 : total;
    final angle = (index / safeTotal) * math.pi * 2;
    final ring = 1.8 + (index % 3) * 0.25;
    final y = ((index % 5) - 2) * 0.45;
    return vm.Vector3(math.cos(angle) * ring, y, math.sin(angle) * ring);
  }

  bool _hasDebt(Map<String, dynamic> data) {
    final priceValue = data['price'];
    final totalCost = priceValue is num ? priceValue.toDouble() : null;
    if (totalCost == null) return false;

    double totalPaid = 0;
    final paymentsRaw = data['payments'];
    if (paymentsRaw is List) {
      for (final p in paymentsRaw) {
        if (p is Map) {
          final amount = p['amount'];
          if (amount is num) totalPaid += amount.toDouble();
        }
      }
    }

    return totalPaid + 0.001 < totalCost;
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryPageScaffold(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: '3D patients map',
            subtitle:
                'Clusters by waiting list stage with scheduled/urgent/debt status.',
            actionLabel: 'Back to dashboard',
            onAction: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (_error != null)
                Expanded(
                  child: Text(
                    _error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    _isLoading ? 'Loading graph…' : 'Ready',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted.withOpacity(0.9),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: _isLoading ? null : _refresh,
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
          const SizedBox(height: 14),
          Container(
            decoration: buildSurfaceCardDecoration(),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(
                  Icons.rotate_right_rounded,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Rotation',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _autoRotateSpeed,
                    min: 0.0,
                    max: 0.6,
                    activeColor: AppColors.accent,
                    inactiveColor: Colors.white.withOpacity(0.12),
                    onChanged:
                        (value) => setState(() {
                          _autoRotateSpeed = value;
                        }),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_autoRotateSpeed * 57.3).round()}°/s',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                _statusLabels.entries.map((entry) {
                  final color = _statusColors[entry.key] ?? AppColors.textMuted;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 18),
          Container(
            height: 560,
            decoration: buildSurfaceCardDecoration(glow: true),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Patient3DGraphCanvas(
                    families: _families,
                    autoRotateSpeed: _autoRotateSpeed,
                    onPatientTap: (patient, _) {
                      Navigator.of(context).pushNamed(
                        PatientDetailsPage.routeName,
                        arguments: PatientDetailsArgs(
                          patientId: patient.id,
                          displayName: patient.name,
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.25),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tip: Drag to rotate, use wheel/pinch to zoom, tap/hover spheres for details.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}
