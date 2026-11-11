import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/screens/home_screen.dart';
import 'package:mojan/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(420 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    builder: (_, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: home,
  ));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> wait(WidgetTester tester, [int ms = 800]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

  testWidgets('guest sign-in, tabs, profile edits, daily reward, settings and sign out', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await tester.tap(find.byKey(const ValueKey('login-guest')));
    await wait(tester);
    await tester.tap(find.byKey(const ValueKey('avatar-3')));
    await tester.enterText(find.byKey(const ValueKey('name-field')), 'نورة');
    await wait(tester, 300);
    await tester.tap(find.byKey(const ValueKey('finish-setup')));
    await wait(tester, 1500);

    final acc = Account.instance;
    expect(acc.profile!.name, 'نورة');
    expect(acc.profile!.avatar, 3);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('أهلاً يا نورة 👋'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);

    // الغرف
    await tester.tap(find.text('الغرف'));
    await wait(tester);
    expect(find.text('انضم لغرفة صديق'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('room-code')), '123456');
    await wait(tester, 200);
    await tester.tap(find.byKey(const ValueKey('room-join')));
    await wait(tester, 300);
    expect(find.textContaining('بعد تشغيل السيرفر'), findsWidgets);

    // المتصدرون
    await tester.tap(find.text('المتصدرون'));
    await wait(tester);
    expect(find.byKey(const ValueKey('my-rank-pinned')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lb-quiz')));
    await wait(tester);
    await tester.tap(find.text('الأسبوع'));
    await wait(tester);
    expect(find.byKey(const ValueKey('my-rank-pinned')), findsOneWidget);

    // حسابي
    await tester.tap(find.text('حسابي'));
    await wait(tester, 1200);
    expect(find.text('نورة'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('claim-daily')));
    await wait(tester, 500);
    expect(acc.profile!.coins, 600);
    expect(find.byKey(const ValueKey('claim-daily')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('edit-name')));
    await wait(tester, 500);
    await tester.enterText(find.byKey(const ValueKey('rename-field')), 'نورة الأولى');
    await tester.tap(find.byKey(const ValueKey('rename-save')));
    await wait(tester, 500);
    expect(acc.profile!.name, 'نورة الأولى');

    await tester.tap(find.byKey(const ValueKey('edit-avatar')));
    await wait(tester, 600);
    await tester.tap(find.byKey(const ValueKey('pick-avatar-7')));
    await wait(tester, 600);
    expect(acc.profile!.avatar, 7);

    // الإعدادات
    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await wait(tester, 600);
    await tester.tap(find.byKey(const ValueKey('haptics-switch')));
    await wait(tester, 300);
    expect(acc.haptics, isFalse);
    await tester.tap(find.byKey(const ValueKey('sign-out')));
    await wait(tester, 500);
    await tester.tap(find.byKey(const ValueKey('confirm-sign-out')));
    await wait(tester, 1000);
    expect(acc.profile, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('phone sign-in: validation, wrong code, right code, setup', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await tester.tap(find.byKey(const ValueKey('login-phone')));
    await wait(tester);
    await tester.enterText(find.byKey(const ValueKey('phone-field')), '0501234567');
    await wait(tester, 200);
    await tester.tap(find.byKey(const ValueKey('send-code')));
    await wait(tester, 1500);
    expect(find.byKey(const ValueKey('code-field')), findsOneWidget);
    expect(find.text('+966501234567'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('code-field')), '123456');
    await wait(tester, 1500);
    expect(find.byKey(const ValueKey('auth-error')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('code-field')), '000000');
    await wait(tester, 1500);
    expect(find.byKey(const ValueKey('name-field')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('finish-setup')));
    await wait(tester, 1500);
    expect(Account.instance.profile!.method, AuthMethod.phone);
    expect(Account.instance.profile!.contact, '+966501234567');
    expect(find.byType(HomeScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('google sign-in goes to setup with the account name', (tester) async {
    await pumpApp(tester, const LoginScreen());
    await tester.tap(find.byKey(const ValueKey('login-google')));
    await wait(tester, 1500);
    expect(find.byKey(const ValueKey('name-field')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('finish-setup')));
    await wait(tester, 1500);
    expect(Account.instance.profile!.method, AuthMethod.google);
    expect(find.byType(HomeScreen), findsOneWidget);
    await finish(tester);
  });
}
