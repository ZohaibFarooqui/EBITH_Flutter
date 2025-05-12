import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:animate_do/animate_do.dart';
import 'package:vibration/vibration.dart';
import '../services/voice_navigation_service.dart';
import '../widgets/camera_preview.dart';
import '../widgets/esp32_camera_stream.dart';
import '../models/yolov8.dart';

class BlindScreen extends StatefulWidget {
  final CameraController cameraController;
  bool useESP32;

  BlindScreen({
    Key? key,
    required this.cameraController,
    required this.useESP32,
  }) : super(key: key);

  @override
  State<BlindScreen> createState() => _BlindScreenState();
}

class _BlindScreenState extends State<BlindScreen>
    with SingleTickerProviderStateMixin {
  late YOLOv8 _objectDetectionModel;
  final VoiceNavigationService _voiceService = VoiceNavigationService();
  bool _isNavigating = false;
  bool _isSpeaking = false;
  bool _isEnglish = true;
  bool _isDetecting = false;
  var logger = Logger();
  Timer? _detectionTimer;
  List<String> _spokenWarnings = [];

  final String backendURL = 'http://192.168.18.87:5000/detect';
  final String esp32SnapshotURL = 'http://192.168.18.209/capture';

  late AnimationController _gradientController;
  late Animation<Color?> _color1Animation;
  late Animation<Color?> _color2Animation;

  @override
  void initState() {
    super.initState();
    _objectDetectionModel = YOLOv8();
    _loadLanguagePreference();

    _detectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isNavigating) _startObjectDetection();
    });

    // Initialize gradient animation
    _gradientController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);
    _color1Animation = ColorTween(
      begin: const Color(0xFF00FFFF).withOpacity(0.2), // Neon Blue
      end: const Color(0xFFFF00FF).withOpacity(0.2), // Pink
    ).animate(_gradientController);
    _color2Animation = ColorTween(
      begin: const Color(0xFFFF00FF).withOpacity(0.2), // Pink
      end: const Color(0xFF00FFFF).withOpacity(0.2), // Neon Blue
    ).animate(_gradientController);
  }

  Future<void> _loadLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isEnglish = prefs.getBool('isEnglish') ?? true;
    });
    _speak("Welcome to the Blind Screen!", "نابینا اسکرین شروع ہو گئی ہے۔");
  }

  Future<void> _toggleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isEnglish = !_isEnglish;
      prefs.setBool('isEnglish', _isEnglish);
    });
  }

  void _speak(String englishText, String urduText) async {
    if (_isSpeaking) return;
    _isSpeaking = true;
    await _voiceService.speak(_isEnglish ? englishText : urduText);
    _isSpeaking = false;
  }

  void _startObjectDetection() async {
    if (!mounted || _isDetecting) return;
    setState(() => _isDetecting = true);

    try {
      Uint8List imageBytes;

      if (widget.useESP32) {
        var response = await http.get(Uri.parse(esp32SnapshotURL));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
        } else {
          logger.d("ESP32 snapshot failed: ${response.statusCode}");
          _speak("ESP32 camera error.", "ای ایس پی 32 کیمرہ خرابی۔");
          setState(() => _isDetecting = false);
          return;
        }
      } else {
        if (!widget.cameraController.value.isInitialized) {
          logger.d("Camera not initialized");
          _speak("Camera not initialized.", "کیمرہ شروع نہیں ہوا۔");
          setState(() => _isDetecting = false);
          return;
        }
        final image = await widget.cameraController.takePicture();
        imageBytes = await image.readAsBytes();
      }

      await _detectObjects(imageBytes);
    } catch (e) {
      logger.d("Error during object detection: $e");
      _speak("Object detection error.", "شے کا پتہ لگانے میں خرابی۔");
    } finally {
      setState(() => _isDetecting = false);
    }
  }

  Future<void> _detectObjects(Uint8List imageData) async {
    try {
      final response = await _sendImageToBackend(imageData);
      if (response != null) {
        var detectedObjects = response['detections'];
        logger.d("Detected Objects: $detectedObjects");

        if (detectedObjects.isEmpty) return;

        for (var obj in detectedObjects) {
          String objectName = obj['class'] ?? 'Unknown';
          double distance = obj.containsKey('distance') ? obj['distance'] : 0.0;

          if (distance > 1.0) continue;

          String warningMessage = "Warning! $objectName detected nearby.";
          String urduMessage = "انتباہ! $objectName قریب ہے۔";

          if (!_spokenWarnings.contains(warningMessage)) {
            _spokenWarnings.add(warningMessage);
            if (_spokenWarnings.length > 5) _spokenWarnings.removeAt(0);
            _speak(warningMessage, urduMessage);
          }
        }
      }
    } catch (e) {
      logger.d("Detection error: $e");
      _speak("Detection error.", "پتہ لگانے میں خرابی۔");
    }
  }

  Future<Map<String, dynamic>?> _sendImageToBackend(Uint8List imageData) async {
    var uri = Uri.parse(backendURL);
    var request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes('image', imageData, filename: 'image.jpg'),
      );

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        return jsonDecode(responseBody);
      } else {
        logger.d("Backend error: ${response.statusCode}");
        _speak("Backend error.", "بیک اینڈ خرابی۔");
        return null;
      }
    } catch (e) {
      logger.d("Error sending image: $e");
      _speak("Network error.", "نیٹ ورک خرابی۔");
      return null;
    }
  }

  void _toggleCamera() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
    setState(() {
      widget.useESP32 = !widget.useESP32;
    });
    _speak(
      widget.useESP32
          ? "Switched to ESP32 camera."
          : "Switched to Phone camera.",
      widget.useESP32
          ? "ای ایس پی 32 کیمرہ پر سوئچ کیا گیا۔"
          : "فون کیمرہ پر سوئچ کیا گیا۔",
    );
  }

  void _toggleNavigation() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
    setState(() {
      _isNavigating = !_isNavigating;
    });
    _speak(
      _isNavigating ? "Navigation started." : "Navigation stopped.",
      _isNavigating ? "نیویگیشن شروع ہو گئی ہے۔" : "نیویگیشن روک دی گئی ہے۔",
    );
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Gradient Background
          AnimatedBuilder(
            animation: _gradientController,
            builder: (context, child) {
              return Container(
                color: const Color(0xFF1A1A2E), // Dark background
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _color1Animation.value ??
                            const Color(
                              0xFF00FFFF,
                            ).withOpacity(0.2), // Neon Blue
                        _color2Animation.value ??
                            const Color(0xFFFF00FF).withOpacity(0.2), // Pink
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              );
            },
          ),
          // Camera Preview or ESP32 Stream
          widget.useESP32
              ? ESP32CameraStream()
              : CameraPreviewWidget(controller: widget.cameraController),
          // Top HUD: Language Toggle and Status Indicator
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BounceInDown(
                  child: GestureDetector(
                    onTap: _toggleLanguage,
                    child: GlassmorphicContainer(
                      width: 120,
                      height: 40,
                      borderRadius: 20,
                      blur: 15,
                      alignment: Alignment.center,
                      border: 1,
                      linearGradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.2),
                          const Color(0xFF00FFFF).withOpacity(0.2), // Neon Blue
                        ],
                      ),
                      borderGradient: LinearGradient(
                        colors: [
                          const Color(0xFF00FFFF), // Neon Blue
                          const Color(0xFFFF00FF), // Pink
                        ],
                      ),
                      child: Semantics(
                        label: 'Toggle Language',
                        child: Text(
                          _isEnglish ? "English" : "اردو",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Pulse(
                  child: Semantics(
                    label: _isDetecting ? 'Processing' : 'Idle',
                    child: Image.asset(
                      'assets/icons/status_${_isDetecting ? "processing" : "idle"}.png',
                      width: 32,
                      height: 32,
                      errorBuilder:
                          (context, error, stackTrace) => SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              color:
                                  _isDetecting
                                      ? const Color(0xFFFF00FF)
                                      : Colors.grey, // Pink when detecting
                              strokeWidth: 2,
                            ),
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Camera Toggle Button
          Positioned(
            bottom: 80,
            right: 20,
            child: ElasticIn(
              child: GestureDetector(
                onTap: _toggleCamera,
                child: GlassmorphicContainer(
                  width: 60,
                  height: 60,
                  borderRadius: 30,
                  blur: 15,
                  alignment: Alignment.center,
                  border: 2,
                  linearGradient: LinearGradient(
                    colors: [
                      const Color(0xFF00FFFF).withOpacity(0.3), // Neon Blue
                      const Color(0xFFFF00FF).withOpacity(0.3), // Pink
                    ],
                  ),
                  borderGradient: LinearGradient(
                    colors: [
                      const Color(0xFF00FFFF), // Neon Blue
                      const Color(0xFFFF00FF), // Pink
                    ],
                  ),
                  child: Semantics(
                    label: 'Toggle Camera Source',
                    child: Image.asset(
                      'assets/icons/camera_toggle.png',
                      width: 32,
                      height: 32,
                      errorBuilder:
                          (context, error, stackTrace) =>
                              Icon(Icons.camera, color: Colors.white, size: 32),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Navigation Toggle Button
          Positioned(
            bottom: 20,
            right: 20,
            child: ElasticIn(
              child: GestureDetector(
                onTap: _toggleNavigation,
                child: GlassmorphicContainer(
                  width: 60,
                  height: 60,
                  borderRadius: 30,
                  blur: 15,
                  alignment: Alignment.center,
                  border: 2,
                  linearGradient: LinearGradient(
                    colors: [
                      const Color(0xFF00FFFF).withOpacity(0.3), // Neon Blue
                      const Color(0xFFFF00FF).withOpacity(0.3), // Pink
                    ],
                  ),
                  borderGradient: LinearGradient(
                    colors: [
                      const Color(0xFF00FFFF), // Neon Blue
                      const Color(0xFFFF00FF), // Pink
                    ],
                  ),
                  child: Semantics(
                    label:
                        _isNavigating ? 'Stop Navigation' : 'Start Navigation',
                    child: Icon(
                      _isNavigating ? Icons.stop : Icons.directions_walk,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
