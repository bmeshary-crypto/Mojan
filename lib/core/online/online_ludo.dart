import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../account/account.dart';
import '../ai/ai_brain.dart';
import '../firebase/cloud.dart';

/// مقعد في مباراة أونلاين: لاعب حقيقي أو شخصية ذكاء اصطناعي.
class OnlineSeat {
  const OnlineSeat({this.uid, this.ai, required this.name, required this.avatar, this.seen});
  final String? uid;
  final String? ai;
  final String name;
  final int avatar;
  final DateTime? seen;
  bool get isAi => ai != null;

  static OnlineSeat? from(Object? v, DateTime? seen) {
    if (v is! Map) return null;
    return OnlineSeat(
      uid: v['uid'] as String?,
      ai: v['ai'] as String?,
      name: (v['name'] as String?) ?? 'لاعب',
      avatar: (v['avatar'] as num?)?.toInt() ?? 0,
      seen: seen,
    );
  }
}

/// مباراة أونلاين في matches/{id}. الحركات في matches/{id}/actions بالترتيب.
class OnlineMatch {
  OnlineMatch(this.id, Map<String, dynamic> d)
      : game = d['game'] as String? ?? 'ludo',
        status = d['status'] as String? ?? 'waiting',
        size = (d['size'] as num?)?.toInt() ?? 2,
        host = d['host'] as String? ?? '',
        lastActive = (d['lastActive'] as Timestamp?)?.toDate(),
        seats = List.generate((d['size'] as num?)?.toInt() ?? 2, (i) {
          final s = (d['seats'] as Map?)?['$i'];
          final uid = s is Map ? s['uid'] as String? : null;
          final seen = uid == null ? null : ((d['seen'] as Map?)?[uid] as Timestamp?)?.toDate();
          return OnlineSeat.from(s, seen);
        });
  final String id;
  final String game;
  final String status;
  final int size;
  final String host;
  final DateTime? lastActive;
  final List<OnlineSeat?> seats;

  int get filled => seats.whereType<OnlineSeat>().length;
  bool get full => filled == size;
  String get hostName => seats.whereType<OnlineSeat>().where((s) => s.uid == host).firstOrNull?.name ?? 'لاعب';
  int seatOf(String? uid) => uid == null ? -1 : seats.indexWhere((s) => s?.uid == uid);

  /// أول لاعب حقيقي متصل: هو من يحرّك لاعبي الذكاء الاصطناعي ويراقب الانقطاع.
  /// الاتصال يُقاس بالنسبة لأحدث لاعب (حتى لا يؤثر فرق ساعات الأجهزة).
  int get controllerSeat {
    final humans = [for (var i = 0; i < size; i++) if (seats[i] != null && !seats[i]!.isAi) i];
    if (humans.isEmpty) return -1;
    final newest = humans.map((i) => seats[i]!.seen).whereType<DateTime>().fold<DateTime?>(
        null, (a, b) => a == null || b.isAfter(a) ? b : a);
    for (final i in humans) {
      final seen = seats[i]!.seen;
      if (newest == null || seen == null || newest.difference(seen).inSeconds < staleSeconds) return i;
    }
    return humans.first;
  }

  static const staleSeconds = 30;
}

class OnlineLudo {
  OnlineLudo._();
  static final instance = OnlineLudo._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  bool get available => Cloud.instance.enabled && Cloud.instance.uid != null;
  String? get uid => Cloud.instance.uid;

  CollectionReference<Map<String, dynamic>> get _matches => _db.collection('matches');

  Map<String, dynamic> _meSeat() {
    final p = Account.instance.profile;
    return {'uid': uid, 'name': p?.name ?? 'لاعب', 'avatar': p?.avatar ?? 0};
  }

  /// الغرف المفتوحة التي تنتظر لاعبين (آخر نشاط خلال دقيقتين).
  Stream<List<OnlineMatch>> openMatches(String game) => _matches
      .where('game', isEqualTo: game)
      .where('status', isEqualTo: 'waiting')
      .limit(30)
      .snapshots()
      .map((s) {
        final now = DateTime.now();
        final list = [
          for (final d in s.docs) OnlineMatch(d.id, d.data()),
        ].where((m) => !m.full && (m.lastActive == null || now.difference(m.lastActive!).inMinutes < 2)).toList()
          ..sort((a, b) => (b.lastActive ?? now).compareTo(a.lastActive ?? now));
        return list;
      });

  Stream<OnlineMatch?> watch(String id) =>
      _matches.doc(id).snapshots().map((d) => d.exists ? OnlineMatch(d.id, d.data()!) : null);

  Future<String> create(String game, int size) async {
    final ref = await _matches.add({
      'game': game,
      'status': 'waiting',
      'size': size,
      'host': uid,
      'seats': {'0': _meSeat()},
      'seen': {uid!: FieldValue.serverTimestamp()},
      'createdAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// يدخل أول مقعد فاضي. يرجع false إذا امتلأت الغرفة أو بدأت.
  Future<bool> join(String id) async {
    try {
      return await _db.runTransaction((tx) async {
        final ref = _matches.doc(id);
        final d = await tx.get(ref);
        if (!d.exists) return false;
        final m = OnlineMatch(d.id, d.data()!);
        if (m.seatOf(uid) >= 0) return true;
        if (m.status != 'waiting' || m.full) return false;
        final i = m.seats.indexWhere((s) => s == null);
        final full = m.filled + 1 == m.size;
        tx.update(ref, {
          'seats.$i': _meSeat(),
          'seen.$uid': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          if (full) 'status': 'playing',
        });
        return true;
      });
    } catch (e) {
      debugPrint('join failed: $e');
      return false;
    }
  }

  /// لعب سريع: يدخل أقدم غرفة مفتوحة بنفس الحجم، أو ينشئ غرفة جديدة.
  Future<String> quick(String game, int size) async {
    final open = await openMatches(game).first;
    for (final m in open.where((m) => m.size == size && m.host != uid)) {
      if (await join(m.id)) return m.id;
    }
    return create(game, size);
  }

  /// يملأ المقاعد الفاضية بشخصيات ذكاء اصطناعي ويبدأ.
  Future<void> fillAiAndStart(OnlineMatch m) async {
    final used = m.seats.whereType<OnlineSeat>().map((s) => s.ai).toSet();
    final free = aiPersonas.where((p) => !used.contains(p.id)).toList();
    final update = <String, Object?>{'status': 'playing', 'lastActive': FieldValue.serverTimestamp()};
    var k = 0;
    for (var i = 0; i < m.size; i++) {
      if (m.seats[i] != null) continue;
      final p = free[k++ % free.length];
      update['seats.$i'] = {'ai': p.id, 'name': '${p.name} 🤖', 'avatar': p.avatar};
    }
    await _matches.doc(m.id).update(update);
  }

  Future<void> heartbeat(String id) => _matches
      .doc(id)
      .update({'seen.$uid': FieldValue.serverTimestamp(), 'lastActive': FieldValue.serverTimestamp()})
      .catchError((_) {});

  /// يحوّل مقعد لاعب منقطع أو منسحب إلى ذكاء اصطناعي حتى تكمل المباراة.
  Future<void> seatToAi(OnlineMatch m, int seat) async {
    final s = m.seats[seat];
    if (s == null || s.isAi) return;
    final used = m.seats.whereType<OnlineSeat>().map((s) => s.ai).toSet();
    final p = aiPersonas.where((p) => !used.contains(p.id)).firstOrNull ?? aiPersonas[seat % aiPersonas.length];
    await _matches.doc(m.id).update({
      'seats.$seat': {'ai': p.id, 'name': '${s.name} (🤖)', 'avatar': s.avatar},
    }).catchError((_) {});
  }

  /// الخروج: قبل البداية نترك المقعد (أو نغلق الغرفة إذا كنا المضيف)، وأثناء اللعب يكمل AI مكاننا.
  Future<void> leave(OnlineMatch m) async {
    final i = m.seatOf(uid);
    if (i < 0) return;
    try {
      if (m.status == 'waiting') {
        if (m.host == uid) {
          await _matches.doc(m.id).update({'status': 'closed'});
        } else {
          await _matches.doc(m.id).update({'seats.$i': FieldValue.delete()});
        }
      } else if (m.status == 'playing') {
        await seatToAi(m, i);
      }
    } catch (_) {}
  }

  Future<void> finish(String id) => _matches.doc(id).update({'status': 'done'}).catchError((_) {});

  // ---------- الحركات ----------

  Future<void> post(String id, int seq, Map<String, Object?> action) => _matches
      .doc(id)
      .collection('actions')
      .doc(seq.toString().padLeft(5, '0'))
      .set({...action, 'seq': seq, 'by': uid, 'at': FieldValue.serverTimestamp()});

  Stream<List<Map<String, dynamic>>> actions(String id) => _matches
      .doc(id)
      .collection('actions')
      .orderBy('seq')
      .snapshots()
      .map((s) => [for (final d in s.docs) d.data()]);
}
