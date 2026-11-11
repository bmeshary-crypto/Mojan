import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/game_module.dart';
import 'package:mojan/core/shop.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/games/ludo/ludo_board.dart';
import 'package:mojan/games/ludo/ludo_engine.dart';
import 'package:mojan/games/ludo/ludo_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openLudo(WidgetTester tester, PlayMode mode) async {
  tester.view.physicalSize = const Size(420 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Directionality(textDirection: TextDirection.rtl, child: LudoScreen(key: UniqueKey(), mode: mode)),
  ));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapKey(WidgetTester tester, String key, [int ms = 300]) async {
  final f = find.byKey(ValueKey(key));
  if (f.evaluate().isNotEmpty) await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first);
  await pumpFor(tester, ms);
}

/// يلعب حتى تظهر نتيجة المباراة. [onHumanRoll] يُستدعى قبل رمي النرد.
Future<int> playToEnd(WidgetTester tester, {Future<void> Function(int step)? onHumanRoll}) async {
  var i = 0;
  while (find.byKey(const ValueKey('ludo-again')).evaluate().isEmpty) {
    i++;
    expect(i, lessThan(30000), reason: 'game should end');
    final movable = find.byWidgetPredicate((w) => w is LudoPawn && w.highlight);
    final dice = find.byKey(const ValueKey('ludo-dice'));
    if (movable.evaluate().isNotEmpty) {
      await tester.tap(movable.first, warnIfMissed: false);
    } else if (dice.evaluate().isNotEmpty) {
      final ready = find.textContaining('اضغط على النرد').evaluate().isNotEmpty;
      if (onHumanRoll != null && ready) await onHumanRoll(i);
      await tester.tap(dice.first, warnIfMissed: false);
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(tester.takeException(), isNull);
  return i;
}

Future<void> finish(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Account.instance.reset();
  });

  testWidgets('vs computer quick game plays to the end and restarts', (tester) async {
    await openLudo(tester, PlayMode.vsComputer);
    expect(find.byKey(const ValueKey('bet-plus')), findsNothing, reason: 'no betting without an account');
    await tapKey(tester, 'ludo-players-3');
    await tapKey(tester, 'ludo-quick');
    await tapKey(tester, 'ludo-start', 600);
    await playToEnd(tester);
    await tapKey(tester, 'ludo-again', 600);
    expect(find.byKey(const ValueKey('ludo-dice')), findsWidgets);
    await finish(tester);
  });

  testWidgets('leaving any unfinished game asks first; cancel keeps playing', (tester) async {
    await openLudo(tester, PlayMode.local);
    await tapKey(tester, 'ludo-start', 800);
    await tapKey(tester, 'ludo-setup', 600);
    expect(find.text('هل فعلاً تود الانسحاب من اللعب؟'), findsOneWidget);
    await tapKey(tester, 'cancel-leave', 600);
    expect(find.byKey(const ValueKey('ludo-dice')), findsWidgets);
    await tapKey(tester, 'ludo-back', 600);
    expect(find.text('هل فعلاً تود الانسحاب من اللعب؟'), findsOneWidget);
    await tapKey(tester, 'confirm-leave', 800);
    await finish(tester);
  });

  testWidgets('local 4 player quick game plays to the end', (tester) async {
    await openLudo(tester, PlayMode.local);
    await tapKey(tester, 'ludo-players-4');
    await tapKey(tester, 'ludo-quick');
    await tapKey(tester, 'ludo-start', 600);
    await playToEnd(tester);
    await finish(tester);
  });

  testWidgets('help dialog shows classic, power and team tabs', (tester) async {
    await openLudo(tester, PlayMode.vsComputer);
    await tapKey(tester, 'ludo-help', 600);
    expect(find.text('القواعد'), findsOneWidget);
    await tester.tap(find.text('باور').last);
    await pumpFor(tester, 800);
    expect(find.text('وضع الباور'), findsOneWidget);
    await tester.tap(find.text('فرق'));
    await pumpFor(tester, 800);
    expect(find.text('2 ضد 2'), findsWidgets);
    await finish(tester);
  });

  testWidgets('power 2v2 with a bet: entry is charged, items work, prize paid on win', (tester) async {
    final acc = Account.instance;
    await acc.signIn(method: AuthMethod.guest, name: 'لاعب');
    acc.earn(1000); // 1500
    acc.buy(shopItem('item.shield')); // 1100، درع في الحقيبة
    acc.equip('dice.classic');
    await openLudo(tester, PlayMode.vsComputer);
    await tapKey(tester, 'ludo-teams');
    await tapKey(tester, 'ludo-power');
    expect(find.text('معك في المباراة: أداة مجانية من كل نوع + حقيبتك'), findsOneWidget);
    await tapKey(tester, 'bet-plus'); // 200
    await tapKey(tester, 'bet-plus'); // 500
    expect(find.text('${ludoPrize(500, 4, teams: true)}'), findsWidgets);
    await tapKey(tester, 'ludo-start', 800);
    expect(acc.profile!.coins, 600, reason: 'entry is charged at the start');

    var usedShield = false, usedControl = false, usedDouble = false;
    await playToEnd(tester, onHumanRoll: (step) async {
      if (!usedShield) {
        usedShield = true;
        await tapKey(tester, 'use-shield', 400);
        expect(find.textContaining('الدرع مفعّل'), findsOneWidget);
      } else if (!usedControl) {
        usedControl = true;
        await tapKey(tester, 'use-diceControl', 600);
        await tapKey(tester, 'pick-6', 600);
        expect(find.textContaining('سيعطيك 6'), findsOneWidget);
      } else if (!usedDouble && step > 40) {
        usedDouble = true;
        await tapKey(tester, 'use-doubleDistance', 400);
        expect(find.text('×2'), findsOneWidget);
      }
    });
    expect(usedShield && usedControl, isTrue);
    expect(find.byKey(const ValueKey('bet-result')), findsOneWidget);
    final won = find.text('فريقك فاز!').evaluate().isNotEmpty;
    final stats = acc.profile!.statsFor('ludo');
    expect(stats.played, 1);
    expect(stats.wins, won ? 1 : 0);
    final rewardCoins = won ? 100 : 25;
    final prize = ludoPrize(500, 4, teams: true);
    expect(find.text(won ? 'ربحت الرهان +$prize' : 'خسرت الرهان -500'), findsOneWidget);
    // العملات = بعد الدخول + جائزة الرهان + مكافأة المباراة (+ مكافآت الإنجازات بمضاعفات 50)
    final extra = acc.profile!.coins - (600 + rewardCoins + (won ? prize : 0));
    expect(extra >= 0 && extra % 50 == 0, isTrue, reason: 'extra=$extra');
    // الدرع المجاني استُخدم أولاً فبقي درع الحقيبة
    expect(acc.profile!.itemCount(LudoItem.shield), 1);
    await finish(tester);
  });

  testWidgets('leaving a bet match forfeits the entry; not enough coins blocks the start', (tester) async {
    final acc = Account.instance;
    await acc.signIn(method: AuthMethod.guest, name: 'لاعب');
    await openLudo(tester, PlayMode.vsComputer);
    await tapKey(tester, 'bet-plus'); // 200
    await tapKey(tester, 'ludo-start', 800);
    expect(acc.profile!.coins, 300);
    await tester.pump(const Duration(seconds: 3));
    await tapKey(tester, 'ludo-back', 600);
    expect(find.text('هل فعلاً تود الانسحاب من اللعب؟'), findsOneWidget);
    await tapKey(tester, 'confirm-leave', 800);
    expect(acc.profile!.statsFor('ludo').played, 1);
    expect(acc.profile!.statsFor('ludo').wins, 0);
    final before = acc.profile!.coins;

    await openLudo(tester, PlayMode.vsComputer);
    await pumpFor(tester, 1000);
    for (var i = 0; i < 4; i++) {
      await tapKey(tester, 'bet-plus'); // 2000
    }
    expect(find.text('${ludoPrize(2000, 2)}'), findsOneWidget);
    expect(find.text('عملاتك لا تكفي، اذهب للمتجر'), findsOneWidget);
    await tapKey(tester, 'ludo-start', 600);
    expect(find.byKey(const ValueKey('ludo-dice')), findsNothing);
    expect(acc.profile!.coins, before, reason: 'nothing charged');
    await finish(tester);
  });
}
