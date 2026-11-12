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
