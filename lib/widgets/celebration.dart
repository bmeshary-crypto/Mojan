import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme.dart';

const _festive = [
  Color(0xFFFF4D6D),
  Color(0xFFFFC93C),
  Color(0xFF3DDC84),
  Color(0xFF4CC9F0),
  Color(0xFFB794F6),
  Color(0xFFFF8E3C),
];

/// انفجار احتفالي صغير فوق نقطة: فقاعات تطلع وصواريخ تنطلق وتنفجر شرار.
class HomeBurst extends StatefulWidget {
  const HomeBurst({super.key, required this.color, this.size = 160, this.onDone});
  final Color color;
  final double size;
  final VoidCallback? onDone;

  @override
  State<HomeBurst> createState() => _HomeBurstState();
}

class _HomeBurstState extends State<HomeBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
    ..forward().whenComplete(() => widget.onDone?.call());
  late final _seed = Random().nextInt(1 << 20);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(painter: _BurstPainter(_c.value, widget.color, _seed)),
          ),
        ),
      );
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.color, this.seed);
  final double t;
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(seed);
    final c = size.center(Offset.zero);
    final s = size.width / 2;

    // حلقة ضوء
    if (t < .45) {
      final k = t / .45;
      canvas.drawCircle(
        c,
        s * .15 + s * .6 * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .08 * (1 - k)
          ..color = color.withValues(alpha: (1 - k) * .9),
      );
    }

    // فقاعات تطلع لفوق
    for (var i = 0; i < 16; i++) {
      final delay = r.nextDouble() * .35;
      final life = .55 + r.nextDouble() * .3;
      final p = ((t - delay) / life).clamp(0.0, 1.0);
      final dx = (r.nextDouble() - .5) * s * 1.2 + sin(p * 9 + i) * s * .08;
      final rad = s * (.04 + r.nextDouble() * .07);
      if (p <= 0 || p >= 1) continue;
      final pos = c + Offset(dx * p, -s * 1.0 * p);
      final a = p < .8 ? 1.0 : (1 - p) / .2;
      final col = i.isEven ? color : _festive[i % _festive.length];
      canvas.drawCircle(pos, rad, Paint()..color = col.withValues(alpha: .22 * a));
      canvas.drawCircle(
        pos,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: .75 * a),
      );
      canvas.drawCircle(pos + Offset(-rad * .35, -rad * .35), rad * .22, Paint()..color = Colors.white.withValues(alpha: .8 * a));
    }

    // صواريخ تنطلق ثم تنفجر
    for (var i = 0; i < 5; i++) {
      final ang = -pi / 2 + (i - 2) * .42 + (r.nextDouble() - .5) * .2;
      final start = i * .07;
      final fly = .32;
      final dist = s * (.7 + r.nextDouble() * .25);
      final col = _festive[(i + seed) % _festive.length];
      final p = (t - start) / fly;
      final dir = Offset(cos(ang), sin(ang));
      if (p > 0 && p < 1) {
        final e = Curves.easeOutCubic.transform(p);
        final head = c + dir * dist * e;
        final tail = c + dir * dist * max(0, e - .25);
        canvas.drawLine(
          tail,
          head,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = s * .035
            ..shader = LinearGradient(colors: [col.withValues(alpha: 0), Colors.white]).createShader(Rect.fromPoints(tail, head)),
        );
        canvas.drawCircle(head, s * .03, Paint()..color = Colors.white);
      } else if (p >= 1) {
        final q = ((t - start - fly) / .45).clamp(0.0, 1.0);
        if (q >= 1) continue;
        final at = c + dir * dist;
        for (var j = 0; j < 12; j++) {
          final a2 = j * pi / 6;
          final sp = at + Offset(cos(a2), sin(a2)) * s * .32 * Curves.easeOut.transform(q) + Offset(0, s * .1 * q * q);
          canvas.drawCircle(sp, s * .025 * (1 - q) + .6, Paint()..color = (j.isEven ? col : Colors.white).withValues(alpha: 1 - q));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// خلفية احتفال الفوز: بالونات تطلع وألعاب نارية وقصاصات ملونة.
class WinFireworks extends StatefulWidget {
  const WinFireworks({super.key});

  @override
  State<WinFireworks> createState() => _WinFireworksState();
}

class _WinFireworksState extends State<WinFireworks> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  final _seed = Random().nextInt(1 << 20);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(size: Size.infinite, painter: _WinPainter(_c.value, _seed)),
          ),
        ),
      );
}

class _WinPainter extends CustomPainter {
  _WinPainter(this.t, this.seed);
  final double t;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(seed);
    final w = size.width, h = size.height;
    final unit = min(w, h);

    // ألعاب نارية: 7 انفجارات موزعة على الدورة
    for (var i = 0; i < 7; i++) {
      final at = Offset(w * (.12 + r.nextDouble() * .76), h * (.1 + r.nextDouble() * .4));
      final phase = (t + i / 7) % 1.0;
      final col = _festive[(i + seed) % _festive.length];
      final rad = unit * (.12 + r.nextDouble() * .08);
      if (phase < .12) {
        // الصاروخ وهو طالع
        final p = phase / .12;
        final from = Offset(at.dx, h);
        final head = Offset.lerp(from, at, Curves.easeOut.transform(p))!;
        canvas.drawLine(
          Offset.lerp(from, at, max(0, Curves.easeOut.transform(p) - .15))!,
          head,
          Paint()
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: .8),
        );
      } else if (phase < .5) {
        final q = (phase - .12) / .38;
        final e = Curves.easeOutCubic.transform(q);
        for (var j = 0; j < 22; j++) {
          final a = j * 2 * pi / 22;
          final p1 = at + Offset(cos(a), sin(a)) * rad * e + Offset(0, rad * .35 * q * q);
          final p0 = at + Offset(cos(a), sin(a)) * rad * max(0, e - .18) + Offset(0, rad * .35 * q * q);
          canvas.drawLine(
            p0,
            p1,
            Paint()
              ..strokeWidth = 2.6 * (1 - q) + .5
              ..strokeCap = StrokeCap.round
              ..color = (j % 3 == 0 ? Colors.white : col).withValues(alpha: (1 - q).clamp(0, 1)),
          );
        }
        if (q < .25) canvas.drawCircle(at, rad * .25 * (1 - q * 4), Paint()..color = Colors.white.withValues(alpha: .7));
      }
    }

    // قصاصات ملونة نازلة
    for (var i = 0; i < 40; i++) {
      final x0 = r.nextDouble() * w;
      final speed = .6 + r.nextDouble() * .7;
      final p = (t * speed + r.nextDouble()) % 1.0;
      final pos = Offset(x0 + sin(p * 10 + i) * 18, -20 + (h + 40) * p);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p * 12 + i);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 8, height: 4 + 4 * cos(p * 20 + i).abs()),
        Paint()..color = _festive[i % _festive.length].withValues(alpha: .9),
      );
      canvas.restore();
    }

    // بالونات طالعة
    for (var i = 0; i < 12; i++) {
      final x0 = w * (i + .5) / 12 + (r.nextDouble() - .5) * w * .05;
      final speed = .45 + r.nextDouble() * .35;
      final p = (t * speed + r.nextDouble()) % 1.0;
      final bw = unit * (.06 + r.nextDouble() * .025);
      final bh = bw * 1.25;
      final pos = Offset(x0 + sin(p * 6 + i) * 14, h + bh * 2 - (h + bh * 4) * p);
      final col = _festive[(i + 2) % _festive.length];
      // الخيط
      final string = Path()..moveTo(pos.dx, pos.dy + bh * .55);
      for (var k = 1; k <= 4; k++) {
        string.lineTo(pos.dx + (k.isEven ? 4 : -4), pos.dy + bh * .55 + k * bh * .25);
      }
      canvas.drawPath(
        string,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white54,
      );
      final rect = Rect.fromCenter(center: pos, width: bw, height: bh);
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.35, -.4),
            radius: .9,
            colors: [Color.lerp(col, Colors.white, .55)!, col, Color.lerp(col, Colors.black, .3)!],
            stops: const [0, .45, 1],
          ).createShader(rect),
      );
      // العقدة
      final knot = Path()
        ..moveTo(pos.dx - 3, pos.dy + bh * .55)
        ..lineTo(pos.dx + 3, pos.dy + bh * .55)
        ..lineTo(pos.dx, pos.dy + bh * .47)
        ..close();
      canvas.drawPath(knot, Paint()..color = col);
    }
  }

  @override
  bool shouldRepaint(_WinPainter old) => old.t != t;
}

/// لافتة "مبروك" كبيرة مع اسم الفائز.
class WinBanner extends StatelessWidget {
  const WinBanner({super.key, required this.name, this.subtitle});
  final String name;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFFFFF3B0), Color(0xFFFFC93C), Color(0xFFFF8E3C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(b),
          child: Text(
            '🎉 مبرووك 🎉',
            key: const ValueKey('win-banner'),
            textAlign: TextAlign.center,
            style: AppTheme.display.copyWith(
              fontSize: 40,
              color: Colors.white,
              shadows: const [Shadow(color: Color(0xAAFF8E3C), blurRadius: 24)],
            ),
          ),
        )
            .animate()
            .scale(begin: const Offset(.2, .2), duration: 800.ms, curve: Curves.elasticOut)
            .then()
            .shimmer(duration: 1400.ms, color: Colors.white)
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1, end: 1.06, duration: 900.ms, curve: Curves.easeInOut),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFC93C), Color(0xFFFF8E3C)]),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .5), blurRadius: 18)],
          ),
          child: Text(
            '👑 $name',
            key: const ValueKey('win-name'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2A1450)),
          ),
        ).animate().fadeIn(delay: 350.ms).slideY(begin: .6, end: 0, duration: 500.ms, curve: Curves.easeOutBack),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white70)),
        ],
      ]);
}
