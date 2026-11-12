import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../account/account.dart';
import '../account/auth_backend.dart';
import '../account/leaderboard.dart';
import 'firebase_config.dart';

/// الاتصال بـ Firebase (المشروع mojan-11d86): الحسابات وحفظ الملف الشخصي ولوحة المتصدرين.
/// إذا فشل التشغيل (اختبارات، بيئة تمنع Firebase) يبقى [enabled] false
/// ويعمل التطبيق محلياً في وضع التجربة كما كان.
class Cloud {
  Cloud._() {
    if (!kIsWeb) _ready.complete(); // خارج الويب لا يوجد إعداد Firebase حالياً
  }
  static final Cloud instance = Cloud._();

  bool enabled = false;
  final _ready = Completer<void>();

  /// يكتمل بعد محاولة التشغيل (نجحت أو فشلت).
  Future<void> get ready => _ready.future;
  Timer? _debounce;
  String? _weekKey;
  Map<String, dynamic> _weekBase = {};

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get uid => enabled ? _auth.currentUser?.uid : null;

  Future<void> init() async {
    try {
      await _init();
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> _init() async {
    if (!kIsWeb) return; // الإعداد الحالي لنسخة الويب فقط
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: firebaseWebConfig['apiKey']!,
          authDomain: firebaseWebConfig['authDomain'],
          projectId: firebaseWebConfig['projectId']!,
          storageBucket: firebaseWebConfig['storageBucket'],
          messagingSenderId: firebaseWebConfig['messagingSenderId']!,
          appId: firebaseWebConfig['appId']!,
          measurementId: firebaseWebConfig['measurementId'],
        ),
      ).timeout(const Duration(seconds: 20));
      // انتظار استرجاع جلسة الدخول المحفوظة في المتصفح
      await _auth.authStateChanges().first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      enabled = true;
      authBackend = const FirebaseAuthBackend();
    } catch (e) {
      debugPrint('Cloud.init failed, staying in demo mode: $e');
      enabled = false;
    }
  }

  /// الملف الشخصي المحفوظ على السيرفر لهذا المستخدم، إن وجد.
  Future<Map<String, dynamic>?> fetchProfile(String uid) async {
    if (!enabled) return null;
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));
      final data = doc.data();
      if (data == null) return null;
      _weekKey = data['wk'] as String?;
      _weekBase = Map<String, dynamic>.from(data['wb'] as Map? ?? {});
      return data['profile'] == null
          ? null
          : Map<String, dynamic>.from(data['profile'] as Map);
    } catch (e) {
      debugPrint('Cloud.fetchProfile failed: $e');
      return null;
    }
  }

  /// دخول صامت كضيف لحفظ التقدم على السيرفر. يرجع null عند الفشل.
  Future<String?> ensureUser() async {
    if (!enabled) return null;
    try {
      return _auth.currentUser?.uid ??
          (await _auth.signInAnonymously()).user?.uid;
    } catch (e) {
      debugPrint('Cloud.ensureUser failed: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    if (!enabled) return;
    _debounce?.cancel();
    _weekKey = null;
    _weekBase = {};
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  /// حفظ مؤجل قليلاً حتى لا نكتب مع كل عملة.
  void scheduleSave(PlayerProfile p) {
    if (!enabled || _auth.currentUser?.uid != p.id) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => saveNow(p));
  }

  Future<void> saveNow(PlayerProfile p) async {
    if (!enabled || _auth.currentUser?.uid != p.id) return;
    final scores = <String, int>{
      for (final key in boardKeys)
        key: Leaderboard.scoreOf(p, key == 'all' ? null : key),
    };
    final week = weekKey(DateTime.now());
    if (_weekKey != week) {
      _weekKey = week;
      _weekBase = Map.of(scores);
    }
    try {
      await _db.collection('users').doc(p.id).set({
        'profile': p.toJson(),
        'name': p.name,
        'avatar': p.avatar,
        's': scores,
        'w': {
          for (final e in scores.entries)
            e.key: e.value - ((_weekBase[e.key] as num?)?.toInt() ?? e.value),
        },
        'win': {
          for (final key in boardKeys)
            key: Leaderboard.winsOf(p, key == 'all' ? null : key),
        },
        'wk': week,
        'wb': _weekBase,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Cloud.save failed: $e');
    }
  }

  /// أفضل اللاعبين الحقيقيين. [game] = null للترتيب العام.
  Future<List<LeaderEntry>?> topPlayers({
    String? game,
    bool weekly = false,
  }) async {
    if (!enabled) return null;
    final key = game ?? 'all';
    final field = '${weekly ? 'w' : 's'}.$key';
    final week = weekKey(DateTime.now());
    try {
      final snap = await _db
          .collection('users')
          .orderBy(field, descending: true)
          .limit(50)
          .get()
          .timeout(const Duration(seconds: 8));
      final me = _auth.currentUser?.uid;
      return [
        for (final d in snap.docs)
          if (!weekly || d.data()['wk'] == week)
            LeaderEntry(
              name: (d.data()['name'] as String?) ?? 'لاعب',
              avatar:
                  ((d.data()['avatar'] as num?)?.toInt() ?? 0) % avatars.length,
              points:
                  (((d.data()[weekly ? 'w' : 's'] as Map?)?[key]) as num?)
                      ?.toInt() ??
                  0,
              wins: (((d.data()['win'] as Map?)?[key]) as num?)?.toInt() ?? 0,
              isMe: d.id == me,
            ),
      ];
    } catch (e) {
      debugPrint('Cloud.topPlayers failed: $e');
      return null;
    }
  }
}

/// مفاتيح لوحات المتصدرين: العامة وكل لعبة.
final boardKeys = ['all', ...gameTitles.keys];

/// مفتاح الأسبوع الحالي (يبدأ السبت)، مثل 2026-11-07.
String weekKey(DateTime now) {
  final d = DateTime(now.year, now.month, now.day);
  final start = d.subtract(Duration(days: (d.weekday + 1) % 7));
  return '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
}

/// تسجيل دخول حقيقي عبر Firebase Auth (جوجل والضيف). الهاتف يحتاج خطة Blaze فهو غير مفعّل.
class FirebaseAuthBackend implements AuthBackend {
  const FirebaseAuthBackend();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  bool get isDemo => false;

  @override
  bool get phoneEnabled => false;

  AuthIdentity _identity(User u, {bool google = true}) => AuthIdentity(
    uid: u.uid,
    name: u.displayName ?? 'لاعب',
    contact: google ? (u.email ?? 'حساب جوجل') : null,
  );

  Future<T> _guard<T>(Future<T> Function() job) async {
    try {
      return await job();
    } on FirebaseAuthException catch (e) {
      throw AuthError(switch (e.code) {
        'popup-closed-by-user' ||
        'cancelled-popup-request' => 'تم إلغاء تسجيل الدخول',
        'popup-blocked' =>
          'المتصفح منع نافذة جوجل، اسمح بالنوافذ المنبثقة وحاول مجدداً',
        'unauthorized-domain' => 'الدخول بجوجل يعمل من موقع MOJAN الرسمي فقط',
        'credential-already-in-use' ||
        'email-already-in-use' => 'حساب جوجل هذا مرتبط بلاعب آخر',
        'network-request-failed' => 'تحقق من اتصال الإنترنت',
        _ => 'تعذر تسجيل الدخول (${e.code})',
      });
    }
  }

  @override
  Future<AuthIdentity> signInWithGoogle() => _guard(() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    final cred = await _auth.signInWithPopup(provider);
    return _identity(cred.user!);
  });

  @override
  Future<AuthIdentity> linkGoogle() => _guard(() async {
    final u = _auth.currentUser;
    if (u == null) return signInWithGoogle();
    final cred = await u.linkWithPopup(GoogleAuthProvider());
    return _identity(cred.user!);
  });

  @override
  Future<AuthIdentity> signInGuest() => _guard(() async {
    final cred = await _auth.signInAnonymously();
    return _identity(cred.user!, google: false);
  });

  @override
  Future<void> sendPhoneCode(String phone) async =>
      throw const AuthError('الدخول بالهاتف غير متاح حالياً، استخدم جوجل');

  @override
  Future<AuthIdentity> verifyPhoneCode(String phone, String code) async =>
      throw const AuthError('الدخول بالهاتف غير متاح حالياً، استخدم جوجل');
}
