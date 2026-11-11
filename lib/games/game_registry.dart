import 'package:flutter/material.dart';

import '../core/game_module.dart';
import '../core/theme.dart';
import '../screens/coming_soon_screen.dart';
import '../widgets/game_icons.dart';
import 'ludo/ludo_screen.dart';
import 'seeko/seeko_screen.dart';

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
      iconBuilder: (_) => const LudoIcon(),
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
      iconBuilder: (_) => const SeekoIcon(),
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
      iconBuilder: (_) => const QuizIcon(),
      screenBuilder: (_, mode) => ComingSoonScreen(gameId: 'quiz', mode: mode),
    ),
    GameModule(
      id: 'truth_dare',
      title: 'صراحة أو جرأة',
      tagline: 'اعترف أو نفّذ التحدي',
      colors: const [Color(0xFF4CB8FF), Color(0xFF8F6BFF), AppColors.dare],
      players: '2-12',
      modes: const [PlayMode.local, PlayMode.online],
      iconBuilder: (_) => const TruthDareIcon(),
      screenBuilder: (_, mode) => ComingSoonScreen(gameId: 'truth_dare', mode: mode),
    ),
  ];

  static GameModule byId(String id) => games.firstWhere((g) => g.id == id);
}
