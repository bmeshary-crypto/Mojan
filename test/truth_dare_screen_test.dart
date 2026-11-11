import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/game_module.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/games/truth_dare/truth_dare_screen.dart';

void main() {
  testWidgets('truth or dare full flow: add player, spin, choose, resolve, finish', (tester) async {
    tester.view.physicalSize = const Size(420 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const Directionality(textDirection: TextDirection.rtl, child: TruthDareScreen(mode: PlayMode.local)),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField).first, 'سارة');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('سارة'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'سؤال خاص');
    await tester.tap(find.text('+ صراحة'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('ابدأ اللعب'));
    await tester.pump(const Duration(milliseconds: 800));

    for (var round = 0; round < 8; round++) {
      await tester.tap(find.byKey(const ValueKey('td-bottle')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('تدور…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3500));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('VS'), findsOneWidget);
      // اضغط على أعلى اليمين (صراحة) أو أسفل اليسار (جرأة)
      final r = tester.getRect(find.byKey(const ValueKey('td-split')));
      await tester.tapAt(round.isEven ? r.topRight + const Offset(-40, 60) : r.bottomLeft + const Offset(40, -60));
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text(round.isEven ? 'صراحة' : 'جرأة'), findsWidgets);
      if (round % 3 == 2) {
        await tester.tap(find.text('أرفض ✗'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.text('تم، الدور التالي'));
      } else {
        await tester.tap(find.text(round.isEven ? 'جاوبت ✓' : 'نفّذت ✓'));
      }
      await tester.pump(const Duration(milliseconds: 800));
    }
    await tester.tap(find.text('إنهاء'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('العب مرة أخرى'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
