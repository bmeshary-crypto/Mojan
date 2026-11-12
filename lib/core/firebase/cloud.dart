import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account/account.dart';
import '../account/auth_backend.dart';
import '../account/leaderboard.dart';
import '../ban.dart';
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

  /// هل الحساب الحالي أدمن (حسابات محددة في firebase_config.dart).
  bool get isAdmin => adminUids.contains(uid);

  /// حساب موقوف من الإدارة.
  final banned = ValueNotifier<bool>(false);

  /// إشعار من الإدارة يظهر للاعب (مثل وصول عملات الشحن).
  final notice = ValueNotifier<String?>(null);
  StreamSubscription? _meSub;
  String? _watching;

  // ---- التواجد: من داخل التطبيق الآن ومن بالخلفية ومن خارجه ----

  Timer? _presenceTimer;
  AppLifecycleListener? _life;
  String _state = 'on';
  String? _where;

  /// أين اللاعب الآن (مثلاً اسم الغرفة الصوتية) ليظهر للأدمن.
  void setWhere(String? where) {
    if (_where == where) return;
    _where = where;
    _beatPresence();
  }

  void _startPresence() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_state == 'on') _beatPresence();
    });
    _life ??= AppLifecycleListener(onStateChange: (s) {
      final next = switch (s) {
        AppLifecycleState.resumed || AppLifecycleState.inactive => 'on',
        AppLifecycleState.detached => 'off',
        _ => 'away',
      };
      if (next == _state) return;
      _state = next;
      _beatPresence();
    });
    _beatPresence();
  }

  Future<void> _beatPresence() async {
    final id = _watching;
    if (!enabled || id == null) return;
    try {
      await _db.collection('users').doc(id).set({
        'seen': FieldValue.serverTimestamp(),
        'state': _state,
        'where': _where ?? FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('presence: $e');
    }
  }

  /// للأدمن: آخر من ظهر في التطبيق خلال أسبوع، الأحدث أولاً (يتحدث مباشرة).
  Stream<List<Map<String, dynamic>>> presence() {
    if (!isAdmin) return Stream.value(const []);
    final since = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
    return _db
        .collection('users')
        .where('seen', isGreaterThan: since)
        .orderBy('seen', descending: true)
        .limit(150)
        .snapshots()
        .map((s) => [for (final d in s.docs) {...d.data(), 'uid': d.id}]);
  }

  /// متابعة مستند اللاعب: هدايا العملات من الأدمن والإيقاف.
  void watchMe(String id) {
    if (!enabled || _watching == id) return;
    _meSub?.cancel();
    _watching = id;
    _startPresence();
    _meSub = _db.collection('users').doc(id).snapshots().listen((doc) async {
      final data = doc.data();
      if (data == null) return;
      Restrictions.instance.set(isAdmin ? null : BanInfo.parse(data['banned']));
      banned.value = Restrictions.instance.fullBan.value;
      final edit = data['edit'];
      if (edit is Map) {
        try {
          await doc.reference.update({'edit': FieldValue.delete()});
          final acc = Account.instance;
          if (edit['name'] is String) await acc.rename(edit['name'] as String);
          if (edit['bio'] is String) acc.setBio(edit['bio'] as String);
          if (edit['avatar'] is num) await acc.setAvatar((edit['avatar'] as num).toInt());
          if (edit['vipAdd'] is num) acc.addVip((edit['vipAdd'] as num).toInt());
          if (edit['sid'] is String) acc.adoptSpecialId(edit['sid'] as String);
        } catch (e) {
          debugPrint('edit failed: $e');
        }
      }
      if (data['grants'] is Map || data['grant'] is Map) await _claimGrants(doc.reference);
    }, onError: (e) => debugPrint('watchMe: $e'));
  }

  /// يستلم كل شحنات الإدارة المعلقة مرة واحدة (معاملة حتى لا يضيع أو يتكرر شيء).
  bool _claiming = false;
  Future<void> _claimGrants(DocumentReference<Map<String, dynamic>> ref) async {
    if (_claiming) return;
    final acc = Account.instance;
    // نستلم فقط إذا كان الحساب المفتوح فعلاً هو صاحب المستند (مهم لو تبدّل الحساب على نفس المتصفح)
    if (acc.profile?.id != ref.id || _auth.currentUser?.uid != ref.id) return;
    _claiming = true;
    try {
      final total = await _db.runTransaction<int>((tx) async {
        final d = await tx.get(ref);
        final data = d.data() ?? const {};
        var sum = 0;
        final grants = data['grants'];
        if (grants is Map) {
          for (final g in grants.values) {
            if (g is Map && g['coins'] is num) sum += (g['coins'] as num).toInt();
          }
        }
        final old = data['grant'];
        if (old is Map && old['coins'] is num) sum += (old['coins'] as num).toInt();
        tx.update(ref, {'grants': FieldValue.delete(), 'grant': FieldValue.delete()});
        return sum;
      });
      if (total > 0) {
        acc.earn(total);
        acc.addVip(total);
        await saveNow(acc.profile!);
        notice.value = 'تم شحن حسابك بـ $total عملة 🪙\nاستمتعوا باللعب! 🎉';
      }
    } catch (e) {
      debugPrint('grant failed: $e');
    } finally {
      _claiming = false;
    }
  }

  /// حجز رقم ID مميز (فريد على مستوى التطبيق). يرجع رسالة خطأ أو null.
  /// بدون سحابة (وضع التجربة) يُقبل محلياً.
  Future<String?> claimId(String id, {String? release, String? forUid}) async {
    final me = forUid ?? uid;
    if (!enabled || me == null) return null;
    try {
      return await _db.runTransaction<String?>((tx) async {
        final ref = _db.collection('ids').doc(id);
        final cur = await tx.get(ref);
        if (cur.exists && cur.data()?['uid'] != me) return 'هذا الـ ID محجوز لشخص ثاني، جرّب غيره';
        tx.set(ref, {'uid': me, 'at': FieldValue.serverTimestamp()});
        if (release != null && release != id) {
          tx.delete(_db.collection('ids').doc(release));
        }
        return null;
      });
    } catch (e) {
      debugPrint('claimId: $e');
      return 'تعذر حجز الـ ID، حاول مرة ثانية';
    }
  }

  Future<void> releaseId(String id) async {
    if (!enabled) return;
    try {
      await _db.collection('ids').doc(id).delete();
    } catch (e) {
      debugPrint('releaseId: $e');
    }
  }

  // ---- أدوات الأدمن ----

  Future<List<Map<String, dynamic>>> adminUsers() async {
    if (!isAdmin) return [];
    final snap = await _db.collection('users').orderBy('updatedAt', descending: true).limit(200).get();
    return [for (final d in snap.docs) {...d.data(), 'uid': d.id}];
  }

  /// شحن عملات للاعب: تنضاف لحسابه فوراً إذا كان فاتح اللعبة، أو أول ما يفتحها، ويوصله إشعار
  /// ورسالة من الإدارة في محادثة الدعم.
  Future<void> adminGrant(String id, int coins) async {
    final key = '${DateTime.now().millisecondsSinceEpoch}';
    await _db.collection('users').doc(id).set({
      'grants': {key: {'coins': coins, 'at': FieldValue.serverTimestamp()}},
    }, SetOptions(merge: true));
    try {
      final ref = _db.collection('support').doc(id);
      await ref.collection('messages').add({
        'from': 'admin',
        'text': 'تم إضافة $coins عملة شحن لحسابك 🪙 استمتعوا باللعب! 🎉',
        'at': FieldValue.serverTimestamp(),
      });
      await ref.set({
        'lastText': 'تم شحن $coins عملة',
        'lastAt': FieldValue.serverTimestamp(),
        'unreadUser': true,
        'unreadAdmin': false,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('grant message failed: $e');
    }
  }

  /// تعديل ملف لاعب: يُطبق على جهازه عند فتح التطبيق.
  Future<void> adminEdit(String id, {String? name, String? bio, int? avatar, int? vipAdd, String? sid}) => _db.collection('users').doc(id).set({
        'edit': {'name': ?name, 'bio': ?bio, 'avatar': ?avatar, 'vipAdd': ?vipAdd, 'sid': ?sid},
        'name': ?name,
        'avatar': ?avatar,
      }, SetOptions(merge: true));

  /// إيقاف أو رفع إيقاف كل الحسابات على نفس الجهاز.
  Future<void> adminBanDevice(String device, bool ban) async {
    final snap = await _db.collection('users').where('device', isEqualTo: device).get();
    for (final d in snap.docs) {
      if (adminUids.contains(d.id)) continue;
      await d.reference.set({'banned': ban}, SetOptions(merge: true));
    }
  }

  Future<void> adminBan(String id, bool ban) => _db.collection('users').doc(id).set({'banned': ban}, SetOptions(merge: true));

  /// حظر أو تقييد عدة حسابات بمدة (ban = null يفك الحظر والقيود).
  Future<void> adminSetBan(List<String> ids, BanInfo? ban) async {
    for (final id in ids) {
      await _db.collection('users').doc(id).set(
        {'banned': ban == null ? FieldValue.delete() : ban.toJson()},
        SetOptions(merge: true),
      );
    }
  }

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
      // حماية الذكاء الاصطناعي من الاستغلال (reCAPTCHA Enterprise، مفتاح الموقع عام وليس سرياً)
      try {
        await FirebaseAppCheck.instance.activate(providerWeb: ReCaptchaEnterpriseProvider(recaptchaSiteKey));
      } catch (e) {
        debugPrint('AppCheck failed: $e');
      }
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
    _meSub?.cancel();
    _meSub = null;
    _watching = null;
    banned.value = false;
    Restrictions.instance.set(null);
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
        'device': await deviceId(),
        'tz': _timeZone(),
        'lang': PlatformDispatcher.instance.locale.toLanguageTag(),
        'wb': _weekBase,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      watchMe(p.id);
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

String? _device;

/// معرّف ثابت لهذا الجهاز/المتصدفح، مشترك بين كل الحسابات عليه (لكشف تعدد الحسابات).
Future<String> deviceId() async {
  if (_device != null) return _device!;
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('mojan.device');
  if (id == null) {
    final r = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    id = List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
    await prefs.setString('mojan.device', id);
  }
  return _device = id;
}

String _timeZone() {
  final o = DateTime.now().timeZoneOffset;
  final h = o.inHours, m = o.inMinutes.remainder(60).abs();
  return 'UTC${o.isNegative ? '-' : '+'}${h.abs()}${m == 0 ? '' : ':$m'} ${DateTime.now().timeZoneName}';
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
