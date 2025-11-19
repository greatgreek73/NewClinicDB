import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

BoxDecoration buildPrimaryPanelDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(32),
    gradient: RadialGradient(
      center: Alignment.topCenter,
      radius: 1.4,
      colors: [
        AppColors.accentStrong.withOpacity(0.35),
        AppColors.bgMid,
        AppColors.bg,
      ],
      stops: const [0.0, 0.4, 1.0],
    ),
    border: Border.all(
      color: Colors.white.withOpacity(0.05),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.95),
        blurRadius: 140,
        spreadRadius: 50,
      ),
    ],
  );
}

BoxDecoration buildSurfaceCardDecoration({bool glow = false}) {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        AppColors.surface.withOpacity(glow ? 0.98 : 0.93),
        AppColors.surfaceDark.withOpacity(0.96),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(
      color: Colors.white.withOpacity(glow ? 0.14 : 0.08),
    ),
    boxShadow: glow
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 50,
              spreadRadius: 18,
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 32,
              spreadRadius: 10,
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
    fillColor: AppColors.surface.withOpacity(0.9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: Colors.white.withOpacity(0.12),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: Colors.white.withOpacity(0.08),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: AppColors.accent.withOpacity(0.8),
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  );
}
