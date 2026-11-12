import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/shop.dart';
import 'package:mojan/core/voice/voice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final svc = VoiceService.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Account.instance.reset();
    svc.reset();
    await Account.instance.signIn(method: AuthMethod.guest, name: 'موكا');
  });

  test('host moves to any mic and back to the top seat', () {
    final r = svc.create(title: 'غرفتي', category: VoiceCategory.chat, seats: 8);
    expect(svc.hostMoveTo(r, 5), isNull);
    expect(r.seats[5].user?.isMe, isTrue);
    expect(r.hostSeated, isTrue);
    expect(r.onMics.where((u) => u.id == r.host.id).length, 1, reason: 'host is counted once');
    svc.hostMoveTo(r, 2);
    expect(r.seats[5].user, isNull);
    expect(r.seats[2].user?.isMe, isTrue);
    svc.leaveSeat(r);
    expect(r.hostSeated, isFalse);
    expect(svc.isHost(r), isTrue);
  });

  test('lock and open all mics at once', () {
    final r = svc.create(title: 'غرفتي', category: VoiceCategory.chat, seats: 8);
    svc.hostMoveTo(r, 0);
    svc.lockAll(r, true);
    expect(r.seats.skip(1).every((s) => s.locked), isTrue);
    expect(r.seats[0].locked, isFalse, reason: 'occupied seat is untouched');
    svc.lockAll(r, false);
    expect(r.seats.every((s) => !s.locked), isTrue);
  });

  test('invite a specific person to a chosen mic', () async {
    final r = svc.create(title: 'غرفتي', category: VoiceCategory.chat, seats: 8);
    final guest = VoiceUser(id: 'g1', name: 'سارة', avatar: 2);
    r.audience.add(guest);
    expect(svc.inviteUser(r, guest, 3), isNull);
    await Future.delayed(const Duration(milliseconds: 1400));
    expect(r.seats[3].user?.id, 'g1');
    expect(svc.inviteUser(r, guest), contains('على المايك'));
  });

  test('invite dialog: accepting takes the invited seat', () {
    final r = svc.create(title: 'غرفة', category: VoiceCategory.chat, seats: 8);
    r.host = VoiceUser(id: 'other', name: 'المضيف', avatar: 1);
    svc.gotInvite(r, 4);
    expect(svc.pendingInvite?.seat, 4);
    expect(svc.answerInvite(true), isNull);
    expect(r.seats[4].user?.isMe, isTrue);
    expect(svc.pendingInvite, isNull);
  });

  test('chairs are sold in the shop and dress my rooms', () {
    final acc = Account.instance;
    acc.profile!.coins = 100000;
    final item = shopItem('chair.throne');
    expect(acc.buy(item), isNull);
    svc.ensureRooms();
    final r = svc.create(title: 'غرفتي', category: VoiceCategory.chat);
    acc.onChairChanged = svc.applyMyChair;
    acc.equip('chair.throne');
    expect(acc.profile!.chair, 'throne');
    expect(r.chair, 'throne');
    final r2 = svc.create(title: 'ثانية', category: VoiceCategory.chat);
    expect(r2.chair, 'throne');
    expect(styleCatalog.where((i) => i.kind == ShopKind.chair).length, 8);
  });
}
