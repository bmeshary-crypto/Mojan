import 'dart:math';
import 'dart:ui' show Offset, Rect;

/// «ساحة البقاء»: لعبة معركة أخيرة من الأعلى (Top-down) بفكرة ورسوم خاصة بـ MOJAN.
/// المحرك هنا منطق صافٍ (بدون واجهة) حتى يسهل اختباره.

// ───────────────────────── الأسلحة ─────────────────────────

enum AmmoType {
  light('خفيفة'),
  heavy('ثقيلة'),
  shells('خرطوش'),
  long('قنص');

  const AmmoType(this.label);
  final String label;
}

enum WeaponKind {
  pistol('مسدس الصقر', AmmoType.light, 16, .30, 900, 520, .07, 1, 12, 1.2, 1),
  smg('رشاش العاصفة', AmmoType.light, 11, .085, 950, 480, .13, 1, 30, 1.6, 2),
  rifle('بندقية الذيب', AmmoType.heavy, 21, .13, 1150, 720, .05, 1, 30, 2.0, 3),
  shotgun('خرطوش الرعد', AmmoType.shells, 10, .85, 850, 330, .30, 7, 5, 2.4, 3),
  sniper('قناصة النسر', AmmoType.long, 85, 1.4, 1900, 1150, .008, 1, 5, 2.8, 4);

  const WeaponKind(
    this.label,
    this.ammo,
    this.damage,
    this.interval,
    this.speed,
    this.range,
    this.spread,
    this.pellets,
    this.mag,
    this.reload,
    this.tier,
  );
  final String label;
  final AmmoType ammo;
  final double damage;

  /// ثوانٍ بين كل طلقة.
  final double interval;
  final double speed;
  final double range;

  /// انحراف عشوائي (راديان).
  final double spread;
  final int pellets;
  final int mag;
  final double reload;

  /// قوة السلاح (البوتات تستبدل بالأقوى).
  final int tier;
}

class Gun {
  Gun(this.kind, [int? loaded]) : loaded = loaded ?? kind.mag;
  final WeaponKind kind;
  int loaded;
}

// ───────────────────────── الخريطة ─────────────────────────

enum ObstacleKind { tree, rock, wall, bush, crate, barrel }

class Obstacle {
  Obstacle.circle(this.kind, this.c, this.r) : rect = null;
  Obstacle.box(this.kind, Rect this.rect)
      : c = rect.center,
        r = rect.longestSide / 2;
  final ObstacleKind kind;
  final Offset c;
  final double r;
  final Rect? rect;
  bool get isBox => rect != null;
}

class Building {
  Building(this.floor);
  final Rect floor;
}

class Town {
  Town(this.name, this.center);
  final String name;
  final Offset center;
}

enum PickupKind { weapon, ammo, bandage, medkit, armor }

class Pickup {
  Pickup(this.kind, this.pos, {this.weapon, this.ammo, this.amount = 0, this.loaded});
  final PickupKind kind;
  Offset pos;
  final WeaponKind? weapon;
  final AmmoType? ammo;
  final int amount;
  final int? loaded;
  bool taken = false;
}

// ───────────────────────── المقاتلون ─────────────────────────

class Fighter {
  Fighter(this.id, this.name, this.pos, {this.isPlayer = false, required this.skin});
  final int id;
  final String name;
  final bool isPlayer;
  final int skin;
  Offset pos;
  double angle = 0;
  double hp = 100;
  double armor = 0;
  final List<Gun?> slots = [null, null];
  int active = 0;
  final Map<AmmoType, int> ammo = {for (final a in AmmoType.values) a: 0};
  int bandages = 0;
  int medkits = 0;
  int kills = 0;
  bool alive = true;
  int place = 0;
  double fireCd = 0;
  double reloadLeft = 0;

  /// علاج جارٍ: نوعه والوقت الباقي.
  PickupKind? healing;
  double healLeft = 0;

  /// آخر من ضربه (لحساب القتل في المنطقة).
  int? lastHitBy;
  double hurtFlash = 0;
  double muzzle = 0;

  // ذاكرة البوت
  Offset? goal;
  int? targetId;
  double think = 0;
  double strafe = 1;
  double strafeT = 0;
  double reaction = 0;
  Offset lastPos = Offset.zero;
  double stuckT = 0;

  Gun? get gun => slots[active];
  bool get reloading => reloadLeft > 0;
}

class Bullet {
  Bullet(this.pos, this.vel, this.damage, this.left, this.owner, this.kind);
  Offset pos;
  final Offset vel;
  final double damage;
  double left;
  final int owner;
  final WeaponKind kind;
  Offset prev = Offset.zero;
}

class KillEvent {
  KillEvent(this.killer, this.victim, this.weapon, this.at, {this.zone = false});
  final String? killer;
  final String victim;
  final WeaponKind? weapon;
  final double at;
  final bool zone;
}

/// أثر بصري مؤقت (شرارة/رقم ضرر).
class Fx {
  Fx(this.pos, this.kind, {this.value = 0, this.life = .5});
  Offset pos;
  final String kind; // hit, dmg, puff, blood
  final double value;
  double life;
  double age = 0;
}

// ───────────────────────── المنطقة ─────────────────────────

class ZonePhase {
  const ZonePhase(this.wait, this.shrink, this.radiusFrac, this.dps);
  final double wait;
  final double shrink;
  final double radiusFrac;
  final double dps;
}

const zonePhases = [
  ZonePhase(40, 25, .50, 2),
  ZonePhase(28, 20, .28, 4),
  ZonePhase(22, 16, .15, 7),
  ZonePhase(16, 14, .07, 11),
  ZonePhase(12, 14, .0, 16),
];

enum Difficulty {
  easy('سهل', .17, .55, .7),
  normal('عادي', .10, .35, 1),
  hard('صعب', .055, .2, 1.15);

  const Difficulty(this.label, this.aimError, this.reaction, this.botDamage);
  final String label;
  final double aimError;
  final double reaction;
  final double botDamage;
}

/// ما يرسله اللاعب كل إطار.
class ArenaInput {
  Offset move = Offset.zero;
  Offset? aim;
  bool fire = false;
}

// ───────────────────────── اللعبة ─────────────────────────

const botNames = [
  'صقر', 'ذيب_الليل', 'نمر77', 'أبو فهد', 'Shadow', 'قنّاص', 'Falcon', 'ريم', 'سهم', 'Ninja',
  'برق', 'جمر', 'Ghost', 'ليث', 'وحش_الرمل', 'Kiro', 'نجمة', 'Viper', 'زعيم', 'Raad',
  'رعد', 'ملك_الساحة', 'Blaze', 'لمى', 'Sniper99', 'جوكر', 'فارس', 'Storm', 'هيبة', 'ديناصور',
];

class ArenaGame {
  ArenaGame({
    required this.seed,
    this.botCount = 19,
    this.difficulty = Difficulty.normal,
    this.playerName = 'أنت',
    this.playerSkin = 0,
    this.endOnPlayerDeath = true,
  }) : rng = Random(seed) {
    _buildMap();
  }

  static const double size = 3200;
  static const double fighterR = 18;

  final int seed;
  final int botCount;
  final Difficulty difficulty;
  final String playerName;
  final int playerSkin;
  final bool endOnPlayerDeath;
  final Random rng;

  /// ثوانٍ بعد الهبوط لا يطلق فيها أحد.
  static const landingGrace = 4.0;

  final obstacles = <Obstacle>[];
  final bushes = <Obstacle>[];
  final buildings = <Building>[];
  final towns = <Town>[];
  final pickups = <Pickup>[];
  final fighters = <Fighter>[];
  final bullets = <Bullet>[];
  final feed = <KillEvent>[];
  final fx = <Fx>[];

  /// أصوات ينتظر الواجهة تشغيلها: (نوع, مسافة عن اللاعب).
  final sounds = <(String, double)>[];

  double time = 0;
  bool started = false;
  bool over = false;

  // المنطقة
  late Offset zoneC;
  late double zoneR;
  late Offset zoneFromC;
  late double zoneFromR;
  late Offset nextC;
  late double nextR;
  int phase = 0;
  double phaseT = 0;
  bool shrinking = false;

  Fighter get player => fighters.first;
  int get aliveCount => fighters.where((f) => f.alive).length;

  // ── بناء الخريطة ──

  void _buildMap() {
    const names = ['الواحة', 'الميناء', 'المزرعة', 'القلعة', 'المصنع', 'السوق', 'المطار'];
    final margin = 320.0;
    for (final n in names) {
      for (var tries = 0; tries < 50; tries++) {
        final c = Offset(margin + rng.nextDouble() * (size - 2 * margin), margin + rng.nextDouble() * (size - 2 * margin));
        if (towns.every((t) => (t.center - c).distance > 820)) {
          towns.add(Town(n, c));
          break;
        }
      }
    }
    for (final t in towns) {
      final n = 2 + rng.nextInt(3);
      for (var i = 0; i < n; i++) {
        for (var tries = 0; tries < 40; tries++) {
          final w = 220 + rng.nextDouble() * 200, h = 200 + rng.nextDouble() * 180;
          final c = t.center + Offset((rng.nextDouble() - .5) * 560, (rng.nextDouble() - .5) * 560);
          final r = Rect.fromCenter(center: c, width: w, height: h);
          if (r.left < 80 || r.top < 80 || r.right > size - 80 || r.bottom > size - 80) continue;
          if (buildings.any((b) => b.floor.inflate(70).overlaps(r))) continue;
          _addBuilding(r);
          break;
        }
      }
    }
    bool freeAt(Offset c, double r) =>
        buildings.every((b) => !b.floor.inflate(r + 40).contains(c)) &&
        obstacles.every((o) => o.isBox || (o.c - c).distance > o.r + r + 30);
    for (var i = 0; i < 140; i++) {
      final c = _randPoint(60);
      final r = 24 + rng.nextDouble() * 18;
      if (freeAt(c, r)) obstacles.add(Obstacle.circle(ObstacleKind.tree, c, r));
    }
    for (var i = 0; i < 50; i++) {
      final c = _randPoint(60);
      final r = 22 + rng.nextDouble() * 26;
      if (freeAt(c, r)) obstacles.add(Obstacle.circle(ObstacleKind.rock, c, r));
    }
    // صناديق وبراميل قرب المباني وفي الطرقات
    for (final b in [...buildings]) {
      for (var k = 0; k < 2; k++) {
        final side = rng.nextInt(4);
        final f = b.floor;
        final c = switch (side) {
          0 => Offset(f.left + rng.nextDouble() * f.width, f.top - 40),
          1 => Offset(f.right + 40, f.top + rng.nextDouble() * f.height),
          2 => Offset(f.left + rng.nextDouble() * f.width, f.bottom + 40),
          _ => Offset(f.left - 40, f.top + rng.nextDouble() * f.height),
        };
        if (freeAt(c, 20)) obstacles.add(Obstacle.circle(rng.nextInt(3) == 0 ? ObstacleKind.barrel : ObstacleKind.crate, c, 20));
      }
    }
    for (var i = 0; i < 30; i++) {
      final c = _randPoint(80);
      if (freeAt(c, 20)) obstacles.add(Obstacle.circle(rng.nextBool() ? ObstacleKind.barrel : ObstacleKind.crate, c, 20));
    }
    for (var i = 0; i < 60; i++) {
      final c = _randPoint(60);
      final r = 36 + rng.nextDouble() * 18;
      if (freeAt(c, r)) bushes.add(Obstacle.circle(ObstacleKind.bush, c, r));
    }
    // غنائم داخل المباني وحولها
    for (final b in buildings) {
      final n = 3 + rng.nextInt(3);
      for (var i = 0; i < n; i++) {
        final p = Offset(
          b.floor.left + 40 + rng.nextDouble() * (b.floor.width - 80),
          b.floor.top + 40 + rng.nextDouble() * (b.floor.height - 80),
        );
        _spawnLoot(p, inside: true);
      }
    }
    for (var i = 0; i < 90; i++) {
      final p = _randPoint(80);
      if (_blockedAt(p, 14)) continue;
      _spawnLoot(p, inside: false);
    }
  }

  void _addBuilding(Rect r) {
    buildings.add(Building(r));
    const t = 16.0, door = 84.0;
    final sides = [0, 1, 2, 3]..shuffle(rng);
    final doors = sides.take(2).toSet();
    void wall(Rect w) => obstacles.add(Obstacle.box(ObstacleKind.wall, w));
    void side(int s) {
      final horiz = s == 0 || s == 2;
      final len = horiz ? r.width : r.height;
      final rect = switch (s) {
        0 => Rect.fromLTWH(r.left, r.top, r.width, t),
        1 => Rect.fromLTWH(r.right - t, r.top, t, r.height),
        2 => Rect.fromLTWH(r.left, r.bottom - t, r.width, t),
        _ => Rect.fromLTWH(r.left, r.top, t, r.height),
      };
      if (!doors.contains(s)) return wall(rect);
      final at = (len - door) * (.3 + rng.nextDouble() * .4);
      if (horiz) {
        wall(Rect.fromLTWH(rect.left, rect.top, at, t));
        wall(Rect.fromLTRB(rect.left + at + door, rect.top, rect.right, rect.bottom));
      } else {
        wall(Rect.fromLTWH(rect.left, rect.top, t, at));
        wall(Rect.fromLTRB(rect.left, rect.top + at + door, rect.right, rect.bottom));
      }
    }
    for (var s = 0; s < 4; s++) {
      side(s);
    }
  }

  Offset _randPoint(double margin) =>
      Offset(margin + rng.nextDouble() * (size - 2 * margin), margin + rng.nextDouble() * (size - 2 * margin));

  WeaponKind _randWeapon() {
    final roll = rng.nextInt(100);
    if (roll < 12) return WeaponKind.pistol;
    if (roll < 40) return WeaponKind.smg;
    if (roll < 64) return WeaponKind.rifle;
    if (roll < 90) return WeaponKind.shotgun;
    return WeaponKind.sniper;
  }

  int ammoPack(AmmoType a) => switch (a) {
        AmmoType.light => 30,
        AmmoType.heavy => 30,
        AmmoType.shells => 10,
        AmmoType.long => 6,
      };

  void _spawnLoot(Offset p, {required bool inside}) {
    final roll = rng.nextInt(100);
    final weaponChance = inside ? 38 : 26;
    if (roll < weaponChance) {
      final w = _randWeapon();
      pickups.add(Pickup(PickupKind.weapon, p, weapon: w));
      pickups.add(Pickup(PickupKind.ammo, p + const Offset(26, 10), ammo: w.ammo, amount: ammoPack(w.ammo)));
    } else if (roll < 62) {
      final a = AmmoType.values[rng.nextInt(AmmoType.values.length)];
      pickups.add(Pickup(PickupKind.ammo, p, ammo: a, amount: ammoPack(a)));
    } else if (roll < 78) {
      pickups.add(Pickup(PickupKind.bandage, p, amount: 2));
    } else if (roll < 88) {
      pickups.add(Pickup(PickupKind.medkit, p, amount: 1));
    } else {
      pickups.add(Pickup(PickupKind.armor, p, amount: rng.nextInt(3) == 0 ? 100 : 50));
    }
  }

  // ── البداية ──

  /// يُنزل الجميع: اللاعب في [landing]، والبوتات قرب المدن أو عشوائياً.
  void start(Offset landing) {
    final used = <String>{};
    Offset land(Offset p) {
      var q = Offset(p.dx.clamp(60, size - 60), p.dy.clamp(60, size - 60));
      for (var i = 0; i < 30 && _blockedAt(q, fighterR + 4); i++) {
        q += Offset((rng.nextDouble() - .5) * 120, (rng.nextDouble() - .5) * 120);
        q = Offset(q.dx.clamp(60, size - 60), q.dy.clamp(60, size - 60));
      }
      return q;
    }

    fighters.add(Fighter(0, playerName, land(landing), isPlayer: true, skin: playerSkin));
    final names = [...botNames]..shuffle(rng);
    for (var i = 0; i < botCount; i++) {
      Offset spot;
      if (rng.nextInt(3) > 0 && towns.isNotEmpty) {
        final t = towns[rng.nextInt(towns.length)];
        spot = t.center + Offset((rng.nextDouble() - .5) * 600, (rng.nextDouble() - .5) * 600);
      } else {
        spot = _randPoint(100);
      }
      for (var k = 0; k < 20 && (spot - landing).distance < 450; k++) {
        spot = _randPoint(100);
      }
      final f = Fighter(i + 1, names[i % names.length], land(spot), skin: 1 + rng.nextInt(7));
      f.reaction = rng.nextDouble();
      fighters.add(f);
      used.add(f.name);
    }
    for (final f in fighters) {
      f.slots[0] = Gun(WeaponKind.pistol);
      f.ammo[AmmoType.light] = 24;
      f.angle = rng.nextDouble() * pi * 2;
      f.lastPos = f.pos;
    }
    zoneC = const Offset(size / 2, size / 2);
    zoneR = size * .72;
    zoneFromC = zoneC;
    zoneFromR = zoneR;
    _pickNext();
    started = true;
  }

  void _pickNext() {
    final p = zonePhases[phase];
    nextR = size * p.radiusFrac;
    final room = max(0.0, zoneR - nextR) * .85;
    final a = rng.nextDouble() * pi * 2, d = rng.nextDouble() * room;
    nextC = zoneC + Offset(cos(a) * d, sin(a) * d);
    final lo = min(nextR + 60, size / 2), hi = max(size - nextR - 60, size / 2);
    nextC = Offset(nextC.dx.clamp(lo, hi), nextC.dy.clamp(lo, hi));
    if (nextR == 0) nextC = zoneC + Offset(cos(a) * d * .5, sin(a) * d * .5);
  }

  /// الوقت الباقي على المرحلة الحالية (انتظار أو تضييق).
  double get zoneTimeLeft {
    if (phase >= zonePhases.length) return 0;
    final p = zonePhases[phase];
    return shrinking ? p.shrink - phaseT : p.wait - phaseT;
  }

  double get zoneDps => zonePhases[min(phase, zonePhases.length - 1)].dps;

  bool inZone(Offset p) => (p - zoneC).distance <= zoneR;

  // ── التحديث ──

  void update(double dt, ArenaInput input) {
    if (!started || over) return;
    dt = dt.clamp(0, .05);
    time += dt;
    _updateZone(dt);

    final me = player;
    if (me.alive) _control(me, dt, input);
    for (final f in fighters) {
      if (!f.alive) continue;
      if (!f.isPlayer) _bot(f, dt);
      _tickTimers(f, dt);
      if (!inZone(f.pos)) {
        _damage(f, zoneDps * dt, null, zone: true);
      }
    }
    _updateBullets(dt);
    for (final e in fx) {
      e.age += dt;
    }
    fx.removeWhere((e) => e.age >= e.life);
    if (feed.length > 6) feed.removeRange(0, feed.length - 6);

    final alive = fighters.where((f) => f.alive).toList();
    if ((endOnPlayerDeath && !me.alive) || alive.length <= 1) {
      if (alive.length == 1) alive.first.place = 1;
      over = true;
    }
  }

  void _updateZone(double dt) {
    if (phase >= zonePhases.length) return;
    final p = zonePhases[phase];
    phaseT += dt;
    if (!shrinking) {
      if (phaseT >= p.wait) {
        shrinking = true;
        phaseT = 0;
        zoneFromC = zoneC;
        zoneFromR = zoneR;
        sounds.add(('zone', 0));
      }
    } else {
      final k = (phaseT / p.shrink).clamp(0.0, 1.0);
      zoneC = Offset.lerp(zoneFromC, nextC, k)!;
      zoneR = zoneFromR + (nextR - zoneFromR) * k;
      if (k >= 1) {
        phase++;
        phaseT = 0;
        shrinking = false;
        if (phase < zonePhases.length) _pickNext();
      }
    }
  }

  void _tickTimers(Fighter f, double dt) {
    f.fireCd = max(0, f.fireCd - dt);
    f.hurtFlash = max(0, f.hurtFlash - dt);
    f.muzzle = max(0, f.muzzle - dt);
    if (f.reloadLeft > 0) {
      f.reloadLeft -= dt;
      if (f.reloadLeft <= 0) {
        f.reloadLeft = 0;
        final g = f.gun;
        if (g != null) {
          final need = g.kind.mag - g.loaded;
          final take = min(need, f.ammo[g.kind.ammo]!);
          g.loaded += take;
          f.ammo[g.kind.ammo] = f.ammo[g.kind.ammo]! - take;
        }
      }
    }
    if (f.healing != null) {
      f.healLeft -= dt;
      if (f.healLeft <= 0) {
        if (f.healing == PickupKind.medkit && f.medkits > 0) {
          f.medkits--;
          f.hp = 100;
        } else if (f.healing == PickupKind.bandage && f.bandages > 0) {
          f.bandages--;
          f.hp = min(max(f.hp, 75), f.hp + 20);
        }
        f.healing = null;
        if (f.isPlayer) sounds.add(('heal', 0));
      }
    }
  }

  double speedOf(Fighter f) {
    var s = 230.0;
    if (f.healing != null) s *= .45;
    if (_inBush(f.pos)) s *= .8;
    return s;
  }

  void _control(Fighter f, double dt, ArenaInput input) {
    var m = input.move;
    if (m.distance > 1) m = m / m.distance;
    if (m.distance > .05) _moveBy(f, m * speedOf(f) * dt);
    final aim = input.aim;
    if (aim != null && aim.distance > .01) {
      f.angle = aim.direction;
    } else if (m.distance > .2) {
      f.angle = m.direction;
    }
    if (input.fire) tryFire(f);
    _autoPickup(f);
  }

  // ── الحركة والتصادم ──

  void _moveBy(Fighter f, Offset d) {
    var p = f.pos + d;
    for (var pass = 0; pass < 2; pass++) {
      for (final o in obstacles) {
        if ((o.c - p).distance > o.r + fighterR + 4) continue;
        p = _pushOut(p, fighterR, o);
      }
    }
    p = Offset(p.dx.clamp(fighterR, size - fighterR), p.dy.clamp(fighterR, size - fighterR));
    f.pos = p;
  }

  static Offset _pushOut(Offset p, double r, Obstacle o) {
    if (!o.isBox) {
      final v = p - o.c;
      final d = v.distance;
      if (d >= o.r + r) return p;
      if (d < .001) return o.c + Offset(o.r + r, 0);
      return o.c + v / d * (o.r + r);
    }
    final b = o.rect!;
    final cx = p.dx.clamp(b.left, b.right), cy = p.dy.clamp(b.top, b.bottom);
    final v = p - Offset(cx, cy);
    final d = v.distance;
    if (d >= r) return p;
    if (d > .001) return Offset(cx, cy) + v / d * r;
    // داخل الجدار: ادفع من أقرب جهة
    final dl = p.dx - b.left, dr = b.right - p.dx, dtp = p.dy - b.top, db = b.bottom - p.dy;
    final m = [dl, dr, dtp, db].reduce(min);
    if (m == dl) return Offset(b.left - r, p.dy);
    if (m == dr) return Offset(b.right + r, p.dy);
    if (m == dtp) return Offset(p.dx, b.top - r);
    return Offset(p.dx, b.bottom + r);
  }

  bool _blockedAt(Offset p, double r) =>
      obstacles.any((o) => (o.c - p).distance < o.r + r + 2 && _pushOut(p, r, o) != p);

  bool _inBush(Offset p) => bushes.any((b) => (b.c - p).distance < b.r * .8);

  bool hiddenInBush(Fighter f) => _inBush(f.pos);

  /// هل الخط بين نقطتين خالٍ من العوائق؟
  bool clearLine(Offset a, Offset b) {
    for (final o in obstacles) {
      if (_segHit(a, b, o) != null) return false;
    }
    return true;
  }

  /// أول نقطة (0..1) يقطع فيها المقطع العائق، أو null.
  static double? _segHit(Offset a, Offset b, Obstacle o) {
    if (!o.isBox) return _segCircle(a, b, o.c, o.r);
    final r = o.rect!;
    final d = b - a;
    var t0 = 0.0, t1 = 1.0;
    final p = [-d.dx, d.dx, -d.dy, d.dy];
    final q = [a.dx - r.left, r.right - a.dx, a.dy - r.top, r.bottom - a.dy];
    for (var i = 0; i < 4; i++) {
      if (p[i] == 0) {
        if (q[i] < 0) return null;
      } else {
        final t = q[i] / p[i];
        if (p[i] < 0) {
          if (t > t1) return null;
          if (t > t0) t0 = t;
        } else {
          if (t < t0) return null;
          if (t < t1) t1 = t;
        }
      }
    }
    return t0;
  }

  static double? _segCircle(Offset a, Offset b, Offset c, double r) {
    final d = b - a, f = a - c;
    final aa = d.dx * d.dx + d.dy * d.dy;
    if (aa == 0) return f.distance <= r ? 0 : null;
    final bb = 2 * (f.dx * d.dx + f.dy * d.dy);
    final cc = f.dx * f.dx + f.dy * f.dy - r * r;
    if (cc <= 0) return 0;
    final disc = bb * bb - 4 * aa * cc;
    if (disc < 0) return null;
    final t = (-bb - sqrt(disc)) / (2 * aa);
    return t >= 0 && t <= 1 ? t : null;
  }

  // ── الإطلاق ──

  bool tryFire(Fighter f) {
    final g = f.gun;
    if (g == null || f.fireCd > 0 || f.reloading || time < landingGrace) return false;
    if (g.loaded <= 0) {
      reload(f);
      return false;
    }
    if (f.healing != null) f.healing = null;
    g.loaded--;
    f.fireCd = g.kind.interval;
    f.muzzle = .06;
    final k = g.kind;
    final muzzlePos = f.pos + Offset(cos(f.angle), sin(f.angle)) * (fighterR + 14);
    final dmgMul = f.isPlayer ? 1.0 : difficulty.botDamage;
    for (var i = 0; i < k.pellets; i++) {
      final a = f.angle + (rng.nextDouble() - .5) * k.spread * (k.pellets > 1 ? 1 : 2);
      final b = Bullet(muzzlePos, Offset(cos(a), sin(a)) * k.speed, k.damage * dmgMul, k.range, f.id, k);
      b.prev = f.pos;
      bullets.add(b);
    }
    sounds.add(('shot_${k.name}', (f.pos - player.pos).distance));
    if (g.loaded == 0) reload(f);
    return true;
  }

  void reload(Fighter f) {
    final g = f.gun;
    if (g == null || f.reloading || g.loaded >= g.kind.mag || f.ammo[g.kind.ammo]! <= 0) return;
    f.reloadLeft = g.kind.reload;
    if (f.isPlayer) sounds.add(('reload', 0));
  }

  void switchTo(Fighter f, int slot) {
    if (slot == f.active || f.slots[slot] == null) return;
    f.active = slot;
    f.reloadLeft = 0;
    f.fireCd = max(f.fireCd, .25);
  }

  void heal(Fighter f, PickupKind kind) {
    if (f.healing != null || f.hp >= 100) return;
    if (kind == PickupKind.medkit && f.medkits > 0) {
      f.healing = kind;
      f.healLeft = 3.5;
    } else if (kind == PickupKind.bandage && f.bandages > 0 && f.hp < 75) {
      f.healing = kind;
      f.healLeft = 1.6;
    }
  }

  void _updateBullets(double dt) {
    for (final b in bullets) {
      final from = b.pos;
      final step = b.vel * dt;
      var to = from + step;
      b.left -= step.distance;
      double? hitT;
      Fighter? hitF;
      for (final o in obstacles) {
        if ((o.c - from).distance > o.r + step.distance + 4) continue;
        final t = _segHit(from, to, o);
        if (t != null && (hitT == null || t < hitT)) hitT = t;
      }
      for (final f in fighters) {
        if (!f.alive || f.id == b.owner) continue;
        if ((f.pos - from).distance > fighterR + step.distance + 4) continue;
        final t = _segCircle(from, to, f.pos, fighterR);
        if (t != null && (hitT == null || t <= hitT)) {
          hitT = t;
          hitF = f;
        }
      }
      b.prev = from;
      if (hitT != null) {
        to = from + step * hitT;
        b.left = -1;
        if (hitF != null) {
          _damage(hitF, b.damage, b.owner, weapon: b.kind);
          fx.add(Fx(to, 'blood', life: .35));
          fx.add(Fx(hitF.pos + const Offset(0, -30), 'dmg', value: b.damage, life: .7));
        } else {
          fx.add(Fx(to, 'hit', life: .25));
        }
      }
      b.pos = to;
    }
    bullets.removeWhere((b) => b.left <= 0);
  }

  void _damage(Fighter f, double dmg, int? by, {WeaponKind? weapon, bool zone = false}) {
    if (!f.alive) return;
    if (!zone && f.armor > 0) {
      final absorb = min(f.armor, dmg * .5);
      f.armor -= absorb;
      dmg -= absorb;
    }
    f.hp -= dmg;
    if (!zone) {
      f.hurtFlash = .15;
      f.lastHitBy = by;
      if (f.healing != null) f.healing = null;
      if (f.isPlayer) sounds.add(('hurt', 0));
    }
    if (f.hp <= 0) _kill(f, zone ? null : by, weapon, zone: zone);
  }

  void _kill(Fighter f, int? by, WeaponKind? weapon, {bool zone = false}) {
    f.alive = false;
    f.hp = 0;
    f.place = aliveCount + 1;
    Fighter? killer;
    final kid = by ?? (zone ? null : f.lastHitBy);
    if (kid != null) {
      killer = fighters.firstWhere((x) => x.id == kid);
      killer.kills++;
    }
    feed.add(KillEvent(killer?.name, f.name, weapon, time, zone: zone));
    sounds.add((killer?.isPlayer == true ? 'kill' : 'death', (f.pos - player.pos).distance));
    fx.add(Fx(f.pos, 'puff', life: .6));
    // تسقط أغراضه
    var i = 0;
    Offset spot() {
      final a = i++ * 1.3;
      return f.pos + Offset(cos(a), sin(a)) * (16.0 + i * 6);
    }

    for (final g in f.slots) {
      if (g != null && g.kind != WeaponKind.pistol) {
        pickups.add(Pickup(PickupKind.weapon, spot(), weapon: g.kind, loaded: g.loaded));
      }
    }
    for (final a in AmmoType.values) {
      if (f.ammo[a]! > 0) pickups.add(Pickup(PickupKind.ammo, spot(), ammo: a, amount: f.ammo[a]!));
    }
    if (f.medkits > 0) pickups.add(Pickup(PickupKind.medkit, spot(), amount: f.medkits));
    if (f.bandages > 0) pickups.add(Pickup(PickupKind.bandage, spot(), amount: f.bandages));
    if (f.armor > 10) pickups.add(Pickup(PickupKind.armor, spot(), amount: f.armor.round()));
  }

  // ── الالتقاط ──

  static const pickRange = 34.0;

  /// أقرب سلاح على الأرض بجانب اللاعب (لزر «التقاط»).
  Pickup? weaponNear(Fighter f) {
    Pickup? best;
    var bd = pickRange + 10;
    for (final p in pickups) {
      if (p.taken || p.kind != PickupKind.weapon) continue;
      final d = (p.pos - f.pos).distance;
      if (d < bd) {
        bd = d;
        best = p;
      }
    }
    return best;
  }

  void _autoPickup(Fighter f) {
    for (final p in [...pickups]) {
      if (p.taken || (p.pos - f.pos).distance > pickRange) continue;
      switch (p.kind) {
        case PickupKind.weapon:
          final hasSame = f.slots.any((g) => g?.kind == p.weapon);
          if (!hasSame && f.slots.contains(null)) takeWeapon(f, p);
        case PickupKind.ammo:
          f.ammo[p.ammo!] = f.ammo[p.ammo!]! + p.amount;
          _taken(f, p);
        case PickupKind.bandage:
          if (f.bandages >= 10) continue;
          f.bandages += p.amount;
          _taken(f, p);
        case PickupKind.medkit:
          if (f.medkits >= 3) continue;
          f.medkits += p.amount;
          _taken(f, p);
        case PickupKind.armor:
          if (f.armor >= p.amount) continue;
          f.armor = p.amount.toDouble();
          _taken(f, p);
      }
    }
    pickups.removeWhere((p) => p.taken);
  }

  void _taken(Fighter f, Pickup p) {
    p.taken = true;
    if (f.isPlayer) sounds.add(('pickup', 0));
  }

  /// يلتقط السلاح: يملأ خانة فارغة أو يستبدل السلاح الحالي (ويرميه على الأرض).
  void takeWeapon(Fighter f, Pickup p) {
    final w = p.weapon!;
    var slot = f.slots.indexOf(null);
    if (slot < 0) {
      slot = f.active;
      final old = f.slots[slot]!;
      pickups.add(Pickup(PickupKind.weapon, f.pos + const Offset(0, 26), weapon: old.kind, loaded: old.loaded));
    }
    f.slots[slot] = Gun(w, p.loaded);
    f.active = slot;
    f.reloadLeft = 0;
    _taken(f, p);
    pickups.removeWhere((x) => x.taken);
  }

  // ── ذكاء البوتات ──

  void _bot(Fighter f, double dt) {
    f.think -= dt;
    f.strafeT -= dt;
    if (f.strafeT <= 0) {
      f.strafe = rng.nextBool() ? 1 : -1;
      f.strafeT = .6 + rng.nextDouble() * 1.2;
    }
    if (f.think <= 0) {
      f.think = .2 + rng.nextDouble() * .1;
      _botThink(f);
    }
    // التعلق
    if ((f.pos - f.lastPos).distance < 20) {
      f.stuckT += dt;
    } else {
      f.stuckT = 0;
      f.lastPos = f.pos;
    }
    if (f.stuckT > 1.2) {
      f.goal = f.pos + Offset((rng.nextDouble() - .5) * 500, (rng.nextDouble() - .5) * 500);
      f.stuckT = 0;
      f.lastPos = f.pos;
    }

    final target = f.targetId == null ? null : fighters[f.targetId!];
    var move = Offset.zero;
    if (target != null && target.alive) {
      final to = target.pos - f.pos;
      final dist = to.distance;
      final g = f.gun!;
      final want = switch (g.kind) {
        WeaponKind.shotgun => 120.0,
        WeaponKind.sniper => 650.0,
        WeaponKind.smg => 260.0,
        _ => 380.0,
      };
      final dir = to / max(dist, 1);
      final perp = Offset(-dir.dy, dir.dx) * f.strafe;
      move = perp * .8 + (dist > want + 60 ? dir : (dist < want - 60 ? -dir : Offset.zero));
      // تصويب مع خطأ
      f.reaction -= dt;
      final lead = target.isPlayer ? .0 : .0;
      final aimAt = target.pos + Offset.zero * lead;
      final ideal = (aimAt - f.pos).direction;
      final err = (rng.nextDouble() - .5) * 2 * difficulty.aimError * (dist > 500 ? 1.4 : 1);
      f.angle = ideal + err;
      if (f.reaction <= 0 && dist < g.kind.range * .95) {
        if (!tryFire(f) && g.loaded == 0 && f.ammo[g.kind.ammo]! == 0) _botSwap(f);
      }
      // لا تخرج من المنطقة أثناء القتال
      if (!inZone(f.pos + move * 80)) move = (zoneC - f.pos) / max(1, (zoneC - f.pos).distance);
    } else {
      if (f.hp < 55 && f.healing == null) {
        if (f.medkits > 0 && f.hp < 45) {
          heal(f, PickupKind.medkit);
        } else if (f.bandages > 0) {
          heal(f, PickupKind.bandage);
        }
      }
      final g = f.gun;
      if (g != null && g.loaded < g.kind.mag ~/ 2) reload(f);
      if (f.goal != null) {
        final v = f.goal! - f.pos;
        if (v.distance < 24) {
          f.goal = null;
        } else {
          move = v / v.distance;
          f.angle = move.direction;
        }
      }
    }
    if (move.distance > .01) {
      if (move.distance > 1) move = move / move.distance;
      _moveBy(f, move * speedOf(f) * .92 * dt);
    }
    _botPickup(f);
  }

  void _botThink(Fighter f) {
    // هدف مرئي
    Fighter? best;
    var bd = 720.0;
    for (final o in fighters) {
      if (!o.alive || o.id == f.id) continue;
      final d = (o.pos - f.pos).distance;
      if (d >= bd) continue;
      if (hiddenInBush(o) && d > 170) continue;
      if (!clearLine(f.pos, o.pos)) continue;
      bd = d;
      best = o;
    }
    if (best != null && best.id != f.targetId) {
      f.reaction = difficulty.reaction * (.6 + rng.nextDouble() * .8);
    }
    f.targetId = best?.id;
    if (best != null) return;

    // خارج المنطقة أو قرب التضييق → ادخل المنطقة القادمة
    final safeC = shrinking || zoneTimeLeft < 15 ? nextC : zoneC;
    final safeR = shrinking || zoneTimeLeft < 15 ? nextR : zoneR;
    if ((f.pos - safeC).distance > safeR * .9 + 10) {
      final a = rng.nextDouble() * pi * 2;
      f.goal = safeC + Offset(cos(a), sin(a)) * safeR * .5 * rng.nextDouble();
      return;
    }
    // غنائم مفيدة قريبة
    Pickup? want;
    var wd = 650.0;
    for (final p in pickups) {
      final d = (p.pos - f.pos).distance;
      if (d >= wd || !_botWants(f, p)) continue;
      wd = d;
      want = p;
    }
    if (want != null) {
      f.goal = want.pos;
      return;
    }
    if (f.goal == null) {
      final a = rng.nextDouble() * pi * 2;
      f.goal = safeC + Offset(cos(a), sin(a)) * safeR * .7 * rng.nextDouble();
    }
  }

  bool _botWants(Fighter f, Pickup p) => switch (p.kind) {
        PickupKind.weapon => f.slots.contains(null)
            ? !f.slots.any((g) => g?.kind == p.weapon)
            : f.slots.any((g) => g!.kind.tier < p.weapon!.tier),
        PickupKind.ammo => f.slots.any((g) => g?.kind.ammo == p.ammo) && f.ammo[p.ammo!]! < 90,
        PickupKind.bandage => f.bandages < 5,
        PickupKind.medkit => f.medkits < 2,
        PickupKind.armor => f.armor < p.amount,
      };

  void _botPickup(Fighter f) {
    for (final p in [...pickups]) {
      if (p.taken || p.kind != PickupKind.weapon || (p.pos - f.pos).distance > pickRange) continue;
      if (f.slots.any((g) => g?.kind == p.weapon)) continue;
      if (f.slots.contains(null)) {
        takeWeapon(f, p);
        return;
      }
      final worst = f.slots[0]!.kind.tier <= f.slots[1]!.kind.tier ? 0 : 1;
      if (f.slots[worst]!.kind.tier < p.weapon!.tier) {
        f.active = worst;
        takeWeapon(f, p);
        return;
      }
    }
    _autoPickup(f);
  }

  void _botSwap(Fighter f) {
    final other = 1 - f.active;
    final g = f.slots[other];
    if (g != null && (g.loaded > 0 || f.ammo[g.kind.ammo]! > 0)) switchTo(f, other);
  }

  /// نقاط المباراة للوحة المتصدرين.
  int get playerPoints {
    final me = player;
    final placeBonus = max(0, (botCount + 2 - me.place)) * 20;
    return me.kills * 100 + placeBonus + (me.place == 1 ? 500 : 0);
  }

  /// عملات المكافأة (فوق مكافأة المباراة العادية).
  int get playerCoins {
    final me = player;
    return me.kills * 15 + (me.place == 1 ? 200 : me.place <= 5 ? 60 : 0);
  }
}
