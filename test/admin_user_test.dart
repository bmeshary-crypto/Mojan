import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/admin/admin.dart';
import 'package:mojan/core/firebase/cloud.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/screens/admin/admin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final acc = Account.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    acc.reset();
    await acc.signIn(method: AuthMethod.guest, name: 'سارة');
  });

  test('activity log records games, buys and merges coin rounds', () {
    acc.recordGame('ludo', won: true, points: 100);
    acc.recordCoinRound('rocket', bet: 100, won: 0);
    acc.recordCoinRound('rocket', bet: 100, won: 350);
    final p = acc.profile!;
    expect(p.activity.first.kind, 'bet');
    expect(p.activity.first.count, 2);
    expect(p.activity.first.coins, 150);
    expect(p.activity.first.text, contains('2 جولة'));
    expect(p.activity[1].kind, 'game');
    expect(p.activity[1].text, contains('فاز'));
    // يرتفع مع الملف ويرجع كما هو
    final back = PlayerProfile.fromJson(p.toJson());
    expect(back.activity.length, p.activity.length);
    expect(back.activity.first.bet, 200);
    expect(back.activity.first.won, 350);
  });

  test('activity log is capped', () {
    for (var i = 0; i < PlayerProfile.maxActivity + 30; i++) {
      acc.log('room', 'غرفة $i');
    }
    expect(acc.profile!.activity.length, PlayerProfile.maxActivity);
    expect(acc.profile!.activity.first.text, 'غرفة ${PlayerProfile.maxActivity + 29}');
  });

  test('admin edits: add, take (not below zero), set coins, diamonds, items', () async {
    final p = acc.profile!;
    p.coins = 1000;
    await Cloud.instance.applyAdminEdit({'coinsAdd': 500});
    expect(p.coins, 1500);
    await Cloud.instance.applyAdminEdit({'coinsAdd': -5000});
    expect(p.coins, 0);
    await Cloud.instance.applyAdminEdit({'coinsSet': 777, 'diamondsSet': 12});
    expect(p.coins, 777);
    expect(p.diamonds, 12);
    p.owned.add('frame.hearts');
    p.frame = 'hearts';
    await Cloud.instance.applyAdminEdit({'unown': ['frame.hearts'], 'own': ['entrance.lion'], 'inv': {'shield': 3}});
    expect(p.owned, isNot(contains('frame.hearts')));
    expect(p.frame, 'none');
    expect(p.owned, contains('entrance.lion'));
    expect(p.inventory['shield'], 3);
    expect(p.activity.where((e) => e.kind == 'admin').length, greaterThanOrEqualTo(5));
  });

  test('flag from country code', () {
    expect(flagOf('SA'), '🇸🇦');
    expect(flagOf(null), '🌐');
  });

  testWidgets('user page shows balance, log and device tabs, and edits coins (demo)', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    acc.recordGame('seeko', won: false);
    AdminService.instance.adminOverride = true;
    addTearDown(() => AdminService.instance.adminOverride = null);
    final doc = localUserDoc()!;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Directionality(textDirection: TextDirection.rtl, child: AdminUserPage(user: doc)),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('user-balance')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('user-add-coins')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('admin-number')), '2500');
    await tester.tap(find.byKey(const ValueKey('admin-number-ok')));
    await tester.pumpAndSettle();
    expect(acc.profile!.activity.first.text, contains('2500'));
    await tester.tap(find.byKey(const ValueKey('user-tab-log')));
    await tester.pumpAndSettle();
    expect(find.textContaining('سيكو'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('user-tab-games')));
    await tester.pumpAndSettle();
    expect(find.text('1 مباراة'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('user-tab-device')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('user-linked')), findsOneWidget);
  });
}
