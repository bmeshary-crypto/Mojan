import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/haptics.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/game_ui.dart';
import 'arena_engine.dart';
import 'arena_painter.dart';

const arenaColors = [Color(0xFFFFB35C), Color(0xFFE2582B), Color(0xFF5E1A0E)];

/// شاشة إعداد «ساحة البقاء».
class ArenaScreen extends StatefulWidget {
  const ArenaScreen({super.key});

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> {
  Difficulty _diff = Difficulty.normal;
  int _skin = 0;

  @override
  Widget build(BuildContext context) {
    final best = Account.instance.profile?.statsFor('arena');
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              const GameTopBar(title: 'ساحة البقاء', subtitle: 'فردي ضد 19'),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _banner(),
                          const SizedBox(height: 18),
                          if (best != null && best.played > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                children: [
                                  _stat('🎮', '${best.played}', 'مباريات'),
                                  _stat('🏆', '${best.wins}', 'انتصار'),
                                  _stat('⭐', '${best.best}', 'أفضل نقاط'),
                                ],
                              ),
                            ),
                          const Text('الصعوبة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 8),
                          ChoiceRow<Difficulty>(
                            options: [for (final d in Difficulty.values) (d, d.label)],
                            value: _diff,
                            onChanged: (d) => setState(() => _diff = d),
                          ),
                          const SizedBox(height: 18),
                          const Text('لون مقاتلك', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              for (var i = 0; i < arenaSkins.length; i++)
                                GestureDetector(
                                  onTap: () => setState(() => _skin = i),
                                  child: AnimatedContainer(
                                    duration: 200.ms,
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: arenaSkins[i],
                                      shape: BoxShape.circle,
                                      border: Border.all(color: i == _skin ? Colors.white : Colors.white24, width: i == _skin ? 4 : 2),
                                      boxShadow: [if (i == _skin) BoxShadow(color: arenaSkins[i], blurRadius: 14)],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _howTo(),
                          const SizedBox(height: 22),
                          BigButton(
                            label: '🪂  ابدأ المعركة',
                            colors: arenaColors,
                            onTap: () {
                              Sfx.instance.tap();
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ArenaMatchScreen(difficulty: _diff, skin: _skin),
                              ));
                            },
                          ),
                          const SizedBox(height: 10),
                          Text('الأونلاين ضد لاعبين حقيقيين قريباً',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner() => Container(
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: arenaColors, begin: Alignment.topRight, end: Alignment.bottomLeft),
          boxShadow: [BoxShadow(color: arenaColors[1].withValues(alpha: .5), blurRadius: 24)],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Opacity(
                  opacity: .9,
                  child: Image.asset('assets/images/ar_cover.webp',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -.35),
                      errorBuilder: (_, _, _) => const SizedBox()),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.transparent, Color(0xDD1A1033)],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 12,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ساحة البقاء', style: AppTheme.display.copyWith(fontSize: 34, shadows: const [Shadow(blurRadius: 10)])),
                  const Text('20 مقاتل على جزيرة واحدة… آخر واحد يبقى هو البطل',
                      style: TextStyle(fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 8)])),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(begin: -.1, end: 0);

  Widget _stat(String e, String v, String l) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text('$e $v', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(l, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
      );

  Widget _howTo() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(18)),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('طريقة اللعب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            SizedBox(height: 6),
            Text(
              '🪂 اختر مكان نزولك على الخريطة\n'
              '🕹️ العصا اليسرى للحركة، واليمنى للتصويب والإطلاق\n'
              '🔫 خمسة أسلحة: مسدس، رشاش، بندقية، خرطوش، قناصة\n'
              '🩹 الضمادات والحقيبة الطبية تعالجك، والدرع يخفف الضرر\n'
              '🌀 العاصفة البنفسجية تضيق… ابق داخل الدائرة البيضاء\n'
              '⌨️ على الكمبيوتر: WASD للحركة، الماوس للتصويب، R تعبئة، E التقاط',
              style: TextStyle(height: 1.8, fontSize: 13),
            ),
          ],
        ),
      );
}

// ───────────────────────── المباراة ─────────────────────────

class _Stick {
  int? pointer;
  Offset origin = Offset.zero;
  Offset knob = Offset.zero;
  Offset get v => knob - origin;
}

class ArenaMatchScreen extends StatefulWidget {
  const ArenaMatchScreen({super.key, required this.difficulty, required this.skin, this.seed});
  final Difficulty difficulty;
  final int skin;
  final int? seed;

  @override
  State<ArenaMatchScreen> createState() => _ArenaMatchScreenState();
}

class _ArenaMatchScreenState extends State<ArenaMatchScreen> with SingleTickerProviderStateMixin {
  late ArenaGame g;
  late ArenaDecor decor;
  late final Ticker _ticker;
  final _frame = ValueNotifier(0);
  final _hud = ValueNotifier(0);
  final _input = ArenaInput();
  final _left = _Stick(), _right = _Stick();
  final _keys = <LogicalKeyboardKey>{};
  final _focus = FocusNode();
  Duration _last = Duration.zero;
  int _frames = 0;

  // مرحلة القفز
  bool _dropping = true;
  double _dropT = 0;
  static const _dropTime = 10.0;
  Offset? _landing;

  bool _mouse = false;
  Offset? _mouseAim;
  bool _mouseFire = false;
  bool _ended = false;

  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _newGame();
    _ticker = createTicker(_tick)..start();
    ArenaSprites.instance.load();
  }

  void _newGame() {
    g = ArenaGame(
      seed: widget.seed ?? DateTime.now().millisecondsSinceEpoch % 100000,
      difficulty: widget.difficulty,
      playerName: Account.instance.profile?.name ?? 'أنت',
      playerSkin: widget.skin,
    );
    decor = ArenaDecor(g);
    _dropping = true;
    _dropT = 0;
    _landing = null;
    _ended = false;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 0.016 : (now - _last).inMicroseconds / 1e6;
    _last = now;

    if (_dropping) {
      _dropT += dt;
      if (_dropT >= _dropTime) _jump();
      _hud.value++;
      return;
    }
    _readInput();
    g.update(dt, _input);
    _playSounds();
    _frame.value++;
    if (++_frames % 4 == 0) _hud.value++;
    if (g.over && !_ended) {
      _ended = true;
      _finish();
    }
  }

  void _jump() {
    final landing = _landing ??
        g.towns[Random().nextInt(g.towns.length)].center + Offset(Random().nextDouble() * 200 - 100, Random().nextDouble() * 200 - 100);
    g.start(landing);
    Sfx.instance.whistle();
    setState(() => _dropping = false);
  }

  void _readInput() {
    var mv = Offset.zero;
    if (_left.pointer != null) {
      final v = _left.v;
      mv = v.distance > 8 ? v / max(56.0, v.distance) : Offset.zero;
    }
    double k(LogicalKeyboardKey a, LogicalKeyboardKey b) => _keys.contains(a) || _keys.contains(b) ? 1 : 0;
    final kx = k(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight) - k(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft);
    final ky = k(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown) - k(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp);
    if (kx != 0 || ky != 0) mv = Offset(kx, ky) / Offset(kx, ky).distance;
    _input.move = mv;

    if (_right.pointer != null && _right.v.distance > 14) {
      _input.aim = _assist(_right.v);
      _input.fire = _right.v.distance > 26;
    } else if (_mouse && _mouseAim != null) {
      _input.aim = _mouseAim;
      _input.fire = _mouseFire || _keys.contains(LogicalKeyboardKey.space);
    } else {
      _input.aim = null;
      _input.fire = false;
    }
  }

  /// مساعدة تصويب بسيطة للمس: إذا كان عدو قريباً من اتجاه العصا يلتقطه.
  Offset _assist(Offset aim) {
    final me = g.player;
    final a = aim.direction;
    Fighter? best;
    var bd = .22;
    for (final f in g.fighters) {
      if (!f.alive || f.isPlayer) continue;
      final to = f.pos - me.pos;
      if (to.distance > (me.gun?.kind.range ?? 500)) continue;
      var diff = (to.direction - a).abs();
      if (diff > pi) diff = 2 * pi - diff;
      if (diff < bd && g.clearLine(me.pos, f.pos)) {
        bd = diff;
        best = f;
      }
    }
    return best == null ? aim : best.pos - me.pos;
  }

  int _shots = 0;
  void _playSounds() {
    _shots = 0;
    for (final (s, d) in g.sounds) {
      if (d > 1100) continue;
      final vol = (1 - d / 1100).clamp(.05, 1.0);
      if (s.startsWith('shot_')) {
        if (_shots++ > 2) continue;
        final heavy = s.contains('sniper') || s.contains('shotgun');
        Sfx.instance.noise(heavy ? .16 : .07, vol: (heavy ? .32 : .2) * vol, freq: heavy ? 700 : 1500, q: .7);
        Sfx.instance.tone(heavy ? 160 : 260, 60, heavy ? .14 : .06, type: 'square', vol: .06 * vol);
      } else {
        switch (s) {
          case 'pickup':
            Sfx.instance.pickup();
          case 'reload':
            Sfx.instance.tone(900, 700, .05, type: 'square', vol: .06);
            Sfx.instance.tone(700, 1100, .06, type: 'square', vol: .06, delay: .25);
          case 'hurt':
            Haptics.lightImpact();
            Sfx.instance.tone(220, 140, .08, type: 'sawtooth', vol: .08);
          case 'kill':
            Haptics.heavyImpact();
            Sfx.instance.capture();
          case 'heal':
            Sfx.instance.tone(600, 1200, .2, vol: .1);
          case 'zone':
            Sfx.instance.tone(200, 120, .8, type: 'sawtooth', vol: .1);
        }
      }
    }
    g.sounds.clear();
  }

  Future<void> _finish() async {
    final me = g.player;
    final won = me.place == 1;
    if (me.place == 0) me.place = g.aliveCount;
    final reward = Account.instance.recordGame('arena', won: won, points: g.playerPoints);
    Account.instance.earn(g.playerCoins);
    if (won) {
      Sfx.instance.bigWin();
    } else {
      Sfx.instance.lose();
    }
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GameResultDialog(
        reward: reward,
        emoji: won ? '🏆' : (me.place <= 5 ? '🔥' : '🪦'),
        title: won ? 'بطل الساحة!' : 'المركز #${me.place}',
        rows: [
          _row('🎯', 'المركز', '#${me.place} من ${g.fighters.length}'),
          _row('💀', 'الإقصاءات', '${me.kills}'),
          _row('⭐', 'النقاط', '${g.playerPoints}'),
          _row('🪙', 'عملات المكافأة', '+${g.playerCoins}'),
          if (!won && _killerName() != null) _row('☠️', 'أقصاك', _killerName()!),
        ],
        onAgain: () => Navigator.pop(ctx, true),
        onHome: () => Navigator.pop(ctx, false),
      ),
    );
    if (!mounted) return;
    if (again == true) {
      setState(_newGame);
    } else {
      Navigator.of(context).pop();
    }
  }

  String? _killerName() {
    for (final e in g.feed.reversed) {
      if (e.victim == g.player.name) return e.zone ? 'العاصفة' : e.killer;
    }
    return null;
  }

  Widget _row(String e, String l, String v) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Text('$e  $l', style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
        ]),
      );

  // ── الإدخال ──

  void _down(PointerDownEvent e) {
    if (_dropping) return;
    if (e.kind == PointerDeviceKind.mouse) {
      _mouse = true;
      _mouseFire = true;
      _mouseAim = e.localPosition - Offset(_size.width / 2, _size.height / 2);
      return;
    }
    _mouse = false;
    final s = e.localPosition.dx < _size.width / 2 ? _left : _right;
    if (s.pointer != null) return;
    s
      ..pointer = e.pointer
      ..origin = e.localPosition
      ..knob = e.localPosition;
  }

  void _move(PointerMoveEvent e) {
    if (e.kind == PointerDeviceKind.mouse) {
      _mouseAim = e.localPosition - Offset(_size.width / 2, _size.height / 2);
      return;
    }
    for (final s in [_left, _right]) {
      if (s.pointer != e.pointer) continue;
      var v = e.localPosition - s.origin;
      if (v.distance > 70) {
        // العصا تلحق الإصبع
        s.origin = e.localPosition - v / v.distance * 70;
        v = e.localPosition - s.origin;
      }
      s.knob = e.localPosition;
    }
  }

  void _up(PointerEvent e) {
    if (e.kind == PointerDeviceKind.mouse) {
      _mouseFire = false;
      return;
    }
    for (final s in [_left, _right]) {
      if (s.pointer == e.pointer) s.pointer = null;
    }
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is KeyDownEvent) {
      _keys.add(e.logicalKey);
      final me = g.player;
      if (!_dropping && me.alive) {
        final k = e.logicalKey;
        if (k == LogicalKeyboardKey.keyR) g.reload(me);
        if (k == LogicalKeyboardKey.digit1) g.switchTo(me, 0);
        if (k == LogicalKeyboardKey.digit2) g.switchTo(me, 1);
        if (k == LogicalKeyboardKey.keyE) _pickup();
        if (k == LogicalKeyboardKey.keyQ) g.heal(me, PickupKind.bandage);
        if (k == LogicalKeyboardKey.keyH) g.heal(me, PickupKind.medkit);
      }
    } else if (e is KeyUpEvent) {
      _keys.remove(e.logicalKey);
    }
    return KeyEventResult.handled;
  }

  void _pickup() {
    final p = g.weaponNear(g.player);
    if (p != null) {
      g.takeWeapon(g.player, p);
      Sfx.instance.pickup();
    }
  }

  // ── الواجهة ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A7FB8),
      body: LeaveGuard(
        enabled: !_ended,
        message: 'إذا خرجت الآن تنحسب خسارة.',
        onLeave: () {
          if (!_dropping && !_ended) Account.instance.recordGame('arena', won: false, points: g.player.kills * 100);
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _key,
          child: LayoutBuilder(builder: (context, c) {
            _size = c.biggest;
            final scale = (c.biggest.shortestSide / 540).clamp(.55, 1.4);
            return _dropping ? _dropView(c.biggest) : _gameView(scale);
          }),
        ),
      ),
    );
  }

  Widget _gameView(double scale) {
    return Stack(
      children: [
        Positioned.fill(
          child: MouseRegion(
            cursor: SystemMouseCursors.precise,
            onHover: (e) {
              _mouse = true;
              _mouseAim = e.localPosition - Offset(_size.width / 2, _size.height / 2);
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              onPointerCancel: _up,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ArenaPainter(g, decor, scale: scale, repaint: _frame),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
        // عصا التحكم
        IgnorePointer(
          child: ValueListenableBuilder(
            valueListenable: _frame,
            builder: (_, _, _) => _mouse ? const SizedBox.shrink() : CustomPaint(painter: _SticksPainter(_left, _right, _size), size: Size.infinite),
          ),
        ),
        // وميض الضرر / العاصفة
        IgnorePointer(
          child: ValueListenableBuilder(
            valueListenable: _hud,
            builder: (_, _, _) {
              final me = g.player;
              final outside = me.alive && !g.inZone(me.pos);
              final low = me.alive && me.hp < 30;
              if (!outside && !low && me.hurtFlash <= 0) return const SizedBox.expand();
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.1,
                    colors: [
                      Colors.transparent,
                      (outside ? const Color(0xFF7B4DFF) : const Color(0xFFFF2E2E)).withValues(alpha: me.hurtFlash > 0 ? .55 : .35),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(child: ValueListenableBuilder(valueListenable: _hud, builder: (_, _, _) => _hudLayer())),
      ],
    );
  }

  Widget _hudLayer() {
    final me = g.player;
    final gun = me.gun;
    final mm = min(_size.width * .3, 120.0);
    final zoneLeft = g.zoneTimeLeft.ceil();
    final zoneText = g.phase >= zonePhases.length
        ? 'المنطقة الأخيرة'
        : g.shrinking
            ? 'العاصفة تتقدم ${zoneLeft}s'
            : 'العاصفة بعد ${zoneLeft ~/ 60}:${(zoneLeft % 60).toString().padLeft(2, '0')}';
    final near = me.alive ? g.weaponNear(me) : null;
    return Stack(
      children: [
        // أعلى: رجوع، الأحياء، الإقصاءات، المؤقت
        Positioned(
          top: 6,
          right: 8,
          child: Row(
            children: [
              _iconBtn(Icons.arrow_back_rounded, () => Navigator.maybePop(context)),
              const SizedBox(width: 6),
              _chip('👥 ${g.aliveCount}', AppColors.gold),
              const SizedBox(width: 6),
              _chip('💀 ${me.kills}', const Color(0xFFFF6B6B)),
            ],
          ),
        ),
        Positioned(
          top: 52,
          right: 8,
          child: _chip('🌀 $zoneText', const Color(0xFFB9A2FF)),
        ),
        // الخريطة المصغرة
        Positioned(
          top: 6,
          left: 8,
          child: Container(
            width: mm,
            height: mm,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(mm * .08),
              border: Border.all(color: Colors.white70, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
            ),
            child: CustomPaint(painter: ArenaMapPainter(g, decor)),
          ),
        ),
        // سجل الإقصاءات
        Positioned(
          top: mm + 14,
          left: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in g.feed.where((e) => g.time - e.at < 6))
                Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    e.zone ? '🌀 العاصفة أقصت ${e.victim}' : '${e.killer ?? '؟'} 🔫 ${e.victim}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: e.killer == me.name ? AppColors.gold : (e.victim == me.name ? const Color(0xFFFF6B6B) : Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // أسفل الوسط: الصحة والدرع والأسلحة
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: min(_size.width - 16, 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (near != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _actionBtn('✋ التقاط ${near.weapon!.label}', tierColor(near.weapon!), _pickup),
                    ),
                  if (me.reloading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('جاري التعبئة…', style: TextStyle(fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 6)])),
                    ),
                  Row(
                    children: [
                      for (var i = 0; i < 2; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(child: _slot(i)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  _bar(me.armor / 100, const Color(0xFF5CC8FF), 6),
                  const SizedBox(height: 3),
                  _bar(me.hp / 100, me.hp > 30 ? const Color(0xFF6BE38F) : const Color(0xFFFF5A5F), 12,
                      text: '${me.hp.ceil()}'),
                ],
              ),
            ),
          ),
        ),
        // أزرار جانبية: علاج وتعبئة
        Positioned(
          right: 8,
          bottom: 270,
          child: Column(
            children: [
              _roundBtn('🩹', '${me.bandages}', () => g.heal(me, PickupKind.bandage), active: me.bandages > 0 && me.hp < 75),
              const SizedBox(height: 8),
              _roundBtn('💊', '${me.medkits}', () => g.heal(me, PickupKind.medkit), active: me.medkits > 0 && me.hp < 100),
            ],
          ),
        ),
        Positioned(
          left: 8,
          bottom: 270,
          child: _roundBtn('🔄', gun == null ? '' : '${me.ammo[gun.kind.ammo]}', () => g.reload(me),
              active: gun != null && gun.loaded < gun.kind.mag && me.ammo[gun.kind.ammo]! > 0),
        ),
        if (g.time < ArenaGame.landingGrace)
          Center(
            child: Text('🪂 هبطت! اجمع سلاحك… ${(ArenaGame.landingGrace - g.time).ceil()}',
                    style: AppTheme.display.copyWith(fontSize: 26, shadows: const [Shadow(blurRadius: 10)]))
                .animate()
                .fadeIn(),
          ),
        if (!me.alive)
          Center(
            child: Text('تم إقصاؤك', style: AppTheme.display.copyWith(fontSize: 44, color: const Color(0xFFFF6B6B)))
                .animate()
                .scale(begin: const Offset(2, 2), end: const Offset(1, 1), duration: 400.ms),
          ),
      ],
    );
  }

  Widget _slot(int i) {
    final me = g.player;
    final gun = me.slots[i];
    final active = me.active == i;
    return GestureDetector(
      onTap: () => setState(() => g.switchTo(me, i)),
      child: AnimatedContainer(
        duration: 150.ms,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: active ? .6 : .35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? (gun == null ? Colors.white54 : tierColor(gun.kind)) : Colors.white24, width: active ? 2.5 : 1),
        ),
        child: gun == null
            ? const Center(child: Text('فارغ', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)))
            : Row(
                children: [
                  Image.asset('assets/images/ar_gun_${gun.kind.index}.webp',
                      width: 40, height: 26, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox()),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(gun.kind.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: tierColor(gun.kind))),
                  ),
                  Text('${gun.loaded}/${me.ammo[gun.kind.ammo]}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ],
              ),
      ),
    );
  }

  Widget _bar(double v, Color c, double h, {String? text}) => Container(
        height: h,
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(h)),
        child: Stack(
          children: [
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: v.clamp(0, 1),
              child: Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(h))),
            ),
            if (text != null)
              Center(child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, height: 1))),
          ],
        ),
      );

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: .7)),
        ),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w900, color: c, fontSize: 13)),
      );

  Widget _iconBtn(IconData i, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: Icon(i, color: Colors.white),
        ),
      );

  Widget _roundBtn(String e, String n, VoidCallback onTap, {bool active = true}) => GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: active ? 1 : .45,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38, width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(e, style: const TextStyle(fontSize: 22)),
                if (n.isNotEmpty)
                  Positioned(
                    bottom: 2,
                    child: Text(n, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _actionBtn(String t, Color c, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .65),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c, width: 2),
          ),
          child: Text(t, style: TextStyle(fontWeight: FontWeight.w900, color: c)),
        ),
      );

  // ── شاشة القفز ──

  Widget _dropView(Size size) {
    return AnimatedBackground(
      child: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: _hud,
          builder: (_, _, _) {
            final left = (_dropTime - _dropT).ceil();
            return LayoutBuilder(builder: (context, c) {
              final side = min(c.maxWidth - 24, c.maxHeight - 200);
              return Column(
                children: [
                  const GameTopBar(title: 'ساحة البقاء', subtitle: 'اختر مكان النزول'),
                  const SizedBox(height: 6),
                  Text('🪂 المس الخريطة لتحديد مكان هبوطك ($left)',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTapDown: (d) {
                          Sfx.instance.tap();
                          setState(() => _landing = d.localPosition / side * ArenaGame.size);
                        },
                        child: Container(
                          width: side,
                          height: side,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(side * .08),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20)],
                          ),
                          child: CustomPaint(
                            painter: ArenaMapPainter(g, decor,
                                showPlayer: false, landing: _landing, names: true, plane: (_dropT / _dropTime).clamp(0, 1)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
                    child: BigButton(
                      label: _landing == null ? 'انزل في مكان عشوائي' : '🪂 اقفز الآن',
                      colors: arenaColors,
                      onTap: _jump,
                    ),
                  ),
                ],
              );
            });
          },
        ),
      ),
    );
  }
}

class _SticksPainter extends CustomPainter {
  _SticksPainter(this.l, this.r, this.size);
  final _Stick l, r;
  final Size size;

  @override
  void paint(Canvas canvas, Size s) {
    void stick(_Stick st, Offset idle, Color c, String hint) {
      final active = st.pointer != null;
      final o = active ? st.origin : idle;
      canvas.drawCircle(o, 62, Paint()..color = Colors.black.withValues(alpha: active ? .25 : .12));
      canvas.drawCircle(
          o,
          62,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: active ? .6 : .25));
      var k = active ? st.v : Offset.zero;
      if (k.distance > 62) k = k / k.distance * 62;
      canvas.drawCircle(o + k, 26, Paint()..color = c.withValues(alpha: active ? .85 : .35));
      if (!active) {
        final tp = ArenaPainter.label(hint, size: 11, color: Colors.white70);
        tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // على الكمبيوتر لا داعي لرسمها إذا لم تُلمس
    stick(l, Offset(96, s.height - 190), Colors.white, 'تحرك');
    stick(r, Offset(s.width - 96, s.height - 190), const Color(0xFFFF6B6B), 'صوّب');
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
