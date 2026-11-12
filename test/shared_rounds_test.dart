import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/rounds/shared_rounds.dart';
import 'package:mojan/games/coin_games/fruits.dart';
import 'package:mojan/games/coin_games/rocket.dart';
import 'package:mojan/games/sky_wheel/sky_wheel_engine.dart';

void main() {
  test('every device computes the same round results', () {
    // نفس الجولة تعطي نفس النتيجة دائماً
    for (var r = 1000; r < 1020; r++) {
      expect(SkyWheelGame.winnerFor(r), SkyWheelGame.winnerFor(r));
      expect(fruitWinnerFor(r), fruitWinnerFor(r));
    }
    // ونتائج الجولات تختلف عن بعض
    expect({for (var r = 0; r < 50; r++) SkyWheelGame.winnerFor(r)}.length, greaterThan(3));

    // جهازين: واحد فتح بدري، والثاني فتح بعده بدقائق، يوصلون لنفس جولة الصاروخ
    const t = 1794500000000;
    final a = rocketSlotAt(t);
    var b = rocketSlotAt(t - 600000);
    while (b.end <= t) {
      b = b.next();
    }
    expect(b.id, a.id);
    expect(b.crash, a.crash);
    expect(b.start, a.start);

    // الرهانات الآلية وترتيب الساعة متطابقة
    final g1 = SkyWheelGame(synced: true)..loadShared(5000, [('ريم', 1), ('فيصل', 2)], hourStartRound: 4900);
    final g2 = SkyWheelGame(synced: true)..loadShared(5000, [('ريم', 1), ('فيصل', 2)], hourStartRound: 4900);
    g1.botsBet();
    g2.botsBet();
    expect(g1.totals, g2.totals);
    expect(g1.history, g2.history);
    expect(g1.hourlyTop.map((w) => '${w.name}${w.amount}'), g2.hourlyTop.map((w) => '${w.name}${w.amount}'));
    expect(roundSeed('sky', 1), isNot(roundSeed('sky', 2)));
  });
}
