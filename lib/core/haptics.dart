import 'package:flutter/services.dart';

import 'account/account.dart';

/// اهتزاز يحترم إعداد اللاعب.
class Haptics {
  static bool get _on => Account.instance.haptics;
  static Future<void> lightImpact() async => _on ? HapticFeedback.lightImpact() : null;
  static Future<void> mediumImpact() async => _on ? HapticFeedback.mediumImpact() : null;
  static Future<void> heavyImpact() async => _on ? HapticFeedback.heavyImpact() : null;
  static Future<void> selectionClick() async => _on ? HapticFeedback.selectionClick() : null;
  static Future<void> vibrate() async => _on ? HapticFeedback.vibrate() : null;
}
