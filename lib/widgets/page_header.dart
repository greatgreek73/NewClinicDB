import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textMuted.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              backgroundColor: Colors.white.withOpacity(0.06),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              side: BorderSide(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            icon: const Icon(Icons.arrow_back),
            label: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}
