import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/games/truth_dare/truth_dare_content.dart';
import 'package:mojan/games/truth_dare/truth_dare_engine.dart';

void main() {
  test('every level has enough unique content', () {
    for (final l in TdLevel.values) {
      expect(tdTruths[l]!.length, greaterThanOrEqualTo(25));
      expect(tdDares[l]!.length, greaterThanOrEqualTo(25));
      expect(tdTruths[l]!.toSet().length, tdTruths[l]!.length);
      expect(tdDares[l]!.toSet().length, tdDares[l]!.length);
    }
  });

  test('spin never picks the same player twice in a row', () {
    final g = TruthDareGame(names: ['أ', 'ب', 'ج'], level: TdLevel.family, random: Random(1));
    int? last;
    for (var i = 0; i < 200; i++) {
      final p = g.spin();
      expect(p, isNot(last));
      g.draw(TdChoice.truth);
      g.resolve(completed: true);
      last = p;
    }
  });

  test('prompts do not repeat until the pool is exhausted', () {
    final g = TruthDareGame(names: ['أ', 'ب'], level: TdLevel.friends, random: Random(2));
    final seen = <String>{};
    final n = tdDares[TdLevel.friends]!.length;
    for (var i = 0; i < n; i++) {
      g.spin();
      expect(seen.add(g.draw(TdChoice.dare)), isTrue);
      g.resolve(completed: true);
    }
    g.spin();
    expect(seen.contains(g.draw(TdChoice.dare)), isTrue, reason: 'reshuffled after exhaustion');
  });

  test('custom prompts are included and scoring works', () {
    final g = TruthDareGame(
      names: ['أ', 'ب'],
      level: TdLevel.family,
      customTruths: ['سؤالي الخاص'],
      random: Random(3),
    );
    final all = <String>{};
    for (var i = 0; i < 30; i++) {
      g.spin();
      all.add(g.draw(TdChoice.truth));
      g.resolve(completed: i.isEven);
    }
    expect(all, contains('سؤالي الخاص'));

    final g2 = TruthDareGame(names: ['أ', 'ب'], level: TdLevel.bold, random: Random(4));
    final p = g2.spin();
    g2.draw(TdChoice.dare);
    g2.resolve(completed: true);
    expect(g2.players[p].score, 2);
    final q = g2.spin();
    g2.draw(TdChoice.truth);
    g2.resolve(completed: false);
    expect(g2.players[q].score, -1);
    expect(g2.leaderboard.first.score, 2);
  });
}
