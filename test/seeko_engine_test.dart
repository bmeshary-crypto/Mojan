import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/games/seeko/seeko_engine.dart';

/// يضع ورقة محددة في يد اللاعب الحالي ويرجع رقمها.
int give(SeekoGame g, SeekoCard card) {
  g.hands[g.current].add(card);
  return g.hands[g.current].length - 1;
}

/// أي ورقة عادية موجودة في خانة معينة.
SeekoCard cardFor((int, int) cell) => SeekoBoard.cardAt(cell)!;

void main() {
  test('board has 96 card cells, every non-jack card exactly twice, four free corners', () {
    var count = 0;
    for (var r = 0; r < 10; r++) {
      for (var c = 0; c < 10; c++) {
        final card = SeekoBoard.cardAt((r, c));
        if (SeekoBoard.isCorner((r, c))) {
          expect(card, isNull);
        } else {
          expect(card, isNotNull);
          expect(card!.isJack, isFalse);
          count++;
        }
      }
    }
    expect(count, 96);
    expect(SeekoBoard.cellsOf.length, 48);
    expect(SeekoBoard.cellsOf.values.every((l) => l.length == 2), isTrue);
  });

  test('deal: 7 cards for two players, 6 for three or four', () {
    expect(SeekoGame(playerCount: 2, random: Random(1)).hands.map((h) => h.length), [7, 7]);
    expect(SeekoGame(playerCount: 3, random: Random(1)).hands.map((h) => h.length), [6, 6, 6]);
    final g4 = SeekoGame(playerCount: 4, random: Random(1));
    expect(g4.teamCount, 2);
    expect(g4.teamOf(2), 0);
    expect(g4.sequencesToWin, 2);
    expect(SeekoGame(playerCount: 3, random: Random(1)).sequencesToWin, 1);
  });

  test('normal card places on its own empty cells only and draws a card', () {
    final g = SeekoGame(playerCount: 2, random: Random(3));
    final cell = (3, 4);
    final i = give(g, cardFor(cell));
    final handBefore = g.hands[0].length;
    final targets = g.targetsFor(g.hands[0][i], 0);
    expect(targets, contains(cell));
    expect(targets.length, 2);
    g.play(SeekoPlay(handIndex: i, cell: cell, type: SeekoActionType.place));
    expect(g.chips[3][4], 0);
    expect(g.hands[0].length, handBefore, reason: 'played one, drew one');
    expect(g.current, 1);
  });

  test('two-eyed jack goes anywhere empty, one-eyed jack removes opponent chip', () {
    final g = SeekoGame(playerCount: 2, random: Random(4));
    var i = give(g, const SeekoCard('J', 'D'));
    expect(g.targetsFor(g.hands[0][i], 0).length, 96);
    g.play(SeekoPlay(handIndex: i, cell: (5, 5), type: SeekoActionType.place));
    expect(g.chips[5][5], 0);

    i = give(g, const SeekoCard('J', 'S'));
    expect(g.targetsFor(g.hands[1][i], 1), [(5, 5)]);
    g.play(SeekoPlay(handIndex: i, cell: (5, 5), type: SeekoActionType.remove));
    expect(g.chips[5][5], isNull);
  });

  test('five in a row makes a sequence and locks it; corners count', () {
    final g = SeekoGame(playerCount: 2, random: Random(5));
    // صف أفقي في الصف 0 يستخدم الزاوية (0,0)
    for (var c = 1; c <= 3; c++) {
      g.chips[0][c] = 0;
    }
    final i = give(g, const SeekoCard('J', 'C'));
    final res = g.play(SeekoPlay(handIndex: i, cell: (0, 4), type: SeekoActionType.place));
    expect(res.newSequences.length, 1);
    expect(g.sequenceCount[0], 1);
    expect(g.locked.contains((0, 2)), isTrue);
    // لا يمكن إزالة قطعة من صف مكتمل
    final j = give(g, const SeekoCard('J', 'H'));
    expect(g.targetsFor(g.hands[1][j], 1).contains((0, 2)), isFalse);
  });

  test('two sequences win in a two player game; a second may share one chip', () {
    final g = SeekoGame(playerCount: 2, random: Random(6));
    for (var c = 1; c <= 4; c++) {
      g.chips[2][c] = 0;
    }
    var i = give(g, const SeekoCard('J', 'C'));
    g.play(SeekoPlay(handIndex: i, cell: (2, 5), type: SeekoActionType.place));
    expect(g.sequenceCount[0], 1);
    // اللاعب الثاني يلعب أي حركة
    final p1 = g.legalPlays().firstWhere((p) => p.type == SeekoActionType.place && p.cell.$1 > 5);
    g.play(p1);
    // صف عمودي يشارك الخانة (2,5)
    for (var r = 3; r <= 5; r++) {
      g.chips[r][5] = 0;
    }
    i = give(g, const SeekoCard('J', 'D'));
    g.play(SeekoPlay(handIndex: i, cell: (6, 5), type: SeekoActionType.place));
    expect(g.sequenceCount[0], 2);
    expect(g.phase, SeekoPhase.gameOver);
    expect(g.winner, 0);
  });

  test('extending a sequence by one does not count a new sequence', () {
    final g = SeekoGame(playerCount: 2, random: Random(7));
    for (var c = 2; c <= 5; c++) {
      g.chips[4][c] = 0;
    }
    var i = give(g, const SeekoCard('J', 'C'));
    g.play(SeekoPlay(handIndex: i, cell: (4, 6), type: SeekoActionType.place));
    expect(g.sequenceCount[0], 1);
    g.play(g.legalPlays().firstWhere((p) => p.type == SeekoActionType.place && p.cell.$1 > 6));
    i = give(g, const SeekoCard('J', 'C'));
    g.play(SeekoPlay(handIndex: i, cell: (4, 7), type: SeekoActionType.place));
    expect(g.sequenceCount[0], 1);
  });

  test('dead card can be exchanged once per turn', () {
    final g = SeekoGame(playerCount: 2, random: Random(8));
    final card = cardFor((1, 1));
    for (final p in SeekoBoard.cellsOf[card]!) {
      g.chips[p.$1][p.$2] = 1;
    }
    final i = give(g, card);
    expect(g.canExchange(i), isTrue);
    g.exchangeDead(i);
    expect(g.hands[0].contains(card), isFalse);
    final i2 = give(g, card);
    expect(g.canExchange(i2), isFalse, reason: 'only once per turn');
  });

  test('random AI games end without errors', () {
    for (var seed = 0; seed < 40; seed++) {
      final g = SeekoGame(playerCount: 2 + seed % 3, random: Random(seed));
      var steps = 0;
      while (g.phase == SeekoPhase.playing) {
        final a = g.chooseAi();
        if (a.exchange != null) {
          g.exchangeDead(a.exchange!);
          continue;
        }
        g.play(a.play!);
        steps++;
        expect(steps, lessThan(400));
      }
      if (g.winner != null) {
        expect(g.sequenceCount[g.winner!], greaterThanOrEqualTo(g.sequencesToWin));
      }
    }
  });
}
