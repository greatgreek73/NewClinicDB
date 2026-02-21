import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../theme/app_colors.dart';

const double _kPerspective = 5.0;

enum Patient3DStatus { scheduled, urgent, debt, ok, missed }

class Patient3DNode {
  final String id;
  final String name;
  final String? subtitle;
  final Patient3DStatus status;
  final vm.Vector3 offset;

  const Patient3DNode({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.status,
    required this.offset,
  });
}

class Patient3DFamily {
  final String id;
  final String name;
  final Color color;
  final vm.Vector3 position;
  final List<Patient3DNode> patients;

  const Patient3DFamily({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
    required this.patients,
  });
}

typedef Patient3DNodeTapCallback =
    void Function(Patient3DNode patient, Patient3DFamily family);

class Patient3DGraphCanvas extends StatefulWidget {
  final List<Patient3DFamily> families;
  final double autoRotateSpeed;
  final Patient3DNodeTapCallback? onPatientTap;

  const Patient3DGraphCanvas({
    super.key,
    required this.families,
    required this.autoRotateSpeed,
    this.onPatientTap,
  });

  @override
  State<Patient3DGraphCanvas> createState() => _Patient3DGraphCanvasState();
}

class _Patient3DGraphCanvasState extends State<Patient3DGraphCanvas>
    with SingleTickerProviderStateMixin {
  static const double _minZoom = 6;
  static const double _maxZoom = 20;
  static const double _dragSpeed = 0.01;
  static const double _damping = 3.2;
  static const double _familyWorldRadius = 1.0;
  static const double _patientWorldRadius = 0.38;
  static const double _pulseAmplitude = 0.05;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _timeSeconds = 0;

  bool _autoRotate = true;

  double _rotationX = 0;
  double _rotationY = 0;
  double _targetRotationX = 0;
  double _targetRotationY = 0;

  double _zoom = 12;
  double _zoomStart = 12;

  _HitTarget? _hovered;
  _HitTarget? _selected;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (kIsWeb && _lastTick != Duration.zero) {
      if (elapsed - _lastTick < const Duration(milliseconds: 33)) {
        return;
      }
    }

    final dt =
        elapsed == Duration.zero
            ? 0.016
            : (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;

    final clampedDt = dt.isFinite ? dt.clamp(0.0, 0.05) : 0.016;
    final shouldPulse = !kIsWeb && _pulseAmplitude > 0;
    if (shouldPulse) {
      _timeSeconds += clampedDt;
    }

    final autoRotateActive = _autoRotate && widget.autoRotateSpeed > 0;
    if (_autoRotate && widget.autoRotateSpeed > 0) {
      _targetRotationY += widget.autoRotateSpeed * clampedDt;
    }

    final t = 1 - math.exp(-_damping * clampedDt);
    _rotationY += (_targetRotationY - _rotationY) * t;
    _rotationX += (_targetRotationX - _rotationX) * t;

    final isSettled =
        (_targetRotationX - _rotationX).abs() < 0.0002 &&
        (_targetRotationY - _rotationY).abs() < 0.0002;
    if (!autoRotateActive && isSettled && !shouldPulse) {
      return;
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails _) {
    if (!_autoRotate) return;
    setState(() {
      _autoRotate = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _targetRotationY += details.delta.dx * _dragSpeed;
      _targetRotationX += details.delta.dy * _dragSpeed;
      _targetRotationX = _targetRotationX.clamp(-math.pi / 3, math.pi / 3);
    });
  }

  void _onScaleStart(ScaleStartDetails _) {
    _zoomStart = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale == 1.0) return;
    setState(() {
      _zoom = (_zoomStart / details.scale).clamp(_minZoom, _maxZoom);
    });
  }

  void _onPointerSignal(PointerSignalEvent event, Size size) {
    if (event is! PointerScrollEvent) return;
    setState(() {
      _zoom = (_zoom + event.scrollDelta.dy * 0.01).clamp(_minZoom, _maxZoom);
    });
    _updateHover(event.localPosition, size);
  }

  void _onHover(PointerHoverEvent event, Size size) {
    _updateHover(event.localPosition, size);
  }

  void _onExit(PointerExitEvent _) {
    if (_hovered == null) return;
    setState(() {
      _hovered = null;
    });
  }

  void _onTapDown(TapDownDetails details, Size size) {
    final hit = _hitTest(size, details.localPosition);
    setState(() {
      _selected = hit;
      _hovered = hit;
    });
  }

  void _updateHover(Offset localPosition, Size size) {
    final hit = _hitTest(size, localPosition);
    if (_hovered == hit) return;
    setState(() {
      _hovered = hit;
    });
  }

  _HitTarget? _hitTest(Size size, Offset localPosition) {
    if (size.isEmpty) return null;
    if (widget.families.isEmpty) return null;

    final targets = _buildHitTargets(size);
    _HitTarget? best;
    double bestDepth = double.negativeInfinity;
    double bestDistance = double.infinity;

    for (final target in targets) {
      final distance = (target.center - localPosition).distance;
      if (distance > target.radius) continue;

      final depth = -target.z;
      if (depth > bestDepth || (depth == bestDepth && distance < bestDistance)) {
        bestDepth = depth;
        bestDistance = distance;
        best = target;
      }
    }

    return best;
  }

  List<_HitTarget> _buildHitTargets(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = math.min(size.width, size.height) / _zoom;

    final targets = <_HitTarget>[];
    for (final family in widget.families) {
      final familyProjected = _project(
        point: family.position,
        rotationX: _rotationX,
        rotationY: _rotationY,
        center: center,
        scale: scale,
      );
      final familyRadius = _familyWorldRadius * scale * familyProjected.factor;
      targets.add(
        _HitTarget.family(
          family: family,
          center: familyProjected.offset,
          radius: familyRadius,
          z: familyProjected.z,
        ),
      );

      for (final patient in family.patients) {
        final patientPos = family.position + patient.offset;
        final projected = _project(
          point: patientPos,
          rotationX: _rotationX,
          rotationY: _rotationY,
          center: center,
          scale: scale,
        );
        final pulseAmplitude = kIsWeb ? 0.0 : _pulseAmplitude;
        final pulse =
            1 +
            math.sin(_timeSeconds * 2.0 + targets.length) *
                pulseAmplitude;
        final radius =
            _patientWorldRadius * pulse * scale * projected.factor;
        targets.add(
          _HitTarget.patient(
            family: family,
            patient: patient,
            center: projected.offset,
            radius: radius,
            z: projected.z,
          ),
        );
      }
    }

    return targets;
  }

  @override
  Widget build(BuildContext context) {
    final activeTarget = _selected ?? _hovered;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: MouseRegion(
                onHover: (event) => _onHover(event, size),
                onExit: _onExit,
                child: Listener(
                  onPointerSignal: (event) => _onPointerSignal(event, size),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onTapDown: (details) => _onTapDown(details, size),
                    child: CustomPaint(
                      painter: _Patient3DGraphPainter(
                        families: widget.families,
                        rotationX: _rotationX,
                        rotationY: _rotationY,
                        zoom: _zoom,
                        timeSeconds: _timeSeconds,
                        hovered: _hovered,
                        selected: _selected,
                        lowQuality: kIsWeb,
                      ),
                      size: Size.infinite,
                      isComplex: true,
                      willChange: true,
                    ),
                  ),
                ),
              ),
            ),
            if (activeTarget != null)
              Positioned(
                left: 14,
                top: 14,
                child: _GraphTooltip(
                  target: activeTarget,
                  onOpenPatient:
                      activeTarget.type == _HitTargetType.patient
                          ? () {
                            final patient = activeTarget.patient!;
                            final family = activeTarget.family;
                            widget.onPatientTap?.call(patient, family);
                          }
                          : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _HitTargetType { family, patient }

class _HitTarget {
  final _HitTargetType type;
  final Patient3DFamily family;
  final Patient3DNode? patient;
  final Offset center;
  final double radius;
  final double z;

  const _HitTarget._({
    required this.type,
    required this.family,
    required this.patient,
    required this.center,
    required this.radius,
    required this.z,
  });

  factory _HitTarget.family({
    required Patient3DFamily family,
    required Offset center,
    required double radius,
    required double z,
  }) {
    return _HitTarget._(
      type: _HitTargetType.family,
      family: family,
      patient: null,
      center: center,
      radius: radius,
      z: z,
    );
  }

  factory _HitTarget.patient({
    required Patient3DFamily family,
    required Patient3DNode patient,
    required Offset center,
    required double radius,
    required double z,
  }) {
    return _HitTarget._(
      type: _HitTargetType.patient,
      family: family,
      patient: patient,
      center: center,
      radius: radius,
      z: z,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _HitTarget &&
        other.type == type &&
        other.family.id == family.id &&
        other.patient?.id == patient?.id;
  }

  @override
  int get hashCode => Object.hash(type, family.id, patient?.id);
}

class _GraphTooltip extends StatelessWidget {
  final _HitTarget target;
  final VoidCallback? onOpenPatient;

  const _GraphTooltip({required this.target, required this.onOpenPatient});

  Color _statusColor(Patient3DStatus status) {
    switch (status) {
      case Patient3DStatus.scheduled:
        return const Color(0xFF3B82F6);
      case Patient3DStatus.urgent:
        return const Color(0xFFEF4444);
      case Patient3DStatus.debt:
        return const Color(0xFFF97316);
      case Patient3DStatus.ok:
        return const Color(0xFF22C55E);
      case Patient3DStatus.missed:
        return const Color(0xFFEAB308);
    }
  }

  String _statusLabel(Patient3DStatus status) {
    switch (status) {
      case Patient3DStatus.scheduled:
        return 'Scheduled';
      case Patient3DStatus.urgent:
        return 'Urgent';
      case Patient3DStatus.debt:
        return 'Debt';
      case Patient3DStatus.ok:
        return 'OK';
      case Patient3DStatus.missed:
        return 'Missed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPatient = target.type == _HitTargetType.patient;
    final patient = target.patient;

    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 30,
            spreadRadius: 8,
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: AppColors.textPrimary),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isPatient ? patient!.name : target.family.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              isPatient
                  ? target.family.name
                  : 'Patients: ${target.family.patients.length}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted.withOpacity(0.85),
              ),
            ),
            if (isPatient && (patient?.subtitle?.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 4),
              Text(
                patient!.subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted.withOpacity(0.85),
                ),
              ),
            ],
            if (isPatient) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(patient!.status),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(patient.status),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onOpenPatient != null)
                    TextButton(
                      onPressed: onOpenPatient,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                      ),
                      child: const Text(
                        'Open profile',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Patient3DGraphPainter extends CustomPainter {
  final List<Patient3DFamily> families;
  final double rotationX;
  final double rotationY;
  final double zoom;
  final double timeSeconds;
  final _HitTarget? hovered;
  final _HitTarget? selected;
  final bool lowQuality;

  _Patient3DGraphPainter({
    required this.families,
    required this.rotationX,
    required this.rotationY,
    required this.zoom,
    required this.timeSeconds,
    required this.hovered,
    required this.selected,
    required this.lowQuality,
  });

  static const double _familyWorldRadius = 1.0;
  static const double _patientWorldRadius = 0.38;
  static const double _pulseAmplitude = 0.05;

  @override
  void paint(Canvas canvas, Size size) {
    if (families.isEmpty) return;

    final rect = Offset.zero & size;
    final bgPaint =
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.2, -0.2),
            radius: 1.2,
            colors: [
              AppColors.accentStrong.withOpacity(0.10),
              AppColors.bgMid.withOpacity(0.86),
              AppColors.bg.withOpacity(0.96),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final center = Offset(size.width / 2, size.height / 2);
    final scale = math.min(size.width, size.height) / zoom;
    final drawables = <_Drawable3D>[];

    // Family center connections (dashed)
    final familyConnections = <List<int>>[
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 0],
      [0, 2],
    ];
    for (final conn in familyConnections) {
      if (conn[0] >= families.length || conn[1] >= families.length) continue;
      final a = families[conn[0]];
      final b = families[conn[1]];
      final pa = _project(
        point: a.position,
        rotationX: rotationX,
        rotationY: rotationY,
        center: center,
        scale: scale,
      );
      final pb = _project(
        point: b.position,
        rotationX: rotationX,
        rotationY: rotationY,
        center: center,
        scale: scale,
      );
      final z = (pa.z + pb.z) / 2 + 0.2;
      drawables.add(
        _Drawable3D(
          z: z,
          draw:
              (c) => _drawDashedLine(
                c,
                pa.offset,
                pb.offset,
                const Color(0xFFA78BFA).withOpacity(0.26),
              ),
        ),
      );
    }

    int pulseIndex = 0;
    final pulseAmplitude = lowQuality ? 0.0 : _pulseAmplitude;
    for (final family in families) {
      final familyProjected = _project(
        point: family.position,
        rotationX: rotationX,
        rotationY: rotationY,
        center: center,
        scale: scale,
      );

      final familyRadius =
          _familyWorldRadius * scale * familyProjected.factor;

      final familyIsActive =
          (selected?.type == _HitTargetType.family &&
              selected?.family.id == family.id) ||
          (selected == null &&
              hovered?.type == _HitTargetType.family &&
              hovered?.family.id == family.id);

      for (final patient in family.patients) {
        final patientWorldPos = family.position + patient.offset;
        final projected = _project(
          point: patientWorldPos,
          rotationX: rotationX,
          rotationY: rotationY,
          center: center,
          scale: scale,
        );
        final avgZ = (familyProjected.z + projected.z) / 2 + 0.12;

        drawables.add(
          _Drawable3D(
            z: avgZ,
            draw: (c) {
              final paint =
                  Paint()
                    ..color = family.color.withOpacity(0.45)
                    ..strokeWidth = lowQuality ? 1.2 : 1.6;
              c.drawLine(familyProjected.offset, projected.offset, paint);
            },
          ),
        );

        final pulse =
            1 + math.sin(timeSeconds * 2.0 + pulseIndex) * pulseAmplitude;
        pulseIndex++;
        final patientRadius =
            _patientWorldRadius * pulse * scale * projected.factor;

        final patientIsActive =
            (selected?.type == _HitTargetType.patient &&
                selected?.patient?.id == patient.id) ||
            (selected == null &&
                hovered?.type == _HitTargetType.patient &&
                hovered?.patient?.id == patient.id);

        drawables.add(
          _Drawable3D(
            z: projected.z,
            draw:
                (c) => _drawSphere(
                  c,
                  projected.offset,
                  patientRadius,
                  _statusColor(patient.status),
                  glowIntensity: 0.28,
                  active: patientIsActive,
                ),
          ),
        );
      }

      drawables.add(
        _Drawable3D(
          z: familyProjected.z,
          draw:
              (c) => _drawSphere(
                c,
                familyProjected.offset,
                familyRadius,
                family.color,
                glowIntensity: 0.32,
                glowRadius: 14,
                active: familyIsActive,
              ),
        ),
      );
    }

    drawables.sort((a, b) => b.z.compareTo(a.z));
    for (final d in drawables) {
      d.draw(canvas);
    }
  }

  Color _statusColor(Patient3DStatus status) {
    switch (status) {
      case Patient3DStatus.scheduled:
        return const Color(0xFF3B82F6);
      case Patient3DStatus.urgent:
        return const Color(0xFFEF4444);
      case Patient3DStatus.debt:
        return const Color(0xFFF97316);
      case Patient3DStatus.ok:
        return const Color(0xFF22C55E);
      case Patient3DStatus.missed:
        return const Color(0xFFEAB308);
    }
  }

  void _drawSphere(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    required double glowIntensity,
    double glowRadius = 10,
    required bool active,
  }) {
    if (lowQuality) {
      final glowPaint = Paint()..color = color.withOpacity(glowIntensity * 0.65);
      canvas.drawCircle(center, radius * 1.25, glowPaint);

      final spherePaint = Paint()..color = color;
      canvas.drawCircle(center, radius, spherePaint);

      if (active) {
        final outline =
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2.0, radius * 0.08)
              ..color = Colors.white.withOpacity(0.70);
        canvas.drawCircle(center, radius * 1.05, outline);
      }
      return;
    }

    final glowPaint =
        Paint()
          ..color = color.withOpacity(glowIntensity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);
    canvas.drawCircle(center, radius * 1.25, glowPaint);

    final gradient = RadialGradient(
      center: const Alignment(-0.32, -0.32),
      radius: 0.85,
      colors: [
        Color.lerp(color, Colors.white, 0.42)!,
        color,
        Color.lerp(color, Colors.black, 0.32)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final spherePaint =
        Paint()
          ..shader = gradient.createShader(
            Rect.fromCircle(center: center, radius: radius),
          );
    canvas.drawCircle(center, radius, spherePaint);

    final highlightPaint = Paint()..color = Colors.white.withOpacity(0.38);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
      radius * 0.18,
      highlightPaint,
    );

    if (active) {
      final outline =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.0, radius * 0.08)
            ..color = Colors.white.withOpacity(0.75);
      canvas.drawCircle(center, radius * 1.05, outline);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Color color) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1.4;

    const dashLength = 8.0;
    const gapLength = 5.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance <= 0.001) return;

    final steps = (distance / (dashLength + gapLength)).floor();
    for (int i = 0; i < steps; i++) {
      final t1 = i * (dashLength + gapLength) / distance;
      final t2 = (i * (dashLength + gapLength) + dashLength) / distance;
      if (t2 > 1) break;
      canvas.drawLine(
        Offset(p1.dx + dx * t1, p1.dy + dy * t1),
        Offset(p1.dx + dx * t2, p1.dy + dy * t2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Patient3DGraphPainter oldDelegate) {
    return oldDelegate.families != families ||
        oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoom != zoom ||
        oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.hovered != hovered ||
        oldDelegate.selected != selected ||
        oldDelegate.lowQuality != lowQuality;
  }
}

class _ProjectedPoint {
  final Offset offset;
  final double z;
  final double factor;

  _ProjectedPoint({required this.offset, required this.z, required this.factor});
}

_ProjectedPoint _project({
  required vm.Vector3 point,
  required double rotationX,
  required double rotationY,
  required Offset center,
  required double scale,
}) {
  final rotated = _rotatePoint(point, rotationX, rotationY);
  final factor = _kPerspective / (_kPerspective + rotated.z);
  return _ProjectedPoint(
    offset: Offset(
      center.dx + rotated.x * scale * factor,
      center.dy - rotated.y * scale * factor,
    ),
    z: rotated.z,
    factor: factor,
  );
}

vm.Vector3 _rotatePoint(vm.Vector3 point, double rx, double ry) {
  final cosY = math.cos(ry);
  final sinY = math.sin(ry);
  final cosX = math.cos(rx);
  final sinX = math.sin(rx);

  final x1 = point.x * cosY - point.z * sinY;
  var z1 = point.x * sinY + point.z * cosY;

  final y2 = point.y * cosX - z1 * sinX;
  z1 = point.y * sinX + z1 * cosX;

  return vm.Vector3(x1, y2, z1);
}

class _Drawable3D {
  final double z;
  final void Function(Canvas) draw;

  _Drawable3D({required this.z, required this.draw});
}
