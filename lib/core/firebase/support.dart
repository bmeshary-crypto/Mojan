import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../account/account.dart';
import 'cloud.dart';
import 'firebase_config.dart';

/// رسالة في محادثة الدعم بين لاعب والإدارة.
class SupportMsg {
  const SupportMsg({required this.fromAdmin, required this.text, this.at, this.kind = 'text', this.img, this.auto = false});
  final bool fromAdmin;
  final String text;
  final DateTime? at;

  /// text, topup (طلب شحن), methods (اختيار طريقة الدفع), details, proof (صورة التحويل).
  final String kind;
  final Uint8List? img;

  /// رد تلقائي باسم الإدارة.
  final bool auto;
}

/// طرق الدفع المتاحة للشحن.
const payMethods = <String, String>{'bank': 'تحويل بنكي', 'stc': 'STC Pay', 'wallet': 'محفظة إلكترونية'};

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
                fromAdmin: d.data()['from'] == 'admin' || d.data()['from'] == 'auto',
                auto: d.data()['from'] == 'auto',
                text: d.data()['text'] ?? '',
                kind: d.data()['kind'] as String? ?? 'text',
                img: _img(d.data()['img']),
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

  static Uint8List? _img(Object? v) {
    if (v is! String) return null;
    try {
      return base64Decode(v);
    } catch (_) {
      return null;
    }
  }

  Future<void> _add(String uid, Map<String, Object?> msg) =>
      _db.collection('support').doc(uid).collection('messages').add({...msg, 'at': FieldValue.serverTimestamp()});

  Future<void> _summary(String uid, String last, {Map<String, Object?> extra = const {}}) {
    final p = Account.instance.profile;
    return _db.collection('support').doc(uid).set({
      'name': p?.name ?? 'لاعب',
      'avatar': p?.avatar ?? 0,
      'lastText': last,
      'lastAt': FieldValue.serverTimestamp(),
      'unreadAdmin': true,
      ...extra,
    }, SetOptions(merge: true));
  }

  // ---------- طلبات الشحن ----------

  /// اللاعب يطلب باقة: يوصل طلب للإدارة ويطلع له رد تلقائي باختيار طريقة الدفع.
  Future<void> requestTopup(String uid, int coins, String price) async {
    final text = 'طلب شحن باقة $coins عملة ($price ر.س) 💰';
    await _add(uid, {'from': 'user', 'kind': 'topup', 'text': text, 'coins': coins, 'price': price});
    await _summary(uid, text, extra: {
      'pending': {'coins': coins, 'price': price, 'proof': false, 'at': FieldValue.serverTimestamp()},
    });
    await _add(uid, {
      'from': 'auto',
      'kind': 'methods',
      'text': 'أهلاً فيك 🌹 برجاء اختيار طريقة الشحن:',
    });
  }

  /// تفاصيل طرق الدفع (يعدلها الأدمن).
  Future<Map<String, String>> paymentConfig() async {
    try {
      final d = await _db.collection('config').doc('payments').get();
      return {for (final e in (d.data() ?? const {}).entries) if (e.value is String) e.key: e.value as String};
    } catch (_) {
      return const {};
    }
  }

  Future<void> setPaymentConfig(Map<String, String> v) =>
      _db.collection('config').doc('payments').set(v, SetOptions(merge: true));

  Future<void> chooseMethod(String uid, String method) async {
    final label = payMethods[method] ?? method;
    await _add(uid, {'from': 'user', 'kind': 'text', 'text': 'طريقة الدفع: $label'});
    final cfg = await paymentConfig();
    final details = (cfg[method] ?? '').trim();
    await _add(uid, {
      'from': 'auto',
      'kind': 'details',
      'text': '${details.isEmpty ? 'الإدارة بترسل لك تفاصيل $label هنا.' : 'تفاصيل $label:\n$details'}\n\n'
          'بعد التحويل برجاء إرفاق صورة من التحويل 📎 وسيتم شحن حسابكم مباشرة بعد موافقة الإدارة ✅',
    });
    await _summary(uid, 'طريقة الدفع: $label', extra: {'pending': {'method': method}});
  }

  Future<void> sendProof(String uid, Uint8List jpeg) async {
    await _add(uid, {'from': 'user', 'kind': 'proof', 'text': '📎 صورة التحويل', 'img': base64Encode(jpeg)});
    await _summary(uid, '📎 صورة التحويل', extra: {'pending': {'proof': true}});
    await _add(uid, {
      'from': 'auto',
      'kind': 'text',
      'text': 'استلمنا صورة التحويل 👍 بيتم شحن حسابك أول ما توافق الإدارة.',
    });
  }

  Stream<Map<String, dynamic>?> chat(String uid) =>
      _db.collection('support').doc(uid).snapshots().map((d) => d.data());

  /// الأدمن يوافق: تنضاف العملات للاعب ويوصله إشعار.
  Future<void> approveTopup(String uid, int coins) async {
    await Cloud.instance.adminGrant(uid, coins);
    await _db.collection('support').doc(uid).set({'pending': FieldValue.delete()}, SetOptions(merge: true));
  }

  Future<void> rejectTopup(String uid) async {
    await send(uid, 'نعتذر، ما قدرنا نأكد التحويل ❌ تواصل معنا هنا إذا عندك أي استفسار.', asAdmin: true);
    await _db.collection('support').doc(uid).set({'pending': FieldValue.delete()}, SetOptions(merge: true));
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
