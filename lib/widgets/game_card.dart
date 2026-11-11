import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/game_module.dart';
import '../core/theme.dart';
import 'bouncy_button.dart';

/// بطاقة لعبة كبيرة تطفو بحركة خفيفة، مع لمعة تمر عليها كل فترة.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game, required this.index, required this.onTap});
  final GameModule game;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = Hero(
      tag: 'game-${game.id}',
      flightShuttleBuilder: (_, anim, _, _, _) => Material(
        type: MaterialType.transparency,
        child: _CardBody(game: game),
      ),
      child: Material(type: MaterialType.transparency, child: _CardBody(game: game)),
    );

    return BouncyButton(
      onTap: onTap,
      child: card
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
            begin: 0,
            end: -6,
            duration: (2200 + index * 250).ms,
            curve: Curves.easeInOutSine,
            delay: (index * 180).ms,
          ),
    )
        .animate()
        .fadeIn(delay: (250 + index * 120).ms, duration: 450.ms)
        .slideY(begin: .35, end: 0, delay: (250 + index * 120).ms, duration: 600.ms, curve: Curves.easeOutBack)
        .scaleXY(begin: .85, end: 1, delay: (250 + index * 120).ms, duration: 600.ms, curve: Curves.easeOutBack);
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.game});
  final GameModule game;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: game.colors,
        ),
        boxShadow: [
          BoxShadow(
            color: game.colors[1].withValues(alpha: .45),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: .35), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // دوائر زخرفية
            Positioned(
              top: -30,
              left: -30,
              child: _Circle(size: 110, alpha: .14),
            ),
            Positioned(
              bottom: -40,
              right: -20,
              child: _Circle(size: 130, alpha: .10),
            ),
            // لمعة تمر على البطاقة
            Positioned.fill(
              child: IgnorePointer(
                child: const SizedBox.expand()
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      delay: 2600.ms,
                      duration: 1300.ms,
                      color: Colors.white.withValues(alpha: .28),
                      angle: .6,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.topStart,
                    child: _PlayersChip(players: game.players),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      child: Center(child: game.iconBuilder(context)),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      game.title,
                      style: AppTheme.display.copyWith(
                        fontSize: 26,
                        shadows: const [Shadow(color: Colors.black38, offset: Offset(0, 3), blurRadius: 4)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    game.tagline,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: .9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.alpha});
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

class _PlayersChip extends StatelessWidget {
  const _PlayersChip({required this.players});
  final String players;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgTop.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 3),
          Text(players,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}
