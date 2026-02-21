import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

BoxDecoration buildPrimaryPanelDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(32),
    gradient: RadialGradient(
      center: Alignment.topLeft,
      radius: 1.6,
      colors: [
        AppColors.accentStrong.withOpacity(0.28),
        AppColors.bgMid,
        AppColors.bg,
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    border: Border.all(
      color: Colors.white.withOpacity(0.1),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.9),
        blurRadius: 120,
        spreadRadius: 40,
      ),
      BoxShadow(
        color: AppColors.accentStrong.withOpacity(0.25),
        blurRadius: 80,
        spreadRadius: 18,
        offset: const Offset(0, 24),
      ),
    ],
  );
}

BoxDecoration buildSurfaceCardDecoration({bool glow = false}) {
  final borderColor =
      glow ? AppColors.accent.withOpacity(0.6) : Colors.white.withOpacity(0.12);
  final highlight = glow
      ? AppColors.accentStrong.withOpacity(0.22)
      : Colors.white.withOpacity(0.04);
  return BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.topLeft,
      radius: 1.4,
      colors: [
        highlight,
        AppColors.surface.withOpacity(glow ? 0.97 : 0.93),
        AppColors.surfaceDark.withOpacity(0.98),
      ],
      stops: const [0.0, 0.55, 1.0],
    ),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(
      color: borderColor,
    ),
    boxShadow: glow
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 40,
              spreadRadius: 12,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: AppColors.accentStrong.withOpacity(0.45),
              blurRadius: 42,
              spreadRadius: 6,
              offset: const Offset(0, 16),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 28,
              spreadRadius: 8,
              offset: const Offset(0, 14),
            ),
          ],
  );
}

InputDecoration buildFormInputDecoration(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: TextStyle(
      color: AppColors.textMuted.withOpacity(0.9),
    ),
    hintStyle: TextStyle(
      color: AppColors.textMuted.withOpacity(0.6),
    ),
    filled: true,
    fillColor: AppColors.surfaceDark.withOpacity(0.96),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: Colors.white.withOpacity(0.12),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: Colors.white.withOpacity(0.12),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: AppColors.accent.withOpacity(0.9),
        width: 1.2,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
  );
}
