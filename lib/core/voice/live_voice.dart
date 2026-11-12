import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../ai/ai_brain.dart';
import '../ai/speech.dart';
import '../firebase/cloud.dart';
import 'rtc/rtc.dart';
import 'voice.dart';

/// الغرف الصوتية الحقيقية: حالة الغرفة والدردشة في Firestore، والصوت مباشرة بين المتصفحات (WebRTC).
///
/// - rooms/{id}: العنوان والمضيف والمقاعد (seats.N) والحالة.
/// - rooms/{id}/messages: الدردشة والهدايا.
/// - rooms/{id}/people/{uid}: الموجودون الآن (نبضة كل 20 ثانية).
/// - rooms/{id}/signals/{a_b}: تبادل عروض WebRTC بين كل شخصين.
class LiveVoice {
  LiveVoice._();
  static final instance = LiveVoice._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  bool get enabled => Cloud.instance.enabled && Cloud.instance.uid != null;
  String get _me => Cloud.instance.uid!;
  VoiceService get _svc => VoiceService.instance;

  StreamSubscription? _listSub;
  final _session = Random().nextInt(1 << 30).toString();

  VoiceRoom? _room;
  final _subs = <StreamSubscription>[];
  final _sigSubs = <String, StreamSubscription>{};
  Timer? _beat, _levels;
  Map<String, Map<String, dynamic>> _people = {};
  final _offeredAt = <String, DateTime>{};
  final _answeredFor = <String, String>{};
  final Set<String> _seenMsgs = {};
  bool _firstMessages = true;

  /// هدايا وصلت من الآخرين لعرض تأثيرها.
  final List<VoiceMessage> incomingFx = [];

  String newId() => _db.collection('rooms').doc().id;

  // ---------- قائمة الغرف ----------

  void startListing() {
    if (!enabled || _listSub != null) return;
    _listSub = _db.collection('rooms').where('open', isEqualTo: true).limit(40).snapshots().listen((snap) {
      final now = DateTime.now();
      final alive = <String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final last = (data['lastActive'] as Timestamp?)?.toDate();
        // غرفة غاب مضيفها أكثر من 3 دقائق لا تظهر
        if (last != null && now.difference(last).inMinutes >= 3 && data['host'] != _me) continue;
        alive.add(d.id);
        final r = _svc.byId(d.id) ?? _newRoom(d.id, data);
        if (!_svc.rooms.contains(r)) _svc.rooms.insert(0, r);
        if (r != _room) _applyRoom(r, data);
      }
      _svc.rooms.removeWhere((r) => r.live && !alive.contains(r.id) && r != _room);
      _svc.notify();
    }, onError: (e) => debugPrint('rooms list: $e'));
  }

  VoiceRoom _newRoom(String id, Map<String, dynamic> data) {
    final r = VoiceRoom(
      id: id,
      title: data['title'] ?? 'غرفة',
      host: _hostUser(data),
      category: VoiceCategory.values.firstWhere((c) => c.name == data['category'], orElse: () => VoiceCategory.chat),
      seats: (data['seatCount'] as num?)?.toInt() ?? 8,
      theme: VoiceTheme.values.firstWhere((t) => t.name == data['theme'], orElse: () => VoiceTheme.classic),
    )..live = true;
    return r;
  }

  VoiceUser _hostUser(Map<String, dynamic> data) {
    final uid = data['host'] as String;
    return VoiceUser(
      id: uid,
      name: data['hostName'] ?? 'المضيف',
      avatar: (data['hostAvatar'] as num?)?.toInt() ?? 0,
      isMe: uid == _me,
      isBot: false,
      frame: SeatFrame.host,
    );
  }

  VoiceUser _userFrom(Map m) {
    final ai = m['ai'] as String?;
    if (ai != null) {
      final p = personaById(ai);
      if (p != null) return _svc.aiUser(p);
    }
    final uid = m['uid'] as String? ?? '';
    final me = uid == _me ? _svc.me() : null;
    return me ??
        VoiceUser(
          id: uid,
          name: m['name'] ?? 'لاعب',
          avatar: (m['avatar'] as num?)?.toInt() ?? 0,
          isBot: false,
          frameArt: m['frame'] as String?,
          bubble: m['bubble'] as String?,
          entrance: m['entrance'] as String?,
          bio: m['bio'] as String? ?? '',
          vipLevel: (m['vip'] as num?)?.toInt() ?? 0,
        );
  }

  Map<String, dynamic> _meMap() {
    final u = _svc.me();
    return {
      'uid': _me,
      'name': u.name,
      'avatar': u.avatar,
      'frame': ?u.frameArt,
      'bubble': ?u.bubble,
      'entrance': ?u.entrance,
      'bio': u.bio,
      'vip': u.vipLevel,
    };
  }

  void _applyRoom(VoiceRoom r, Map<String, dynamic> data) {
    r.title = data['title'] ?? r.title;
    r.announcement = data['announcement'] ?? r.announcement;
    r.theme = VoiceTheme.values.firstWhere((t) => t.name == data['theme'], orElse: () => r.theme);
    r.locked = data['locked'] == true;
    r.chatMuted = data['chatMuted'] == true;
    r.heat = (data['heat'] as num?)?.toInt() ?? r.heat;
    r.game = data['game'] as String?;
    r.host = r.host.id == data['host'] ? r.host : _hostUser(data);
    final count = (data['seatCount'] as num?)?.toInt() ?? r.seats.length;
    if (count != r.seats.length) r.seats = List.generate(count, (i) => i < r.seats.length ? r.seats[i] : VoiceSeat(i));
    final seats = (data['seats'] as Map?) ?? {};
    final locked = ((data['lockedSeats'] as List?) ?? []).map((e) => (e as num).toInt()).toSet();
    for (final s in r.seats) {
      final m = seats['${s.index}'] as Map?;
      s.locked = locked.contains(s.index);
      if (m == null) {
        s.user = null;
        s.muted = false;
        continue;
      }
      final keep = s.user != null && (s.user!.id == m['uid'] || (m['ai'] != null && s.user!.aiId == m['ai']));
      s.user = keep ? s.user : _userFrom(m);
      s.muted = m['muted'] == true;
      s.user!.mic = m['mic'] == true;
    }
    r.kicked
      ..clear()
      ..addAll(((data['kicked'] as List?) ?? []).cast<String>());
    if (data['open'] == false && !r.closed) {
      r.closed = true;
      r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: data['closeReason'] ?? 'أغلق المضيف الغرفة'));
    }
    // أنا على مقعد؟ نحدث المايك الحقيقي
    if (r == _room) _syncMic();
  }

  // ---------- إنشاء ودخول وخروج ----------

  Future<void> publish(VoiceRoom r) async {
    if (!enabled) return;
    final me = _svc.me();
    final aiSeat = r.seats.where((s) => s.user?.isAi == true).firstOrNull;
    await _db.collection('rooms').doc(r.id).set({
      'title': r.title,
      'host': _me,
      'hostName': me.name,
      'hostAvatar': me.avatar,
      'category': r.category.name,
      'theme': r.theme.name,
      'seatCount': r.seats.length,
      'announcement': r.announcement,
      'open': true,
      'heat': 0,
      'seats': {if (aiSeat != null) '${aiSeat.index}': {'ai': aiSeat.user!.aiId}},
      'createdAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  Future<void> enter(VoiceRoom r) async {
    if (!enabled || !r.live) return;
    if (_room != null && _room != r) await exit(_room!);
    _room = r;
    _firstMessages = true;
    _seenMsgs.clear();
    final ref = _db.collection('rooms').doc(r.id);
    final peopleRef = ref.collection('people').doc(_me);
    Future<void> beat() async {
      try {
        await peopleRef.set({..._meMap(), 'session': _session, 'at': FieldValue.serverTimestamp()});
        if (_svc.isHost(r)) await ref.update({'lastActive': FieldValue.serverTimestamp()});
      } catch (e) {
        debugPrint('beat: $e');
      }
    }

    await beat();
    _beat = Timer.periodic(const Duration(seconds: 20), (_) => beat());
    if (!_svc.isHost(r)) {
      unawaited(_post(r, {'kind': 'join', 'text': 'دخل الغرفة'}));
    }
    _subs.add(ref.snapshots().listen((d) {
      final data = d.data();
      if (data == null) return;
      _applyRoom(r, data);
      _svc.notify();
    }));
    _subs.add(ref.collection('messages').orderBy('at', descending: true).limit(60).snapshots().listen((snap) {
      _applyMessages(r, snap.docs.reversed.toList());
    }));
    _subs.add(ref.collection('people').snapshots().listen((snap) {
      final now = DateTime.now();
      _people = {
        for (final d in snap.docs)
          if (d.id != _me && now.difference((d.data()['at'] as Timestamp?)?.toDate() ?? now).inSeconds < 70) d.id: d.data(),
      };
      final seated = r.onMics.map((u) => u.id).toSet();
      r.audience
        ..clear()
        ..addAll([for (final e in _people.entries) if (!seated.contains(e.key)) _userFrom({...e.value, 'uid': e.key})]);
      r.listeners = r.audience.length;
      _connectPeers(r);
      _svc.notify();
    }));
    _levels = Timer.periodic(const Duration(milliseconds: 350), (_) => _updateLevels(r));
  }

  Future<void> exit(VoiceRoom r, {bool hostClose = true}) async {
    if (_room != r) return;
    _room = null;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    for (final s in _sigSubs.values) {
      await s.cancel();
    }
    _sigSubs.clear();
    _beat?.cancel();
    _levels?.cancel();
    _offeredAt.clear();
    _answeredFor.clear();
    RtcMesh.instance.closeAll();
    final ref = _db.collection('rooms').doc(r.id);
    try {
      await ref.collection('people').doc(_me).delete();
      final mine = r.seats.where((s) => s.user?.isMe == true).map((s) => s.index);
      for (final i in mine) {
        await ref.update({'seats.$i': FieldValue.delete()});
      }
      if (r.host.isMe && hostClose) await ref.update({'open': false});
    } catch (e) {
      debugPrint('exit: $e');
    }
  }

  // ---------- الدردشة والهدايا ----------

  Future<void> _post(VoiceRoom r, Map<String, dynamic> m) =>
      _db.collection('rooms').doc(r.id).collection('messages').add({..._meMap(), ...m, 'at': FieldValue.serverTimestamp()});

  Future<void> sendChat(VoiceRoom r, String text) => _post(r, {'kind': 'chat', 'text': text});

  /// رسالة شخصية AI (يرسلها جهاز المضيف فقط).
  Future<void> postAi(VoiceRoom r, AiPersona p, String text) => _post(r, {'kind': 'chat', 'text': text, 'ai': p.id});

  Future<void> sendGift(VoiceRoom r, VoiceGift g, List<VoiceUser> to, int count, String text) async {
    await _post(r, {
      'kind': 'gift',
      'text': text,
      'gift': g.id,
      'count': count,
      'to': [for (final u in to) {'uid': u.id, 'name': u.name, 'avatar': u.avatar, 'ai': ?u.aiId}],
    });
    await _db.collection('rooms').doc(r.id).update({'heat': FieldValue.increment(g.price * count * to.length)});
  }

  void _applyMessages(VoiceRoom r, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final msgs = <VoiceMessage>[VoiceMessage(kind: VoiceMsgKind.system, text: r.announcement)];
    r.received.clear();
    r.sent.clear();
    r.giftCounts.clear();
    for (final d in docs) {
      final m = d.data();
      final kind = VoiceMsgKind.values.firstWhere((k) => k.name == m['kind'], orElse: () => VoiceMsgKind.chat);
      final user = _userFrom(m);
      final to = [for (final t in (m['to'] as List?) ?? []) _userFrom(t as Map)];
      final gift = m['gift'] == null ? null : giftById(m['gift'] as String);
      final count = (m['count'] as num?)?.toInt() ?? 1;
      final vm = VoiceMessage(kind: kind, text: m['text'] ?? '', user: user, gift: gift, count: count, to: to);
      msgs.add(vm);
      if (gift != null) r.recordGift(user, to, gift, count);
      final fresh = _seenMsgs.add(d.id) && !_firstMessages;
      if (!fresh) continue;
      // كل الأجهزة تنطق رد الـ AI بصوتها
      if (m['ai'] != null && _svc.speakerOn) {
        final p = personaById(m['ai'] as String);
        if (p != null) Speech.instance.speak(vm.text, female: p.female, voice: p.voice, egyptian: p.egyptian);
      }
      if (gift != null && !user.isMe) incomingFx.add(vm);
      // جهاز المضيف فقط يشغّل شخصيات الـ AI حتى لا يرد أكثر من مرة
      if (r.host.isMe && kind == VoiceMsgKind.chat && m['ai'] == null) {
        _svc.aiRespond(r, vm.text.replaceFirst('🎤 ', ''));
      }
    }
    _firstMessages = false;
    r.messages
      ..clear()
      ..addAll(msgs);
    _svc.notify();
  }

  // ---------- المقاعد وأدوات المضيف ----------

  DocumentReference<Map<String, dynamic>> _ref(VoiceRoom r) => _db.collection('rooms').doc(r.id);

  /// الجلوس على مقعد بشكل آمن (معاملة تمنع جلوس شخصين على نفس المقعد).
  Future<String?> claimSeat(VoiceRoom r, int i) async {
    try {
      final ok = await _db.runTransaction((tx) async {
        final snap = await tx.get(_ref(r));
        final seats = Map<String, dynamic>.from(snap.data()?['seats'] as Map? ?? {});
        if (seats['$i'] != null) return false;
        seats.removeWhere((k, v) => v is Map && v['uid'] == _me);
        seats['$i'] = {..._meMap(), 'mic': true};
        tx.update(_ref(r), {'seats': seats});
        return true;
      });
      if (!ok) return 'المقعد مشغول';
      await RtcMesh.instance.startMic();
      return null;
    } catch (e) {
      return 'تعذر الجلوس، حاول مرة أخرى';
    }
  }

  Future<void> seatAi(VoiceRoom r, int i, AiPersona p) => _ref(r).update({'seats.$i': {'ai': p.id}});

  Future<void> releaseSeat(VoiceRoom r, int i) => _ref(r).update({'seats.$i': FieldValue.delete()});

  Future<void> setMicFlag(VoiceRoom r, int i, bool on) => _ref(r).update({'seats.$i.mic': on});

  Future<void> setSeatMuted(VoiceRoom r, int i, bool muted) => _ref(r).update({'seats.$i.muted': muted});

  Future<void> setLocked(VoiceRoom r) =>
      _ref(r).update({'lockedSeats': [for (final s in r.seats) if (s.locked) s.index]});

  Future<void> kick(VoiceRoom r, VoiceUser u) async {
    final updates = <String, dynamic>{'kicked': FieldValue.arrayUnion([u.id])};
    for (final s in r.seats) {
      if (s.user?.id == u.id) updates['seats.${s.index}'] = FieldValue.delete();
    }
    await _ref(r).update(updates);
  }

  Future<void> update(VoiceRoom r) => _ref(r).update({
        'title': r.title,
        'announcement': r.announcement,
        'theme': r.theme.name,
        'locked': r.locked,
        'chatMuted': r.chatMuted,
        'category': r.category.name,
        'seatCount': r.seats.length,
        'game': r.game,
      });

  Future<void> close(VoiceRoom r, String reason) => _ref(r).update({'open': false, 'closeReason': reason});

  // ---------- الصوت ----------

  int? _mySeat(VoiceRoom r) => r.seats.where((s) => s.user?.isMe == true).firstOrNull?.index;

  bool _isSpeaker(VoiceRoom r) => r.host.isMe || _mySeat(r) != null;

  void _syncMic() {
    final r = _room;
    if (r == null) return;
    final s = _mySeat(r);
    final muted = s != null && r.seats[s].muted;
    final on = _svc.micOn && _isSpeaker(r) && !muted;
    if (on && !RtcMesh.instance.micReady) {
      RtcMesh.instance.startMic().then((ok) {
        if (!ok) _svc.micDenied();
      });
    }
    RtcMesh.instance.setMic(on);
  }

  void micChanged() => _syncMic();

  void speakerChanged(bool on) => RtcMesh.instance.setSpeaker(on);

  /// نتصل بكل شخص موجود إذا كان أحدنا متحدثاً (المستمعون لا يتصلون ببعض).
  void _connectPeers(VoiceRoom r) {
    final speakers = {r.host.id, for (final u in r.onMics) u.id};
    final iSpeak = speakers.contains(_me);
    final wanted = {for (final id in _people.keys) if (iSpeak || speakers.contains(id)) id};
    for (final id in [..._sigSubs.keys]) {
      if (!wanted.contains(id)) {
        _sigSubs.remove(id)?.cancel();
        RtcMesh.instance.close(id);
      }
    }
    for (final id in wanted) {
      _sigSubs[id] ??= _watchSignal(r, id);
      final st = RtcMesh.instance.state(id);
      final last = _offeredAt[id];
      final stale = last == null || DateTime.now().difference(last).inSeconds > 12;
      if (_me.compareTo(id) < 0 && (st == 'none' || st == 'new' || st == 'failed' || st == 'closed' || st == 'disconnected') && stale) {
        _offer(r, id);
      }
    }
  }

  String _pair(String a, String b) => a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  Future<void> _offer(VoiceRoom r, String peer) async {
    _offeredAt[peer] = DateTime.now();
    final sdp = await RtcMesh.instance.offer(peer);
    final theirs = _people[peer]?['session'];
    if (sdp == null || theirs == null) return;
    await _ref(r).collection('signals').doc(_pair(_me, peer)).set({
      'offer': sdp,
      'from': _me,
      'fromSession': _session,
      'toSession': theirs,
      'answer': null,
      'at': FieldValue.serverTimestamp(),
    });
  }

  StreamSubscription _watchSignal(VoiceRoom r, String peer) {
    final doc = _ref(r).collection('signals').doc(_pair(_me, peer));
    return doc.snapshots().listen((snap) async {
      final d = snap.data();
      if (d == null) return;
      if (d['from'] == peer && d['toSession'] == _session && d['offer'] != null) {
        // عرض جديد موجه لي: أرد عليه مرة واحدة
        final key = '${d['fromSession']}:${(d['offer'] as String).hashCode}';
        if (_answeredFor[peer] == key) return;
        _answeredFor[peer] = key;
        final ans = await RtcMesh.instance.answer(peer, d['offer'] as String);
        if (ans == null) return;
        await doc.update({'answer': ans, 'answerTo': d['fromSession']});
      } else if (d['from'] == _me && d['answer'] != null && d['answerTo'] == _session) {
        await RtcMesh.instance.accept(peer, d['answer'] as String);
      }
    }, onError: (e) => debugPrint('signal: $e'));
  }

  void _updateLevels(VoiceRoom r) {
    var changed = false;
    for (final u in [r.host, for (final s in r.seats) ?s.user]) {
      if (u.isAi) continue;
      final lvl = u.isMe ? RtcMesh.instance.myLevel() : RtcMesh.instance.level(u.id);
      final speaking = lvl > .08;
      if (u.speaking != speaking) {
        u.speaking = speaking;
        changed = true;
      }
    }
    final host = r.host.speaking;
    if (r.hostSpeaking != host) {
      r.hostSpeaking = host;
      changed = true;
    }
    if (changed) _svc.notify();
  }
}
