import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ludo_engine.dart';
import '../../core/shop.dart';

/// ألوان لودو على اللوح.
const ludoColors = {
  LudoColor.red: Color(0xFFF2453D),
  LudoColor.green: Color(0xFF2EBD59),
  LudoColor.yellow: Color(0xFFFFC21A),
  LudoColor.blue: Color(0xFF2F8BF5),
};

const ludoNames = {
  LudoColor.red: 'الأحمر',
  LudoColor.green: 'الأخضر',
  LudoColor.yellow: 'الأصفر',
  LudoColor.blue: 'الأزرق',
};

/// هندسة اللوح: شبكة 15×15، ومواقع الخانات بوحدات الخانة (مركز الخانة).
class LudoLayout {
  static const grid = 15;

  /// المسار الرئيسي (52 خانة) بالترتيب، كل عنصر (عمود، صف).
  static final List<(int, int)> track = () {
    final t = <(int, int)>[];
    for (var x = 0; x <= 5; x++) {
      t.add((x, 6));
    }
    for (var y = 5; y >= 0; y--) {
      t.add((6, y));
    }
    t.add((7, 0));
    for (var y = 0; y <= 5; y++) {
      t.add((8, y));
    }
    for (var x = 9; x <= 14; x++) {
      t.add((x, 6));
    }
    t.add((14, 7));
    for (var x = 14; x >= 9; x--) {
      t.add((x, 8));
    }
    for (var y = 9; y <= 14; y++) {
      t.add((8, y));
    }
    t.add((7, 14));
    for (var y = 14; y >= 9; y--) {
      t.add((6, y));
    }
    for (var x = 5; x >= 0; x--) {
      t.add((x, 8));
    }
    t.add((0, 7));
    assert(t.length == 52);
    return t;
  }();

  /// ممر البيت لكل لون (5 خانات من الخارج للداخل).
  static List<(int, int)> homeColumn(LudoColor c) => switch (c) {
        LudoColor.green => [for (var x = 1; x <= 5; x++) (x, 7)],
        LudoColor.yellow => [for (var y = 1; y <= 5; y++) (7, y)],
        LudoColor.blue => [for (var x = 13; x >= 9; x--) (x, 7)],
        LudoColor.red => [for (var y = 13; y >= 9; y--) (7, y)],
      };

  /// الزاوية العلوية اليسرى لساحة كل لون.
  static (int, int) yardOrigin(LudoColor c) => switch (c) {
        LudoColor.green => (0, 0),
        LudoColor.yellow => (9, 0),
        LudoColor.blue => (9, 9),
        LudoColor.red => (0, 9),
      };

  /// اتجاه مثلث البيت في الوسط لكل لون.
  static Offset finishSpot(LudoColor c) => switch (c) {
        LudoColor.green => const Offset(6.55, 7.5),
        LudoColor.yellow => const Offset(7.5, 6.55),
        LudoColor.blue => const Offset(8.45, 7.5),
        LudoColor.red => const Offset(7.5, 8.45),
      };

  static Offset cellCenter((int, int) c) => Offset(c.$1 + .5, c.$2 + .5);

  /// مركز القطعة بوحدات الخانة.
  static Offset tokenCenter(LudoColor c, int tokenId, int pos) {
    if (pos == LudoGeo.yard) {
      final (ox, oy) = yardOrigin(c);
      const slots = [Offset(2, 2), Offset(4, 2), Offset(2, 4), Offset(4, 4)];
      return Offset(ox.toDouble(), oy.toDouble()) + slots[tokenId % 4];
    }
    if (pos == LudoGeo.finished) return finishSpot(c);
    if (pos > LudoGeo.lastTrack) return cellCenter(homeColumn(c)[pos - LudoGeo.lastTrack - 1]);
    return cellCenter(track[LudoGeo.globalIndex(c, pos)!]);
  }
}

/// إطار اللوح: تدرج لوني، أو الرسمة كاملة بإطارها المزخرف للألواح المرسومة.
class BoardSurface extends StatelessWidget {
  const BoardSurface({super.key, required this.theme, required this.size, required this.child, this.shadow = true});
  final String theme;
  final double size;
  final Widget child;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final th = boardThemes[theme] ?? boardThemes['classic']!;
    final art = th.art;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * (art != null ? .075 : .025)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .05),
        gradient: art == null ? LinearGradient(colors: th.frame) : null,
        image: art == null
            ? null
            : DecorationImage(image: AssetImage('assets/images/$art.webp'), fit: BoxFit.cover),
        boxShadow: shadow ? const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 12))] : null,
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(size * .02), child: child),
    );
  }
}

/// يرسم اللوح الثابت: الساحات والمسار والنجوم والوسط.
class LudoBoardPainter extends CustomPainter {
  LudoBoardPainter({required this.active, this.theme = 'classic', this.power = false});
  final Set<LudoColor> active;
  final String theme;

  /// يرسم خانات الرمية الإضافية لوضع الباور.
  final bool power;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / LudoLayout.grid;
    Rect cell((int, int) c) => Rect.fromLTWH(c.$1 * s, c.$2 * s, s, s);

    final th = boardThemes[theme] ?? boardThemes['classic']!;
    // الألواح المرسومة: الخلفية تبان من تحت، والخانات شبه شفافة
    final art = th.art != null;
    if (!art) canvas.drawRect(Offset.zero & size, Paint()..color = th.cell);
    if (art) {
      final glass = Paint()..color = th.cell.withValues(alpha: .8);
      for (final c in LudoLayout.track) {
        canvas.drawRect(cell(c), glass);
      }
    }

    // خانات المسار
    final line = Paint()
      ..color = th.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .04;
    for (final c in LudoLayout.track) {
      canvas.drawRect(cell(c), line);
    }

    for (final color in LudoColor.values) {
      final base = ludoColors[color]!;
      final dim0 = active.contains(color) ? base : Color.lerp(base, th.cell, .55)!;
      final dim1 = Color.lerp(dim0, Colors.black, th.yardTint)!;
      final dim = art ? dim1.withValues(alpha: .9) : dim1;

      // ممر البيت وخانة البداية
      for (final c in LudoLayout.homeColumn(color)) {
        canvas.drawRect(cell(c), Paint()..color = dim);
        canvas.drawRect(cell(c), line);
      }
      final start = LudoLayout.track[LudoGeo.startIndex[color]!];
      canvas.drawRect(cell(start), Paint()..color = dim);
      _arrow(canvas, cell(start), color, s);

      // الساحة
      final (ox, oy) = LudoLayout.yardOrigin(color);
      final yard = Rect.fromLTWH(ox * s, oy * s, 6 * s, 6 * s);
      final inner = RRect.fromRectAndRadius(yard.deflate(s * .9), Radius.circular(s * 1.2));
      if (art) {
        // الرسمة تبان في الساحة، مع إطار بلون اللاعب وصبغة خفيفة
        final ry = RRect.fromRectAndRadius(yard.deflate(s * .12), Radius.circular(s * .8));
        canvas.drawRRect(ry, Paint()..color = dim1.withValues(alpha: .22));
        canvas.drawRRect(
          ry,
          Paint()
            ..color = dim1
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * .28,
        );
        canvas.drawRRect(inner, Paint()..color = Colors.black.withValues(alpha: .28));
      } else {
        canvas.drawRect(yard, Paint()..color = dim);
        canvas.drawRRect(inner, Paint()..color = Colors.white.withValues(alpha: .25));
      }
      canvas.drawRRect(
        inner,
        Paint()
          ..color = Colors.black.withValues(alpha: .08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .08,
      );
      for (var i = 0; i < 4; i++) {
        final ctr = LudoLayout.tokenCenter(color, i, LudoGeo.yard) * s;
        canvas.drawCircle(ctr, s * .62, Paint()..color = Colors.black.withValues(alpha: .12));
        canvas.drawCircle(ctr, s * .55, Paint()..color = art ? dim1.withValues(alpha: .55) : Colors.white.withValues(alpha: .35));
        if (art) {
          canvas.drawCircle(
            ctr,
            s * .55,
            Paint()
              ..color = Colors.white.withValues(alpha: .7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * .06,
          );
        }
      }
    }

    // خانات الرمية الإضافية (+1)
    if (power) {
      for (final g in LudoGeo.bonusIndices) {
        final r = cell(LudoLayout.track[g]).deflate(s * .06);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(s * .18)),
          Paint()..shader = const LinearGradient(colors: [Color(0xFFFFE27A), Color(0xFFE09B12)]).createShader(r),
        );
        final tp = TextPainter(
          text: TextSpan(text: '+1', style: TextStyle(color: const Color(0xFF6B3A00), fontSize: s * .5, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // النجوم على الخانات الآمنة
    for (final g in LudoGeo.safeIndices) {
      if (LudoGeo.startIndex.containsValue(g)) continue;
      final r = cell(LudoLayout.track[g]);
      canvas.drawRect(r, Paint()..color = Color.lerp(th.cell, const Color(0xFF9AA1AE), .18)!.withValues(alpha: art ? .85 : 1));
      canvas.drawRect(r, line);
      _star(canvas, r.center, s * .34, Paint()..color = const Color(0xFF9AA1AE));
    }

    // الوسط: أربعة مثلثات
    final c0 = Offset(6 * s, 6 * s), c1 = Offset(9 * s, 6 * s), c2 = Offset(9 * s, 9 * s), c3 = Offset(6 * s, 9 * s);
    final mid = Offset(7.5 * s, 7.5 * s);
    void tri(Offset a, Offset b, LudoColor col) {
      final base = ludoColors[col]!;
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(mid.dx, mid.dy)
          ..close(),
        Paint()..color = active.contains(col) ? base : Color.lerp(base, Colors.white, .55)!,
      );
    }

    tri(c0, c1, LudoColor.yellow);
    tri(c1, c2, LudoColor.blue);
    tri(c2, c3, LudoColor.red);
    tri(c3, c0, LudoColor.green);
    final w = Paint()
      ..color = Colors.white.withValues(alpha: .7)
      ..strokeWidth = s * .05;
    canvas.drawLine(c0, c2, w);
    canvas.drawLine(c1, c3, w);
  }

  void _arrow(Canvas canvas, Rect r, LudoColor c, double s) {
    final angle = switch (c) {
      LudoColor.green => 0.0,
      LudoColor.yellow => math.pi / 2,
      LudoColor.blue => math.pi,
      LudoColor.red => -math.pi / 2,
    };
    canvas.save();
    canvas.translate(r.center.dx, r.center.dy);
    canvas.rotate(angle);
    final p = Path()
      ..moveTo(s * .28, 0)
      ..lineTo(-s * .18, -s * .25)
      ..lineTo(-s * .18, s * .25)
      ..close();
    canvas.drawPath(p, Paint()..color = Colors.white.withValues(alpha: .9));
    canvas.restore();
  }

  void _star(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * .45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = c + Offset(math.cos(a) * rad, math.sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), p);
  }

  @override
  bool shouldRepaint(covariant LudoBoardPainter old) => old.active.length != active.length;
}

/// قطعة اللاعب.
class LudoPawn extends StatelessWidget {
  const LudoPawn({super.key, required this.color, required this.size, this.highlight = false});
  final LudoColor color;
  final double size;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = ludoColors[color]!;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // ظل القاعدة وهالة التمييز
          Positioned(
            bottom: 0,
            child: Container(
              width: size * .8,
              height: size * .28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(size * .4, size * .14)),
                color: highlight ? Colors.white : Colors.black.withValues(alpha: .35),
                boxShadow: [
                  if (highlight) BoxShadow(color: Colors.white, blurRadius: size * .4, spreadRadius: size * .1),
                ],
              ),
            ),
          ),
          Positioned(
            left: -size * .2,
            right: -size * .2,
            top: -size * .45,
            bottom: size * .02,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/pawn_${color.name}.webp',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => _PawnDisc(color: c, size: size),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PawnDisc extends StatelessWidget {
  const _PawnDisc({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-.3, -.4),
            colors: [Color.lerp(color, Colors.white, .45)!, color, Color.lerp(color, Colors.black, .3)!],
            stops: const [0, .55, 1],
          ),
          border: Border.all(color: Colors.white, width: size * .1),
        ),
      );
}

/// وجه نرد بالنقاط.
class DiceFace extends StatelessWidget {
  const DiceFace({super.key, required this.value, required this.size, this.color = const Color(0xFF1A1033), this.skin = 'classic'});
  final String skin;
  final int value;
  final double size;
  final Color color;

  static const _pips = {
    1: [Offset(.5, .5)],
    2: [Offset(.25, .25), Offset(.75, .75)],
    3: [Offset(.25, .25), Offset(.5, .5), Offset(.75, .75)],
    4: [Offset(.25, .25), Offset(.75, .25), Offset(.25, .75), Offset(.75, .75)],
    5: [Offset(.25, .25), Offset(.75, .25), Offset(.5, .5), Offset(.25, .75), Offset(.75, .75)],
    6: [Offset(.25, .22), Offset(.75, .22), Offset(.25, .5), Offset(.75, .5), Offset(.25, .78), Offset(.75, .78)],
  };

  @override
  Widget build(BuildContext context) {
    final d = size * .18;
    final sk = diceSkins[skin] ?? diceSkins['classic']!;
    final pip = skin == 'classic' ? color : sk.pip;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: sk.faces,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: size * .15, offset: Offset(0, size * .08)),
          if (sk.glow != null) BoxShadow(color: sk.glow!.withValues(alpha: .55), blurRadius: size * .3),
        ],
      ),
      child: Stack(
        children: [
          for (final p in _pips[value.clamp(1, 6)]!)
            Positioned(
              left: p.dx * size - d / 2,
              top: p.dy * size - d / 2,
              child: Container(
                width: d,
                height: d,
                decoration: BoxDecoration(color: value == 1 && skin == 'classic' ? const Color(0xFFE63946) : pip, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

/// صورة النرد ثلاثية الأبعاد للسكن (للمتجر والحقيبة وأثناء الرمي).
class DiceArt extends StatelessWidget {
  const DiceArt({super.key, this.skin = 'classic', required this.size});
  final String skin;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          'assets/images/dice_$skin.webp',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => DiceFace(value: 6, size: size * .8, skin: skin),
        ),
      );
}

/// أيقونة أداة الباور المرسومة.
class ItemArt extends StatelessWidget {
  const ItemArt({super.key, required this.item, required this.size});
  final LudoItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (_, _, icon, color) = itemInfo[item]!;
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/item_${item.name}.webp',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Icon(icon, color: Colors.white, size: size * .55),
        ),
      ),
    );
  }
}
