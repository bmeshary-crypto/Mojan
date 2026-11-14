import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/games/arena/arena_engine.dart';

void main() {
  test('map is generated with towns, walls and loot', () {
    final g = ArenaGame(seed: 7);
    expect(g.towns.length, greaterThanOrEqualTo(5));
    expect(g.buildings, isNotEmpty);
    expect(g.pickups.length, greaterThan(60));
  });

  test('a full match ends with one winner and the zone closes', () {
    final g = ArenaGame(seed: 9, endOnPlayerDeath: false);
    g.start(const Offset(1600, 1600));
    final input = ArenaInput();
    var t = 0.0;
    var i = 0;
    while (!g.over && t < 600) {
      if (i++ % 20 == 0) {
        input.move = Offset((i * 37 % 7) - 3.0, (i * 13 % 5) - 2.0);
        input.aim = Offset((i * 11 % 9) - 4.0, (i * 7 % 3) - 1.0);
        input.fire = i % 3 == 0;
      }
      g.update(1 / 30, input);
      g.sounds.clear();
      t += 1 / 30;
    }
    expect(g.over, isTrue);
    final kills = g.fighters.fold<int>(0, (a, f) => a + f.kills);
    // ignore: avoid_print
    print('ended at ${t.toStringAsFixed(0)}s, alive ${g.aliveCount}, kills $kills, player place ${g.player.place}');
    expect(g.player.place, greaterThan(0));
    expect(kills, greaterThan(3));
  });

  test('bullets stop at walls and armor absorbs damage', () {
    final g = ArenaGame(seed: 11, botCount: 1);
    g.start(const Offset(400, 400));
    final me = g.player, bot = g.fighters[1];
    bot.pos = me.pos + const Offset(100, 0);
    g.obstacles.clear();
    bot.armor = 50;
    me.angle = 0;
    me.slots[0] = Gun(WeaponKind.sniper);
    g.time = 10;
    expect(g.tryFire(me), isTrue);
    for (var i = 0; i < 10; i++) {
      g.update(1 / 60, ArenaInput());
    }
    expect(bot.hp, lessThan(100));
    expect(bot.armor, lessThan(50));
  });

  test('walking over loot picks it up (weapon, ammo, armor)', () {
    final g = ArenaGame(seed: 5, botCount: 1);
    g.start(const Offset(500, 500));
    final me = g.player;
    g.pickups
      ..clear()
      ..add(Pickup(PickupKind.weapon, me.pos, weapon: WeaponKind.rifle))
      ..add(Pickup(PickupKind.ammo, me.pos, ammo: AmmoType.heavy, amount: 30))
      ..add(Pickup(PickupKind.armor, me.pos, amount: 50));
    g.update(1 / 60, ArenaInput());
    expect(me.slots[1]?.kind, WeaponKind.rifle);
    expect(me.ammo[AmmoType.heavy], 30);
    expect(me.armor, 50);
    // سلاح ثالث يحتاج زر الالتقاط ويستبدل الحالي
    g.pickups.add(Pickup(PickupKind.weapon, me.pos, weapon: WeaponKind.sniper));
    g.update(1 / 60, ArenaInput());
    expect(g.weaponNear(me), isNotNull);
    g.takeWeapon(me, g.weaponNear(me)!);
    expect(me.gun?.kind, WeaponKind.sniper);
    expect(g.pickups.any((p) => p.weapon == WeaponKind.rifle), isTrue);
  });
}
