import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/account/account.dart';
import '../core/haptics.dart';
import '../core/sfx.dart';
import '../core/theme.dart';
import '../core/vip.dart';
import '../widgets/account_widgets.dart';
import 'shop_screen.dart';

Future<void> openVip(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VipScreen()));

String _n(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// صفحة VIP: مستواك، التقدم للمستوى الجاي، المكافأة اليومية، وكل المستويات بمزاياها.
class VipScreen extends StatelessWidget {
  const VipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A2400), Color(0xFF241047), AppColors.bgTop],
            stops: [0, .35, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListenableBuilder(
                listenable: Account.instance,
                builder: (context, _) {
                  final p = Account.instance.profile;
                  final pts = p?.vipPoints ?? 0;
                  final lvl = p?.vipLevel ?? 0;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                    children: [
                      Row(children: [
                        IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, size: 28)),
                        Text('نادي VIP', style: AppTheme.display.copyWith(fontSize: 30, color: AppColors.gold)),
                      ]),
                      _hero(context, lvl, pts),
                      const SizedBox(height: 14),
                      _daily(context, lvl),
                      const SizedBox(height: 18),
                      _howTo(context),
                      const SizedBox(height: 18),
                      Text('المستويات والمزايا', style: AppTheme.display.copyWith(fontSize: 24)),
                      const SizedBox(height: 8),
                      for (final t in vipTiers) _tierCard(t, lvl, pts),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, int lvl, int pts) {
    final t = vipTier(lvl);
    final next = lvl < vipTiers.length ? vipTiers[lvl] : null;
    final from = t?.points ?? 0;
    final progress = next == null ? 1.0 : ((pts - from) / (next.points - from)).clamp(0.0, 1.0);
    final colors = t?.colors ?? const [Color(0xFF6B5C99), Color(0xFF3B2F66)];
    return Container(
      key: const ValueKey('vip-hero'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [...colors, const Color(0xFF241047)]),
        border: Border.all(color: Colors.white.withValues(alpha: .5), width: 1.5),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: .35), blurRadius: 26)],
      ),
      child: Column(
        children: [
          Text(lvl == 0 ? '🎖️' : (lvl >= 8 ? '👑' : '💎'), style: const TextStyle(fontSize: 54))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.08, duration: 1200.ms),
          Text(
            lvl == 0 ? 'لست VIP بعد' : 'VIP$lvl  ${t!.name}',
            key: const ValueKey('vip-level'),
            style: AppTheme.display.copyWith(fontSize: 30),
          ),
          Text('${_n(pts)} نقطة VIP', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white70)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.black.withValues(alpha: .3),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFFE27A)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null ? 'وصلت لأعلى مستوى! 👑' : 'باقي ${_n(next.points - pts)} نقطة للوصول لـ VIP${next.level} ${next.name}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _daily(BuildContext context, int lvl) {
    final t = vipTier(lvl);
    final ready = Account.instance.vipDailyReady;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: .4)),
      ),
      child: Row(children: [
        const Text('🎁', style: TextStyle(fontSize: 34)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('مكافأة VIP اليومية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            Text(
              t == null ? 'تبدأ من VIP1 بـ 100 عملة يومياً' : '${_n(t.daily)} عملة كل يوم',
              style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ]),
        ),
        FilledButton(
          key: const ValueKey('vip-daily'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgTop),
          onPressed: !ready
              ? null
              : () {
                  final c = Account.instance.claimVipDaily();
                  if (c == null) return;
                  Haptics.mediumImpact();
                  Sfx.instance.win();
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      content: Text('استلمت $c عملة 🎉', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ));
                },
          child: Text(t == null ? 'مقفلة' : (ready ? 'استلم' : 'استلمتها ✓'), style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }

  Widget _howTo(BuildContext context) {
    Widget row(String e, String t, String s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Text(e, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(s, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ]),
            ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('كيف تجمع النقاط؟', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 6),
        row('💳', 'شحن العملات', 'كل عملة تشحنها = نقطة VIP'),
        row('🎁', 'إرسال الهدايا في الغرف', 'كل عملة تصرفها على هدية = نقطة'),
        row('🛍️', 'الشراء من المتجر', 'كل عملة تصرفها في المتجر = نقطة'),
        const Text('الرهانات في الألعاب ما تحتسب، والمستوى ما ينزل أبداً.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('vip-topup'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgTop),
            onPressed: () => openShop(context),
            icon: const CoinIcon(size: 20),
            label: const Text('اشحن عملات', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ]),
    );
  }

  Widget _tierCard(VipTier t, int lvl, int pts) {
    final got = lvl >= t.level;
    final current = lvl == t.level;
    final all = [
      '🎁 مكافأة يومية ${_n(t.daily)} عملة',
      if (t.discount > 0) '🏷️ خصم ${t.discount}% على المتجر',
      ...t.perks.map((x) => '✨ $x'),
    ];
    return Container(
      key: ValueKey('vip-tier-${t.level}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: got ? .2 : .3),
        border: Border.all(color: current ? t.colors.first : Colors.white12, width: current ? 2.5 : 1),
        gradient: current
            ? LinearGradient(colors: [t.colors.first.withValues(alpha: .25), Colors.transparent])
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          VipBadge(t.level, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(t.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
          if (got)
            Text(current ? 'مستواك الحالي' : 'مفتوح ✓',
                style: TextStyle(color: current ? AppColors.gold : AppColors.seeko, fontWeight: FontWeight.w900, fontSize: 12))
          else
            Text('${_n(t.points)} نقطة', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800, fontSize: 12)),
          if (!got) const Padding(padding: EdgeInsetsDirectional.only(start: 4), child: Icon(Icons.lock_rounded, size: 16, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 6),
        for (final x in all)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(x, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: got ? Colors.white : Colors.white70)),
          ),
      ]),
    );
  }
}

/// احتفال الترقية لمستوى VIP جديد.
class VipUpOverlay extends StatelessWidget {
  const VipUpOverlay({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int?>(
        valueListenable: Account.instance.vipUp,
        builder: (context, lvl, _) {
          final t = lvl == null ? null : vipTier(lvl);
          if (t == null) return const SizedBox.shrink();
          return Material(
            color: Colors.black54,
            child: Center(
              child: Container(
                key: const ValueKey('vip-up'),
                margin: const EdgeInsets.all(28),
                padding: const EdgeInsets.all(22),
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(colors: [...t.colors, const Color(0xFF241047)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(t.level >= 8 ? '👑' : '💎', style: const TextStyle(fontSize: 64)),
                    Text('مبروك! صرت VIP${t.level}', style: AppTheme.display.copyWith(fontSize: 28)),
                    Text(t.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 10),
                    for (final x in [
                      'مكافأة يومية ${t.daily} عملة',
                      if (t.discount > 0) 'خصم ${t.discount}% على المتجر',
                      ...t.perks,
                    ])
                      Text('✨ $x', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.6)),
                    const SizedBox(height: 14),
                    FilledButton(
                      key: const ValueKey('vip-up-ok'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.bgTop),
                      onPressed: () => Account.instance.vipUp.value = null,
                      child: const Text('رائع!', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ]),
                ),
              ).animate().scale(duration: 450.ms, curve: Curves.elasticOut),
            ),
          );
        },
      );
}
