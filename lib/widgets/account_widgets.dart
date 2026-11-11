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
        child: Text(emoji, style: TextStyle(fontSize: size * .5, height: 1.1)),
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
