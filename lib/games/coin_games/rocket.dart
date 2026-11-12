import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/account/account.dart';
import '../../core/haptics.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../widgets/account_widgets.dart';
import 'coin_ui.dart';

/// سرعة صعود المضاعف: ×2 بعد 6 ثوانٍ، ×10 بعد 20 ثانية تقريباً.
const rocketGrowth = 0.1155;
const rocketMax = 1000.0;

/// نقطة الانفجار: احتمال الوصول إلى ×m = 0.97 ÷ m، فالعائد المتوقع ≈97% مهما كان وقت السحب.
double rocketCrashPoint(Random r) {
  final u = r.nextDouble();
  final c = (97 / (1 - u)).floor() / 100;
  return c.clamp(1.0, rocketMax);
}

double rocketMultAt(double seconds) => exp(rocketGrowth * seconds);

enum RocketPhase { waiting, flying, crashed }

class _Rider {
  _Rider(this.name, this.bet, this.target);
  final String name;
  final int bet;
  final double target;
  double? out;
  bool get you => name == 'أنت';
}

const _riderNames = ['نورة', 'فيصل', 'ريم', 'تركي', 'لمى', 'سلطان', 'دانة', 'يوسف', 'مها', 'راكان', 'غلا', 'عمر', 'هيا', 'ماجد', 'شهد', 'بندر'];

/// أقصى رهان أو ربح لأي لاعب آلي (حتى لا تتضخم العملات).
const rocketBotCap = 50000;

/// صاروخ المجرة: المضاعف يكبر مع صعود الصاروخ، اسحب قبل ما ينفجر.
class RocketScreen extends StatefulWidget {
  const RocketScreen({super.key, this.random, this.waitSeconds = 6, this.timeScale = 1.0});
  final Random? random;
  final int waitSeconds;

  /// تسريع الوقت (للاختبارات).
  final double timeScale;

  @override
  State<RocketScreen> createState() => _RocketScreenState();
}

class _RocketScreenState extends State<RocketScreen> with SingleTickerProviderStateMixin {
  late final Random _rng = widget.random ?? Random();
  late final Ticker _ticker = createTicker(_onTick);
  RocketPhase phase = RocketPhase.waiting;
  Duration _phaseStart = Duration.zero;
  Duration _now = Duration.zero;
  double _crash = 1;
  double _mult = 1;
  double _left = 0;
  int _chip = 100;
  double? _auto;

  int _myBet = 0;
  double? _myOut;
  int _queued = 0;

  List<_Rider> _riders = [];
  final List<double> _history = [];

  double get _elapsed => (_now - _phaseStart).inMicroseconds / 1e6 * widget.timeScale;

  @override
  void initState() {
    super.initState();
    _newRound();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _newRound() {
    phase = RocketPhase.waiting;
    _phaseStart = _now;
    _mult = 1;
    _myBet = 0;
    _myOut = null;
    final n = 5 + _rng.nextInt(6);
    final names = List.of(_riderNames)..shuffle(_rng);
    _riders = [
      for (var i = 0; i < n; i++)
        _Rider(
          names[i],
          const [100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000][_rng.nextInt(9)].clamp(0, rocketBotCap),
          (1.1 + -log(1 - _rng.nextDouble()) * 1.6 * (_rng.nextDouble() + .3)).clamp(1.05, 60.0),
        ),
    ];
    if (_queued > 0) {
      _myBet = _queued;
      _queued = 0;
      _riders.insert(0, _Rider('أنت', _myBet, _auto ?? double.infinity));
    }
  }

  void _onTick(Duration t) {
    _now = t;
    final e = _elapsed;
    switch (phase) {
      case RocketPhase.waiting:
        _left = widget.waitSeconds - e;
        if (_left <= 0) {
          phase = RocketPhase.flying;
          _phaseStart = t;
          _crash = rocketCrashPoint(_rng);
          Sfx.instance.tone(180, 520, .6, type: 'sawtooth', vol: .06);
        }
      case RocketPhase.flying:
        _mult = rocketMultAt(e);
        if (_mult >= _crash) {
          _mult = _crash;
          _explode();
        } else {
          for (final r in _riders) {
            if (r.out == null && _mult >= r.target) {
              if (r.you) {
                _cashOut(at: r.target);
              } else {
                r.out = r.target;
              }
            }
          }
        }
      case RocketPhase.crashed:
        if (e >= 3) _newRound();
    }
    setState(() {});
  }

  void _explode() {
    phase = RocketPhase.crashed;
    _phaseStart = _now;
    _history.insert(0, _crash);
    if (_history.length > 12) _history.removeLast();
    if (_myBet > 0 && _myOut == null) {
      Sfx.instance.lose();
      Haptics.heavyImpact();
      Account.instance.recordCoinRound('rocket', bet: _myBet, won: 0);
    } else {
      Sfx.instance.tone(220, 50, .5, type: 'square', vol: .06);
    }
  }

  void _placeBet() {
    if (phase == RocketPhase.waiting && _myBet == 0) {
      if (!takeBet(context, _chip)) return;
      Haptics.selectionClick();
      setState(() {
        _myBet = _chip;
        _riders.insert(0, _Rider('أنت', _myBet, _auto ?? double.infinity));
      });
    } else if (phase != RocketPhase.waiting && _queued == 0) {
      if (!takeBet(context, _chip)) return;
      setState(() => _queued = _chip);
      coinToast(context, 'رهانك محجوز للجولة الجاية');
    }
  }

  void _cancel() {
    if (phase == RocketPhase.waiting && _myBet > 0) {
      Account.instance.earn(_myBet);
      setState(() {
        _myBet = 0;
        _riders.removeWhere((r) => r.you);
      });
    } else if (_queued > 0) {
      Account.instance.earn(_queued);
      setState(() => _queued = 0);
    }
  }

  void _cashOut({double? at}) {
    if (phase != RocketPhase.flying || _myBet == 0 || _myOut != null) return;
    final m = at ?? _mult;
    final pay = (_myBet * m + 1e-6).floor();
    _myOut = m;
    for (final r in _riders) {
      if (r.you) r.out = m;
    }
    Account.instance.earn(pay);
    Account.instance.recordCoinRound('rocket', bet: _myBet, won: pay);
    Sfx.instance.win();
    Haptics.mediumImpact();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final inRound = _myBet > 0 && _myOut == null && phase != RocketPhase.crashed;
    return CoinGameScaffold(
      title: 'صاروخ المجرة',
      colors: const [Color(0xFF0B0F3A), Color(0xFF1A1250)],
      inPlay: inRound || _queued > 0,
      leaveMessage: 'رهانك لسه في الصاروخ، وإذا خرجت يضيع عليك.',
      onHelp: () => showHowTo(
        context,
        'صاروخ المجرة',
        'حط رهانك قبل الإقلاع. لما يطير الصاروخ يبدأ المضاعف يكبر: ×1.5، ×2، ×10 وأكثر. '
            'اضغط "اسحب" في أي لحظة وتاخذ رهانك مضروب في المضاعف وقتها، '
            'لكن لو انفجر الصاروخ قبل ما تسحب يضيع الرهان.\n\n'
            'السحب التلقائي يسحب لك لحاله عند المضاعف اللي تختاره. '
            'الصاروخ أحياناً ينفجر بدري جداً، وأحياناً يوصل لأرقام كبيرة، وما أحد يعرف متى.',
      ),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final m in _history)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (m >= 10 ? const Color(0xFFFFB13D) : m >= 2 ? const Color(0xFF2EE59D) : const Color(0xFF6B7BD9)).withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(fmtMult(m), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
              ],
            ),
          ),
          Expanded(flex: 5, child: _sky()),
          Expanded(flex: 2, child: _ridersList()),
          _controls(),
        ],
      ),
    );
  }

  Widget _sky() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _SkyPainter(
              phase: phase,
              elapsed: phase == RocketPhase.flying ? _elapsed : (phase == RocketPhase.crashed ? log(_crash) / rocketGrowth : 0),
              now: _now.inMilliseconds / 1000,
            ),
          ),
          Align(
            alignment: const Alignment(0, -.35),
            child: _centerText(),
          ),
        ],
      ),
    ),
  );

  Widget _centerText() {
    switch (phase) {
      case RocketPhase.waiting:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('الإقلاع بعد', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white70)),
            Text(_left.clamp(0, 99).toStringAsFixed(1), key: const ValueKey('rocket-wait'), style: AppTheme.display.copyWith(fontSize: 48)),
          ],
        );
      case RocketPhase.flying:
        return Text(
          ltr('×${_mult.toStringAsFixed(2)}'),
          key: const ValueKey('rocket-mult'),
          style: AppTheme.display.copyWith(fontSize: 58, color: _myOut != null ? const Color(0xFF2EE59D) : Colors.white),
        );
      case RocketPhase.crashed:
        return Column(
          key: const ValueKey('rocket-crashed'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💥', style: TextStyle(fontSize: 44)),
            Text('انفجر عند ${ltr('×${_crash.toStringAsFixed(2)}')}', style: AppTheme.display.copyWith(fontSize: 30, color: const Color(0xFFFF6B6B))),
          ],
        );
    }
  }

  Widget _ridersList() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    children: [
      for (final r in _riders)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(r.name, style: TextStyle(fontWeight: FontWeight.w800, color: r.you ? AppColors.gold : Colors.white)),
              ),
              const CoinIcon(size: 14),
              const SizedBox(width: 4),
              SizedBox(width: 52, child: Text(fmtCoins(r.bet), style: const TextStyle(fontWeight: FontWeight.w700))),
              SizedBox(
                width: 92,
                child: Text(
                  r.out != null
                      ? '${fmtMult(r.out!)}  ${ltr('+${fmtCoins(min(r.bet * r.out!, r.you ? double.infinity : rocketBotCap.toDouble()))}')}'
                      : (phase == RocketPhase.crashed ? 'خسر' : '...'),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: r.out != null ? const Color(0xFF2EE59D) : (phase == RocketPhase.crashed ? const Color(0xFFFF6B6B) : Colors.white54),
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _controls() {
    final canCash = phase == RocketPhase.flying && _myBet > 0 && _myOut == null;
    Widget main;
    if (canCash) {
      main = CoinActionButton(
        key: const ValueKey('rocket-cashout'),
        label: 'اسحب ${fmtCoins((_myBet * _mult + 1e-6).floor())}',
        color: const Color(0xFF2EE59D),
        onTap: _cashOut,
      );
    } else if ((phase == RocketPhase.waiting && _myBet > 0) || _queued > 0) {
      main = CoinActionButton(
        key: const ValueKey('rocket-cancel'),
        label: 'إلغاء الرهان',
        sub: _queued > 0 ? 'محجوز للجولة الجاية' : 'رهانك ${fmtCoins(_myBet)}',
        color: const Color(0xFFFF8A8A),
        onTap: _cancel,
      );
    } else {
      main = CoinActionButton(
        key: const ValueKey('rocket-bet'),
        label: phase == RocketPhase.waiting ? 'راهن ${fmtCoins(_chip)}' : 'راهن للجولة الجاية',
        onTap: _placeBet,
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('سحب تلقائي', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final a in const [null, 1.5, 2.0, 3.0, 5.0, 10.0])
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            key: ValueKey('auto-${a ?? 'off'}'),
                            label: Text(a == null ? 'إيقاف' : fmtMult(a), style: const TextStyle(fontWeight: FontWeight.w800)),
                            selected: _auto == a,
                            onSelected: _myBet > 0 && phase != RocketPhase.crashed ? null : (_) => setState(() => _auto = a),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        BetChips(value: _chip, enabled: _myBet == 0 || phase == RocketPhase.crashed, onChanged: (v) => setState(() => _chip = v)),
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 14), child: main),
      ],
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.phase, required this.elapsed, required this.now});
  final RocketPhase phase;
  final double elapsed;
  final double now;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF070A2A), Color(0xFF241A6B), Color(0xFF4B2A8F)],
        ).createShader(Offset.zero & size),
    );
    // نجوم تتحرك للأسفل أثناء الطيران.
    final star = Paint()..color = Colors.white;
    final rnd = Random(3);
    final drift = phase == RocketPhase.flying ? elapsed * 40 : 0.0;
    for (var i = 0; i < 60; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = (rnd.nextDouble() * size.height + drift * (.5 + rnd.nextDouble())) % size.height;
      final tw = .3 + .7 * (0.5 + 0.5 * sin(now * 2 + i));
      canvas.drawCircle(Offset(x, y), rnd.nextDouble() * 1.4 + .4, star..color = Colors.white.withValues(alpha: tw * .8));
    }
    if (phase == RocketPhase.waiting) {
      _rocket(canvas, Offset(size.width * .12, size.height * .86), -pi / 4, 1);
      return;
    }
    // منحنى الصعود: المحور الأفقي زمن، والعمودي المضاعف (يتمدد مع الوقت).
    final span = max(8.0, elapsed * 1.15);
    final maxM = max(2.0, rocketMultAt(span));
    Offset at(double s) {
      final m = rocketMultAt(s);
      return Offset(
        size.width * (.08 + .8 * s / span),
        size.height * (.9 - .78 * (m - 1) / (maxM - 1)),
      );
    }

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    const n = 60;
    for (var i = 1; i <= n; i++) {
      final p = at(elapsed * i / n);
      path.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(path)
      ..lineTo(at(elapsed).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();
    final crashed = phase == RocketPhase.crashed;
    canvas.drawPath(fill, Paint()..color = (crashed ? const Color(0xFFFF5A5F) : const Color(0xFF2EE59D)).withValues(alpha: .15));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = crashed ? const Color(0xFFFF5A5F) : const Color(0xFF2EE59D),
    );
    final tip = at(elapsed);
    final before = at(max(0, elapsed - .3));
    final ang = atan2(tip.dy - before.dy, tip.dx - before.dx);
    if (!crashed) _rocket(canvas, tip, ang, 1);
  }

  void _rocket(Canvas canvas, Offset p, double ang, double s) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(ang);
    // لهب
    final flame = Path()
      ..moveTo(-14, -5)
      ..lineTo(-26 - 6 * sin(now * 30).abs(), 0)
      ..lineTo(-14, 5)
      ..close();
    canvas.drawPath(flame, Paint()..color = const Color(0xFFFFB13D));
    // جسم
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -7, 26, 14), const Radius.circular(7));
    canvas.drawRRect(body, Paint()..color = const Color(0xFFF2F4FF));
    final nose = Path()
      ..moveTo(8, -7)
      ..quadraticBezierTo(22, 0, 8, 7)
      ..close();
    canvas.drawPath(nose, Paint()..color = const Color(0xFFFF4D6D));
    final fin = Path()
      ..moveTo(-14, -7)
      ..lineTo(-20, -13)
      ..lineTo(-8, -7)
      ..moveTo(-14, 7)
      ..lineTo(-20, 13)
      ..lineTo(-8, 7);
    canvas.drawPath(fin, Paint()..color = const Color(0xFFFF4D6D));
    canvas.drawCircle(const Offset(0, 0), 3.5, Paint()..color = const Color(0xFF3DB8FF));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkyPainter old) => true;
}
