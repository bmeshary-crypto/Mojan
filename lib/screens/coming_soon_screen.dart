import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/game_module.dart';
import '../core/theme.dart';
import '../games/game_registry.dart';
import '../widgets/animated_background.dart';

/// شاشة مؤقتة لكل لعبة حتى نبنيها في المرحلة الثانية.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.gameId, required this.mode});
  final String gameId;
  final PlayMode mode;

  @override
  Widget build(BuildContext context) {
    final game = GameRegistry.byId(gameId);
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 30),
                ),
              ),
              const Spacer(),
              Hero(
                tag: 'game-${game.id}',
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: game.iconBuilder(context),
                ),
              ),
              const SizedBox(height: 24),
              Text(game.title, style: AppTheme.display.copyWith(fontSize: 40)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: game.colors[1].withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(mode.icon, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      mode.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                    'اللعبة قيد البناء… قريباً',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fadeIn(duration: 900.ms),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
