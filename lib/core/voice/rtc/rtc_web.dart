import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class _Peer {
  _Peer(this.pc);
  final web.RTCPeerConnection pc;
  web.RTCRtpSender? sender;
  web.HTMLAudioElement? audio;
  web.AnalyserNode? analyser;
}

/// شبكة صوت مباشرة بين كل الموجودين في الغرفة (mesh). مناسبة للغرف الصغيرة (حتى ~12 متحدث).
/// الإشارة (offer/answer) تمر عبر Firestore، والصوت نفسه يمر مباشرة بين المتصفحات.
class RtcMesh {
  RtcMesh._();
  static final instance = RtcMesh._();

  bool get supported => true;

  final _peers = <String, _Peer>{};
  web.MediaStream? _mic;
  web.AnalyserNode? _myAnalyser;
  web.AudioContext? _ctx;
  bool _micOn = false;
  bool _speaker = true;

  bool get micReady => _mic != null;

  web.AudioContext get _audio => _ctx ??= web.AudioContext();

  /// خوادم TURN إضافية (من config/turn في Firestore) لشبكات الواي فاي التي تمنع الاتصال المباشر.
  List<Map<String, dynamic>> _turn = const [];
  void setTurn(List<Map<String, dynamic>> servers) => _turn = servers;

  web.RTCConfiguration get _config => web.RTCConfiguration(
        iceServers: [
          web.RTCIceServer(
            urls: [
              'stun:stun.l.google.com:19302',
              'stun:stun1.l.google.com:19302',
              'stun:stun2.l.google.com:19302',
              'stun:stun.cloudflare.com:3478',
            ].map((e) => e.toJS).toList().toJS,
          ),
          for (final t in _turn)
            web.RTCIceServer(
              urls: [for (final u in (t['urls'] as List? ?? [])) '$u'.toJS].toJS,
              username: '${t['username'] ?? ''}',
              credential: '${t['credential'] ?? ''}',
            ),
          // خادم TURN عام مجاني كاحتياط أخير (غير مضمون)
          web.RTCIceServer(
            urls: ['turn:openrelay.metered.ca:80', 'turn:openrelay.metered.ca:443', 'turn:openrelay.metered.ca:443?transport=tcp']
                .map((e) => e.toJS)
                .toList()
                .toJS,
            username: 'openrelayproject',
            credential: 'openrelayproject',
          ),
        ].toJS,
      );

  /// المتصفح منع تشغيل الصوت تلقائياً: نحتاج لمسة من المستخدم.
  final audioBlocked = ValueNotifier<bool>(false);

  void _play(web.HTMLAudioElement el) {
    el.play().toDart.then((_) {
      audioBlocked.value = false;
    }, onError: (Object _) {
      audioBlocked.value = true;
    });
  }

  /// عند إغلاق الصفحة أو التطبيق (أفضل محاولة لإزالة اللاعب من الغرفة).
  void onPageHide(void Function() f) {
    web.window.addEventListener('pagehide', ((web.Event _) => f()).toJS);
  }

  /// طلب إذن المايك. يرجع false إذا رفض المستخدم.
  Future<bool> startMic() async {
    if (_mic != null) return true;
    try {
      final constraints = web.MediaStreamConstraints(
        audio: {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true}.jsify()!,
      );
      _mic = await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
      _myAnalyser = _analyse(_mic!);
      _connectMicToMix();
      setMic(_micOn);
      for (final p in _peers.values) {
        await p.sender?.replaceTrack(_out).toDart;
      }
      return true;
    } catch (e) {
      debugPrint('mic denied: $e');
      return false;
    }
  }

  web.MediaStreamTrack? get _track {
    final t = _mic?.getAudioTracks().toDart;
    return t == null || t.isEmpty ? null : t.first;
  }

  /// ما يُرسل للآخرين: المايك وحده، أو خليط المايك مع الموسيقى إذا كانت شغالة.
  web.MediaStreamTrack? get _out {
    final mix = _mixDest;
    if (mix != null) {
      final t = mix.stream.getAudioTracks().toDart;
      if (t.isNotEmpty) return t.first;
    }
    return _micOn ? _track : null;
  }

  void setMic(bool on) {
    _micOn = on;
    _track?.enabled = on;
    _micGain?.gain.value = on ? 1 : 0;
    for (final p in _peers.values) {
      p.sender?.replaceTrack(_out);
    }
  }

  // ---------- تشغيل موسيقى أو ملف صوتي للغرفة ----------

  web.MediaStreamAudioDestinationNode? _mixDest;
  web.GainNode? _micGain, _mediaGain;
  web.AudioNode? _micSrc, _mediaSrc;
  web.HTMLAudioElement? _media;
  double _mediaVolume = .8;

  bool get mediaOn => _media != null;
  bool get mediaPaused => _media?.paused ?? true;
  double get mediaPosition => _media?.currentTime ?? 0;
  double get mediaDuration {
    final d = _media?.duration ?? 0;
    return d.isFinite ? d : 0;
  }

  void _ensureMix() {
    if (_mixDest != null) return;
    final ctx = _audio;
    _mixDest = ctx.createMediaStreamDestination();
    _micGain = ctx.createGain()..gain.value = _micOn ? 1 : 0;
    _micGain!.connect(_mixDest!);
    _mediaGain = ctx.createGain()..gain.value = _mediaVolume;
    _mediaGain!.connect(_mixDest!);
    // صاحب الموسيقى يسمعها أيضاً
    _mediaGain!.connect(ctx.destination);
    _connectMicToMix();
  }

  void _connectMicToMix() {
    if (_mixDest == null || _mic == null || _micSrc != null) return;
    _micSrc = _audio.createMediaStreamSource(_mic!)..connect(_micGain!);
  }

  /// يشغّل ملفاً صوتياً ويبثه لكل من في الغرفة مع صوت المايك.
  Future<bool> playMedia(String url) async {
    try {
      stopMedia(update: false);
      _ensureMix();
      if (_audio.state == 'suspended') await _audio.resume().toDart;
      final el = web.HTMLAudioElement()
        ..src = url
        ..preload = 'auto';
      _mediaSrc = _audio.createMediaElementSource(el)..connect(_mediaGain!);
      _media = el;
      await el.play().toDart;
      for (final p in _peers.values) {
        p.sender?.replaceTrack(_out);
        _boost(p.sender);
      }
      return true;
    } catch (e) {
      debugPrint('media: $e');
      stopMedia();
      return false;
    }
  }

  /// جودة أعلى للصوت المرسل أثناء الموسيقى.
  void _boost(web.RTCRtpSender? s) {
    if (s == null) return;
    try {
      final params = s.getParameters();
      final enc = params.encodings.toDart;
      if (enc.isEmpty) return;
      enc.first.maxBitrate = 128000;
      s.setParameters(params).toDart.catchError((_) => null);
    } catch (_) {}
  }

  void pauseMedia() => _media?.pause();
  void resumeMedia() => _media?.play().toDart.catchError((_) => null);

  void setMediaVolume(double v) {
    _mediaVolume = v;
    _mediaGain?.gain.value = v;
  }

  void stopMedia({bool update = true}) {
    final el = _media;
    _media = null;
    el?.pause();
    el?.removeAttribute('src');
    try {
      _mediaSrc?.disconnect();
      _micSrc?.disconnect();
      _micGain?.disconnect();
      _mediaGain?.disconnect();
    } catch (_) {}
    _mediaSrc = null;
    _micSrc = null;
    _micGain = null;
    _mediaGain = null;
    _mixDest = null;
    if (update) {
      for (final p in _peers.values) {
        p.sender?.replaceTrack(_out);
      }
    }
  }

  /// يختار ملفاً صوتياً من الجهاز. يرجع رابطاً مؤقتاً واسم الملف.
  Future<(String, String)?> pickAudio() async {
    final done = Completer<(String, String)?>();
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = 'audio/*';
    input.onchange = ((web.Event _) {
      final f = input.files?.item(0);
      if (f == null) {
        if (!done.isCompleted) done.complete(null);
        return;
      }
      final name = f.name.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '');
      if (!done.isCompleted) done.complete((web.URL.createObjectURL(f), name));
    }).toJS;
    input.click();
    return done.future;
  }

  void setSpeaker(bool on) {
    _speaker = on;
    for (final p in _peers.values) {
      p.audio?.muted = !on;
    }
  }

  web.AnalyserNode? _analyse(web.MediaStream s) {
    try {
      final a = _audio.createAnalyser()..fftSize = 256;
      _audio.createMediaStreamSource(s).connect(a);
      return a;
    } catch (_) {
      return null;
    }
  }

  double _levelOf(web.AnalyserNode? a) {
    if (a == null) return 0;
    final data = Uint8List(a.fftSize);
    a.getByteTimeDomainData(data.toJS);
    var peak = 0;
    for (final v in data) {
      final d = (v - 128).abs();
      if (d > peak) peak = d;
    }
    return peak / 128;
  }

  double level(String peer) => _levelOf(_peers[peer]?.analyser);
  double myLevel() => _micOn ? _levelOf(_myAnalyser) : 0;

  bool has(String peer) => _peers.containsKey(peer);
  String state(String peer) => _peers[peer]?.pc.connectionState ?? 'none';

  /// [offerer]: الطرف الذي يبدأ يضيف قناة الصوت بنفسه. الطرف المجيب يستخدم القناة التي وصلت في العرض،
  /// وإلا صار مايكه على قناة غير متفق عليها ولا يصل صوته للطرف الآخر.
  _Peer _create(String peer) {
    close(peer);
    final pc = web.RTCPeerConnection(_config);
    final p = _Peer(pc);
    pc.ontrack = ((web.RTCTrackEvent e) {
      final streams = e.streams.toDart;
      final stream = streams.isNotEmpty ? streams.first : web.MediaStream([e.track].toJS);
      p.audio?.remove();
      final el = web.HTMLAudioElement()
        ..autoplay = true
        ..srcObject = stream
        ..muted = !_speaker;
      el.setAttribute('playsinline', '');
      el.style.display = 'none';
      // بعض المتصفحات لا تشغل الصوت إلا إذا كان العنصر داخل الصفحة
      web.document.body?.append(el);
      _play(el);
      p.audio = el;
      p.analyser = _analyse(stream);
    }).toJS;
    _peers[peer] = p;
    return p;
  }

  void _attachMic(_Peer p) {
    final t = _out;
    if (t != null) p.sender?.replaceTrack(t);
    if (_mixDest != null) _boost(p.sender);
  }

  /// يعيد تشغيل الأصوات الواردة (بعد لمسة من المستخدم إذا منع المتصفح التشغيل التلقائي).
  void resume() {
    try {
      if (_ctx?.state == 'suspended') _ctx!.resume();
    } catch (_) {}
    for (final p in _peers.values) {
      final a = p.audio;
      if (a != null && a.paused) _play(a);
    }
    if (_peers.values.every((p) => p.audio == null || !p.audio!.paused)) audioBlocked.value = false;
  }

  /// ننتظر جمع عناوين الشبكة (بدون trickle) ثم نرسل الوصف كاملاً مرة واحدة.
  Future<String?> _local(web.RTCPeerConnection pc) async {
    if (pc.iceGatheringState != 'complete') {
      final done = Completer<void>();
      pc.onicegatheringstatechange = ((web.Event _) {
        if (pc.iceGatheringState == 'complete' && !done.isCompleted) done.complete();
      }).toJS;
      await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    }
    return pc.localDescription?.sdp;
  }

  Future<String?> offer(String peer) async {
    try {
      final p = _create(peer);
      p.sender = p.pc.addTransceiver('audio'.toJS, web.RTCRtpTransceiverInit(direction: 'sendrecv')).sender;
      _attachMic(p);
      // بدون وسيط: المتصفح ينشئ العرض بنفسه
      await p.pc.setLocalDescription().toDart;
      return await _local(p.pc);
    } catch (e) {
      debugPrint('offer failed: $e');
      return null;
    }
  }

  Future<String?> answer(String peer, String offer) async {
    try {
      final p = _create(peer);
      await p.pc.setRemoteDescription(web.RTCSessionDescriptionInit(type: 'offer', sdp: offer)).toDart;
      final ts = p.pc.getTransceivers().toDart;
      if (ts.isNotEmpty) {
        ts.first.direction = 'sendrecv';
        p.sender = ts.first.sender;
      } else {
        p.sender = p.pc.addTransceiver('audio'.toJS, web.RTCRtpTransceiverInit(direction: 'sendrecv')).sender;
      }
      _attachMic(p);
      await p.pc.setLocalDescription().toDart;
      return await _local(p.pc);
    } catch (e) {
      debugPrint('answer failed: $e');
      return null;
    }
  }

  Future<void> accept(String peer, String answer) async {
    final p = _peers[peer];
    if (p == null || p.pc.signalingState != 'have-local-offer') return;
    try {
      await p.pc.setRemoteDescription(web.RTCSessionDescriptionInit(type: 'answer', sdp: answer)).toDart;
    } catch (e) {
      debugPrint('accept failed: $e');
    }
  }

  void close(String peer) {
    final p = _peers.remove(peer);
    if (p == null) return;
    p.audio?.pause();
    p.audio?.srcObject = null;
    p.audio?.remove();
    p.pc.close();
  }

  void closeAll() {
    stopMedia(update: false);
    for (final k in [..._peers.keys]) {
      close(k);
    }
    _mic?.getTracks().toDart.forEach((t) => t.stop());
    _mic = null;
    _myAnalyser = null;
    _micOn = false;
  }
}
