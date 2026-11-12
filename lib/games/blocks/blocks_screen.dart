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
  const BlocksScreen({super.key, this.random});
  final Random? random;

  @override
  State<BlocksScreen> createState() => _BlocksScreenState();
}

class _BlocksScreenState extends State<BlocksScreen> {
  static const _bestPref = 'blocks_best';
  static const _bg = Color(0xFF3A5091);
  static const _boardBg = Color(0xFF1E2747);

  late BlocksGame game = BlocksGame(random: widget.random);
  int _best = 0;
  final _boardKey = GlobalKey();
  double _cell = 40;

  /// معاينة: القطعة والموقع.
  int? _hoverPiece;
  (int, int)? _hoverAt;
  Set<(int, int)> _flash = {};
  String? _praise;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _best = p.getInt(_bestPref) ?? 0);
    });
  }

  (int, int)? _cellAt(Offset globalTopLeft) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalTopLeft);
    // نقرّب لأقرب خانة من الزاوية العلوية اليسرى للقطعة
    final c = (local.dx / _cell).round();
    final r = (local.dy / _cell).round();
    return (r, c);
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
    Sfx.instance.tap();
    if (res.lines > 0) {
      final cleared = <(int, int)>{
        for (final r in res.rows)
          for (var c = 0; c < game.size; c++) (r, c),
        for (final c in res.cols)
          for (var r = 0; r < game.size; r++) (r, c),
      };
      Sfx.instance.win();
      Haptics.heavyImpact();
      setState(() {
        _flash = cleared;
        _praise = res.lines >= 3 ? 'رهيب! 🔥' : (res.lines == 2 ? 'ممتاز! ✨' : (game.streak > 1 ? 'سلسلة ×${game.streak}' : 'حلو! 👍'));
        _flashColors = {for (final (r, c) in cleared) (r, c): before[r][c] >= 0 ? before[r][c] : pc};
      });
      Future.delayed(const Duration(milliseconds: 380), () {
        if (mounted) setState(() => _flash = {});
      });
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _praise = null);
      });
    } else {
      setState(() {});
    }
    if (game.over) _gameOver();
  }

  Map<(int, int), int> _flashColors = {};

  Future<void> _gameOver() async {
    if (_ended) return;
    _ended = true;
    final score = game.score;
    final record = score > _best;
    if (record) {
      _best = score;
      (await SharedPreferences.getInstance()).setInt(_bestPref, score);
    }
    Account.instance.recordGame('blocks', won: record, points: score ~/ 10);
    Sfx.instance.lose();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('blocks-over'),
        backgroundColor: AppColors.surface,
        title: Text(record ? '👑 رقم قياسي جديد!' : 'خلصت الحركات', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$score', style: AppTheme.display.copyWith(fontSize: 54)),
            Text('أفضل نتيجة: $_best', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); Navigator.maybePop(context); }, child: const Text('خروج')),
          FilledButton(
            key: const ValueKey('blocks-again'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('العب مرة ثانية'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      game = BlocksGame(random: widget.random);
      _ended = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                      const Text('👑', style: TextStyle(fontSize: 26)),
                      const SizedBox(width: 6),
                      Text('${max(_best, game.score)}', key: const ValueKey('blocks-best'), style: AppTheme.display.copyWith(fontSize: 28, color: const Color(0xFFFFC93C))),
                      const Spacer(),
                      IconButton(
                        key: const ValueKey('blocks-restart'),
                        tooltip: 'من جديد',
                        onPressed: () => setState(() {
                          if (game.score > 0) Account.instance.recordGame('blocks', won: false, points: game.score ~/ 10);
                          game = BlocksGame(random: widget.random);
                        }),
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 30),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text('${game.score}', key: const ValueKey('blocks-score'), style: AppTheme.display.copyWith(fontSize: 64, color: Colors.white)),
                      if (_praise != null)
                        Positioned(
                          bottom: 0,
                          child: Text(_praise!, style: AppTheme.display.copyWith(fontSize: 22, color: const Color(0xFFFFE07A)))
                              .animate()
                              .scale(duration: 300.ms, curve: Curves.elasticOut)
                              .fadeOut(delay: 700.ms),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AspectRatio(aspectRatio: 1, child: _board()),
                ),
                Expanded(child: _tray()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _board() => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFF2A3766),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4))],
    ),
    child: LayoutBuilder(
      builder: (context, c) {
        _cell = c.maxWidth / game.size;
        final p = _hoverPiece == null ? null : game.tray[_hoverPiece!];
        final ghost = <(int, int)>{};
        var clearRows = <int>[], clearCols = <int>[];
        if (p != null && _hoverAt != null) {
          for (final (r, cc) in p.cells) {
            ghost.add((_hoverAt!.$1 + r, _hoverAt!.$2 + cc));
          }
          (clearRows, clearCols) = game.linesIf(p, _hoverAt!.$1, _hoverAt!.$2);
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
              children: [
                for (var r = 0; r < game.size; r++)
                  for (var col = 0; col < game.size; col++)
                    Positioned(
                      left: col * _cell,
                      top: r * _cell,
                      width: _cell,
                      height: _cell,
                      child: _cellView(r, col, ghost, p, clearRows.contains(r) || clearCols.contains(col)),
                    ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _cellView(int r, int c, Set<(int, int)> ghost, BlockPiece? p, bool willClear) {
    final v = game.board[r][c];
    Widget child;
    if (_flash.contains((r, c))) {
      child = BlockTile(color: blockPalette[_flashColors[(r, c)] ?? 0])
          .animate()
          .scaleXY(end: .2, duration: 350.ms, curve: Curves.easeIn)
          .fadeOut(duration: 350.ms);
    } else if (v >= 0) {
      // الخلايا اللي بتنمسح تاخذ لون القطعة كمعاينة
      child = BlockTile(color: willClear && p != null ? blockPalette[p.color] : blockPalette[v]);
    } else if (ghost.contains((r, c)) && p != null) {
      child = BlockTile(color: blockPalette[p.color], ghost: true);
    } else {
      child = Container(
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF283357), width: .8)),
      );
    }
    return Padding(padding: const EdgeInsets.all(.5), child: child);
  }

  Widget _tray() => Row(
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
    const small = 22.0;
    final fits = game.fitsAnywhere(p);
    final w = p.cols * _cell, h = p.rows * _cell;
    return Draggable<int>(
      key: ValueKey('blocks-piece-$i'),
      data: i,
      maxSimultaneousDrags: fits ? 1 : 0,
      // القطعة تطلع فوق الإصبع عشان تشوف مكانها
      dragAnchorStrategy: (d, ctx, pos) => Offset(w / 2, h + 50),
      feedback: Directionality(textDirection: TextDirection.ltr, child: _pieceView(p, _cell)),
      childWhenDragging: _pieceView(p, small, dim: true),
      onDragEnd: (_) {
        if (_hoverPiece == i) setState(() => _hoverPiece = null);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.transparent,
        child: Directionality(textDirection: TextDirection.ltr, child: _pieceView(p, small, dim: !fits)),
      ),
    );
  }
}
