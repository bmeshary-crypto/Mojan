import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/ban.dart';
import 'package:mojan/core/voice/voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final acc = Account.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    acc.reset();
    VoiceService.instance.reset();
    Restrictions.instance.set(null);
    await acc.signIn(method: AuthMethod.guest, name: 'موكا');
  });
  tearDown(() => Restrictions.instance.set(null));

  test('ban info: old and new formats, duration and expiry', () {
    expect(BanInfo.parse(true)!.full, isTrue);
    expect(BanInfo.parse(true)!.active, isTrue, reason: 'old bans are permanent');
    expect(BanInfo.parse(false), isNull);
    expect(BanInfo.parse(null), isNull);
    final soon = DateTime.now().add(const Duration(hours: 5, minutes: 30));
    final b = BanInfo.parse(BanInfo(limits: {'mic', 'chat'}, until: soon, reason: 'سب').toJson())!;
    expect(b.full, isFalse);
    expect(b.limits, {'mic', 'chat'});
    expect(b.reason, 'سب');
    expect(b.active, isTrue);
    expect(b.remaining(), contains('5 ساعة'));
    expect(b.activeAt(soon.add(const Duration(minutes: 1))), isFalse);
    final old = BanInfo(full: true, until: DateTime.now().subtract(const Duration(minutes: 1)));
    Restrictions.instance.set(old);
    expect(Restrictions.instance.fullBan.value, isFalse, reason: 'expired bans do nothing');
  });

  test('restrictions block only what the admin chose', () {
    final voice = VoiceService.instance..ensureDemo();
    final room = voice.rooms.firstWhere((r) => !r.locked && !r.closed);
    Restrictions.instance.set(BanInfo(limits: {'chat', 'coins'}, until: DateTime.now().add(const Duration(days: 1))));
    expect(Restrictions.instance.fullBan.value, isFalse);
    expect(acc.spend(10), isFalse, reason: 'coins are frozen');
    expect(voice.join(room), isNull, reason: 'rooms are still allowed');
    expect(voice.sendMessage(room, 'هلا'), contains('ممنوع'));
    Restrictions.instance.set(BanInfo(limits: {'rooms'}));
    expect(acc.spend(10), isTrue);
    voice.leave(room);
    expect(voice.join(room), contains('ممنوع'));
    Restrictions.instance.set(const BanInfo(full: true));
    expect(Restrictions.instance.fullBan.value, isTrue);
    Restrictions.instance.set(null);
    expect(Restrictions.instance.check('mic'), isNull);
  });
}
