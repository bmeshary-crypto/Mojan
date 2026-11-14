import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool _entered = false;

/// على متصفح الجوال: ملء الشاشة ثم قفل الاتجاه أفقياً (يعمل على أندرويد).
/// يجب استدعاؤها مباشرة من ضغطة زر. على الآيفون لا يدعم المتصفح القفل،
/// فتتولى اللعبة تدوير نفسها.
Future<void> enterLandscape() async {
  final ua = web.window.navigator.userAgent.toLowerCase();
  final mobile = ua.contains('android') || ua.contains('iphone') || ua.contains('ipad') || ua.contains('mobile');
  if (!mobile) return;
  try {
    if (web.document.fullscreenElement == null) {
      await web.document.documentElement?.requestFullscreen().toDart;
      _entered = true;
    }
  } catch (_) {}
  try {
    await web.window.screen.orientation.lock('landscape').toDart;
  } catch (_) {}
}

Future<void> exitLandscape() async {
  try {
    web.window.screen.orientation.unlock();
  } catch (_) {}
  try {
    if (_entered && web.document.fullscreenElement != null) await web.document.exitFullscreen().toDart;
  } catch (_) {}
  _entered = false;
}
