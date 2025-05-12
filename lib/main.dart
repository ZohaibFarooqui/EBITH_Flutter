import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'screens/home_screen.dart';
import 'services/voice_navigation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize voice navigation (but don't speak yet)
  final VoiceNavigationService voiceService = VoiceNavigationService();
  await voiceService.initialize();

  runApp(MyApp(voiceService: voiceService));
}

class MyApp extends StatelessWidget {
  final VoiceNavigationService voiceService;

  const MyApp({super.key, required this.voiceService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EBITH',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SplashScreen(voiceService: voiceService),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final VoiceNavigationService voiceService;

  const SplashScreen({super.key, required this.voiceService});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to HomeScreen after 3 seconds and then speak
    Future.delayed(const Duration(seconds: 3), () async {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
      // Speak welcome instructions after splash screen ends
      await widget.voiceService.speak(
        "Welcome To EBITH. Please scroll left for blind screen, and scroll right for deaf screen",
      );
      await widget.voiceService.speak(
        "EBITH میں خوش آمدید۔ براہ کرم بلائنڈ اسکرین کے لیے بائیں اسکرول کریں، اور بہری اسکرین کے لیے دائیں اسکرول کریں۔",
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SlideInDown(
          duration: const Duration(seconds: 2),
          child: ZoomIn(
            duration: const Duration(seconds: 2),
            child: FadeIn(
              duration: const Duration(seconds: 2),
              child: Image.asset(
                'assets/images/ebith_logo.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),
      ),
    );
  }
}