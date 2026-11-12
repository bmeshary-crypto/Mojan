import 'dart:math' as math;

import 'package:flutter/material.dart';

/// أنواع الحركة اللي تنضاف فوق صورة الإطار.
enum FrameFx { flame, embers, glow, shine, sparkle, hearts, snow, petals, lightning, bubbles, leaves, notes }

/// حركة كل إطار: سرعة الدوران (لفات كل 12 ثانية، 0 = ثابت) + المؤثرات + لون التوهج.
class FrameMotion {
  const FrameMotion({this.spin = 0, this.fx = const [], this.glow = const Color(0xFFFFFFFF), this.breathe = 0});
  final int spin;
  final List<FrameFx> fx;
  final Color glow;

  /// تكبير وتصغير خفيف (نبض) بالنسبة.
  final double breathe;
}

const frameMotions = <String, FrameMotion>{
  'fr_fire': FrameMotion(fx: [FrameFx.flame, FrameFx.embers, FrameFx.glow], glow: Color(0xFFFF6A00)),
  'fr_phoenix': FrameMotion(fx: [FrameFx.flame, FrameFx.embers, FrameFx.glow], glow: Color(0xFFFF7A1A)),
  'fr_demon': FrameMotion(fx: [FrameFx.glow, FrameFx.embers], glow: Color(0xFFFF2020), breathe: .02),
  'fr_angel': FrameMotion(fx: [FrameFx.glow, FrameFx.shine, FrameFx.sparkle], glow: Color(0xFFFFE08A), breathe: .025),
  'fr_galaxy': FrameMotion(spin: 1, fx: [FrameFx.sparkle, FrameFx.glow], glow: Color(0xFF9C6BFF)),
  'fr_neon': FrameMotion(spin: 2, fx: [FrameFx.glow], glow: Color(0xFF29E5FF)),
  'fr_rainbow': FrameMotion(spin: 2, fx: [FrameFx.glow, FrameFx.sparkle], glow: Color(0xFFFF7AD9)),
  'fr_storm': FrameMotion(spin: 1, fx: [FrameFx.lightning, FrameFx.glow], glow: Color(0xFF4FC3FF)),
  'fr_emerald': FrameMotion(spin: 1, fx: [FrameFx.shine, FrameFx.sparkle], glow: Color(0xFF2EE59D)),
  'fr_candy': FrameMotion(spin: 1, fx: [FrameFx.sparkle], glow: Color(0xFFFF8FD0)),
  'fr_ocean': FrameMotion(spin: 1, fx: [FrameFx.bubbles, FrameFx.shine], glow: Color(0xFF4FC3FF)),
  'fr_jungle': FrameMotion(spin: 1, fx: [FrameFx.leaves], glow: Color(0xFF7BE36B)),
  'fr_desert': FrameMotion(fx: [FrameFx.shine, FrameFx.sparkle], glow: Color(0xFFFFD66B)),
  'fr_hearts': FrameMotion(fx: [FrameFx.hearts, FrameFx.glow], glow: Color(0xFFFF5FA8), breathe: .04),
  'fr_ice': FrameMotion(fx: [FrameFx.snow, FrameFx.shine], glow: Color(0xFFBDEBFF)),
  'fr_sakura': FrameMotion(fx: [FrameFx.petals], glow: Color(0xFFFFB3CF), breathe: .015),
  'fr_ramadan': FrameMotion(fx: [FrameFx.shine, FrameFx.sparkle, FrameFx.glow], glow: Color(0xFFFFC94D)),
  'fr_royal': FrameMotion(fx: [FrameFx.shine, FrameFx.sparkle], glow: Color(0xFFB98CFF)),
  'frame_host': FrameMotion(fx: [FrameFx.shine, FrameFx.sparkle, FrameFx.glow], glow: Color(0xFFFFD66B), breathe: .015),
  'frame_party': FrameMotion(fx: [FrameFx.glow, FrameFx.notes, FrameFx.sparkle], glow: Color(0xFFE040FB), breathe: .03),
  'frame_vip': FrameMotion(fx: [FrameFx.shine, FrameFx.sparkle], glow: Color(0xFFE6F2FF)),
};

/// صورة الإطار متحركة: دوران، لهب، لمعة، جزيئات… على حسب نوعه.
class AnimatedFrameArt extends StatefulWidget {
  const AnimatedFrameArt({super.key, required this.art, this.hole = .24});
  final String art;

  /// نصف قطر فتحة الإطار كنسبة من عرضه (التوهج يترسم على الحلقة بس، مش على الصورة).
  final double hole;

  /// يقفل الحركة (للاختبارات مثلاً).
  static bool enabled = true;

  @override
  State<AnimatedFrameArt> createState() => _AnimatedFrameArtState();
}

class _AnimatedFrameArtState extends State<AnimatedFrameArt> with SingleTickerProviderStateMixin {
  static const _loop = 12.0;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 12));

  FrameMotion? get _m => frameMotions[widget.art];

  @override
  void initState() {
    super.initState();
    if (AnimatedFrameArt.enabled && _m != null) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _image() => Image.asset(
        'assets/images/${widget.art}.webp',
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    final m = _m;
    final img = _image();
    if (m == null || !AnimatedFrameArt.enabled) return img;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: img,
        builder: (context, child) {
          final s = _c.value * _loop; // ثواني داخل الدورة
          Widget frame = child!;

          if (m.fx.contains(FrameFx.shine)) {
            // لمعة بيضاء تعدي على الإطار كل 4 ثواني
            final p = (s % 4) / 4 * 3 - 1;
            frame = ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (r) => LinearGradient(
                begin: Alignment(p - .5, -1),
                end: Alignment(p + .5, 1),
                colors: const [Color(0x00FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)],
                stops: const [.35, .5, .65],
              ).createShader(r),
              child: frame,
            );
          }

          if (m.fx.contains(FrameFx.flame)) {
            // اللهب يرقص: يتمطط لفوق ويتهز ونسخة مضيئة فوقه تومض
            final f1 = math.sin(s * 11) * .5 + math.sin(s * 17.3) * .3 + math.sin(s * 29.1) * .2;
            final f2 = math.sin(s * 13.7 + 1) * .5 + math.sin(s * 23.9) * .5;
            frame = Stack(fit: StackFit.expand, children: [
              Transform(
                alignment: const Alignment(0, .35),
                transform: Matrix4.diagonal3Values(1 + f2 * .012, 1 + .035 + f1 * .03, 1),
                child: frame,
              ),
              Opacity(
                opacity: (.28 + f1 * .18).clamp(0, 1),
                child: Transform(
                  alignment: const Alignment(0, .4),
                  transform: Matrix4.diagonal3Values(1.04 + f2 * .02, 1.1 + f1 * .05, 1),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Color(0xFFFFC14D), BlendMode.modulate),
                    child: child,
                  ),
                ),
              ),
            ]);
          }

          if (m.fx.contains(FrameFx.lightning)) {
            // ومضة برق عشوائية
            final flash = _flash(s);
            if (flash > 0) {
              frame = Stack(fit: StackFit.expand, children: [
                frame,
                Opacity(
                  opacity: flash,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Color(0xFFE8F8FF), BlendMode.srcATop),
                    child: child,
                  ),
                ),
              ]);
            }
          }

          if (m.spin != 0) {
            frame = Transform.rotate(angle: 2 * math.pi * _c.value * m.spin, child: frame);
          }
          if (m.breathe > 0) {
            frame = Transform.scale(scale: 1 + m.breathe * math.sin(s * 2 * math.pi / 2), child: frame);
          }

          final glowOn = m.fx.contains(FrameFx.glow);
          final glowPulse = .55 + .45 * math.sin(s * 2 * math.pi / 1.6);
          final flashGlow = m.fx.contains(FrameFx.lightning) ? _flash(s) : 0.0;
          return Stack(clipBehavior: Clip.none, fit: StackFit.expand, children: [
            if (glowOn)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GlowRing(
                      m.glow.withValues(alpha: (.3 + .4 * glowPulse + flashGlow * .3).clamp(0, 1)),
                      widget.hole,
                    ),
                  ),
                ),
              ),
            frame,
            if (m.fx.any(_particleFx.contains))
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _ParticlePainter(m.fx, s, m.glow)),
                ),
              ),
          ]);
        },
      ),
    );
  }

  /// قوة ومضة البرق في اللحظة s (ومضتين سريعتين كل حوالي 3 ثواني).
  static double _flash(double s) {
    const marks = [1.1, 1.25, 4.6, 7.9, 8.05, 10.7];
    var v = 0.0;
    for (final t in marks) {
      final d = s - t;
      if (d >= 0 && d < .18) v = math.max(v, 1 - d / .18);
    }
    return v * .75;
  }
}

const _particleFx = {
  FrameFx.embers,
  FrameFx.sparkle,
  FrameFx.hearts,
  FrameFx.snow,
  FrameFx.petals,
  FrameFx.bubbles,
  FrameFx.leaves,
  FrameFx.notes,
};

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.fx, this.s, this.color);
  final List<FrameFx> fx;
  final double s;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, size.height / 2);
    for (final f in fx) {
      switch (f) {
        case FrameFx.embers:
          _rising(canvas, c, w, 14, 1.6, (p, a, r) {
            canvas.drawCircle(p, r * .7, Paint()..color = Color.lerp(const Color(0xFFFFE08A), const Color(0xFFFF3D00), 1 - a)!.withValues(alpha: a));
          }, startR: .3, spread: .9);
        case FrameFx.hearts:
          _rising(canvas, c, w, 7, 2.6, (p, a, r) => _heart(canvas, p, r * 1.6, const Color(0xFFFF5FA8).withValues(alpha: a)), startR: .32, spread: 1.3);
        case FrameFx.bubbles:
          _rising(canvas, c, w, 8, 3, (p, a, r) {
            canvas.drawCircle(p, r * 1.1, Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(.8, r * .25)
              ..color = Colors.white.withValues(alpha: a * .85));
          }, startR: .35, spread: 1.2);
        case FrameFx.notes:
          _rising(canvas, c, w, 5, 3.2, (p, a, r) => _note(canvas, p, r * 2.2, color.withValues(alpha: a)), startR: .36, spread: 1.4);
        case FrameFx.snow:
          _falling(canvas, c, w, 10, 4, (p, a, r, rot) {
            canvas.drawCircle(p, r * .8, Paint()..color = Colors.white.withValues(alpha: a));
          });
        case FrameFx.petals:
          _falling(canvas, c, w, 7, 4.5, (p, a, r, rot) {
            canvas.save();
            canvas.translate(p.dx, p.dy);
            canvas.rotate(rot);
            canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.4, height: r * 1.4),
                Paint()..color = const Color(0xFFFFB3CF).withValues(alpha: a));
            canvas.restore();
          });
        case FrameFx.leaves:
          _falling(canvas, c, w, 5, 5, (p, a, r, rot) {
            canvas.save();
            canvas.translate(p.dx, p.dy);
            canvas.rotate(rot);
            canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.6, height: r * 1.2),
                Paint()..color = const Color(0xFF6BD35B).withValues(alpha: a));
            canvas.restore();
          });
        case FrameFx.sparkle:
          // نجوم صغيرة تلمع على حلقة الإطار
          for (var i = 0; i < 6; i++) {
            final rnd = math.Random(i * 7919 + color.toARGB32());
            final ang = rnd.nextDouble() * 2 * math.pi;
            final rad = w * (.36 + rnd.nextDouble() * .1);
            final period = 1.4 + rnd.nextDouble() * 1.4;
            final ph = ((s + rnd.nextDouble() * period) % period) / period;
            final a = math.sin(ph * math.pi);
            if (a < .05) continue;
            _star(canvas, c + Offset(math.cos(ang), math.sin(ang)) * rad, w * .045 * a, Colors.white.withValues(alpha: a));
          }
        default:
          break;
      }
    }
  }

  /// جزيئات تطلع لفوق من حوالين الحلقة وتختفي.
  void _rising(Canvas canvas, Offset c, double w, int n, double life, void Function(Offset, double, double) draw,
      {required double startR, required double spread}) {
    for (var i = 0; i < n; i++) {
      final rnd = math.Random(i * 104729 + n);
      final off = rnd.nextDouble() * life;
      final ph = ((s + off) % life) / life;
      final ang = math.pi + rnd.nextDouble() * math.pi; // النص الفوقاني غالباً
      final x0 = c.dx + math.cos(ang) * w * startR * spread;
      final y0 = c.dy + math.sin(ang) * w * startR * .6;
      final sway = math.sin((s + off) * 3 + i) * w * .025;
      final p = Offset(x0 + sway, y0 - ph * w * .35);
      final a = (ph < .15 ? ph / .15 : 1 - (ph - .15) / .85).clamp(0.0, 1.0);
      draw(p, a, w * (.018 + rnd.nextDouble() * .014));
    }
  }

  /// جزيئات تنزل من فوق بميلان خفيف وتلف.
  void _falling(Canvas canvas, Offset c, double w, int n, double life, void Function(Offset, double, double, double) draw) {
    for (var i = 0; i < n; i++) {
      final rnd = math.Random(i * 15485863 + n);
      final off = rnd.nextDouble() * life;
      final ph = ((s + off) % life) / life;
      final x0 = c.dx + (rnd.nextDouble() - .5) * w * .9;
      final p = Offset(x0 + math.sin((s + off) * 2 + i) * w * .05, c.dy - w * .45 + ph * w * .95);
      final a = (ph < .1 ? ph / .1 : ph > .8 ? (1 - ph) / .2 : 1.0).clamp(0.0, 1.0) * .9;
      draw(p, a, w * (.016 + rnd.nextDouble() * .012), (s + off) * 2.2);
    }
  }

  void _star(Canvas canvas, Offset p, double r, Color col) {
    final path = Path();
    for (var k = 0; k < 8; k++) {
      final rr = k.isEven ? r : r * .3;
      final a = k * math.pi / 4;
      final pt = p + Offset(math.cos(a), math.sin(a)) * rr;
      k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = col);
    canvas.drawCircle(p, r * .45, Paint()
      ..color = col.withValues(alpha: col.a * .5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .6));
  }

  void _heart(Canvas canvas, Offset p, double r, Color col) {
    final path = Path()
      ..moveTo(p.dx, p.dy + r * .35)
      ..cubicTo(p.dx - r, p.dy - r * .35, p.dx - r * .45, p.dy - r, p.dx, p.dy - r * .45)
      ..cubicTo(p.dx + r * .45, p.dy - r, p.dx + r, p.dy - r * .35, p.dx, p.dy + r * .35)
      ..close();
    canvas.drawPath(path, Paint()..color = col);
  }

  void _note(Canvas canvas, Offset p, double r, Color col) {
    final paint = Paint()..color = col;
    canvas.drawOval(Rect.fromCenter(center: p, width: r * .55, height: r * .4), paint);
    canvas.drawRect(Rect.fromLTWH(p.dx + r * .2, p.dy - r * .9, r * .08, r * .9), paint);
    canvas.drawRect(Rect.fromLTWH(p.dx + r * .2, p.dy - r * .9, r * .35, r * .1), paint);
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.s != s;
}

/// توهج على شكل حلقة حوالين الفتحة، ما يغطي صورة اللاعب.
class _GlowRing extends CustomPainter {
  _GlowRing(this.color, this.hole);
  final Color color;
  final double hole;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.drawCircle(
      Offset(w / 2, size.height / 2),
      w * (hole + .06),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .09
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * .06),
    );
  }

  @override
  bool shouldRepaint(_GlowRing old) => old.color != color;
}
