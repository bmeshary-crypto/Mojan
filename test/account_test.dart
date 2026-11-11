import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/account/auth_backend.dart';
import 'package:mojan/core/account/leaderboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final acc = Account.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    acc.reset();
  });

  test('level curve: 100 xp for level 2, then +50 per level', () {
    expect(PlayerProfile.levelOf(0).$1, 1);
    expect(PlayerProfile.levelOf(99).$1, 1);
    expect(PlayerProfile.levelOf(100).$1, 2);
    expect(PlayerProfile.levelOf(249).$1, 2);
    expect(PlayerProfile.levelOf(250).$1, 3);
  });

  test('no account means games record nothing', () {
    expect(acc.recordGame('ludo', won: true), isNull);
  });

  test('recording games gives xp, coins, stats and achievements', () async {
    await acc.signIn(method: AuthMethod.guest, name: 'سارة');
    final p = acc.profile!;
    expect(p.coins, 500);
    final r = acc.recordGame('ludo', won: true, points: 400)!;
    expect(r.coins, 100);
    expect(r.xp, 62);
    expect(r.unlocked.map((a) => a.id), containsAll(['first_game', 'first_win']));
    expect(p.coins, 500 + 100 + 50 * 2);
    expect(p.statsFor('ludo').wins, 1);
    expect(p.statsFor('ludo').best, 400);
    final lose = acc.recordGame('quiz', won: false, points: 3000)!;
    expect(lose.coins, 25);
    expect(lose.xp, 20 + 15);
    expect(lose.levelUp, isFalse);
    acc.recordGame('seeko', won: false);
    final last = acc.recordGame('truth_dare', won: false)!;
    expect(last.unlocked.map((a) => a.id), contains('all_games'));
    expect(p.totalPlayed, 4);
  });

  test('profile survives save and load', () async {
    await acc.signIn(method: AuthMethod.phone, name: 'خالد', contact: '+966500000000');
    acc.recordGame('seeko', won: true, points: 300);
    await acc.rename('خالد ٢');
    await acc.setHaptics(false);
    acc.reset();
    expect(acc.profile, isNull);
    await acc.load();
    expect(acc.profile!.name, 'خالد ٢');
    expect(acc.profile!.method, AuthMethod.phone);
    expect(acc.profile!.statsFor('seeko').wins, 1);
    expect(acc.haptics, isFalse);
    await acc.signOut();
    acc.reset();
    await acc.load();
    expect(acc.profile, isNull);
  });

  test('daily reward grows with the streak and resets after a gap', () async {
    await acc.signIn(method: AuthMethod.guest, name: 'x');
    final d1 = DateTime(2026, 1, 1, 10);
    expect(acc.claimDaily(now: d1), 100);
    expect(acc.claimDaily(now: d1), isNull, reason: 'once per day');
    expect(acc.claimDaily(now: d1.add(const Duration(days: 1))), 200);
    expect(acc.claimDaily(now: d1.add(const Duration(days: 2))), 300);
    expect(acc.claimDaily(now: d1.add(const Duration(days: 5))), 100, reason: 'missed days reset');
  });

  test('guest can link to phone and keep progress', () async {
    await acc.signIn(method: AuthMethod.guest, name: 'ضيف');
    acc.recordGame('quiz', won: true, points: 5000);
    await acc.link(method: AuthMethod.phone, contact: '+966511111111');
    expect(acc.profile!.method, AuthMethod.phone);
    expect(acc.profile!.statsFor('quiz').wins, 1);
  });

  test('leaderboard is sorted and includes me with my real points', () async {
    await acc.signIn(method: AuthMethod.guest, name: 'أنا');
    acc.recordGame('quiz', won: true, points: 9000);
    for (final game in [null, 'quiz', 'ludo']) {
      final list = Leaderboard.build(acc.profile, game: game);
      for (var i = 1; i < list.length; i++) {
        expect(list[i - 1].points, greaterThanOrEqualTo(list[i].points));
      }
      expect(list.where((e) => e.isMe).length, 1);
    }
    final quiz = Leaderboard.build(acc.profile, game: 'quiz').firstWhere((e) => e.isMe);
    expect(quiz.points, 9000 + 100);
    expect(Leaderboard.build(null).any((e) => e.isMe), isFalse);
  });

  test('demo auth: phone validation and code check', () async {
    const auth = DemoAuthBackend(delay: Duration.zero);
    expect(isValidPhone('+966501234567'), isTrue);
    expect(isValidPhone('0501234567'), isFalse);
    await expectLater(auth.sendPhoneCode('+12'), throwsA(isA<AuthError>()));
    await expectLater(auth.verifyPhoneCode('+966501234567', '123456'), throwsA(isA<AuthError>()));
    final id = await auth.verifyPhoneCode('+966501234567', '000000');
    expect(id.contact, '+966501234567');
  });
}
