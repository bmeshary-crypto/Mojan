import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/game_module.dart';
import '../core/theme.dart';
import 'bouncy_button.dart';

/// نافذة سفلية لاختيار طريقة اللعب. ترجع الطريقة المختارة أو null.
Future<PlayMode?> showModeSheet(BuildContext context, GameModule game) {
  return showModalBottomSheet<PlayMode>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (context) => _ModeSheet(game: game),
  );
}

class _ModeSheet extends StatelessWidget {
  const _ModeSheet({required this.game});
  final GameModule game;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: game.colors[1].withValues(alpha: .6), width: 2),
        boxShadow: [BoxShadow(color: game.colors[1].withValues(alpha: .35), blurRadius: 30)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(height: 72, child: game.iconBuilder(context))
                .animate()
                .scale(duration: 500.ms, curve: Curves.elasticOut, begin: const Offset(.5, .5)),
            const SizedBox(height: 8),
            Text(game.title, style: AppTheme.display.copyWith(fontSize: 30)),
            Text('اختر طريقة اللعب',
                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            for (final (i, mode) in game.modes.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BouncyButton(
                  tilt: false,
                  onTap: () => Navigator.pop(context, mode),
                  child: _ModeTile(mode: mode, color: game.colors[1]),
                )
                    .animate()
                    .fadeIn(delay: (120 + i * 80).ms)
                    .slideX(begin: .25, end: 0, delay: (120 + i * 80).ms, curve: Curves.easeOutCubic),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.mode, required this.color});
  final PlayMode mode;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [
          color.withValues(alpha: .9),
          color.withValues(alpha: .65),
        ]),
        border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: .25), width: 4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .22),
              shape: BoxShape.circle,
            ),
            child: Icon(mode.icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(mode.label,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 30),
        ],
      ),
    );
  }
}
