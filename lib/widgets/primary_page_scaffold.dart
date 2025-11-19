import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/system_ui.dart';
import '../utils/decorations.dart';

class PrimaryPageScaffold extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  const PrimaryPageScaffold({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.padding = const EdgeInsets.all(36),
  });

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.of(context).viewPadding;
    final contentPadding = EdgeInsets.only(
      left: 24 + viewPadding.left,
      right: 24 + viewPadding.right,
      top: 24 + viewPadding.top,
      bottom: 24 + viewPadding.bottom,
    );

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
          child: Padding(
            padding: contentPadding,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth,
                        minHeight: constraints.maxHeight,
                      ),
                      child: Container(
                        decoration: buildPrimaryPanelDecoration(),
                        child: Padding(
                          padding: padding,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
