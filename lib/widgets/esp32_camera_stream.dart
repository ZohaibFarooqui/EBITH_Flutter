import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ESP32CameraStream extends StatelessWidget {
  final WebViewController controller;

  ESP32CameraStream({super.key})
      : controller = WebViewController()
          ..loadRequest(Uri.parse('http://192.168.18.209'));

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: controller);
  }
}