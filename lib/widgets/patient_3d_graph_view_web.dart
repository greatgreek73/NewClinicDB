import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

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
  late final String _viewType;
  late final html.IFrameElement _iframe;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _viewType =
        'patient-3d-graph-${DateTime.now().microsecondsSinceEpoch}-${widget.hashCode}';

    _iframe =
        html.IFrameElement()
          ..src = widget.assetPath
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%';

    _iframe.onLoad.listen((_) {
      _isLoaded = true;
      _postData();
      _postOptions();
    });

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe,
    );
  }

  @override
  void didUpdateWidget(covariant Patient3DGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _iframe.src = widget.assetPath;
    }

    if (oldWidget.data != widget.data) {
      _postData();
    }
    if (oldWidget.options != widget.options) {
      _postOptions();
    }
  }

  void _postData() {
    if (!_isLoaded) return;
    final payload = jsonEncode(widget.data);
    _iframe.contentWindow?.postMessage(
      {'type': 'setGraphData', 'payload': payload},
      '*',
    );
  }

  void _postOptions() {
    if (!_isLoaded) return;
    if (widget.options == null) return;
    final payload = jsonEncode(widget.options);
    _iframe.contentWindow?.postMessage(
      {'type': 'setGraphOptions', 'payload': payload},
      '*',
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
