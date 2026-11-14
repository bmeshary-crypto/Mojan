import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../account/account.dart';
import '../firebase/cloud.dart';

/// نسبة الماسات من قيمة الهدية.
const diamondShare = .30;

int diamondsFor(int coins) => (coins * diamondShare).floor();

/// الماسات: كل هدية من شخص حقيقي لشخص حقيقي تُسجل في gifts/{id}،
/// وجهاز المستلم يستلمها مرة واحدة (معاملة) ويضيف له 30% من قيمتها ماسات.
class Diamonds {
  Diamonds._();
  static final instance = Diamonds._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  StreamSubscription? _sub;
  String? _watching;
  final _claiming = <String>{};

  /// تسجيل هدية لشخص حقيقي.
  Future<void> send({required String to, required int coins, required String gift, String where = ''}) async {
    final me = Cloud.instance.uid;
    if (!Cloud.instance.enabled || me == null || to == me || coins <= 0) return;
    try {
      await _db.collection('gifts').add({
        'from': me,
        'fromName': Account.instance.profile?.name ?? 'لاعب',
        'to': to,
        'coins': coins,
        'gift': gift,
        'where': where,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('gift ledger: $e');
    }
  }

  /// يستلم الهدايا الواصلة لهذا الحساب.
  void watch(String uid) {
    if (_watching == uid) return;
    _sub?.cancel();
    _watching = uid;
    _sub = _db.collection('gifts').where('to', isEqualTo: uid).snapshots().listen((snap) {
      for (final d in snap.docs) {
        _claim(d.reference);
      }
    }, onError: (e) => debugPrint('gifts: $e'));
  }

  Future<void> _claim(DocumentReference<Map<String, dynamic>> ref) async {
    if (!_claiming.add(ref.id)) return;
    try {
      final got = await _db.runTransaction<Map<String, dynamic>?>((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data();
        if (data == null) return null;
        tx.delete(ref);
        return data;
      });
      if (got == null) return;
      final n = diamondsFor((got['coins'] as num?)?.toInt() ?? 0);
      if (n <= 0) return;
      Account.instance.addDiamonds(n, from: '${got['gift'] ?? ''} من ${got['fromName'] ?? 'لاعب'}'.trim());
      Cloud.instance.notice.value = '💎 وصلتك $n ماسة من هدية ${got['fromName'] ?? 'لاعب'}';
    } catch (e) {
      debugPrint('claim gift: $e');
    } finally {
      _claiming.remove(ref.id);
    }
  }
}
