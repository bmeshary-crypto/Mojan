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
