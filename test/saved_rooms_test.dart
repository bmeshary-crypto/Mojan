import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/voice/voice.dart';
import 'package:mojan/screens/voice/voice_home.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final svc = VoiceService.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Account.instance.reset();
    svc.reset();
    await Account.instance.signIn(method: AuthMethod.guest, name: 'موكا');
  });

  test('quiet and closed rooms move to saved, mine first', () {
    final mine = svc.create(title: 'غرفتي', category: VoiceCategory.chat)..live = true;
    final other = svc.create(title: 'غرفة سارة', category: VoiceCategory.chat)..live = true;
    other.host = VoiceUser(id: 'x', name: 'سارة', avatar: 1, isBot: false);
    expect(svc.live, containsAll([mine, other]));
    expect(svc.saved, isEmpty);
    other.lastActive = DateTime.now().subtract(const Duration(minutes: 2));
    mine.lastActive = DateTime.now().subtract(const Duration(hours: 5));
    other.lastActive = DateTime.now().subtract(const Duration(minutes: 10));
    expect(svc.live, isNot(contains(other)));
    expect(svc.saved, [mine, other]);
  });

  test('host reopens a closed saved room, others cannot', () {
    final r = svc.create(title: 'غرفتي', category: VoiceCategory.chat);
    r.closed = true;
    r.host = VoiceUser(id: 'x', name: 'سارة', avatar: 1, isBot: false);
    r.live = true;
    expect(svc.join(r), isNotNull);
    r.host = svc.me();
    r.live = false;
    // غرفة محلية مغلقة لا تُفتح، الحقيقية فقط
    expect(svc.join(r), isNotNull);
  });

  test('last seen label', () {
    final now = DateTime(2026, 11, 12, 18);
    expect(lastSeenLabel(now.subtract(const Duration(seconds: 20)), now: now), 'الآن');
    expect(lastSeenLabel(now.subtract(const Duration(minutes: 7)), now: now), 'قبل 7 د');
    expect(lastSeenLabel(now.subtract(const Duration(hours: 3)), now: now), 'قبل 3 س');
    expect(lastSeenLabel(now.subtract(const Duration(days: 1)), now: now), 'أمس');
    expect(lastSeenLabel(now.subtract(const Duration(days: 4)), now: now), 'قبل 4 يوم');
  });

  test('host deletes a saved room', () {
    final r = svc.create(title: 'غرفتي', category: VoiceCategory.chat);
    svc.deleteSaved(r);
    expect(svc.rooms, isNot(contains(r)));
  });

  test('room count uses only people really present', () {
    final r = svc.create(title: 'غرفتي', category: VoiceCategory.chat, seats: 8);
    final ghost = VoiceUser(id: 'ghost', name: 'طلع', avatar: 1, isBot: false);
    r.seats[2].user = ghost;
    r.presentIds = {svc.me().id, 'a', 'b'};
    expect(r.online, 3);
    expect(r.isPresent(ghost), isFalse);
    r.presentIds = null;
    expect(r.online, greaterThan(0));
  });

  test('room list counts only fresh "here" marks', () {
    final r = svc.create(title: 'غرفة', category: VoiceCategory.chat, seats: 8)..live = true;
    final now = DateTime.now();
    r.seats[1].user = VoiceUser(id: 'ghost', name: 'طلع', avatar: 1, isBot: false);
    r.seats[2].user = VoiceUser(id: 'real', name: 'موجود', avatar: 2, isBot: false);
    r.hereKnown = true;
    r.hereAt = {'real': now.subtract(const Duration(seconds: 10)), 'ghost': now.subtract(const Duration(hours: 2))};
    r.host = VoiceUser(id: 'host', name: 'المضيف', avatar: 3, isBot: false);
    r.lastActive = now.subtract(const Duration(seconds: 30));
    r.presentIds = r.freshHere();
    expect(r.presentIds, {'real'});
    expect(r.online, 1);
    expect(r.micsHere, 1, reason: 'only the present person counts on the mics');
    expect(r.active, isTrue);
    r.hereAt = {'ghost': now.subtract(const Duration(hours: 2))};
    r.presentIds = r.freshHere();
    expect(r.active, isFalse, reason: 'nobody really there = saved room');
  });

  test('my room is the banner room; visited rooms show newest first, mine excluded', () {
    expect(svc.myRoom, isNull);
    final mine = svc.create(title: 'غرفتي', category: VoiceCategory.chat)..live = true;
    expect(svc.myRoom, mine);
    final a = svc.create(title: 'أ', category: VoiceCategory.chat);
    a.host = VoiceUser(id: 'a', name: 'أ', avatar: 1, isBot: false);
    final b = svc.create(title: 'ب', category: VoiceCategory.chat);
    b.host = VoiceUser(id: 'b', name: 'ب', avatar: 2, isBot: false);
    svc.join(a);
    svc.leave(a);
    svc.join(b);
    svc.leave(b);
    svc.visited[a.id] = DateTime.now().add(const Duration(seconds: 1));
    svc.join(mine);
    svc.leave(mine);
    expect(svc.recent, [a, b]);
  });
}
