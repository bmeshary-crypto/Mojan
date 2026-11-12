import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/admin/admin.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/core/voice/voice.dart';
import 'package:mojan/screens/admin/admin_screen.dart';
import 'package:mojan/screens/voice/voice_home.dart';
import 'package:mojan/screens/voice/voice_room_screen.dart';
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

Future<void> pumpApp(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(420 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: home)),
  ));
  await pumpFor(tester, 600);
}

Future<void> finish(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  final svc = VoiceService.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Account.instance.reset();
    svc.reset();
    AdminService.instance.reset();
    await Account.instance.signIn(method: AuthMethod.guest, name: 'موكا');
  });

  test('voice service: seats, host tools, gifts, game hall, reports, bans', () {
    svc.ensureDemo();
    expect(svc.live, isNotEmpty);
    final r = svc.create(title: 'غرفتي', category: VoiceCategory.music, seats: 8);
    expect(r.seats[0].user?.isAi, isTrue, reason: 'new rooms start with an AI persona');
    r.seats[0].user = null;
    expect(svc.isHost(r), isTrue);
    expect(svc.takeSeat(r, 0), isNotNull, reason: 'host has own seat');
    svc.toggleLock(r, 7);
    expect(r.seats[7].locked, isTrue);
    svc.invite(r);
    expect(r.onSeats, 1);
    final bot = r.seats.firstWhere((s) => s.user != null);
    svc.toggleMute(r, bot.index);
    expect(bot.muted, isTrue);
    svc.removeFromSeat(r, bot.index);
    expect(r.onSeats, 0);
    svc.setSeatCount(r, 20);
    expect(r.seats.length, 20);
    expect(r.seats[7].locked, isTrue, reason: 'existing seats keep their state');

    // هدية تخصم العملات وتزيد الشعبية
    final coins = Account.instance.profile!.coins;
    expect(svc.sendGift(r, giftById('rose'), r.host, count: 5), isNull);
    expect(Account.instance.profile!.coins, coins - 50);
    expect(r.heat, 50);
    expect(svc.sendGift(r, giftById('rocket'), r.host), 'عملاتك لا تكفي');

    svc.setGame(r, 'ludo');
    expect(r.game, 'ludo');
    svc.update(r, chatMuted: true);
    expect(svc.sendMessage(r, 'hi'), isNull, reason: 'host can still chat');

    // مستمع في غرفة غيره
    final other = svc.live.firstWhere((x) => !svc.isHost(x) && x.seats.any((s) => s.empty && !s.locked));
    expect(svc.join(other), isNull);
    final free = other.seats.firstWhere((s) => s.empty && !s.locked).index;
    expect(svc.takeSeat(other, free), isNull);
    expect(svc.micOn, isTrue);
    svc.toggleMic(other);
    expect(svc.micOn, isFalse);
    svc.leaveSeat(other);
    expect(svc.mySeat(other), isNull);
    svc.report(other, reportReasons[1], target: 'x');
    expect(svc.reports.first.reason, reportReasons[1]);

    // الطرد والحظر
    svc.kick(other, svc.me());
    expect(svc.join(other), 'تم طردك من هذه الغرفة');
    AdminService.instance.unlock(AdminService.demoPin);
    AdminService.instance.toggleBan('موكا');
    expect(svc.join(svc.live.first), 'حسابك موقوف من الغرف الصوتية');
    AdminService.instance.toggleBan('موكا');

    // الأدمن يغلق غرفة
    AdminService.instance.closeRoom(other);
    expect(other.closed, isTrue);
    expect(svc.join(other), 'هذه الغرفة مغلقة');
    expect(AdminService.instance.log, isNotEmpty);
  });

  test('simulation ticks keep chat bounded and requests come to the host', () {
    final r = svc.create(title: 'x', category: VoiceCategory.chat, seats: 12);
    r.seats[0].user = null;
    for (var i = 0; i < 400; i++) {
      svc.tick(r);
    }
    expect(r.messages.length, lessThanOrEqualTo(80));
    expect(r.requests.length, lessThanOrEqualTo(3));
    if (r.requests.isNotEmpty) {
      svc.acceptRequest(r, r.requests.first);
      expect(r.onSeats, 1);
    }
  });

  testWidgets('voice home: filters, create a party room, use every room control', (tester) async {
    await pumpApp(tester, const VoiceHome());
    expect(find.text('اكتشف غرف جديدة'), findsOneWidget);
    await tapKey(tester, 'voice-cat-music');
    expect(find.text('سهرة طرب'), findsOneWidget);
    expect(find.text('صوتك أحلى'), findsNothing);
    await tapKey(tester, 'voice-cat-all');

    await tapKey(tester, 'voice-create', 800);
    await tester.enterText(find.byKey(const ValueKey('create-title')), 'حفلتي');
    await tapKey(tester, 'create-cat-party');
    await tapKey(tester, 'create-seats-8');
    await tapKey(tester, 'create-go', 1200);
    expect(find.byType(VoiceRoomScreen), findsOneWidget);
    expect(find.text('حفلتي'), findsWidgets);
    final room = svc.rooms.first;
    expect(room.theme, VoiceTheme.party);
    expect(room.seats.length, 8);
    room.seats[0].user = null; // نخلي مقعد الـ AI لاختبار أدوات المضيف
    svc.notify();
    await tester.pump();

    // المضيف يقفل مقعد ويدعو مستمع
    await tapKey(tester, 'seat-3');
    await tapKey(tester, 'seat-lock');
    expect(room.seats[3].locked, isTrue);
    await tapKey(tester, 'seat-0');
    await tapKey(tester, 'seat-invite');
    expect(room.seats[0].user, isNotNull);
    // بطاقة المستخدم: كتم ثم طرد
    await tapKey(tester, 'seat-0');
    await tapKey(tester, 'host-mute');
    expect(room.seats[0].muted, isTrue);
    await tapKey(tester, 'seat-0');
    await tapKey(tester, 'host-kick');
    expect(room.seats[0].user, isNull);

    // دردشة وإيموجي وهدية
    await tapKey(tester, 'chat-open');
    await tester.enterText(find.byKey(const ValueKey('chat-field')), 'هلا والله');
    await tapKey(tester, 'chat-send');
    expect(room.messages.any((m) => m.text == 'هلا والله'), isTrue);
    await tapKey(tester, 'btn-emoji');
    await tapKey(tester, 'emoji-3');
    expect(room.host.reaction, '🔥');
    await tapKey(tester, 'btn-gift', 800);
    await tapKey(tester, 'gift-heart');
    final heat = room.heat;
    final coins = Account.instance.profile!.coins;
    await tapKey(tester, 'gift-send', 800);
    // الهدية (30) تنضاف لحرارة الغرفة، والبوتات ممكن تضيف هداياها خلال نفس الوقت.
    expect(room.heat, greaterThanOrEqualTo(heat + 30));
    expect(Account.instance.profile!.coins, coins - 30);
    await pumpFor(tester, 3000);

    // إعدادات الغرفة: 20 مايك، صالة لودو
    await tapKey(tester, 'room-menu', 800);
    await tapKey(tester, 'seats-20');
    expect(room.seats.length, 20);
    await tapKey(tester, 'room-game', 800);
    await tapKey(tester, 'pick-game-ludo', 800);
    expect(room.game, 'ludo');
    await tapKey(tester, 'room-save', 800);
    expect(find.byKey(const ValueKey('game-hall')), findsOneWidget);
    await tapKey(tester, 'hall-start', 1200);
    expect(find.text('ابدأ اللعب'), findsOneWidget, reason: 'Ludo setup opened from the hall');
    await tapKey(tester, 'ludo-back', 800);

    // طلبات المايك
    await tapKey(tester, 'btn-requests', 800);
    await tapKey(tester, 'invite-mic');
    expect(room.onSeats, greaterThan(0));
    await tester.tapAt(const Offset(200, 40));
    await pumpFor(tester, 600);

    // الخروج مع إبقاء الغرفة مفتوحة
    await tapKey(tester, 'room-exit', 600);
    await tapKey(tester, 'exit-keep', 1000);
    expect(find.byType(VoiceRoomScreen), findsNothing);
    expect(room.closed, isFalse);
    await finish(tester);
  });

  testWidgets('listener joins a room, takes a mic, reports and follows', (tester) async {
    svc.ensureDemo();
    final room = svc.live.firstWhere((r) => r.title == 'صوتك أحلى');
    await pumpApp(tester, const VoiceHome());
    await tapKey(tester, 'voice-room-${room.id}', 1200);
    expect(find.byType(VoiceRoomScreen), findsOneWidget);
    await tapKey(tester, 'room-follow');
    expect(svc.following.contains(room.id), isTrue);
    await tapKey(tester, 'btn-hand');
    expect(svc.mySeat(room), isNotNull);
    await tapKey(tester, 'btn-mic');
    expect(svc.micOn, isFalse);
    await tapKey(tester, 'room-menu', 600);
    await tapKey(tester, 'menu-report', 800);
    await tapKey(tester, 'report-0', 600);
    expect(room.reports, 1);
    await pumpFor(tester, 5000);
    await finish(tester);
  });

  testWidgets('admin: pin, overview, void match, monitor room, resolve reports, ban user', (tester) async {
    svc.ensureDemo();
    Account.instance.recordGame('ludo', won: true, points: 400);
    await pumpApp(tester, Builder(builder: (c) => Center(child: TextButton(onPressed: () => openAdmin(c), child: const Text('admin')))));
    await tester.tap(find.text('admin'));
    await pumpFor(tester, 600);
    await tester.enterText(find.byKey(const ValueKey('admin-pin')), '9999');
    await tapKey(tester, 'admin-enter', 600);
    expect(find.byType(AdminScreen), findsNothing);
    await tester.tap(find.text('admin'));
    await pumpFor(tester, 600);
    await tester.enterText(find.byKey(const ValueKey('admin-pin')), AdminService.demoPin);
    await tapKey(tester, 'admin-enter', 1000);
    expect(find.byType(AdminScreen), findsOneWidget);
    expect(find.text('سوالف آخر الليل'), findsWidgets, reason: 'flagged room shown on overview');
    expect(tester.widget<Text>(find.byKey(const ValueKey('stat-4'))).data, '1', reason: 'this device match log');

    await tapKey(tester, 'admin-tab-matches', 800);
    final m = AdminService.instance.matches.firstWhere((m) => m.entry > 0);
    await tapKey(tester, 'void-${m.id}');
    expect(m.status, 'voided');

    await tapKey(tester, 'admin-tab-rooms', 800);
    final flagged = svc.live.firstWhere((r) => r.flagged);
    await tapKey(tester, 'warn-${flagged.id}');
    expect(flagged.warned, isTrue);
    await tapKey(tester, 'muteall-${flagged.id}');
    expect(flagged.seats.where((s) => s.user != null).every((s) => s.muted), isTrue);
    await tapKey(tester, 'monitor-${flagged.id}', 1200);
    expect(find.byType(VoiceRoomScreen), findsOneWidget);
    await tapKey(tester, 'room-exit', 600);
    await tapKey(tester, 'exit-leave', 1000);
    await tapKey(tester, 'close-${flagged.id}', 600);
    await tapKey(tester, 'confirm-admin-close', 600);
    expect(flagged.closed, isTrue);

    await tapKey(tester, 'admin-tab-reports', 800);
    await tapKey(tester, 'rep-ban-0');
    expect(svc.reports[0].status, 'banned');
    expect(svc.bannedUsers, contains(svc.reports[0].target));
    await tapKey(tester, 'rep-warn-1');
    expect(svc.reports[1].status, 'warned');

    await tapKey(tester, 'admin-tab-users', 800);
    await tester.enterText(find.byKey(const ValueKey('user-search')), 'موكا');
    await pumpFor(tester, 400);
    await tapKey(tester, 'ban-موكا');
    expect(svc.bannedUsers.contains('موكا'), isTrue);
    await finish(tester);
  });
}
