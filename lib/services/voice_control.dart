import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceControl {
  static final stt.SpeechToText _speech = stt.SpeechToText();

  static Future<void> initialize() async {
    await _speech.initialize();
  }

  static void startListening(Function(String) onResult) {
    _speech.listen(
      onResult: (result) => onResult(result.recognizedWords),
    );
  }

  static void stopListening() {
    _speech.stop();
  }
}