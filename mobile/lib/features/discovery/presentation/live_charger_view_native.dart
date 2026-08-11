import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LiveChargerPlatformView extends StatefulWidget {
  const LiveChargerPlatformView({super.key, required this.uri});

  final Uri uri;

  @override
  State<LiveChargerPlatformView> createState() =>
      _LiveChargerPlatformViewState();
}

class _LiveChargerPlatformViewState extends State<LiveChargerPlatformView> {
  WebViewController? _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFF4F7F2))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
          ),
        )
        ..loadRequest(widget.uri);
    } catch (_) {
      // Widget tests and unsupported desktop hosts may not register a WebView.
      _controller = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return ColoredBox(
        key: const Key('liveChargerPlatformView'),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'The live charger map is available in the web, Android, and iOS app builds.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Stack(
      key: const Key('liveChargerPlatformView'),
      children: [
        Positioned.fill(child: WebViewWidget(controller: controller)),
        if (_progress < 100)
          Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(value: _progress / 100),
          ),
      ],
    );
  }
}
