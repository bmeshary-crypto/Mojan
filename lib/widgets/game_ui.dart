import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme.dart';
import 'bouncy_button.dart';

/// شريط علوي مشترك لشاشات الألعاب.
class GameTopBar extends StatelessWidget {
  const GameTopBar({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 28),
          ),
          Flexible(
            flex: 10,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(title, maxLines: 1, style: AppTheme.display.copyWith(fontSize: 28)),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Flexible(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// صف اختيارات (مثل عدد اللاعبين).
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, (v, label)) in options.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: BouncyButton(
              tilt: false,
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: 250.ms,
                height: 54,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: v == value ? AppColors.gold : Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: v == value ? AppColors.gold : Colors.white24),
                ),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: v == value ? AppColors.bgTop : Colors.white,
                    )),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// زر كبير ملون بحافة سفلية بارزة.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.label, required this.colors, required this.onTap, this.pulse = true});
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    Widget w = BouncyButton(
      tilt: false,
      onTap: onTap,
      child: Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(colors: colors),
          border: Border(bottom: BorderSide(color: Color.lerp(colors.last, Colors.black, .4)!, width: 5)),
          boxShadow: [BoxShadow(color: colors[colors.length ~/ 2].withValues(alpha: .5), blurRadius: 20)],
        ),
        child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    );
    if (pulse) {
      w = w.animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1, end: 1.03, duration: 900.ms);
    }
    return w;
  }
}

/// نافذة النتيجة في نهاية أي لعبة.
class GameResultDialog extends StatelessWidget {
  const GameResultDialog({
    super.key,
    required this.emoji,
    required this.title,
    required this.rows,
    required this.onAgain,
    required this.onHome,
  });
  final String emoji;
  final String title;
  final List<Widget> rows;
  final VoidCallback onAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.gold, width: 2),
          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .4), blurRadius: 30)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56))
                .animate()
                .scale(duration: 700.ms, curve: Curves.elasticOut, begin: Offset.zero),
            Text(title,
                textAlign: TextAlign.center, style: AppTheme.display.copyWith(fontSize: 30, color: AppColors.gold)),
            const SizedBox(height: 14),
            for (final (i, r) in rows.indexed)
              r.animate().fadeIn(delay: (200 + i * 120).ms).slideX(begin: .3, end: 0),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgTop,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onAgain,
                    child: const Text('العب مرة أخرى', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onHome,
                    child: const Text('الرئيسية', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// غطاء "مرّر الجهاز" عند اللعب على نفس الجهاز حتى لا يرى اللاعب أوراق غيره.
class PassDeviceCover extends StatelessWidget {
  const PassDeviceCover({super.key, required this.name, required this.color, required this.onReady});
  final String name;
  final Color color;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onReady,
      child: Container(
        color: AppColors.bgTop.withValues(alpha: .96),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android_rounded, size: 72, color: color)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .rotate(begin: -.04, end: .04, duration: 600.ms),
            const SizedBox(height: 16),
            Text('دور $name', style: AppTheme.display.copyWith(fontSize: 34, color: color)),
            const SizedBox(height: 6),
            Text('مرّر الجهاز ثم اضغط في أي مكان لعرض أوراقك',
                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
