import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/account/account.dart';
import '../../core/haptics.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import 'coin_ui.dart';
import 'slot_reels.dart';
import 'slot_shell.dart';
import 'win_fx.dart';

class ClassicSymbol {
  const ClassicSymbol(this.id, this.name, this.emoji, this.weight, this.three);
  final String id;
  final String name;
  final String emoji;

  /// وزن الرمز في كل بكرة (الأندر أعلى ربح).
  final int weight;

  /// ربح ثلاثة متطابقة على الخط (مضروب في الرهان).
  final int three;
}

const classicSymbols = [
  ClassicSymbol('seven', 'سبعة', '7️⃣', 1, 100),
  ClassicSymbol('bar', 'بار', '🟫', 2, 40),
  ClassicSymbol('bell', 'جرس', '🔔', 3, 20),
  ClassicSymbol('grape', 'عنب', '🍇', 4, 12),
  ClassicSymbol('orange', 'برتقال', '🍊', 5, 8),
  ClassicSymbol('cherry', 'كرز', '🍒', 5, 6),
];

ClassicSymbol classicById(String id) => classicSymbols.firstWhere((s) => s.id == id);

String pickClassic(Random r) {
  final total = classicSymbols.fold(0, (a, s) => a + s.weight);
  var x = r.nextInt(total);
  for (final s in classicSymbols) {
    x -= s.weight;
    if (x < 0) return s.id;
  }
  return classicSymbols.last.id;
}

/// مضاعف الربح لخط الوسط.
/// ثلاثة متطابقة = جدول الأرباح. كرزة في البكرة الأولى = ×1، ومعها كرزة ثانية = ×4.
int classicPay(List<String> line) {
  if (line[0] == line[1] && line[1] == line[2]) return classicById(line[0]).three;
  if (line[0] != 'cherry') return 0;
  return line.where((s) => s == 'cherry').length == 2 ? 4 : 1;
}

/// العائد المتوقع محسوب بدقة من الأوزان (≈95%).
double classicRtp() {
  final total = classicSymbols.fold(0, (a, s) => a + s.weight);
  var sum = 0.0;
  for (final a in classicSymbols) {
    for (final b in classicSymbols) {
      for (final c in classicSymbols) {
        sum += a.weight * b.weight * c.weight * classicPay([a.id, b.id, c.id]);
      }
    }
  }
  return sum / pow(total, 3);
}

const classicBets = [10, 50, 100, 200, 500, 1000, 5000];

/// ماكينة الحظ: ثلاث بكرات كلاسيكية وخط واحد في الوسط.
class LuckySlotsScreen extends StatefulWidget {
  const LuckySlotsScreen({super.key, this.random, this.speed = 1.0});
  final Random? random;
  final double speed;

  @override
  State<LuckySlotsScreen> createState() => _LuckySlotsScreenState();
}

class _LuckySlotsScreenState extends State<LuckySlotsScreen> {
  late final Random _rng = widget.random ?? Random();
  final _reels = SlotReelsController();
  late final List<List<String>> _initial = [
    for (var i = 0; i < 3; i++) [pickClassic(_rng), pickClassic(_rng), pickClassic(_rng)],
  ];
  int _betIndex = 2;
  bool _spinning = false;
  bool _fast = false;
  bool _auto = false;
  int _lastWin = 0;
  int _lastMult = 0;
  bool _disposed = false;
  int _winKey = 0;

  int get _bet => classicBets[_betIndex];

  /// النتائج محسوبة مسبقاً بالترتيب (الأدمن يشوفها).
  final List<List<List<String>>> _queue = [];

  List<List<List<String>>> get _upcoming {
    _fill();
    return _queue;
  }

  void _fill() {
    while (_queue.length < 8) {
      _queue.add([
        for (var i = 0; i < 3; i++) [pickClassic(_rng), pickClassic(_rng), pickClassic(_rng)],
      ]);
    }
  }

  List<List<String>> _takeNext() {
    _fill();
    final c = _queue.removeAt(0);
    _fill();
    return c;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning) return;
    if (!takeBet(context, _bet)) {
      setState(() => _auto = false);
      return;
    }
    Haptics.selectionClick();
    final bet = _bet;
    final cols = _takeNext();
    setState(() {
      _spinning = true;
      _lastWin = 0;
      _lastMult = 0;
    });
    final base = _fast ? 260 : 700;
    final step = _fast ? 120 : 330;
    await _reels.spin(
      cols,
      filler: () => pickClassic(_rng),
      stopMs: [for (var i = 0; i < 3; i++) ((base + i * step) * widget.speed).round().clamp(1, 99999)],
    );
    if (_disposed) return;
    final mult = classicPay([cols[0][1], cols[1][1], cols[2][1]]);
    final won = bet * mult;
    if (won > 0) {
      Account.instance.earn(won);
      Haptics.heavyImpact();
      if (winTier(mult.toDouble()) != null && mounted) {
        unawaited(showBigWin(context, amount: won, mult: mult.toDouble(), hero: SizedBox(width: 110, height: 110, child: _symbol(cols[0][1]))));
      } else {
        Sfx.instance.lineWin();
        Sfx.instance.coins(mult >= 4 ? 8 : 4);
      }
    }
    _winKey++;
    Account.instance.recordCoinRound('lucky_slots', bet: bet, won: won);
    setState(() {
      _spinning = false;
      _lastWin = won;
      _lastMult = mult;
    });
    if (_auto) {
      await Future.delayed(Duration(milliseconds: ((winTier(mult.toDouble()) != null ? 3800 : (mult > 0 ? 900 : 450)) * widget.speed).round()));
      if (_disposed || !_auto) return;
      unawaited(_spin());
    }
  }

  void _toggleAuto() {
    setState(() => _auto = !_auto);
    if (_auto && !_spinning) _spin();
  }

  void _paytable() => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('جدول الأرباح', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in classicSymbols) _payRow([s.id, s.id, s.id], s.three),
            _payRow(['cherry', 'cherry'], 4),
            _payRow(['cherry'], 1),
            const SizedBox(height: 8),
            Text(
              'الربح على خط الوسط فقط، ويتضرب في رهانك. الكرز يحسب لو كان في البكرة الأولى.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.6),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تمام'))],
    ),
  );

  Widget _payRow(List<String> ids, int mult) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      textDirection: TextDirection.ltr,
      children: [
        for (final id in ids) SizedBox(width: 38, height: 38, child: _symbol(id)),
        const Spacer(),
        Text(ltr('×$mult'), style: AppTheme.display.copyWith(fontSize: 20, color: AppColors.gold)),
      ],
    ),
  );

  Widget _symbol(String id) {
    final s = classicById(id);
    return SymbolArt('assets/images/cl_$id.webp', fallback: s.emoji);
  }

  @override
  Widget build(BuildContext context) {
    return SlotShell(
      background: 'assets/images/bg_vegas.webp',
      logo: 'assets/images/logo_lucky.webp',
      title: 'ماكينة الحظ',
      accent: const Color(0xFF5A1080),
      keyPrefix: 'slots',
      inPlay: _spinning || _auto,
      bet: _bet,
      lastWin: _lastWin,
      spinning: _spinning,
      auto: _auto,
      fast: _fast,
      hint: '٧٧٧ تدفع ×100',
      onSpin: _spinning || _auto ? null : _spin,
      onAuto: _toggleAuto,
      onFast: () => setState(() => _fast = !_fast),
      onHelp: _paytable,
      onMinus: !_spinning && !_auto && _betIndex > 0 ? () => setState(() => _betIndex--) : null,
      onPlus: !_spinning && !_auto && _betIndex < classicBets.length - 1 ? () => setState(() => _betIndex++) : null,
      floating: _lastWin > 0 && !_spinning && winTier(_lastMult.toDouble()) == null ? FloatingWin(key: ValueKey('fw$_winKey'), amount: _lastWin) : null,
      header: AdminUpcoming(
        items: [
          for (final c in _upcoming)
            () {
              final m = classicPay([c[0][1], c[1][1], c[2][1]]);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) SizedBox(width: 16, height: 16, child: _symbol(c[i][1])),
                  adminChip(m > 0 ? ltr('×$m') : '—', color: m >= 8 ? AppColors.gold : Colors.white),
                ],
              );
            }(),
        ],
      ),
      machine: AspectRatio(aspectRatio: .78, child: _machine()),
    );
  }

  Widget _paytableStrip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF0A0420),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF7A3AFF), width: 1.5),
    ),
    child: Column(
      children: [
        for (final row in [classicSymbols.sublist(0, 3), classicSymbols.sublist(3)])
          Row(
            children: [
              for (final s in row)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var k = 0; k < 3; k++) SizedBox(width: 15, height: 15, child: _symbol(s.id)),
                      const SizedBox(width: 3),
                      Text(ltr('×${s.three}'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFFFE07A))),
                    ],
                  ),
                ),
            ],
          ),
      ],
    ),
  );

  Widget _machine() => MachineFrame(
    inner: const Color(0xFF7A0A18),
    lit: _lastMult > 0 && !_spinning,
    top: _paytableStrip(),
    child: Stack(
      children: [
        SlotReels(
          initial: _initial,
          rows: 3,
          controller: _reels,
          symbol: _symbol,
          highlight: !_spinning && _lastMult > 0 ? {(0, 1), (1, 1), (2, 1)} : const {},
          reelDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6A6E7A), Color(0xFFF4F4F8), Color(0xFFFFFFFF), Color(0xFFF4F4F8), Color(0xFF6A6E7A)],
              stops: [0, .2, .5, .8, 1],
            ),
          ),
        ),
        // خط الربح في الوسط مع سهمين
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Row(
                children: [
                  const Text('▶', style: TextStyle(color: Color(0xFFFFC93C), fontSize: 14)),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _lastMult > 0 && !_spinning ? 5 : 2.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC93C).withValues(alpha: .9),
                        boxShadow: _lastMult > 0 && !_spinning ? const [BoxShadow(color: Color(0xFFFFE04D), blurRadius: 12, spreadRadius: 2)] : null,
                      ),
                    ),
                  ),
                  const Text('◀', style: TextStyle(color: Color(0xFFFFC93C), fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
