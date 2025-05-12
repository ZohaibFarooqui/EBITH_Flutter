import 'package:http/http.dart' as http;
import 'dart:convert';

class ESP32Service {
  static Future<bool> checkConnection() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.18.209'));
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print('ESP32 connection check error: $e');
      return false;
    }
  }
}
