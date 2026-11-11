import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/account/account.dart';
import '../core/account/leaderboard.dart';
import '../core/theme.dart';
import '../widgets/account_widgets.dart';

/// تبويب "المتصدرون": ترتيب عام أو لكل لعبة، أسبوعي أو كل الأوقات.
class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key});

  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> {
  String? _game;
  bool _weekly = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Account.instance,
      builder: (context, _) {
        final list = Leaderboard.build(
          Account.instance.profile,
          game: _game,
          weekly: _weekly,
        );
        final myRank = list.indexWhere((e) => e.isMe);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FittedBox(
                        child: Text(
                          'المتصدرون',
                          style: AppTheme.display.copyWith(fontSize: 30),
                        ),
                      ),
                    ),
                  ),
                  _PeriodToggle(
                    weekly: _weekly,
                    onChanged: (v) => setState(() => _weekly = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final (id, title) in [
                    (null, 'الكل'),
                    ...gameTitles.entries.map((e) => (e.key, e.value)),
                  ])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        key: ValueKey('lb-${id ?? 'all'}'),
                        label: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        selected: _game == id,
                        selectedColor: AppColors.gold,
                        labelStyle: TextStyle(
                          color: _game == id ? AppColors.bgTop : Colors.white,
                        ),
                        backgroundColor: Colors.white.withValues(alpha: .08),
                        showCheckmark: false,
                        side: BorderSide.none,
                        onSelected: (_) => setState(() => _game = id),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: ValueKey('$_game-$_weekly'),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 190),
                children: [
                  _Podium(top: list.take(3).toList()),
                  const SizedBox(height: 14),
                  for (var i = 3; i < list.length; i++)
                    _Row(rank: i + 1, e: list[i])
                        .animate()
                        .fadeIn(delay: (40 * (i - 3)).ms)
                        .slideX(begin: .15, end: 0),
                  const SizedBox(height: 10),
                  const Text(
                    'المنافسون الظاهرون تجريبيون حتى تشغيل السيرفر، ونتيجتك حقيقية من مبارياتك.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (myRank >= 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                child: _Row(rank: myRank + 1, e: list[myRank], pinned: true),
              ),
          ],
        );
      },
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.weekly, required this.onChanged});
  final bool weekly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String t, bool v) => GestureDetector(
      onTap: () => onChanged(v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: weekly == v ? AppColors.quiz : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          t,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('الأسبوع', true), seg('كل الأوقات', false)],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top});
  final List<LeaderEntry> top;

  @override
  Widget build(BuildContext context) {
    if (top.length < 3) return const SizedBox.shrink();
    Widget col(LeaderEntry e, int place, double h, Color c) => Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (place == 1)
            const Text('👑', style: TextStyle(fontSize: 26))
                .animate(onPlay: (a) => a.repeat(reverse: true))
                .moveY(begin: 0, end: -4, duration: 900.ms),
          PlayerAvatar(index: e.avatar, size: place == 1 ? 72 : 58),
          const SizedBox(height: 4),
          Text(
            e.isMe ? '${e.name} (أنت)' : e.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            '${e.points}',
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c, c.withValues(alpha: .4)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$place',
              style: AppTheme.display.copyWith(
                fontSize: 34,
                color: Colors.white,
              ),
            ),
          ).animate().scaleY(
            begin: 0,
            end: 1,
            alignment: Alignment.bottomCenter,
            duration: 600.ms,
            delay: (place * 120).ms,
            curve: Curves.easeOutBack,
          ),
        ],
      ),
    );
    return SizedBox(
      height: 272,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          col(top[1], 2, 80, const Color(0xFFB8C2D9)),
          col(top[0], 1, 110, AppColors.gold),
          col(top[2], 3, 60, const Color(0xFFD28C55)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.e, this.pinned = false});
  final int rank;
  final LeaderEntry e;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: e.isMe ? ValueKey(pinned ? 'my-rank-pinned' : 'my-rank') : null,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: e.isMe
            ? AppColors.gold.withValues(alpha: pinned ? .95 : .2)
            : Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: e.isMe ? AppColors.gold : Colors.transparent),
        boxShadow: pinned
            ? const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: pinned ? AppColors.bgTop : Colors.white),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            PlayerAvatar(index: e.avatar, size: 38, ring: false),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                e.isMe ? '${e.name} (أنت)' : e.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${e.wins} فوز',
              style: TextStyle(
                fontSize: 12,
                color: pinned ? AppColors.bgTop : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${e.points}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: pinned ? AppColors.bgTop : AppColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
