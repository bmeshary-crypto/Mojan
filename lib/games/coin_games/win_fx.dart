import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/sfx.dart';
import '../../core/theme.dart';
import 'coin_ui.dart';

/// رقم يعد من الصفر للقيمة (للأرباح).
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, this.style, this.ms = 900, this.prefix = ''});
  final int value;
  final TextStyle? style;
  final int ms;
  final String prefix;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(value),
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: Duration(milliseconds: ms),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Text('$prefix${fmtCoins(v.round())}', style: style),
  );
}

String? winTier(double mult) => mult >= 50
    ? 'أسطوري!'
    : mult >= 20
    ? 'ربح ضخم!'
    : mult >= 8
    ? 'ربح كبير!'
    : null;

/// شاشة الربح الكبير فوق اللعبة: أشعة تدور، عملات تتساقط، وعداد.
/// ترجع لما تخلص أو يضغط اللاعب.
Future<void> showBigWin(BuildContext context, {required int amount, required double mult, String? title, Widget? hero}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return Future.value();
  final done = Completer<void>();
  late OverlayEntry entry;
  void close() {
    if (done.isCompleted) return;
    entry.remove();
    done.complete();
  }

  entry = OverlayEntry(
    builder: (_) => _BigWin(amount: amount, title: title ?? winTier(mult) ?? 'ربحت!', hero: hero, onDone: close),
  );
  overlay.insert(entry);
  Sfx.instance.bigWin();
  return done.future;
}

class _BigWin extends StatefulWidget {
  const _BigWin({required this.amount, required this.title, required this.onDone, this.hero});
  final int amount;
  final String title;
  final Widget? hero;
  final VoidCallback onDone;

  @override
  State<_BigWin> createState() => _BigWinState();
}

class _BigWinState extends State<_BigWin> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _rng = Random();
  final List<_Coin> _coins = [];
  Duration _t = Duration.zero;
  Timer? _close;
  Timer? _ticks;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 70; i++) {
      _coins.add(_Coin(
        x: _rng.nextDouble(),
        delay: _rng.nextDouble() * 1.6,
        speed: .35 + _rng.nextDouble() * .45,
        size: 14 + _rng.nextDouble() * 18,
        spin: 2 + _rng.nextDouble() * 6,
        drift: (_rng.nextDouble() - .5) * .15,
      ));
    }
    _ticker.start();
    var n = 0;
    _ticks = Timer.periodic(const Duration(milliseconds: 70), (t) {
      Sfx.instance.countTick();
      if (++n > 22) t.cancel();
    });
    _close = Timer(const Duration(milliseconds: 3600), widget.onDone);
  }

  void _tick(Duration d) => setState(() => _t = d);

  @override
  void dispose() {
    _ticker.dispose();
    _close?.cancel();
    _ticks?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = _t.inMilliseconds / 1000;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        key: const ValueKey('big-win'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDone,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.black.withValues(alpha: .62)).animate().fadeIn(duration: 250.ms)),
            // أشعة تدور
            Positioned.fill(
              child: Center(
                child: Transform.rotate(
                  angle: secs * .5,
                  child: const SizedBox(width: 700, height: 700, child: CustomPaint(painter: _RaysPainter())),
                ),
              ),
            ),
            Positioned.fill(child: CustomPaint(painter: _CoinRain(_coins, secs))),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.hero != null) widget.hero!.animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFF7C2), Color(0xFFFFC93C), Color(0xFFE07A10)],
                    ).createShader(r),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: AppTheme.display.copyWith(
                        fontSize: 54,
                        color: Colors.white,
                        shadows: const [Shadow(color: Color(0xFF7A1A00), offset: Offset(3, 4), blurRadius: 2)],
                      ),
                    ),
                  )
                      .animate()
                      .scale(begin: const Offset(.2, .2), duration: 700.ms, curve: Curves.elasticOut)
                      .then()
                      .shimmer(duration: 1200.ms, color: Colors.white),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      gradient: const LinearGradient(colors: [Color(0xFF5A1A00), Color(0xFF2A0A00)]),
                      border: Border.all(color: const Color(0xFFFFC93C), width: 3),
                      boxShadow: const [BoxShadow(color: Color(0x99FFC93C), blurRadius: 24)],
                    ),
                    child: CountUp(
                      value: widget.amount,
                      ms: 1600,
                      prefix: '+',
                      style: AppTheme.display.copyWith(fontSize: 40, color: const Color(0xFFFFE07A)),
                    ),
                  ).animate().fadeIn(delay: 250.ms).slideY(begin: .5, curve: Curves.easeOutBack),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Coin {
  _Coin({required this.x, required this.delay, required this.speed, required this.size, required this.spin, required this.drift});
  final double x, delay, speed, size, spin, drift;
}

class _CoinRain extends CustomPainter {
  _CoinRain(this.coins, this.t);
  final List<_Coin> coins;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in coins) {
      final lt = t - c.delay;
      if (lt < 0) continue;
      final y = -40 + lt * c.speed * size.height * .9 + 200 * lt * lt;
      if (y > size.height + 40) continue;
      final x = (c.x + c.drift * lt) * size.width;
      final squash = cos(lt * c.spin).abs().clamp(.15, 1.0);
      final rect = Rect.fromCenter(center: Offset(x, y), width: c.size * squash, height: c.size);
      canvas.drawOval(
        rect,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFFFFF0A0), Color(0xFFFFC21A), Color(0xFFB8700A)]).createShader(rect),
      );
      canvas.drawOval(
        rect.deflate(c.size * .14),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF9A5A00),
      );
    }
  }

  @override
  bool shouldRepaint(_CoinRain o) => true;
}

class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..shader = RadialGradient(colors: [const Color(0x88FFD84D), const Color(0x00FFD84D)]).createShader(Rect.fromCircle(center: c, radius: r));
    const n = 18;
    for (var i = 0; i < n; i++) {
      final a1 = i * 2 * pi / n, a2 = a1 + pi / n * .6;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + cos(a1) * r, c.dy + sin(a1) * r)
          ..lineTo(c.dx + cos(a2) * r, c.dy + sin(a2) * r)
          ..close(),
        paint,
      );
    }
    canvas.drawCircle(c, r * .35, Paint()..shader = RadialGradient(colors: [const Color(0x66FFF3B0), const Color(0x00FFF3B0)]).createShader(Rect.fromCircle(center: c, radius: r * .35)));
  }

  @override
  bool shouldRepaint(_) => false;
}

/// أرقام صغيرة تطير لفوق (+500) عند الربح العادي.
class FloatingWin extends StatelessWidget {
  const FloatingWin({super.key, required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Text(
      '+${fmtCoins(amount)}',
      style: AppTheme.display.copyWith(
        fontSize: 34,
        color: const Color(0xFFFFE07A),
        shadows: const [Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2))],
      ),
    )
        .animate()
        .scale(begin: const Offset(.4, .4), duration: 400.ms, curve: Curves.elasticOut)
        .then(delay: 600.ms)
        .slideY(end: -1.2, duration: 700.ms)
        .fadeOut(duration: 700.ms),
  );
}
