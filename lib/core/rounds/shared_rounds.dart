import 'dart:math';

import 'clock_sync.dart';

/// جولات موحدة بين كل الأجهزة بدون سيرفر.
///
/// كل لعبة جماعية (عجلة السماء، الفواكه، الصاروخ) تقسم الوقت لجولات ثابتة
/// محسوبة من الساعة، ونتيجة كل جولة تُحسب من رقمها. فأي جهاز يفتح اللعبة
/// في نفس اللحظة يشوف نفس الجولة ونفس العداد ونفس النتيجة ونفس الفائزين.
class SharedClock {
  SharedClock._();

  /// الفرق بين ساعة الجهاز وساعة السيرفر (يتحدث عند فتح التطبيق).
  static Duration offset = Duration.zero;

  /// للاختبارات: تثبيت الوقت.
  static int? fixedMs;

  static int nowMs() => fixedMs ?? DateTime.now().millisecondsSinceEpoch + offset.inMilliseconds;

  static Future<void> sync() async {
    final o = await serverClockOffset();
    if (o != null) offset = o;
  }
}

/// بذرة ثابتة لجولة معينة في لعبة معينة (FNV-1a).
int roundSeed(String game, int round, [String part = '']) {
  var h = 0x811c9dc5;
  for (final c in 'mojan|$game|$round|$part'.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

Random roundRng(String game, int round, [String part = '']) => Random(roundSeed(game, round, part));

/// جولات بطول ثابت: رقم الجولة والوقت داخلها.
class FixedRounds {
  const FixedRounds(this.periodMs);
  final int periodMs;

  int roundAt(int ms) => ms ~/ periodMs;
  int startOf(int round) => round * periodMs;
  int get current => roundAt(SharedClock.nowMs());
  int get elapsedMs => SharedClock.nowMs() - startOf(current);
}
