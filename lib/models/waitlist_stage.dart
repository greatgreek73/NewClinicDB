import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class WaitlistStageDefinition {
  final int id;
  final String title;
  final String description;
  final Color color;
  final IconData icon;

  const WaitlistStageDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
  });
}

const List<WaitlistStageDefinition> waitlistStages = [
  WaitlistStageDefinition(
    id: 1,
    title: 'New',
    description: 'Recently added patients waiting for first review.',
    color: AppColors.accentStrong,
    icon: Icons.fiber_new_rounded,
  ),
  WaitlistStageDefinition(
    id: 2,
    title: 'Contact',
    description: 'Patients the team needs to call or confirm with.',
    color: AppColors.accent,
    icon: Icons.call_rounded,
  ),
  WaitlistStageDefinition(
    id: 3,
    title: 'Ready',
    description: 'Patients ready to be booked when a slot opens.',
    color: Color(0xFF6CD6A2),
    icon: Icons.event_available_rounded,
  ),
  WaitlistStageDefinition(
    id: 4,
    title: 'Deferred',
    description: 'Patients paused until timing or conditions change.',
    color: Color(0xFF78A0FF),
    icon: Icons.pause_circle_outline_rounded,
  ),
  WaitlistStageDefinition(
    id: 5,
    title: 'Completed',
    description: 'Patients who have already completed treatment.',
    color: Color(0xFF4DD0C8),
    icon: Icons.task_alt_rounded,
  ),
];

WaitlistStageDefinition? waitlistStageById(int id) {
  try {
    return waitlistStages.firstWhere((stage) => stage.id == id);
  } catch (_) {
    return null;
  }
}
