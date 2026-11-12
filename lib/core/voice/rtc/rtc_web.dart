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

  static final _config = web.RTCConfiguration(
    iceServers: [
      web.RTCIceServer(urls: ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'].map((e) => e.toJS).toList().toJS),
      // خادم TURN عام مجاني كاحتياط للشبكات التي تمنع الاتصال المباشر (شبكات الجوال غالباً)
      web.RTCIceServer(
        urls: ['turn:openrelay.metered.ca:80', 'turn:openrelay.metered.ca:443', 'turn:openrelay.metered.ca:443?transport=tcp'].map((e) => e.toJS).toList().toJS,
        username: 'openrelayproject',
        credential: 'openrelayproject',
      ),
    ].toJS,
  );

  /// طلب إذن المايك. يرجع false إذا رفض المستخدم.
  Future<bool> startMic() async {
    if (_mic != null) return true;
    try {
      final constraints = web.MediaStreamConstraints(
        audio: {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true}.jsify()!,
      );
      _mic = await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
      _myAnalyser = _analyse(_mic!);
      setMic(_micOn);
      for (final p in _peers.values) {
        await p.sender?.replaceTrack(_micOn ? _track : null).toDart;
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

  void setMic(bool on) {
    _micOn = on;
    _track?.enabled = on;
    for (final p in _peers.values) {
      p.sender?.replaceTrack(on ? _track : null);
    }
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
      el.play().toDart.catchError((_) => null);
      p.audio = el;
      p.analyser = _analyse(stream);
    }).toJS;
    _peers[peer] = p;
    return p;
  }

  void _attachMic(_Peer p) {
    if (_micOn && _track != null) p.sender?.replaceTrack(_track);
  }

  /// يعيد تشغيل الأصوات الواردة (بعد لمسة من المستخدم إذا منع المتصفح التشغيل التلقائي).
  void resume() {
    try {
      if (_ctx?.state == 'suspended') _ctx!.resume();
    } catch (_) {}
    for (final p in _peers.values) {
      p.audio?.play().toDart.catchError((_) => null);
    }
  }

  /// ننتظر جمع عناوين الشبكة (بدون trickle) ثم نرسل الوصف كاملاً مرة واحدة.
  Future<String?> _local(web.RTCPeerConnection pc) async {
    if (pc.iceGatheringState != 'complete') {
      final done = Completer<void>();
      pc.onicegatheringstatechange = ((web.Event _) {
        if (pc.iceGatheringState == 'complete' && !done.isCompleted) done.complete();
      }).toJS;
      await done.future.timeout(const Duration(seconds: 4), onTimeout: () {});
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
    for (final k in [..._peers.keys]) {
      close(k);
    }
    _mic?.getTracks().toDart.forEach((t) => t.stop());
    _mic = null;
    _myAnalyser = null;
    _micOn = false;
  }
}
