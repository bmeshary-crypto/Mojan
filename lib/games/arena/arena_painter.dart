import 'dart:math';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'arena_camera.dart';
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
  ArenaPainter(this.g, this.decor, {required this.scale, required Listenable repaint, this.cam, this.aim, this.camera})
      : super(repaint: repaint);

  /// مركز الكاميرا (يتبع اللاعب بنعومة مع اهتزاز). إذا null فهو اللاعب.
  final Offset? Function()? cam;

  /// اتجاه تصويب اللاعب الحالي (لخط التصويب).
  final Offset? Function()? aim;

  /// الكاميرا المائلة (تحدّثها الشاشة كل إطار).
  final ArenaCamera? camera;
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

  /// اتجاه الظل لكل وحدة ارتفاع (الشمس من أعلى اليسار).
  static const _sun = Offset(.42, .22);

  /// ارتفاع صدر المقاتل (حيث يُرسم وتطير الطلقات).
  static const fighterH = 26.0;
  static const _wallH = 62.0;

  static double _treeH(Obstacle o) => _isPalm(o) ? 150 : 118;
  static bool _isPalm(Obstacle o) => (o.c.dx + o.c.dy).round() % 3 == 0;

  void _onPlane(Canvas canvas, ArenaCamera cv, double h, void Function() draw) {
    canvas.save();
    canvas.transform(cv.plane(h));
    draw();
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final me = g.player;
    final cv = camera ?? (ArenaCamera()..update(size, cam?.call() ?? me.pos, scale));
    final view = cv.groundView().inflate(80);
    bool vis(Offset p, double r) => view.inflate(r).contains(p);
    final t = g.time;

    // ── الأرض ──
    canvas.save();
    canvas.transform(cv.plane());
    canvas.drawRect(view.inflate(300), Paint()..color = _sea);
    _drawSea(canvas, view, t);
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
    for (final tp in decor.tufts) {
      if (grass != null || !vis(tp, 10)) continue;
      canvas.drawLine(tp, tp + const Offset(-4, -9), tuft);
      canvas.drawLine(tp, tp + const Offset(4, -8), tuft);
    }

    // أرضيات المباني مع ظل داخلي عند الجدران
    for (final b in g.buildings) {
      if (!view.overlaps(b.floor)) continue;
      final wood = _tex('ar_tex_wood', 160);
      canvas.drawRect(b.floor, wood ?? (Paint()..color = const Color(0xFFC4A57A)));
      canvas.drawRect(
          b.floor.deflate(6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
            ..color = Colors.black.withValues(alpha: .28));
    }

    // آثار على الأرض: بقع، جثث، خراطيش، غبار
    for (final e in g.fx) {
      if (!vis(e.pos, 60)) continue;
      _fxGround(canvas, e);
    }

    // ظلال كل شيء عالٍ
    _shadows(canvas, vis);

    // ضوء الطلقات والانفجارات على الأرض
    _lights(canvas, vis);

    // خط التصويب
    final aimDir = aim?.call();
    if (aimDir != null && aimDir.distance > 0 && me.alive && me.gun != null) {
      final d = aimDir / aimDir.distance;
      final len = min(me.gun!.kind.range, 600.0);
      final start = me.pos + d * 50;
      final paint = Paint()
        ..strokeWidth = 3
        ..shader = LinearGradient(colors: [Colors.white.withValues(alpha: .6), Colors.white.withValues(alpha: 0)])
            .createShader(Rect.fromPoints(start, start + d * len));
      for (var x = 0.0; x < len; x += 26) {
        canvas.drawLine(start + d * x, start + d * min(x + 14, len), paint);
      }
    }

    // العاصفة على الأرض
    final storm = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(view.inflate(300))
      ..addOval(Rect.fromCircle(center: g.zoneC, radius: g.zoneR));
    canvas.drawPath(
        storm,
        Paint()
          ..shader = RadialGradient(
            colors: const [Color(0x006A3BFF), Color(0x666A3BFF), Color(0x997A2BFF)],
            stops: const [.0, .5, 1],
          ).createShader(Rect.fromCircle(center: g.zoneC, radius: g.zoneR + 500)));
    if (g.phase < zonePhases.length) {
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
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

    // ── الأشياء القائمة، مرتبة من البعيد للقريب ──
    final items = <(double, void Function())>[];
    for (final p in g.pickups) {
      if (!vis(p.pos, 30)) continue;
      final bob = 8 + 4 * sin(t * 3 + p.pos.dx);
      items.add((p.pos.dy, () => _onPlane(canvas, cv, bob, () => _pickup(canvas, p, t))));
    }
    for (final o in g.obstacles) {
      if (o.kind == ObstacleKind.tree) {
        if (!vis(o.c, o.r * 2 + 120)) continue;
        items.add((o.c.dy + 4, () => _tree(canvas, cv, o, t)));
      } else if (o.isBox) {
        if (!view.inflate(80).overlaps(o.rect!)) continue;
        _wallItems(canvas, cv, o, items);
      } else if (vis(o.c, o.r)) {
        items.add((o.c.dy, () => _stacked(canvas, cv, o)));
      }
    }
    for (final f in g.fighters) {
      if (!f.alive || !vis(f.pos, 40)) continue;
      final hidden = g.hiddenInBush(f);
      if (hidden && !f.isPlayer && (f.pos - me.pos).distance > 170) continue;
      items.add((f.pos.dy + 1, () => _fighter(canvas, cv, f, hidden)));
    }
    for (final b in g.bushes) {
      if (!vis(b.c, b.r)) continue;
      items.add((b.c.dy + 2, () => _bush(canvas, cv, b)));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final it in items) {
      it.$2();
    }

    // ── في الهواء: الرصاص والدخان والشرر ──
    canvas.save();
    canvas.transform(cv.plane(fighterH));
    final trail = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final b in g.bullets) {
      if (!vis(b.pos, 40)) continue;
      final dir = b.vel / b.vel.distance;
      final tl = b.kind == WeaponKind.sniper ? 80.0 : 38.0;
      final sh = Rect.fromPoints(b.pos - dir * tl, b.pos);
      trail
        ..strokeWidth = 8
        ..shader = LinearGradient(colors: [const Color(0x00FFB040), const Color(0x77FFB040)]).createShader(sh);
      canvas.drawLine(b.pos - dir * tl, b.pos, trail);
      trail
        ..strokeWidth = 2.8
        ..shader = LinearGradient(colors: [const Color(0x00FFE08A), const Color(0xFFFFFBE8)]).createShader(sh);
      canvas.drawLine(b.pos - dir * tl, b.pos, trail);
    }
    for (final e in g.fx) {
      if (e.kind == 'dmg' || !vis(e.pos, 160)) continue;
      _fxAir(canvas, e);
    }
    canvas.restore();

    // ستارة العاصفة الشاهقة
    _stormWall(canvas, cv, view, t);

    // أرقام الضرر والأسماء دائماً مقروءة (مواجهة للكاميرا)
    for (final e in g.fx) {
      if (e.kind != 'dmg' || !vis(e.pos, 60)) continue;
      final k = e.age / e.life;
      _fxAir(canvas, e, at: cv.project(e.pos, 50 + 40 * k));
    }
    for (final f in g.fighters) {
      if (!f.alive || !vis(f.pos, 40)) continue;
      if (g.hiddenInBush(f) && !f.isPlayer && (f.pos - me.pos).distance > 170) continue;
      final lift = _lift(f);
      _overhead(canvas, f, cv.project(f.pos, fighterH + 300 * lift + 30), cv.depthScale(f.pos, fighterH).clamp(.6, 1.3));
    }

    // ضباب خفيف في البعيد يعطي عمقاً
    canvas.drawRect(
        Offset.zero & Size(size.width, size.height * .4),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x55D8ECFF), Color(0x00D8ECFF)],
          ).createShader(Offset.zero & Size(size.width, size.height * .4)));
  }

  double _lift(Fighter f) => Curves.easeIn.transform((1 - g.time / 2.2).clamp(0.0, 1.0));

  void _drawSea(Canvas canvas, Rect view, double t) {
    const s = ArenaGame.size;
    // موج يتكسر على الشاطئ
    for (var i = 0; i < 3; i++) {
      final ph = (t * .35 + i / 3) % 1;
      canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-60, -60, s + 120, s + 120).inflate(8 + 70 * ph), Radius.circular(180 + 70 * ph)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10 * (1 - ph) + 2
            ..color = Colors.white.withValues(alpha: .45 * (1 - ph)));
    }
    // لمعان الماء
    final sp = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const step = 90.0;
    for (var x = (view.left / step).floor() * step; x < view.right; x += step) {
      for (var y = (view.top / step).floor() * step; y < view.bottom; y += step) {
        if (x > -100 && x < s + 100 && y > -100 && y < s + 100) continue;
        final hsh = ((x * 73856093).toInt() ^ (y * 19349663).toInt()) & 1023;
        final ph = sin(t * 2 + hsh);
        if (ph < .3) continue;
        final p = Offset(x + (hsh % 60), y + (hsh % 37) + 6 * sin(t + hsh));
        sp.color = Colors.white.withValues(alpha: .5 * (ph - .3));
        canvas.drawLine(p, p + const Offset(18, 0), sp);
      }
    }
  }

  void _shadows(Canvas canvas, bool Function(Offset, double) vis) {
    final sh = Paint()
      ..color = Colors.black.withValues(alpha: .24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (final o in g.obstacles) {
      if (o.isBox) {
        if (!vis(o.c, o.r + 60)) continue;
        final r = o.rect!;
        final d = _sun * _wallH;
        final path = Path()
          ..moveTo(r.left, r.top)
          ..lineTo(r.left + d.dx, r.top + d.dy)
          ..lineTo(r.right + d.dx, r.top + d.dy)
          ..lineTo(r.right + d.dx, r.bottom + d.dy)
          ..lineTo(r.left + d.dx, r.bottom + d.dy)
          ..lineTo(r.left, r.bottom)
          ..close();
        canvas.drawPath(path, sh);
        continue;
      }
      if (!vis(o.c, o.r + 80)) continue;
      if (o.kind == ObstacleKind.tree) {
        final h = _treeH(o);
        canvas.drawLine(
            o.c,
            o.c + _sun * h * .8,
            Paint()
              ..strokeWidth = 9
              ..color = Colors.black.withValues(alpha: .2));
        canvas.drawCircle(o.c + _sun * h, o.r * (_isPalm(o) ? 1.6 : 1.5), sh);
      } else {
        final h = switch (o.kind) { ObstacleKind.rock => o.r * .7, ObstacleKind.barrel => o.r * 1.6, _ => o.r * 1.2 };
        canvas.drawCircle(o.c + _sun * h * .5, o.r * 1.05, sh);
      }
    }
    for (final b in g.bushes) {
      if (vis(b.c, b.r + 20)) canvas.drawCircle(b.c + _sun * 14, b.r, sh);
    }
    for (final f in g.fighters) {
      if (!f.alive || !vis(f.pos, 60)) continue;
      final lift = _lift(f);
      final r = ArenaGame.fighterR * (1 - .3 * lift);
      canvas.drawOval(Rect.fromCenter(center: f.pos + _sun * (fighterH + 120 * lift), width: r * 2.3, height: r * 2),
          Paint()
            ..color = Colors.black.withValues(alpha: .3 * (1 - .6 * lift))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
    for (final p in g.pickups) {
      if (vis(p.pos, 20)) canvas.drawOval(Rect.fromCenter(center: p.pos + const Offset(4, 3), width: 26, height: 18), sh);
    }
  }

  void _lights(Canvas canvas, bool Function(Offset, double) vis) {
    void light(Offset c, double r, Color col) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = RadialGradient(colors: [col, col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)));
    }

    for (final f in g.fighters) {
      if (f.alive && f.muzzle > 0 && vis(f.pos, 100)) {
        light(f.pos + Offset.fromDirection(f.angle, 40), 95, const Color(0x66FFB050));
      }
    }
    for (final e in g.fx) {
      if (e.kind != 'boom' || !vis(e.pos, 300)) continue;
      final k = e.age / e.life;
      light(e.pos, e.value * 2.2, const Color(0xFFFF9A3D).withValues(alpha: .8 * (1 - k)));
    }
  }

  /// صندوق مجسم: جدار أو سور، مقسم لقطع قصيرة ليصح ترتيب العمق.
  void _wallItems(Canvas canvas, ArenaCamera cv, Obstacle o, List<(double, void Function())> items) {
    final r = o.rect!;
    final me = g.player;
    final horiz = r.width >= r.height;
    final len = horiz ? r.width : r.height;
    final n = max(1, (len / 70).ceil());
    for (var i = 0; i < n; i++) {
      final seg = horiz
          ? Rect.fromLTWH(r.left + len * i / n, r.top, len / n, r.height)
          : Rect.fromLTWH(r.left, r.top + len * i / n, r.width, len / n);
      final first = i == 0, last = i == n - 1;
      // شفاف إذا كان اللاعب خلفه مباشرة
      final behind = me.alive && me.pos.dy < seg.bottom && me.pos.dy > seg.top - 90 && me.pos.dx > seg.left - 30 && me.pos.dx < seg.right + 30;
      items.add((
        seg.bottom,
        () => _box(canvas, cv, seg,
            h: _wallH,
            alpha: behind ? .45 : 1,
            west: horiz ? first : true,
            east: horiz ? last : true,
            north: horiz ? true : first,
            south: horiz ? true : last)
      ));
    }
  }

  void _box(Canvas canvas, ArenaCamera cv, Rect r,
      {required double h, double alpha = 1, bool west = true, bool east = true, bool north = true, bool south = true}) {
    Offset p(double x, double y, double z) => cv.project(Offset(x, y), z);
    void face(List<Offset> q, Color top, Color bottom) {
      final path = Path()..addPolygon(q, true);
      final b = path.getBounds();
      canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top.withValues(alpha: alpha), bottom.withValues(alpha: alpha)],
            ).createShader(b));
    }

    final eye = cv.cam;
    if (west && eye.dx < r.left) {
      face([p(r.left, r.top, h), p(r.left, r.bottom, h), p(r.left, r.bottom, 0), p(r.left, r.top, 0)],
          const Color(0xFF8C6B4F), const Color(0xFF4A3628));
    }
    if (east && eye.dx > r.right) {
      face([p(r.right, r.top, h), p(r.right, r.bottom, h), p(r.right, r.bottom, 0), p(r.right, r.top, 0)],
          const Color(0xFF7A5C43), const Color(0xFF3E2D21));
    }
    if (south) {
      final q = [p(r.left, r.bottom, h), p(r.right, r.bottom, h), p(r.right, r.bottom, 0), p(r.left, r.bottom, 0)];
      face(q, const Color(0xFFA27C5A), const Color(0xFF5A4231));
      // ألواح خشبية
      final line = Paint()
        ..strokeWidth = 1.2
        ..color = Colors.black.withValues(alpha: .22 * alpha);
      for (final z in [h * .33, h * .66]) {
        canvas.drawLine(p(r.left, r.bottom, z), p(r.right, r.bottom, z), line);
      }
    }
    // السطح العلوي
    final top = [p(r.left, r.top, h), p(r.right, r.top, h), p(r.right, r.bottom, h), p(r.left, r.bottom, h)];
    canvas.drawPath(Path()..addPolygon(top, true), Paint()..color = const Color(0xFFD9B98F).withValues(alpha: alpha));
    canvas.drawPath(
        Path()..addPolygon(top, true),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF6B4F38).withValues(alpha: alpha));
  }

  /// صخرة أو صندوق أو برميل: طبقات فوق بعض تعطي حجماً حقيقياً.
  void _stacked(Canvas canvas, ArenaCamera cv, Obstacle o) {
    final img = _prop(o.kind);
    final h = switch (o.kind) { ObstacleKind.rock => o.r * .7, ObstacleKind.barrel => o.r * 1.6, _ => o.r * 1.2 };
    final layers = o.kind == ObstacleKind.rock ? 5 : 7;
    for (var i = 0; i <= layers; i++) {
      final k = i / layers;
      final rad = o.kind == ObstacleKind.rock ? o.r * (1.15 - .25 * k * k) : o.r * 1.12;
      _onPlane(canvas, cv, h * k, () {
        final dark = Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = i == layers ? null : ColorFilter.mode(Colors.black.withValues(alpha: .55 - .35 * k), BlendMode.srcATop);
        if (img != null) {
          drawSprite(canvas, img, Rect.fromCircle(center: o.c, radius: rad), paint: dark);
        } else {
          canvas.drawCircle(o.c, rad, Paint()..color = Color.lerp(const Color(0xFF55575E), const Color(0xFFA9ACB5), k)!);
        }
      });
    }
  }

  void _bush(Canvas canvas, ArenaCamera cv, Obstacle b) {
    final inside = (b.c - g.player.pos).distance < b.r;
    final a = inside ? .45 : .97;
    final bi = sprites['ar_bush'];
    for (var i = 0; i <= 3; i++) {
      final k = i / 3;
      _onPlane(canvas, cv, 18 * k, () {
        final rad = b.r * (.85 + .25 * k);
        final sway = Offset(sin(g.time * 1.6 + b.c.dx * .01) * 1.5 * k, 0);
        if (bi != null) {
          drawSprite(canvas, bi, Rect.fromCircle(center: b.c + sway, radius: rad),
              paint: Paint()
                ..filterQuality = FilterQuality.medium
                ..colorFilter = i == 3 ? null : ColorFilter.mode(Colors.black.withValues(alpha: .4 - .3 * k), BlendMode.srcATop)
                ..color = Colors.white.withValues(alpha: a));
        } else {
          canvas.drawCircle(b.c + sway, rad, Paint()..color = Color.lerp(const Color(0xFF2F5E22), const Color(0xFF5FA043), k)!.withValues(alpha: a));
        }
      });
    }
  }

  void _tree(Canvas canvas, ArenaCamera cv, Obstacle o, double t) {
    final h = _treeH(o);
    final palm = _isPalm(o);
    final me = g.player;
    // شفافة إذا غطّت اللاعب
    final crown = cv.project(o.c, h * .85);
    final mine = cv.project(me.pos, fighterH);
    final crownR = o.r * 1.7 * cv.depthScale(o.c, h);
    final a = (crown - mine).distance < crownR ? .35 : 1.0;
    final sway = Offset(sin(t * 1.1 + o.c.dx * .013), cos(t * .9 + o.c.dy * .011) * .6) * 4;
    // الجذع
    final base = cv.project(o.c), topP = cv.project(o.c + sway * .6 + (palm ? Offset(o.r * .5, 0) : Offset.zero), h * .8);
    final ds = cv.depthScale(o.c, h * .4);
    final trunk = Path()..moveTo(base.dx, base.dy);
    if (palm) {
      final mid = cv.project(o.c + Offset(-o.r * .3, 0), h * .45);
      trunk.quadraticBezierTo(mid.dx, mid.dy, topP.dx, topP.dy);
    } else {
      trunk.lineTo(topP.dx, topP.dy);
    }
    canvas.drawPath(
        trunk,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (palm ? 9 : 13) * ds
          ..color = (palm ? const Color(0xFF8A6A45) : const Color(0xFF5E4130)).withValues(alpha: a));
    canvas.drawPath(
        trunk,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (palm ? 3 : 4) * ds
          ..color = Colors.white.withValues(alpha: .18 * a));
    // التاج: 3 طبقات، السفلى أغمق، تتمايل مع الريح
    final ti = sprites[palm ? 'ar_palm' : 'ar_tree'];
    final layers = palm ? 2 : 3;
    for (var i = 0; i < layers; i++) {
      final k = layers == 1 ? 1.0 : i / (layers - 1);
      final z = h * (palm ? .78 + .1 * k : .62 + .38 * k);
      final c = o.c + sway * (.5 + k) + (palm ? Offset(o.r * .5, 0) : Offset.zero);
      final rad = o.r * (palm ? 1.75 : 1.75 - .35 * k);
      _onPlane(canvas, cv, z, () {
        final paint = Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = i == layers - 1 ? null : ColorFilter.mode(Colors.black.withValues(alpha: .45 - .2 * k), BlendMode.srcATop)
          ..color = Colors.white.withValues(alpha: a);
        if (ti != null) {
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(sin(t * .8 + o.c.dx) * .04 + i * .5);
          drawSprite(canvas, ti, Rect.fromCircle(center: Offset.zero, radius: rad), paint: paint);
          canvas.restore();
        } else {
          canvas.drawCircle(c, rad, Paint()..color = Color.lerp(const Color(0xFF2F6B2A), const Color(0xFF58A84B), k)!.withValues(alpha: a));
        }
      });
    }
  }

  /// جدار العاصفة البنفسجي الشاهق على حافة الدائرة.
  void _stormWall(Canvas canvas, ArenaCamera cv, Rect view, double t) {
    if (!view.inflate(200).overlaps(Rect.fromCircle(center: g.zoneC, radius: g.zoneR + 40))) return;
    final r = max(g.zoneR, 1.0);
    final n = (2 * pi * r / 50).clamp(24, 600).round();
    const hTop = 230.0;
    final pos = <Offset>[], cols = <Color>[];
    final bottom = const Color(0xCC8E5BFF), top = const Color(0x007A2BFF);
    for (var i = 0; i < n; i++) {
      final a0 = i / n * 2 * pi, a1 = (i + 1) / n * 2 * pi;
      final w0 = g.zoneC + Offset.fromDirection(a0, r), w1 = g.zoneC + Offset.fromDirection(a1, r);
      if (!view.contains(w0) && !view.contains(w1)) continue;
      final wave0 = hTop * (.75 + .25 * sin(t * 2 + i * .7)), wave1 = hTop * (.75 + .25 * sin(t * 2 + (i + 1) * .7));
      final b0 = cv.project(w0), b1 = cv.project(w1), t0 = cv.project(w0, wave0), t1 = cv.project(w1, wave1);
      pos.addAll([b0, b1, t1, b0, t1, t0]);
      cols.addAll([bottom, bottom, top, bottom, top, top]);
    }
    if (pos.isEmpty) return;
    canvas.drawVertices(ui.Vertices(VertexMode.triangles, pos, colors: cols), BlendMode.dst, Paint());
    // شرارات تصعد على الجدار
    final spark = Paint()..color = const Color(0xFFE9DDFF);
    for (var i = 0; i < n; i += 3) {
      final a = i / n * 2 * pi;
      final w = g.zoneC + Offset.fromDirection(a, r);
      if (!view.contains(w)) continue;
      final ph = (t * .6 + i * .137) % 1;
      final sp = cv.project(w, ph * hTop);
      spark.color = const Color(0xFFE9DDFF).withValues(alpha: .9 * (1 - ph));
      canvas.drawCircle(sp, 2.5 * cv.depthScale(w), spark);
    }
  }

  void _pickup(Canvas canvas, Pickup p, double t) {
    var c = p.pos;
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

  void _fighter(Canvas canvas, ArenaCamera cv, Fighter f, bool hidden) {
    final lift = _lift(f);
    final h = fighterH + 300 * lift;
    final img = sprites['ar_fighter_${f.skin % 8}'];
    _onPlane(canvas, cv, h, () {
      if (img != null) {
        _fighterSprite(canvas, f, hidden, img);
      } else {
        _fighterShape(canvas, f, hidden);
      }
    });
    if (lift > 0) _parachute(canvas, cv, f, h, lift);
  }

  void _fighterSprite(Canvas canvas, Fighter f, bool hidden, ui.Image img) {
    final c = f.pos;
    const r = ArenaGame.fighterR;
    final alpha = hidden ? .55 : 1.0;
    final t = this.g.time;
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
    // ارتداد عند الإطلاق: الجسم يرجع للخلف قليلاً
    final kick = f.muzzle > 0 ? f.muzzle / .06 : 0.0;
    canvas.translate(-cos(f.angle) * 4 * kick, -sin(f.angle) * 4 * kick);
    // تمايل المشي، وتنفّس خفيف وقت الوقوف، وانضغاط لحظة الهبوط
    final step = sin(f.walkT);
    final breathe = (1 - f.moveAmt) * .018 * sin(t * 3 + f.id);
    final land = t > 2.2 && t < 2.6 ? .12 * sin((t - 2.2) / .4 * pi) : 0.0;
    canvas.scale(1 + .035 * f.moveAmt * step.abs() + breathe + land);
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
          drawSprite(canvas, gi, Rect.fromLTWH(hand.dx - 8 - 6 * kick, hand.dy - h * .45, len, h), paint: paint);
        }
      }
      if (f.muzzle > 0) {
        // وميض نجمي يتغير كل طلقة
        final fc = tip + const Offset(6, 0);
        final star = Path();
        final spikes = 7;
        for (var i = 0; i < spikes * 2; i++) {
          final rr = i.isEven ? (i == 0 ? 22.0 : 13.0) * (.7 + .3 * kick) : 4.5;
          final a = i / (spikes * 2) * 2 * pi + f.id;
          final pt = fc + Offset(cos(a) * rr * (i == 0 ? 1 : .8), sin(a) * rr * .8);
          i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
        }
        star.close();
        canvas.drawPath(star, Paint()..color = const Color(0xFFFFC94D));
        canvas.drawCircle(fc, 6, Paint()..color = Colors.white);
      }
    }
    canvas.restore();
  }

  /// مظلة مجسمة فوق المقاتل: قبة ملونة وحبال تنزل إليه.
  void _parachute(Canvas canvas, ArenaCamera cv, Fighter f, double h, double lift) {
    final col = arenaSkins[f.skin % arenaSkins.length];
    final top = h + 95;
    const w = 58.0;
    final c = f.pos;
    final me = cv.project(c, h + 10);
    final lines = Paint()
      ..strokeWidth = 1.3
      ..color = Colors.black.withValues(alpha: .55);
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * 2 * pi;
      canvas.drawLine(cv.project(c + Offset.fromDirection(a, w * .92), top - 8), me, lines);
    }
    final sway = sin(g.time * 2.5 + f.id) * .12;
    _onPlane(canvas, cv, top, () {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(sway);
      for (var i = 0; i < 8; i++) {
        canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: w), i * pi / 4, pi / 4, true,
            Paint()..color = i.isEven ? col : Colors.white);
      }
      canvas.drawCircle(
          Offset.zero,
          w,
          Paint()
            ..shader = const RadialGradient(colors: [Color(0x00000000), Color(0x55000000)], stops: [.55, 1])
                .createShader(Rect.fromCircle(center: Offset.zero, radius: w)));
      canvas.drawCircle(Offset.zero, 8, Paint()..color = Colors.white.withValues(alpha: .8));
      canvas.restore();
    });
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
          // يسقط ويدور ثم يستقر
          final fall = Curves.easeOutBack.transform(min(1.0, e.age * 2.5));
          canvas.rotate(e.rot - _tilt + .9 * fall);
          canvas.scale(1.12 - .22 * fall);
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

  void _fxAir(Canvas canvas, Fx e, {Offset? at}) {
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
        final p = at ?? e.pos;
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.scale(pop);
        if (k > .7) canvas.scale(1 - (k - .7));
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
    }
  }

  /// الاسم وشريط الصحة فوق الرأس، مرسومة على الشاشة مباشرة لتبقى واضحة.
  void _overhead(Canvas canvas, Fighter f, Offset at, double k) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(k);
    if (f.healing != null) {
      canvas.drawArc(
          Rect.fromCircle(center: const Offset(0, 8), radius: 9),
          -pi / 2,
          2 * pi * (1 - f.healLeft / (f.healing == PickupKind.medkit ? 3.5 : 1.6)),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..color = const Color(0xFF6BE38F));
    }
    if (f.isPlayer) {
      final bob = sin(g.time * 4) * 3;
      final p = Path()
        ..moveTo(0, -8 + bob)
        ..lineTo(-8, -20 + bob)
        ..lineTo(8, -20 + bob)
        ..close();
      canvas.drawPath(p, Paint()..color = const Color(0xFFFFC23D));
      canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.black54);
      canvas.restore();
      return;
    }
    final tp = label(f.name, size: 11);
    tp.paint(canvas, Offset(-tp.width / 2, -30));
    final bar = const Rect.fromLTWH(-21, -12, 42, 6);
    canvas.drawRRect(RRect.fromRectAndRadius(bar.inflate(1), const Radius.circular(3)), Paint()..color = Colors.black54);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bar.left, bar.top, 42 * (f.hp / 100).clamp(0, 1), 6), const Radius.circular(3)),
        Paint()..color = f.hp > 50 ? const Color(0xFF6BE38F) : f.hp > 25 ? const Color(0xFFFFC23D) : const Color(0xFFFF5A5F));
    if (f.armor > 0) {
      canvas.drawRect(Rect.fromLTWH(bar.left, bar.top - 3.5, 42 * (f.armor / 100).clamp(0, 1), 2.5),
          Paint()..color = const Color(0xFF5CC8FF));
    }
    canvas.restore();
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
