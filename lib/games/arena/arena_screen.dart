import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/haptics.dart';
import '../../core/landscape.dart';
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
                              enterLandscape();
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

  // الكاميرا: تتبع ناعم + نظرة للأمام باتجاه التصويب + اهتزاز
  Offset _cam = Offset.zero;
  Offset _look = Offset.zero;
  Offset _camShake = Offset.zero;
  final _rng = Random();
  int _seenKills = 0;
  double _streakAt = -10;
  int _streak = 0;

  /// هل الشاشة طولية على جوال؟ عندها نديرها بأنفسنا (مثل سفاري الآيفون).
  bool _rotated = false;

  @override
  void initState() {
    super.initState();
    enterLandscape();
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
    _look = Offset.zero;
    _seenKills = 0;
    _streak = 0;
    _streakAt = -10;
  }

  @override
  void dispose() {
    exitLandscape();
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
    _updateCamera(dt);
    _trackKills();
    _playSounds();
    _frame.value++;
    if (++_frames % 4 == 0) _hud.value++;
    if (g.over && !_ended) {
      _ended = true;
      _finish();
    }
  }

  void _updateCamera(double dt) {
    final me = g.player;
    var want = Offset.zero;
    final aim = _input.aim;
    if (me.alive && aim != null && aim.distance > 0) {
      want = aim / aim.distance * (me.gun?.kind == WeaponKind.sniper ? 170 : 90);
    } else if (me.alive) {
      want = _input.move * 45;
    }
    final k1 = 1 - exp(-3.5 * dt), k2 = 1 - exp(-14 * dt);
    _look = Offset.lerp(_look, want, k1)!;
    final target = me.pos + _look;
    _cam = (_cam - target).distance > 600 ? target : Offset.lerp(_cam, target, k2)!;
    final s = g.shake * g.shake * 14;
    _camShake = s < .3 ? Offset.zero : Offset((_rng.nextDouble() * 2 - 1) * s, (_rng.nextDouble() * 2 - 1) * s);
  }

  void _trackKills() {
    final n = g.playerKillTimes.length;
    if (n == _seenKills) return;
    _seenKills = n;
    _streak = g.time - _streakAt < 6 ? _streak + 1 : 1;
    _streakAt = g.time;
  }

  void _jump() {
    final landing = _landing ??
        g.towns[Random().nextInt(g.towns.length)].center + Offset(Random().nextDouble() * 200 - 100, Random().nextDouble() * 200 - 100);
    g.start(landing);
    _cam = g.player.pos;
    _look = Offset.zero;
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
          case 'boom':
            if (d < 500) Haptics.heavyImpact();
            Sfx.instance.noise(.55, vol: .45 * vol, freq: 260, q: .5, filter: 'lowpass');
            Sfx.instance.tone(120, 35, .5, type: 'sine', vol: .25 * vol);
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
      builder: (ctx) => _maybeRotate(GameResultDialog(
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
      )),
    );
    if (!mounted) return;
    if (again == true) {
      setState(_newGame);
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _maybeRotate(Widget w) => _rotated ? RotatedBox(quarterTurns: 1, child: w) : w;

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

  double get _scale => (_size.shortestSide / 480).clamp(.6, 1.4);

  /// موقع الماوس على الشاشة → اتجاه من اللاعب (مع مراعاة حركة الكاميرا).
  Offset _toAim(Offset p) {
    final playerOnScreen = Offset(_size.width / 2, _size.height / 2) + (g.player.pos - _cam) * _scale;
    return p - playerOnScreen;
  }

  void _down(PointerDownEvent e) {
    if (_dropping) return;
    if (e.kind == PointerDeviceKind.mouse) {
      _mouse = true;
      _mouseFire = true;
      _mouseAim = _toAim(e.localPosition);
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
      _mouseAim = _toAim(e.localPosition);
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
      if (!_dropping && g.player.alive) {
        final me = g.player;
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
          child: LayoutBuilder(builder: (context, outer) {
            final phone = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
            _rotated = phone && outer.maxHeight > outer.maxWidth * 1.1;
            final view = LayoutBuilder(builder: (context, c) {
              _size = c.biggest;
              final scale = (c.biggest.shortestSide / 480).clamp(.6, 1.4);
              return _dropping ? _dropView(c.biggest) : _gameView(scale);
            });
            if (!_rotated) return view;
            // المتصفح رفض قفل الاتجاه: ندير اللعبة لتكون أفقية دائماً
            final mq = MediaQuery.of(context);
            return RotatedBox(
              quarterTurns: 1,
              child: MediaQuery(
                data: mq.copyWith(
                  size: Size(mq.size.height, mq.size.width),
                  padding: EdgeInsets.fromLTRB(mq.padding.top, mq.padding.right, mq.padding.bottom, mq.padding.left),
                  viewPadding: EdgeInsets.fromLTRB(mq.padding.top, mq.padding.right, mq.padding.bottom, mq.padding.left),
                ),
                child: view,
              ),
            );
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
              _mouseAim = _toAim(e.localPosition);
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              onPointerCancel: _up,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ArenaPainter(g, decor,
                      scale: scale, repaint: _frame, cam: () => _cam + _camShake, aim: () => _input.aim),
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
              // نبض القلب عند انخفاض الصحة
              final beat = low ? pow(sin(g.time * 7.5).abs(), 6).toDouble() : 0.0;
              final a = me.hurtFlash > 0 ? .55 : (outside ? .38 : .22 + .3 * beat);
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.05 - .12 * beat,
                    stops: const [.55, 1],
                    colors: [
                      Colors.transparent,
                      (outside ? const Color(0xFF7B4DFF) : const Color(0xFFFF2E2E)).withValues(alpha: a),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // علامة الإصابة عند المؤشر
        IgnorePointer(
          child: ValueListenableBuilder(
            valueListenable: _frame,
            builder: (_, _, _) => g.hitMarker <= 0
                ? const SizedBox.expand()
                : CustomPaint(painter: _HitMarkerPainter(_hitPoint(), g.hitMarker / .25, g.hitKill), size: Size.infinite),
          ),
        ),
        SafeArea(child: ValueListenableBuilder(valueListenable: _hud, builder: (_, _, _) => _hudLayer())),
      ],
    );
  }

  Offset _hitPoint() {
    final center = Offset(_size.width / 2, _size.height / 2) + (g.player.pos - _cam) * _scale;
    final aim = _input.aim;
    if (aim == null || aim.distance == 0) return center;
    if (_mouse && _mouseAim != null) return center + _mouseAim!;
    return center + aim / aim.distance * 110 * _scale;
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
    final land = _size.width > _size.height;
    final healBtns = [
      _roundBtn('🩹', '${me.bandages}', () => g.heal(me, PickupKind.bandage), active: me.bandages > 0 && me.hp < 75),
      const SizedBox(height: 8, width: 8),
      _roundBtn('💊', '${me.medkits}', () => g.heal(me, PickupKind.medkit), active: me.medkits > 0 && me.hp < 100),
    ];
    final reloadBtn = _roundBtn('🔄', gun == null ? '' : '${me.ammo[gun.kind.ammo]}', () => g.reload(me),
        active: gun != null && gun.loaded < gun.kind.mag && me.ammo[gun.kind.ammo]! > 0);
    final streakOn = g.time - _streakAt < 2.2 && _streak > 0;
    final warnOn = g.time - g.zoneWarnAt < 3;
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
        if (land)
          Positioned(
            right: 8,
            top: 96,
            child: Column(children: [reloadBtn, const SizedBox(height: 8), ...healBtns]),
          )
        else ...[
          Positioned(right: 8, bottom: 270, child: Column(children: healBtns)),
          Positioned(left: 8, bottom: 270, child: reloadBtn),
        ],
        // شريط الإقصاءات المتتالية
        if (streakOn)
          Positioned(
            top: _size.height * .2,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _streak >= 3 ? '🔥 إقصاء ×$_streak!' : (_streak == 2 ? '💥 إقصاء مزدوج!' : '💀 إقصاء!'),
                style: AppTheme.display.copyWith(
                  fontSize: 30,
                  color: _streak >= 2 ? AppColors.gold : Colors.white,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 12), Shadow(color: Color(0xFFE2582B), blurRadius: 24)],
                ),
              )
                  .animate(key: ValueKey('streak$_seenKills'))
                  .scale(begin: const Offset(2.2, 2.2), end: const Offset(1, 1), duration: 260.ms, curve: Curves.easeOutBack)
                  .fadeIn(duration: 120.ms)
                  .then(delay: 1400.ms)
                  .fadeOut(duration: 400.ms),
            ),
          ),
        if (warnOn && !streakOn)
          Positioned(
            top: _size.height * .2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xCC2A1450),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFB9A2FF), width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x887B4DFF), blurRadius: 18)],
                ),
                child: const Text('⚠️ العاصفة تتقدم! ادخل الدائرة',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
              )
                  .animate(key: ValueKey('warn${g.zoneWarnAt}'))
                  .slideY(begin: -1, end: 0, duration: 300.ms, curve: Curves.easeOutBack)
                  .fadeIn()
                  .then()
                  .shimmer(duration: 900.ms, color: const Color(0xFFB9A2FF)),
            ),
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
              final land = c.maxWidth > c.maxHeight;
              final side = land ? min(c.maxHeight - 16, c.maxWidth * .55) : min(c.maxWidth - 24, c.maxHeight - 200);
              final map = GestureDetector(
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
              );
              final jumpBtn = BigButton(
                label: _landing == null ? 'انزل في مكان عشوائي' : '🪂 اقفز الآن',
                colors: arenaColors,
                onTap: _jump,
              );
              if (land) {
                return Row(
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: map.animate().scale(begin: const Offset(.9, .9), duration: 300.ms)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          children: [
                            const GameTopBar(title: 'ساحة البقاء', subtitle: 'اختر مكان النزول'),
                            const Spacer(),
                            Text('🪂 المس الخريطة لتحديد مكان هبوطك',
                                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                            const SizedBox(height: 6),
                            Text('$left', style: AppTheme.display.copyWith(fontSize: 42, color: AppColors.gold)),
                            const Spacer(),
                            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: jumpBtn),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
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
    final land = s.width > s.height;
    final ix = land ? min(130.0, s.width * .15) : 96.0;
    final iy = land ? s.height - min(120.0, s.height * .3) : s.height - 190;
    stick(l, Offset(ix, iy), Colors.white, 'تحرك');
    stick(r, Offset(s.width - ix, iy), const Color(0xFFFF6B6B), 'صوّب');
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// علامة X عند إصابة الهدف (حمراء عند الإقصاء).
class _HitMarkerPainter extends CustomPainter {
  _HitMarkerPainter(this.at, this.t, this.kill);
  final Offset at;
  final double t;
  final bool kill;

  @override
  void paint(Canvas canvas, Size size) {
    final k = t.clamp(0.0, 1.0);
    final gap = 6 + 8 * (1 - k);
    final len = kill ? 13.0 : 9.0;
    final p = Paint()
      ..strokeWidth = kill ? 4 : 3
      ..strokeCap = StrokeCap.round
      ..color = (kill ? const Color(0xFFFF3B3B) : Colors.white).withValues(alpha: k);
    final sh = Paint()
      ..strokeWidth = p.strokeWidth + 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: .4 * k);
    for (var i = 0; i < 4; i++) {
      final d = Offset.fromDirection(pi / 4 + i * pi / 2);
      canvas.drawLine(at + d * gap, at + d * (gap + len), sh);
      canvas.drawLine(at + d * gap, at + d * (gap + len), p);
    }
  }

  @override
  bool shouldRepaint(covariant _HitMarkerPainter o) => true;
}
