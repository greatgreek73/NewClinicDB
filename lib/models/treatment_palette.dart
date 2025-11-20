import 'dart:math';

import 'package:flutter/material.dart';

/// Определяет устойчивые цвета для типов лечения, чтобы легенда и метки были стабильны.
class TreatmentPalette {
  TreatmentPalette({Color? fallback})
      : _fallback = fallback ?? Colors.blueGrey.shade400;

  final Color _fallback;
  final Map<String, Color> _cache = {};

  Color colorFor(String type) {
    if (type.isEmpty) return _fallback;
    return _cache.putIfAbsent(type, () => _generateColor(type));
  }

  /// Детеминированное преобразование строки в мягкий цвет.
  Color _generateColor(String seed) {
    final hash = seed.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    final rand = Random(hash);
    final hue = rand.nextDouble() * 360;
    final saturation = 0.55 + rand.nextDouble() * 0.25; // 0.55-0.8
    final lightness = 0.45 + rand.nextDouble() * 0.2; // 0.45-0.65
    return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
  }
}
