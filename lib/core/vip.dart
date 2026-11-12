import 'package:flutter/material.dart';

/// مستويات VIP: تُكسب بنقاط VIP (كل عملة شحن = نقطة، وكل عملة تُصرف على هدايا أو المتجر = نقطة).
/// الرهانات في الألعاب لا تحتسب حتى ما يصير اللعب طريقة سهلة للترقية.
/// المزايا تراكمية: كل مستوى ياخذ مزايا اللي قبله.
class VipTier {
  const VipTier({
    required this.level,
    required this.name,
    required this.points,
    required this.colors,
    required this.daily,
    this.discount = 0,
    this.unlocks = const [],
    this.perks = const [],
  });

  final int level;
  final String name;

  /// النقاط المطلوبة للوصول لهذا المستوى.
  final int points;
  final List<Color> colors;

  /// مكافأة يومية بالعملات.
  final int daily;

  /// خصم المتجر (نسبة مئوية).
  final int discount;

  /// مظاهر من المتجر تُفتح مجاناً.
  final List<String> unlocks;

  /// مزايا إضافية جديدة في هذا المستوى (نصوص للعرض).
  final List<String> perks;

  String get badge => 'VIP$level';
}

const vipTiers = <VipTier>[
  VipTier(
    level: 1,
    name: 'برونزي',
    points: 5000,
    colors: [Color(0xFFE0A27A), Color(0xFF9C5A33)],
    daily: 100,
    perks: ['شارة VIP بجانب اسمك في الغرف والملف', 'اسمك بلون مميز في الدردشة'],
  ),
  VipTier(
    level: 2,
    name: 'فضي',
    points: 20000,
    colors: [Color(0xFFE8EEF7), Color(0xFF8B9BB4)],
    daily: 200,
    unlocks: ['bubble.gold'],
    perks: ['فقاعة الدردشة الذهبية مجاناً'],
  ),
  VipTier(
    level: 3,
    name: 'ذهبي',
    points: 60000,
    colors: [Color(0xFFFFE27A), Color(0xFFFF9F1C)],
    daily: 400,
    discount: 5,
    unlocks: ['frame.royal'],
    perks: ['الإطار الملكي مجاناً', 'خصم 5% على المتجر'],
  ),
  VipTier(
    level: 4,
    name: 'بلاتيني',
    points: 150000,
    colors: [Color(0xFF9DF3FF), Color(0xFF2E9BD6)],
    daily: 800,
    discount: 5,
    unlocks: ['entrance.lion'],
    perks: ['دخولية الأسد الملكي مجاناً', 'إعلان دخولك للغرفة باسم VIP'],
  ),
  VipTier(
    level: 5,
    name: 'ماسي',
    points: 400000,
    colors: [Color(0xFFC9A7FF), Color(0xFF6A3DE8)],
    daily: 1500,
    discount: 10,
    perks: ['حماية من الطرد: المضيف ما يقدر يطردك من الغرفة', 'خصم 10% على المتجر'],
  ),
  VipTier(
    level: 6,
    name: 'ملكي',
    points: 1000000,
    colors: [Color(0xFFFF9EC7), Color(0xFFD6246E)],
    daily: 3000,
    discount: 10,
    unlocks: ['entrance.jet'],
    perks: ['دخولية الطائرة الخاصة مجاناً'],
  ),
  VipTier(
    level: 7,
    name: 'أسطوري',
    points: 2500000,
    colors: [Color(0xFFFF8A5C), Color(0xFFB8001F)],
    daily: 6000,
    discount: 15,
    perks: ['خصم 15% على المتجر', 'أولوية في طلبات المايك'],
  ),
  VipTier(
    level: 8,
    name: 'إمبراطور',
    points: 6000000,
    colors: [Color(0xFFFFF4B0), Color(0xFFFFB800), Color(0xFF8A4B00)],
    daily: 12000,
    discount: 20,
    perks: ['خصم 20% على المتجر', 'تاج الإمبراطور بجانب اسمك'],
  ),
];

/// المستوى المقابل لعدد النقاط (0 = ليس VIP).
int vipLevelFor(int points) {
  var l = 0;
  for (final t in vipTiers) {
    if (points >= t.points) l = t.level;
  }
  return l;
}

VipTier? vipTier(int level) => level <= 0 ? null : vipTiers[(level - 1).clamp(0, vipTiers.length - 1)];

/// شارة VIP صغيرة بلون المستوى.
class VipBadge extends StatelessWidget {
  const VipBadge(this.level, {super.key, this.size = 12});
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = vipTier(level);
    if (t == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * .45, vertical: size * .08),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: t.colors),
        borderRadius: BorderRadius.circular(size * .7),
        border: Border.all(color: Colors.white.withValues(alpha: .7), width: 1),
      ),
      child: Text(
        '${level >= 8 ? '👑 ' : ''}${t.badge}',
        textDirection: TextDirection.ltr,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: size, color: const Color(0xFF2A1400), height: 1.2),
      ),
    );
  }
}

/// أقل عدد أرقام مسموح للـ ID المميز حسب مستوى VIP (null = غير متاح).
/// VIP3 = 7 أرقام، VIP4 = 6، ... VIP8 = رقمين.
int? specialIdDigits(int vipLevel) => vipLevel < 3 ? null : (10 - vipLevel).clamp(2, 7);

/// الـ ID العادي لكل لاعب: 8 أرقام ثابتة مشتقة من معرف الحساب.
String defaultPlayerId(String uid) {
  var h = 0x811c9dc5;
  for (final c in uid.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  return '${10000000 + h % 90000000}';
}

/// يتحقق من صيغة ID مميز لمستوى معين. يرجع رسالة خطأ أو null.
String? checkSpecialId(String id, int vipLevel) {
  final min = specialIdDigits(vipLevel);
  if (min == null) return 'الـ ID المميز يبدأ من VIP3';
  if (!RegExp(r'^[0-9]+$').hasMatch(id)) return 'الـ ID أرقام فقط';
  if (id.startsWith('0')) return 'ما يبدأ بصفر';
  if (id.length < min) return 'مستواك يسمح بـ ID من $min أرقام أو أكثر';
  if (id.length > 7) return 'الـ ID المميز من 7 أرقام كحد أقصى';
  return null;
}

/// اقتراحات أرقام مميزة بعدد أرقام معين (مكررة ومتسلسلة).
List<String> specialIdIdeas(int digits) {
  final out = <String>[];
  for (final d in [7, 8, 9, 1, 5, 6]) {
    out.add('$d' * digits);
  }
  final seq = '123456789'.substring(0, digits.clamp(2, 9));
  out.insert(2, seq);
  out.add('1'.padRight(digits, '0'));
  if (digits >= 4) out.add(('78' * digits).substring(0, digits));
  return out.toSet().toList();
}

/// شارة الـ ID: ذهبية مع 💎 للمميز، وعادية للباقي.
class PlayerIdTag extends StatelessWidget {
  const PlayerIdTag(this.id, {super.key, this.special = false, this.size = 12});
  final String id;
  final bool special;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: size * .6, vertical: size * .15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size),
          gradient: special ? const LinearGradient(colors: [Color(0xFFFFF0A8), Color(0xFFFFB800), Color(0xFFFF7A00)]) : null,
          color: special ? null : Colors.white.withValues(alpha: .1),
          border: special ? Border.all(color: Colors.white, width: 1) : null,
          boxShadow: special ? [BoxShadow(color: const Color(0xFFFFB800).withValues(alpha: .5), blurRadius: 8)] : null,
        ),
        child: Text(
          special ? '💎 ID $id' : 'ID $id',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            letterSpacing: special ? 1.2 : .3,
            color: special ? const Color(0xFF4A2600) : Colors.white70,
          ),
        ),
      );
}
