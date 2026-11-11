import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/games/ludo/ludo_engine.dart';

LudoGame twoPlayer({LudoRules rules = const LudoRules()}) =>
    LudoGame(players: [LudoColor.red, LudoColor.yellow], rules: rules, random: Random(1));

void main() {
  test('starts are 13 apart and stars are safe', () {
    expect(LudoGeo.globalIndex(LudoColor.green, 0), 1);
    expect(LudoGeo.globalIndex(LudoColor.yellow, 0), 14);
    expect(LudoGeo.globalIndex(LudoColor.blue, 0), 27);
    expect(LudoGeo.globalIndex(LudoColor.red, 0), 40);
    expect(LudoGeo.globalIndex(LudoColor.red, 50), 38);
    expect(LudoGeo.globalIndex(LudoColor.red, 51), isNull);
  });

  test('needs a six to leave the yard; otherwise turn passes', () {
    final g = twoPlayer();
    expect(g.roll(3), isFalse);
    expect(g.current, LudoColor.yellow);
    expect(g.roll(6), isTrue);
    expect(g.legalMoves.length, 4);
    final r = g.move(g.legalMoves.first);
    expect(r.move.token.pos, 0);
    expect(r.extraTurn, isTrue, reason: 'six gives another roll');
    expect(g.current, LudoColor.yellow);
  });

  test('exact roll needed to finish', () {
    final g = twoPlayer();
    final t = g.tokens[LudoColor.red]![0]..pos = 54;
    expect(g.movesFor(LudoColor.red, 3), isEmpty);
    final ms = g.movesFor(LudoColor.red, 2);
    expect(ms.single.token, t);
    expect(ms.single.to, LudoGeo.finished);
  });

  test('capture sends opponent home and gives extra turn', () {
    final g = twoPlayer();
    // الأصفر أمام الأحمر بثلاث خانات على خانة غير آمنة
    final red = g.tokens[LudoColor.red]![0]..pos = 2; // global 42
    final yellow = g.tokens[LudoColor.yellow]![0]..pos = 31; // global 45
    expect(LudoGeo.isSafeGlobal(45), isFalse);
    g.roll(3);
    final m = g.legalMoves.firstWhere((m) => m.token == red);
    final r = g.move(m);
    expect(r.captured, [yellow]);
    expect(yellow.inYard, isTrue);
    expect(r.extraTurn, isTrue);
    expect(g.current, LudoColor.red);
  });

  test('no capture on a safe square', () {
    final g = twoPlayer();
    final red = g.tokens[LudoColor.red]![0]..pos = 5; // global 45
    final yellow = g.tokens[LudoColor.yellow]![0]..pos = 34; // global 48 (star)
    expect(LudoGeo.isSafeGlobal(48), isTrue);
    g.roll(3);
    final r = g.move(g.legalMoves.firstWhere((m) => m.token == red));
    expect(r.captured, isEmpty);
    expect(yellow.pos, 34);
  });

  test('three sixes in a row loses the turn', () {
    final g = twoPlayer();
    g.tokens[LudoColor.red]![0].pos = 0;
    g.roll(6);
    g.move(g.legalMoves.firstWhere((m) => m.token.pos == 0));
    g.roll(6);
    g.move(g.legalMoves.firstWhere((m) => m.token.pos == 6));
    expect(g.current, LudoColor.red);
    expect(g.roll(6), isFalse);
    expect(g.current, LudoColor.yellow);
  });

  test('a player finishing all tokens ends a two player game', () {
    final g = twoPlayer(rules: const LudoRules(tokensPerPlayer: 2));
    g.tokens[LudoColor.red]![0].pos = LudoGeo.finished;
    g.tokens[LudoColor.red]![1].pos = 53;
    g.roll(3);
    g.move(g.legalMoves.single);
    expect(g.phase, LudoPhase.gameOver);
    expect(g.ranking, [LudoColor.red, LudoColor.yellow]);
  });

  test('four player game continues after first finisher and skips them', () {
    final g = LudoGame(
      players: LudoColor.values,
      rules: const LudoRules(tokensPerPlayer: 1),
      random: Random(2),
    );
    g.tokens[LudoColor.red]![0].pos = 55;
    g.roll(1);
    final r = g.move(g.legalMoves.single);
    expect(r.playerFinished, isTrue);
    expect(r.extraTurn, isFalse);
    expect(g.phase, LudoPhase.waitingRoll);
    expect(g.current, LudoColor.green);
    for (var i = 0; i < 3; i++) {
      g.roll(1);
    }
    expect(g.current, LudoColor.green, reason: 'red is skipped');
  });

  test('AI prefers capturing and finishing', () {
    final g = twoPlayer();
    final a = g.tokens[LudoColor.red]![0]..pos = 2; // global 42
    g.tokens[LudoColor.red]![1].pos = 20;
    g.tokens[LudoColor.yellow]![0].pos = 31; // global 45
    g.roll(3);
    expect(g.chooseAiMove().token, a);

    final g2 = twoPlayer();
    final f = g2.tokens[LudoColor.red]![0]..pos = 52;
    g2.tokens[LudoColor.red]![1].pos = 10;
    g2.roll(4);
    expect(g2.chooseAiMove().token, f);
  });

  test('random AI games always finish without errors', () {
    for (var seed = 0; seed < 60; seed++) {
      final players = LudoColor.values.take(2 + seed % 3).toList();
      final g = LudoGame(players: players, random: Random(seed));
      var steps = 0;
      while (g.phase != LudoPhase.gameOver) {
        if (g.roll()) g.move(g.chooseAiMove());
        steps++;
        expect(steps, lessThan(5000));
        for (final t in g.allTokens) {
          expect(t.pos, inInclusiveRange(-1, 56));
        }
      }
      expect(g.ranking.toSet().length, players.length);
    }
  });
}
