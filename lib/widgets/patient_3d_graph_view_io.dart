import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_colors.dart';

class Patient3DGraphView extends StatefulWidget {
  final Object? data;
  final Object? options;
  final String assetPath;

  const Patient3DGraphView({
    super.key,
    required this.data,
    this.options,
    this.assetPath = 'assets/patient_3d_graph.html',
  });

  @override
  State<Patient3DGraphView> createState() => _Patient3DGraphViewState();
}

class _Patient3DGraphViewState extends State<Patient3DGraphView> {
  late final WebViewController _controller;
  bool _isPageLoaded = false;

  bool get _isSupported {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (!_isSupported) return;

    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (_) {
                _isPageLoaded = true;
                _pushData();
                _pushOptions();
              },
            ),
          )
          ..loadFlutterAsset(widget.assetPath);
  }

  @override
  void didUpdateWidget(covariant Patient3DGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSupported || !_isPageLoaded) return;
    if (oldWidget.data != widget.data) {
      _pushData();
    }
    if (oldWidget.options != widget.options) {
      _pushOptions();
    }
  }

  Future<void> _pushData() async {
    if (!_isSupported || !_isPageLoaded) return;
    final jsonPayload = jsonEncode(widget.data);
    final jsArg = jsonEncode(jsonPayload);
    try {
      await _controller.runJavaScript('setGraphData($jsArg);');
    } catch (_) {}
  }

  Future<void> _pushOptions() async {
    if (!_isSupported || !_isPageLoaded) return;
    if (widget.options == null) return;
    final jsonPayload = jsonEncode(widget.options);
    final jsArg = jsonEncode(jsonPayload);
    try {
      await _controller.runJavaScript('setGraphOptions($jsArg);');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupported) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withOpacity(0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        padding: const EdgeInsets.all(16),
        child: const Text(
          '3D view is not supported on this platform.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return WebViewWidget(
      controller: _controller,
      gestureRecognizers: {
        Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
      },
    );
  }
}
