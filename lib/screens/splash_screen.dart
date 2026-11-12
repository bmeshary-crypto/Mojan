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
              MojanBrandLogo(width: (MediaQuery.sizeOf(context).width * .85).clamp(220, 420), animateIn: true),
              const SizedBox(height: 10),
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

/// أيقونة MOJAN (حرف M مع السماعة والكروت).
class MojanLogoMark extends StatelessWidget {
  const MojanLogoMark({super.key, required this.size, this.animateIn = false});
  final double size;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final img = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .24),
        boxShadow: [BoxShadow(color: AppColors.quiz.withValues(alpha: .45), blurRadius: size * .25)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: Image.asset('assets/images/brand_icon.webp', fit: BoxFit.cover),
      ),
    );
    return img.maybeAnimate(
      animateIn,
      (a) => a.scale(duration: 700.ms, curve: Curves.elasticOut, begin: const Offset(.4, .4)).fadeIn(duration: 300.ms),
    );
  }
}

/// شعار MOJAN الكامل (موجان) بخلفية شفافة.
class MojanBrandLogo extends StatelessWidget {
  const MojanBrandLogo({super.key, required this.width, this.animateIn = false});
  final double width;
  final bool animateIn;

  @override
  Widget build(BuildContext context) => Image.asset('assets/images/brand_logo.webp', width: width).maybeAnimate(
        animateIn,
        (a) => a.fadeIn(duration: 500.ms).scale(duration: 900.ms, curve: Curves.elasticOut, begin: const Offset(.6, .6)),
      );
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
