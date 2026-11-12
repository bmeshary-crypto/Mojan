import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/account/account.dart';
import '../core/theme.dart';

/// صورة اللاعب الرمزية.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.index, this.size = 48, this.ring = true});
  final int index;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final (emoji, color) = avatars[index % avatars.length];
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring ? size * .06 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ring ? const LinearGradient(colors: [AppColors.gold, AppColors.ludo]) : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [Color.lerp(Color(color), Colors.white, .35)!, Color(color)]),
        ),
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/images/av_${index % avatars.length}.webp',
          width: size,
          height: size,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -.2),
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) =>
              Text(emoji, style: TextStyle(fontSize: size * .5, height: 1.1)),
        ),
      ),
    );
  }
}

/// مكان الفتحة الدائرية في كل إطار (مركزها ونصف قطرها كنسبة من عرض الصورة)،
/// مقاسة من الصور نفسها عشان يجي الإطار مضبوط على الأفاتار.
const frameHoles = <String, (double, double, double)>{
  'fr_angel': (0.489, 0.509, 0.204),
  'fr_candy': (0.500, 0.498, 0.287),
  'fr_demon': (0.494, 0.486, 0.207),
  'fr_desert': (0.499, 0.499, 0.286),
  'fr_emerald': (0.496, 0.499, 0.285),
  'fr_fire': (0.489, 0.532, 0.208),
  'fr_galaxy': (0.500, 0.497, 0.280),
  'fr_hearts': (0.503, 0.500, 0.198),
  'fr_ice': (0.494, 0.499, 0.201),
  'fr_jungle': (0.504, 0.517, 0.207),
  'fr_neon': (0.496, 0.499, 0.285),
  'fr_ocean': (0.510, 0.488, 0.272),
  'fr_phoenix': (0.498, 0.507, 0.269),
  'fr_rainbow': (0.496, 0.500, 0.212),
  'fr_ramadan': (0.502, 0.499, 0.199),
  'fr_royal': (0.495, 0.492, 0.212),
  'fr_sakura': (0.502, 0.505, 0.274),
  'fr_storm': (0.498, 0.499, 0.292),
  'frame_host': (0.541, 0.569, 0.276),
  'frame_party': (0.524, 0.488, 0.305),
  'frame_vip': (0.491, 0.476, 0.279),
};

/// يرسم إطاراً فوق أفاتار قطره [diameter] ومركزه [center]، بحيث تنطبق فتحة الإطار على الأفاتار.
/// [art] اسم الصورة مثل fr_royal أو frame_host.
Widget frameOverlay(String art, {required double diameter, required Offset center}) {
  final (cx, cy, r) = frameHoles[art] ?? (.5, .5, .24);
  // الفتحة أصغر من الأفاتار بشوي عشان الحلقة تغطي طرفه
  final w = diameter * .5 * .95 / r;
  return Positioned(
    left: center.dx - cx * w,
    top: center.dy - cy * w,
    width: w,
    height: w,
    child: IgnorePointer(
      child: Image.asset(
        'assets/images/$art.webp',
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    ),
  );
}

/// صورة اللاعب مع إطار المتجر (إن وجد).
class FramedAvatar extends StatelessWidget {
  const FramedAvatar({super.key, required this.index, required this.size, this.frame});
  final int index;
  final double size;

  /// اسم إطار المتجر مثل angel، أو null/none بدون إطار.
  final String? frame;

  @override
  Widget build(BuildContext context) {
    final f = frame == null || frame == 'none' ? null : frame;
    if (f == null) return PlayerAvatar(index: index, size: size);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          PlayerAvatar(index: index, size: size * .86, ring: false),
          frameOverlay('fr_$f', diameter: size * .86, center: Offset(size / 2, size / 2)),
        ],
      ),
    );
  }
}

/// عملة ذهبية صغيرة.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Color(0xFFFFE07A), AppColors.goldDeep]),
        ),
        alignment: Alignment.center,
        child: Text('M', style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * .55, color: const Color(0xFF8A4B00))),
      );
}

/// شريط المكافأة في نافذة النتيجة: خبرة وعملات ومستوى جديد وإنجازات.
class RewardBanner extends StatelessWidget {
  const RewardBanner({super.key, required this.reward});
  final Reward reward;

  @override
  Widget build(BuildContext context) {
    Widget pill(Widget icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .25), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(width: 6), Text(text, style: const TextStyle(fontWeight: FontWeight.w900))]),
        );
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            pill(const CoinIcon(size: 18), '+${reward.coins}'),
            pill(const Icon(Icons.bolt_rounded, color: AppColors.gold, size: 18), '+${reward.xp} خبرة'),
            if (reward.levelUp) pill(const Icon(Icons.arrow_upward_rounded, color: AppColors.seeko, size: 18), 'المستوى ${reward.newLevel}!'),
          ],
        ),
        for (final a in reward.unlocked)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${a.emoji} إنجاز جديد: ${a.title} (+50)',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold)),
          ),
      ],
    ).animate().fadeIn(delay: 500.ms).scaleXY(begin: .8, end: 1, curve: Curves.easeOutBack);
  }
}

/// بطاقة زجاجية موحدة لشاشات الحساب.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: child,
      );
}

String authMethodLabel(AuthMethod m) => switch (m) {
      AuthMethod.google => 'Google',
      AuthMethod.phone => 'رقم الهاتف',
      AuthMethod.guest => 'ضيف',
    };
