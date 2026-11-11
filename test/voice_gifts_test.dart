import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/core/voice/voice.dart';
import 'package:mojan/screens/voice/mini_room_bubble.dart';
import 'package:mojan/screens/voice/voice_room_screen.dart';
import 'package:mojan/screens/voice/voice_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapKey(WidgetTester tester, String key, [int ms = 500]) async {
  final f = find.byKey(ValueKey(key));
  expect(f, findsWidgets, reason: key);
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first);
  await pumpFor(tester, ms);
}

void main() {
  final svc = VoiceService.instance;
  final acc = Account.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    acc.reset();
    svc.reset();
    await acc.signIn(method: AuthMethod.guest, name: 'موكا');
  });

  test('big numbers turn into K / M', () {
    expect(fmtK(950), '950');
    expect(fmtK(1000), '1K');
    expect(fmtK(1530), '1.5K');
    expect(fmtK(48000), '48K');
    expect(fmtK(2300000), '2.3M');
    expect(fmtK(150000000), '150M');
  });

  test('gift to everyone on the mics: price × count × people, stats per person', () {
    svc.ensureDemo();
    final r = svc.live.firstWhere((r) => r.onSeats >= 3);
    expect(r.audience, isNotEmpty, reason: 'demo rooms have people in the box');
    expect(r.receivedBy(r.host.id), greaterThan(0), reason: 'demo stats are seeded');
    svc.join(r);
    acc.earn(100000);
    final before = acc.profile!.coins;
    final mics = r.onMics;
    final was = {for (final u in mics) u.id: r.receivedBy(u.id)};
    final count = r.giftsCount;
    final rose = giftById('rose');
    expect(svc.sendGiftTo(r, rose, mics, count: 5), isNull);
    expect(acc.profile!.coins, before - 10 * 5 * mics.length);
    for (final u in mics) {
      expect(r.receivedBy(u.id), was[u.id]! + 50);
    }
    expect(r.giftsCount, count + 5 * mics.length);
    expect(r.messages.last.to.length, mics.length);
    expect(r.top(r.sent).any((e) => e.$1.isMe), isTrue);
  });

  testWidgets('room: gift badges, fly to seat / people box, chat card, stats, minimize', (tester) async {
    tester.view.physicalSize = const Size(420 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    svc.ensureDemo();
    final room = svc.live.firstWhere((r) => r.onSeats >= 3);
    acc.earn(200000);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      navigatorKey: appNavigatorKey,
      builder: (c, child) => Stack(children: [?child, const MiniRoomBubble()]),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Builder(
            builder: (c) => Center(
              child: TextButton(onPressed: () => openVoiceRoom(c, room), child: const Text('open')),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await pumpFor(tester, 1200);
    expect(find.byType(VoiceRoomScreen), findsOneWidget);

    // الشارة تحت المضيف بصيغة مختصرة
    final hostBadge = find.descendant(of: find.byKey(const ValueKey('gifts-host')), matching: find.byType(Text));
    expect(tester.widget<Text>(hostBadge).data, fmtK(room.receivedBy(room.host.id)));
    final seated = room.seats.firstWhere((s) => s.user != null);
    expect(find.byKey(ValueKey('gifts-${seated.index}')), findsOneWidget);

    // هدية لكل من على المايك
    final mics = room.onMics;
    final coins = acc.profile!.coins;
    await tapKey(tester, 'btn-gift', 800);
    await tapKey(tester, 'gift-to-all-mics');
    expect(find.textContaining('كل من على المايك'), findsOneWidget);
    await tapKey(tester, 'gift-rose');
    await tapKey(tester, 'gift-send', 300);
    expect(acc.profile!.coins, coins - 10 * mics.length);
    expect(find.byKey(const ValueKey('flight-1')), findsOneWidget);
    expect(find.byKey(ValueKey('flight-${mics.length}')), findsOneWidget, reason: 'one gift per person');
    await pumpFor(tester, 3500);
    expect(find.byKey(const ValueKey('flight-1')), findsNothing);

    // الضغط على رسالة في الدردشة يفتح بطاقة صاحبها بالنبذة
    await tapKey(tester, 'chat-user-0', 800);
    expect(find.byKey(const ValueKey('user-bio')), findsOneWidget);
    await tester.tapAt(const Offset(200, 40));
    await pumpFor(tester, 600);

    // صندوق الأشخاص: هدية لشخص من الحضور تطير للصندوق
    final aud = room.audience.first;
    final had = room.receivedBy(aud.id);
    await tapKey(tester, 'room-people', 800);
    expect(find.byKey(const ValueKey('audience-sheet')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('aud-${aud.id}')),
      120,
      scrollable: find.descendant(of: find.byKey(const ValueKey('audience-sheet')), matching: find.byType(Scrollable)),
    );
    await tapKey(tester, 'aud-${aud.id}', 800);
    expect(find.byKey(const ValueKey('user-bio')), findsOneWidget);
    await tapKey(tester, 'user-gift', 800);
    expect(tester.widget<Text>(find.byKey(const ValueKey('gift-target-name'))).data, aud.name);
    await tapKey(tester, 'gift-heart');
    await tapKey(tester, 'gift-send', 300);
    expect(room.receivedBy(aud.id), had + 30);
    await pumpFor(tester, 3000);

    // إحصائيات هدايا الغرفة
    await tapKey(tester, 'room-stats', 800);
    expect(find.byKey(const ValueKey('gift-stats-sheet')), findsOneWidget);
    expect(find.text('إحصائيات هدايا الغرفة'), findsOneWidget);
    await tester.tapAt(const Offset(200, 30));
    await pumpFor(tester, 600);

    // تصغير الغرفة ثم الرجوع لها من الفقاعة
    await tapKey(tester, 'room-exit', 600);
    await tapKey(tester, 'exit-minimize', 1000);
    expect(find.byType(VoiceRoomScreen), findsNothing);
    expect(svc.minimized, room);
    expect(find.byKey(const ValueKey('mini-room')), findsOneWidget);
    await tapKey(tester, 'mini-room', 1000);
    expect(find.byType(VoiceRoomScreen), findsOneWidget);
    expect(svc.minimized, isNull);
    expect(find.byKey(const ValueKey('mini-room')), findsNothing);

    // الضغط على نفس الغرفة من القائمة وهي مصغّرة يرجعك لها بدون دخول جديد
    await tapKey(tester, 'room-exit', 600);
    await tapKey(tester, 'exit-minimize', 1000);
    final l0 = room.listeners;
    await tester.tap(find.text('open'));
    await pumpFor(tester, 1000);
    expect(find.byType(VoiceRoomScreen), findsOneWidget);
    expect(room.listeners, l0);
    expect(svc.minimized, isNull);

    // دخول غرفة أخرى يخرجك من المصغّرة
    await tapKey(tester, 'room-exit', 600);
    await tapKey(tester, 'exit-minimize', 1000);
    final other = svc.live.firstWhere((r) => r != room);
    final ctx = tester.element(find.text('open'));
    openVoiceRoom(ctx, other);
    await pumpFor(tester, 1000);
    expect(svc.minimized, isNull);
    expect(room.listeners, l0 - 1);
    await tapKey(tester, 'room-exit', 600);
    await tapKey(tester, 'exit-leave', 1000);
    await tester.tap(find.text('open'));
    await pumpFor(tester, 1200);

    await tapKey(tester, 'room-exit', 600);
    await tapKey(tester, 'exit-minimize', 1000);
    final listeners = room.listeners;
    await tapKey(tester, 'mini-room-close', 600);
    expect(svc.minimized, isNull);
    expect(room.listeners, listeners - 1);
    expect(find.byKey(const ValueKey('mini-room')), findsNothing);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
