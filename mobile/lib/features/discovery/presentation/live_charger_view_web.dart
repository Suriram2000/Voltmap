import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class LiveChargerPlatformView extends StatefulWidget {
  const LiveChargerPlatformView({super.key, required this.uri});

  final Uri uri;

  @override
  State<LiveChargerPlatformView> createState() =>
      _LiveChargerPlatformViewState();
}

class _LiveChargerPlatformViewState extends State<LiveChargerPlatformView> {
  static int _nextViewId = 0;
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'voltmapev-live-chargers-${_nextViewId++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      return web.HTMLIFrameElement()
        ..src = widget.uri.toString()
        ..title = 'Live EV charging stations near the selected area'
        ..allow = 'geolocation'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: const Key('liveChargerPlatformView'),
      viewType: _viewType,
    );
  }
}
