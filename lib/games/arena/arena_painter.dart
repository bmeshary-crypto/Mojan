import 'dart:math';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'arena_engine.dart';

/// ألوان ملابس المقاتلين (0 = لون اللاعب الافتراضي).
const arenaSkins = [
  Color(0xFFFFC23D),
  Color(0xFFFF5A5F),
  Color(0xFF3DB8FF),
  Color(0xFF2EE59D),
  Color(0xFFB57BFF),
  Color(0xFFFF8C3B),
  Color(0xFFE8E8F0),
  Color(0xFF2B2B3A),
];

const _ground = Color(0xFF79AE58);
const _sea = Color(0xFF2A7FB8);
const _sand = Color(0xFFE2CB8E);
const _road = Color(0xFFCDB37C);

Color tierColor(WeaponKind k) => switch (k.tier) {
      1 => const Color(0xFFDADADA),
      2 => const Color(0xFF5CC8FF),
      3 => const Color(0xFFB57BFF),
      _ => const Color(0xFFFFC23D),
    };

Color ammoColor(AmmoType a) => switch (a) {
      AmmoType.light => const Color(0xFFFFD45C),
      AmmoType.heavy => const Color(0xFF6BE38F),
      AmmoType.shells => const Color(0xFFFF6B6B),
      AmmoType.long => const Color(0xFF5CC8FF),
    };

/// زخارف ثابتة للأرض تُحسب مرة واحدة لكل خريطة.
class ArenaDecor {
  ArenaDecor(ArenaGame g) {
    final r = Random(g.seed * 31 + 5);
    for (var i = 0; i < 160; i++) {
      patches.add((
        Offset(r.nextDouble() * ArenaGame.size, r.nextDouble() * ArenaGame.size),
        60 + r.nextDouble() * 160,
        r.nextBool() ? const Color(0xFF86BA62) : const Color(0xFF6C9F4D),
      ));
    }
    for (var i = 0; i < 400; i++) {
      tufts.add(Offset(r.nextDouble() * ArenaGame.size, r.nextDouble() * ArenaGame.size));
    }
    // طرق تصل المدن ببعض
    final t = [...g.towns]..sort((a, b) => a.center.dx.compareTo(b.center.dx));
    for (var i = 0; i + 1 < t.length; i++) {
      roads.add((t[i].center, t[i + 1].center));
    }
    if (t.length > 3) roads.add((t.first.center, t[t.length ~/ 2].center));
  }
  final patches = <(Offset, double, Color)>[];
  final tufts = <Offset>[];
  final roads = <(Offset, Offset)>[];
}

/// رسومات Gemini للعبة (تُحمّل مرة واحدة). إذا لم تتوفر يُرسم بالكود.
class ArenaSprites {
  ArenaSprites._();
  static final instance = ArenaSprites._();
  final images = <String, ui.Image>{};
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final names = [
      for (var i = 0; i < 8; i++) 'ar_fighter_$i',
      for (var i = 0; i < 5; i++) 'ar_gun_$i',
      for (final n in ['tree', 'palm', 'bush', 'rock', 'crate', 'barrel', 'tex_grass', 'tex_sand', 'tex_wood']) 'ar_$n',
      for (final n in ['ammo_light', 'ammo_heavy', 'ammo_shells', 'ammo_long', 'bandage', 'medkit', 'armor', 'armor_gold']) 'ar_$n',
    ];
    await Future.wait(names.map((n) async {
      try {
        final data = await rootBundle.load('assets/images/$n.webp');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        images[n] = (await codec.getNextFrame()).image;
      } catch (_) {}
    }));
  }

  ui.Image? operator [](String n) => images[n];
}

/// يرسم صورة [img] داخل [dst] مع الحفاظ على الشكل.
void drawSprite(Canvas canvas, ui.Image img, Rect dst, {Paint? paint}) {
  canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst,
      paint ?? (Paint()..filterQuality = FilterQuality.medium));
}

/// مقاس السلاح في يد المقاتل (بوحدات العالم).
double gunLen(WeaponKind k) => switch (k) {
      WeaponKind.pistol => 22,
      WeaponKind.smg => 32,
      WeaponKind.rifle => 42,
      WeaponKind.shotgun => 40,
      WeaponKind.sniper => 52,
    };

class ArenaPainter extends CustomPainter {
  ArenaPainter(this.g, this.decor, {required this.scale, required Listenable repaint, this.cam, this.aim})
      : super(repaint: repaint);

  /// مركز الكاميرا (يتبع اللاعب بنعومة مع اهتزاز). إذا null فهو اللاعب.
  final Offset? Function()? cam;

  /// اتجاه تصويب اللاعب الحالي (لخط التصويب).
  final Offset? Function()? aim;
  static final sprites = ArenaSprites.instance;
  static final _texPaints = <String, Paint>{};

  /// طلاء بنقش متكرر من صورة أرضية.
  static Paint? _tex(String name, double tile) {
    final img = sprites[name];
    if (img == null) return null;
    return _texPaints.putIfAbsent(name, () {
      final k = tile / img.width;
      return Paint()
        ..filterQuality = FilterQuality.medium
        ..shader = ImageShader(img, TileMode.repeated, TileMode.repeated, Matrix4.diagonal3Values(k, k, 1).storage);
    });
  }

  static ui.Image? _prop(ObstacleKind k) => switch (k) {
        ObstacleKind.rock => sprites['ar_rock'],
        ObstacleKind.crate => sprites['ar_crate'],
        ObstacleKind.barrel => sprites['ar_barrel'],
        _ => null,
      };
  final ArenaGame g;
  final ArenaDecor decor;
  final double scale;

  static final _labels = <String, TextPainter>{};
  static TextPainter label(String s, {double size = 12, Color color = Colors.white, FontWeight w = FontWeight.w800}) =>
      _labels.putIfAbsent('$s|$size|${color.toARGB32()}', () {
        return TextPainter(
          text: TextSpan(
            text: s,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: size,
              color: color,
              fontWeight: w,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
      });

  @override
  void paint(Canvas canvas, Size size) {
    final me = g.player;
    final cam = this.cam?.call() ?? me.pos;
    final half = Offset(size.width / 2, size.height / 2) / scale;
    final view = Rect.fromCenter(center: cam, width: half.dx * 2, height: half.dy * 2).inflate(80);
    bool vis(Offset p, double r) => view.inflate(r).contains(p);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-cam.dx, -cam.dy);

    // البحر والشاطئ والأرض
    canvas.drawRect(view.inflate(200), Paint()..color = _sea);
    const s = ArenaGame.size;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-60, -60, s + 120, s + 120), const Radius.circular(180)),
        _tex('ar_tex_sand', 220) ?? (Paint()..color = _sand));
    final grass = _tex('ar_tex_grass', 260);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, s, s), const Radius.circular(140)),
        grass ?? (Paint()..color = _ground));
    for (final (c, r, col) in decor.patches) {
      if (vis(c, r)) canvas.drawCircle(c, r, Paint()..color = col.withValues(alpha: grass == null ? .55 : .22));
    }
    final roadPaint = Paint()
      ..color = _road
      ..strokeWidth = 64
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in decor.roads) {
      canvas.drawLine(a, b, roadPaint);
    }
    final tuft = Paint()
      ..color = const Color(0xFF5E9440)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final t in decor.tufts) {
      if (grass != null || !vis(t, 10)) continue;
      canvas.drawLine(t, t + const Offset(-4, -9), tuft);
      canvas.drawLine(t, t + const Offset(4, -8), tuft);
    }

    // أرضيات المباني
    for (final b in g.buildings) {
      if (!view.overlaps(b.floor)) continue;
      canvas.drawRect(b.floor.shift(const Offset(6, 8)), Paint()..color = Colors.black.withValues(alpha: .18));
      final wood = _tex('ar_tex_wood', 160);
      canvas.drawRect(b.floor, wood ?? (Paint()..color = const Color(0xFFC4A57A)));
      if (wood != null) continue;
      final tile = Paint()
        ..color = const Color(0xFFB0916A)
        ..strokeWidth = 1.5;
      for (var x = b.floor.left + 40; x < b.floor.right; x += 40) {
        canvas.drawLine(Offset(x, b.floor.top), Offset(x, b.floor.bottom), tile);
      }
      for (var y = b.floor.top + 40; y < b.floor.bottom; y += 40) {
        canvas.drawLine(Offset(b.floor.left, y), Offset(b.floor.right, y), tile);
      }
    }

    // آثار على الأرض: بقع، جثث، خراطيش، غبار
    for (final e in g.fx) {
      if (!vis(e.pos, 60)) continue;
      _fxGround(canvas, e);
    }

    // خط التصويب
    final aimDir = aim?.call();
    if (aimDir != null && me.alive && me.gun != null) {
      final d = aimDir / aimDir.distance;
      final len = min(me.gun!.kind.range, 600.0);
      final start = me.pos + d * 50;
      final paint = Paint()
        ..strokeWidth = 3
        ..shader = LinearGradient(colors: [Colors.white.withValues(alpha: .55), Colors.white.withValues(alpha: 0)])
            .createShader(Rect.fromPoints(start, start + d * len));
      for (var x = 0.0; x < len; x += 26) {
        canvas.drawLine(start + d * x, start + d * min(x + 14, len), paint);
      }
    }

    // الغنائم
    final t = g.time;
    for (final p in g.pickups) {
      if (vis(p.pos, 30)) _pickup(canvas, p, t);
    }

    // الصخور والجدران
    for (final o in g.obstacles) {
      if (o.kind == ObstacleKind.tree || !vis(o.c, o.r)) continue;
      if (o.isBox) {
        canvas.drawRect(o.rect!.shift(const Offset(3, 4)), Paint()..color = Colors.black26);
        canvas.drawRect(o.rect!, Paint()..color = const Color(0xFF5B4636));
        canvas.drawRect(o.rect!.deflate(3), Paint()..color = const Color(0xFF7A604B));
      } else if (_prop(o.kind) case final img?) {
        canvas.drawCircle(o.c + const Offset(5, 7), o.r, Paint()..color = Colors.black26);
        drawSprite(canvas, img, Rect.fromCircle(center: o.c, radius: o.r * 1.15));
      } else {
        canvas.drawCircle(o.c + const Offset(4, 6), o.r, Paint()..color = Colors.black26);
        canvas.drawCircle(o.c, o.r, Paint()..color = const Color(0xFF8C8F99));
        canvas.drawCircle(o.c + Offset(-o.r * .25, -o.r * .25), o.r * .6, Paint()..color = const Color(0xFFA9ACB5));
      }
    }

    // الرصاص
    final trail = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final b in g.bullets) {
      if (!vis(b.pos, 40)) continue;
      final dir = b.vel / b.vel.distance;
      final tl = b.kind == WeaponKind.sniper ? 70.0 : 34.0;
      final sh = Rect.fromPoints(b.pos - dir * tl, b.pos);
      trail
        ..strokeWidth = 7
        ..shader = LinearGradient(colors: [const Color(0x00FFB040), const Color(0x66FFB040)]).createShader(sh);
      canvas.drawLine(b.pos - dir * tl, b.pos, trail);
      trail
        ..strokeWidth = 2.5
        ..shader = LinearGradient(colors: [const Color(0x00FFE08A), const Color(0xFFFFFBE8)]).createShader(sh);
      canvas.drawLine(b.pos - dir * tl, b.pos, trail);
    }

    // المقاتلون
    for (final f in g.fighters) {
      if (!f.alive || !vis(f.pos, 40)) continue;
      final hidden = g.hiddenInBush(f);
      if (hidden && !f.isPlayer && (f.pos - me.pos).distance > 170) continue;
      _fighter(canvas, f, hidden);
    }

    // الشجيرات والأشجار فوق المقاتلين
    for (final b in g.bushes) {
      if (!vis(b.c, b.r)) continue;
      final inside = (b.c - me.pos).distance < b.r;
      final a = inside ? .45 : .95;
      final bi = sprites['ar_bush'];
      if (bi != null) {
        drawSprite(canvas, bi, Rect.fromCircle(center: b.c, radius: b.r * 1.1),
            paint: Paint()
              ..filterQuality = FilterQuality.medium
              ..color = Colors.white.withValues(alpha: a));
        continue;
      }
      canvas.drawCircle(b.c, b.r, Paint()..color = const Color(0xFF4E8A36).withValues(alpha: a));
      for (var k = 0; k < 5; k++) {
        final ang = k * 1.26 + b.c.dx;
        canvas.drawCircle(b.c + Offset(cos(ang), sin(ang)) * b.r * .55, b.r * .42,
            Paint()..color = const Color(0xFF5FA043).withValues(alpha: a));
      }
    }
    for (final o in g.obstacles) {
      if (o.kind != ObstacleKind.tree || !vis(o.c, o.r * 1.6)) continue;
      final near = (o.c - me.pos).distance < o.r * 1.6;
      final a = near ? .5 : 1.0;
      canvas.drawCircle(o.c + const Offset(8, 10), o.r * 1.5, Paint()..color = Colors.black.withValues(alpha: .18 * a));
      final ti = sprites[(o.c.dx + o.c.dy).round() % 3 == 0 ? 'ar_palm' : 'ar_tree'];
      if (ti != null) {
        drawSprite(canvas, ti, Rect.fromCircle(center: o.c, radius: o.r * 1.65),
            paint: Paint()
              ..filterQuality = FilterQuality.medium
              ..color = Colors.white.withValues(alpha: a));
        continue;
      }
      canvas.drawCircle(o.c, o.r * 1.5, Paint()..color = const Color(0xFF2F6B2A).withValues(alpha: a));
      canvas.drawCircle(o.c + Offset(-o.r * .3, -o.r * .35), o.r * 1.0, Paint()..color = const Color(0xFF3F8A37).withValues(alpha: a));
      canvas.drawCircle(o.c + Offset(-o.r * .45, -o.r * .5), o.r * .45, Paint()..color = const Color(0xFF58A84B).withValues(alpha: a));
    }

    // آثار في الهواء
    for (final e in g.fx) {
      if (!vis(e.pos, 160)) continue;
      _fxAir(canvas, e);
    }

    // العاصفة (خارج المنطقة): لون متدرج وحافة متحركة
    final t2 = g.time;
    final storm = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(view.inflate(300))
      ..addOval(Rect.fromCircle(center: g.zoneC, radius: g.zoneR));
    canvas.drawPath(
        storm,
        Paint()
          ..shader = RadialGradient(
            colors: const [Color(0x006A3BFF), Color(0x666A3BFF), Color(0x887A2BFF)],
            stops: const [.0, .5, 1],
          ).createShader(Rect.fromCircle(center: g.zoneC, radius: g.zoneR + 500)));
    if (view.inflate(60).overlaps(Rect.fromCircle(center: g.zoneC, radius: g.zoneR + 40))) {
      canvas.drawCircle(
          g.zoneC,
          g.zoneR + 10,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 40
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
            ..color = const Color(0xFF9B6BFF).withValues(alpha: .5 + .15 * sin(t2 * 3)));
      // شرارات العاصفة تدور على الحافة
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE2D4FF);
      final circ = 2 * pi * max(g.zoneR, 1);
      final n = (circ / 90).clamp(8, 400).round();
      for (var i = 0; i < n; i++) {
        final a = i / n * 2 * pi + t2 * 40 / max(g.zoneR, 60);
        final pt = g.zoneC + Offset.fromDirection(a, g.zoneR);
        if (!view.contains(pt)) continue;
        canvas.drawArc(Rect.fromCircle(center: g.zoneC, radius: g.zoneR), a, 22 / max(g.zoneR, 1), false, arc);
        final wob = sin(t2 * 6 + i * 1.7);
        canvas.drawCircle(g.zoneC + Offset.fromDirection(a + .002 * i, g.zoneR + 18 + 10 * wob), 3 + 2 * wob.abs(),
            Paint()..color = const Color(0xFFCFB8FF).withValues(alpha: .7));
      }
    }
    if (g.phase < zonePhases.length) {
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white.withValues(alpha: .9);
      final r = max(g.nextR, 4.0);
      final n = max(12, (2 * pi * r / 60).round());
      for (var i = 0; i < n; i += 1) {
        final a = i / n * 2 * pi;
        if (!view.contains(g.nextC + Offset.fromDirection(a, r))) continue;
        canvas.drawArc(Rect.fromCircle(center: g.nextC, radius: r), a, pi / n, false, dash);
      }
    }
    canvas.restore();
  }

  void _pickup(Canvas canvas, Pickup p, double t) {
    final bob = sin(t * 3 + p.pos.dx) * 2;
    var c = p.pos + Offset(0, bob);
    final age = t - p.born;
    if (age < .5) {
      final k = (age / .45).clamp(0.0, 1.0);
      if (p.from != null) c = Offset.lerp(p.from!, p.pos, Curves.easeOut.transform(k))! - Offset(0, sin(k * pi) * 40);
      final sc = Curves.elasticOut.transform(min(1.0, age / .5)).clamp(.05, 1.4);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(sc);
      canvas.translate(-c.dx, -c.dy);
      _pickupAt(canvas, p, c);
      canvas.restore();
      return;
    }
    _pickupAt(canvas, p, c);
  }

  void _pickupAt(Canvas canvas, Pickup p, Offset c) {
    final glow = switch (p.kind) {
      PickupKind.weapon => tierColor(p.weapon!),
      PickupKind.ammo => ammoColor(p.ammo!),
      PickupKind.bandage => const Color(0xFFFFE4C2),
      PickupKind.medkit => const Color(0xFFFF6B6B),
      PickupKind.armor => const Color(0xFF5CC8FF),
    };
    canvas.drawCircle(c, 20, Paint()..color = glow.withValues(alpha: .28));
    canvas.drawCircle(
        c,
        20,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = glow.withValues(alpha: .8));
    final itemImg = switch (p.kind) {
      PickupKind.ammo => sprites['ar_ammo_${p.ammo!.name}'],
      PickupKind.bandage => sprites['ar_bandage'],
      PickupKind.medkit => sprites['ar_medkit'],
      PickupKind.armor => sprites[p.amount >= 100 ? 'ar_armor_gold' : 'ar_armor'] ?? sprites['ar_armor'],
      PickupKind.weapon => null,
    };
    if (itemImg != null) {
      const w = 30.0;
      final h = w * itemImg.height / itemImg.width;
      drawSprite(canvas, itemImg, Rect.fromCenter(center: c, width: w, height: h));
      return;
    }
    switch (p.kind) {
      case PickupKind.weapon:
        final img = sprites['ar_gun_${p.weapon!.index}'];
        if (img != null) {
          const w = 38.0;
          final h = w * img.height / img.width;
          drawSprite(canvas, img, Rect.fromCenter(center: c, width: w, height: h));
        } else {
          _gunShape(canvas, c - const Offset(14, 0), 0, p.weapon!, 1.0);
        }
      case PickupKind.ammo:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 22, height: 15), const Radius.circular(3)),
            Paint()..color = const Color(0xFF4A3B2A));
        for (var i = -1; i <= 1; i++) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(i * 6.0, -4), width: 4, height: 10), const Radius.circular(2)),
              Paint()..color = ammoColor(p.ammo!));
        }
      case PickupKind.bandage:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 22, height: 12), const Radius.circular(5)),
            Paint()..color = const Color(0xFFF3DFC1));
        canvas.drawRect(Rect.fromCenter(center: c, width: 6, height: 12), Paint()..color = const Color(0xFFD9B98F));
      case PickupKind.medkit:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 22, height: 18), const Radius.circular(4)),
            Paint()..color = Colors.white);
        canvas.drawRect(Rect.fromCenter(center: c, width: 12, height: 4), Paint()..color = const Color(0xFFE53935));
        canvas.drawRect(Rect.fromCenter(center: c, width: 4, height: 12), Paint()..color = const Color(0xFFE53935));
      case PickupKind.armor:
        final path = Path()
          ..moveTo(c.dx, c.dy - 11)
          ..lineTo(c.dx + 10, c.dy - 6)
          ..lineTo(c.dx + 8, c.dy + 5)
          ..lineTo(c.dx, c.dy + 11)
          ..lineTo(c.dx - 8, c.dy + 5)
          ..lineTo(c.dx - 10, c.dy - 6)
          ..close();
        canvas.drawPath(path, Paint()..color = p.amount >= 100 ? const Color(0xFFFFC23D) : const Color(0xFF3D8BFF));
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = Colors.white70);
    }
  }

  /// شكل السلاح من الأعلى: يبدأ من [from] باتجاه [angle].
  static void _gunShape(Canvas canvas, Offset from, double angle, WeaponKind k, double s) {
    final len = switch (k) {
      WeaponKind.pistol => 16.0,
      WeaponKind.smg => 24.0,
      WeaponKind.rifle => 32.0,
      WeaponKind.shotgun => 30.0,
      WeaponKind.sniper => 40.0,
    };
    final w = k == WeaponKind.shotgun ? 7.0 : 5.5;
    canvas.save();
    canvas.translate(from.dx, from.dy);
    canvas.rotate(angle);
    canvas.scale(s);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, -w / 2, len, w), const Radius.circular(2)),
        Paint()..color = const Color(0xFF2C2C34));
    canvas.drawRect(Rect.fromLTWH(len * .2, -w / 2, len * .35, w), Paint()..color = tierColor(k));
    if (k == WeaponKind.sniper) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(len * .35, -4.5, 12, 3.5), const Radius.circular(2)),
          Paint()..color = const Color(0xFF111111));
    }
    canvas.restore();
  }

  /// نقطة الرأس داخل صورة المقاتل (من 160) وطرف السلاح، والزاوية التي تجعل السلاح على خط التصويب.
  static const _spriteSize = 78.0;
  static const _pivot = Offset(64 / 160 * _spriteSize, 72 / 160 * _spriteSize);
  static const _hand = Offset(115 / 160 * _spriteSize, 107 / 160 * _spriteSize);
  static const _tilt = .353;

  void _fighter(Canvas canvas, Fighter f, bool hidden) {
    final img = sprites['ar_fighter_${f.skin % 8}'];
    if (img != null) return _fighterSprite(canvas, f, hidden, img);
    _fighterShape(canvas, f, hidden);
  }

  void _fighterSprite(Canvas canvas, Fighter f, bool hidden, ui.Image img) {
    final c = f.pos;
    const r = ArenaGame.fighterR;
    final alpha = hidden ? .55 : 1.0;
    // الهبوط بالمظلة في أول ثانيتين
    final fall = (1 - this.g.time / 2.2).clamp(0.0, 1.0);
    final lift = Curves.easeIn.transform(fall);
    canvas.drawCircle(c + Offset(4 + 30 * lift, 7 + 40 * lift), (r + 4) * (1 - .4 * lift),
        Paint()..color = Colors.black.withValues(alpha: .22 * (1 - .5 * lift)));
    if (f.armor > 0) {
      canvas.drawCircle(
          c,
          r + 6,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = (f.armor >= 100 ? const Color(0xFFFFC23D) : const Color(0xFF3D8BFF)).withValues(alpha: .7 * alpha));
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (lift > 0) canvas.scale(1 + .7 * lift);
    // تمايل المشي
    final step = sin(f.walkT);
    canvas.scale(1 + .035 * f.moveAmt * step.abs());
    canvas.rotate(f.angle - _tilt + .07 * f.moveAmt * step);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Colors.white.withValues(alpha: alpha);
    if (f.hurtFlash > 0) paint.colorFilter = const ColorFilter.mode(Color(0x99FFFFFF), BlendMode.srcATop);
    drawSprite(canvas, img, Rect.fromLTWH(-_pivot.dx, -_pivot.dy, _spriteSize, _spriteSize), paint: paint);
    final g = f.gun;
    final hand = _hand - _pivot;
    var tip = hand + const Offset(22, 0);
    if (g != null) {
      final len = gunLen(g.kind);
      tip = hand + Offset(len - 6, 0);
      if (g.kind != WeaponKind.pistol) {
        final gi = sprites['ar_gun_${g.kind.index}'];
        if (gi != null) {
          final h = len * gi.height / gi.width;
          drawSprite(canvas, gi, Rect.fromLTWH(hand.dx - 8, hand.dy - h * .45, len, h), paint: paint);
        }
      }
      if (f.muzzle > 0) {
        canvas.drawCircle(tip + const Offset(4, 0), 9, Paint()..color = const Color(0xFFFFE08A));
        canvas.drawCircle(tip + const Offset(4, 0), 5, Paint()..color = Colors.white);
      }
    }
    canvas.restore();
    if (lift > 0) _parachute(canvas, c, lift, f.skin);
    _overhead(canvas, f);
  }

  void _parachute(Canvas canvas, Offset c, double lift, int skin) {
    final top = c - Offset(0, 50 + 60 * lift);
    final w = 60 + 30 * lift;
    final col = arenaSkins[skin % arenaSkins.length];
    final lines = Paint()
      ..strokeWidth = 1.5
      ..color = Colors.black54;
    for (final x in [-w * .9, -w * .3, w * .3, w * .9]) {
      canvas.drawLine(top + Offset(x, 6), c, lines);
    }
    final rect = Rect.fromCenter(center: top, width: w * 2, height: w * 1.1);
    canvas.drawArc(rect, pi, pi, true, Paint()..color = col);
    for (var i = 0; i < 6; i += 2) {
      canvas.drawArc(rect, pi + i * pi / 6, pi / 6, true, Paint()..color = Colors.white.withValues(alpha: .85));
    }
    canvas.drawArc(
        rect,
        pi,
        pi,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black38);
  }

  void _fxGround(Canvas canvas, Fx e) {
    final k = e.age / e.life;
    switch (e.kind) {
      case 'splat':
        final a = (k < .7 ? .55 : .55 * (1 - (k - .7) / .3));
        final col = e.value > 2 ? const Color(0xFF2A2420) : const Color(0xFF9E1B1B);
        canvas.save();
        canvas.translate(e.pos.dx, e.pos.dy);
        canvas.rotate(e.rot);
        final r = 9 * e.value;
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.2, height: r * 1.5), Paint()..color = col.withValues(alpha: a));
        canvas.drawCircle(Offset(r * 1.2, r * .4), r * .35, Paint()..color = col.withValues(alpha: a));
        canvas.drawCircle(Offset(-r * .9, -r * .6), r * .25, Paint()..color = col.withValues(alpha: a));
        canvas.restore();
      case 'corpse':
        final img = sprites['ar_fighter_${e.value.round() % 8}'];
        final a = k < .8 ? .85 : .85 * (1 - (k - .8) / .2);
        if (img != null) {
          canvas.save();
          canvas.translate(e.pos.dx, e.pos.dy);
          canvas.rotate(e.rot - _tilt + .5);
          canvas.scale(1 - .1 * min(1, e.age * 3));
          drawSprite(canvas, img, Rect.fromLTWH(-_pivot.dx, -_pivot.dy, _spriteSize, _spriteSize),
              paint: Paint()
                ..filterQuality = FilterQuality.medium
                ..colorFilter = ColorFilter.mode(Colors.black.withValues(alpha: .45), BlendMode.srcATop)
                ..color = Colors.white.withValues(alpha: a));
          canvas.restore();
        }
      case 'shell':
        final a = k < .7 ? 1.0 : 1 - (k - .7) / .3;
        canvas.save();
        canvas.translate(e.pos.dx, e.pos.dy);
        canvas.rotate(e.rot);
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 7 * e.value, height: 3.2), const Radius.circular(1.5)),
            Paint()..color = (e.value > 1 ? const Color(0xFFE53935) : const Color(0xFFFFC94D)).withValues(alpha: a));
        canvas.restore();
      case 'dust':
        canvas.drawCircle(e.pos, 5 + 10 * k, Paint()..color = const Color(0xFFE8DDBF).withValues(alpha: .45 * (1 - k)));
    }
  }

  void _fxAir(Canvas canvas, Fx e) {
    final k = e.age / e.life;
    switch (e.kind) {
      case 'hit':
        canvas.drawCircle(e.pos, 3 + 8 * k, Paint()..color = const Color(0xFFFFE9A8).withValues(alpha: 1 - k));
      case 'blood':
        canvas.drawCircle(e.pos, 5 + 9 * k, Paint()..color = const Color(0xFFFF3D3D).withValues(alpha: .85 * (1 - k)));
      case 'spark':
        final dir = e.vel.distance > 0 ? e.vel / e.vel.distance : const Offset(1, 0);
        canvas.drawLine(
            e.pos,
            e.pos - dir * (6 + 10 * (1 - k)),
            Paint()
              ..strokeWidth = 2.2
              ..strokeCap = StrokeCap.round
              ..color = (e.value == 1 ? const Color(0xFFFF5A5A) : const Color(0xFFFFE08A)).withValues(alpha: 1 - k));
      case 'smoke':
        canvas.drawCircle(e.pos, (6 + 18 * k) * e.value, Paint()..color = const Color(0xFFDADADA).withValues(alpha: .35 * (1 - k)));
      case 'puff':
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4;
          canvas.drawCircle(e.pos + Offset(cos(a), sin(a)) * 34 * k, 13 * (1 - k) + 3,
              Paint()..color = Colors.white.withValues(alpha: .6 * (1 - k)));
        }
      case 'boom':
        final r = e.value * (.4 + .8 * Curves.easeOut.transform(k));
        canvas.drawCircle(
            e.pos,
            r,
            Paint()
              ..shader = RadialGradient(colors: [
                Colors.white.withValues(alpha: 1 - k),
                const Color(0xFFFFD25C).withValues(alpha: .9 * (1 - k)),
                const Color(0xFFFF5A1F).withValues(alpha: .7 * (1 - k)),
                const Color(0x00FF3D00),
              ], stops: const [0, .3, .65, 1]).createShader(Rect.fromCircle(center: e.pos, radius: r)));
      case 'ring':
        canvas.drawCircle(
            e.pos,
            e.value * Curves.easeOut.transform(k),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8 * (1 - k) + 1
              ..color = Colors.white.withValues(alpha: .7 * (1 - k)));
      case 'debris':
        canvas.save();
        canvas.translate(e.pos.dx, e.pos.dy);
        canvas.rotate(e.rot);
        canvas.drawRect(const Rect.fromLTWH(-5, -3, 10, 6), Paint()..color = const Color(0xFF8E2A1A).withValues(alpha: 1 - k * k));
        canvas.restore();
      case 'dmg':
        final big = e.value >= 40;
        final pop = k < .15 ? 1 + (1 - k / .15) * .6 : 1.0;
        final tp = label(e.value.round().toString(), size: big ? 20 : 15, color: big ? const Color(0xFFFF8A3D) : const Color(0xFFFFE066));
        canvas.save();
        canvas.translate(e.pos.dx, e.pos.dy);
        canvas.scale(pop);
        if (k > .7) canvas.scale(1 - (k - .7));
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
    }
  }

  void _overhead(Canvas canvas, Fighter f) {
    final c = f.pos;
    const r = ArenaGame.fighterR;
    if (f.healing != null) {
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r + 10),
          -pi / 2,
          2 * pi * (1 - f.healLeft / (f.healing == PickupKind.medkit ? 3.5 : 1.6)),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = const Color(0xFF6BE38F));
    }
    if (f.isPlayer) {
      // سهم صغير يميز اللاعب
      final p = Path()
        ..moveTo(c.dx, c.dy - r - 22)
        ..lineTo(c.dx - 7, c.dy - r - 32)
        ..lineTo(c.dx + 7, c.dy - r - 32)
        ..close();
      canvas.drawPath(p, Paint()..color = const Color(0xFFFFC23D));
      return;
    }
    final tp = label(f.name, size: 11);
    tp.paint(canvas, c + Offset(-tp.width / 2, -r - 34));
    final bar = Rect.fromLTWH(c.dx - 20, c.dy - r - 16, 40, 5);
    canvas.drawRect(bar, Paint()..color = Colors.black54);
    canvas.drawRect(Rect.fromLTWH(bar.left, bar.top, 40 * (f.hp / 100).clamp(0, 1), 5),
        Paint()..color = f.hp > 50 ? const Color(0xFF6BE38F) : f.hp > 25 ? const Color(0xFFFFC23D) : const Color(0xFFFF5A5F));
    if (f.armor > 0) {
      canvas.drawRect(Rect.fromLTWH(bar.left, bar.top - 3, 40 * (f.armor / 100).clamp(0, 1), 2.5),
          Paint()..color = const Color(0xFF5CC8FF));
    }
  }

  void _fighterShape(Canvas canvas, Fighter f, bool hidden) {
    final c = f.pos;
    const r = ArenaGame.fighterR;
    final skin = arenaSkins[f.skin % arenaSkins.length];
    final alpha = hidden ? .55 : 1.0;
    canvas.drawCircle(c + const Offset(3, 6), r, Paint()..color = Colors.black.withValues(alpha: .25));
    final dir = Offset(cos(f.angle), sin(f.angle));
    final side = Offset(-dir.dy, dir.dx);
    // السلاح واليدان
    final g = f.gun;
    if (g != null) _gunShape(canvas, c + dir * (r - 4), f.angle, g.kind, 1);
    canvas.drawCircle(c + dir * (r + 2) + side * 6, 5.5, Paint()..color = const Color(0xFFE9B98C).withValues(alpha: alpha));
    canvas.drawCircle(c + dir * (r - 4) - side * 9, 5.5, Paint()..color = const Color(0xFFE9B98C).withValues(alpha: alpha));
    // الجسم
    final body = f.hurtFlash > 0 ? Colors.white : skin;
    canvas.drawCircle(c, r, Paint()..color = body.withValues(alpha: alpha));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Color.lerp(skin, Colors.black, .45)!.withValues(alpha: alpha));
    if (f.armor > 0) {
      canvas.drawCircle(
          c,
          r - 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFF3D8BFF).withValues(alpha: .8 * alpha));
    }
    // الرأس
    canvas.drawCircle(c + dir * 2, r * .52, Paint()..color = const Color(0xFFE9B98C).withValues(alpha: alpha));
    canvas.drawCircle(c - dir * 2, r * .5, Paint()..color = const Color(0xFF3B2A20).withValues(alpha: alpha));
    if (f.muzzle > 0 && g != null) {
      final len = switch (g.kind) {
        WeaponKind.pistol => 16.0,
        WeaponKind.smg => 24.0,
        WeaponKind.rifle => 32.0,
        WeaponKind.shotgun => 30.0,
        WeaponKind.sniper => 40.0,
      };
      final tip = c + dir * (r - 4 + len + 6);
      canvas.drawCircle(tip, 9, Paint()..color = const Color(0xFFFFE08A));
      canvas.drawCircle(tip, 5, Paint()..color = Colors.white);
    }
    if (f.healing != null) {
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r + 7),
          -pi / 2,
          2 * pi * (1 - f.healLeft / (f.healing == PickupKind.medkit ? 3.5 : 1.6)),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFF6BE38F));
    }
    // الاسم وشريط الصحة
    if (!f.isPlayer) {
      final tp = label(f.name, size: 11);
      tp.paint(canvas, c + Offset(-tp.width / 2, -r - 30));
      final bar = Rect.fromLTWH(c.dx - 20, c.dy - r - 12, 40, 5);
      canvas.drawRect(bar, Paint()..color = Colors.black54);
      canvas.drawRect(Rect.fromLTWH(bar.left, bar.top, 40 * (f.hp / 100).clamp(0, 1), 5),
          Paint()..color = f.hp > 50 ? const Color(0xFF6BE38F) : f.hp > 25 ? const Color(0xFFFFC23D) : const Color(0xFFFF5A5F));
      if (f.armor > 0) {
        canvas.drawRect(Rect.fromLTWH(bar.left, bar.top - 3, 40 * (f.armor / 100).clamp(0, 1), 2.5),
            Paint()..color = const Color(0xFF5CC8FF));
      }
    }
  }

  @override
  bool shouldRepaint(covariant ArenaPainter old) => old.scale != scale || old.g != g;
}

/// الخريطة المصغرة / خريطة القفز.
class ArenaMapPainter extends CustomPainter {
  ArenaMapPainter(this.g, this.decor, {this.showPlayer = true, this.landing, this.names = false, this.plane, super.repaint});
  final ArenaGame g;
  final ArenaDecor decor;
  final bool showPlayer;
  final Offset? landing;
  final bool names;

  /// تقدم الطائرة (0..1) فوق الخريطة.
  final double? plane;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / ArenaGame.size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * .08)));
    canvas.drawRect(Offset.zero & size, Paint()..color = _sea);
    canvas.scale(k);
    const s = ArenaGame.size;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-40, -40, s + 80, s + 80), const Radius.circular(180)),
        Paint()..color = _sand);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, s, s), const Radius.circular(140)),
        Paint()..color = _ground);
    final roadPaint = Paint()
      ..color = _road
      ..strokeWidth = 64
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in decor.roads) {
      canvas.drawLine(a, b, roadPaint);
    }
    for (final b in g.buildings) {
      canvas.drawRect(b.floor, Paint()..color = const Color(0xFF8E7354));
    }
    for (final o in g.obstacles) {
      if (o.kind == ObstacleKind.tree) canvas.drawCircle(o.c, o.r * 1.4, Paint()..color = const Color(0xFF3F8A37));
    }
    if (g.started) {
      final storm = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(const Rect.fromLTWH(-200, -200, s + 400, s + 400))
        ..addOval(Rect.fromCircle(center: g.zoneC, radius: g.zoneR));
      canvas.drawPath(storm, Paint()..color = const Color(0xFF6A3BFF).withValues(alpha: .4));
      if (g.phase < zonePhases.length) {
        canvas.drawCircle(
            g.nextC,
            max(g.nextR, 20),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 18
              ..color = Colors.white);
      }
    }
    if (plane != null) {
      const a = Offset(-100, s * .2), b = Offset(s + 100, s * .85);
      canvas.drawLine(
          a,
          b,
          Paint()
            ..strokeWidth = 16
            ..color = Colors.white.withValues(alpha: .5));
      final p = Offset.lerp(a, b, plane!)!;
      final ang = (b - a).direction;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(ang);
      final body = Paint()..color = Colors.white;
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-110, -22, 220, 44), const Radius.circular(22)), body);
      canvas.drawPath(Path()..moveTo(10, 0)..lineTo(-40, -120)..lineTo(-70, -120)..lineTo(-40, 0)..close(), body);
      canvas.drawPath(Path()..moveTo(10, 0)..lineTo(-40, 120)..lineTo(-70, 120)..lineTo(-40, 0)..close(), body);
      canvas.drawPath(Path()..moveTo(-90, 0)..lineTo(-120, -50)..lineTo(-135, -50)..lineTo(-115, 0)..close(), body);
      canvas.drawPath(Path()..moveTo(-90, 0)..lineTo(-120, 50)..lineTo(-135, 50)..lineTo(-115, 0)..close(), body);
      canvas.restore();
    }
    if (landing != null) {
      canvas.drawCircle(landing!, 70, Paint()..color = AppColorsGold.c.withValues(alpha: .35));
      canvas.drawCircle(landing!, 34, Paint()..color = AppColorsGold.c);
    }
    if (showPlayer && g.started) {
      final me = g.player;
      canvas.save();
      canvas.translate(me.pos.dx, me.pos.dy);
      canvas.rotate(me.angle);
      canvas.drawPath(
          Path()
            ..moveTo(80, 0)
            ..lineTo(-50, -50)
            ..lineTo(-25, 0)
            ..lineTo(-50, 50)
            ..close(),
          Paint()..color = AppColorsGold.c);
      canvas.restore();
    }
    canvas.restore();
    if (names) {
      for (final t in g.towns) {
        final tp = ArenaPainter.label(t.name, size: 13);
        tp.paint(canvas, t.center * k - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant ArenaMapPainter old) => true;
}

class AppColorsGold {
  static const c = Color(0xFFFFC23D);
}
