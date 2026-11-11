import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme.dart';
import '../widgets/animated_background.dart';
import 'home_screen.dart';
import '../core/account/account.dart';
import 'login_screen.dart';

/// الشاشة الافتتاحية: أربع قطع بألوان الألعاب تطير وتتجمع لتكوّن شعار MOJAN.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, _, _) => Account.instance.signedIn
              ? const HomeScreen()
              : const LoginScreen(),
          transitionsBuilder: (_, anim, _, child) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween(begin: 1.08, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MojanLogoMark(size: 120, animateIn: true),
              const SizedBox(height: 28),
              const MojanWordmark(fontSize: 64, animateIn: true),
              const SizedBox(height: 6),
              Text(
                    'العب مع الكل… في أي مكان',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 1900.ms, duration: 500.ms)
                  .slideY(begin: .6, end: 0, delay: 1900.ms),
              const SizedBox(height: 40),
              SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(
                    minHeight: 6,
                    color: AppColors.gold,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ).animate().fadeIn(delay: 2100.ms),
            ],
          ),
        ),
      ),
    );
  }
}

/// علامة الشعار: مربع من أربع قطع بألوان الألعاب.
class MojanLogoMark extends StatelessWidget {
  const MojanLogoMark({super.key, required this.size, this.animateIn = false});
  final double size;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    const tiles = [
      (AppColors.ludo, Offset(-1, -1)),
      (AppColors.gold, Offset(1, -1)),
      (AppColors.quiz, Offset(-1, 1)),
      (AppColors.seeko, Offset(1, 1)),
    ];
    final tile = size * .46;
    final gap = size * .08;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          for (final (i, (color, dir)) in tiles.indexed)
            Positioned(
              left: dir.dx < 0 ? 0 : tile + gap,
              top: dir.dy < 0 ? 0 : tile + gap,
              child: _tile(color, tile, i, dir),
            ),
          Center(
            child: Container(
              width: size * .3,
              height: size * .3,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: .8),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: AppColors.bgBottom,
                size: size * .22,
              ),
            ),
          ).maybeAnimate(
            animateIn,
            (a) => a.scale(
              delay: 1100.ms,
              duration: 600.ms,
              curve: Curves.elasticOut,
              begin: Offset.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Color color, double s, int i, Offset dir) {
    final w = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(s * .3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, .25)!, color],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .6),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
    if (!animateIn) return w;
    return w
        .animate()
        .fadeIn(delay: (i * 140).ms, duration: 300.ms)
        .move(
          begin: Offset(dir.dx * 260, dir.dy * 360),
          end: Offset.zero,
          delay: (i * 140).ms,
          duration: 800.ms,
          curve: Curves.easeOutBack,
        )
        .rotate(
          begin: dir.dx * .6,
          end: 0,
          delay: (i * 140).ms,
          duration: 800.ms,
          curve: Curves.easeOutBack,
        );
  }
}

/// كلمة MOJAN بحروف تقفز واحداً تلو الآخر.
class MojanWordmark extends StatelessWidget {
  const MojanWordmark({
    super.key,
    required this.fontSize,
    this.animateIn = false,
  });
  final double fontSize;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    const letters = 'MOJAN';
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < letters.length; i++)
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFE08A), AppColors.gold, AppColors.goldDeep],
              ).createShader(r),
              child: Text(
                letters[i],
                style: AppTheme.display.copyWith(
                  fontSize: fontSize,
                  letterSpacing: 2,
                  shadows: const [
                    Shadow(color: Color(0xFF7A3E00), offset: Offset(0, 4)),
                  ],
                ),
              ),
            ).maybeAnimate(
              animateIn,
              (a) => a
                  .fadeIn(delay: (900 + i * 110).ms, duration: 200.ms)
                  .slideY(
                    begin: -1.2,
                    end: 0,
                    delay: (900 + i * 110).ms,
                    duration: 650.ms,
                    curve: Curves.bounceOut,
                  ),
            ),
        ],
      ),
    );
  }
}

extension _MaybeAnimate on Widget {
  Widget maybeAnimate(bool on, Animate Function(Animate) build) =>
      on ? build(animate()) : this;
}
