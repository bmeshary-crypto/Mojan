import 'package:flutter/material.dart';

import '../core/game_module.dart';
import '../core/theme.dart';
import '../screens/coming_soon_screen.dart';
import '../screens/online_lobby.dart';
import '../widgets/game_icons.dart';
import 'blocks/blocks_screen.dart';
import 'coin_games/fruits.dart';
import 'coin_games/lucky_slots.dart';
import 'coin_games/star_league.dart';
import 'coin_games/sultan.dart';
import 'coin_games/pegs.dart';
import 'coin_games/rocket.dart';
import 'coin_games/treasure.dart';
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
          mode == PlayMode.online
              ? OnlineLobby(
                  game: 'ludo',
                  title: 'لودو',
                  colors: const [Color(0xFFFF6B85), AppColors.ludo],
                  modes: const [('classic', 'كلاسيك'), ('power', '⚡ باور'), ('quick', '🏃 سريع')],
                  screen: (m) => LudoOnlineScreen(match: m),
                  vsComputer: () => const LudoScreen(mode: PlayMode.vsComputer),
                )
              : LudoScreen(mode: mode),
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
          mode == PlayMode.online
              ? OnlineLobby(
                  game: 'seeko',
                  title: 'سيكو',
                  colors: const [Color(0xFF3FE0A5), AppColors.seeko],
                  sizes: const [2, 4],
                  sizeLabels: const {2: 'لاعبين', 4: '4 (فريقان)'},
                  screen: (m) => SeekoOnlineScreen(match: m),
                  vsComputer: () => const SeekoScreen(mode: PlayMode.vsComputer),
                )
              : SeekoScreen(mode: mode),
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
    GameModule(
      id: 'fruits',
      title: 'سوق الفواكه',
      tagline: 'راهن على الفاكهة الرابحة',
      colors: const [Color(0xFF5CF2B5), Color(0xFF16A06B), Color(0xFF0B5E42)],
      players: 'الكل',
      modes: const [PlayMode.live],
      iconBuilder: (_) => const GameArt('assets/images/fruits.webp', fallback: EmojiArt('🍉', small: '🍓🍍')),
      screenBuilder: (_, _) => const FruitsScreen(),
    ),
    GameModule(
      id: 'treasure',
      title: 'صناديق الكنز',
      tagline: 'افتح واسحب قبل الوحش',
      colors: const [Color(0xFFFFC46B), Color(0xFFB8641E), Color(0xFF5A2E0E)],
      players: '1',
      modes: const [PlayMode.solo],
      iconBuilder: (_) => const GameArt('assets/images/treasure.webp', fallback: EmojiArt('🧰', small: '💎👹')),
      screenBuilder: (_, _) => const TreasureScreen(),
    ),
    GameModule(
      id: 'pegs',
      title: 'هرم المسامير',
      tagline: 'أسقط الكرة واصطد المضاعف',
      colors: const [Color(0xFF7CB8FF), Color(0xFF3A5BD9), Color(0xFF1A2A7A)],
      players: '1',
      modes: const [PlayMode.solo],
      iconBuilder: (_) => const GameArt('assets/images/pegs.webp', fallback: EmojiArt('🔺', small: '⚪⚪')),
      screenBuilder: (_, _) => const PegsScreen(),
    ),
    GameModule(
      id: 'rocket',
      title: 'صاروخ المجرة',
      tagline: 'اسحب أرباحك قبل ما ينفجر',
      colors: const [Color(0xFF9B7BFF), Color(0xFF3B2A9F), Color(0xFF120C45)],
      players: 'الكل',
      modes: const [PlayMode.live],
      iconBuilder: (_) => const GameArt('assets/images/rocket.webp', fallback: EmojiArt('🚀', small: '✨💥')),
      screenBuilder: (_, _) => const RocketScreen(),
    ),
    GameModule(
      id: 'star_league',
      title: 'دوري النجوم',
      tagline: 'راهن على النادي الفائز',
      colors: const [Color(0xFF6BE38F), Color(0xFF1D8A45), Color(0xFF0A3D1E)],
      players: 'الكل',
      modes: const [PlayMode.live],
      iconBuilder: (_) => const GameArt('assets/images/star_league.webp', fallback: EmojiArt('⚽', small: '🏆🦁')),
      screenBuilder: (_, _) => const StarLeagueScreen(),
    ),
    GameModule(
      id: 'lucky_slots',
      title: 'ماكينة الحظ',
      tagline: 'ثلاث بكرات و٧٧٧ أعلى ربح',
      colors: const [Color(0xFFFF6B6B), Color(0xFFC3141F), Color(0xFF5A0710)],
      players: '1',
      modes: const [PlayMode.solo],
      iconBuilder: (_) => const GameArt('assets/images/lucky_slots.webp', fallback: EmojiArt('🎰', small: '🍒7️⃣')),
      screenBuilder: (_, _) => const LuckySlotsScreen(),
    ),
    GameModule(
      id: 'sultan',
      title: 'كنز السلطان',
      tagline: '20 خط وجاكبوت ولفات مجانية',
      colors: const [Color(0xFFD38CFF), Color(0xFF6A1DA8), Color(0xFF2A0845)],
      players: '1',
      modes: const [PlayMode.solo],
      iconBuilder: (_) => const GameArt('assets/images/sultan.webp', fallback: EmojiArt('🪔', small: '🪙🗝️')),
      screenBuilder: (_, _) => const SultanScreen(),
    ),
    GameModule(
      id: 'blocks',
      title: 'مكعبات',
      tagline: 'رتب القطع وامسح الصفوف',
      colors: const [Color(0xFF7FA0FF), Color(0xFF3A5091), Color(0xFF1E2747)],
      players: '1',
      modes: const [PlayMode.solo],
      iconBuilder: (_) => const GameArt('assets/images/blocks.webp', fallback: EmojiArt('🟧', small: '🟪🟩')),
      screenBuilder: (_, _) => const BlocksScreen(),
    ),
  ];

  static GameModule byId(String id) => games.firstWhere((g) => g.id == id);
}
