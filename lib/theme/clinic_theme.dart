import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClinicThemeData {
  final Gradient backgroundGradient;
  final double horizontalPadding;
  final double verticalPadding;
  final double maxContentWidth;
  final SystemUiOverlayStyle overlayStyle;

  const ClinicThemeData({
    this.backgroundGradient = const RadialGradient(
      center: Alignment.topCenter,
      radius: 1.5,
      colors: [
        Color(0xFF1f2937),
        Color(0xFF020617),
        Color(0xFF000000),
      ],
      stops: [0.0, 0.45, 1.0],
    ),
    this.horizontalPadding = 24,
    this.verticalPadding = 24,
    this.maxContentWidth = 1200,
    this.overlayStyle = const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  });

  ClinicThemeData copyWith({
    Gradient? backgroundGradient,
    double? horizontalPadding,
    double? verticalPadding,
    double? maxContentWidth,
    SystemUiOverlayStyle? overlayStyle,
  }) {
    return ClinicThemeData(
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      verticalPadding: verticalPadding ?? this.verticalPadding,
      maxContentWidth: maxContentWidth ?? this.maxContentWidth,
      overlayStyle: overlayStyle ?? this.overlayStyle,
    );
  }
}

class ClinicTheme extends InheritedWidget {
  final ClinicThemeData data;

  const ClinicTheme({
    Key? key,
    this.data = const ClinicThemeData(),
    required Widget child,
  }) : super(key: key, child: child);

  static ClinicThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<ClinicTheme>();
    return theme?.data ?? const ClinicThemeData();
  }

  @override
  bool updateShouldNotify(covariant ClinicTheme oldWidget) {
    return data != oldWidget.data;
  }
}

class ClinicPageShell extends StatelessWidget {
  final Widget child;

  const ClinicPageShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = ClinicTheme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final viewPadding = mediaQuery.viewPadding;

    final resolvedPadding = EdgeInsets.only(
      left: math.max(data.horizontalPadding, viewPadding.left),
      right: math.max(data.horizontalPadding, viewPadding.right),
      top: math.max(data.verticalPadding, viewPadding.top),
      bottom: math.max(data.verticalPadding, viewPadding.bottom),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: data.overlayStyle,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: data.backgroundGradient,
        ),
        child: Padding(
          padding: resolvedPadding,
          child: child,
        ),
      ),
    );
  }
}

typedef ClinicResponsiveBuilder = Widget Function(
  BuildContext context,
  BoxConstraints constraints,
);

class ClinicContentLayout extends StatelessWidget {
  final ClinicResponsiveBuilder builder;

  const ClinicContentLayout({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = ClinicTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: data.maxContentWidth,
              ),
              child: LayoutBuilder(
                builder: (context, innerConstraints) {
                  return builder(context, innerConstraints);
                },
              ),
            ),
          ),
        );

        return SingleChildScrollView(
          child: content,
        );
      },
    );
  }
}
