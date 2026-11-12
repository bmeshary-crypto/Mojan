import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/game_module.dart';
import '../../core/haptics.dart';
import '../../core/sfx.dart';
import '../../core/num_format.dart';
import '../../core/online/online_games.dart';
import '../../core/shop.dart';
import '../../core/theme.dart';
import '../../widgets/game_ui.dart';
import '../../widgets/game_social.dart';
import '../../core/voice/match_voice.dart';
import '../../screens/shop_screen.dart';
import '../../widgets/account_widgets.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/bouncy_button.dart';
import '../../widgets/celebration.dart';
import 'ludo_board.dart';
import 'ludo_engine.dart';

enum LudoVariant { classic, power, quick }

/// إعدادات مباراة لودو.
class LudoSetup {
  const LudoSetup({this.players = 2, this.teams = false, this.variant = LudoVariant.classic, this.entry = 0});
  final int players;
  final bool teams;
  final LudoVariant variant;
  final int entry;

  bool get power => variant == LudoVariant.power;
  int get count => teams ? 4 : players;

  List<LudoColor> get colors => switch (count) {
        2 => const [LudoColor.red, LudoColor.yellow],
        3 => const [LudoColor.red, LudoColor.green, LudoColor.yellow],
        _ => LudoColor.values,
      };

  LudoRules get rules => LudoRules(tokensPerPlayer: variant == LudoVariant.quick ? 2 : 4);

  int get prize => ludoPrize(entry, count, teams: teams);
}

/// شاشة لعبة لودو: الإعداد (عدد اللاعبين، الوضع، الرهان) ثم اللوح.
class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key, required this.mode});
  final PlayMode mode;

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> {
  int _players = 2;
  bool _teams = false;
  LudoVariant _variant = LudoVariant.classic;
  int _entryIndex = 0;
  bool _started = false;
  int _gameKey = 0;

  bool get _vsAi => widget.mode == PlayMode.vsComputer;
  bool get _canBet => _vsAi && Account.instance.signedIn;
  int get _entry => _canBet ? ludoEntries[_entryIndex] : 0;

  LudoSetup get _setupData => LudoSetup(players: _players, teams: _teams, variant: _variant, entry: _entry);

  /// يبدأ مباراة جديدة ويخصم رسوم الدخول إن وُجدت.
  void _start() {
    final s = _setupData;
    if (s.entry > 0 && !Account.instance.spend(s.entry)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(duration: const Duration(seconds: 2), persist: false, 
          behavior: SnackBarBehavior.floating,
          content: const Text('عملاتك لا تكفي لرسوم الدخول', style: TextStyle(fontWeight: FontWeight.w700)),
          action: SnackBarAction(label: 'المتجر', onPressed: () => openShop(context)),
        ));
      setState(() => _started = false);
      return;
    }
    setState(() {
      _started = true;
      _gameKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _setupData;
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: _started
              ? _LudoTable(
                  key: ValueKey(_gameKey),
                  setup: s,
                  humans: _vsAi ? {LudoColor.red} : s.colors.toSet(),
                  onRestart: _start,
                  onSetup: () => setState(() => _started = false),
                )
              : ListenableBuilder(listenable: Account.instance, builder: (context, _) => _setup(context)),
        ),
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap, {Key? key, String? sub, IconData? icon}) => Expanded(
        child: BouncyButton(
          tilt: false,
          onTap: onTap,
          child: AnimatedContainer(
            key: key,
            duration: 250.ms,
            height: sub == null ? 54 : 70,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.gold : Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? AppColors.gold : Colors.white24),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: selected ? AppColors.bgTop : Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(label,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: selected ? AppColors.bgTop : Colors.white,
                        )),
                  ]),
                  if (sub != null)
                    Text(sub,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.bgTop.withValues(alpha: .7) : AppColors.textMuted,
                        )),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _setup(BuildContext context) {
    final s = _setupData;
    final acc = Account.instance;
    const label = TextStyle(fontWeight: FontWeight.w800, fontSize: 16);
    return Column(
      children: [
        _BackBar(
          title: 'لودو',
          
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (acc.signedIn) _CoinPill(coins: acc.profile!.coins, onTap: () => openShop(context)),
            IconButton(
              key: const ValueKey('ludo-help'),
              tooltip: 'طريقة اللعب',
              onPressed: () => showLudoHelp(context),
              icon: const Icon(Icons.help_outline_rounded, size: 26),
            ),
          ]),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: CustomPaint(
                            painter: LudoBoardPainter(
                              active: s.colors.toSet(),
                              theme: acc.profile?.boardTheme ?? 'classic',
                              power: s.power,
                            ),
                          ),
                        ),
                      ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms),
                    ),
                    const SizedBox(height: 20),
                    Text(_vsAi ? 'عدد اللاعبين (أنت + الكمبيوتر)' : 'عدد اللاعبين', style: label),
                    const SizedBox(height: 10),
                    Row(children: [
                      for (final n in [2, 3, 4]) ...[
                        _choice('$n', !_teams && _players == n, () => setState(() {
                              _players = n;
                              _teams = false;
                            }), key: ValueKey('ludo-players-$n')),
                        const SizedBox(width: 8),
                      ],
                      _choice('2 ضد 2', _teams, () => setState(() => _teams = true),
                          key: const ValueKey('ludo-teams'), icon: Icons.groups_rounded),
                    ]),
                    if (_teams)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _vsAi
                              ? 'أنت (الأحمر) مع شريكك الأصفر ضد الأخضر والأزرق. الفريق الذي يوصل كل قطعه أولاً يفوز.'
                              : 'الأحمر والأصفر فريق، والأخضر والأزرق فريق. لا يأكل الشريك قطع شريكه.',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.5),
                        ),
                      ),
                    const SizedBox(height: 20),
                    const Text('وضع اللعب', style: label),
                    const SizedBox(height: 10),
                    Row(children: [
                      _choice('كلاسيك', _variant == LudoVariant.classic,
                          () => setState(() => _variant = LudoVariant.classic),
                          key: const ValueKey('ludo-classic'), sub: '4 قطع'),
                      const SizedBox(width: 8),
                      _choice('باور', _variant == LudoVariant.power, () => setState(() => _variant = LudoVariant.power),
                          key: const ValueKey('ludo-power'), sub: 'أدوات + رميات', icon: Icons.bolt_rounded),
                      const SizedBox(width: 8),
                      _choice('سريع', _variant == LudoVariant.quick, () => setState(() => _variant = LudoVariant.quick),
                          key: const ValueKey('ludo-quick'), sub: 'قطعتان'),
                    ]),
                    if (s.power) ...[
                      const SizedBox(height: 10),
                      _PowerKit(
                          bag: {for (final i in LudoItem.values) i: acc.profile?.itemCount(i) ?? 0},
                          onShop: acc.signedIn ? () => openShop(context, tab: ShopTab.items) : null),
                    ],
                    if (_canBet) ...[
                      const SizedBox(height: 20),
                      const Text('الرهان', style: label),
                      const SizedBox(height: 10),
                      _betBox(s, acc.profile!.coins),
                    ],
                    const SizedBox(height: 28),
                    BouncyButton(
                      tilt: false,
                      onTap: _start,
                      child: Container(
                        key: const ValueKey('ludo-start'),
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(colors: [Color(0xFFFF6B85), AppColors.ludo, Color(0xFFC9184A)]),
                          border: const Border(bottom: BorderSide(color: Color(0xFF8A0F33), width: 5)),
                          boxShadow: [BoxShadow(color: AppColors.ludo.withValues(alpha: .5), blurRadius: 20)],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('ابدأ اللعب',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                          if (s.entry > 0) ...[
                            const SizedBox(width: 10),
                            const CoinIcon(size: 20),
                            const SizedBox(width: 4),
                            Text('${s.entry}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                          ],
                        ]),
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1, end: 1.03, duration: 900.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _betBox(LudoSetup s, int coins) {
    Widget step(IconData icon, bool enabled, VoidCallback onTap, Key key) => IconButton.filled(
          key: key,
          style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .15)),
          onPressed: enabled ? onTap : null,
          icon: Icon(icon, color: Colors.white),
        );
    final enough = coins >= s.entry;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF3B2A8A).withValues(alpha: .9),
          const Color(0xFF241657).withValues(alpha: .9),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: .5)),
      ),
      child: Column(children: [
        Row(children: [
          step(Icons.remove_rounded, _entryIndex > 0, () => setState(() => _entryIndex--), const ValueKey('bet-minus')),
          Expanded(
            child: Column(children: [
              const Text('الجائزة', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const CoinIcon(size: 26),
                const SizedBox(width: 6),
                Text(s.entry == 0 ? 'ودّية' : '${s.prize}',
                    key: const ValueKey('bet-prize'),
                    style: AppTheme.display.copyWith(fontSize: 30, color: AppColors.gold)),
              ]),
            ]),
          ),
          step(Icons.add_rounded, _entryIndex < ludoEntries.length - 1, () => setState(() => _entryIndex++),
              const ValueKey('bet-plus')),
        ]),
        const SizedBox(height: 6),
        Text(
          s.entry == 0
              ? 'بدون رهان: تكسب عملات وخبرة عادية بعد المباراة'
              : 'الدخول ${s.entry} عملة. ${s.teams ? 'الفريق الفائز يقتسم الجائزة' : 'الفائز يأخذ الجائزة'} (5٪ رسوم)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: enough ? AppColors.textMuted : const Color(0xFFFF7A7A),
          ),
        ),
        if (!enough)
          TextButton(onPressed: () => openShop(context), child: const Text('عملاتك لا تكفي، اذهب للمتجر')),
      ]),
    );
  }
}

/// حبة العملات في الأعلى: تفتح المتجر.
class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.coins, required this.onTap});
  final int coins;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const CoinIcon(size: 20),
            const SizedBox(width: 5),
            Text(fmtK(coins), style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(width: 4),
            const Icon(Icons.add_circle_rounded, size: 18, color: AppColors.gold),
          ]),
        ),
      );
}

/// يعرض أدوات الباور: واحدة مجانية من كل أداة في كل مباراة + ما في حقيبتك.
class _PowerKit extends StatelessWidget {
  const _PowerKit({required this.bag, this.onShop});
  final Map<LudoItem, int> bag;
  final VoidCallback? onShop;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('معك في المباراة: أداة مجانية من كل نوع + حقيبتك',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          for (final i in LudoItem.values)
            Expanded(
              child: Column(children: [
                _ItemBadge(item: i, count: 1 + bag[i]!, size: 40),
                const SizedBox(height: 4),
                Text(itemInfo[i]!.$1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
        if (onShop != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onShop,
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text('اشترِ أدوات'),
            ),
          ),
      ]),
    );
  }
}

class _ItemBadge extends StatelessWidget {
  const _ItemBadge({required this.item, required this.count, this.size = 44, this.active = false, this.enabled = true});
  final LudoItem item;
  final int count;
  final double size;
  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = itemInfo[item]!.$4;
    return Opacity(
      opacity: enabled || active ? 1 : .4,
      child: SizedBox(
        width: size + 8,
        height: size + 8,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 4,
            top: 4,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: active ? .9 : .25), blurRadius: active ? 18 : 6)],
              ),
              child: active
                  ? ItemArt(item: item, size: size)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1, end: 1.12, duration: 500.ms)
                  : ItemArt(item: item, size: size),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: count > 0 ? AppColors.ludo : Colors.grey,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// نافذة شرح الأوضاع: كلاسيك، باور، فرق.
Future<void> showLudoHelp(BuildContext context) {
  Widget section(String title, List<(IconData, Color, String)> lines) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.display.copyWith(fontSize: 20, color: AppColors.gold)),
          const SizedBox(height: 6),
          for (final (icon, color, text) in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text(text, style: const TextStyle(height: 1.5, fontWeight: FontWeight.w600))),
              ]),
            ),
        ],
      );

  return showDialog(
    context: context,
    builder: (ctx) => DefaultTabController(
      length: 3,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const TabBar(
              indicatorColor: AppColors.gold,
              labelColor: AppColors.gold,
              labelStyle: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Cairo'),
              tabs: [Tab(text: 'كلاسيك'), Tab(text: 'باور'), Tab(text: 'فرق')],
            ),
            Flexible(
              child: TabBarView(children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: section('القواعد', const [
                    (Icons.casino_rounded, Colors.white, 'تحتاج 6 لتخرج قطعة من البيت، والـ 6 تعطيك رمية إضافية.'),
                    (Icons.restaurant_rounded, Color(0xFFFF6B81), 'إذا وقفت على قطعة خصم ترجعها لبيتها وتلعب مرة أخرى.'),
                    (Icons.star_rounded, AppColors.gold, 'خانات النجمة آمنة: لا تؤكل فيها أي قطعة.'),
                    (Icons.flag_rounded, AppColors.seeko, 'أول من يوصل كل قطعه للمنتصف يفوز. ثلاث ستات متتالية تضيّع الدور.'),
                  ]),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: section('وضع الباور', [
                    for (final i in LudoItem.values)
                      (itemInfo[i]!.$3, itemInfo[i]!.$4, '${itemInfo[i]!.$1}: ${itemInfo[i]!.$2}.'),
                    (Icons.add_box_rounded, AppColors.gold,
                        'خانات +1 الذهبية على المسار: إذا وقفت عليها تأخذ رمية إضافية.'),
                    (Icons.backpack_rounded, AppColors.textMuted,
                        'تبدأ كل مباراة بأداة مجانية من كل نوع، وتقدر تستخدم أدوات حقيبتك التي اشتريتها من المتجر. الأداة تُستخدم قبل رمي النرد.'),
                  ]),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: section('2 ضد 2', const [
                    (Icons.groups_rounded, Colors.white, 'أربعة لاعبين في فريقين: الأحمر مع الأصفر، والأخضر مع الأزرق.'),
                    (Icons.handshake_rounded, AppColors.seeko, 'لا تأكل قطع شريكك، وتقدر تقف معه في نفس الخانة.'),
                    (Icons.emoji_events_rounded, AppColors.gold, 'الفريق الذي يوصل كل قطع اللاعبين الاثنين أولاً يفوز، والجائزة تنقسم بينهما.'),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('فهمت')),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _BackBar extends StatelessWidget {
  const _BackBar({required this.title, this.subtitle, this.trailing, this.onBack});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('ludo-back'),
            onPressed: onBack ?? () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 28),
          ),
          Text(title, style: AppTheme.display.copyWith(fontSize: 28)),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Flexible(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
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

/// مباراة لودو أونلاين بعد امتلاء الغرفة.
class LudoOnlineScreen extends StatelessWidget {
  const LudoOnlineScreen({super.key, required this.match});
  final OnlineMatch match;

  @override
  Widget build(BuildContext context) {
    final variant = LudoVariant.values.where((v) => v.name == match.mode).firstOrNull ?? LudoVariant.classic;
    final setup = LudoSetup(players: match.size, variant: variant);
    final mine = match.seatOf(OnlineGames.instance.uid);
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: _LudoTable(
            setup: setup,
            humans: {setup.colors[mine < 0 ? 0 : mine]},
            online: match,
            onRestart: () => Navigator.maybePop(context),
            onSetup: () => Navigator.maybePop(context),
          ),
        ),
      ),
    );
  }
}

/// طاولة اللعب نفسها.
class _LudoTable extends StatefulWidget {
  const _LudoTable({
    super.key,
    required this.setup,
    required this.humans,
    required this.onRestart,
    required this.onSetup,
    this.online,
  });
  final LudoSetup setup;
  final Set<LudoColor> humans;

  /// مباراة أونلاين (null = على نفس الجهاز أو ضد الكمبيوتر).
  final OnlineMatch? online;
  final VoidCallback onRestart;
  final VoidCallback onSetup;

  @override
  State<_LudoTable> createState() => _LudoTableState();
}

class _LudoTableState extends State<_LudoTable> {
  LudoSetup get s => widget.setup;
  late final LudoGame game;
  final _rng = Random();

  /// الأدوات المجانية المتبقية للاعب صاحب الحساب (بعدها يُخصم من الحقيبة).
  final Map<LudoItem, int> _free = {for (final i in LudoItem.values) i: 1};

  /// إيموجي/هدية ظاهرة فوق صورة كل لاعب.
  final Map<LudoColor, ({String emoji, String? from, int key})> _fx = {};
  int _fxKey = 0;
  GameFxChannel? _fxChannel;

  void _showFx(LudoColor c, String emoji, {String? from}) {
    final k = ++_fxKey;
    setState(() => _fx[c] = (emoji: emoji, from: from, key: k));
    Sfx.instance.pickup();
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!_disposed && _fx[c]?.key == k) setState(() => _fx.remove(c));
    });
  }

  Future<void> _sendFx(LudoColor c) async {
    if (c == _me && _solo) return;
    final g = await pickGameGift(context, _nameOf(c) == 'أنت' ? 'نفسك' : _nameOf(c));
    if (g == null || _disposed) return;
    _showFx(c, g.emoji);
    if (_online) {
      final seat = _seat(c);
      _fxChannel?.send(to: c.name, toUid: seat != null && !seat.isAi ? seat.uid : null, g: g);
    }
  }

  void _voiceChanged() {
    if (!_disposed) setState(() {});
  }

  Future<void> _toggleMic() async {
    final v = MatchVoice.instance;
    if (!v.active) {
      final err = v.start(_match.id);
      if (err != null) {
        setState(() => _status = err);
        return;
      }
    }
    final ok = await v.toggleMic();
    if (!ok && !_disposed) setState(() => _status = 'ما قدرنا نشغل المايك، اسمح للمتصفح باستخدامه');
  }

  /// مرات الشراء من داخل الجيم: مرتين بالكثير لكل أداة.
  final Map<LudoItem, int> _bought = {for (final i in LudoItem.values) i: 0};
  static const maxBuys = 2;

  /// مواقع مؤقتة للقطع أثناء الأنميشن (القطعة تمشي خانة خانة).
  final Map<LudoToken, int> _shown = {};
  bool _busy = false;
  bool _rolling = false;
  int _diceFace = 6;
  String _status = '';
  LudoToken? _hopping;

  /// احتفالات دخول البيت الظاهرة الآن.
  final _bursts = <int, LudoColor>{};
  var _burstSeq = 0;
  bool _disposed = false;
  bool _over = false;
  bool _leaving = false;

  bool get _solo => widget.humans.length == 1;

  // ---------- أونلاين ----------
  bool get _online => widget.online != null;
  late OnlineMatch _match = widget.online!;
  int _applied = 0;
  final Map<int, Map<String, dynamic>> _pending = {};
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _beat;

  int _seatOfColor(LudoColor c) => s.colors.indexOf(c);
  OnlineSeat? _seat(LudoColor c) => _online ? _match.seats[_seatOfColor(c)] : null;

  /// هل هذا الجهاز هو من يحرك هذا اللون؟ (لاعبه، أو لاعب AI ونحن المتحكم)
  bool _iControl(LudoColor c) => !_online || _match.controlledBy(_seatOfColor(c), OnlineGames.instance.uid);

  void _startOnline() {
    final svc = OnlineGames.instance;
    _subs.add(svc.actions(_match.id).listen((list) {
      for (final a in list) {
        final seq = (a['seq'] as num).toInt();
        if (seq >= _applied) _pending[seq] = a;
      }
      _drain();
    }));
    _subs.add(svc.watch(_match.id).listen((m) {
      if (m == null || _disposed) return;
      final wasControl = _iControl(game.current);
      setState(() => _match = m);
      if (!wasControl && _iControl(game.current)) _resumeControl();
    }));
    svc.heartbeat(_match.id);
    _beat = Timer.periodic(const Duration(seconds: 8), (_) {
      svc.heartbeat(_match.id);
      // المتحكم يحوّل اللاعب المنقطع إلى AI حتى لا تتوقف المباراة
      for (final i in _match.staleSeats(svc.uid)) {
        svc.seatToAi(_match, i);
      }
    });
  }

  /// صرنا نحن المتحكم في هذا الدور (لاعب انقطع أو انسحب).
  void _resumeControl() {
    if (_busy || _over) return;
    if (game.phase == LudoPhase.waitingRoll) {
      _scheduleAi();
    } else if (game.phase == LudoPhase.waitingMove && !_humanTurn && _pending[_applied] == null) {
      _doMove(game.chooseAiMove());
    }
  }

  /// تطبيق حركات اللاعبين الآخرين بالترتيب.
  void _drain() {
    if (!_online || _busy || _disposed || game.phase == LudoPhase.gameOver) return;
    final a = _pending.remove(_applied);
    if (a == null) return;
    switch (a['t']) {
      case 'roll' when game.phase == LudoPhase.waitingRoll:
        _applied++;
        _roll((a['v'] as num).toInt());
      case 'item' when game.phase == LudoPhase.waitingRoll:
        _applied++;
        final it = LudoItem.values.firstWhere((i) => i.name == a['i'], orElse: () => LudoItem.shield);
        game.useItem(it, value: (a['v'] as num?)?.toInt());
        setState(() => _status = '${_nameOf(game.current)} استخدم ${itemInfo[it]!.$1}');
        _drain();
      case 'buy':
        _applied++;
        final it = LudoItem.values.firstWhere((i) => i.name == a['i'], orElse: () => LudoItem.shield);
        final c = LudoColor.values.firstWhere((c) => c.name == a['c'], orElse: () => game.current);
        game.items[c]![it] = game.itemCount(c, it) + 1;
        setState(() => _status = '🛒 ${_nameOf(c)} اشترى ${itemInfo[it]!.$1}');
        _drain();
      case 'move' when game.phase == LudoPhase.waitingMove:
        final m = game.legalMoves.where((m) => m.token.id == (a['token'] as num).toInt()).firstOrNull;
        _applied++;
        if (m != null) _doMove(m, remote: true);
      default:
        _applied++;
        _drain();
    }
  }

  void _send(Map<String, Object?> action) {
    if (!_online) return;
    OnlineGames.instance.post(_match.id, _applied, action);
    _applied++;
  }
  bool get _humanTurn => widget.humans.contains(game.current);
  LudoColor get _me => widget.humans.first;
  String get _diceSkin => Account.instance.profile?.diceSkin ?? 'classic';
  String get _boardTheme => Account.instance.profile?.boardTheme ?? 'classic';

  @override
  void initState() {
    super.initState();
    final items = <LudoColor, Map<LudoItem, int>>{};
    if (s.power) {
      for (final c in s.colors) {
        final bag = _solo && c == _me && Account.instance.signedIn;
        items[c] = {
          for (final i in LudoItem.values) i: 1 + (bag ? Account.instance.profile!.itemCount(i) : 0),
        };
      }
    }
    game = LudoGame(
      players: s.colors,
      rules: s.rules,
      teams: s.teams,
      power: s.power,
      items: items,
      pickupSeed: _online ? _match.seed : null,
    );
    _status = _turnText();
    if (_online) {
      _startOnline();
      _fxChannel = GameFxChannel(_match.id);
      _subs.add(_fxChannel!.stream().listen((f) {
        final c = LudoColor.values.where((c) => c.name == f.to).firstOrNull;
        if (c != null && !_disposed) _showFx(c, f.emoji, from: f.from);
      }));
      // الكل يسمع من البداية، والمايك مقفول لين يفتحه اللاعب
      MatchVoice.instance.start(_match.id);
      MatchVoice.instance.addListener(_voiceChanged);
    }
    _scheduleAi();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final x in _subs) {
      x.cancel();
    }
    if (_online) {
      MatchVoice.instance.removeListener(_voiceChanged);
      MatchVoice.instance.stop();
    }
    _beat?.cancel();
    super.dispose();
  }

  String _nameOf(LudoColor c) {
    if (_online) return c == _me ? 'أنت' : (_seat(c)?.name ?? 'لاعب');
    if (_solo) {
      if (c == _me) return 'أنت';
      if (s.teams && game.allies(c, _me)) return 'شريكك';
      final ai = s.colors.where((p) => p != _me && !(s.teams && game.allies(p, _me))).toList().indexOf(c) + 1;
      return 'كمبيوتر $ai';
    }
    return 'لاعب ${ludoNames[c]}';
  }

  Future<void> _wait(int ms) => Future.delayed(Duration(milliseconds: ms));

  String _turnText() {
    if (!_humanTurn) return 'دور ${_nameOf(game.current)}…';
    final who = _solo ? 'دورك!' : 'دور ${_nameOf(game.current)}:';
    if (game.controlledValue != null) return '$who النرد سيعطيك ${game.controlledValue}';
    if (s.power) return '$who استخدم أداة أو اضغط على النرد';
    return '$who اضغط على النرد';
  }

  void _scheduleAi() {
    _drain();
    if (_humanTurn || game.phase != LudoPhase.waitingRoll || !_iControl(game.current)) return;
    Future.delayed(const Duration(milliseconds: 700), () async {
      if (_disposed || _humanTurn || game.phase != LudoPhase.waitingRoll || _busy || !_iControl(game.current)) return;
      final used = game.aiUseItem();
      if (used != null) {
        _busy = true;
        Haptics.mediumImpact();
        setState(() => _status = '${_nameOf(game.current)} استخدم ${itemInfo[used]!.$1}');
        await _wait(1000);
        if (_disposed) return;
        _busy = false;
      }
      _roll();
    });
  }

  Future<void> _useItem(LudoItem item) async {
    if (_busy || !_humanTurn || game.phase != LudoPhase.waitingRoll) return;
    int? value;
    if (item == LudoItem.diceControl) {
      value = await _pickDiceValue();
      if (value == null || _disposed) return;
    }
    if (!game.useItem(item, value: value)) return;
    _send({'t': 'item', 'i': item.name, 'v': ?value});
    Sfx.instance.pickup();
    // المجاني أولاً ثم الحقيبة (فقط لصاحب الحساب)
    if (_solo && game.current == _me) {
      if (_free[item]! > 0) {
        _free[item] = _free[item]! - 1;
      } else {
        Account.instance.consumeItem(item);
      }
    }
    Haptics.mediumImpact();
    setState(() => _status = switch (item) {
          LudoItem.doubleDistance => 'مسافة مضاعفة! الرمية القادمة ×2',
          LudoItem.diceControl => 'النرد سيعطيك $value',
          LudoItem.shield => 'الدرع مفعّل: قطعك محمية حتى يرجع دورك',
        });
  }

  /// شراء أداة أثناء اللعب (مرتين بالكثير لكل أداة في الجيم).
  Future<void> _buyItem(LudoItem item, LudoColor owner) async {
    final left = maxBuys - _bought[item]!;
    if (left <= 0) {
      setState(() => _status = 'اشتريت ${itemInfo[item]!.$1} مرتين، هذا الحد في الجيم');
      return;
    }
    final price = shopCatalog.where((x) => x.id == 'item.${item.name}').firstOrNull?.price ?? 400;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('شراء ${itemInfo[item]!.$1}'),
        content: Text('${itemInfo[item]!.$2}\nالسعر: $price 🪙  •  باقي لك $left من 2 في هذا الجيم'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(key: const ValueKey('buy-item-ok'), onPressed: () => Navigator.pop(d, true), child: const Text('اشترِ')),
        ],
      ),
    );
    if (ok != true || _disposed) return;
    if (!Account.instance.spend(price)) {
      setState(() => _status = 'عملاتك ما تكفي');
      return;
    }
    _bought[item] = _bought[item]! + 1;
    game.items[owner]![item] = game.itemCount(owner, item) + 1;
    _send({'t': 'buy', 'i': item.name, 'c': owner.name});
    Sfx.instance.pickup();
    setState(() => _status = '🛒 اشتريت ${itemInfo[item]!.$1}، استخدمها الحين');
  }

  Future<int?> _pickDiceValue() => showModalBottomSheet<int>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('اختر رقم النرد', style: AppTheme.display.copyWith(fontSize: 22)),
              const SizedBox(height: 14),
              Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                for (var v = 1; v <= 6; v++)
                  GestureDetector(
                    key: ValueKey('pick-$v'),
                    onTap: () => Navigator.pop(ctx, v),
                    child: DiceFace(value: v, size: 52, skin: _diceSkin),
                  ),
              ]),
            ]),
          ),
        ),
      );

  Future<void> _roll([int? forced]) async {
    if (_busy || game.phase != LudoPhase.waitingRoll) return;
    // الرقم يتحدد مرة وحدة عند صاحب الدور ويوصل لكل اللاعبين
    final value = forced ?? (game.controlledValue ?? _rng.nextInt(6) + 1);
    if (forced == null) _send({'t': 'roll', 'v': value});
    _busy = true;
    Haptics.mediumImpact();
    Sfx.instance.diceShake();
    setState(() => _rolling = true);
    for (var i = 0; i < 8; i++) {
      await _wait(70);
      if (_disposed) return;
      setState(() => _diceFace = _rng.nextInt(6) + 1);
    }
    final player = game.current;
    final doubled = game.doubleActive;
    final hasMoves = game.roll(value);
    if (_disposed) return;
    setState(() {
      _rolling = false;
      _diceFace = game.dice!;
    });
    Sfx.instance.diceLand();

    if (!hasMoves) {
      final threeSixes = game.dice == 6 && !doubled;
      setState(() => _status = threeSixes ? 'ثلاث ستات! خسرت الدور' : 'لا توجد حركة متاحة');
      await _wait(900);
      if (_disposed) return;
      _busy = false;
      setState(() => _status = _turnText());
      _scheduleAi();
      return;
    }

    if (!_iControl(player)) {
      // ننتظر حركة اللاعب الآخر
      _busy = false;
      setState(() => _status = 'دور ${_nameOf(player)}…');
      _drain();
      return;
    }

    if (!widget.humans.contains(player)) {
      await _wait(450);
      if (_disposed) return;
      await _doMove(game.chooseAiMove());
      return;
    }

    // لاعب بشري: حركة تلقائية إن كانت كل الخيارات متطابقة
    final moves = game.legalMoves;
    final distinct = moves.map((m) => '${m.from}').toSet();
    if (moves.length == 1 || distinct.length == 1) {
      await _wait(300);
      if (_disposed) return;
      await _doMove(moves.first);
      return;
    }
    _busy = false;
    setState(() => _status = 'اختر القطعة التي تريد تحريكها');
  }

  Future<void> _doMove(LudoMove m, {bool remote = false}) async {
    _busy = true;
    if (!remote) _send({'t': 'move', 'token': m.token.id});
    final before = {for (final t in game.allTokens) t: t.pos};
    final result = game.move(m);
    _shown
      ..clear()
      ..addAll(before);
    _hopping = m.token;
    setState(() {});
    final fromBase = before[m.token] != null && m.path.length == 1 && (before[m.token]! < 0);
    if (fromBase) Sfx.instance.release();
    for (final (i, p) in m.path.indexed) {
      _shown[m.token] = p;
      Haptics.selectionClick();
      if (!fromBase) Sfx.instance.hop(i);
      setState(() {});
      await _wait(m.path.length > 8 ? 110 : 170);
      if (_disposed) return;
    }
    _hopping = null;
    for (final c in result.captured) {
      _shown.remove(c);
    }
    if (result.captured.isNotEmpty) {
      Haptics.heavyImpact();
      Sfx.instance.capture();
      setState(() => _status = '${_nameOf(m.token.color)} أكل قطعة ${_nameOf(result.captured.first.color)}!');
      await _wait(700);
      if (_disposed) return;
    }
    _shown.clear();
    if (m.to == LudoGeo.finished) {
      final id = ++_burstSeq;
      _bursts[id] = m.token.color;
      Haptics.mediumImpact();
      Sfx.instance.home();
      Sfx.instance.noise(.35, vol: .12, freq: 3200, delay: .3);
      Sfx.instance.noise(.3, vol: .1, freq: 2400, delay: .45);
      if (!result.playerFinished && game.phase != LudoPhase.gameOver) {
        _status = '🎉 ${_nameOf(m.token.color)} دخّل قطعة البيت!';
      }
    }
    setState(() {});
    if (m.to == LudoGeo.finished && game.phase != LudoPhase.gameOver) {
      await _wait(900);
      if (_disposed) return;
    }

    if (game.phase == LudoPhase.gameOver) {
      if (_online) OnlineGames.instance.finish(_match.id);
      await _wait(400);
      if (!_disposed) _showResults();
      return;
    }
    if (result.playerFinished) {
      setState(() => _status = '${_nameOf(m.token.color)} أنهى كل القطع!');
      await _wait(900);
    } else if (result.picked != null) {
      Haptics.mediumImpact();
      Sfx.instance.pickup();
      setState(() => _status = '🎁 ${_nameOf(m.token.color)} أخذ ${itemInfo[result.picked]!.$1}');
      await _wait(900);
      if (result.bonusRoll) {
        setState(() => _status = '⭐ +1 رمية إضافية لـ${_nameOf(m.token.color)}');
        await _wait(700);
      }
    } else if (result.bonusRoll) {
      Haptics.mediumImpact();
      setState(() => _status = '⭐ +1 رمية إضافية لـ${_nameOf(m.token.color)}');
      await _wait(800);
    } else if (result.extraTurn) {
      setState(() => _status = '${_nameOf(game.current)} يلعب مرة أخرى');
      await _wait(500);
    }
    if (_disposed) return;
    _busy = false;
    setState(() => _status = _turnText());
    _scheduleAi();
  }

  void _onTokenTap(LudoToken t) {
    if (_busy || !_humanTurn || game.phase != LudoPhase.waitingMove) return;
    final m = game.legalMoves.where((m) => m.token == t).firstOrNull;
    if (m != null) _doMove(m);
  }

  bool get _humanWon {
    if (s.teams) return game.winnerTeam == LudoGame.teamOf(_me);
    return game.ranking.first == _me;
  }

  void _showResults() {
    _over = true;
    Reward? reward;
    var payout = 0;
    if (_solo) {
      final won = _humanWon;
      final place = game.ranking.indexOf(_me);
      final points = s.teams ? (won ? 300 : 0) : const [400, 200, 100, 0][place.clamp(0, 3)];
      reward = Account.instance.recordGame('ludo', won: won, points: points + (won ? s.entry ~/ 10 : 0));
      if (won && s.entry > 0) {
        payout = s.prize;
        Account.instance.earn(payout);
      }
    } else {
      reward = Account.instance.recordGame('ludo', won: false);
    }
    final first = game.ranking.first;
    String realName(LudoColor c) {
      final n = _nameOf(c);
      return n == 'أنت' ? (Account.instance.profile?.name ?? 'أنت') : n;
    }
    final winnerName = s.teams
        ? s.colors.where((c) => game.allies(c, first)).map(realName).join(' و ')
        : realName(first);
    Sfx.instance.win();
    Sfx.instance.noise(.4, vol: .14, freq: 3000, delay: .5);
    Sfx.instance.noise(.4, vol: .12, freq: 2200, delay: .9);
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (ctx) => Stack(children: [
        const Positioned.fill(child: WinFireworks()),
        _ResultsDialog(
        winnerName: winnerName,
        reward: reward,
        ranking: game.ranking,
        nameOf: _nameOf,
        teams: s.teams,
        humanWon: _solo ? _humanWon : true,
        entry: _solo ? s.entry : 0,
        payout: payout,
        onAgain: () {
          Navigator.pop(ctx);
          widget.onRestart();
        },
        onHome: () {
          Navigator.pop(ctx);
          Navigator.maybePop(context);
        },
      ),
      ]),
    );
  }

  /// سؤال الانسحاب يظهر دائماً أثناء المباراة. [toSetup] يرجع لشاشة الإعداد بدل الخروج.
  Future<void> _leave({bool toSetup = false}) async {
    if (!_over && _leaving) return;
    if (!_over) {
      _leaving = true;
      final bet = s.entry > 0 && _solo;
      final ok = await showLeaveDialog(
        context,
        message: bet
            ? 'المباراة ما خلصت، وإذا انسحبت تخسر رسوم الدخول (${s.entry} عملة) وتنحسب خسارة.'
            : _online
                ? 'المباراة ما خلصت، وإذا انسحبت تنحسب خسارة ويكمل لاعب ذكاء اصطناعي مكانك.'
            : _solo
                ? 'المباراة ما خلصت، وإذا انسحبت تنحسب خسارة.'
                : 'المباراة ما خلصت، وإذا انسحبت تضيع اللعبة على الجميع.',
      );
      _leaving = false;
      if (!ok || !mounted) return;
      if (_solo) Account.instance.recordGame('ludo', won: false);
      if (_online) OnlineGames.instance.leave(_match);
      // نسمح بالخروج بعد التأكيد (حتى لا يظهر السؤال مرة ثانية)
      setState(() => _over = true);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    if (toSetup) {
      widget.onSetup();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _over,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Column(
        children: [
          _BackBar(
            title: _online ? 'لودو أونلاين' : 'لودو',
            subtitle: [
              if (s.teams) '2 ضد 2',
              if (s.power) '⚡ باور',
              if (s.variant == LudoVariant.quick) 'سريع',
            ].join(' · ').ifEmpty('كلاسيك'),
            onBack: _leave,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_online) ...[
                IconButton(
                  key: const ValueKey('ludo-mic'),
                  tooltip: MatchVoice.instance.micOn ? 'اقفل المايك' : 'افتح المايك',
                  onPressed: _toggleMic,
                  icon: Icon(
                    MatchVoice.instance.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                    color: MatchVoice.instance.micOn ? const Color(0xFF3DDC84) : Colors.white70,
                  ),
                ),
                IconButton(
                  key: const ValueKey('ludo-speaker'),
                  tooltip: MatchVoice.instance.speakerOn ? 'كتم أصوات اللاعبين' : 'تشغيل أصوات اللاعبين',
                  onPressed: MatchVoice.instance.toggleSpeaker,
                  icon: Icon(MatchVoice.instance.speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                ),
              ],
              if (s.entry > 0) _PotPill(prize: s.prize),
              IconButton(
                tooltip: 'طريقة اللعب',
                onPressed: () => showLudoHelp(context),
                icon: const Icon(Icons.help_outline_rounded),
              ),
              if (s.entry == 0 && !_online)
                IconButton(
                  key: const ValueKey('ludo-setup'),
                  tooltip: 'إعدادات اللعبة',
                  onPressed: () => _leave(toSetup: true),
                  icon: const Icon(Icons.tune_rounded),
                ),
            ]),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final reserved = s.power ? 290.0 : 210.0;
              final boardSize = min(c.maxWidth - 24, c.maxHeight - reserved).clamp(240.0, 640.0);
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Center(
                  child: SizedBox(
                    width: boardSize,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _playersRow(LudoColor.green, LudoColor.yellow),
                        const SizedBox(height: 10),
                        _board(boardSize),
                        const SizedBox(height: 10),
                        _playersRow(LudoColor.red, LudoColor.blue),
                        const SizedBox(height: 10),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: AnimatedSwitcher(
                            duration: 250.ms,
                            child: Text(
                              _status,
                              key: ValueKey(_status),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        if (s.power) ...[const SizedBox(height: 8), _itemBar()],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// شريط الأدوات للاعب البشري في دوره.
  Widget _itemBar() {
    final c = game.current;
    final mine = _humanTurn && game.phase != LudoPhase.gameOver;
    final owner = mine ? c : (_solo ? _me : c);
    final canUse = mine && !_busy && game.phase == LudoPhase.waitingRoll;
    bool active(LudoItem i) => switch (i) {
          LudoItem.doubleDistance => game.doubleActive && game.current == owner,
          LudoItem.diceControl => game.controlledValue != null && game.current == owner,
          LudoItem.shield => game.shielded.contains(owner),
        };
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .25),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ludoColors[owner]!.withValues(alpha: .6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final i in LudoItem.values)
              GestureDetector(
                key: ValueKey('use-${i.name}'),
                onTap: canUse && !active(i)
                    ? () => game.itemCount(owner, i) > 0 ? _useItem(i) : _buyItem(i, owner)
                    : null,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _ItemBadge(
                    item: i,
                    count: game.itemCount(owner, i),
                    size: 40,
                    active: active(i),
                    enabled: canUse && (game.itemCount(owner, i) > 0 || _bought[i]! < maxBuys),
                  ),
                  Text(itemInfo[i]!.$1, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _playersRow(LudoColor left, LudoColor right) {
    return Row(
      children: [
        Expanded(child: _panel(left, alignEnd: false)),
        const SizedBox(width: 10),
        Expanded(child: _panel(right, alignEnd: true)),
      ],
    );
  }

  Widget _panel(LudoColor c, {required bool alignEnd}) {
    if (!s.colors.contains(c)) return const SizedBox(height: 64);
    final active = game.current == c && game.phase != LudoPhase.gameOver;
    final color = ludoColors[c]!;
    final done = game.tokens[c]!.where((t) => t.finished).length;
    final isHuman = widget.humans.contains(c);
    final shielded = game.shielded.contains(c);

    final fx = _fx[c];
    final seatUid = _seat(c)?.uid;
    final talking = _online && seatUid != null && MatchVoice.instance.micsOpen.contains(seatUid);
    final avatar = GestureDetector(
      key: ValueKey('ludo-avatar-${c.name}'),
      onTap: () => _sendFx(c),
      child: SizedBox(
      width: 50,
      height: 50,
      child: Stack(clipBehavior: Clip.none, children: [
        AnimatedContainer(
          duration: 300.ms,
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color : Colors.white24,
            boxShadow: active ? [BoxShadow(color: color, blurRadius: 16)] : null,
          ),
          child: _online && _seat(c) != null
              ? FramedAvatar(index: _seat(c)!.avatar, size: 42, frame: _seat(c)!.frame)
              : _solo && c == _me && Account.instance.signedIn
              ? FramedAvatar(index: Account.instance.profile!.avatar, size: 42, frame: Account.instance.profile!.frame)
              : CircleAvatar(
                  backgroundColor: Color.lerp(color, Colors.black, .35),
                  child: Icon(isHuman ? Icons.face_rounded : Icons.smart_toy_rounded, color: Colors.white),
                ),
        ),
        if (shielded)
          const Positioned(
            right: -4,
            bottom: -2,
            child: Icon(Icons.shield_rounded, color: Color(0xFF2EE59D), size: 22),
          ),
        if (s.teams)
          Positioned(
            left: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: LudoGame.teamOf(c) == 0 ? const Color(0xFFFF8A3D) : const Color(0xFF3DB8FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(LudoGame.teamOf(c) == 0 ? 'A' : 'B',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ),
        if (talking)
          const Positioned(
            left: -4,
            bottom: -2,
            child: CircleAvatar(radius: 9, backgroundColor: Color(0xFF3DDC84), child: Icon(Icons.mic_rounded, size: 12, color: Colors.black)),
          ),
        if (fx != null)
          Positioned(
            left: -20,
            right: -20,
            top: -46,
            child: Center(child: GameFxBubble(key: ValueKey(fx.key), emoji: fx.emoji, from: fx.from)),
          ),
      ]),
    ),
    );

    final info = Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_nameOf(c),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          Text('🏁 $done/${s.rules.tokensPerPlayer}',
              maxLines: 1,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
        ],
      ),
    );

    final dice = active ? _dice(isHuman) : const SizedBox(width: 52);

    final children = [avatar, const SizedBox(width: 6), Expanded(child: info), dice];
    return SizedBox(
      height: 64,
      child: Row(children: alignEnd ? children.reversed.toList() : children),
    );
  }

  Widget _dice(bool isHuman) {
    final canTap = isHuman && !_busy && game.phase == LudoPhase.waitingRoll;
    final skin = isHuman && (_solo || widget.humans.length > 1) ? _diceSkin : 'classic';
    Widget d = _rolling ? DiceArt(skin: skin, size: 50) : DiceFace(value: _diceFace, size: 46, skin: skin);
    if (_rolling) {
      d = d
          .animate(onPlay: (c) => c.repeat())
          .rotate(duration: 280.ms, begin: 0, end: 1)
          .scaleXY(begin: .9, end: 1.1, duration: 140.ms)
          .then()
          .scaleXY(begin: 1.1, end: .9, duration: 140.ms);
    } else if (canTap) {
      d = d
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -5, duration: 450.ms)
          .scaleXY(begin: 1, end: 1.08, duration: 450.ms);
    }
    final x2 = game.doubleActive && !_rolling;
    return GestureDetector(
      key: isHuman ? const ValueKey('ludo-dice') : null,
      onTap: canTap ? _roll : null,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: canTap
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .7), blurRadius: 14)],
                )
              : null,
          child: d,
        ),
        if (x2)
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFF3DB8FF), borderRadius: BorderRadius.circular(8)),
              child: const Text('×2', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1, end: 1.15, duration: 400.ms),
          ),
      ]),
    );
  }

  Widget _board(double size) {
    final movable = (_humanTurn && game.phase == LudoPhase.waitingMove && !_busy)
        ? game.legalMoves.map((m) => m.token).toSet()
        : <LudoToken>{};

    final positions = <LudoToken, Offset>{};
    final groups = <String, List<LudoToken>>{};
    for (final t in game.allTokens) {
      final pos = _shown[t] ?? t.pos;
      final ctr = LudoLayout.tokenCenter(t.color, t.id, pos);
      positions[t] = ctr;
      if (pos != LudoGeo.yard) groups.putIfAbsent('${ctr.dx},${ctr.dy}', () => []).add(t);
    }

    final sorted = game.allTokens.toList()
      ..sort((a, b) {
        int rank(LudoToken t) => t == _hopping ? 2 : (movable.contains(t) ? 1 : 0);
        return rank(a).compareTo(rank(b));
      });

    final theme = boardThemes[_boardTheme] ?? boardThemes['classic']!;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .025),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .05),
        gradient: LinearGradient(colors: theme.frame),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .03),
        child: LayoutBuilder(builder: (context, c) {
          final cs = c.maxWidth / LudoLayout.grid;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: LudoBoardPainter(active: s.colors.toSet(), theme: _boardTheme, power: s.power),
                ),
              ),
              // أدوات الباور الموجودة على اللوح
              for (final e in game.pickups.entries)
                Positioned(
                  key: ValueKey('pickup-${e.key}'),
                  left: (LudoLayout.track[e.key].$1 + .5) * cs - cs * .48,
                  top: (LudoLayout.track[e.key].$2 + .5) * cs - cs * .48,
                  width: cs * .96,
                  height: cs * .96,
                  child: IgnorePointer(
                    child: ItemArt(item: e.value, size: cs * .96)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: .86, end: 1.04, duration: 700.ms, curve: Curves.easeInOut),
                  ),
                ),
              for (final t in sorted) _tokenWidget(t, positions[t]!, groups, cs, movable.contains(t)),
              for (final e in _bursts.entries)
                Positioned(
                  key: ValueKey('burst-${e.key}'),
                  left: LudoLayout.finishSpot(e.value).dx * cs - cs * 3,
                  top: LudoLayout.finishSpot(e.value).dy * cs - cs * 3,
                  width: cs * 6,
                  height: cs * 6,
                  child: HomeBurst(
                    color: ludoColors[e.value]!,
                    size: cs * 6,
                    onDone: () {
                      if (mounted) setState(() => _bursts.remove(e.key));
                    },
                  ),
                ),
            ],
          );
        }),
      ),
    ).animate().fadeIn(duration: 400.ms).scaleXY(begin: .9, end: 1, curve: Curves.easeOutBack, duration: 500.ms);
  }

  Widget _tokenWidget(LudoToken t, Offset ctr, Map<String, List<LudoToken>> groups, double cs, bool movable) {
    final group = groups['${ctr.dx},${ctr.dy}'];
    var size = cs * .82;
    var offset = Offset.zero;
    if (group != null && group.length > 1) {
      final i = group.indexOf(t);
      size = cs * .6;
      const spread = [Offset(-.2, -.2), Offset(.2, -.2), Offset(-.2, .2), Offset(.2, .2)];
      offset = spread[i % 4] * cs;
    }
    if (t.inYard && !_shown.containsKey(t)) size = cs * 1.0;
    final center = ctr * cs + offset;
    final hopping = t == _hopping;
    final shielded = game.isProtected(t) && !t.inYard && !t.finished;

    Widget pawn = LudoPawn(color: t.color, size: size, highlight: movable);
    if (shielded) {
      pawn = Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2EE59D), width: 2),
              boxShadow: const [BoxShadow(color: Color(0x992EE59D), blurRadius: 8)],
            ),
          ),
        ),
        pawn,
      ]);
    }
    if (movable) {
      pawn = pawn
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -cs * .18, duration: 380.ms, curve: Curves.easeInOut);
    }
    if (hopping) {
      pawn = pawn.animate(key: ValueKey(_shown[t])).scaleXY(begin: 1.25, end: 1, duration: 160.ms);
    }

    return AnimatedPositioned(
      key: ValueKey('${t.color}-${t.id}'),
      duration: Duration(milliseconds: hopping ? 150 : 450),
      curve: hopping ? Curves.easeOut : Curves.easeInOutBack,
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTokenTap(t),
        child: pawn,
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _PotPill extends StatelessWidget {
  const _PotPill({required this.prize});
  final int prize;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFE27A), AppColors.goldDeep]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏆', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text('$prize', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.bgTop)),
        ]),
      );
}

class _ResultsDialog extends StatelessWidget {
  const _ResultsDialog({
    required this.ranking,
    required this.nameOf,
    required this.humanWon,
    required this.onAgain,
    required this.onHome,
    this.winnerName = '',
    this.teams = false,
    this.entry = 0,
    this.payout = 0,
    this.reward,
  });
  final Reward? reward;
  final String winnerName;
  final List<LudoColor> ranking;
  final String Function(LudoColor) nameOf;
  final bool humanWon;
  final bool teams;
  final int entry;
  final int payout;
  final VoidCallback onAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    const medals = ['🥇', '🥈', '🥉', '4'];
    final winner = nameOf(ranking.first);
    final title = teams
        ? (humanWon ? 'فريقك فاز!' : 'فاز الفريق الآخر')
        : '$winner ${winner == 'أنت' ? 'فزت' : 'فاز'}!';
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 56))
                  .animate()
                  .scale(duration: 700.ms, curve: Curves.elasticOut, begin: Offset.zero),
              WinBanner(name: winnerName.isEmpty ? winner : winnerName, subtitle: title),
              const SizedBox(height: 14),
              for (final (i, c) in ranking.indexed)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: ludoColors[c]!.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(medals[i], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 10),
                      LudoPawn(color: c, size: 24),
                      const SizedBox(width: 10),
                      Text(nameOf(c), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ],
                  ),
                ).animate().fadeIn(delay: (200 + i * 120).ms).slideX(begin: .3, end: 0),
              if (entry > 0)
                Container(
                  key: const ValueKey('bet-result'),
                  margin: const EdgeInsets.only(top: 4, bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: (payout > 0 ? AppColors.gold : const Color(0xFFFF5A5F)).withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const CoinIcon(size: 24),
                    const SizedBox(width: 8),
                    Text(
                      payout > 0 ? 'ربحت الرهان +$payout' : 'خسرت الرهان -$entry',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: payout > 0 ? AppColors.gold : const Color(0xFFFF8A8A),
                      ),
                    ),
                  ]),
                ).animate().scale(delay: 500.ms, curve: Curves.elasticOut, duration: 700.ms),
              if (reward != null) ...[const SizedBox(height: 6), RewardBanner(reward: reward!)],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('ludo-again'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bgTop,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: onAgain,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(entry > 0 ? 'مرة أخرى ($entry)' : 'العب مرة أخرى',
                            style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
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
      ),
    );
  }
}
