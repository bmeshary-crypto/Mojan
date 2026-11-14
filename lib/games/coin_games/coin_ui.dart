import 'package:flutter/material.dart';

import '../../core/account/account.dart';
import '../../core/admin/admin.dart';
import '../../core/ban.dart';
import '../../core/theme.dart';
import '../../screens/shop_screen.dart';
import '../../widgets/account_widgets.dart';
import '../../widgets/game_ui.dart';

/// أدوات مشتركة لألعاب العملات (الفواكه، الكنز، المسامير، الصاروخ).

String fmtCoins(num n) => n >= 1000000
    ? '${(n / 1000000).toStringAsFixed(1)}M'
    : n >= 10000
    ? '${(n / 1000).toStringAsFixed(n >= 100000 ? 0 : 1)}k'
    : '${n.round()}';

/// يعزل النص اتجاهياً حتى تظهر «×5» صحيحة داخل سطر عربي.
String ltr(String s) => '\u2066$s\u2069';

String fmtMult(double m) => ltr(m >= 100 ? '×${m.round()}' : '×${m.toStringAsFixed(m == m.roundToDouble() ? 0 : (m >= 10 ? 1 : 2))}');

int get myCoins => Account.instance.profile?.coins ?? 0;

/// رسالة سفلية قصيرة (ثانيتين). تقترح المتجر لو الرصيد ما يكفي.
void coinToast(BuildContext context, String t) {
  final noCoins = t.contains('رصيد');
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        persist: false,
        content: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
        action: noCoins ? SnackBarAction(label: 'المتجر', onPressed: () => openShop(context)) : null,
      ),
    );
}

/// خصم الرهان من الرصيد، مع رسالة لو ما يكفي.
bool takeBet(BuildContext context, int amount) {
  final limited = Restrictions.instance.check('coins');
  if (limited != null) {
    coinToast(context, limited);
    return false;
  }
  if (Account.instance.spend(amount)) return true;
  coinToast(context, 'رصيدك ما يكفي لهذا الرهان');
  return false;
}

/// هيكل شاشة لعبة عملات: خلفية متدرجة، شريط علوي بالرصيد، ومنع الخروج أثناء جولة.
class CoinGameScaffold extends StatelessWidget {
  const CoinGameScaffold({
    super.key,
    required this.title,
    required this.colors,
    required this.child,
    this.inPlay = false,
    this.leaveMessage = 'عندك رهان في هذه الجولة، وإذا خرجت يضيع عليك.',
    this.onHelp,
  });

  final String title;
  final List<Color> colors;
  final Widget child;
  final bool inPlay;
  final String leaveMessage;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) => LeaveGuard(
    enabled: inPlay,
    message: leaveMessage,
    child: Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [...colors, AppColors.bgTop],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  GameTopBar(
                    title: title,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onHelp != null)
                          IconButton(
                            key: const ValueKey('coin-help'),
                            onPressed: onHelp,
                            icon: const Icon(Icons.help_outline_rounded),
                          ),
                        const BalancePill(),
                      ],
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// رصيد اللاعب، يتحدث تلقائياً.
class BalancePill extends StatelessWidget {
  const BalancePill({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Account.instance,
    builder: (context, _) => InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => openShop(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: .5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 20),
            const SizedBox(width: 6),
            Text(
              fmtCoins(myCoins),
              key: const ValueKey('coin-balance'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
      ),
    ),
  );
}

const betSteps = [10, 50, 100, 500, 1000, 5000, 10000];

/// اختيار قيمة الرهان (رقائق).
class BetChips extends StatelessWidget {
  const BetChips({super.key, required this.value, required this.onChanged, this.enabled = true, this.steps = betSteps});
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final List<int> steps;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final v in steps)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              key: ValueKey('chip-$v'),
              onTap: enabled ? () => onChanged(v) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: v == value
                      ? const LinearGradient(colors: [Color(0xFFFFE07A), AppColors.goldDeep])
                      : null,
                  color: v == value ? null : Colors.black.withValues(alpha: .3),
                  border: Border.all(
                    color: v == value ? Colors.white : Colors.white24,
                    width: v == value ? 2.5 : 1.5,
                  ),
                ),
                child: Text(
                  fmtCoins(v),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: v == value ? const Color(0xFF5A2E00) : Colors.white.withValues(alpha: enabled ? 1 : .4),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// شرح اللعبة.
void showHowTo(BuildContext context, String title, String body) => showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
    content: Text(body, style: const TextStyle(height: 1.7)),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('فهمت'))],
  ),
);

/// زر رئيسي كبير ملون.
class CoinActionButton extends StatelessWidget {
  const CoinActionButton({super.key, required this.label, required this.onTap, this.color = AppColors.gold, this.sub});
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 60,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: const Color(0xFF2A1400),
        disabledBackgroundColor: Colors.white12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
          if (sub != null) Text(sub!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    ),
  );
}

/// للأدمن فقط: شريط النتائج الجاية في ألعاب الحظ.
class AdminUpcoming extends StatelessWidget {
  const AdminUpcoming({super.key, required this.items, this.title = 'النتائج الجاية', this.compact = false});
  final List<Widget> items;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!AdminService.instance.can('results')) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('admin-upcoming'),
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 2 : 4),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: .7)),
      ),
      child: Row(
        children: [
          Text('🔒 $title', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold, fontSize: 11)),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (i, w) in items.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          w,
                          Text(i == 0 ? 'الجاية' : '+${i + 1}', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: i == 0 ? AppColors.gold : Colors.white60)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// نص صغير لعنصر في شريط الأدمن.
Widget adminChip(String t, {Color color = Colors.white}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
  child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
);
