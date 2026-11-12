import 'dart:math';

import 'account.dart';

class LeaderEntry {
  const LeaderEntry({
    required this.name,
    required this.avatar,
    required this.points,
    required this.wins,
    this.isMe = false,
  });
  final String name;
  final int avatar;
  final int points;
  final int wins;
  final bool isMe;
}

const _rivalNames = [
  'أبو فهد',
  'نورة',
  'سلطان',
  'ريم',
  'خالد',
  'لمى',
  'فيصل',
  'جود',
  'تركي',
  'سارة',
  'عبدالله',
  'هيا',
  'ماجد',
  'دانة',
  'ناصر',
  'شهد',
  'بندر',
  'غلا',
  'راكان',
  'لين',
  'يوسف',
  'مها',
  'عمر',
  'رهف',
  'سعود',
];

/// لوحة المتصدرين. قبل ربط السيرفر تعرض منافسين تجريبيين ثابتين مع نتيجتك الحقيقية.
class Leaderboard {
  /// [game] = null للترتيب العام. [weekly] يقلل النقاط لتمثيل الأسبوع الحالي.
  static List<LeaderEntry> build(
    PlayerProfile? me, {
    String? game,
    bool weekly = false,
  }) {
    final seed =
        (game ?? 'all').codeUnits.fold(7, (a, c) => a * 31 + c) +
        (weekly ? 99 : 0);
    final r = Random(seed);
    final coinGame = coinGames.contains(game);
    final scale = game == null ? 4.0 : (coinGame ? 120.0 : 1.0);
    final list = <LeaderEntry>[
      for (var i = 0; i < _rivalNames.length; i++)
        LeaderEntry(
          name: _rivalNames[i],
          avatar: (i * 5 + seed) % avatars.length,
          points:
              ((weekly ? 400 : 2500) *
                      scale *
                      pow(.88, i) *
                      (0.85 + r.nextDouble() * .3))
                  .round(),
          wins:
              ((weekly ? 4 : 25) * (coinGame ? 3 : scale) * pow(.9, i))
                  .round() +
              r.nextInt(3),
        ),
    ];
    if (me != null) list.add(mine(me, game));
    list.sort((a, b) => b.points.compareTo(a.points));
    return list;
  }

  /// نقاط اللاعب في لوحة [game] (null = العامة).
  static int scoreOf(PlayerProfile me, String? game) => game == null
      ? me.totalPoints + me.totalWins * 100
      : coinGames.contains(game)
      ? me.statsFor(game).points
      : me.statsFor(game).points + me.statsFor(game).wins * 100;

  static int winsOf(PlayerProfile me, String? game) =>
      game == null ? me.totalWins : me.statsFor(game).wins;

  static LeaderEntry mine(PlayerProfile me, String? game) => LeaderEntry(
    name: me.name,
    avatar: me.avatar,
    points: scoreOf(me, game),
    wins: winsOf(me, game),
    isMe: true,
  );

  /// دمج نتيجة السيرفر مع نتيجتي الحالية على الجهاز (الأحدث دائماً).
  /// في الترتيب الأسبوعي نُبقي رقم السيرفر لأنه يُحسب من بداية الأسبوع.
  static List<LeaderEntry> merge(
    List<LeaderEntry> cloud,
    PlayerProfile? me, {
    String? game,
    bool weekly = false,
  }) {
    final list = [
      for (final e in cloud)
        if (!e.isMe) e,
    ];
    if (me != null) {
      final server = cloud.where((e) => e.isMe).firstOrNull;
      final local = mine(me, game);
      list.add(
        weekly
            ? LeaderEntry(
                name: me.name,
                avatar: me.avatar,
                points: server?.points ?? 0,
                wins: server?.wins ?? 0,
                isMe: true,
              )
            : local,
      );
    }
    list.sort((a, b) => b.points.compareTo(a.points));
    return list;
  }
}
