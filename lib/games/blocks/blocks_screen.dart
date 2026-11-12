import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/account/account.dart';
import '../../core/haptics.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import 'blocks_engine.dart';

const blockPalette = [
  Color(0xFFF2832B), // برتقالي
  Color(0xFF8E5BE8), // بنفسجي
  Color(0xFFE5393F), // أحمر
  Color(0xFF3DBE4B), // أخضر
  Color(0xFF2F8CF0), // أزرق
  Color(0xFFF5C02A), // أصفر
  Color(0xFF22C3C9), // فيروزي
];

/// مربع بحواف بارزة (شكل المكعب).
class BlockTile extends StatelessWidget {
  const BlockTile({super.key, required this.color, this.ghost = false});
  final Color color;
  final bool ghost;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: ghost ? .45 : 1,
    child: CustomPaint(painter: _BevelPainter(color), child: const SizedBox.expand()),
  );
}

/// مكعب بحواف مائلة: فاتح فوق ويسار، غامق تحت ويمين.
class _BevelPainter extends CustomPainter {
  _BevelPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final hsl = HSLColor.fromColor(color);
    final light = hsl.withLightness(min(1, hsl.lightness + .16)).toColor();
    final dark = hsl.withLightness(max(0, hsl.lightness - .2)).toColor();
    final side = hsl.withLightness(max(0, hsl.lightness - .08)).toColor();
    final b = s.width * .13;
    final w = s.width, h = s.height;
    Path poly(List<Offset> p) => Path()..addPolygon(p, true);
    canvas.drawPath(poly([Offset.zero, Offset(w, 0), Offset(w - b, b), Offset(b, b)]), Paint()..color = light);
    canvas.drawPath(poly([Offset.zero, Offset(b, b), Offset(b, h - b), Offset(0, h)]), Paint()..color = Color.lerp(light, color, .4)!);
    canvas.drawPath(poly([Offset(w, 0), Offset(w, h), Offset(w - b, h - b), Offset(w - b, b)]), Paint()..color = side);
    canvas.drawPath(poly([Offset(0, h), Offset(b, h - b), Offset(w - b, h - b), Offset(w, h)]), Paint()..color = dark);
    final face = Rect.fromLTRB(b, b, w - b, h - b);
    canvas.drawRect(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, .12)!, color],
        ).createShader(face),
    );
    canvas.drawRect(Offset.zero & s, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black26);
  }

  @override
  bool shouldRepaint(_BevelPainter o) => o.color != color;
}

class BlocksScreen extends StatefulWidget {
  const BlocksScreen({super.key, this.random, this.mode});
  final Random? random;

  /// للاختبارات: يبدأ مباشرة بوضع معين بدون قائمة.
  final BlocksMode? mode;

  @override
  State<BlocksScreen> createState() => _BlocksScreenState();
}

class _Burst {
  _Burst(this.r, this.c, this.color, this.id);
  final int r, c, color, id;
}

class _BlocksScreenState extends State<BlocksScreen> {
  static const _bg1 = Color(0xFF3A5091);
  static const _bg2 = Color(0xFF243466);
  static const _boardBg = Color(0xFF1E2747);

  BlocksMode? _mode;
  BlocksGame? _game;
  BlocksGame get game => _game!;
  final Map<BlocksMode, int> _bests = {};
  final _boardKey = GlobalKey();
  double _cell = 40;

  int? _hoverPiece;
  (int, int)? _hoverAt;
  Set<(int, int)> _flash = {};
  List<_Burst> _bursts = [];
  int _burstId = 0;
  String? _praise;
  int _praiseKey = 0;
  BlockPower? _armed;
  bool _ended = false;
  int _shownScore = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        for (final m in BlocksMode.values) {
          _bests[m] = p.getInt(m.bestKey) ?? (m == BlocksMode.classic ? p.getInt('blocks_best') ?? 0 : 0);
        }
      });
    });
    if (widget.mode != null) _start(widget.mode!);
  }

  int get _best => _bests[_mode] ?? 0;

  void _start(BlocksMode m) {
    setState(() {
      _mode = m;
      _game = BlocksGame(random: widget.random, mode: m);
      _ended = false;
      _shownScore = 0;
      _armed = null;
      _flash = {};
      _bursts = [];
    });
    Sfx.instance.release();
  }

  void _toMenu() {
    if (_game != null && game.score > 0 && !_ended) {
      Account.instance.recordGame('blocks', won: false, points: game.score ~/ 10);
    }
    setState(() {
      _mode = null;
      _game = null;
    });
  }

  (int, int)? _cellAt(Offset globalTopLeft) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalTopLeft);
    return ((local.dy / _cell).round(), (local.dx / _cell).round());
  }

  void _onMove(int index, Offset topLeft) {
    final at = _cellAt(topLeft);
    final p = game.tray[index];
    final ok = p != null && at != null && game.canPlace(p, at.$1, at.$2);
    final next = ok ? at : null;
    if (next != _hoverAt || _hoverPiece != index) {
      setState(() {
        _hoverPiece = index;
        _hoverAt = next;
      });
    }
  }

  void _drop(int index) {
    final at = _hoverAt;
    setState(() {
      _hoverAt = null;
      _hoverPiece = null;
    });
    if (at == null) return;
    final before = [for (final row in game.board) List.of(row)];
    final pc = game.tray[index]?.color ?? 0;
    final res = game.place(index, at.$1, at.$2);
    if (res == null) return;
    Haptics.selectionClick();
    Sfx.instance.hop(res.placed);
    if (res.lines > 0) {
      _clearFx(res.cleared, {for (final (r, c) in res.cleared) (r, c): before[r][c] >= 0 ? before[r][c] : pc});
      // صوت مسح يعلى مع الكومبو
      final base = 520.0 + min(res.combo, 8) * 60;
      for (var k = 0; k < min(res.lines + 1, 5); k++) {
        Sfx.instance.tone(base * (1 + k * .25), base * (1 + k * .25) * 1.02, .12, type: 'triangle', vol: .13, delay: k * .06);
      }
      Haptics.heavyImpact();
      final praise = res.allClear
          ? 'صفّيت اللوحة! +300'
          : res.lines >= 4
          ? 'أسطوري! 🔥'
          : res.lines == 3
          ? 'ممتاز! ⚡'
          : res.lines == 2
          ? 'رائع! ✨'
          : res.combo >= 2
          ? 'كومبو ×${res.combo}'
          : 'جميل! 👍';
      if (res.allClear || res.lines >= 3) Sfx.instance.bigWin();
      setState(() {
        _praise = praise;
        _praiseKey++;
      });
    } else {
      setState(() {});
    }
    _checkEnd();
  }

  void _clearFx(Set<(int, int)> cells, Map<(int, int), int> colors) {
    final bursts = [for (final (r, c) in cells) _Burst(r, c, colors[(r, c)] ?? 0, _burstId++)];
    setState(() {
      _flash = cells;
      _bursts = bursts;
    });
    Future.delayed(const Duration(milliseconds: 380), () {
      if (mounted) setState(() => _flash = {});
    });
    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted && _bursts == bursts) setState(() => _bursts = []);
    });
  }

  void _usePower(BlockPower p) {
    if ((game.powers[p] ?? 0) <= 0) {
      coinToastLite('ما عندك ${p.title}. اجمع كومبو ×3 أو امسح 3 خطوط مرة وحدة');
      return;
    }
    Sfx.instance.tap();
    if (p == BlockPower.shuffle) {
      setState(game.shuffle);
      Sfx.instance.pickup();
      _checkEnd();
      return;
    }
    setState(() => _armed = _armed == p ? null : p);
  }

  void _tapCell(int r, int c) {
    if (_armed != BlockPower.bomb) return;
    final before = [for (final row in game.board) List.of(row)];
    final hit = game.bomb(r, c);
    setState(() => _armed = null);
    Sfx.instance.capture();
    Haptics.heavyImpact();
    if (hit.isNotEmpty) _clearFx(hit, {for (final (rr, cc) in hit) (rr, cc): before[rr][cc]});
    _checkEnd();
  }

  void _tapPiece(int i) {
    if (_armed == BlockPower.rotate && game.rotate(i)) {
      Sfx.instance.pickup();
      setState(() => _armed = null);
      _checkEnd();
    }
  }

  void coinToastLite(String t) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2), content: Text(t, style: const TextStyle(fontWeight: FontWeight.w800))));

  void _checkEnd() {
    if (game.over) {
      _gameOver();
    } else if (game.stuck) {
      coinToastLite(game.canUndo ? 'ما فيه مكان! استخدم التراجع ↩️' : 'ما فيه مكان! استخدم أداة 💣🔄🔀');
    }
  }

  Future<void> _gameOver() async {
    if (_ended) return;
    _ended = true;
    final mode = _mode!;
    final score = game.score;
    final record = score > _best;
    if (record) {
      _bests[mode] = score;
      (await SharedPreferences.getInstance()).setInt(mode.bestKey, score);
    }
    Account.instance.recordGame('blocks', won: record, points: score ~/ 10);
    Sfx.instance.lose();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        key: const ValueKey('blocks-over'),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4A63B0), Color(0xFF243466)]),
            border: Border.all(color: const Color(0xFFFFC93C), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(record ? '👑 رقم قياسي جديد!' : 'خلصت الحركات', style: AppTheme.display.copyWith(fontSize: 26)),
              const SizedBox(height: 6),
              Text('${mode.icon} ${mode.title}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score.toDouble()),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text('${v.round()}', style: AppTheme.display.copyWith(fontSize: 60, color: Colors.white)),
              ),
              Text('أفضل نتيجة: ${_bests[mode]}', style: const TextStyle(color: Color(0xFFFFC93C), fontWeight: FontWeight.w900)),
              Text('خطوط ممسوحة: ${game.linesTotal}', style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('الأوضاع'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('blocks-again'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFC93C), foregroundColor: const Color(0xFF3A2000)),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('العب مرة ثانية', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
      ),
    );
    if (!mounted) return;
    if (again == true) {
      _start(mode);
    } else {
      setState(() {
        _mode = null;
        _game = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bg1, _bg2]),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _game == null ? _menu() : _play(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu() => Column(
    children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
      ),
      SizedBox(
        height: 120,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          textDirection: TextDirection.ltr,
          children: [
            for (final (i, col) in [0, 1, 3, 4].indexed)
              SizedBox(width: 34, height: 34, child: BlockTile(color: blockPalette[col]))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -10, delay: (i * 150).ms, duration: 600.ms, curve: Curves.easeInOut),
          ],
        ),
      ),
      Text('مكعبات', style: AppTheme.display.copyWith(fontSize: 46)),
      const Text('اختر الوضع', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          children: [
            for (final (i, m) in BlocksMode.values.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  key: ValueKey('blocks-mode-${m.name}'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _start(m),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(colors: [
                        const [Color(0xFF3DBE4B), Color(0xFF1E7A2A)],
                        const [Color(0xFFF2832B), Color(0xFFB0500A)],
                        const [Color(0xFFE5393F), Color(0xFF8A1018)],
                        const [Color(0xFF8E5BE8), Color(0xFF4A1FA0)],
                      ][i]),
                      border: Border.all(color: Colors.white30, width: 1.5),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 5))],
                    ),
                    child: Row(
                      children: [
                        Text(m.icon, style: const TextStyle(fontSize: 38)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.title, style: AppTheme.display.copyWith(fontSize: 24)),
                              Text(m.desc, style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.4)),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            const Text('👑', style: TextStyle(fontSize: 18)),
                            Text('${_bests[m] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFE07A))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: (i * 90).ms).slideX(begin: .2, curve: Curves.easeOutCubic),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _play() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 12, 0),
        child: Row(
          children: [
            IconButton(key: const ValueKey('blocks-menu'), onPressed: _toMenu, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
            const Text('👑', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 4),
            Text('${max(_best, game.score)}', key: const ValueKey('blocks-best'), style: AppTheme.display.copyWith(fontSize: 24, color: const Color(0xFFFFC93C))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(14)),
              child: Text('${_mode!.icon} ${_mode!.title}', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            IconButton(
              key: const ValueKey('blocks-restart'),
              tooltip: 'من جديد',
              onPressed: () {
                if (game.score > 0) Account.instance.recordGame('blocks', won: false, points: game.score ~/ 10);
                _start(_mode!);
              },
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
      SizedBox(
        height: 92,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: _shownScore.toDouble(), end: game.score.toDouble()),
              duration: const Duration(milliseconds: 500),
              onEnd: () => _shownScore = game.score,
              builder: (_, v, _) => Text(
                '${v.round()}',
                style: AppTheme.display.copyWith(fontSize: 62, color: Colors.white, shadows: const [Shadow(color: Colors.black26, offset: Offset(0, 3))]),
              ),
            ),
            // نص مخفي للاختبارات بالقيمة الفعلية
            Opacity(opacity: 0, child: Text('${game.score}', key: const ValueKey('blocks-score'))),
            if (game.combo >= 2)
              PositionedDirectional(
                start: 16,
                child: Container(
                  key: const ValueKey('blocks-combo'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(colors: [Color(0xFFFF7A3D), Color(0xFFE5393F)]),
                    boxShadow: const [BoxShadow(color: Color(0x88FF7A3D), blurRadius: 10)],
                  ),
                  child: Text('🔥 كومبو ×${game.combo}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ).animate(key: ValueKey(game.combo)).scale(duration: 350.ms, curve: Curves.elasticOut),
              ),
            if (_praise != null)
              Positioned(
                bottom: 0,
                child: Text(
                  _praise!,
                  key: ValueKey('praise$_praiseKey'),
                  style: AppTheme.display.copyWith(fontSize: 26, color: const Color(0xFFFFE07A), shadows: const [Shadow(color: Color(0xFFB0500A), offset: Offset(2, 2))]),
                )
                    .animate(key: ValueKey(_praiseKey))
                    .scale(begin: const Offset(.3, .3), duration: 400.ms, curve: Curves.elasticOut)
                    .then(delay: 500.ms)
                    .moveY(end: -20, duration: 400.ms)
                    .fadeOut(duration: 400.ms),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: AspectRatio(aspectRatio: 1, child: _board()),
      ),
      _toolsBar(),
      Expanded(child: _tray()),
    ],
  );

  Widget _toolsBar() {
    if (_mode == BlocksMode.easy) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextButton.icon(
          key: const ValueKey('blocks-undo'),
          onPressed: game.canUndo
              ? () {
                  setState(game.undo);
                  Sfx.instance.release();
                }
              : null,
          icon: const Icon(Icons.undo_rounded, color: Colors.white),
          label: Text('تراجع (${game.undos})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
      );
    }
    if (_mode != BlocksMode.pro) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          for (final p in BlockPower.values)
            Expanded(
              child: GestureDetector(
                key: ValueKey('blocks-power-${p.name}'),
                onTap: () => _usePower(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _armed == p ? const Color(0xFFFFC93C).withValues(alpha: .35) : Colors.black26,
                    border: Border.all(color: _armed == p ? const Color(0xFFFFC93C) : Colors.white24, width: _armed == p ? 2 : 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(p.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 4),
                      Text('${p.title} ${game.powers[p] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _board() => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFF2A3766),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _armed == BlockPower.bomb ? const Color(0xFFFF5A5A) : const Color(0xFF34457F), width: 2),
      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 6))],
    ),
    child: LayoutBuilder(
      builder: (context, c) {
        _cell = c.maxWidth / game.size;
        final p = _hoverPiece == null ? null : game.tray[_hoverPiece!];
        final ghost = <(int, int)>{};
        var willClear = <(int, int)>{};
        if (p != null && _hoverAt != null) {
          for (final (r, cc) in p.cells) {
            ghost.add((_hoverAt!.$1 + r, _hoverAt!.$2 + cc));
          }
          final (rows, cols, boxes) = game.linesIf(p, _hoverAt!.$1, _hoverAt!.$2);
          willClear = game.cellsOf(rows, cols, boxes);
        }
        return DragTarget<int>(
          onWillAcceptWithDetails: (_) => true,
          onMove: (d) => _onMove(d.data, d.offset),
          onLeave: (_) => setState(() => _hoverAt = null),
          onAcceptWithDetails: (d) => _drop(d.data),
          builder: (context, _, _) => Container(
            key: _boardKey,
            color: _boardBg,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var r = 0; r < game.size; r++)
                  for (var col = 0; col < game.size; col++)
                    Positioned(
                      left: col * _cell,
                      top: r * _cell,
                      width: _cell,
                      height: _cell,
                      child: GestureDetector(
                        key: ValueKey('blocks-cell-$r-$col'),
                        onTap: () => _tapCell(r, col),
                        child: _cellView(r, col, ghost, p, willClear.contains((r, col))),
                      ),
                    ),
                for (final b in _bursts) ..._burst(b),
              ],
            ),
          ),
        );
      },
    ),
  );

  /// شظايا صغيرة تطير من المربع الممسوح.
  List<Widget> _burst(_Burst b) {
    final rnd = Random(b.id);
    final s = _cell * .28;
    return [
      for (var k = 0; k < 3; k++)
        Positioned(
          left: b.c * _cell + _cell / 2 - s / 2,
          top: b.r * _cell + _cell / 2 - s / 2,
          width: s,
          height: s,
          child: IgnorePointer(
            child: BlockTile(color: blockPalette[b.color])
                .animate()
                .move(
                  end: Offset((rnd.nextDouble() - .5) * _cell * 2.4, (rnd.nextDouble() - .9) * _cell * 2.2),
                  duration: 650.ms,
                  curve: Curves.easeOutCubic,
                )
                .rotate(end: rnd.nextDouble() - .5, duration: 650.ms)
                .fadeOut(delay: 250.ms, duration: 400.ms),
          ),
        ),
    ];
  }

  Widget _cellView(int r, int c, Set<(int, int)> ghost, BlockPiece? p, bool willClear) {
    final v = game.board[r][c];
    final shade = game.hasBoxes && ((r ~/ 3) + (c ~/ 3)).isOdd;
    Widget child;
    if (_flash.contains((r, c))) {
      child = Container(color: Colors.white)
          .animate()
          .fadeOut(duration: 350.ms);
    } else if (v >= 0) {
      child = BlockTile(color: willClear && p != null ? blockPalette[p.color] : blockPalette[v]);
      if (willClear) child = child.animate(onPlay: (ctl) => ctl.repeat(reverse: true)).fade(begin: 1, end: .7, duration: 300.ms);
    } else if (ghost.contains((r, c)) && p != null) {
      child = BlockTile(color: blockPalette[p.color], ghost: !willClear);
    } else {
      child = Container(
        decoration: BoxDecoration(
          color: shade ? const Color(0xFF26315A) : null,
          border: Border.all(color: const Color(0xFF283357), width: .8),
        ),
      );
    }
    return Padding(padding: const EdgeInsets.all(.5), child: child);
  }

  Widget _tray() => Row(
    textDirection: TextDirection.ltr,
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      for (var i = 0; i < 3; i++) Expanded(child: Center(child: _trayPiece(i))),
    ],
  );

  Widget _pieceView(BlockPiece p, double cell, {bool dim = false}) => Opacity(
    opacity: dim ? .35 : 1,
    child: SizedBox(
      width: p.cols * cell,
      height: p.rows * cell,
      child: Stack(
        children: [
          for (final (r, c) in p.cells)
            Positioned(left: c * cell, top: r * cell, width: cell, height: cell, child: BlockTile(color: blockPalette[p.color])),
        ],
      ),
    ),
  );

  Widget _trayPiece(int i) {
    final p = game.tray[i];
    if (p == null) return const SizedBox(width: 60, height: 60);
    final small = min(26.0, 110 / max(p.rows, p.cols));
    final fits = game.fitsAnywhere(p);
    final w = p.cols * _cell, h = p.rows * _cell;
    final view = Container(
      padding: const EdgeInsets.all(12),
      color: Colors.transparent,
      child: Directionality(textDirection: TextDirection.ltr, child: _pieceView(p, small, dim: !fits)),
    );
    if (_armed == BlockPower.rotate) {
      return GestureDetector(
        key: ValueKey('blocks-piece-$i'),
        onTap: () => _tapPiece(i),
        child: view.animate(onPlay: (c) => c.repeat(reverse: true)).rotate(begin: -.02, end: .02, duration: 300.ms),
      );
    }
    return Draggable<int>(
      key: ValueKey('blocks-piece-$i'),
      data: i,
      maxSimultaneousDrags: fits ? 1 : 0,
      dragAnchorStrategy: (d, ctx, pos) => Offset(w / 2, h + 50),
      feedback: Directionality(textDirection: TextDirection.ltr, child: _pieceView(p, _cell)),
      childWhenDragging: Opacity(opacity: 0, child: view),
      onDragStarted: () => Sfx.instance.tick(),
      onDragEnd: (_) {
        if (_hoverPiece == i) setState(() => _hoverPiece = null);
      },
      child: view.animate(key: ValueKey(p)).scale(begin: const Offset(.5, .5), duration: 300.ms, curve: Curves.easeOutBack),
    );
  }
}
