import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PatientBucketDefinition {
  final int id;
  final String title;
  final String description;
  final Color color;
  final IconData icon;

  const PatientBucketDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
  });
}

const List<PatientBucketDefinition> patientBuckets = [
  PatientBucketDefinition(
    id: 1,
    title: 'Priority I',
    description: 'Critical cases that need the soonest attention.',
    color: AppColors.accentStrong,
    icon: Icons.local_fire_department_rounded,
  ),
  PatientBucketDefinition(
    id: 2,
    title: 'Priority II',
    description: 'High priority patients to keep moving forward.',
    color: AppColors.accent,
    icon: Icons.flash_on_rounded,
  ),
  PatientBucketDefinition(
    id: 3,
    title: 'Priority III',
    description: 'Routine care and planned follow-ups.',
    color: Color(0xFF6CD6A2),
    icon: Icons.assignment_turned_in_rounded,
  ),
  PatientBucketDefinition(
    id: 4,
    title: 'Priority IV',
    description: 'Long-term monitoring or wellness.',
    color: Color(0xFF78A0FF),
    icon: Icons.inbox_rounded,
  ),
];

PatientBucketDefinition? bucketById(int id) {
  try {
    return patientBuckets.firstWhere((bucket) => bucket.id == id);
  } catch (_) {
    return null;
  }
}
