import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firebase/cloud.dart';
import 'live_voice.dart';
import 'rtc/rtc.dart';

/// صوت بين اللاعبين الحقيقيين داخل مباراة أونلاين (لودو مثلاً).
/// كل لاعب يفتح مايكه أو يقفله، والكل يسمع الكل (عدد قليل فيكفي اتصال مباشر بين كل اثنين).
class MatchVoice extends ChangeNotifier {
  MatchVoice._();
  static final instance = MatchVoice._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _me => Cloud.instance.uid;
  final _session = Random().nextInt(1 << 30).toString();

  String? _match;
  Set<String> _peers = {};
  Map<String, String> _sessions = {};
  StreamSubscription? _docSub;
  final _sigSubs = <String, StreamSubscription>{};
  final _offeredAt = <String, DateTime>{};
  final _answeredFor = <String, String>{};
  Timer? _timer;

  bool micOn = false;
  bool speakerOn = true;
  bool get active => _match != null;

  /// مايك من على اللاعبين مفتوح (للأيقونة جنب الاسم).
  Set<String> micsOpen = {};

  DocumentReference<Map<String, dynamic>> get _ref => _db.collection('matches').doc(_match);

  /// يبدأ الصوت في المباراة. يرجع رسالة إن ما ينفع.
  String? start(String matchId) {
    if (!Cloud.instance.enabled || _me == null) return 'الصوت يحتاج تسجيل دخول';
    if (_match == matchId) return null;
    if (LiveVoice.instance.inRoom) return 'اطلع من الغرفة الصوتية أول عشان تستخدم المايك في اللعبة';
    stop();
    _match = matchId;
    _docSub = _ref.snapshots().listen((d) {
      final data = d.data() ?? {};
      final v = (data['voice'] as Map?) ?? {};
      _sessions = {for (final e in v.entries) if (e.value is Map && e.key != _me) '${e.key}': '${(e.value as Map)['s']}'};
      micsOpen = {for (final e in v.entries) if (e.value is Map && (e.value as Map)['mic'] == true) '${e.key}'};
      final seats = (data['seats'] as Map?) ?? {};
      _peers = {
        for (final s in seats.values)
          if (s is Map && s['uid'] is String && s['ai'] == null && s['uid'] != _me) s['uid'] as String,
      };
      _connect();
      notifyListeners();
    }, onError: (e) => debugPrint('match voice: $e'));
    _announce();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _connect());
    return null;
  }

  Future<void> _announce() async {
    try {
      await _ref.update({'voice.$_me': {'s': _session, 'mic': micOn}});
    } catch (e) {
      debugPrint('voice announce: $e');
    }
  }

  Future<bool> toggleMic() async {
    if (!active) return false;
    if (!micOn && !await RtcMesh.instance.startMic()) return false;
    micOn = !micOn;
    RtcMesh.instance.setMic(micOn);
    await _announce();
    notifyListeners();
    return true;
  }

  void toggleSpeaker() {
    speakerOn = !speakerOn;
    RtcMesh.instance.setSpeaker(speakerOn);
    notifyListeners();
  }

  void stop() {
    final id = _match;
    _match = null;
    _docSub?.cancel();
    _docSub = null;
    _timer?.cancel();
    for (final s in _sigSubs.values) {
      s.cancel();
    }
    _sigSubs.clear();
    _offeredAt.clear();
    _answeredFor.clear();
    micsOpen = {};
    if (micOn || _peers.isNotEmpty) RtcMesh.instance.closeAll();
    micOn = false;
    if (id != null && _me != null) {
      _db.collection('matches').doc(id).update({'voice.$_me': FieldValue.delete()}).catchError((Object _) {});
    }
  }

  String _pair(String a, String b) => a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  void _connect() {
    final me = _me;
    if (!active || me == null) return;
    final rtc = RtcMesh.instance;
    for (final id in [..._sigSubs.keys]) {
      if (!_sessions.containsKey(id)) {
        _sigSubs.remove(id)?.cancel();
        rtc.close(id);
      }
    }
    for (final id in _peers.where(_sessions.containsKey)) {
      _sigSubs[id] ??= _watch(id);
      final st = rtc.state(id);
      if (st == 'connected') continue;
      final last = _offeredAt[id];
      final since = last == null ? 999 : DateTime.now().difference(last).inSeconds;
      final starter = me.compareTo(id) < 0;
      final dead = st == 'none' || st == 'failed' || st == 'closed';
      if (starter ? (dead && since > 4) || since > 15 : since > 25 && dead) _offer(id);
    }
  }

  Future<void> _offer(String peer) async {
    _offeredAt[peer] = DateTime.now();
    final sdp = await RtcMesh.instance.offer(peer);
    final theirs = _sessions[peer];
    if (sdp == null || theirs == null || !active) return;
    await _ref.collection('signals').doc(_pair(_me!, peer)).set({
      'offer': sdp,
      'from': _me,
      'fromSession': _session,
      'toSession': theirs,
      'answer': null,
      'at': FieldValue.serverTimestamp(),
    });
  }

  StreamSubscription _watch(String peer) {
    final doc = _ref.collection('signals').doc(_pair(_me!, peer));
    return doc.snapshots().listen((snap) async {
      final d = snap.data();
      if (d == null) return;
      if (d['from'] == peer && d['toSession'] == _session && d['offer'] != null) {
        final key = '${d['fromSession']}:${(d['offer'] as String).hashCode}';
        if (_answeredFor[peer] == key) return;
        _answeredFor[peer] = key;
        final ans = await RtcMesh.instance.answer(peer, d['offer'] as String);
        if (ans == null) return;
        await doc.update({'answer': ans, 'answerTo': d['fromSession']});
      } else if (d['from'] == _me && d['answer'] != null && d['answerTo'] == _session) {
        await RtcMesh.instance.accept(peer, d['answer'] as String);
      }
    }, onError: (e) => debugPrint('match signal: $e'));
  }
}
