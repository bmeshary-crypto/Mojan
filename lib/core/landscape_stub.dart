import 'package:flutter/services.dart';

/// على الجوال: تدوير الشاشة أفقياً وإخفاء أشرطة النظام.
Future<void> enterLandscape() async {
  try {
    await SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (_) {}
}

Future<void> exitLandscape() async {
  try {
    await SystemChrome.setPreferredOrientations(const []);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (_) {}
}
