import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

@JS('webkitSpeechRecognition')
extension type _Recognition._(JSObject _) implements JSObject {
  external factory _Recognition();
  external set lang(String v);
  external set continuous(bool v);
  external set interimResults(bool v);
  external set onresult(JSFunction f);
  external set onend(JSFunction f);
  external set onerror(JSFunction f);
  external void start();
  external void stop();
}

/// الكلام بصوت عربي (speechSynthesis) والاستماع للمستخدم (webkitSpeechRecognition).
class Speech {
  Speech._();
  static final instance = Speech._();

  bool get canSpeak => web.window.has('speechSynthesis');
  bool get canListen => web.window.has('webkitSpeechRecognition');

  _Recognition? _rec;
  bool _wanted = false;
  bool get listening => _wanted;

  web.SpeechSynthesisVoice? _voice(bool female) {
    final voices = web.window.speechSynthesis.getVoices().toDart.where((v) => v.lang.startsWith('ar')).toList();
    if (voices.isEmpty) return null;
    final byGender = voices.where((v) {
      final n = v.name.toLowerCase();
      return female ? (n.contains('female') || n.contains('zariyah') || n.contains('hoda') || n.contains('salma')) : (n.contains('male') && !n.contains('female') || n.contains('hamed') || n.contains('naayf'));
    }).toList();
    final sa = voices.where((v) => v.lang == 'ar-SA').toList();
    return byGender.firstOrNull ?? sa.firstOrNull ?? voices.first;
  }

  void speak(String text, {bool female = true, double pitch = 1}) {
    if (!canSpeak) return;
    final clean = text.replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true), '');
    final u = web.SpeechSynthesisUtterance(clean)
      ..lang = 'ar-SA'
      ..rate = 1.05
      ..pitch = female ? pitch * 1.15 : pitch * .85;
    final v = _voice(female);
    if (v != null) u.voice = v;
    web.window.speechSynthesis.speak(u);
  }

  void stopSpeaking() {
    if (canSpeak) web.window.speechSynthesis.cancel();
  }

  /// يستمع باستمرار ويرسل كل جملة مكتملة.
  void listen(void Function(String text) onText) {
    if (!canListen || _wanted) return;
    _wanted = true;
    final r = _Recognition()
      ..lang = 'ar-SA'
      ..continuous = true
      ..interimResults = false;
    r.onresult = ((JSObject e) {
      final results = e['results'] as JSObject;
      final i = (e['resultIndex'] as JSNumber).toDartInt;
      final len = (results['length'] as JSNumber).toDartInt;
      for (var k = i; k < len; k++) {
        final res = results[k.toString()] as JSObject;
        if ((res['isFinal'] as JSBoolean).toDart) {
          final alt = res['0'] as JSObject;
          final t = (alt['transcript'] as JSString).toDart.trim();
          if (t.isNotEmpty) onText(t);
        }
      }
    }).toJS;
    // المتصفح يوقف الاستماع بعد صمت طويل، فنعيد التشغيل ما دام المستخدم يريده
    r.onend = (() {
      if (_wanted) {
        try {
          r.start();
        } catch (_) {}
      }
    }).toJS;
    r.onerror = ((JSObject e) {
      final err = (e['error'] as JSString?)?.toDart;
      if (err == 'not-allowed' || err == 'service-not-allowed') _wanted = false;
    }).toJS;
    _rec = r;
    try {
      r.start();
    } catch (_) {
      _wanted = false;
    }
  }

  void stopListening() {
    _wanted = false;
    try {
      _rec?.stop();
    } catch (_) {}
    _rec = null;
  }
}
