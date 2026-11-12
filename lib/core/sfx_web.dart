import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

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

  /// دفقة ضجيج مفلترة (خشخشة النرد، طرقة القطعة).
  void noise(double dur, {double vol = .25, double freq = 2500, double q = 1, double delay = 0, String filter = 'bandpass'}) {
    if (!Account.instance.sounds) return;
    try {
      final ctx = _ctx ??= web.AudioContext();
      if (ctx.state == 'suspended') ctx.resume();
      final n = max(1, (ctx.sampleRate * dur).round());
      final buf = ctx.createBuffer(1, n, ctx.sampleRate);
      final data = Float32List(n);
      for (var i = 0; i < n; i++) {
        data[i] = (_rng.nextDouble() * 2 - 1) * pow(1 - i / n, 2).toDouble();
      }
      buf.copyToChannel(data.toJS, 0);
      final src = ctx.createBufferSource()..buffer = buf;
      final f = ctx.createBiquadFilter()
        ..type = filter
        ..frequency.value = freq
        ..Q.value = q;
      final g = ctx.createGain()..gain.value = vol;
      src.connect(f);
      f.connect(g);
      g.connect(ctx.destination);
      src.start(ctx.currentTime + delay);
    } catch (_) {}
  }

  /// خشخشة النرد في الكوب ثم ارتطامه.
  void diceShake() {
    for (var i = 0; i < 5; i++) {
      noise(.05, vol: .35, freq: 2600 + _rng.nextInt(1800).toDouble(), q: 3, delay: i * .07 + _rng.nextDouble() * .02);
    }
  }

  void diceLand() {
    noise(.09, vol: .5, freq: 900, q: 1.2);
    tone(220, 140, .08, type: 'triangle', vol: .12);
    noise(.05, vol: .25, freq: 1800, q: 2, delay: .09);
  }

  /// طرقة خشبية لكل خطوة للقطعة، تعلو قليلاً مع كل خطوة.
  void hop([int step = 0]) {
    final f = 600 + (step % 8) * 40.0;
    tone(f, f * .55, .07, type: 'triangle', vol: .16);
    noise(.03, vol: .18, freq: 3000, q: 4);
  }

  /// أكل قطعة.
  void capture() {
    tone(700, 120, .35, type: 'square', vol: .1);
    noise(.25, vol: .3, freq: 600, q: .8, delay: .02);
  }

  /// قطعة خرجت من البيت أو وصلت.
  void release() {
    tone(392, 784, .18, type: 'triangle', vol: .14);
  }

  void home() {
    for (final (i, f) in [659.0, 784.0, 988.0].indexed) {
      tone(f, f, .12, type: 'triangle', vol: .14, delay: i * .08);
    }
  }

  /// استلام أداة أو هدية.
  void pickup() {
    tone(880, 1760, .12, type: 'sine', vol: .14);
    tone(1320, 2200, .1, type: 'sine', vol: .1, delay: .08);
  }

  /// تكة قصيرة (مرور المؤشر، اصطدام الكرة).
  void tick() => tone(1400, 900, .04, type: 'triangle', vol: .08);

  /// بداية اللف: سحبة ذراع وهواء.
  void spinStart() {
    noise(.35, vol: .25, freq: 700, q: .7, filter: 'lowpass');
    tone(180, 520, .3, type: 'sawtooth', vol: .05);
  }

  /// توقف بكرة: طرقة معدنية.
  void reelStop([int i = 0]) {
    noise(.06, vol: .45, freq: 1200, q: 2);
    tone(260 - i * 12.0, 120, .12, type: 'triangle', vol: .18);
  }

  /// رنين عملات متتالية.
  void coins([int n = 6]) {
    for (var i = 0; i < n; i++) {
      final f = 2000 + _rng.nextInt(1600).toDouble();
      tone(f, f * 1.02, .09, type: 'sine', vol: .09, delay: i * .06 + _rng.nextDouble() * .02);
      tone(f * 1.5, f * 1.5, .06, type: 'triangle', vol: .05, delay: i * .06 + .01);
    }
  }

  /// خط رابح: رنة صاعدة.
  void lineWin() {
    for (final (i, f) in [784.0, 988.0, 1175.0, 1568.0].indexed) {
      tone(f, f, .1, type: 'square', vol: .06, delay: i * .05);
    }
  }

  /// ربح كبير: فانفير ثلاث أكوردات ثم أربيجيو.
  void bigWin() {
    const chords = [
      [523.0, 659.0, 784.0],
      [587.0, 740.0, 880.0],
      [659.0, 831.0, 988.0, 1319.0],
    ];
    for (final (i, ch) in chords.indexed) {
      for (final f in ch) {
        tone(f, f, i == 2 ? .7 : .22, type: 'sawtooth', vol: .05, delay: i * .24);
        tone(f / 2, f / 2, i == 2 ? .7 : .22, type: 'triangle', vol: .08, delay: i * .24);
      }
    }
    for (var i = 0; i < 12; i++) {
      final f = [1319.0, 1568.0, 1760.0, 2093.0][i % 4];
      tone(f, f, .08, type: 'sine', vol: .07, delay: .75 + i * .07);
    }
    coins(14);
  }

  /// عداد الأرباح يطلع.
  void countTick() => tone(1800, 1700, .03, type: 'square', vol: .03);

  /// صافرة حكم.
  void whistle() {
    for (var i = 0; i < 9; i++) {
      tone(2900 + (i.isEven ? 120 : -120), 2900, .045, type: 'sine', vol: .1, delay: i * .04);
    }
    tone(2900, 2800, .25, type: 'sine', vol: .08, delay: .4);
  }

  /// هتاف الجمهور.
  void cheer() {
    noise(1.6, vol: .35, freq: 1100, q: .5);
    noise(1.2, vol: .25, freq: 2400, q: .7, delay: .2);
  }

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
