import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/core/voice/voice.dart';
import 'package:mojan/games/coin_games/fruits.dart';
import 'package:mojan/games/coin_games/pegs.dart';
import 'package:mojan/games/coin_games/rocket.dart';
import 'package:mojan/games/coin_games/treasure.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tapKey(WidgetTester tester, String key, [int ms = 300]) async {
  final f = find.byKey(ValueKey(key));
  expect(f, findsWidgets, reason: key);
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first);
  await pumpFor(tester, ms);
}

Future<void> pumpApp(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(420 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Directionality(textDirection: TextDirection.rtl, child: home),
  ));
  await pumpFor(tester, 300);
}

Future<void> finish(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  final acc = Account.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    acc.reset();
    VoiceService.instance.reset();
    await acc.signIn(method: AuthMethod.guest, name: 'موكا');
    acc.earn(10000);
  });

  test('odds: every game returns about 97% and the top prizes are rare', () {
    // الفواكه: كل فاكهة ترجع نفس النسبة.
    final c = fruitChances();
    expect(c.reduce((a, b) => a + b), closeTo(1, 1e-9));
    for (var i = 0; i < fruitSlots.length; i++) {
      expect(c[i] * fruitSlots[i].mult, closeTo(.972, .01));
    }
    expect(fruitSlots.map((f) => f.mult).reduce(min), 5);
    expect(fruitSlots.map((f) => f.mult).reduce(max), 45);
    // المسامير
    for (final r in PegRisk.values) {
      expect(r.rtp, closeTo(.97, .006), reason: r.name);
      expect(r.slots.length, pegRows + 1);
    }
    expect(PegRisk.high.slots.first, 1000);
    // الكنز: العائد ثابت مهما كان وقت السحب.
    for (final l in TreasureLevel.values) {
      for (var s = 1; s <= treasureFloors; s++) {
        final survive = pow((l.boxes - 1) / l.boxes, s);
        expect(survive * l.multAt(s), closeTo(.97, .01));
      }
    }
    // الصاروخ: نسبة الوصول لـ ×2 تقريباً 48.5%.
    final r = Random(1);
    final pts = [for (var i = 0; i < 40000; i++) rocketCrashPoint(r)];
    expect(pts.every((p) => p >= 1 && p <= rocketMax), isTrue);
    expect(pts.where((p) => p >= 2).length / pts.length, closeTo(.485, .015));
  });

  testWidgets('fruits: bet, spin, get paid when the pointer stops on my fruit', (tester) async {
    await pumpApp(tester, FruitsScreen(betSeconds: 30, speed: .05, random: Random(4)));
    final start = acc.profile!.coins;
    // راهن 100 على كل الفواكه: لازم يكسب واحد منها.
    for (var i = 0; i < 8; i++) {
      await tapKey(tester, 'fruit-$i', 50);
    }
    expect(acc.profile!.coins, start - 800);
    for (var i = 0; i < 100 && find.byKey(const ValueKey('fruit-result')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const ValueKey('fruit-result')), findsOneWidget);
    final won = acc.profile!.coins - (start - 800);
    expect(fruitSlots.map((f) => f.mult * 100), contains(won));
    expect(acc.profile!.statsFor('fruits').played, 1);
    await finish(tester);
  });

  testWidgets('treasure: open boxes, cash out or lose to the monster', (tester) async {
    await pumpApp(tester, TreasureScreen(random: Random(2)));
    final start = acc.profile!.coins;
    await tapKey(tester, 'treasure-start');
    expect(acc.profile!.coins, start - 100);
    // افتح صناديق لين نسحب أو نخسر.
    var floor = 0;
    while (find.byKey(const ValueKey('treasure-outcome')).evaluate().isEmpty && floor < treasureFloors) {
      await tapKey(tester, 'box-$floor-0', 100);
      floor++;
      if (floor == 2 && find.byKey(const ValueKey('treasure-outcome')).evaluate().isEmpty) {
        await tapKey(tester, 'treasure-cashout');
        expect(acc.profile!.coins, start - 100 + (100 * TreasureLevel.medium.multAt(2)).floor());
        break;
      }
    }
    expect(find.byKey(const ValueKey('treasure-outcome')), findsOneWidget);
    expect(acc.profile!.statsFor('treasure').played, 1);
    await finish(tester);
  });

  testWidgets('pegs: a dropped ball lands and pays its slot', (tester) async {
    await pumpApp(tester, PegsScreen(random: Random(5), rowMs: 20));
    final start = acc.profile!.coins;
    await tapKey(tester, 'pegs-drop', 50);
    await tapKey(tester, 'pegs-drop', 50);
    expect(acc.profile!.coins, start - 200);
    await pumpFor(tester, 1200);
    expect(acc.profile!.statsFor('pegs').played, 2);
    expect(find.byKey(const ValueKey('pegs-last')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('rocket: bet, fly, cash out (or explode)', (tester) async {
    await pumpApp(tester, RocketScreen(random: Random(9), waitSeconds: 2, timeScale: 1));
    final start = acc.profile!.coins;
    await tapKey(tester, 'rocket-bet');
    expect(acc.profile!.coins, start - 100);
    await pumpFor(tester, 2000);
    if (find.byKey(const ValueKey('rocket-cashout')).evaluate().isNotEmpty) {
      await tapKey(tester, 'rocket-cashout', 100);
      expect(acc.profile!.coins, greaterThan(start - 100));
    } else {
      expect(find.byKey(const ValueKey('rocket-crashed')), findsOneWidget);
    }
    expect(acc.profile!.statsFor('rocket').played, 1);
    await finish(tester);
  });
}
