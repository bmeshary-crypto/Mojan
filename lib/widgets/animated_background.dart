import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// خلفية ليلية متدرجة مع جزيئات مضيئة تطفو ببطء.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key, this.child});
  final Widget? child;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  final _particles = List.generate(38, (i) => _Particle(math.Random(i * 7 + 3)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bgTop, AppColors.bgBottom, Color(0xFF3A1F7A)],
            ),
          ),
        ),
        // خلفية مصممة بجيميناي فوق التدرج (تتجاهل إن لم تتوفر)
        Opacity(
          opacity: .85,
          child: Image.asset(
            'assets/images/background.webp',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        // هالات ضوئية كبيرة
        const Positioned(top: -120, right: -80, child: _Glow(color: Color(0xFF7B4DFF), size: 320)),
        const Positioned(bottom: -140, left: -100, child: _Glow(color: Color(0xFFFF4D9D), size: 340)),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _ParticlePainter(_particles, _c.value),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: .45), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle(math.Random r)
      : x = r.nextDouble(),
        y = r.nextDouble(),
        radius = 1 + r.nextDouble() * 2.6,
        speed = .3 + r.nextDouble() * .9,
        phase = r.nextDouble() * math.pi * 2,
        gold = r.nextDouble() < .3;
  final double x, y, radius, speed, phase;
  final bool gold;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = ((p.y - t * p.speed) % 1.0) * size.height;
      final x = p.x * size.width + math.sin(t * math.pi * 2 * p.speed + p.phase) * 14;
      final twinkle = .35 + .65 * (0.5 + 0.5 * math.sin(t * math.pi * 8 * p.speed + p.phase));
      final color = (p.gold ? AppColors.gold : Colors.white).withValues(alpha: twinkle * .8);
      canvas.drawCircle(
        Offset(x, y),
        p.radius * 2.5,
        Paint()
          ..color = color.withValues(alpha: twinkle * .18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(Offset(x, y), p.radius, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.t != t;
}
