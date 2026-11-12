import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/account/auth_backend.dart';
import 'package:mojan/core/account/leaderboard.dart';
import 'package:mojan/core/firebase/cloud.dart';

void main() {
  test('cloud stays off in tests and demo auth is used', () async {
    await Cloud.instance.init();
    expect(Cloud.instance.enabled, isFalse);
    expect(authBackend.isDemo, isTrue);
    expect((await authBackend.signInGuest()).uid, isNotEmpty);
  });

  test('week starts on Saturday', () {
    expect(weekKey(DateTime(2026, 11, 12)), '2026-11-07'); // خميس
    expect(weekKey(DateTime(2026, 11, 7)), '2026-11-07'); // سبت
    expect(weekKey(DateTime(2026, 11, 6)), '2026-10-31'); // جمعة
  });

  test('merge puts my live score among real players', () {
    final me = PlayerProfile(id: 'u1', name: 'أنا', method: AuthMethod.guest);
    me.statsFor('ludo')
      ..wins = 3
      ..points = 50;
    final cloud = [
      const LeaderEntry(name: 'سارة', avatar: 1, points: 900, wins: 5),
      const LeaderEntry(name: 'أنا', avatar: 0, points: 10, wins: 0, isMe: true),
      const LeaderEntry(name: 'خالد', avatar: 2, points: 100, wins: 1),
    ];
    final list = Leaderboard.merge(cloud, me);
    expect(list.where((e) => e.isMe).length, 1);
    expect(list.firstWhere((e) => e.isMe).points, Leaderboard.scoreOf(me, null));
    expect(list.map((e) => e.name).toList(), ['سارة', 'أنا', 'خالد']);
  });
}
