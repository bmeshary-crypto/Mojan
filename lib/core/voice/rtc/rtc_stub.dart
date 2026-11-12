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
  double level(String peer) => 0;
  double myLevel() => 0;
}
