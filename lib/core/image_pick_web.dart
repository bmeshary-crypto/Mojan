import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// يفتح اختيار صورة ويرجعها JPEG مصغرة (أطول ضلع [maxSide]) حتى تنحفظ في الرسالة.
Future<Uint8List?> pickImageJpeg({int maxSide = 1100}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*';
  final picked = Completer<web.File?>();
  input.onchange = ((web.Event _) {
    final files = input.files;
    picked.complete(files != null && files.length > 0 ? files.item(0) : null);
  }).toJS;
  input.click();
  final file = await picked.future.timeout(const Duration(minutes: 5), onTimeout: () => null);
  if (file == null) return null;

  final url = web.URL.createObjectURL(file);
  try {
    final img = web.HTMLImageElement()..src = url;
    final loaded = Completer<bool>();
    img.onload = ((web.Event _) => loaded.complete(true)).toJS;
    img.onerror = ((web.Event _) => loaded.complete(false)).toJS;
    if (!await loaded.future) return null;
    var w = img.naturalWidth, h = img.naturalHeight;
    if (w <= 0 || h <= 0) return null;
    final scale = (w > h ? w : h) > maxSide ? maxSide / (w > h ? w : h) : 1.0;
    w = (w * scale).round();
    h = (h * scale).round();
    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(img, 0, 0, w.toDouble(), h.toDouble());
    for (final q in [.72, .55, .4]) {
      final data = canvas.toDataURL('image/jpeg', q.toJS);
      final bytes = base64Decode(data.substring(data.indexOf(',') + 1));
      if (bytes.length < 600 * 1024) return bytes;
    }
    return null;
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
