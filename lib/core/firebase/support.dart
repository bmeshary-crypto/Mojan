import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../account/account.dart';
import 'cloud.dart';
import 'firebase_config.dart';

/// رسالة في محادثة الدعم بين لاعب والإدارة.
class SupportMsg {
  const SupportMsg({required this.fromAdmin, required this.text, this.at});
  final bool fromAdmin;
  final String text;
  final DateTime? at;
}

/// محادثة خاصة: كل لاعب يراسل الإدارة فقط، والأدمن يرد من لوحة التحكم.
/// support/{uid} ملخص المحادثة، و support/{uid}/messages الرسائل.
class Support {
  Support._();
  static final instance = Support._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  bool get available => Cloud.instance.enabled && Cloud.instance.uid != null;

  /// بيانات صفحة الأدمن (الاسم والصورة) من ملفه.
  Future<Map<String, dynamic>?> adminProfile() async {
    if (!available) return null;
    try {
      final d = await _db.collection('users').doc(adminUids.first).get();
      return d.data();
    } catch (_) {
      return null;
    }
  }

  Stream<List<SupportMsg>> messages(String uid) => _db
      .collection('support')
      .doc(uid)
      .collection('messages')
      .orderBy('at')
      .limitToLast(100)
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              SupportMsg(
                fromAdmin: d.data()['from'] == 'admin',
                text: d.data()['text'] ?? '',
                at: (d.data()['at'] as Timestamp?)?.toDate(),
              ),
          ]);

  /// إرسال رسالة. [uid] صاحب المحادثة (اللاعب). الأدمن يرسل بـ asAdmin.
  Future<void> send(String uid, String text, {bool asAdmin = false}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final p = Account.instance.profile;
    final ref = _db.collection('support').doc(uid);
    await ref.collection('messages').add({'from': asAdmin ? 'admin' : 'user', 'text': t, 'at': FieldValue.serverTimestamp()});
    await ref.set({
      if (!asAdmin) 'name': p?.name ?? 'لاعب',
      if (!asAdmin) 'avatar': p?.avatar ?? 0,
      'lastText': t,
      'lastAt': FieldValue.serverTimestamp(),
      'unreadAdmin': !asAdmin,
      'unreadUser': asAdmin,
    }, SetOptions(merge: true));
  }

  Future<void> markRead(String uid, {bool asAdmin = false}) =>
      _db.collection('support').doc(uid).set({asAdmin ? 'unreadAdmin' : 'unreadUser': false}, SetOptions(merge: true));

  /// محادثات الدعم للأدمن، الأحدث أولاً.
  Stream<List<Map<String, dynamic>>> inbox() => _db
      .collection('support')
      .orderBy('lastAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => [for (final d in s.docs) {...d.data(), 'uid': d.id}]);

  // ---------- البلاغات مع صورة الشاشة ----------

  Future<void> report({
    required String reason,
    String? roomId,
    String? roomTitle,
    String? target,
    Uint8List? screenshot,
  }) async {
    if (!available) return;
    final p = Account.instance.profile;
    try {
      await _db.collection('reports').add({
        'by': Cloud.instance.uid,
        'byName': p?.name ?? 'لاعب',
        'reason': reason,
        'roomId': ?roomId,
        'roomTitle': ?roomTitle,
        'target': ?target,
        // صورة صغيرة (أقل من 700 كيلوبايت) داخل البلاغ نفسه
        if (screenshot != null) 'shot': base64Encode(screenshot),
        'status': 'open',
        'at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('report failed: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> reports() => _db
      .collection('reports')
      .orderBy('at', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => [for (final d in s.docs) {...d.data(), 'id': d.id}]);

  Future<void> setReportStatus(String id, String status) =>
      _db.collection('reports').doc(id).update({'status': status});
}
