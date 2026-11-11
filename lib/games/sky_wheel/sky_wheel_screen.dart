import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../screens/shop_screen.dart';
import '../../widgets/account_widgets.dart';
import '../../widgets/game_ui.dart';
import 'sky_wheel_engine.dart';

/// لاعبون تجريبيون حتى يشتغل السيرفر (الاسم، رقم الصورة: زوجي بنت وفردي ولد).
const _botPool = [
  ('سهرة', 0), ('أحمد', 1), ('نورة', 2), ('فيصل', 3), ('ريم', 4), ('تركي', 5), ('لمى', 6),
  ('سلطان', 7), ('دانة', 8), ('يوسف', 9), ('مها', 10), ('راكان', 11), ('غلا', 12), ('عمر', 13),
  ('هيا', 14), ('ماجد', 15), ('شهد', 16), ('بندر', 15),
];

String _fmt(int n) => n >= 1000000
    ? '${(n / 1000000).toStringAsFixed(1)}M'
    : n >= 10000
        ? '${(n / 1000).toStringAsFixed(n >= 100000 ? 0 : 1)}k'
        : '$n';

/// عجلة السماء: راهن بعملاتك على كابينة قبل انتهاء الوقت، ثم تدور العجلة.
/// التاج هو أعلى ربح (×45).
class SkyWheelScreen extends StatefulWidget {
  const SkyWheelScreen({super.key, this.betSeconds = 15, this.random, this.stepMs = 1.0});

  /// مدة الرهان في كل جولة.
  final int betSeconds;
  final Random? random;

  /// معامل سرعة الحركة (أصغر = أسرع، للاختبارات).
  final double stepMs;

  @override
  State<SkyWheelScreen> createState() => _SkyWheelScreenState();
}

class _SkyWheelScreenState extends State<SkyWheelScreen> {
  late final SkyWheelGame game;
  Timer? _clock;
  late int _left = widget.betSeconds;
  int _chip = 100;
  int? _lit;
  bool _resultOpen = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    game = SkyWheelGame(random: widget.random, round: (now.hour * 60 + now.minute) * 60 ~/ 25 + 1);
    // نتائج سابقة حتى لا يكون الشريط فارغاً
    for (var i = 0; i < 8; i++) {
      game.history.add(game.pickWinner());
    }
    _startClock();
  }

  @override
  void dispose() {
    _disposed = true;
    _clock?.cancel();
    super.dispose();
  }

  void _startClock() {
    _clock?.cancel();
    _left = widget.betSeconds;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _left--;
        game.botsBet();
      });
      if (_left <= 3 && _left > 0) Haptics.selectionClick();
      if (_left <= 0) {
        _clock?.cancel();
        _spin();
      }
    });
  }

  Future<void> _wait(int ms) => Future.delayed(Duration(milliseconds: (ms * widget.stepMs).round()));

  Future<void> _spin() async {
    final win = game.startSpin();
    final target = skyPods.indexWhere((p) => p.id == win);
    // الإضاءة تلف حول العجلة دورتين ثم تتباطأ حتى تقف على الفائز
    final start = _lit ?? 0;
    final steps = skyPods.length * 3 + ((target - start) % skyPods.length);
    for (var i = 1; i <= steps; i++) {
      if (_disposed) return;
      setState(() => _lit = (start + i) % skyPods.length);
      Haptics.selectionClick();
      final t = i / steps;
      await _wait((45 + 320 * t * t * t).round());
    }
    if (_disposed) return;
    final p = Account.instance.profile;
    final pay = game.settle(_botPool, myName: p?.name ?? 'أنا', myAvatar: p?.avatar ?? 0);
    if (pay > 0) {
      Account.instance.earn(pay);
      Haptics.heavyImpact();
    }
    setState(() => _resultOpen = true);
    await Future.delayed(const Duration(milliseconds: 4200));
    if (_disposed) return;
    _nextRound();
  }

  void _nextRound() {
    if (game.phase != SkyPhase.result) return;
    setState(() {
      _resultOpen = false;
      game.next();
    });
    _startClock();
  }

  void _toast(String t) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
        action: t.contains('رصيد') ? SnackBarAction(label: 'المتجر', onPressed: () => openShop(context)) : null,
      ));
  }

  void _bet(String key) {
    if (game.phase != SkyPhase.betting) {
      _toast('انتظر الجولة الجاية للرهان');
      return;
    }
    if (_left <= 0) return;
    if (!Account.instance.spend(_chip)) {
      _toast('رصيدك لا يكفي لهذا الرهان');
      return;
    }
    Haptics.lightImpact();
    setState(() => game.bet(key, _chip));
  }

  @override
  Widget build(BuildContext context) {
    final inPlay = game.myTotal > 0 && game.phase != SkyPhase.result;
    return LeaveGuard(
      enabled: inPlay,
      message: 'عندك رهانات في هذه الجولة، وإذا خرجت تضيع عليك.',
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A2C8F), Color(0xFF5B49C9), Color(0xFF2A1E6B), AppColors.bgTop],
              stops: [0, .45, .75, 1],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: ListenableBuilder(
                      listenable: Account.instance,
                      builder: (context, _) => Column(
                        children: [
                          _topBar(),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: Column(
                                children: [
                                  _wheel(),
                                  const SizedBox(height: 8),
                                  _prompt(),
                                  const SizedBox(height: 10),
                                  _chips(),
                                  const SizedBox(height: 10),
                                  _stats(),
                                  const SizedBox(height: 10),
                                  _historyStrip(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_resultOpen) _resultOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- الشريط العلوي ----------------

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('sw-back'),
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 28),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('عجلة السماء', style: AppTheme.display.copyWith(fontSize: 24)),
                  ),
                  Text('الجولة ${game.round} اليوم',
                      key: const ValueKey('sw-round'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            _roundBtn('sw-rank', Icons.emoji_events_rounded, _showRanking, color: AppColors.gold),
            _roundBtn('sw-history', Icons.receipt_long_rounded, _showHistory),
            _roundBtn('sw-help', Icons.help_outline_rounded, _showRules),
          ],
        ),
      );

  Widget _roundBtn(String key, IconData icon, VoidCallback onTap, {Color color = Colors.white}) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 6),
        child: InkResponse(
          key: ValueKey(key),
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .12),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      );

  // ---------------- العجلة ----------------

  Widget _wheel() => LayoutBuilder(builder: (context, c) {
        final s = min(c.maxWidth, 440.0);
        final r = s * .36;
        final pod = s * .2;
        final ctr = Offset(s / 2, s / 2);
        return SizedBox(
          width: s,
          height: s * 1.04,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // سحب في الأسفل
              Positioned(
                left: -12,
                right: -12,
                bottom: 0,
                height: s * .26,
                child: const IgnorePointer(child: _Clouds()),
              ),
              Positioned.fill(
                bottom: s * .04,
                child: CustomPaint(painter: _WheelPainter(radius: r, hub: s * .17, lit: _lit)),
              ),
              // المركز: العد التنازلي
              Positioned(
                left: ctr.dx - s * .17,
                top: ctr.dy - s * .17,
                width: s * .34,
                height: s * .34,
                child: _hub(s * .34),
              ),
              for (final (i, p) in skyPods.indexed)
                Positioned(
                  left: ctr.dx + r * cos(-pi / 2 + i * 2 * pi / skyPods.length) - pod / 2,
                  top: ctr.dy + r * sin(-pi / 2 + i * 2 * pi / skyPods.length) - pod / 2,
                  width: pod,
                  height: pod + 22,
                  child: _podTile(i, p, pod),
                ),
              // رهانات المجموعات في الزاويتين
              for (final (i, g) in skyGroups.indexed)
                Positioned(
                  left: i == 0 ? 0 : null,
                  right: i == 1 ? 0 : null,
                  bottom: -s * .02,
                  width: s * .19,
                  child: _groupTile(g, s * .19),
                ),
            ],
          ),
        );
      });

  Widget _hub(double d) {
    final betting = game.phase == SkyPhase.betting;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xFFFFF3A6), Color(0xFFFFD23D), Color(0xFFF3A712)]),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0xAAFFD23D), blurRadius: 24, spreadRadius: 2)],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                betting ? 'وقت الرهان' : (game.phase == SkyPhase.spinning ? 'جاري السحب' : 'النتيجة'),
                style: const TextStyle(color: Color(0xFF8A4B00), fontWeight: FontWeight.w900, fontSize: 13),
              ),
              if (betting)
                Text('$_left',
                        key: const ValueKey('sw-timer'),
                        style: AppTheme.display.copyWith(fontSize: 44, color: const Color(0xFF6B3A00), height: 1.1))
                    .animate(key: ValueKey(_left))
                    .scaleXY(begin: 1.25, end: 1, duration: 300.ms, curve: Curves.easeOutBack)
              else if (game.phase == SkyPhase.spinning)
                const Text('🎡', style: TextStyle(fontSize: 38))
                    .animate(onPlay: (c) => c.repeat())
                    .rotate(duration: 900.ms)
              else
                Image.asset('assets/images/${skyPod(game.winner!).art}.webp', width: 48, height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _betBadge(int amount) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFF2EE59D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 1.2),
        ),
        child: Text(_fmt(amount),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10.5, color: AppColors.bgTop)),
      );

  Widget _podTile(int i, SkyPod p, double d) {
    final lit = _lit == i && game.phase != SkyPhase.betting;
    final won = game.phase == SkyPhase.result && game.winner == p.id;
    final mine = game.myBets[p.id] ?? 0;
    final crown = p.id == 'crown';
    Widget bubble = Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-.3, -.4),
          colors: [Colors.white.withValues(alpha: .55), const Color(0xFF8F7CFF).withValues(alpha: .35)],
        ),
        border: Border.all(
          color: lit || won ? AppColors.gold : (crown ? const Color(0xFFFFE27A) : Colors.white70),
          width: lit || won ? 3.5 : 2,
        ),
        boxShadow: [
          if (lit || won) const BoxShadow(color: Color(0xCCFFD23D), blurRadius: 22, spreadRadius: 3),
          if (crown && !lit) const BoxShadow(color: Color(0x66FFD23D), blurRadius: 14),
        ],
      ),
      padding: EdgeInsets.all(d * .16),
      child: Image.asset('assets/images/${p.art}.webp', fit: BoxFit.contain),
    );
    if (won) {
      bubble = bubble
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.12, duration: 450.ms);
    } else if (lit) {
      bubble = Transform.scale(scale: 1.1, child: bubble);
    }
    return GestureDetector(
      key: ValueKey('sw-pod-${p.id}'),
      onTap: () => _bet(p.id),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              bubble,
              if (mine > 0) Positioned(top: -8, child: _betBadge(mine)),
            ],
          ),
          Transform.translate(
            offset: const Offset(0, -6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: crown ? const Color(0xFFE09B12) : const Color(0xFF3B2A9E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: crown ? const Color(0xFFFFE27A) : const Color(0xFF7CC8FF), width: 1.2),
              ),
              child: Text('×${p.mult}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupTile(SkyGroup g, double d) {
    final mine = game.myBets[g.id] ?? 0;
    final won = game.phase == SkyPhase.result && g.pods.contains(game.winner);
    return GestureDetector(
      key: ValueKey('sw-${g.id}'),
      onTap: () => _bet(g.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: d,
                height: d,
                padding: EdgeInsets.all(d * .14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFB86CFF), Color(0xFF6C3FD6)]),
                  border: Border.all(color: won ? AppColors.gold : Colors.white70, width: won ? 3 : 1.5),
                  boxShadow: [if (won) const BoxShadow(color: Color(0xCCFFD23D), blurRadius: 18)],
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  children: [
                    for (final id in g.pods)
                      Image.asset('assets/images/${skyPod(id).art}.webp',
                          width: d * (g.pods.length > 2 ? .3 : .34), height: d * (g.pods.length > 2 ? .3 : .34)),
                  ],
                ),
              ),
              if (mine > 0) Positioned(top: -8, child: _betBadge(mine)),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${g.title} ×${g.payout}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  // ---------------- الرهان ----------------

  Widget _prompt() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6C3FD6), Color(0xFF8E6CFF)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          game.phase == SkyPhase.betting
              ? (game.myTotal > 0
                  ? 'رهانك في هذه الجولة: ${game.myTotal} 🪙'
                  : 'اختر قيمة الرهان ← ثم اضغط على الكابينة')
              : 'انتظر الجولة الجاية…',
          key: const ValueKey('sw-prompt'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      );

  Widget _chips() => Row(
        children: [
          for (final (i, v) in skyChips.indexed)
            Expanded(
              child: GestureDetector(
                key: ValueKey('sw-chip-$v'),
                onTap: () => setState(() => _chip = v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _chip == v ? const Color(0xFF7CC8FF).withValues(alpha: .3) : Colors.white.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _chip == v ? const Color(0xFF7CF5FF) : Colors.white24, width: _chip == v ? 2.5 : 1),
                    boxShadow: [if (_chip == v) const BoxShadow(color: Color(0x887CF5FF), blurRadius: 12)],
                  ),
                  child: Column(children: [
                    Image.asset('assets/images/coins_${i + 1}.webp', width: 42, height: 42),
                    Text('$v', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
            ),
        ],
      );

  Widget _stats() {
    final coins = Account.instance.profile?.coins ?? 0;
    Widget card(String key, String label, String value) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.white.withValues(alpha: .16), Colors.white.withValues(alpha: .06)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const CoinIcon(size: 18),
                const SizedBox(width: 4),
                Text(value, key: ValueKey(key), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              ]),
            ]),
          ),
        );
    return Row(children: [
      card('sw-coins', 'رصيدك', '$coins'),
      card('sw-today', 'ربحك اليوم', '${game.todayWin}'),
    ]);
  }

  Widget _historyStrip() => Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Text('النتائج:', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
            const SizedBox(width: 6),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (i, id) in game.history.take(12).indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Image.asset('assets/images/${skyPod(id).art}.webp', width: 30, height: 30),
                            if (i == 0)
                              Positioned(
                                bottom: -4,
                                left: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF4D6D),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('جديد', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900)),
                                ),
                              ),
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

  // ---------------- النتيجة ----------------

  Widget _resultOverlay() {
    final w = skyPod(game.winner!);
    final pay = game.lastPayout;
    final crown = w.id == 'crown';
    final title = pay > 0
        ? 'مبروك! ربحت $pay في هذه الجولة'
        : game.myTotal > 0
            ? 'حظ أوفر المرة الجاية'
            : 'الفائز في هذه الجولة: ${w.title}';
    return Positioned.fill(
      child: GestureDetector(
        key: const ValueKey('sw-result'),
        onTap: _nextRound,
        child: Container(
          color: Colors.black.withValues(alpha: .6),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF5B3BD6), Color(0xFF2A1E6B)],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: crown ? AppColors.gold : Colors.white24, width: crown ? 2.5 : 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الجولة ${game.round}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                if (crown)
                  Text('👑 التاج! أعلى ربح ×${w.mult}',
                          style: AppTheme.display.copyWith(fontSize: 22, color: AppColors.gold))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .shimmer(duration: 1200.ms, color: Colors.white),
                const SizedBox(height: 6),
                SizedBox(
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const _Rays()
                          .animate(onPlay: (c) => c.repeat())
                          .rotate(duration: 8.seconds),
                      Image.asset('assets/images/${w.art}.webp', width: 110, height: 110)
                          .animate()
                          .scale(begin: const Offset(.3, .3), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 900.ms),
                    ],
                  ),
                ),
                Text(title,
                    key: const ValueKey('sw-result-title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: pay > 0 ? AppColors.gold : Colors.white,
                    )),
                const SizedBox(height: 14),
                const Text('— كبار الفائزين —', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final (i, x) in game.roundWinners.indexed)
                      Expanded(
                        child: Column(children: [
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.topCenter,
                            children: [
                              PlayerAvatar(index: x.avatar, size: 52),
                              Positioned(
                                top: -14,
                                child: Text(['👑', '🥈', '🥉'][i], style: const TextStyle(fontSize: 18)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(x.isMe ? 'أنت' : x.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w800, color: x.isMe ? AppColors.gold : Colors.white)),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const CoinIcon(size: 14),
                            const SizedBox(width: 3),
                            Text(_fmt(x.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                          ]),
                        ]),
                      ),
                  ],
                ),
              ],
            ),
          ).animate().scale(begin: const Offset(.85, .85), end: const Offset(1, 1), curve: Curves.easeOutBack).fadeIn(),
        ),
      ),
    );
  }

  // ---------------- النوافذ ----------------

  void _sheet(String title, Widget child, {Key? key}) => showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF2A1E6B),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => ConstrainedBox(
          key: key,
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                child: Row(children: [
                  Expanded(child: Text(title, style: AppTheme.display.copyWith(fontSize: 22))),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      );

  void _showRanking() {
    final top = game.hourlyTop;
    _sheet(
      'كبار الفائزين هذه الساعة',
      key: const ValueKey('sw-rank-sheet'),
      top.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(30),
              child: Text('لا يوجد فائزون بعد، انتظر نهاية الجولة', style: TextStyle(color: Colors.white70)),
            )
          : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              itemCount: top.length,
              itemBuilder: (_, i) {
                final x = top[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: x.isMe ? AppColors.gold.withValues(alpha: .15) : Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 28,
                      child: Text(i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                    PlayerAvatar(index: x.avatar, size: 40),
                    const SizedBox(width: 10),
                    Expanded(child: Text(x.isMe ? '${x.name} (أنت)' : x.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                    const CoinIcon(size: 16),
                    const SizedBox(width: 4),
                    Text(_fmt(x.amount), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
                  ]),
                );
              },
            ),
    );
  }

  void _showHistory() {
    final counts = <String, int>{};
    for (final id in game.history) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    _sheet(
      'آخر ${game.history.length} نتائج',
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final p in skyPods)
              Container(
                width: 92,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  Image.asset('assets/images/${p.art}.webp', width: 40, height: 40),
                  Text('${counts[p.id] ?? 0} مرة', style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('×${p.mult}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  void _showRules() {
    _sheet(
      'طريقة اللعب',
      ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text(
            '1. اختر قيمة الرهان من الأسفل (10 أو 100 أو 1000 أو 10000).\n'
            '2. اضغط على الكابينة التي تتوقع أن تفوز، وتقدر تراهن على أكثر من كابينة وأكثر من مرة.\n'
            '3. عند انتهاء الوقت تدور الإضاءة على العجلة وتقف على كابينة فائزة.\n'
            '4. إذا وقفت على كابينتك تربح رهانك مضروباً في رقمها.\n'
            '5. 👑 التاج هو أعلى ربح ×45، لكنه الأندر.\n'
            '6. رهان المجموعة يربح إذا وقفت العجلة على أي كابينة فيها.\n'
            'العملات افتراضية داخل اللعبة فقط.',
            style: TextStyle(height: 1.8, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          for (final p in skyPods)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Image.asset('assets/images/${p.art}.webp', width: 30, height: 30),
                const SizedBox(width: 10),
                Expanded(child: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800))),
                Text('×${p.mult}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
                const SizedBox(width: 14),
                SizedBox(
                  width: 70,
                  child: Text('${(SkyWheelGame.chanceOf(p.id) * 100).toStringAsFixed(1)}٪',
                      textAlign: TextAlign.end, style: const TextStyle(color: Colors.white70)),
                ),
              ]),
            ),
          for (final g in skyGroups)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                const Icon(Icons.grid_view_rounded, size: 26, color: Color(0xFFB86CFF)),
                const SizedBox(width: 12),
                Expanded(child: Text('مجموعة ${g.title}', style: const TextStyle(fontWeight: FontWeight.w800))),
                Text('×${g.payout}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
                const SizedBox(width: 14),
                SizedBox(
                  width: 70,
                  child: Text(
                      '${(g.pods.fold(0.0, (a, id) => a + SkyWheelGame.chanceOf(id)) * 100).toStringAsFixed(1)}٪',
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: Colors.white70)),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

/// أذرع العجلة والحلقة الخارجية.
class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.radius, required this.hub, this.lit});
  final double radius;
  final double hub;
  final int? lit;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.width / 2);
    final n = skyPods.length;
    // هالة خلف العجلة
    canvas.drawCircle(
      c,
      radius * 1.05,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFF7CC8FF).withValues(alpha: .35), Colors.transparent])
            .createShader(Rect.fromCircle(center: c, radius: radius * 1.3)),
    );
    final spoke = Paint()
      ..color = const Color(0xFF5FA8FF)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final spokeGlow = Paint()
      ..color = const Color(0xFFBFE3FF)
      ..strokeWidth = 2;
    for (var i = 0; i < n; i++) {
      final a = -pi / 2 + i * 2 * pi / n;
      final end = c + Offset(cos(a), sin(a)) * radius;
      canvas.drawLine(c, end, spoke..color = i == lit ? const Color(0xFFFFD23D) : const Color(0xFF5FA8FF));
      canvas.drawLine(c, end, spokeGlow);
    }
    // الحلقة الخارجية والداخلية
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = const Color(0xFF4A8CF0),
    );
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFFCDEBFF),
    );
    canvas.drawCircle(
      c,
      hub * 1.18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0xFF3B6FD8),
    );
    // أضواء حول المركز
    for (var i = 0; i < 12; i++) {
      final a = i * 2 * pi / 12;
      canvas.drawCircle(
        c + Offset(cos(a), sin(a)) * hub * 1.18,
        3.2,
        Paint()..color = Colors.white,
      );
    }
    // قاعدة العجلة
    final base = Paint()
      ..color = const Color(0xFF4A8CF0)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, c + Offset(-radius * .55, radius * 1.08), base);
    canvas.drawLine(c, c + Offset(radius * .55, radius * 1.08), base);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.lit != lit || old.radius != radius;
}

class _Clouds extends StatelessWidget {
  const _Clouds();

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        Widget puff(double x, double y, double r, double a) => Positioned(
              left: x * w - r,
              top: y * h - r,
              child: Container(
                width: r * 2,
                height: r * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: a),
                  boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: a * .6), blurRadius: 18)],
                ),
              ),
            );
        return Stack(clipBehavior: Clip.hardEdge, children: [
          puff(.1, .75, h * .45, .55),
          puff(.3, .9, h * .55, .6),
          puff(.5, .8, h * .5, .5),
          puff(.72, .92, h * .55, .6),
          puff(.92, .75, h * .45, .55),
        ]);
      });
}

class _Rays extends StatelessWidget {
  const _Rays();

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(160, 160), painter: _RaysPainter());
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()..color = const Color(0x33FFE27A);
    for (var i = 0; i < 12; i++) {
      final a = i * 2 * pi / 12;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + cos(a - .12) * 80, c.dy + sin(a - .12) * 80)
        ..lineTo(c.dx + cos(a + .12) * 80, c.dy + sin(a + .12) * 80)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => false;
}
