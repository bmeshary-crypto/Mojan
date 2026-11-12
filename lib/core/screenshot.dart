import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// يلتف حول التطبيق كله لأخذ صورة للشاشة (دليل البلاغات).
final appShotKey = GlobalKey();

/// صورة PNG مصغرة لما يظهر على الشاشة الآن.
Future<Uint8List?> captureScreen() async {
  try {
    final boundary = appShotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    for (final ratio in [.6, .4, .28]) {
      final img = await boundary.toImage(pixelRatio: ratio);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      final bytes = data?.buffer.asUint8List();
      if (bytes != null && bytes.length < 520 * 1024) return bytes;
    }
  } catch (e) {
    debugPrint('screenshot failed: $e');
  }
  return null;
}
