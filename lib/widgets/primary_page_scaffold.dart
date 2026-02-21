import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/system_ui.dart';
import '../utils/decorations.dart';

class PrimaryPageScaffold extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const PrimaryPageScaffold({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(36),
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kClinicOverlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.4,
              colors: [
                AppColors.accentStrong.withOpacity(0.25),
                AppColors.bgMid,
                AppColors.bg,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Container(
                    width: double.infinity,
                    decoration: buildPrimaryPanelDecoration(),
                    child: SafeArea(
                      child: Padding(padding: padding, child: child),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
