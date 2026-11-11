import 'package:flutter/material.dart';

/// ألوان MOJAN: طابع ليلي بنفسجي مع ذهبي، ولكل لعبة لونها.
class AppColors {
  static const bgTop = Color(0xFF1A1033);
  static const bgBottom = Color(0xFF2D1B69);
  static const surface = Color(0xFF2A1A5E);
  static const gold = Color(0xFFFFC23D);
  static const goldDeep = Color(0xFFFF9F1C);
  static const ludo = Color(0xFFFF4D6D);
  static const seeko = Color(0xFF2EE59D);
  static const quiz = Color(0xFF3DB8FF);
  static const truth = Color(0xFF1DA1F2);
  static const dare = Color(0xFFFF5A5F);
  static const textMuted = Color(0xFFB9A9E8);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Cairo',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.bgBottom,
        brightness: Brightness.dark,
        primary: AppColors.gold,
      ),
      scaffoldBackgroundColor: AppColors.bgTop,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }

  /// خط العناوين العريض.
  static const display = TextStyle(
    fontFamily: 'Lalezar',
    color: Colors.white,
    height: 1.1,
  );
}
