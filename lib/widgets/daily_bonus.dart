import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/account/account.dart';
import '../core/haptics.dart';
import '../core/shop.dart';
import '../core/theme.dart';

/// صور هدايا الأيام السبعة.
const _dailyArt = ['coins_1', 'coins_2', 'item_shield', 'chest_free', 'dice_gold', 'coins_3', 'gift_crown'];

/// نافذة البونص اليومي: تقويم 7 أيام بجوائز متصاعدة.
Future<void> showDailyBonus(BuildContext context) => showDialog(
      context: context,
      builder: (_) => const DailyBonusDialog(),
    );

class DailyBonusDialog extends StatefulWidget {
  const DailyBonusDialog({super.key});

  @override
  State<DailyBonusDialog> createState() => _DailyBonusDialogState();
}

class _DailyBonusDialogState extends State<DailyBonusDialog> {
  DailyGift? _claimed;

  void _claim() {
    final got = Account.instance.claimDaily();
    if (got == null) return;
    Haptics.heavyImpact();
    setState(() => _claimed = got);
  }

  @override
  Widget build(BuildContext context) {
    final acc = Account.instance;
    final today = acc.nextDailyIndex;
    final available = acc.dailyAvailable;

    Widget tile(int i, {bool wide = false}) {
      final g = dailyGifts[i];
      final done = i < today || (i == today && !available);
      final current = i == today && available;
      final tileWidget = Container(
        key: ValueKey('daily-day-${i + 1}'),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: current
                ? const [Color(0xFFFFE27A), AppColors.goldDeep]
                : wide
                    ? const [Color(0xFF8E6CFF), Color(0xFF4B2BB3)]
                    : [Colors.white.withValues(alpha: .14), Colors.white.withValues(alpha: .06)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: current ? Colors.white : Colors.white24, width: current ? 2.5 : 1),
          boxShadow: current ? [BoxShadow(color: AppColors.gold.withValues(alpha: .6), blurRadius: 16)] : null,
        ),
        child: Stack(alignment: Alignment.center, children: [
          FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('اليوم ${i + 1}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: current ? AppColors.bgTop : AppColors.textMuted,
                )),
            const SizedBox(height: 2),
            Image.asset('assets/images/${_dailyArt[i]}.webp',
                width: wide ? 56 : 42,
                height: wide ? 56 : 42,
                errorBuilder: (_, _, _) => Text(g.emoji, style: TextStyle(fontSize: wide ? 36 : 28))),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(g.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: current ? AppColors.bgTop : Colors.white,
                  )),
            ),
          ])),
          if (done)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.seeko, size: 34),
              ),
            ),
        ]),
      );
      return current
          ? tileWidget
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.05, duration: 700.ms)
          : tileWidget;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('البونص اليومي', style: AppTheme.display.copyWith(fontSize: 28, color: AppColors.gold)),
              const Text('ادخل كل يوم والجوائز تكبر. إذا فاتك يوم ترجع لليوم الأول.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: .9,
                children: [for (var i = 0; i < 6; i++) tile(i)],
              ),
              const SizedBox(height: 10),
              SizedBox(height: 104, width: double.infinity, child: tile(6, wide: true)),
              const SizedBox(height: 16),
              if (_claimed != null)
                Column(children: [
                  Text('${_claimed!.emoji} حصلت على ${_claimed!.label}',
                      key: const ValueKey('daily-got'),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.gold)),
                  const SizedBox(height: 8),
                ]).animate().scale(curve: Curves.elasticOut, duration: 700.ms),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('daily-claim'),
                  style: FilledButton.styleFrom(
                    backgroundColor: available ? AppColors.gold : Colors.white24,
                    foregroundColor: AppColors.bgTop,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: available ? _claim : () => Navigator.pop(context),
                  child: Text(available ? 'استلم هدية اليوم' : 'رجع بكرة!',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
