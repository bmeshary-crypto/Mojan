import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// رسومات مؤقتة للألعاب (ستُستبدل بصور Gemini لاحقاً).

class LudoIcon extends StatelessWidget {
  const LudoIcon({super.key});

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF2ECC71),
      Color(0xFFFFC23D),
      Color(0xFFFF4D4D),
      Color(0xFF3D8BFF),
    ];
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5A2B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              GridView.count(
                crossAxisCount: 2,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  for (final c in colors)
                    Container(
                      color: c,
                      alignment: Alignment.center,
                      child: FractionallySizedBox(
                        widthFactor: .55,
                        heightFactor: .55,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .25),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Center(
                child: FractionallySizedBox(
                  widthFactor: .34,
                  heightFactor: .34,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                      ],
                    ),
                    child: const _DiceFace(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiceFace extends StatelessWidget {
  const _DiceFace();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final d = c.maxWidth * .18;
      Widget dot() => Container(
            width: d,
            height: d,
            decoration: const BoxDecoration(color: Color(0xFF1A1033), shape: BoxShape.circle),
          );
      return Padding(
        padding: EdgeInsets.all(c.maxWidth * .16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [dot(), dot()]),
            Center(child: dot()),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [dot(), dot()]),
          ],
        ),
      );
    });
  }
}

class SeekoIcon extends StatelessWidget {
  const SeekoIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth * .46;
        Widget card(String rank, String suit, Color color, double angle, double dx) {
          return Transform.translate(
            offset: Offset(dx * c.maxWidth, 0),
            child: Transform.rotate(
              angle: angle,
              child: Container(
                width: w,
                height: w * 1.4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rank,
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w900, fontSize: w * .22, height: 1)),
                    Expanded(
                      child: Center(
                        child: Text(suit, style: TextStyle(color: color, fontSize: w * .45)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            card('A', '♠', const Color(0xFF1A1033), -.32, -.2),
            card('K', '♥', const Color(0xFFE63946), .0, 0),
            card('J', '♦', const Color(0xFFE63946), .32, .2),
            Positioned(
              bottom: c.maxWidth * .06,
              child: Container(
                width: c.maxWidth * .26,
                height: c.maxWidth * .26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF6FFFC6), AppColors.seeko, Color(0xFF14A86C)],
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class QuizIcon extends StatelessWidget {
  const QuizIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, c) {
        final s = c.maxWidth;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s * .82,
              height: s * .82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 6)),
                ],
              ),
            ),
            Text('؟',
                style: TextStyle(
                  fontFamily: 'Lalezar',
                  fontSize: s * .62,
                  color: AppColors.quiz,
                  height: 1.2,
                )),
            Positioned(
              top: s * .04,
              left: s * .02,
              child: _Badge(text: 'A', color: AppColors.gold, size: s * .26),
            ),
            Positioned(
              bottom: s * .04,
              right: s * .02,
              child: _Badge(text: 'B', color: AppColors.ludo, size: s * .26),
            ),
          ],
        );
      }),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, required this.size});
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Text(text,
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * .45, height: 1)),
    );
  }
}

class TruthDareIcon extends StatelessWidget {
  const TruthDareIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, c) {
        final s = c.maxWidth;
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _SplitPainter())),
              Center(
                child: Transform.rotate(
                  angle: -math.pi / 14,
                  child: Text(
                    'VS',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: 'Lalezar',
                      fontSize: s * .42,
                      color: Colors.white,
                      height: 1.3,
                      shadows: const [
                        Shadow(color: Color(0xFF1A1033), offset: Offset(3, 4)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _SplitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blue = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    final red = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(blue, Paint()..color = AppColors.truth);
    canvas.drawPath(red, Paint()..color = AppColors.dare);
    canvas.drawLine(
      Offset.zero,
      Offset(size.width, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// صورة اللعبة المصممة (من جيميناي)، وترجع للأيقونة المرسومة بالكود إن لم تتوفر.
class GameArt extends StatelessWidget {
  const GameArt(this.asset, {super.key, required this.fallback});
  final String asset;
  final Widget fallback;

  @override
  Widget build(BuildContext context) => Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => fallback,
      );
}

/// رسمة بطاقة من إيموجي (للألعاب اللي ما لها صورة بعد).
class EmojiArt extends StatelessWidget {
  const EmojiArt(this.big, {super.key, this.small = ''});
  final String big;
  final String small;

  @override
  Widget build(BuildContext context) => FittedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(big, style: const TextStyle(fontSize: 72, shadows: [Shadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 6))])),
            if (small.isNotEmpty) Text(small, style: const TextStyle(fontSize: 26)),
          ],
        ),
      );
}
