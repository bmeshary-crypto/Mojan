import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/account/account.dart';
import '../core/haptics.dart';
import '../core/num_format.dart';
import '../core/shop.dart';
import '../core/theme.dart';
import '../games/ludo/ludo_board.dart';
import '../games/ludo/ludo_engine.dart';
import '../widgets/account_widgets.dart';
import '../widgets/animated_background.dart';
import '../widgets/daily_bonus.dart';
import 'support_screen.dart';
import 'voice/entrance_fx.dart';

/// يفتح المتجر. [tab]: 0 عملات، 1 سكنات، 2 أدوات، 3 حقيبتي.
/// أرقام تبويبات المتجر.
abstract final class ShopTab {
  static const coins = 0;
  static const diamonds = 1;
  static const frames = 2;
  static const entrances = 3;
  static const bubbles = 4;
  static const chairs = 5;
  static const skins = 6;
  static const items = 7;
  static const bag = 8;
}

Future<void> openShop(BuildContext context, {int tab = 0}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopScreen(initialTab: tab)));

/// باقات العملات (تُفعّل بالدفع الحقيقي عند النشر في المتاجر).
const coinPacks = [(5000, '4.99'), (12000, '9.99'), (30000, '19.99'), (80000, '44.99')];

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.initialTab = 0, this.embedded = false});
  final int initialTab;

  /// داخل تبويب الصفحة الرئيسية (بدون زر رجوع وخلفية خاصة).
  final bool embedded;

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
      ..showSnackBar(SnackBar(duration: const Duration(seconds: 2), 
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
          Text('${Account.instance.priceFor(item)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
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
    final cosmetic = item.kind != ShopKind.item && item.kind != ShopKind.bundle;
    if (cosmetic) acc.equip(item.id);
    _toast(cosmetic ? 'اشتريت ${item.title} وتم تركيبه ✨' : 'أضفنا ${item.title} لحقيبتك 🎒');
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: Account.instance,
      builder: (context, _) {
        final p = Account.instance.profile;
        if (p == null) {
          return const Center(child: Text('سجّل دخولك لفتح المتجر'));
        }
        return Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(widget.embedded ? 16 : 8, widget.embedded ? 12 : 4, 12, 0),
            child: Row(children: [
              if (!widget.embedded)
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 28),
                ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('المتجر', style: AppTheme.display.copyWith(fontSize: 28)),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const CoinIcon(size: 22),
                  const SizedBox(width: 6),
                  Text(fmtK(p.coins),
                      key: const ValueKey('shop-coins'),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ]),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('💎', style: TextStyle(fontSize: 17)),
                  const SizedBox(width: 5),
                  Text(fmtK(p.diamonds), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ]),
              ),
            ]),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white70,
            dividerColor: Colors.transparent,
            labelStyle: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 14),
            tabs: [
              Tab(key: ValueKey('shop-tab-coins'), text: 'عملات'),
              Tab(key: ValueKey('shop-tab-diamonds'), text: '💎 ماسات'),
              Tab(key: ValueKey('shop-tab-frames'), text: 'إطارات'),
              Tab(key: ValueKey('shop-tab-entrances'), text: 'دخوليات'),
              Tab(key: ValueKey('shop-tab-bubbles'), text: 'فقاعات'),
              Tab(key: ValueKey('shop-tab-chairs'), text: 'كراسي'),
              Tab(key: ValueKey('shop-tab-skins'), text: 'سكنات لودو'),
              Tab(key: ValueKey('shop-tab-items'), text: 'أدوات'),
              Tab(key: ValueKey('shop-tab-bag'), text: 'حقيبتي'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [
              _coinsTab(p),
              _diamondsTab(p),
              _framesTab(p),
              _entrancesTab(p),
              _bubblesTab(p),
              _chairsTab(p),
              _skinsTab(p),
              _itemsTab(p),
              _bagTab(p),
            ]),
          ),
        ]);
      },
    );
    return DefaultTabController(
      length: 9,
      initialIndex: widget.initialTab,
      child: widget.embedded
          ? body
          : Scaffold(body: AnimatedBackground(child: SafeArea(child: body))),
    );
  }

  // ---------- الإطارات والدخوليات والفقاعات ----------

  Widget _styleCard(PlayerProfile p, ShopItem item, Widget preview) {
    final name = item.id.split('.').last;
    final equipped = switch (item.kind) {
      ShopKind.frame => p.frame == name,
      ShopKind.entrance => p.entrance == name,
      ShopKind.chair => p.chair == name,
      _ => p.bubble == name,
    };
    return _skinCard(
      key: ValueKey('style-${item.id}'),
      preview: preview,
      title: item.title,
      owned: p.owns(item.id),
      equipped: equipped,
      price: Account.instance.priceFor(item),
      onTap: () => _skinTap(p, item.id),
    );
  }

  Widget _unequip(PlayerProfile p, String kind, String current) => current == 'none'
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: TextButton.icon(
              key: ValueKey('unequip-$kind'),
              onPressed: () => Account.instance.equip('$kind.none'),
              icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white70),
              label: const Text('بدون (إزالة المركّب)', style: TextStyle(color: Colors.white70)),
            ),
          ),
        );

  Widget _intro(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(color: AppColors.textMuted, height: 1.5)),
      );

  Widget _framesTab(PlayerProfile p) {
    final frames = styleCatalog.where((i) => i.kind == ShopKind.frame);
    return _list([
      _intro('إطار حول صورتك في الغرف الصوتية والملف الشخصي.'),
      _unequip(p, 'frame', p.frame),
      _grid(ratio: .74, [
        for (final f in frames)
          _styleCard(
            p,
            f,
            SizedBox(
              width: 92,
              height: 92,
              child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                PlayerAvatar(index: p.avatar, size: 46, ring: false),
                frameOverlay(frameArt(f.id.split('.').last), diameter: 46, center: const Offset(46, 46)),
              ]),
            ),
          ),
      ]),
    ]);
  }

  Widget _entrancesTab(PlayerProfile p) {
    final list = styleCatalog.where((i) => i.kind == ShopKind.entrance);
    return _list([
      _intro('تظهر دخوليتك لكل الموجودين لما تدخل أي غرفة صوتية.'),
      _unequip(p, 'entrance', p.entrance),
      _grid(ratio: .78, [
        for (final e in list)
          _styleCard(
            p,
            e,
            EntranceArt(e.id.split('.').last, size: 84)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveX(begin: -4, end: 4, duration: 1100.ms, curve: Curves.easeInOut),
          ),
      ]),
    ]);
  }

  Widget _bubblesTab(PlayerProfile p) {
    final list = styleCatalog.where((i) => i.kind == ShopKind.bubble);
    return _list([
      _intro('لون رسائلك في دردشة الغرف الصوتية.'),
      _unequip(p, 'bubble', p.bubble),
      _grid(ratio: .9, [
        for (final b in list)
          _styleCard(
            p,
            b,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: bubbleStyles[b.id.split('.').last]!),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('هلا والله 👋', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
      ]),
    ]);
  }

  Widget _chairsTab(PlayerProfile p) {
    final list = styleCatalog.where((i) => i.kind == ShopKind.chair);
    return _list([
      _intro('شكل كراسي المايكات في غرفتك: كل اللي يدخل غرفتك يشوف المايكات على هالكراسي.'),
      _unequip(p, 'chair', p.chair),
      _grid(ratio: .78, [
        for (final c in list)
          _styleCard(
            p,
            c,
            SizedBox(
              width: 96,
              height: 96,
              child: Image.asset(chairAsset(c.id.split('.').last), fit: BoxFit.contain),
            ),
          ),
      ]),
    ]);
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

  Widget _art(String name, double size) => Image.asset(
        'assets/images/$name.webp',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => SizedBox(width: size, height: size, child: const Icon(Icons.card_giftcard_rounded)),
      );

  // ---------- الماسات ----------
  Widget _preview(PlayerProfile p, ShopItem item) {
    final name = item.id.split('.').last;
    return switch (item.kind) {
      ShopKind.frame => SizedBox(
          width: 84,
          height: 84,
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            PlayerAvatar(index: p.avatar, size: 42, ring: false),
            frameOverlay(frameArt(name), diameter: 42, center: const Offset(42, 42)),
          ]),
        ),
      ShopKind.entrance => EntranceArt(name, size: 80),
      ShopKind.chair => SizedBox(width: 84, height: 84, child: Image.asset(chairAsset(name), fit: BoxFit.contain)),
      ShopKind.bubble => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: bubbleStyles[name]!),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text('هلا والله 👋', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        ),
      _ => const Icon(Icons.card_giftcard_rounded, size: 50),
    };
  }

  Future<void> _exchange(PlayerProfile p) async {
    var amount = p.diamonds;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('بدّل ماساتك بكوينز', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('💎 $amount  ←  🪙 $amount',
                key: const ValueKey('exchange-amount'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.gold)),
            const SizedBox(height: 4),
            const Text('كل ماسة = كوين واحد', style: TextStyle(color: AppColors.textMuted)),
            if (p.diamonds > 1)
              Slider(
                value: amount.toDouble(),
                min: 1,
                max: p.diamonds.toDouble(),
                divisions: p.diamonds - 1 > 200 ? 200 : p.diamonds - 1,
                activeColor: AppColors.gold,
                onChanged: (v) => set(() => amount = v.round()),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              key: const ValueKey('confirm-exchange'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgTop),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('بدّل', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (Account.instance.exchangeDiamonds(amount)) {
      Haptics.heavyImpact();
      _toast('بدّلت $amount ماسة بـ$amount كوين 🪙');
    }
  }

  Future<void> _buyDiamonds(PlayerProfile p, ShopItem item) async {
    final acc = Account.instance;
    if (p.owns(item.id)) {
      acc.equip(item.id);
      return;
    }
    final price = acc.diamondPriceFor(item);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('شراء ${item.title}؟', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text('💎 $price ماسة بدل ${item.price} كوين',
            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            key: const ValueKey('confirm-buy-diamonds'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgTop),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('اشترِ بالماسات', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = acc.buyWithDiamonds(item);
    if (err != null) {
      _toast(err);
      return;
    }
    Haptics.heavyImpact();
    acc.equip(item.id);
    _toast('اشتريت ${item.title} بالماسات وتم تركيبه ✨');
  }

  Widget _diamondsTab(PlayerProfile p) {
    final picks = [for (final id in diamondPicks) shopItem(id)];
    return _list([
      GlassCard(
        key: const ValueKey('diamonds-card'),
        color: const Color(0xFF4CC9F0).withValues(alpha: .12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('💎', style: TextStyle(fontSize: 34)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p.diamonds} ماسة',
                    key: const ValueKey('shop-diamonds'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const Text('توصلك من هدايا الناس: 30% من قيمة كل هدية.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('exchange-diamonds'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgTop),
              onPressed: p.diamonds > 0 ? () => _exchange(p) : null,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('بدّلها بكوينز (نفس القيمة)', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      _heading('💎 مميز بالماسات • خصم 30%'),
      _grid(ratio: .74, [
        for (final it in picks)
          _skinCard(
            key: ValueKey('dia-${it.id}'),
            preview: _preview(p, it),
            title: it.title,
            owned: p.owns(it.id),
            equipped: false,
            price: Account.instance.diamondPriceFor(it),
            diamonds: true,
            onTap: () => _buyDiamonds(p, it),
          ),
      ]),
    ]);
  }

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
          Opacity(opacity: ready ? 1 : .55, child: _art('chest_free', 56))
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
              onTap: () => openSupport(context, pack: (coins, price)),
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
                  Expanded(child: _art('coins_${i + 1}', 90)),
                  Text('$coins', style: AppTheme.display.copyWith(fontSize: 24, color: AppColors.gold)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                    child: Text('$price ر.س · اطلب',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ]),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'للشحن اضغط على الباقة وتواصل مع الإدارة مباشرة، ويوصلك الشحن على حسابك. وتقدر تجمع عملات مجاناً من الفوز والبونص والصندوق.',
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
    bool diamonds = false,
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
                          diamonds ? const Text('💎', style: TextStyle(fontSize: 13)) : const CoinIcon(size: 16),
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
            preview: DiceArt(skin: name, size: 74)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .rotate(begin: -.02, end: .02, duration: 1200.ms),
            title: 'نرد ${_skinNames[name]}',
            owned: p.owns('dice.$name'),
            equipped: p.diceSkin == name,
            price: name == 'classic' ? null : Account.instance.priceFor(shopItem('dice.$name')),
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
            price: name == 'classic' ? null : Account.instance.priceFor(shopItem('board.$name')),
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

  Widget _itemIcon(LudoItem i, {double size = 56}) => ItemArt(item: i, size: size);

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
          price: Account.instance.priceFor(shopItem('item.${i.name}')),
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
            icon: _art('bundle_power', 60),
            title: bundle.title,
            desc: '${bundle.description}، توفّر ${3 * (300 + 500 + 400) - bundle.price} عملة',
            price: Account.instance.priceFor(bundle),
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
                ? DiceArt(skin: id.split('.').last, size: 64)
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
