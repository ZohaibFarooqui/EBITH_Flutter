import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:animate_do/animate_do.dart';
import 'package:vibration/vibration.dart';
import '../services/voice_navigation_service.dart';
import '../widgets/camera_preview.dart';
import '../widgets/esp32_camera_stream.dart';

class DeafScreen extends StatefulWidget {
  final CameraController cameraController;
  bool useESP32;

  DeafScreen({
    Key? key,
    required this.cameraController,
    required this.useESP32,
  }) : super(key: key);

  @override
  _DeafScreenState createState() => _DeafScreenState();
}

class _DeafScreenState extends State<DeafScreen> with SingleTickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  final VoiceNavigationService _voiceService = VoiceNavigationService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  late bool _isEnglish;
  String _displayText = "Initializing...";
  String _gifPhrase = "";
  Timer? _captureTimer;
  final List<String> _frameBuffer = [];
  bool _busy = false;

  final String _predictUrl = 'http://192.168.18.87:5000/predict';

  static const int SEQUENCE_LENGTH = 90;
  static const int CAPTURE_INTERVAL = 400;
  static const int MIN_CONSECUTIVE = 8;
  static const int COOLDOWN_MS = 2000;
  static const double MIN_CONFIDENCE = 0.5;

  DateTime _lastSpoken = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, int> _counts = {};

  late AnimationController _gradientController;
  late Animation<Color?> _color1Animation;
  late Animation<Color?> _color2Animation;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _startListeningVoiceCommand();
    _captureTimer = Timer.periodic(
      Duration(milliseconds: CAPTURE_INTERVAL),
      (_) => _captureAndPredict(),
    );

    // Initialize gradient animation
    _gradientController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);
    _color1Animation = ColorTween(
      begin: const Color(0xFF00FFFF).withOpacity(0.2), // Neon Blue
      end: const Color(0xFFFF00FF).withOpacity(0.2),   // Pink
    ).animate(_gradientController);
    _color2Animation = ColorTween(
      begin: const Color(0xFFFF00FF).withOpacity(0.2), // Pink
      end: const Color(0xFF00FFFF).withOpacity(0.2),   // Neon Blue
    ).animate(_gradientController);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isEnglish = prefs.getBool('isEnglish') ?? true);
  }

  Future<void> _toggleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isEnglish = !_isEnglish;
      prefs.setBool('isEnglish', _isEnglish);
    });
  }

  void _updateDisplay(String txt, {bool speak = false}) async {
    if (!mounted) return;
    setState(() => _displayText = txt);
    if (speak) {
      final toSpeak = _isEnglish ? txt : _translate(txt);
      await _tts.speak(toSpeak);
    }
  }

  Future<void> _captureAndPredict() async {
    if (_busy) return;
    _busy = true;

    Uint8List bytes;
    try {
      if (widget.useESP32) {
        final res = await http.get(Uri.parse('http://192.168.18.209/capture'));
        if (res.statusCode != 200) {
          _updateDisplay("ESP32 error", speak: false);
          _busy = false;
          return;
        }
        bytes = res.bodyBytes;
      } else {
        if (!widget.cameraController.value.isInitialized) {
          _busy = false;
          return;
        }
        final pic = await widget.cameraController.takePicture();
        bytes = await pic.readAsBytes();
      }

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        _updateDisplay("Invalid frame", speak: false);
        _busy = false;
        return;
      }
      final resized = img.copyResize(decoded, width: 112, height: 112);
      final jpg = img.encodeJpg(resized, quality: 100);
      _frameBuffer.add(base64Encode(jpg));
      if (_frameBuffer.length > SEQUENCE_LENGTH) {
        _frameBuffer.removeAt(0);
      }

      if (_frameBuffer.length == SEQUENCE_LENGTH) {
        await _sendPredict();
        _frameBuffer.clear();
      }
    } catch (e) {
      _updateDisplay("Capture error: $e", speak: false);
    } finally {
      _busy = false;
    }
  }

  Future<void> _sendPredict() async {
    try {
      final res = await http.post(
        Uri.parse(_predictUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'frames': _frameBuffer}),
      ).timeout(Duration(seconds: 5));

      final js = jsonDecode(res.body) as Map<String, dynamic>;
      final status = js['status'] as String? ?? '';
      final phrase = js['phrase'] as String? ?? '';
      final conf = (js['confidence'] as num? ?? 0).toDouble();

      _updateDisplay("$status → $phrase (${(conf * 100).toStringAsFixed(1)}%)", speak: false);

      if (status == 'Success' && conf >= MIN_CONFIDENCE && phrase.isNotEmpty) {
        _counts[phrase] = (_counts[phrase] ?? 0) + 1;
        if (_counts[phrase]! >= MIN_CONSECUTIVE) {
          final now = DateTime.now();
          if (now.difference(_lastSpoken).inMilliseconds > COOLDOWN_MS) {
            _lastSpoken = now;
            setState(() => _gifPhrase = phrase); // Update _gifPhrase for predicted phrase
            _updateDisplay("Predicted: $phrase", speak: true);
          }
          _counts.clear();
        }
      } else {
        _counts.clear();
      }
    } catch (e) {
      _updateDisplay("Network error: $e", speak: false);
    }
  }

  String _translate(String txt) {
    const m = {
      "are_you_deaf": "کیا آپ بہرے ہیں؟",
      "are_you_ready": "کیا آپ تیار ہیں؟",
      "assalam_o_alaikum": "السلام علیکم",
      "can_i_help_you": "کیا میں آپ کی مدد کر سکتا ہوں؟",
      "come_here": "یہاں آئیں",
      "congratulations": "مبارک ہو",
      "hello": "ہیلو",
      "how_are_you": "آپ کیسے ہیں؟",
      "no": "نہیں",
      "please": "براہ کرم",
      "see_you_later": "بعد میں ملتے ہیں",
      "Thank_you": "شکریہ",
      "walaikum_as_salaam": "وعلیکم السلام",
      "what_is_your_name": "آپ کا نام کیا ہے؟",
      "yes": "ہاں",
      "Now listening": "اب سن رہے ہیں",
      "Predicted": "پیش گوئی کی گئی",
      "Detected voice": "آواز کا پتہ چلا",
      "Switched to ESP32 camera": "ای ایس پی 32 کیمرہ پر سوئچ کیا گیا",
      "Switched to Phone camera": "فون کیمرہ پر سوئچ کیا گیا",
    };
    // Handle "Predicted: phrase" or "Detected voice: phrase"
    if (txt.contains("Predicted:") || txt.contains("Detected voice:")) {
      final parts = txt.split(":");
      if (parts.length == 2) {
        final prefix = parts[0].trim();
        final phrase = parts[1].trim();
        final translatedPrefix = m[prefix] ?? prefix;
        final translatedPhrase = m[phrase] ?? phrase;
        return "$translatedPrefix: $translatedPhrase";
      }
    }
    return m[txt] ?? txt;
  }

  Future<void> _startListeningVoiceCommand() async {
    bool available = await _speech.initialize(
      onStatus: (val) {
        if (val == "listening") {
          _tts.speak(_isEnglish ? "Now listening" : _translate("Now listening"));
        }
      },
      onError: (err) => debugPrint("Speech error: $err"),
    );

    if (available) {
      _speech.listen(
        onResult: (val) {
          if (val.finalResult) {
            final spoken = val.recognizedWords.trim().toLowerCase().replaceAll(' ', '_');
            setState(() => _gifPhrase = spoken); // Already updates for voice detection
            _updateDisplay("Detected voice: $spoken", speak: true);
            _speech.stop();
            Future.delayed(Duration(seconds: 6), _startListeningVoiceCommand);
          }
        },
        listenMode: stt.ListenMode.confirmation,
      );
    }
  }

  void _toggleCamera() async {
    // Trigger haptic feedback if device supports it
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
    setState(() => widget.useESP32 = !widget.useESP32);
    _updateDisplay(
      "Switched to ${widget.useESP32 ? 'ESP32' : 'Phone'} camera",
      speak: true,
    );
    _counts.clear();
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _speech.stop();
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
                        _color1Animation.value ?? const Color(0xFF00FFFF).withOpacity(0.2), // Neon Blue
                        _color2Animation.value ?? const Color(0xFFFF00FF).withOpacity(0.2), // Pink
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
                      linearGradient: LinearGradient(colors: [
                        Colors.white.withOpacity(0.2),
                        const Color(0xFF00FFFF).withOpacity(0.2), // Neon Blue
                      ]),
                      borderGradient: LinearGradient(colors: [
                        const Color(0xFF00FFFF), // Neon Blue
                        const Color(0xFFFF00FF), // Pink
                      ]),
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
                    label: _busy ? 'Processing' : 'Idle',
                    child: Image.asset(
                      'assets/icons/status_${_busy ? "processing" : "idle"}.png',
                      width: 32,
                      height: 32,
                      errorBuilder: (context, error, stackTrace) => SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: _busy ? const Color(0xFFFF00FF) : Colors.grey, // Pink when busy
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom Info Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideInUp(
              child: GlassmorphicContainer(
                width: double.infinity,
                height: 200,
                borderRadius: 30,
                blur: 20,
                alignment: Alignment.center,
                border: 2,
                linearGradient: LinearGradient(
                  colors: [
                    const Color(0xFF00FFFF).withOpacity(0.3), // Neon Blue
                    const Color(0xFFFF00FF).withOpacity(0.3), // Pink
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderGradient: LinearGradient(colors: [
                  const Color(0xFF00FFFF), // Neon Blue
                  const Color(0xFFFF00FF), // Pink
                ]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeIn(
                      child: Semantics(
                        label: 'Display Text',
                        child: Text(
                          _displayText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: const Color(0xFF00FFFF).withOpacity(0.5), // Neon Blue glow
                              ),
                              Shadow(
                                blurRadius: 10,
                                color: const Color(0xFFFF00FF).withOpacity(0.5), // Pink glow
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    if (_gifPhrase.isNotEmpty)
                      ZoomIn(
                        child: Container(
                          margin: EdgeInsets.only(top: 16),
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFFF00FF), // Pink
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00FFFF).withOpacity(0.5), // Neon Blue
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Semantics(
                            label: 'Gesture Animation for $_gifPhrase',
                            child: Image.asset(
                              'assets/gifs/$_gifPhrase.gif',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 120,
                                alignment: Alignment.center,
                                child: Text(
                                  _gifPhrase.replaceAll('_', ' '),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Camera Toggle Button
          Positioned(
            bottom: 220,
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
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.camera,
                        color: Colors.white,
                        size: 32,
                      ),
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