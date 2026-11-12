import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/shop.dart';
import 'voice_widgets.dart';

/// شكل الجزيئات اللي تطلع ورا الدخولية.
enum EntryParticle { sparkle, circle, heart }

class EntryStyle {
  const EntryStyle(this.shape, this.colors, {this.rise = 0, this.size = 1});
  final EntryParticle shape;
  final List<Color> colors;

  /// اتجاه الجزيئات عمودياً: موجب = تطلع لفوق (نار/دخان)، سالب = تنزل (غبار).
  final double rise;
  final double size;
}

const _gold = [Color(0xFFFFF2A8), Color(0xFFFFC93D), Color(0xFFFF9F1C)];

const entryStyles = <String, EntryStyle>{
  'scooter': EntryStyle(EntryParticle.heart, [Color(0xFFFF7AB6), Color(0xFFFF4D6D), Color(0xFFFFC2DD)], rise: .6),
  'car': EntryStyle(EntryParticle.sparkle, _gold),
  'carpet': EntryStyle(EntryParticle.sparkle, [Color(0xFFC9A7FF), Color(0xFFFFD66B), Color(0xFF8E6CFF)], rise: .3),
  'horse': EntryStyle(EntryParticle.circle, [Color(0xFFE8C9A0), Color(0xFFC79A6B), Color(0xFFFFE6C2)], rise: -.4, size: 1.3),
  'yacht': EntryStyle(EntryParticle.circle, [Color(0xFFBFF4FF), Color(0xFF5BC8FF), Colors.white], rise: .5),
  'rocket': EntryStyle(EntryParticle.circle, [Color(0xFFFFE27A), Color(0xFFFF8A3D), Color(0xFFFF3D3D)], rise: .2, size: 1.4),
  'dragon': EntryStyle(EntryParticle.circle, [Color(0xFFFFE27A), Color(0xFFFF6A2B), Color(0xFFD6001C)], rise: .9, size: 1.5),
  'lion': EntryStyle(EntryParticle.sparkle, _gold, rise: .2),
  'jet': EntryStyle(EntryParticle.sparkle, [Colors.white, Color(0xFF9DE1FF), Color(0xFFFFE27A)]),
  'falcon': EntryStyle(EntryParticle.sparkle, [Color(0xFFFFE27A), Color(0xFFFFB800), Colors.white], rise: .3),
  'supercar': EntryStyle(EntryParticle.circle, [Color(0xFFFFD66B), Color(0xFFFF4D3D), Color(0xFFFF9F1C)], size: 1.1),
  'unicorn': EntryStyle(EntryParticle.sparkle, [Color(0xFFFF6B8B), Color(0xFFFFD66B), Color(0xFF6BE58B), Color(0xFF6BC8FF), Color(0xFFB86CFF)], rise: .4),
  'ufo': EntryStyle(EntryParticle.sparkle, [Color(0xFF7CF5FF), Color(0xFFB86CFF), Colors.white], rise: -.2),
  'lamp': EntryStyle(EntryParticle.circle, [Color(0xFFC9A7FF), Color(0xFF8E6CFF), Color(0xFFE6D6FF)], rise: .7, size: 1.8),
  'carriage': EntryStyle(EntryParticle.sparkle, [Color(0xFFFFF2A8), Color(0xFFFFC93D), Color(0xFFFF7AB6)], rise: .2),
};

EntryStyle entryStyleFor(String name) => entryStyles[name] ?? const EntryStyle(EntryParticle.sparkle, _gold);

/// حالة المركبة في لحظة t (0..1) من عمر الدخولية.
class EntryPose {
  const EntryPose(this.dx, this.dy, this.scale, this.rotY, this.opacity, this.moving);
  final double dx, dy, scale, rotY, opacity;
  final bool moving;
}

const _inEnd = .28, _outStart = .72;

/// مسار المركبة: تجي من العمق يسار، تحوم وتلف في المنتصف، وتطلع يمين باتجاه الكاميرا.
EntryPose entryPose(double t, double w) {
  double lerp(double a, double b, double x) => a + (b - a) * x;
  if (t < _inEnd) {
    final p = Curves.easeOutCubic.transform(t / _inEnd);
    return EntryPose(lerp(-.75 * w, 0, p), lerp(-70, 0, p), lerp(.3, 1, p), lerp(1.1, 0, p), (t / .08).clamp(0, 1), true);
  }
  if (t < _outStart) {
    final q = (t - _inEnd) / (_outStart - _inEnd);
    return EntryPose(
      0,
      math.sin(q * math.pi * 3) * 7,
      1 + .04 * math.sin(q * math.pi * 4),
      math.sin(q * math.pi * 2) * .32,
      1,
      false,
    );
  }
  final e = Curves.easeInCubic.transform((t - _outStart) / (1 - _outStart));
  return EntryPose(lerp(0, .9 * w, e), lerp(0, 20, e), lerp(1, 1.6, e), lerp(0, -.6, e), e < .6 ? 1 : 1 - (e - .6) / .4, true);
}

/// دخولية ثلاثية الأبعاد: منظور وعمق، دوران، لمعة ضوء، ظل، أشعة للدخوليات الغالية، وجزيئات حسب نوعها.
class Entrance3D extends StatefulWidget {
  const Entrance3D(this.name, {super.key, this.size = 170, this.duration = const Duration(milliseconds: 3400)});
  final String name;
  final double size;
  final Duration duration;

  @override
  State<Entrance3D> createState() => _Entrance3DState();
}

class _Entrance3DState extends State<Entrance3D> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _premium {
    try {
      return shopItem('entrance.${widget.name}').price >= 8000;
    } catch (_) {
      return false;
    }
  }

  Widget _vehicle(EntryPose p, {double alpha = 1, double? shine}) {
    Widget img = artImage(entranceArt(widget.name), widget.size);
    if (shine != null) {
      img = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Colors.transparent, Color(0x99FFFFFF), Colors.transparent],
          stops: [(shine - .12).clamp(0, 1), shine.clamp(0, 1), (shine + .12).clamp(0, 1)],
        ).createShader(r),
        child: img,
      );
    }
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .0018)
        ..translateByDouble(p.dx, p.dy, 0, 1)
        ..rotateY(p.rotY)
        ..scaleByDouble(p.scale, p.scale, 1, 1),
      child: Opacity(opacity: (p.opacity * alpha).clamp(0, 1), child: img),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = entryStyleFor(widget.name);
    final premium = _premium;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final p = entryPose(t, w);
          // اللمعة تعبر مرتين وقت الوقوف
          double? shine;
          if (t > .3 && t < .7) shine = (((t - .3) / .2) % 1) * 1.4 - .2;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _EntryFxPainter(t: t, w: w, size: widget.size, style: style, premium: premium),
                ),
              ),
              // ظل/أثر حركة خلف المركبة
              if (p.moving)
                for (var k = 3; k >= 1; k--) _vehicle(entryPose((t - .018 * k).clamp(0, 1), w), alpha: .22 / k),
              _vehicle(p, shine: shine),
            ],
          );
        },
      );
    });
  }
}

class _EntryFxPainter extends CustomPainter {
  _EntryFxPainter({required this.t, required this.w, required this.size, required this.style, required this.premium});
  final double t, w, size;
  final EntryStyle style;
  final bool premium;

  static const _n = 80;

  @override
  void paint(Canvas canvas, Size box) {
    final c = box.center(Offset.zero);
    final p = entryPose(t, w);
    final main = style.colors[style.colors.length > 1 ? 1 : 0];

    // أشعة ضوء تدور خلف الدخوليات الغالية
    if (premium && t > .2 && t < .85) {
      final a = (math.min((t - .2) / .1, (.85 - t) / .1)).clamp(0.0, 1.0);
      final r = size * 1.25;
      final paint = Paint()
        ..shader = RadialGradient(colors: [main.withValues(alpha: .55 * a), main.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: r));
      for (var i = 0; i < 12; i++) {
        final ang = i * math.pi / 6 + t * 2.4;
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + r * math.cos(ang - .1), c.dy + r * math.sin(ang - .1))
          ..lineTo(c.dx + r * math.cos(ang + .1), c.dy + r * math.sin(ang + .1))
          ..close();
        canvas.drawPath(path, paint);
      }
    }

    // ظل على الأرض تحت المركبة
    final shadowC = c + Offset(p.dx, size * .5 + 4);
    canvas.drawOval(
      Rect.fromCenter(center: shadowC, width: size * .9 * p.scale, height: size * .14 * p.scale),
      Paint()
        ..color = Colors.black.withValues(alpha: .35 * p.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // موجة عند الوصول
    if (t > _inEnd - .02 && t < _inEnd + .16) {
      final k = (t - (_inEnd - .02)) / .18;
      canvas.drawOval(
        Rect.fromCenter(center: shadowC, width: size * (.6 + 1.6 * k), height: size * (.12 + .3 * k)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - k) + 1
          ..color = main.withValues(alpha: (1 - k) * .9),
      );
    }

    // جزيئات: كل وحدة تولد خلف المركبة في وقتها وتعيش فترة قصيرة
    for (var i = 0; i < _n; i++) {
      final rnd = math.Random(i * 7919 + 13);
      final born = .02 + (i / _n) * .9;
      const life = .2;
      final age = (t - born) / life;
      if (age < 0 || age > 1) continue;
      final at = entryPose(born, w);
      final back = at.moving ? -size * .4 * at.scale : (rnd.nextDouble() - .5) * size * .9;
      final start = c + Offset(at.dx + back, at.dy + (rnd.nextDouble() - .5) * size * .45);
      final vx = (at.moving ? -1 : 1) * (20 + rnd.nextDouble() * 70) * (at.moving ? 1 : (rnd.nextBool() ? 1 : -1));
      final vy = -(style.rise * 70) + (rnd.nextDouble() - .5) * 50;
      final pos = start + Offset(vx * age, vy * age);
      final s = (3 + rnd.nextDouble() * 5) * style.size * (1 - age * .5);
      final col = style.colors[rnd.nextInt(style.colors.length)].withValues(alpha: (1 - age) * .95);
      final paint = Paint()..color = col;
      switch (style.shape) {
        case EntryParticle.circle:
          canvas.drawCircle(pos, s, paint..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .4));
        case EntryParticle.sparkle:
          _sparkle(canvas, pos, s * 1.4, paint, rot: age * 3);
        case EntryParticle.heart:
          _heart(canvas, pos, s * 1.5, paint);
      }
    }
  }

  void _sparkle(Canvas canvas, Offset o, double r, Paint paint, {double rot = 0}) {
    final path = Path();
    for (var k = 0; k < 8; k++) {
      final ang = rot + k * math.pi / 4;
      final rr = k.isEven ? r : r * .28;
      final pt = o + Offset(math.cos(ang) * rr, math.sin(ang) * rr);
      k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  void _heart(Canvas canvas, Offset o, double s, Paint paint) {
    final path = Path()
      ..moveTo(o.dx, o.dy + s * .35)
      ..cubicTo(o.dx - s, o.dy - s * .3, o.dx - s * .35, o.dy - s, o.dx, o.dy - s * .35)
      ..cubicTo(o.dx + s * .35, o.dy - s, o.dx + s, o.dy - s * .3, o.dx, o.dy + s * .35)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_EntryFxPainter old) => old.t != t || old.w != w;
}
