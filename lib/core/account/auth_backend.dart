import 'dart:math';

/// نتيجة تسجيل الدخول من مزود خارجي.
class AuthIdentity {
  const AuthIdentity({required this.uid, required this.name, this.contact});
  final String uid;
  final String name;
  final String? contact;
}

class AuthError implements Exception {
  const AuthError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// واجهة مزود تسجيل الدخول. التنفيذ الحقيقي في core/firebase/cloud.dart.
abstract class AuthBackend {
  /// true في وضع التجربة (بدون سيرفر).
  bool get isDemo;

  /// هل الدخول برقم الهاتف متاح.
  bool get phoneEnabled;
  Future<AuthIdentity> signInWithGoogle();

  /// ربط حساب الضيف الحالي بجوجل مع الاحتفاظ بنفس المعرّف.
  Future<AuthIdentity> linkGoogle();

  /// دخول كضيف.
  Future<AuthIdentity> signInGuest();
  Future<void> sendPhoneCode(String phone);
  Future<AuthIdentity> verifyPhoneCode(String phone, String code);
}

/// وضع التجربة: يحاكي جوجل والرسائل محلياً. رمز التحقق دائماً 000000.
class DemoAuthBackend implements AuthBackend {
  const DemoAuthBackend({this.delay = const Duration(milliseconds: 900)});
  final Duration delay;
  static const demoCode = '000000';

  @override
  bool get isDemo => true;

  @override
  bool get phoneEnabled => true;

  @override
  Future<AuthIdentity> linkGoogle() => signInWithGoogle();

  @override
  Future<AuthIdentity> signInGuest() async {
    final r = Random();
    return AuthIdentity(
      uid: List.generate(8, (_) => r.nextInt(10)).join(),
      name: '',
    );
  }

  @override
  Future<AuthIdentity> signInWithGoogle() async {
    await Future.delayed(delay);
    return const AuthIdentity(
      uid: 'google-demo',
      name: 'لاعب جوجل',
      contact: 'حساب جوجل (تجريبي)',
    );
  }

  @override
  Future<void> sendPhoneCode(String phone) async {
    if (!isValidPhone(phone)) throw const AuthError('رقم الهاتف غير صحيح');
    await Future.delayed(delay);
  }

  @override
  Future<AuthIdentity> verifyPhoneCode(String phone, String code) async {
    await Future.delayed(delay);
    if (code != demoCode) throw const AuthError('رمز التحقق غير صحيح');
    return AuthIdentity(
      uid: 'phone-$phone',
      name: 'لاعب ${phone.substring(phone.length - 4)}',
      contact: phone,
    );
  }
}

/// يقبل الأرقام الدولية: + ثم 8 إلى 15 رقماً.
bool isValidPhone(String phone) => RegExp(r'^\+\d{8,15}$').hasMatch(phone);

/// مزود الدخول المستخدم في التطبيق.
AuthBackend authBackend = const DemoAuthBackend();
