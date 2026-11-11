import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/game_module.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/games/seeko/seeko_screen.dart';
import 'package:mojan/widgets/game_ui.dart';

Future<void> playToEnd(WidgetTester tester, PlayMode mode, String playersLabel) async {
  tester.view.physicalSize = const Size(420 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Directionality(textDirection: TextDirection.rtl, child: SeekoScreen(mode: mode)),
  ));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text(playersLabel));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('ابدأ اللعب'));
  await tester.pump(const Duration(milliseconds: 500));

  var i = 0, card = 0;
  while (find.text('العب مرة أخرى').evaluate().isEmpty) {
    i++;
    expect(i, lessThan(8000));
    final cover = find.byType(PassDeviceCover);
    final dead = find.text('ورقة ميتة: استبدلها');
    final targets = find.byWidgetPredicate((w) => w is SeekoBoardCell && w.target);
    if (cover.evaluate().isNotEmpty) {
      await tester.tap(cover, warnIfMissed: false);
    } else if (dead.evaluate().isNotEmpty) {
      await tester.tap(dead);
    } else if (targets.evaluate().isNotEmpty) {
      await tester.tap(targets.first, warnIfMissed: false);
    } else {
      final cards = find.byType(CardFace);
      if (cards.evaluate().isNotEmpty) {
        await tester.tap(cards.at(card % cards.evaluate().length), warnIfMissed: false);
        card++;
      }
    }
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(tester.takeException(), isNull);
  // ignore: avoid_print
  print('seeko finished after $i steps');
  await tester.tap(find.text('العب مرة أخرى'));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('seeko vs computer plays to the end', (t) => playToEnd(t, PlayMode.vsComputer, '2'));
  testWidgets('seeko local 3 players plays to the end', (t) => playToEnd(t, PlayMode.local, '3'));
  testWidgets('seeko vs computer teams plays to the end', (t) => playToEnd(t, PlayMode.vsComputer, '4 (فريقان)'));
}
