import 'dart:typed_data';

/// بديل خارج الويب (الاختبارات والتطبيقات): لا صوت.
class Speech {
  Speech._();
  static final instance = Speech._();
  static Future<Uint8List?> Function(String text, String voice, bool egyptian)? natural;
  bool get canSpeak => false;
  bool get canListen => false;
  bool get listening => false;
  int get pending => 0;
  void speak(String text, {bool female = true, double pitch = 1, String? voice, bool egyptian = false, bool naturalOnly = false}) {}
  void stopSpeaking() {}
  bool get streaming => false;
  void playStream(String url, double startSec) {}
  void stopStream() {}
  void listen(void Function(String text) onText) {}
  void stopListening() {}
}
