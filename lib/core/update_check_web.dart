import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// رقم النسخة يُكتب وقت البناء على GitHub (build_id.txt بجانب الموقع).
const _buildId = String.fromEnvironment('BUILD_ID');

class UpdateCheck {
  UpdateCheck._();
  static final instance = UpdateCheck._();

  /// true إذا نزلت نسخة أحدث من اللي شغالة الحين.
  final available = ValueNotifier<bool>(false);
  Timer? _timer;

  void start() {
    if (_buildId.isEmpty || _timer != null) return;
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _check());
    Timer(const Duration(seconds: 20), _check);
  }

  Future<void> _check() async {
    try {
      final res = await web.window
          .fetch('build_id.txt?t=${DateTime.now().millisecondsSinceEpoch}'.toJS, web.RequestInit(cache: 'no-store'))
          .toDart;
      if (!res.ok) return;
      final latest = (await res.text().toDart).toDart.trim();
      if (latest.isNotEmpty && latest != _buildId) available.value = true;
    } catch (_) {}
  }

  /// يحدّث ملفات الموقع في كاش المتصفح أول، وإلا ممكن يرجع يفتح النسخة القديمة.
  Future<void> reload() async {
    try {
      await Future.wait([
        for (final f in ['main.dart.js', 'flutter_bootstrap.js', 'index.html', 'flutter.js'])
          web.window.fetch(f.toJS, web.RequestInit(cache: 'reload')).toDart,
      ]).timeout(const Duration(seconds: 15));
    } catch (_) {}
    web.window.location.reload();
  }
}
