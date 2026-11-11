import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/games/ludo/ludo_engine.dart';
import 'package:mojan/screens/shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapKey(WidgetTester tester, String key, [int ms = 500]) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first);
  await pumpFor(tester, ms);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Account.instance.reset();
  });

  testWidgets('shop: chest, coin packs, buy and equip skins, buy items, backpack, daily bonus', (tester) async {
    tester.view.physicalSize = const Size(420 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final acc = Account.instance;
    await acc.signIn(method: AuthMethod.guest, name: 'متسوق');
    acc.earn(4500); // 5000
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const Directionality(textDirection: TextDirection.rtl, child: ShopScreen()),
    ));
    await pumpFor(tester, 600);

    // صندوق مجاني
    await tapKey(tester, 'shop-chest');
    expect(acc.profile!.coins, 5000 + Account.chestCoins);
    expect(find.textContaining('يفتح بعد'), findsOneWidget);
    // باقات الفلوس الحقيقية تقول بصراحة أنها لاحقاً
    await tester.tap(find.textContaining('4.99').first);
    await pumpFor(tester, 400);
    expect(find.textContaining('عند نزول التطبيق في المتاجر'), findsOneWidget);

    // السكنات: شراء نرد ياقوتي يركّبه تلقائياً
    await tapKey(tester, 'shop-tab-skins', 800);
    await tapKey(tester, 'skin-dice.ruby');
    await tapKey(tester, 'confirm-buy', 800);
    expect(acc.profile!.owns('dice.ruby'), isTrue);
    expect(acc.profile!.diceSkin, 'ruby');
    expect(acc.profile!.coins, 5300 - 1500);
    // الرجوع للكلاسيك بدون شراء
    await tapKey(tester, 'skin-dice.classic');
    expect(acc.profile!.diceSkin, 'classic');
    // لوح الليل
    await tapKey(tester, 'skin-board.night');
    await tapKey(tester, 'confirm-buy', 800);
    expect(acc.profile!.boardTheme, 'night');

    // الأدوات
    await tapKey(tester, 'shop-tab-items', 800);
    await tapKey(tester, 'buy-item.diceControl');
    await tapKey(tester, 'confirm-buy', 800);
    expect(acc.profile!.itemCount(LudoItem.diceControl), 1);
    // حزمة الباور أغلى من الرصيد الباقي (1300)
    await tapKey(tester, 'buy-bundle.power');
    await tapKey(tester, 'confirm-buy', 800);
    expect(find.text('عملاتك لا تكفي'), findsOneWidget);
    expect(acc.profile!.itemCount(LudoItem.shield), 0);

    // الحقيبة
    await tapKey(tester, 'shop-tab-bag', 800);
    expect(tester.widget<Text>(find.byKey(const ValueKey('bag-diceControl'))).data, '×1');
    expect(find.byKey(const ValueKey('bag-dice.ruby')), findsOneWidget);
    await tapKey(tester, 'bag-dice.ruby');
    expect(acc.profile!.diceSkin, 'ruby');

    // البونص اليومي من المتجر
    await tapKey(tester, 'shop-tab-coins', 800);
    await tapKey(tester, 'shop-daily', 800);
    await tapKey(tester, 'daily-claim', 800);
    expect(acc.dailyAvailable, isFalse);
    expect(find.byKey(const ValueKey('daily-got')), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
