import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:animate_do/animate_do.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;

  const CameraPreviewWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Semantics(
        label: 'Camera Loading',
        child: Center(
          child: ZoomIn(
            child: GlassmorphicContainer(
              width: 100,
              height: 100,
              borderRadius: 50,
              blur: 15,
              alignment: Alignment.center,
              border: 2,
              linearGradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.3),
                  Colors.purple.withOpacity(0.3),
                ],
              ),
              borderGradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.purpleAccent],
              ),
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 4,
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(label: 'Camera Preview', child: CameraPreview(controller));
  }
}
