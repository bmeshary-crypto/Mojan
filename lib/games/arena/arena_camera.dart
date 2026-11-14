import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';

/// كاميرا مائلة بمنظور ثلاثي الأبعاد فوق أرض الجزيرة.
///
/// العالم أرض مستوية (x, y) والارتفاع h فوقها. الكاميرا تنظر من الجنوب
/// بميل [tilt] فيظهر البعيد أصغر، والأشياء العالية ترتفع على الشاشة.
class ArenaCamera {
  static const tilt = .62; // ≈ 35°
  static const persp = 1 / 1250;

  /// موضع مركز الكاميرا على الشاشة (أسفل المنتصف قليلاً ليظهر ما أمامك).
  static const anchorY = .58;

  Size size = Size.zero;
  Offset cam = Offset.zero;
  double scale = 1;
  Matrix4 _m = Matrix4.identity();
  final _planes = <int, Float64List>{};

  static final cosT = cos(tilt);

  void update(Size size, Offset cam, double scale) {
    if (size == this.size && cam == this.cam && scale == this.scale) return;
    this.size = size;
    this.cam = cam;
    this.scale = scale;
    _m = Matrix4.identity()
      ..translateByDouble(size.width / 2, size.height * anchorY, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1)
      ..multiply(Matrix4.identity()..setEntry(3, 2, persp))
      ..multiply(Matrix4.rotationX(-tilt))
      ..translateByDouble(-cam.dx, -cam.dy, 0, 1);
    _planes.clear();
  }

  /// مصفوفة رسم مستوى أفقي على ارتفاع [h] (لـ canvas.transform).
  Float64List plane([double h = 0]) => _planes.putIfAbsent(
      h.round(), () => (_m.clone()..translateByDouble(0, 0, -h.roundToDouble(), 1)).storage);

  /// نقطة من العالم على ارتفاع [h] → الشاشة.
  Offset project(Offset p, [double h = 0]) {
    final s = _m.storage;
    final z = -h;
    final x = s[0] * p.dx + s[4] * p.dy + s[8] * z + s[12];
    final y = s[1] * p.dx + s[5] * p.dy + s[9] * z + s[13];
    final w = s[3] * p.dx + s[7] * p.dy + s[11] * z + s[15];
    return Offset(x / w, y / w);
  }

  /// كم يتكبّر شيء عند هذه النقطة (1 = بحجم الكاميرا).
  double depthScale(Offset p, [double h = 0]) {
    final s = _m.storage;
    final w = s[3] * p.dx + s[7] * p.dy + s[11] * -h + s[15];
    return scale / w;
  }

  /// نقطة على الشاشة → العالم على مستوى الارتفاع [h].
  Offset unproject(Offset sp, [double h = 0]) {
    final s = _m.storage;
    final z = -h;
    final d0 = s[8] * z + s[12], d1 = s[9] * z + s[13], d3 = s[11] * z + s[15];
    final a00 = s[0] - sp.dx * s[3], a01 = s[4] - sp.dx * s[7], b0 = sp.dx * d3 - d0;
    final a10 = s[1] - sp.dy * s[3], a11 = s[5] - sp.dy * s[7], b1 = sp.dy * d3 - d1;
    final det = a00 * a11 - a01 * a10;
    if (det.abs() < 1e-9) return cam;
    return Offset((b0 * a11 - a01 * b1) / det, (a00 * b1 - b0 * a10) / det);
  }

  /// الجزء الظاهر من الأرض (مستطيل يحيط بشبه المنحرف المرئي).
  Rect groundView() {
    final pts = [
      unproject(Offset.zero),
      unproject(Offset(size.width, 0)),
      unproject(Offset(0, size.height)),
      unproject(Offset(size.width, size.height)),
    ];
    var r = Rect.fromPoints(pts[0], pts[3]);
    for (final p in pts) {
      r = r.expandToInclude(Rect.fromCenter(center: p, width: 1, height: 1));
    }
    // حماية من الأرقام الضخمة إذا كانت الشاشة غريبة المقاس
    return r.intersect(Rect.fromCenter(center: cam, width: 6000, height: 6000));
  }

  /// اتجاه على الشاشة (عصا التحكم) → اتجاه على الأرض.
  Offset screenDirToWorld(Offset v) => Offset(v.dx, v.dy / cosT);
}
