import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/admin/admin.dart';
import 'package:mojan/core/account/leaderboard.dart';
import 'package:mojan/core/shop.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/core/voice/voice.dart';
import 'package:mojan/games/ludo/ludo_engine.dart';
import 'package:mojan/games/sky_wheel/sky_wheel_engine.dart';
import 'package:mojan/games/sky_wheel/sky_wheel_screen.dart';
import 'package:mojan/screens/shop_screen.dart';
import 'package:mojan/screens/voice/voice_room_screen.dart';
import 'package:mojan/widgets/game_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tapKey(WidgetTester tester, String key, [int ms = 400]) async {
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
  await pumpFor(tester, 400);
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
  });

  test('ludo power: pickups sit on plain cells, landing takes the item and it moves', () {
    final g = LudoGame(players: [LudoColor.red, LudoColor.yellow], power: true, random: Random(4));
    expect(g.pickups.length, LudoGame.pickupCount);
    for (final c in g.pickups.keys) {
      expect(LudoGeo.isSafeGlobal(c), isFalse);
      expect(LudoGeo.bonusIndices.contains(c), isFalse);
    }
    expect(LudoGame(players: [LudoColor.red, LudoColor.yellow]).pickups, isEmpty, reason: 'classic has none');

    final start = LudoGeo.startIndex[LudoColor.red]!;
    final target = g.pickups.keys.firstWhere((c) {
      final p = (c - 1 - start) % 52;
      return p >= 0 && p <= 49;
    });
    final item = g.pickups[target]!;
    final before = g.itemCount(LudoColor.red, item);
    g.tokens[LudoColor.red]![0].pos = (target - 1 - start) % 52;
    expect(g.current, LudoColor.red);
    g.roll(1);
    final m = g.legalMoves.firstWhere((m) => m.token.id == 0);
    final r = g.move(m);
    expect(r.picked, item);
    expect(g.itemCount(LudoColor.red, item), before + 1);
    expect(g.pickups.containsKey(target), isFalse, reason: 'taken item moves elsewhere');
    expect(g.pickups.length, LudoGame.pickupCount);
  });

  test('sky wheel: odds, payouts and long-run return', () {
    expect(skyPods.fold(0.0, (a, p) => a + SkyWheelGame.chanceOf(p.id)), closeTo(1, 1e-9));
    expect(skyPods.first.id, 'crown');
    expect(skyPods.map((p) => p.mult).reduce(max), 45, reason: 'the crown is the top win');
    expect(SkyWheelGame.chanceOf('crown') < SkyWheelGame.chanceOf('lollipop'), isTrue);

    expect(SkyWheelGame.payoutFor({'crown': 100}, 'crown'), 4500);
    expect(SkyWheelGame.payoutFor({'crown': 100}, 'donut'), 0);
    expect(SkyWheelGame.payoutFor({'g.sweets': 100}, 'donut'), 120);
    expect(SkyWheelGame.payoutFor({'g.toys': 100, 'teddy': 10}, 'teddy'), 550 + 150);

    final g = SkyWheelGame(random: Random(3));
    expect(g.bet('crown', 100), isTrue);
    g.startSpin(forced: 'crown');
    expect(g.bet('donut', 10), isFalse, reason: 'no bets while spinning');
    expect(g.settle([('ريم', 4)], myName: 'أنا', myAvatar: 1), 4500);
    expect(g.history.first, 'crown');
    expect(g.roundWinners, isNotEmpty);
    expect(g.hourlyTop.any((w) => w.isMe), isTrue);
    g.next();
    expect(g.myBets, isEmpty);
    expect(g.phase, SkyPhase.betting);

    // كل كابينة ترجع قرابة 97٪ على المدى الطويل
    final sim = SkyWheelGame(random: Random(11));
    var back = 0;
    const n = 40000;
    for (var i = 0; i < n; i++) {
      back += SkyWheelGame.payoutFor({'lollipop': 10}, sim.pickWinner());
    }
    expect(back / (n * 10), inInclusiveRange(.9, 1.05));
  });

  testWidgets('sky wheel screen: bet, spin, result, ranking, rules and leave guard', (tester) async {
    await pumpApp(tester, const SkyWheelScreen(betSeconds: 4, stepMs: .05, shared: false));
    expect(find.text('عجلة السماء'), findsOneWidget);
    await tapKey(tester, 'sw-chip-100', 100);
    await tapKey(tester, 'sw-pod-crown', 100);
    await tapKey(tester, 'sw-g.sweets', 100);

    expect(acc.profile!.coins, 300);
    expect(find.textContaining('رهانك في هذه الجولة: 200'), findsOneWidget);
    await tapKey(tester, 'sw-chip-10000', 100);
    await tapKey(tester, 'sw-pod-teddy', 300);
    expect(acc.profile!.coins, 300, reason: 'not enough coins');

    await pumpFor(tester, 4500);
    expect(find.byKey(const ValueKey('sw-result')), findsOneWidget);
    final c = acc.profile!.coins;
    expect(c == 300 || c == 300 + 4500 || c == 300 + 120, isTrue, reason: 'coins $c');
    await tapKey(tester, 'sw-result', 300);
    expect(find.byKey(const ValueKey('sw-timer')), findsOneWidget);

    await tapKey(tester, 'sw-rank', 500);
    expect(find.byKey(const ValueKey('sw-rank-sheet')), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await pumpFor(tester, 500);
    await tapKey(tester, 'sw-help', 500);
    expect(find.text('طريقة اللعب'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await pumpFor(tester, 500);

    await tapKey(tester, 'sw-chip-10', 100);
    await tapKey(tester, 'sw-pod-donut', 100);
    await tapKey(tester, 'sw-back', 400);
    expect(find.byKey(const ValueKey('cancel-leave')), findsOneWidget);
    await tapKey(tester, 'cancel-leave', 400);
    expect(find.text('عجلة السماء'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('leave guard asks before leaving and pops on confirm', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('open'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LeaveGuard(child: Scaffold(body: GameTopBar(title: 'لعبة'))),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tapKey(tester, 'open', 600);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await pumpFor(tester, 400);
    expect(find.text('هل فعلاً تود الانسحاب من اللعب؟'), findsOneWidget);
    await tapKey(tester, 'cancel-leave', 400);
    expect(find.text('لعبة'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await pumpFor(tester, 400);
    await tapKey(tester, 'confirm-leave', 600);
    expect(find.text('لعبة'), findsNothing);
    await finish(tester);
  });

  testWidgets('shop sells frames, entrances and bubbles and equips them', (tester) async {
    acc.earn(20000);
    await pumpApp(tester, const ShopScreen());
    await tapKey(tester, 'shop-tab-frames', 600);
    await tapKey(tester, 'style-frame.hearts', 400);
    await tapKey(tester, 'confirm-buy', 600);
    expect(acc.profile!.frame, 'hearts');
    expect(acc.profile!.coins, 20500 - 1500);
    await tapKey(tester, 'unequip-frame', 300);
    expect(acc.profile!.frame, 'none');
    await tapKey(tester, 'style-frame.hearts', 300);
    expect(acc.profile!.frame, 'hearts', reason: 'owned items equip without buying again');

    await tapKey(tester, 'shop-tab-entrances', 600);
    await tapKey(tester, 'style-entrance.car', 400);
    await tapKey(tester, 'confirm-buy', 600);
    expect(acc.profile!.entrance, 'car');
    await tapKey(tester, 'shop-tab-bubbles', 600);
    await tapKey(tester, 'style-bubble.gold', 400);
    await tapKey(tester, 'confirm-buy', 600);
    expect(acc.profile!.bubble, 'gold');

    final me = VoiceService.instance.me();
    expect(me.frameArt, 'hearts');
    expect(me.entrance, 'car');
    expect(me.bubble, 'gold');
    await finish(tester);
  });

  testWidgets('my entrance plays when I join a voice room', (tester) async {
    acc.earn(20000);
    expect(acc.buy(shopItem('entrance.dragon')), isNull);
    acc.equip('entrance.dragon');
    final svc = VoiceService.instance;
    final r = svc.create(title: 'غرفتي', category: VoiceCategory.chat, seats: 8);
    await pumpApp(tester, VoiceRoomScreen(room: r, simulate: false));
    await pumpFor(tester, 800);
    expect(find.byKey(const ValueKey('entry-fx')), findsOneWidget);
    expect(find.textContaining('دخل بـالتنين'), findsOneWidget);
    await pumpFor(tester, 3500);
    expect(find.byKey(const ValueKey('entry-fx')), findsNothing);
    expect(find.byKey(const ValueKey('btn-speaker')), findsOneWidget);
    await tapKey(tester, 'btn-speaker', 300);
    expect(svc.speakerOn, isFalse);
    await finish(tester);
  });

  test('admin can grant test coins to my account', () {
    final before = acc.profile!.coins;
    AdminService.instance.grantCoins(1000000);
    expect(acc.profile!.coins, before + 1000000);
    expect(AdminService.instance.log.first, contains('1000000'));
  });

  test('sky wheel rounds feed their own leaderboard, not the overall totals', () {
    acc.recordSkyRound(bet: 100, won: 4500);
    acc.recordSkyRound(bet: 100, won: 0);
    final st = acc.profile!.statsFor('sky_wheel');
    expect(st.played, 2);
    expect(st.wins, 1);
    expect(st.points, 4500);
    expect(acc.profile!.totalPlayed, 0);
    final lb = Leaderboard.build(acc.profile, game: 'sky_wheel');
    expect(lb.firstWhere((e) => e.isMe).points, 4500);
    expect(gameTitles['sky_wheel'], 'عجلة السماء');
  });

  test('profile bio and posts persist', () {
    acc.setBio('أحب اللودو 🎲');
    acc.addPost('أول منشور', mood: 2);
    acc.addPost('  ');
    final p = acc.profile!;
    expect(p.posts.length, 1);
    acc.toggleLike(p.posts.first);
    expect(p.posts.first.likes, 1);
    final copy = PlayerProfile.fromJson(p.toJson());
    expect(copy.bio, 'أحب اللودو 🎲');
    expect(copy.posts.single.text, 'أول منشور');
    expect(copy.posts.single.mood, 2);
    expect(copy.posts.single.liked, isTrue);
    acc.deletePost(p.posts.first.id);
    expect(p.posts, isEmpty);
  });
}
