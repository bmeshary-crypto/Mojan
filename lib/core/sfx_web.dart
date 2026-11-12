import 'dart:math';

import 'package:web/web.dart' as web;

import 'account/account.dart';

/// صوت «بوب» قصير مولّد بالكود (بدون ملفات صوت)، بنغمة مختلفة قليلاً كل مرة.
class Sfx {
  Sfx._();
  static final instance = Sfx._();

  web.AudioContext? _ctx;
  final _rng = Random();
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// نغمة قصيرة من [from] إلى [to] هيرتز.
  void tone(double from, double to, double dur, {String type = 'sine', double vol = .2, double delay = 0}) {
    if (!Account.instance.sounds) return;
    try {
      final ctx = _ctx ??= web.AudioContext();
      if (ctx.state == 'suspended') ctx.resume();
      final t = ctx.currentTime + delay;
      final osc = ctx.createOscillator()..type = type;
      osc.frequency
        ..setValueAtTime(from, t)
        ..exponentialRampToValueAtTime(to, t + dur);
      final gain = ctx.createGain();
      gain.gain
        ..setValueAtTime(.0001, t)
        ..exponentialRampToValueAtTime(vol, t + .015)
        ..exponentialRampToValueAtTime(.0001, t + dur);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t);
      osc.stop(t + dur + .02);
    } catch (_) {}
  }

  /// تكة قصيرة (مرور المؤشر، اصطدام الكرة).
  void tick() => tone(1400, 900, .04, type: 'triangle', vol: .08);

  /// لحن فوز صغير.
  void win() {
    for (final (i, f) in [523.0, 659.0, 784.0, 1046.0].indexed) {
      tone(f, f * 1.01, .16, type: 'triangle', vol: .16, delay: i * .09);
    }
  }

  /// صوت خسارة أو انفجار.
  void lose() => tone(300, 60, .45, type: 'sawtooth', vol: .12);

  void tap() {
    if (!Account.instance.sounds) return;
    final now = DateTime.now();
    if (now.difference(_last).inMilliseconds < 60) return;
    _last = now;
    try {
      final ctx = _ctx ??= web.AudioContext();
      if (ctx.state == 'suspended') ctx.resume();
      final t = ctx.currentTime;
      final base = 520 + _rng.nextInt(5) * 70.0;
      final osc = ctx.createOscillator()..type = 'sine';
      osc.frequency
        ..setValueAtTime(base, t)
        ..exponentialRampToValueAtTime(base * 1.9, t + .07);
      final gain = ctx.createGain();
      gain.gain
        ..setValueAtTime(.0001, t)
        ..exponentialRampToValueAtTime(.22, t + .012)
        ..exponentialRampToValueAtTime(.0001, t + .13);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t);
      osc.stop(t + .14);
    } catch (_) {}
  }
}
