import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/shop.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/core/vip.dart';
import 'package:mojan/core/voice/voice.dart';
import 'package:mojan/screens/vip_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final acc = Account.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    acc.reset();
    VoiceService.instance.reset();
    acc.vipUp.value = null;
    await acc.signIn(method: AuthMethod.guest, name: 'موكا');
  });

  test('levels go up with points and unlock free styles', () {
    expect(vipLevelFor(0), 0);
    expect(vipLevelFor(4999), 0);
    expect(vipLevelFor(5000), 1);
    expect(vipLevelFor(10000000), 8);
    for (var i = 1; i < vipTiers.length; i++) {
      expect(vipTiers[i].points > vipTiers[i - 1].points, isTrue);
      expect(vipTiers[i].daily > vipTiers[i - 1].daily, isTrue);
    }
    final p = acc.profile!;
    expect(acc.addVip(4000), isNull);
    expect(acc.addVip(1000), 1);
    expect(acc.vipUp.value, 1);
    acc.addVip(60000);
    expect(p.vipLevel, 3);
    expect(p.owns('frame.royal'), isTrue);
    expect(p.owns('bubble.gold'), isTrue);
    expect(p.frame, 'royal', reason: 'equipped because nothing was worn');
  });

  test('daily reward once a day, shop discount, purchases give points', () {
    final p = acc.profile!;
    expect(acc.claimVipDaily(), isNull, reason: 'not VIP yet');
    acc.addVip(60000);
    final before = p.coins;
    expect(acc.claimVipDaily(), 400);
    expect(p.coins, before + 400);
    expect(acc.claimVipDaily(), isNull);
    expect(acc.claimVipDaily(now: DateTime.now().add(const Duration(days: 1))), 400);
    final item = shopItem('frame.fire');
    expect(acc.priceFor(item), (item.price * .95).round());
    acc.earn(10000);
    final pts = p.vipPoints;
    final coins = p.coins;
    expect(acc.buy(item), isNull);
    expect(p.coins, coins - acc.priceFor(item));
    expect(p.vipPoints, pts + acc.priceFor(item));
  });

  test('VIP5 cannot be kicked; bets do not count', () {
    final svc = VoiceService.instance..ensureDemo();
    final room = svc.rooms.first;
    final vip = VoiceUser(id: 'x', name: 'سلطان', avatar: 1, vipLevel: 5);
    expect(svc.kick(room, vip), contains('محمي'));
    final normal = VoiceUser(id: 'y', name: 'فهد', avatar: 1);
    expect(svc.kick(room, normal), isNull);
    final pts = acc.profile!.vipPoints;
    acc.spend(100);
    expect(acc.profile!.vipPoints, pts);
  });

  testWidgets('VIP page shows level, tiers and claims the daily reward', (tester) async {
    tester.view.physicalSize = const Size(420 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    acc.addVip(20000);
    acc.vipUp.value = null;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const Directionality(textDirection: TextDirection.rtl, child: VipScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('VIP2  فضي'), findsOneWidget);
    final coins = acc.profile!.coins;
    await tester.tap(find.byKey(const ValueKey('vip-daily')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(acc.profile!.coins, coins + 200);
    expect(find.text('استلمتها ✓'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('vip-tier-8')), 300);
    expect(find.byKey(const ValueKey('vip-tier-8')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
