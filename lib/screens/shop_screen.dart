import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/account/account.dart';
import '../core/haptics.dart';
import '../core/shop.dart';
import '../core/theme.dart';
import '../games/ludo/ludo_board.dart';
import '../games/ludo/ludo_engine.dart';
import '../widgets/account_widgets.dart';
import '../widgets/animated_background.dart';
import '../widgets/daily_bonus.dart';

/// يفتح المتجر. [tab]: 0 عملات، 1 سكنات، 2 أدوات، 3 حقيبتي.
Future<void> openShop(BuildContext context, {int tab = 0}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopScreen(initialTab: tab)));

/// باقات العملات (تُفعّل بالدفع الحقيقي عند النشر في المتاجر).
const coinPacks = [(5000, '4.99'), (12000, '9.99'), (30000, '19.99'), (80000, '44.99')];

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // تحديث عدّاد الصندوق المجاني
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && Account.instance.chestWait() > Duration.zero) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
      ));
  }

  Future<void> _buy(ShopItem item) async {
    final acc = Account.instance;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('شراء ${item.title}؟', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Row(children: [
          const Text('السعر: ', style: TextStyle(fontWeight: FontWeight.w700)),
          const CoinIcon(size: 20),
          const SizedBox(width: 4),
          Text('${item.price}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            key: const ValueKey('confirm-buy'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgTop),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('اشترِ', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = acc.buy(item);
    if (err != null) {
      _toast(err);
      return;
    }
    Haptics.heavyImpact();
    final cosmetic = item.kind == ShopKind.dice || item.kind == ShopKind.board;
    if (cosmetic) acc.equip(item.id);
    _toast(cosmetic ? 'اشتريت ${item.title} وتم تركيبه ✨' : 'أضفنا ${item.title} لحقيبتك 🎒');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTab,
      child: Scaffold(
        body: AnimatedBackground(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: Account.instance,
              builder: (context, _) {
                final p = Account.instance.profile;
                if (p == null) {
                  return const Center(child: Text('سجّل دخولك لفتح المتجر'));
                }
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                    child: Row(children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded, size: 28),
                      ),
                      Text('المتجر', style: AppTheme.display.copyWith(fontSize: 28)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const CoinIcon(size: 22),
                          const SizedBox(width: 6),
                          Text('${p.coins}',
                              key: const ValueKey('shop-coins'),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ]),
                      ),
                    ]),
                  ),
                  const TabBar(
                    isScrollable: false,
                    indicatorColor: AppColors.gold,
                    labelColor: AppColors.gold,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 14),
                    tabs: [
                      Tab(key: ValueKey('shop-tab-coins'), text: 'عملات'),
                      Tab(key: ValueKey('shop-tab-skins'), text: 'سكنات'),
                      Tab(key: ValueKey('shop-tab-items'), text: 'أدوات'),
                      Tab(key: ValueKey('shop-tab-bag'), text: 'حقيبتي'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(children: [
                      _coinsTab(p),
                      _skinsTab(p),
                      _itemsTab(p),
                      _bagTab(p),
                    ]),
                  ),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(List<Widget> children) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: children),
        ),
      );

  Widget _heading(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text(t, style: AppTheme.display.copyWith(fontSize: 20)),
      );

  // ---------- العملات ----------
  Widget _coinsTab(PlayerProfile p) {
    final acc = Account.instance;
    final wait = acc.chestWait();
    final ready = wait == Duration.zero;
    String two(int n) => n.toString().padLeft(2, '0');
    final left = '${two(wait.inHours)}:${two(wait.inMinutes % 60)}:${two(wait.inSeconds % 60)}';
    return _list([
      GlassCard(
        color: ready ? AppColors.gold.withValues(alpha: .16) : null,
        child: Row(children: [
          Text(ready ? '🧰' : '⏳', style: const TextStyle(fontSize: 40))
              .animate(onPlay: (c) => ready ? c.repeat(reverse: true) : null)
              .rotate(begin: -.02, end: ready ? .02 : -.02, duration: 300.ms),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('صندوق مجاني', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text(ready ? '${Account.chestCoins} عملة كل 4 ساعات' : 'يفتح بعد $left',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
          FilledButton(
            key: const ValueKey('shop-chest'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgTop),
            onPressed: ready
                ? () {
                    final got = acc.claimChest();
                    if (got != null) {
                      Haptics.heavyImpact();
                      _toast('فتحت الصندوق: +$got عملة 🎉');
                    }
                  }
                : null,
            child: const Text('افتح', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      GlassCard(
        child: InkWell(
          key: const ValueKey('shop-daily'),
          onTap: () => showDailyBonus(context),
          child: Row(children: [
            const Text('🎁', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('البونص اليومي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(acc.dailyAvailable ? 'هدية اليوم ${acc.nextDailyIndex + 1} جاهزة!' : 'استلمت هدية اليوم',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ]),
            ),
            const Icon(Icons.chevron_left_rounded),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      _heading('باقات العملات'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
        children: [
          for (final (i, (coins, price)) in coinPacks.indexed)
            GestureDetector(
              onTap: () => _toast('شراء العملات بفلوس حقيقية يتفعّل عند نزول التطبيق في المتاجر'),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFF4B2BB3), const Color(0xFF2B1466).withValues(alpha: .9)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold.withValues(alpha: .4)),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(const ['🪙', '💰', '👜', '🏦'][i], style: const TextStyle(fontSize: 38)),
                  Text('$coins', style: AppTheme.display.copyWith(fontSize: 24, color: AppColors.gold)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                    child: Text('$price ر.س · قريباً',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ]),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'الشراء بالفلوس الحقيقية يعمل عبر متجر جوجل وآبل بعد نشر التطبيق. حالياً اجمع العملات من الفوز والبونص والصندوق.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    ]);
  }

  // ---------- السكنات ----------
  Widget _skinCard({
    required Key key,
    required Widget preview,
    required String title,
    required bool owned,
    required bool equipped,
    int? price,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: equipped ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: equipped ? .16 : .07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: equipped ? AppColors.gold : Colors.white24, width: equipped ? 2 : 1),
        ),
        child: Column(children: [
          Expanded(child: Center(child: preview)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: equipped ? AppColors.gold : (owned ? Colors.white24 : const Color(0xFF2EE59D)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: equipped
                  ? const Text('مُركّب', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.bgTop))
                  : owned
                      ? const Text('ركّب', style: TextStyle(fontWeight: FontWeight.w900))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const CoinIcon(size: 16),
                          const SizedBox(width: 4),
                          Text('$price',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.bgTop)),
                        ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _grid(List<Widget> children, {double ratio = .78}) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: ratio,
        children: children,
      );

  void _skinTap(PlayerProfile p, String id) {
    if (p.owns(id)) {
      Account.instance.equip(id);
      Haptics.selectionClick();
    } else {
      _buy(shopItem(id));
    }
  }

  static const _skinNames = {
    'classic': 'كلاسيك',
    'gold': 'ذهبي',
    'ruby': 'ياقوتي',
    'emerald': 'زمردي',
    'ocean': 'المحيط',
    'galaxy': 'المجرة',
    'night': 'الليل',
    'desert': 'الصحراء',
  };

  Widget _skinsTab(PlayerProfile p) {
    return _list([
      _heading('النرد'),
      _grid([
        for (final name in diceSkins.keys)
          _skinCard(
            key: ValueKey('skin-dice.$name'),
            preview: DiceFace(value: 6, size: 54, skin: name)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .rotate(begin: -.02, end: .02, duration: 1200.ms),
            title: 'نرد ${_skinNames[name]}',
            owned: p.owns('dice.$name'),
            equipped: p.diceSkin == name,
            price: name == 'classic' ? null : shopItem('dice.$name').price,
            onTap: () => _skinTap(p, 'dice.$name'),
          ),
      ]),
      const SizedBox(height: 16),
      _heading('لوح اللعب'),
      _grid(ratio: .72, [
        for (final name in boardThemes.keys)
          _skinCard(
            key: ValueKey('skin-board.$name'),
            preview: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: boardThemes[name]!.frame),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CustomPaint(painter: LudoBoardPainter(active: LudoColor.values.toSet(), theme: name)),
                ),
              ),
            ),
            title: 'لوح ${_skinNames[name]}',
            owned: p.owns('board.$name'),
            equipped: p.boardTheme == name,
            price: name == 'classic' ? null : shopItem('board.$name').price,
            onTap: () => _skinTap(p, 'board.$name'),
          ),
      ]),
    ]);
  }

  // ---------- الأدوات ----------
  Widget _itemRow({required Key key, required Widget icon, required String title, required String desc, required int price, required int have, required VoidCallback onBuy}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(children: [
        icon,
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
            if (have > 0)
              Text('في حقيبتك: $have',
                  style: const TextStyle(color: AppColors.seeko, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        ),
        FilledButton(
          key: key,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.bgTop,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: onBuy,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const CoinIcon(size: 16),
            const SizedBox(width: 4),
            Text('$price', style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
        ),
      ]),
    );
  }

  Widget _itemIcon(LudoItem i, {double size = 52}) {
    final (_, _, icon, color) = itemInfo[i]!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [Color.lerp(color, Colors.white, .35)!, color]),
        boxShadow: [BoxShadow(color: color.withValues(alpha: .5), blurRadius: 10)],
      ),
      child: Icon(icon, color: Colors.white, size: size * .55),
    );
  }

  Widget _itemsTab(PlayerProfile p) {
    final bundle = shopItem('bundle.power');
    return _list([
      const Text('أدوات وضع الباور في لودو. تُستخدم قبل رمي النرد، وكل مباراة تعطيك واحدة مجانية من كل أداة.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      for (final i in LudoItem.values)
        _itemRow(
          key: ValueKey('buy-item.${i.name}'),
          icon: _itemIcon(i),
          title: itemInfo[i]!.$1,
          desc: itemInfo[i]!.$2,
          price: shopItem('item.${i.name}').price,
          have: p.itemCount(i),
          onBuy: () => _buy(shopItem('item.${i.name}')),
        ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFE27A), Color(0xFFFF7A1A), Color(0xFFB86CFF)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
          child: _itemRow(
            key: const ValueKey('buy-bundle.power'),
            icon: const Text('⚡', style: TextStyle(fontSize: 44)),
            title: bundle.title,
            desc: '${bundle.description}، توفّر ${3 * (300 + 500 + 400) - bundle.price} عملة',
            price: bundle.price,
            have: 0,
            onBuy: () => _buy(bundle),
          ),
        ),
      ),
    ]);
  }

  // ---------- الحقيبة ----------
  Widget _bagTab(PlayerProfile p) {
    final skins = [
      for (final n in diceSkins.keys)
        if (p.owns('dice.$n')) 'dice.$n',
      for (final n in boardThemes.keys)
        if (p.owns('board.$n')) 'board.$n',
    ];
    return _list([
      _heading('أدواتي'),
      Row(children: [
        for (final i in LudoItem.values)
          Expanded(
            child: Column(children: [
              _itemIcon(i, size: 56),
              const SizedBox(height: 6),
              Text(itemInfo[i]!.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              Text('×${p.itemCount(i)}',
                  key: ValueKey('bag-${i.name}'),
                  style: AppTheme.display.copyWith(fontSize: 22, color: AppColors.gold)),
            ]),
          ),
      ]),
      const SizedBox(height: 18),
      _heading('سكناتي'),
      _grid([
        for (final id in skins)
          _skinCard(
            key: ValueKey('bag-$id'),
            preview: id.startsWith('dice.')
                ? DiceFace(value: 5, size: 50, skin: id.split('.').last)
                : AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CustomPaint(
                        painter: LudoBoardPainter(active: LudoColor.values.toSet(), theme: id.split('.').last),
                      ),
                    ),
                  ),
            title: '${id.startsWith('dice.') ? 'نرد' : 'لوح'} ${_skinNames[id.split('.').last]}',
            owned: true,
            equipped: id.startsWith('dice.')
                ? p.diceSkin == id.split('.').last
                : p.boardTheme == id.split('.').last,
            onTap: () => _skinTap(p, id),
          ),
      ]),
    ]);
  }
}
