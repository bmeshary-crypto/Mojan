import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
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

  /// مصدر الصوت الطبيعي (Gemini TTS). يرجع PCM 24kHz أو null للرجوع لصوت المتصفح.
  static Future<Uint8List?> Function(String text, String voice, bool egyptian)? natural;

  web.AudioContext? _ctx;
  web.AudioBufferSourceNode? _src;
  Future<void> _queue = Future.value();
  int _gen = 0;

  /// عدد الجمل التي تنتظر أو تُقال الآن.
  int pending = 0;
  /// على الجوال المتصفح يطلع صوت «تسجيل» مع كل بداية ونهاية استماع، فنوقفه هناك.
  bool get canListen {
    if (!web.window.has('webkitSpeechRecognition')) return false;
    final ua = web.window.navigator.userAgent;
    return !RegExp('Android|iPhone|iPad|iPod|Mobile').hasMatch(ua);
  }

  DateTime _lastStart = DateTime.fromMillisecondsSinceEpoch(0);

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
    // الأصوات «الطبيعية» (Online/Natural/Google) أوضح بكثير من أصوات الجهاز
    bool good(web.SpeechSynthesisVoice v) {
      final n = v.name.toLowerCase();
      return n.contains('natural') || n.contains('online') || n.contains('neural') || n.contains('google');
    }
    final sa = voices.where((v) => v.lang == 'ar-SA').toList();
    return byGender.where(good).firstOrNull ?? voices.where(good).firstOrNull ?? byGender.firstOrNull ?? sa.firstOrNull ?? voices.first;
  }

  /// يتكلم بصوت طبيعي من Gemini إن توفر [voice]، وإلا بصوت المتصفح. الجمل تُقال بالترتيب بدون تداخل.
  /// [naturalOnly]: إذا ما توفر الصوت الطبيعي لا نستخدم صوت المتصفح (يبقى الكلام مكتوباً فقط).
  void speak(String text, {bool female = true, double pitch = 1, String? voice, bool egyptian = false, bool naturalOnly = false}) {
    final clean = text.replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true), '').trim();
    if (clean.isEmpty) return;
    final gen = _gen;
    // نطلب الصوت فوراً (بالتوازي) ونشغله بالدور
    final pcm = (voice != null && natural != null) ? natural!(clean, voice, egyptian) : Future<Uint8List?>.value(null);
    pending++;
    _queue = _queue.then((_) async {
      if (gen != _gen) return;
      Uint8List? data;
      try {
        data = await pcm;
      } catch (_) {}
      if (gen != _gen) return;
      if (data != null && data.length > 100) {
        await _playPcm(data);
      } else if (!naturalOnly) {
        await _browserSpeak(clean, female, pitch);
      }
    }).whenComplete(() {
      if (gen == _gen && pending > 0) pending--;
    });
  }

  Future<void> _playPcm(Uint8List bytes) async {
    try {
      final ctx = _ctx ??= web.AudioContext();
      if (ctx.state == 'suspended') await ctx.resume().toDart;
      final n = bytes.length ~/ 2;
      final bd = ByteData.sublistView(bytes);
      final f = Float32List(n);
      for (var i = 0; i < n; i++) {
        f[i] = bd.getInt16(i * 2, Endian.little) / 32768;
      }
      final buf = ctx.createBuffer(1, n, 24000);
      buf.copyToChannel(f.toJS, 0);
      final src = ctx.createBufferSource()..buffer = buf;
      src.connect(ctx.destination);
      final done = Completer<void>();
      src.onended = ((web.Event _) {
        if (!done.isCompleted) done.complete();
      }).toJS;
      _src = src;
      src.start();
      await done.future.timeout(Duration(milliseconds: n * 1000 ~/ 24000 + 1500), onTimeout: () {});
      _src = null;
    } catch (_) {}
  }

  Future<void> _browserSpeak(String clean, bool female, double pitch) async {
    if (!canSpeak) return;
    final u = web.SpeechSynthesisUtterance(clean)
      ..lang = 'ar-SA'
      ..rate = 1
      ..pitch = female ? pitch * 1.15 : pitch * .85;
    final v = _voice(female);
    if (v != null) u.voice = v;
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }
    u.onend = ((web.Event _) => finish()).toJS;
    u.onerror = ((web.Event _) => finish()).toJS;
    web.window.speechSynthesis.speak(u);
    await done.future.timeout(Duration(seconds: 4 + clean.length ~/ 10), onTimeout: () {});
  }

  web.HTMLAudioElement? _stream;
  bool get streaming => _stream != null;

  /// تشغيل ملف صوتي من الإنترنت (بودكاست) بدءاً من ثانية معينة.
  void playStream(String url, double startSec) {
    stopStream();
    final a = web.HTMLAudioElement()
      ..src = url
      ..preload = 'auto';
    a.onloadedmetadata = ((web.Event _) {
      try {
        a.currentTime = startSec;
      } catch (_) {}
    }).toJS;
    _stream = a;
    a.play().toDart.catchError((_) => null);
  }

  void stopStream() {
    final a = _stream;
    _stream = null;
    if (a == null) return;
    a.pause();
    a.removeAttribute('src');
  }

  void stopSpeaking() {
    stopStream();
    _gen++;
    pending = 0;
    _queue = Future.value();
    try {
      _src?.stop();
    } catch (_) {}
    _src = null;
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
      if (!_wanted) return;
      // نعيد التشغيل بهدوء وبدون تكرار سريع
      final wait = const Duration(seconds: 2) - DateTime.now().difference(_lastStart);
      Future.delayed(wait.isNegative ? Duration.zero : wait, () {
        if (!_wanted || _rec != r) return;
        try {
          _lastStart = DateTime.now();
          r.start();
        } catch (_) {}
      });
    }).toJS;
    r.onerror = ((JSObject e) {
      final err = (e['error'] as JSString?)?.toDart;
      if (err == 'not-allowed' || err == 'service-not-allowed') _wanted = false;
    }).toJS;
    _rec = r;
    try {
      _lastStart = DateTime.now();
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
