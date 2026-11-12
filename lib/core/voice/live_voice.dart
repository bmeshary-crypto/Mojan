import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../ai/ai_brain.dart';
import '../ai/speech.dart';
import '../firebase/cloud.dart';
import 'rtc/rtc.dart';
import 'system_rooms.dart';
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
  // متى بدأ اتصال الصوت مع شخص يتعثر، ومتى غاب شخص جالس على المايك
  final _badSince = <String, DateTime>{};
  final _absentSince = <String, DateTime>{};
  Set<String> _docIds = {};
  Timer? _conn;
  bool _satThisVisit = false;
  bool _turnLoaded = false, _hideHooked = false;
  final _answeredFor = <String, String>{};
  final Set<String> _seenMsgs = {};
  bool _firstMessages = true;

  /// هدايا وصلت من الآخرين لعرض تأثيرها.
  final List<VoiceMessage> incomingFx = [];

  String newId() => _db.collection('rooms').doc().id;

  // ---------- قائمة الغرف ----------

  void startListing() {
    if (!enabled || _listSub != null) return;
    // كل الغرف المحفوظة (النشطة وغير النشطة) مرتبة بآخر ظهور
    _listSub = _db.collection('rooms').orderBy('lastActive', descending: true).limit(80).snapshots().listen((snap) {
      final alive = <String>{};
      for (final d in snap.docs) {
        final data = d.data();
        if (data['system'] != null) continue;
        alive.add(d.id);
        final r = _svc.byId(d.id) ?? _newRoom(d.id, data);
        if (!_svc.rooms.contains(r)) _svc.rooms.add(r);
        r.lastActive = (data['lastActive'] as Timestamp?)?.toDate() ?? r.lastActive;
        if (r != _room) {
          r.closed = data['open'] == false;
          _applyRoom(r, data);
        }
      }
      _svc.rooms.removeWhere((r) => r.live && r.system == null && !alive.contains(r.id) && r != _room);
      for (final r in _svc.rooms) {
        if (r.live && r.system == null && r != _room) _sweepIdle(r);
      }
      _svc.notify();
    }, onError: (e) => debugPrint('rooms list: $e'));
    // غرفتا النظام: نعرف عدد الموجودين فيهما من علامات "أنا هنا"
    for (final id in [SystemRooms.welcomeId, SystemRooms.podcastId]) {
      _sysSubs.add(_db.collection('rooms').doc(id).snapshots().listen((d) {
        final r = _svc.byId(id);
        final data = d.data();
        if (r == null || data == null || r == _room) return;
        final here = data['here'];
        r.hereKnown = here is Map;
        r.hereAt = {
          if (here is Map)
            for (final e in here.entries)
              if (e.value is Timestamp) '${e.key}': (e.value as Timestamp).toDate(),
        };
        r.presentIds = r.freshHere();
        _svc.notify();
      }, onError: (e) => debugPrint('sys room: $e')));
    }
  }

  final _sysSubs = <StreamSubscription>[];
  final _idleSwept = <String, DateTime>{};

  /// غرفة ما فيها أحد من دقيقتين: ننزل من بقوا "معلقين" على المايكات (طلعوا بدون ما يُحذفوا).
  void _sweepIdle(VoiceRoom r) {
    final last = r.lastActive;
    if (last == null || DateTime.now().difference(last).inSeconds < 120) return;
    final fresh = r.hereKnown ? r.freshHere() : <String>{};
    final ghosts = [
      for (final s in r.seats)
        if (s.user != null && !s.user!.isAi && !fresh.contains(s.user!.id)) s.index,
    ];
    if (ghosts.isEmpty) return;
    final prev = _idleSwept[r.id];
    if (prev != null && DateTime.now().difference(prev).inSeconds < 60) return;
    _idleSwept[r.id] = DateTime.now();
    _ref(r).update({for (final i in ghosts) 'seats.$i': FieldValue.delete()}).catchError((Object e) => debugPrint('idle sweep: $e'));
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
          sid: m['sid'] as String?,
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
      'sid': ?u.sid,
    };
  }

  void _applyRoom(VoiceRoom r, Map<String, dynamic> data) {
    final here = data['here'];
    r.hereKnown = here is Map;
    r.hereAt = {
      if (here is Map)
        for (final e in here.entries)
          if (e.value is Timestamp) '${e.key}': (e.value as Timestamp).toDate(),
    };
    // غرفة ما دخلتها: الموجودون = من علامته "أنا هنا" حديثة
    if (r != _room) r.presentIds = r.hereKnown ? r.freshHere() : null;
    if (r.system != null) {
      // غرف النظام: العنوان والمضيف ثابتة، نأخذ فقط المقاعد والشعبية
      r.heat = (data['heat'] as num?)?.toInt() ?? r.heat;
      final seats = (data['seats'] as Map?) ?? {};
      for (final s in r.seats) {
        final m = seats['${s.index}'] as Map?;
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
      SystemRooms.instance.pin(r);
      SystemRooms.instance.onDoc(r, data);
      if (r == _room) _syncMic();
      return;
    }
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
    r.chair = data['chair'] as String?;
    r.private = data['private'] == true;
    final media = data['media'] as Map?;
    r.mediaTitle = media?['title'] as String?;
    r.mediaBy = media?['by'] as String?;
    r.mediaUid = media?['uid'] as String?;
    final inv = (data['invites'] as Map?)?[_me];
    if (inv == null) _inviteHandled = false;
    if (inv is num && r == _room && !_inviteHandled) _svc.gotInvite(r, inv.toInt());
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
      'chair': ?r.chair,
      'open': true,
      'heat': 0,
      'seats': {if (aiSeat != null) '${aiSeat.index}': {'ai': aiSeat.user!.aiId}},
      'createdAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  Future<void> enter(VoiceRoom r, {bool hidden = false}) async {
    if (!enabled || !r.live) return;
    if (_room != null && _room != r) await exit(_room!);
    _room = r;
    r.presentIds = {if (!hidden) _me};
    _satThisVisit = false;
    _firstMessages = true;
    _loadTurn();
    if (!_hideHooked) {
      _hideHooked = true;
      // إغلاق الصفحة أو التطبيق: نشيل نفسنا من الغرفة ومن المايك فوراً
      RtcMesh.instance.onPageHide(() {
        final room = _room;
        if (room != null) _leaveDoc(room);
      });
    }
    _seenMsgs.clear();
    final ref = _db.collection('rooms').doc(r.id);
    final peopleRef = ref.collection('people').doc(_me);
    if (r.system != null) {
      // غرفة النظام تُنشأ على السيرفر أول مرة يدخلها أحد
      try {
        final snap = await ref.get();
        if (!snap.exists) {
          await ref.set({
            'system': r.system,
            'title': r.title,
            'host': _me,
            'seatCount': r.seats.length,
            'heat': 0,
            'seats': SystemRooms.instance.aiSeats(r),
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          final seats = (snap.data()?['seats'] as Map?) ?? {};
          for (final e in SystemRooms.instance.aiSeats(r).entries) {
            if ((seats[e.key] as Map?)?['ai'] != (e.value as Map)['ai']) await ref.update({'seats.${e.key}': e.value});
          }
        }
      } catch (e) {
        debugPrint('system room: $e');
      }
    }
    Future<void> beat() async {
      try {
        await peopleRef.set({..._meMap(), 'session': _session, 'at': FieldValue.serverTimestamp(), if (hidden) 'hidden': true});
        // أي شخص داخل الغرفة يبقيها نشطة ويحدّث آخر ظهور لها
        // وعلامة "أنا هنا" في مستند الغرفة نفسه، عشان القائمة تعرف مين فعلاً موجود بدون ما تدخل
        if (!hidden) {
          r.lastActive = DateTime.now();
          await ref.update({
            'here.$_me': FieldValue.serverTimestamp(),
            if (r.system == null) 'lastActive': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('beat: $e');
      }
    }

    await beat();
    _beat = Timer.periodic(const Duration(seconds: 20), (_) => beat());
    if (!_svc.isHost(r) && !hidden) {
      unawaited(_post(r, {'kind': 'join', 'text': 'دخل الغرفة'}));
    }
    _subs.add(ref.snapshots().listen((d) {
      final data = d.data();
      if (data == null) return;
      _applyRoom(r, data);
      // من صعد أو نزل من المايك: نتصل به فوراً بدون انتظار نبضة الحضور
      _connectPeers(r);
      _svc.notify();
    }));
    _subs.add(ref.collection('messages').orderBy('at', descending: true).limit(60).snapshots().listen((snap) {
      _applyMessages(r, snap.docs.reversed.toList());
    }));
    _subs.add(ref.collection('people').snapshots().listen((snap) {
      final now = DateTime.now();
      _docIds = {for (final d in snap.docs) d.id};
      // الموجود فعلاً: آخر نبضة خلال 75 ثانية (اللي طلع أو انقطع ما يظهر)
      _people = {
        for (final d in snap.docs)
          if (d.id != _me && now.difference((d.data()['at'] as Timestamp?)?.toDate() ?? now).inSeconds < 75) d.id: d.data(),
      };
      _refreshPeople(r);
    }));
    _conn = Timer.periodic(const Duration(seconds: 5), (_) {
      _connectPeers(r);
      _sweepSeats(r);
    });
    _levels = Timer.periodic(const Duration(milliseconds: 350), (_) => _updateLevels(r));
  }

  Future<void> exit(VoiceRoom r) async {
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
    _conn?.cancel();
    _badSince.clear();
    _absentSince.clear();
    r.presentIds = null;
    await _leaveDoc(r);
  }

  /// يحذف حضوري ومقعدي من الغرفة.
  Future<void> _leaveDoc(VoiceRoom r) async {
    final ref = _db.collection('rooms').doc(r.id);
    try {
      final mine = r.seats.where((s) => s.user?.isMe == true).map((s) => s.index).toList();
      await Future.wait([
        ref.collection('people').doc(_me).delete(),
        ref.update({'here.$_me': FieldValue.delete(), for (final i in mine) 'seats.$i': FieldValue.delete()}),
      ]);
    } catch (e) {
      debugPrint('exit: $e');
    }
  }

  /// يحدّث قائمة الموجودين والحضور ويتصل بالجدد.
  void _refreshPeople(VoiceRoom r) {
    // المراقب المخفي (الأدمن) يسمع الغرفة لكنه لا يظهر في الحضور ولا في العدد
    final visible = {for (final e in _people.entries) if (e.value['hidden'] != true) e.key: e.value};
    r.presentIds = {if (!_svc.hiddenIn(r)) _me, ...visible.keys};
    final seated = r.onMics.map((u) => u.id).toSet();
    r.audience
      ..clear()
      ..addAll([for (final e in visible.entries) if (!seated.contains(e.key)) _userFrom({...e.value, 'uid': e.key})]);
    r.listeners = r.audience.length;
    _connectPeers(r);
    _sweepSeats(r);
    _svc.notify();
  }

  /// من جلس على المايك ثم أغلق التطبيق أو انقطع: ينزل من المقعد بعد 40 ثانية من غيابه.
  /// ينفذها جهاز واحد فقط: المضيف إن كان موجوداً، وإلا أصغر معرّف بين الموجودين.
  void _sweepSeats(VoiceRoom r) {
    final present = r.presentIds ?? {};
    final now = DateTime.now();
    final gone = <int>[];
    for (final s in r.seats) {
      final u = s.user;
      if (u == null || u.isAi || u.isMe) continue;
      if (present.contains(u.id)) {
        _absentSince.remove(u.id);
        continue;
      }
      final since = _absentSince.putIfAbsent(u.id, () => now);
      final seen = r.hereAt[u.id];
      // ما له علامة حضور حديثة أصلاً: معلّق من زيارة قديمة، ينزل فوراً
      final stale = r.hereKnown && (seen == null || now.difference(seen).inSeconds > 90);
      if (stale || now.difference(since).inSeconds >= 40) gone.add(s.index);
    }
    // مقعدي من زيارة سابقة (طلعت بدون ما ينحذف): أنزل منه
    if (!_satThisVisit && !_svc.isHost(r)) {
      final mine = [for (final s in r.seats) if (s.user?.isMe == true) s.index];
      if (mine.isNotEmpty) {
        _satThisVisit = true;
        _ref(r).update({for (final i in mine) 'seats.$i': FieldValue.delete()}).catchError((Object e) => debugPrint('own ghost: $e'));
      }
    }
    if (gone.isEmpty) return;
    if (present.isEmpty) return;
    final janitor = present.contains(r.host.id) ? r.host.id : (present.toList()..sort()).first;
    if (janitor != _me) return;
    _ref(r).update({for (final i in gone) 'seats.$i': FieldValue.delete()}).catchError((Object e) => debugPrint('sweep: $e'));
  }

  /// خوادم TURN الخاصة (إن أضافها الأدمن في config/turn) لتحسين الصوت على الواي فاي المقيد.
  Future<void> _loadTurn() async {
    if (_turnLoaded) return;
    _turnLoaded = true;
    try {
      final d = (await _db.collection('config').doc('turn').get()).data();
      final list = d?['servers'];
      if (list is List) RtcMesh.instance.setTurn([for (final e in list) if (e is Map) Map<String, dynamic>.from(e)]);
    } catch (e) {
      debugPrint('turn: $e');
    }
  }

  // ---------- الدردشة والهدايا ----------

  Future<void> _post(VoiceRoom r, Map<String, dynamic> m) =>
      _db.collection('rooms').doc(r.id).collection('messages').add({..._meMap(), ...m, 'at': FieldValue.serverTimestamp()});

  Future<void> sendChat(VoiceRoom r, String text) => _post(r, {'kind': 'chat', 'text': text});

  /// رسالة شخصية AI (يرسلها جهاز المضيف فقط).
  /// [quiet]: يظهر كتابةً في التعليقات فقط ولا يُنطق (ردود البودكاست على المستمعين).
  Future<void> postAi(VoiceRoom r, AiPersona p, String text, {bool quiet = false}) =>
      _post(r, {'kind': 'chat', 'text': text, 'ai': p.id, if (quiet) 'quiet': true});

  /// يحجز توليد حلقة البودكاست لهذا اليوم (حتى لا يولدها أكثر من جهاز).
  Future<bool> claimPodcast(VoiceRoom r, int day) async {
    try {
      return await _db.runTransaction((tx) async {
        final snap = await tx.get(_ref(r));
        final d = snap.data() ?? {};
        final pod = d['pod'];
        if (pod is Map && pod['day'] == day) return false;
        final g = d['podGen'];
        if (g is Map && g['day'] == day) {
          final at = (g['at'] as Timestamp?)?.toDate();
          if (at != null && DateTime.now().difference(at).inMinutes < 3) return false;
        }
        tx.update(_ref(r), {'podGen': {'day': day, 'by': _me, 'at': FieldValue.serverTimestamp()}});
        return true;
      });
    } catch (e) {
      debugPrint('podcast claim: $e');
      return false;
    }
  }

  Future<void> savePodcast(VoiceRoom r, int day, List<Map<String, dynamic>> episodes) async {
    try {
      await _ref(r).update({'pod': {'day': day, 'episodes': episodes}});
    } catch (e) {
      debugPrint('podcast save: $e');
    }
  }

  Future<void> sendGift(VoiceRoom r, VoiceGift g, List<VoiceUser> to, int count, String text) async {
    await _post(r, {
      'kind': 'gift',
      'text': text,
      'gift': g.id,
      'count': count,
      'to': [for (final u in to) {'uid': u.id, 'name': u.name, 'avatar': u.avatar, 'ai': ?u.aiId}],
    });
    try {
      await _db.collection('rooms').doc(r.id).update({'heat': FieldValue.increment(g.price * count * to.length)});
    } catch (e) {
      debugPrint('heat: $e');
    }
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
      // كل الأجهزة تنطق رد الـ AI بصوتها (إلا ردود التعليقات الصامتة)
      if (m['ai'] != null && m['quiet'] != true) {
        final p = personaById(m['ai'] as String);
        if (p != null) {
          if (_svc.speakerOn) Speech.instance.speak(vm.text, female: p.female, voice: p.voice, egyptian: p.egyptian, naturalOnly: r.isWelcome);
          SystemRooms.instance.glow(r, p.id, vm.text);
        }
      }
      if (gift != null && !user.isMe) incomingFx.add(vm);
      final mine = m['uid'] == _me && m['ai'] == null;
      if (r.system != null) {
        // غرف النظام بلا مضيف بشري: جهاز كاتب الرسالة هو من يطلب رد الـ AI
        if (mine && kind == VoiceMsgKind.chat) unawaited(SystemRooms.instance.onMyChat(r, vm.text.replaceFirst('🎤 ', '')));
        if (mine && gift != null) unawaited(SystemRooms.instance.onMyGift(r, vm));
      } else if (r.host.isMe && kind == VoiceMsgKind.chat && m['ai'] == null) {
        // جهاز المضيف فقط يشغّل شخصيات الـ AI حتى لا يرد أكثر من مرة
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
        seats['$i'] = {..._meMap(), 'mic': r.host.isMe ? _svc.micOn : true};
        tx.update(_ref(r), {'seats': seats});
        return true;
      });
      if (!ok) return 'المقعد مشغول';
      _satThisVisit = true;
      await RtcMesh.instance.startMic();
      return null;
    } catch (e) {
      return 'تعذر الجلوس، حاول مرة أخرى';
    }
  }

  /// دعوة شخص بعينه للمايك: تظهر له رسالة يقبل أو يرفض.
  Future<void> sendInvite(VoiceRoom r, String uid, int seat) => _ref(r).update({'invites.$uid': seat});

  bool _inviteHandled = false;

  Future<void> clearInvite(VoiceRoom r) async {
    _inviteHandled = true;
    try {
      await _ref(r).update({'invites.$_me': FieldValue.delete()});
    } catch (_) {}
  }

  /// ما يُشغَّل الآن في الغرفة (يظهر للجميع).
  Future<void> setMedia(VoiceRoom r, String? title) async {
    try {
      await _ref(r).update({'media': title == null ? FieldValue.delete() : {'title': title, 'by': _svc.me().name, 'uid': _me}});
    } catch (_) {}
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
        'chair': r.chair,
      });

  Future<void> close(VoiceRoom r, String reason) => _ref(r).update({'open': false, 'closeReason': reason});

  // ---------- الغرف الخاصة بكلمة سر ----------

  /// المضيف أو الأدمن يضع كلمة سر (أو يشيلها بـ null).
  Future<String?> setPassword(VoiceRoom r, String? pw) async {
    try {
      final secret = _ref(r).collection('secret').doc('pw');
      if (pw == null || pw.isEmpty) {
        await _ref(r).update({'private': false});
        await secret.delete();
      } else {
        await secret.set({'pw': pw});
        await _ref(r).update({'private': true});
        // المضيف نفسه يبقى عضواً بالكلمة الجديدة
        await _ref(r).collection('pass').doc(_me).set({'pw': pw, 'at': FieldValue.serverTimestamp()});
      }
      r.private = pw != null && pw.isNotEmpty;
      return null;
    } catch (e) {
      debugPrint('password: $e');
      return 'تعذر حفظ كلمة السر';
    }
  }

  /// كلمة السر الحالية (للمضيف والأدمن فقط).
  Future<String?> password(VoiceRoom r) async {
    try {
      return (await _ref(r).collection('secret').doc('pw').get()).data()?['pw'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// هل أقدر أدخل الغرفة الخاصة بدون كلمة سر (دخلتها قبل والكلمة ما تغيرت).
  Future<bool> canEnter(VoiceRoom r) async {
    if (!r.private) return true;
    try {
      await _ref(r).collection('messages').limit(1).get();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// يجرب كلمة السر. السيرفر يرفضها إذا كانت غلط.
  Future<bool> submitPassword(VoiceRoom r, String pw) async {
    try {
      await _ref(r).collection('pass').doc(_me).set({'pw': pw.trim(), 'at': FieldValue.serverTimestamp()});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// المضيف يحذف غرفته المحفوظة نهائياً.
  Future<void> deleteRoom(VoiceRoom r) async {
    try {
      await _ref(r).delete();
    } catch (e) {
      debugPrint('delete room: $e');
    }
  }

  /// المضيف يعيد فتح غرفته المحفوظة.
  Future<void> reopen(VoiceRoom r) async {
    try {
      await _ref(r).update({'open': true, 'closeReason': FieldValue.delete(), 'lastActive': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('reopen: $e');
    }
  }

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
  /// الاتصال المتعثر يُعاد تلقائياً، ولو الطرف المسؤول عن البدء ما بدأ خلال 20 ثانية نبدأ نحن.
  void _connectPeers(VoiceRoom r) {
    if (_room != r) return;
    final speakers = {r.host.id, for (final u in r.onMics) u.id};
    final iSpeak = speakers.contains(_me);
    final wanted = {for (final id in _people.keys) if (iSpeak || speakers.contains(id)) id};
    final rtc = RtcMesh.instance;
    for (final id in [..._sigSubs.keys]) {
      if (wanted.contains(id)) continue;
      // اتصال شغال ما نقطعه لمجرد تأخر نبضة، إلا إذا طلع الشخص فعلاً من الغرفة
      if (rtc.state(id) == 'connected' && _docIds.contains(id) && (iSpeak || speakers.contains(id))) continue;
      _sigSubs.remove(id)?.cancel();
      rtc.close(id);
      _badSince.remove(id);
    }
    final now = DateTime.now();
    for (final id in wanted) {
      _sigSubs[id] ??= _watchSignal(r, id);
      final st = rtc.state(id);
      if (st == 'connected') {
        _badSince.remove(id);
        continue;
      }
      final bad = _badSince.putIfAbsent(id, () => now);
      final badFor = now.difference(bad).inSeconds;
      final last = _offeredAt[id];
      final sinceOffer = last == null ? 999 : now.difference(last).inSeconds;
      final dead = st == 'none' || st == 'failed' || st == 'closed';
      final starter = _me.compareTo(id) < 0;
      final due = starter
          ? (dead && sinceOffer > 4) || (badFor > 10 && sinceOffer > 15)
          : badFor > 20 && sinceOffer > 25;
      if (due) _offer(r, id);
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
