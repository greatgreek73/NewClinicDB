import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared tooth status used across storage and UI.
enum ToothCondition { healthy, treated, inProgress, planned }

/// Serialize enum to Firestore.
String toothConditionToString(ToothCondition condition) {
  switch (condition) {
    case ToothCondition.healthy:
      return 'healthy';
    case ToothCondition.treated:
      return 'treated';
    case ToothCondition.inProgress:
      return 'inProgress';
    case ToothCondition.planned:
      return 'planned';
  }
}

/// Parse Firestore string to enum (defaults to healthy).
ToothCondition toothConditionFromString(String? value) {
  switch (value) {
    case 'treated':
      return ToothCondition.treated;
    case 'inProgress':
    case 'in_progress':
      return ToothCondition.inProgress;
    case 'planned':
      return ToothCondition.planned;
    case 'healthy':
    default:
      return ToothCondition.healthy;
  }
}

extension ToothConditionDisplay on ToothCondition {
  Color get color {
    switch (this) {
      case ToothCondition.healthy:
        return AppColors.surfaceDark.withOpacity(0.9);
      case ToothCondition.treated:
        return AppColors.accent.withOpacity(0.9);
      case ToothCondition.inProgress:
        return Colors.pinkAccent.withOpacity(0.9);
      case ToothCondition.planned:
        return Colors.tealAccent.withOpacity(0.9);
    }
  }

  String get label {
    switch (this) {
      case ToothCondition.healthy:
        return 'Healthy';
      case ToothCondition.treated:
        return 'Treated';
      case ToothCondition.inProgress:
        return 'In progress';
      case ToothCondition.planned:
        return 'Planned';
    }
  }
}
