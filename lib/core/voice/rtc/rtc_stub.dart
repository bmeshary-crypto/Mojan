import 'package:flutter/foundation.dart';

/// بديل بدون صوت (الاختبارات والتطبيقات قبل دعم WebRTC فيها).
class RtcMesh {
  RtcMesh._();
  static final instance = RtcMesh._();
  bool get supported => false;
  bool get micReady => false;
  Future<bool> startMic() async => false;
  void setMic(bool on) {}
  void setSpeaker(bool on) {}
  Future<String?> offer(String peer) async => null;
  Future<String?> answer(String peer, String offer) async => null;
  Future<void> accept(String peer, String answer) async {}
  bool has(String peer) => false;
  String state(String peer) => 'none';
  void close(String peer) {}
  void closeAll() {}
  void resume() {}
  final audioBlocked = ValueNotifier<bool>(false);
  void setTurn(List<Map<String, dynamic>> servers) {}
  void onPageHide(void Function() f) {}
  bool get mediaOn => false;
  bool get mediaPaused => true;
  double get mediaPosition => 0;
  double get mediaDuration => 0;
  Future<bool> playMedia(String url) async => false;
  void pauseMedia() {}
  void resumeMedia() {}
  void setMediaVolume(double v) {}
  void stopMedia({bool update = true}) {}
  Future<(String, String)?> pickAudio() async => null;
  double level(String peer) => 0;
  double myLevel() => 0;
}
