import 'dart:typed_data';

/// بديل خارج الويب (الاختبارات والتطبيقات): لا صوت.
class Speech {
  Speech._();
  static final instance = Speech._();
  static Future<Uint8List?> Function(String text, String voice)? natural;
  bool get canSpeak => false;
  bool get canListen => false;
  bool get listening => false;
  void speak(String text, {bool female = true, double pitch = 1, String? voice}) {}
  void stopSpeaking() {}
  void listen(void Function(String text) onText) {}
  void stopListening() {}
}
