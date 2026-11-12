import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/voice/voice.dart';
import 'package:mojan/games/coin_games/lucky_slots.dart';
import 'package:mojan/games/coin_games/star_league.dart';
import 'package:mojan/games/coin_games/sultan.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coin_games_test.dart' show pumpApp, pumpFor, tapKey, finish;

void main() {
  final acc = Account.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    acc.reset();
    VoiceService.instance.reset();
    await acc.signIn(method: AuthMethod.guest, name: 'موكا');
    acc.earn(10000);
  });

  test('classic slot pays about 95% and 777 is the top line', () {
    expect(classicRtp(), closeTo(.95, .005));
    expect(classicPay(['seven', 'seven', 'seven']), 100);
    expect(classicPay(['cherry', 'bell', 'cherry']), 4);
    expect(classicPay(['cherry', 'bell', 'bar']), 1);
    expect(classicPay(['bell', 'cherry', 'cherry']), 0);
  });

  test('sultan lines, wilds, coins and keys', () {
    expect(sultanLines.map((l) => l.join()).toSet().length, 20);
    expect(sultanLinePay(0, ['lamp', 'wild', 'lamp', 'K', 'K'])!.pay, 60);
    expect(sultanLinePay(0, ['A', 'wild', 'wild', 'wild', 'A'])!.count, 5);
    expect(sultanLinePay(0, ['wild', 'wild', 'wild', 'Q', 'camel'])!.symbol, 'wild');
    expect(sultanLinePay(0, ['wild', 'wild', 'wild', 'camel', 'Q'])!.symbol, 'camel');
    expect(sultanLinePay(0, ['coin', 'coin', 'coin', 'coin', 'coin']), isNull);
    expect(sultanLinePay(0, ['A', 'K', 'A', 'A', 'A']), isNull);
    // العائد بالمحاكاة: الأساسي + قيمة اللفات المجانية ≈95%
    final r = Random(3);
    var paid = 0.0, keys = 0, hits = 0;
    const n = 60000;
    for (var i = 0; i < n; i++) {
      final res = sultanEvaluate(sultanGrid(r));
      paid += res.mult;
      keys += res.keys;
      if (res.mult > 0) hits++;
    }
    final base = paid / n;
    final free = keys / n / sultanKeysNeeded * sultanFreeSpins * base * sultanFreeMult;
    expect(base + free, closeTo(.95, .05));
    expect(hits / n, greaterThan(.25));
  });

  test('star league: every club returns about 95%', () {
    final c = starChances();
    for (var i = 0; i < starClubs.length; i++) {
      expect(c[i] * starClubs[i].mult, closeTo(.95, .01));
    }
    expect(starRing.length, 20);
    for (var k = 0; k < starClubs.length; k++) {
      expect(starRing.where((x) => x == k).length, 2);
    }
    expect({for (var i = 0; i < 20; i++) starRingCell(i)}.length, 20);
  });

  testWidgets('lucky slots: spin takes the bet and pays the middle line', (tester) async {
    await pumpApp(tester, LuckySlotsScreen(random: Random(7), speed: .2));
    final start = acc.profile!.coins;
    await tapKey(tester, 'slots-plus', 50);
    await tapKey(tester, 'slots-spin', 50);
    expect(acc.profile!.coins, start - 200);
    await pumpFor(tester, 1000);
    expect(acc.profile!.statsFor('lucky_slots').played, 1);
    final won = acc.profile!.coins - (start - 200);
    expect([0, 200, 800, ...classicSymbols.map((s) => s.three * 200)], contains(won));
    await finish(tester);
  });

  testWidgets('sultan: spins, auto and free spins after 5 keys', (tester) async {
    SharedPreferences.setMockInitialValues({'sultan_keys': 4});
    await pumpApp(tester, SultanScreen(random: Random(11), speed: .05));
    final start = acc.profile!.coins;
    await tapKey(tester, 'sultan-spin', 50);
    expect(acc.profile!.coins, start - 100);
    await pumpFor(tester, 400);
    expect(acc.profile!.statsFor('sultan').played, 1);
    // تلقائي لين يطلع مفتاح ويفتح اللفات المجانية
    await tapKey(tester, 'sultan-auto', 50);
    for (var i = 0; i < 400 && !find.textContaining('لفات مجانية:').evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('لفات مجانية:'), findsOneWidget);
    await tapKey(tester, 'sultan-auto', 50);
    await pumpFor(tester, 3000);
    await finish(tester);
  });

  testWidgets('star league: bet on clubs and get paid', (tester) async {
    await pumpApp(tester, StarLeagueScreen(betSeconds: 30, speed: .05, random: Random(4)));
    final start = acc.profile!.coins;
    for (var i = 0; i < 10; i++) {
      await tapKey(tester, 'star-club-$i', 50);
    }
    expect(acc.profile!.coins, start - 1000);
    for (var i = 0; i < 200 && find.byKey(const ValueKey('star-result')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const ValueKey('star-result')), findsOneWidget);
    final won = acc.profile!.coins - (start - 1000);
    expect(starClubs.map((c) => c.mult * 100), contains(won));
    expect(acc.profile!.statsFor('star_league').played, 1);
    await finish(tester);
  });
}
