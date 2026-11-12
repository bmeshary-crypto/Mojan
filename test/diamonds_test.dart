import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/gifts/diamonds.dart';
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
}
