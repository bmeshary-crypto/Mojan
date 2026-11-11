import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/game_module.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/games/quiz/quiz_screen.dart';
import 'package:mojan/core/account/account.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('quiz full match: create room, bots join, answer with lifelines, results', (tester) async {
    tester.view.physicalSize = const Size(420 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    Account.instance.reset();
    await Account.instance.signIn(method: AuthMethod.guest, name: 'لاعب');
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const Directionality(textDirection: TextDirection.rtl, child: QuizScreen(mode: PlayMode.vsComputer)),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('5').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('أنشئ غرفة'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('أنشئ غرفة'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('رمز الغرفة'), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 700));
    }
    await tester.tap(find.text('ابدأ المسابقة'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 3000));

    var questions = 0;
    final lifelines = ['حذف إجابتين', '+10 ثواني', 'تخطي'];
    while (find.text('العب مرة أخرى').evaluate().isEmpty) {
      expect(questions, lessThan(10), reason: 'match should end');
      expect(find.byKey(const ValueKey('answer-0')), findsOneWidget);
      if (questions < lifelines.length) {
        await tester.tap(find.text(lifelines[questions]));
        await tester.pump(const Duration(milliseconds: 200));
      }
      if (questions != 2 && questions != 3) { // 2 = تخطي، 3 = انتهاء الوقت
        for (var a = 0; a < 4; a++) {
          await tester.tap(find.byKey(ValueKey('answer-$a')), warnIfMissed: false);
        }
      }
      for (var t = 0; t < 60 && find.text('الترتيب').evaluate().isEmpty; t++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text('الترتيب'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pump(const Duration(milliseconds: 500));
      questions++;
    }
    expect(questions, 5);
    expect(Account.instance.profile!.statsFor('quiz').played, 1, reason: 'match result saved to the profile');
    expect(find.textContaining('خبرة'), findsOneWidget, reason: 'reward shown in results');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
