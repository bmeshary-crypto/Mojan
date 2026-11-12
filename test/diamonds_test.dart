import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/gifts/diamonds.dart';
import 'package:mojan/core/num_format.dart';
import 'package:mojan/core/shop.dart';
import 'package:mojan/core/voice/voice.dart';
import 'package:mojan/widgets/game_social.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Account.instance.reset();
    await Account.instance.signIn(method: AuthMethod.guest, name: 'موكا');
  });

  test('receiver gets 30% of the gift value as diamonds', () {
    expect(diamondsFor(1000), 300);
    expect(diamondsFor(10), 3);
    expect(diamondsFor(5), 1);
    expect(diamondsFor(3), 0);
  });

  test('diamonds are saved in the profile', () {
    Account.instance.addDiamonds(45);
    final p = Account.instance.profile!;
    expect(p.diamonds, 45);
    final back = PlayerProfile.fromJson(p.toJson());
    expect(back.diamonds, 45);
  });

  test('game gifts: emojis are cheap, gifts cost more', () {
    expect(gameEmojis.every((g) => g.price <= 5), isTrue);
    expect(gameGifts.every((g) => g.price >= 10), isTrue);
    expect(gameGiftByEmoji('🌹')?.price, 10);
  });

  test('diamonds swap to coins 1:1', () {
    final acc = Account.instance;
    final coins = acc.profile!.coins;
    acc.addDiamonds(500);
    expect(acc.exchangeDiamonds(600), isFalse);
    expect(acc.exchangeDiamonds(200), isTrue);
    expect(acc.profile!.diamonds, 300);
    expect(acc.profile!.coins, coins + 200);
  });

  test('special shop items cost 30% less in diamonds', () {
    final acc = Account.instance;
    final item = shopItem(diamondPicks.first);
    final price = acc.diamondPriceFor(item);
    expect(price, (item.price * .7).round());
    expect(acc.buyWithDiamonds(item), isNotNull);
    acc.addDiamonds(price);
    expect(acc.buyWithDiamonds(item), isNull);
    expect(acc.profile!.owns(item.id), isTrue);
    expect(acc.profile!.diamonds, 0);
    for (final id in diamondPicks) {
      shopItem(id);
    }
  });

  test('big numbers are shortened', () {
    expect(fmtK(950), '950');
    expect(fmtK(1500), '1.5K');
    expect(fmtK(2000000), '2M');
  });

  test('animated gifts are listed', () {
    expect(voiceGifts.where((g) => g.animated).length, greaterThanOrEqualTo(15));
    expect(giftById('dragon').art, 'assets/images/ag_dragon.webp');
  });
}
