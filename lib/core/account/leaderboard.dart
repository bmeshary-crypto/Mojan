import 'dart:math';

import 'account.dart';

class LeaderEntry {
  const LeaderEntry({required this.name, required this.avatar, required this.points, required this.wins, this.isMe = false});
  final String name;
  final int avatar;
  final int points;
  final int wins;
  final bool isMe;
}

const _rivalNames = [
  'أبو فهد', 'نورة', 'سلطان', 'ريم', 'خالد', 'لمى', 'فيصل', 'جود', 'تركي', 'سارة',
  'عبدالله', 'هيا', 'ماجد', 'دانة', 'ناصر', 'شهد', 'بندر', 'غلا', 'راكان', 'لين',
  'يوسف', 'مها', 'عمر', 'رهف', 'سعود',
];

/// لوحة المتصدرين. قبل ربط السيرفر تعرض منافسين تجريبيين ثابتين مع نتيجتك الحقيقية.
class Leaderboard {
  /// [game] = null للترتيب العام. [weekly] يقلل النقاط لتمثيل الأسبوع الحالي.
  static List<LeaderEntry> build(PlayerProfile? me, {String? game, bool weekly = false}) {
    final seed = (game ?? 'all').codeUnits.fold(7, (a, c) => a * 31 + c) + (weekly ? 99 : 0);
    final r = Random(seed);
    final scale = game == null ? 4.0 : 1.0;
    final list = <LeaderEntry>[
      for (var i = 0; i < _rivalNames.length; i++)
        LeaderEntry(
          name: _rivalNames[i],
          avatar: (i * 5 + seed) % avatars.length,
          points: ((weekly ? 400 : 2500) * scale * pow(.88, i) * (0.85 + r.nextDouble() * .3)).round(),
          wins: ((weekly ? 4 : 25) * scale * pow(.9, i)).round() + r.nextInt(3),
        ),
    ];
    if (me != null) {
      final points = game == null ? me.totalPoints + me.totalWins * 100 : me.statsFor(game).points + me.statsFor(game).wins * 100;
      final wins = game == null ? me.totalWins : me.statsFor(game).wins;
      list.add(LeaderEntry(name: me.name, avatar: me.avatar, points: points, wins: wins, isMe: true));
    }
    list.sort((a, b) => b.points.compareTo(a.points));
    return list;
  }
}
