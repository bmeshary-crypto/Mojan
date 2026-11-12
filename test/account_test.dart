import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/shop.dart';
import 'package:mojan/games/ludo/ludo_engine.dart';
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
    acc.recordGame('blocks', won: false);
    final last = acc.recordGame('truth_dare', won: false)!;
    expect(last.unlocked.map((a) => a.id), contains('all_games'));
    expect(p.totalPlayed, 5);
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

  test('7-day daily bonus grows with the streak, gives items and skins, resets after a gap', () async {
    await acc.signIn(method: AuthMethod.guest, name: 'x');
    final p = acc.profile!;
    final d1 = DateTime(2026, 1, 1, 10);
    DateTime day(int n) => d1.add(Duration(days: n));
    expect(acc.claimDaily(now: d1)!.coins, 300);
    expect(acc.claimDaily(now: d1), isNull, reason: 'once per day');
    expect(acc.claimDaily(now: day(1))!.coins, 500);
    expect(p.coins, 500 + 300 + 500);
    acc.claimDaily(now: day(2));
    expect(p.itemCount(LudoItem.shield), 2);
    acc.claimDaily(now: day(3));
    expect(acc.claimDaily(now: day(4))!.skin, 'dice.gold');
    expect(p.owns('dice.gold'), isTrue);
    acc.claimDaily(now: day(5));
    final d7 = acc.claimDaily(now: day(6))!;
    expect(d7.coins, 2000);
    expect(p.itemCount(LudoItem.diceControl), 1);
    expect(acc.claimDaily(now: day(7))!.coins, 300, reason: 'cycle restarts after day 7');
    expect(acc.claimDaily(now: day(10))!.coins, 300, reason: 'missed days reset');
  });

  test('shop: buy, equip, items, bundle, chest and spending', () async {
    await acc.signIn(method: AuthMethod.guest, name: 'x');
    final p = acc.profile!;
    expect(p.owns('dice.classic'), isTrue);
    expect(acc.buy(shopItem('dice.gold')), 'عملاتك لا تكفي');
    acc.earn(10000);
    expect(acc.buy(shopItem('dice.gold')), isNull);
    expect(p.coins, 10500 - 1500);
    expect(acc.buy(shopItem('dice.gold')), 'تملكه بالفعل');
    acc.equip('dice.gold');
    expect(p.diceSkin, 'gold');
    acc.equip('board.night');
    expect(p.boardTheme, 'classic', reason: 'cannot equip what you do not own');
    expect(acc.buy(shopItem('item.shield')), isNull);
    expect(p.itemCount(LudoItem.shield), 1);
    expect(acc.buy(shopItem('bundle.power')), isNull);
    expect(p.itemCount(LudoItem.shield), 4);
    expect(p.itemCount(LudoItem.doubleDistance), 3);
    expect(acc.consumeItem(LudoItem.shield), isTrue);
    expect(p.itemCount(LudoItem.shield), 3);

    final now = DateTime(2026, 1, 1, 10);
    final before = p.coins;
    expect(acc.claimChest(now: now), Account.chestCoins);
    expect(acc.claimChest(now: now.add(const Duration(hours: 1))), isNull);
    expect(acc.chestWait(now: now.add(const Duration(hours: 1))), const Duration(hours: 3));
    expect(acc.claimChest(now: now.add(const Duration(hours: 4))), Account.chestCoins);
    expect(p.coins, before + 2 * Account.chestCoins);

    expect(acc.spend(p.coins + 1), isFalse);
    expect(acc.spend(100), isTrue);
    expect(ludoPrize(1000, 4), 3800);
    expect(ludoPrize(1000, 4, teams: true), 1900);

    // يبقى محفوظاً بعد إعادة التحميل
    await acc.setHaptics(true); // ينتظر آخر حفظ
    acc.reset();
    await acc.load();
    expect(acc.profile!.owns('dice.gold'), isTrue);
    expect(acc.profile!.diceSkin, 'gold');
    expect(acc.profile!.itemCount(LudoItem.shield), 3);
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
