import 'package:flutter/material.dart';

import '../core/game_module.dart';
import '../core/theme.dart';
import '../screens/coming_soon_screen.dart';
import '../widgets/game_icons.dart';
import 'ludo/ludo_screen.dart';
import 'quiz/quiz_screen.dart';
import 'seeko/seeko_screen.dart';
import 'sky_wheel/sky_wheel_screen.dart';
import 'truth_dare/truth_dare_screen.dart';

/// كل ألعاب MOJAN. لإضافة لعبة جديدة يكفي إضافة عنصر هنا.
class GameRegistry {
  static final List<GameModule> games = [
    GameModule(
      id: 'ludo',
      title: 'لودو',
      tagline: 'ارمِ النرد وأوصل قطعك للبيت',
      colors: const [Color(0xFFFF6B85), AppColors.ludo, Color(0xFFC9184A)],
      players: '2-4',
      modes: const [PlayMode.vsComputer, PlayMode.local, PlayMode.online],
      iconBuilder: (_) => const GameArt('assets/images/ludo.webp', fallback: LudoIcon()),
      screenBuilder: (_, mode) =>
          mode == PlayMode.online ? ComingSoonScreen(gameId: 'ludo', mode: mode) : LudoScreen(mode: mode),
    ),
    GameModule(
      id: 'seeko',
      title: 'سيكو',
      tagline: 'كوّن صف خمسة قبل خصمك',
      colors: const [Color(0xFF5CF2B5), AppColors.seeko, Color(0xFF0E9F64)],
      players: '2-4',
      modes: const [PlayMode.vsComputer, PlayMode.local, PlayMode.online],
      iconBuilder: (_) => const GameArt('assets/images/seeko.webp', fallback: SeekoIcon()),
      screenBuilder: (_, mode) =>
          mode == PlayMode.online ? ComingSoonScreen(gameId: 'seeko', mode: mode) : SeekoScreen(mode: mode),
    ),
    GameModule(
      id: 'quiz',
      title: 'أسئلة وأجوبة',
      tagline: 'غرف مسابقات مع أصحابك',
      colors: const [Color(0xFF6CCBFF), AppColors.quiz, Color(0xFF1B7FD1)],
      players: '1-8',
      modes: const [PlayMode.rooms, PlayMode.vsComputer],
      iconBuilder: (_) => const GameArt('assets/images/quiz.webp', fallback: QuizIcon()),
      screenBuilder: (_, mode) => QuizScreen(mode: mode),
    ),
    GameModule(
      id: 'truth_dare',
      title: 'صراحة أو جرأة',
      tagline: 'اعترف أو نفّذ التحدي',
      colors: const [Color(0xFF4CB8FF), Color(0xFF8F6BFF), AppColors.dare],
      players: '2-12',
      modes: const [PlayMode.local, PlayMode.online],
      iconBuilder: (_) => const GameArt('assets/images/truth_dare.webp', fallback: TruthDareIcon()),
      screenBuilder: (_, mode) => mode == PlayMode.online
          ? ComingSoonScreen(gameId: 'truth_dare', mode: mode)
          : TruthDareScreen(mode: mode),
    ),
    GameModule(
      id: 'sky_wheel',
      title: 'عجلة السماء',
      tagline: 'راهن على الكابينة والتاج أعلى ربح',
      colors: const [Color(0xFF7CC8FF), Color(0xFF5B49C9), Color(0xFF2A1E6B)],
      players: 'الكل',
      modes: const [PlayMode.live],
      iconBuilder: (_) => const GameArt('assets/images/sky_wheel.webp', fallback: Icon(Icons.attractions_rounded, size: 80)),
      screenBuilder: (_, _) => const SkyWheelScreen(),
    ),
  ];

  static GameModule byId(String id) => games.firstWhere((g) => g.id == id);
}
