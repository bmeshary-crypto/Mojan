import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/games/ludo/ludo_engine.dart';

Map<LudoColor, Map<LudoItem, int>> kit(List<LudoColor> ps, [int n = 1]) =>
    {for (final p in ps) p: {for (final i in LudoItem.values) i: n}};

LudoGame power({bool teams = false, int n = 1}) {
  final ps = teams ? LudoColor.values.toList() : [LudoColor.red, LudoColor.yellow];
  return LudoGame(players: ps, power: true, teams: teams, items: kit(ps, n), random: Random(3));
}

void main() {
  test('items do nothing outside power mode', () {
    final g = LudoGame(players: [LudoColor.red, LudoColor.yellow], items: kit([LudoColor.red]));
    expect(g.useItem(LudoItem.shield), isFalse);
  });

  test('dice control sets the roll and is consumed', () {
    final g = power();
    expect(g.useItem(LudoItem.diceControl), isFalse, reason: 'needs a value');
    expect(g.useItem(LudoItem.diceControl, value: 6), isTrue);
    expect(g.itemCount(LudoColor.red, LudoItem.diceControl), 0);
    expect(g.roll(), isTrue);
    expect(g.dice, 6);
    expect(g.useItem(LudoItem.diceControl, value: 6), isFalse, reason: 'only before rolling');
  });

  test('double distance moves twice the dice and gives no six bonus', () {
    final g = power();
    final t = g.tokens[LudoColor.red]![0]..pos = 3;
    expect(g.useItem(LudoItem.doubleDistance), isTrue);
    g.roll(6);
    final m = g.legalMoves.firstWhere((m) => m.token == t);
    expect(m.to, 15);
    expect(g.legalMoves.any((m) => m.from == LudoGeo.yard), isTrue, reason: 'a real six still opens the yard');
    final r = g.move(m);
    expect(r.extraTurn, isFalse);
    expect(g.current, LudoColor.yellow);
    expect(g.doubleActive, isFalse);
  });

  test('double distance cannot overshoot home', () {
    final g = power();
    g.tokens[LudoColor.red]![0].pos = 50;
    g.useItem(LudoItem.doubleDistance);
    expect(g.roll(4), isFalse, reason: '50 + 8 > 56');
  });

  test('shield protects tokens until the owner plays again', () {
    final g = power();
    final red = g.tokens[LudoColor.red]![0]..pos = 10; // global 50
    expect(g.useItem(LudoItem.shield), isTrue);
    g.roll(1); // red moves 10 -> 11 (global 51)
    g.move(g.legalMoves.firstWhere((m) => m.token == red));
    // yellow start is global 14: yellow pos 37 is global 51
    final y = g.tokens[LudoColor.yellow]![0]..pos = 35;
    g.roll(2);
    final r = g.move(g.legalMoves.firstWhere((m) => m.token == y));
    expect(r.captured, isEmpty);
    expect(red.pos, 11);
    expect(g.shielded, isEmpty, reason: 'shield ends when red’s turn comes back');
  });

  test('landing on a bonus tile gives an extra roll', () {
    final g = power();
    // red start global 40 → global 44 is red pos 4
    final t = g.tokens[LudoColor.red]![0]..pos = 1;
    g.roll(3);
    final r = g.move(g.legalMoves.firstWhere((m) => m.token == t));
    expect(r.bonusRoll, isTrue);
    expect(r.extraTurn, isTrue);
    expect(g.current, LudoColor.red);
  });

  test('team up: allies never capture each other and the team wins together', () {
    final g = power(teams: true);
    expect(LudoGame.teamOf(LudoColor.red), LudoGame.teamOf(LudoColor.yellow));
    expect(g.allies(LudoColor.green, LudoColor.blue), isTrue);
    // red token on yellow's square: yellow start global 14 = red pos 26
    final y = g.tokens[LudoColor.yellow]![0]..pos = 0;
    final r = g.tokens[LudoColor.red]![0]..pos = 24;
    g.roll(2);
    final res = g.move(g.legalMoves.firstWhere((m) => m.token == r));
    expect(res.captured, isEmpty);
    expect(y.pos, 0);

    final g2 = LudoGame(players: LudoColor.values.toList(), teams: true, random: Random(1));
    for (final t in g2.tokens[LudoColor.yellow]!) {
      t.pos = 56;
    }
    for (final t in g2.tokens[LudoColor.red]!.skip(1)) {
      t.pos = 56;
    }
    g2.tokens[LudoColor.red]![0].pos = 55;
    g2.roll(1);
    g2.move(g2.legalMoves.single);
    expect(g2.phase, LudoPhase.gameOver);
    expect(g2.winnerTeam, 0);
    expect(g2.ranking.take(2).toSet(), {LudoColor.red, LudoColor.yellow});
    expect(g2.ranking.length, 4);
  });

  test('random power and team games with AI items always finish', () {
    for (var seed = 0; seed < 40; seed++) {
      final teams = seed.isEven;
      final ps = teams ? LudoColor.values.toList() : LudoColor.values.take(2 + seed % 3).toList();
      final g = LudoGame(players: ps, power: true, teams: teams, items: kit(ps, 2), random: Random(seed));
      var steps = 0;
      while (g.phase != LudoPhase.gameOver) {
        g.aiUseItem();
        if (g.roll()) g.move(g.chooseAiMove());
        steps++;
        expect(steps, lessThan(5000));
      }
      expect(g.ranking.toSet().length, ps.length);
      if (teams) expect(g.winnerTeam, isNotNull);
    }
  });
}
