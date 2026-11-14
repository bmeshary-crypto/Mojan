import 'package:flutter/foundation.dart';

/// صلاحيات فريق الإدارة (المفتاح ← الوصف). نفس المفاتيح موجودة في firestore.rules.
const staffPerms = <String, String>{
  'users': 'عرض اللاعبين وصفحاتهم والملاحظات',
  'coins': 'العملات والماسات وVIP والشحن',
  'profile': 'تعديل الملفات والأغراض والـ ID',
  'ban': 'الحظر والتقييد وتسجيل الخروج',
  'rooms': 'إدارة الغرف الصوتية والمراقبة المخفية',
  'reports': 'البلاغات',
  'support': 'الدعم ورسائل اللاعبين وطرق الدفع',
  'results': 'رؤية النتائج القادمة في ألعاب العملات',
  'delete': 'حذف الملفات وتصفير الإحصائيات',
};

/// الأدوار الجاهزة: الاسم وصلاحياتها الافتراضية (يقدر المالك يعدلها لكل شخص).
const staffRoles = <String, (String, Set<String>)>{
  'manager': ('مدير', {'users', 'coins', 'profile', 'ban', 'rooms', 'reports', 'support', 'results', 'delete'}),
  'supervisor': ('مشرف', {'users', 'ban', 'rooms', 'reports', 'support'}),
  'support': ('خدمة عملاء', {'users', 'support'}),
};

String roleTitle(String? role) => role == 'owner' ? 'المالك' : (staffRoles[role]?.$1 ?? 'فريق');

/// عضو في فريق الإدارة.
class StaffInfo {
  const StaffInfo({required this.role, required this.perms, this.name = ''});
  final String role;
  final Set<String> perms;
  final String name;

  static StaffInfo? parse(Object? v) {
    if (v is! Map) return null;
    return StaffInfo(
      role: v['role'] as String? ?? 'supervisor',
      perms: {for (final p in (v['perms'] as List? ?? const [])) if (p is String) p},
      name: v['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'role': role, 'perms': perms.toList()..sort(), 'name': name};
}

/// صلاحيات الحساب المفتوح حالياً (تتحدث من السيرفر).
class Staff {
  Staff._();
  static final instance = Staff._();

  /// null = مو من الفريق.
  final current = ValueNotifier<StaffInfo?>(null);
}
