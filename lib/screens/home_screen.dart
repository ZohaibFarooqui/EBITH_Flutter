import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:animate_do/animate_do.dart';
import 'package:vibration/vibration.dart';
import '../widgets/bottom_nav.dart';
import '../services/esp32_service.dart';
import '../services/voice_control.dart';
import '../services/voice_navigation_service.dart';
import 'blind_screen.dart';
import 'deaf_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 1;
  CameraController? _cameraController;
  bool _esp32Connected = false;
  final VoiceNavigationService _voiceService = VoiceNavigationService();
  bool _isCameraInitialized = false;
  bool _isEnglish = true;
  late AnimationController _gradientController;
  late Animation<Color?> _color1Animation;
  late Animation<Color?> _color2Animation;
  Timer? _esp32CheckTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
    _initializeCamera();
    _loadLanguagePreference();
    VoiceControl.initialize();

    // Initialize ESP32 connection check (status only, no stream)
    _initializeESP32Connection();
    _esp32CheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkESP32Connection();
    });

    _voiceService.initialize().then((_) {
      _startContinuousListening();
    }).catchError((error) {
      print('Voice service initialization error: $error');
    });

    // Initialize gradient animation
    _gradientController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);
    _color1Animation = ColorTween(
      begin: const Color(0xFF00FFFF).withOpacity(0.2),
      end: const Color(0xFFFF00FF).withOpacity(0.2),
    ).animate(_gradientController);
    _color2Animation = ColorTween(
      begin: const Color(0xFFFF00FF).withOpacity(0.2),
      end: const Color(0xFF00FFFF).withOpacity(0.2),
    ).animate(_gradientController);
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
      );
      await _cameraController!.initialize();
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      print('Camera initialization error: $e');
    }
  }

  Future<void> _initializeESP32Connection() async {
    await _checkESP32Connection();
  }

  Future<void> _checkESP32Connection() async {
    try {
      bool connected = await ESP32Service.checkConnection();
      if (_esp32Connected != connected) {
        setState(() => _esp32Connected = connected);
      }
    } catch (e) {
      print('ESP32 connection error: $e');
      setState(() => _esp32Connected = false);
    }
  }

  Future<void> _loadLanguagePreference() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _isEnglish = true; // Default to English
        prefs.setBool("isEnglish", _isEnglish); // Save default
        print('Loaded language preference: $_isEnglish');
      });
    } catch (e) {
      print('Error loading language preference: $e');
      setState(() {
        _isEnglish = true; // Default to English on error
      });
    }
  }

  Future<void> _saveLanguagePreference() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool("isEnglish", _isEnglish);
      print('Saved language preference: $_isEnglish');
    } catch (e) {
      print('Error saving language preference: $e');
    }
  }

  void _startContinuousListening() {
    VoiceControl.startListening(_handleVoiceCommand);
  }

  void _handleVoiceCommand(String command) {
    print('Voice command received: $command');
    bool shouldRestartListening = true;

    if (command.toLowerCase().contains("blind screen")) {
      _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.ease);
      _voiceService.speak(_isEnglish ? "Navigating to Blind Screen" : "نابینا اسکرین پر جا رہے ہیں۔");
    } else if (command.toLowerCase().contains("deaf screen")) {
      _pageController.animateToPage(2, duration: const Duration(milliseconds: 300), curve: Curves.ease);
      _voiceService.speak(_isEnglish ? "Navigating to Deaf Screen" : "بہرے اسکرین پر جا رہے ہیں۔");
    } else if (command.toLowerCase().contains("english")) {
      setState(() => _isEnglish = true);
      _saveLanguagePreference();
      _voiceService.speak("Language set to English.");
    } else if (command.toLowerCase().contains("urdu")) {
      setState(() => _isEnglish = false);
      _saveLanguagePreference();
      _voiceService.speak("زبان اردو میں تبدیل ہو گئی ہے۔");
    } else {
      _voiceService.speak(
          _isEnglish ? "Sorry, command not recognized." : "معذرت، یہ کمانڈ نہیں سمجھی گئی۔");
    }

    // Restart listening after processing the command
    if (shouldRestartListening) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _startContinuousListening();
      });
    }
  }

  void _onPageChanged(int index) async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
    setState(() {
      _currentIndex = index;
    });
    String message;
    if (index == 0) {
      message = _isEnglish ? "Blind Screen" : "نابینا اسکرین";
    } else if (index == 1) {
      message = _isEnglish ? "Home Screen" : "ہوم اسکرین";
    } else {
      message = _isEnglish ? "Deaf Screen" : "بہرے اسکرین";
    }
    _voiceService.speak(message);
  }

  void _toggleLanguage() async {
    print('Language toggle button tapped');
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
    setState(() {
      _isEnglish = !_isEnglish;
      print('Language toggled to: $_isEnglish');
    });
    await _saveLanguagePreference();
    try {
      await _voiceService.speak(
        _isEnglish ? "Language set to English." : "زبان اردو میں تبدیل ہو گئی ہے۔",
      );
      print('Voice confirmation played');
    } catch (e) {
      print('Error speaking language confirmation: $e');
    }
    await _askUserCondition();
  }

  Future<void> _askUserCondition() async {
    try {
      await _voiceService.speak(
        _isEnglish
            ? "Are you blind or deaf? Please say blind or deaf. Swipe left for Blind Screen, right for Deaf Screen."
            : "کیا آپ نابینا ہیں یا بہرے؟ براہ کرم نابینا یا بہرے کہیں۔ نابینا اسکرین کے لیے بائیں سوائپ کریں، بہرے اسکرین کے لیے دائیں سوائپ کریں۔",
      );
    } catch (e) {
      print('Error in _askUserCondition: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cameraController?.dispose();
    _voiceService.stop();
    _esp32CheckTimer?.cancel();
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
                color: const Color(0xFF1A1A2E),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _color1Animation.value ?? const Color(0xFF00FFFF).withOpacity(0.2),
                        _color2Animation.value ?? const Color(0xFFFF00FF).withOpacity(0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              );
            },
          ),
          // Main Content
          _isCameraInitialized
              ? GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity! > 0) {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      );
                    } else if (details.primaryVelocity! < 0) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      );
                    }
                  },
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    children: [
                      BlindScreen(
                        cameraController: _cameraController!,
                        useESP32: _esp32Connected,
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ZoomIn(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFF00FFFF).withOpacity(0.5),
                                        const Color(0xFFFF00FF).withOpacity(0.2),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00FFFF).withOpacity(0.5),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.public,
                                    size: 100,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                GlassmorphicContainer(
                                  width: 300,
                                  height: 200,
                                  borderRadius: 20,
                                  blur: 15,
                                  alignment: Alignment.center,
                                  border: 2,
                                  linearGradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.2),
                                      const Color(0xFF00FFFF).withOpacity(0.2),
                                    ],
                                  ),
                                  borderGradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00FFFF),
                                      Color(0xFFFF00FF),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FadeInUp(
                                        child: Text(
                                          _isEnglish ? "Welcome to EBITH" : "ای بیتھ میں خوش آمدید",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            shadows: [
                                              Shadow(
                                                blurRadius: 10,
                                                color: const Color(0xFF00FFFF).withOpacity(0.5),
                                              ),
                                              Shadow(
                                                blurRadius: 10,
                                                color: const Color(0xFFFF00FF).withOpacity(0.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      FadeInUp(
                                        delay: const Duration(milliseconds: 200),
                                        child: Text(
                                          _isEnglish
                                              ? "Even Blind I am The Hero"
                                              : "یہاں تک کہ نابینا ہوں، میں ہیرو ہوں",
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      FadeInUp(
                                        delay: const Duration(milliseconds: 400),
                                        child: Text(
                                          _isEnglish
                                              ? "Swipe or say 'blind' or 'deaf' to navigate"
                                              : "سوائپ کریں یا 'نابینا' یا 'بہرے' کہیں",
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 250,
                            left: 40,
                            child: GlassmorphicContainer(
                              width: 60,
                              height: 60,
                              borderRadius: 30,
                              blur: 10,
                              alignment: Alignment.center,
                              border: 1,
                              linearGradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00FFFF).withOpacity(0.3),
                                  const Color(0xFFFF00FF).withOpacity(0.3),
                                ],
                              ),
                              borderGradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00FFFF),
                                  Color(0xFFFF00FF),
                                ],
                              ),
                              child: const Icon(
                                Icons.accessibility,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 250,
                            right: 40,
                            child: GlassmorphicContainer(
                              width: 60,
                              height: 60,
                              borderRadius: 30,
                              blur: 10,
                              alignment: Alignment.center,
                              border: 1,
                              linearGradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00FFFF).withOpacity(0.3),
                                  const Color(0xFFFF00FF).withOpacity(0.3),
                                ],
                              ),
                              borderGradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00FFFF),
                                  Color(0xFFFF00FF),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 150,
                            left: 20,
                            right: 20,
                            child: FadeInUp(
                              delay: const Duration(milliseconds: 600),
                              child: GlassmorphicContainer(
                                width: double.infinity,
                                height: 50,
                                borderRadius: 15,
                                blur: 15,
                                alignment: Alignment.center,
                                border: 1,
                                linearGradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.2),
                                    const Color(0xFF00FFFF).withOpacity(0.2),
                                  ],
                                ),
                                borderGradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00FFFF),
                                    Color(0xFFFF00FF),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isCameraInitialized ? Icons.check_circle : Icons.error,
                                      color: _isCameraInitialized ? Colors.green : Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _isEnglish
                                          ? (_isCameraInitialized ? "Camera Ready" : "Camera Loading")
                                          : (_isCameraInitialized ? "کیمرہ تیار ہے" : "کیمرہ لوڈ ہو رہا ہے"),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Icon(
                                      _esp32Connected ? Icons.check_circle : Icons.error,
                                      color: _esp32Connected ? Colors.green : Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _isEnglish
                                          ? (_esp32Connected ? "ESP32 Connected" : "ESP32 Disconnected")
                                          : (_esp32Connected ? "ای ایس پی 32 منسلک ہے" : "ای ایس پی 32 منقطع ہے"),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 20,
                            top: MediaQuery.of(context).size.height / 2 - 50,
                            child: FadeInLeft(
                              duration: const Duration(seconds: 2),
                              child: GlassmorphicContainer(
                                width: 120,
                                height: 60,
                                borderRadius: 15,
                                blur: 10,
                                alignment: Alignment.center,
                                border: 1,
                                linearGradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF00FFFF).withOpacity(0.3),
                                    const Color(0xFFFF00FF).withOpacity(0.3),
                                  ],
                                ),
                                borderGradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00FFFF),
                                    Color(0xFFFF00FF),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.arrow_left,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _isEnglish ? "Blind Screen" : "نابینا اسکرین",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 20,
                            top: MediaQuery.of(context).size.height / 2 - 50,
                            child: FadeInRight(
                              duration: const Duration(seconds: 2),
                              child: GlassmorphicContainer(
                                width: 120,
                                height: 60,
                                borderRadius: 15,
                                blur: 10,
                                alignment: Alignment.center,
                                border: 1,
                                linearGradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF00FFFF).withOpacity(0.3),
                                    const Color(0xFFFF00FF).withOpacity(0.3),
                                  ],
                                ),
                                borderGradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00FFFF),
                                    Color(0xFFFF00FF),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isEnglish ? "Deaf Screen" : "بہرے اسکرین",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.arrow_right,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      DeafScreen(
                        cameraController: _cameraController!,
                        useESP32: _esp32Connected,
                      ),
                    ],
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
          // Top HUD: Language Toggle and App Title (Moved to the end to ensure top Z-index)
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: FadeInDown(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FadeIn(
                    duration: const Duration(milliseconds: 300),
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
                          const Color(0xFF00FFFF).withOpacity(0.2),
                        ]),
                        borderGradient: const LinearGradient(colors: [
                          Color(0xFF00FFFF),
                          Color(0xFFFF00FF),
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
                  GlassmorphicContainer(
                    width: 100,
                    height: 40,
                    borderRadius: 20,
                    blur: 15,
                    alignment: Alignment.center,
                    border: 1,
                    linearGradient: LinearGradient(colors: [
                      Colors.white.withOpacity(0.2),
                      const Color(0xFF00FFFF).withOpacity(0.2),
                    ]),
                    borderGradient: const LinearGradient(colors: [
                      Color(0xFF00FFFF),
                      Color(0xFFFF00FF),
                    ]),
                    child: Semantics(
                      label: 'App Title',
                      child: Text(
                        "EBITH",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: const Color(0xFF00FFFF).withOpacity(0.5),
                            ),
                            Shadow(
                              blurRadius: 10,
                              color: const Color(0xFFFF00FF).withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ZoomIn(
        child: BottomNav(
          currentIndex: _currentIndex,
          onTap: (index) async {
            if (await Vibration.hasVibrator() ?? false) {
              Vibration.vibrate(duration: 100);
            }
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.ease,
            );
          },
        ),
      ),
    );
  }
}