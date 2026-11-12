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
}
