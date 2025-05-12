import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class YOLOv8 {
  late Interpreter _interpreter;
  bool _isInitialized = false;

  Future<void> initialize() async {
    try {
      // Load the TFLite model
      _interpreter = await Interpreter.fromAsset('assets/models/your_model.tflite');
      _isInitialized = true;
      print("YOLOv8 Model Loaded Successfully!");
    } catch (e) {
      print("Failed to load YOLOv8 Model: $e");
    }
  }

  Future<List<dynamic>> detectObjects(Uint8List imageData) async {
    if (!_isInitialized) {
      print("Model not initialized");
      return [];
    }

    // Prepare input tensor (depends on your model input shape)
    var input = [imageData];

    // Prepare output tensor (depends on model output shape)
    var output = List.filled(1, List.filled(6, 0.0));

    _interpreter.run(input, output);
    return output;
  }
}
