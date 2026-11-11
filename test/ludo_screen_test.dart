import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/game_module.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/games/ludo/ludo_board.dart';
import 'package:mojan/games/ludo/ludo_screen.dart';

Future<void> playToEnd(WidgetTester tester, PlayMode mode, {required String playersLabel}) async {
  tester.view.physicalSize = const Size(420 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Directionality(textDirection: TextDirection.rtl, child: LudoScreen(mode: mode)),
  ));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.tap(find.text(playersLabel));
  await tester.tap(find.text('سريع (قطعتان)'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('ابدأ اللعب'));
  await tester.pump(const Duration(milliseconds: 600));

  var i = 0;
  while (find.text('العب مرة أخرى').evaluate().isEmpty) {
    i++;
    expect(i, lessThan(20000), reason: 'game should end');
    final movable = find.byWidgetPredicate((w) => w is LudoPawn && w.highlight);
    if (movable.evaluate().isNotEmpty) {
      await tester.tap(movable.first, warnIfMissed: false);
    } else if (find.byType(DiceFace).evaluate().isNotEmpty) {
      await tester.tap(find.byType(DiceFace).first, warnIfMissed: false);
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(tester.takeException(), isNull);
  await tester.tap(find.text('العب مرة أخرى'));
  await tester.pump(const Duration(milliseconds: 600));
  expect(find.byType(DiceFace), findsWidgets);
  // ignore: avoid_print
  print('game finished after $i steps');
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('vs computer quick game plays to the end', (tester) async {
    await playToEnd(tester, PlayMode.vsComputer, playersLabel: '3');
  });

  testWidgets('local 4 player quick game plays to the end', (tester) async {
    await playToEnd(tester, PlayMode.local, playersLabel: '4');
  });
}
