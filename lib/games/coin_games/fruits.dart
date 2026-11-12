import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/haptics.dart';
import '../../core/rounds/shared_rounds.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import 'coin_ui.dart';

class FruitSlot {
  const FruitSlot(this.emoji, this.name, this.mult, this.color);
  final String emoji;
  final String name;
  final int mult;
  final Color color;
}

/// الفواكه الثمانية بترتيب الدائرة (مع عقارب الساعة).
const fruitSlots = [
  FruitSlot('🍒', 'كرز', 5, Color(0xFFFF4D6D)),
  FruitSlot('🍉', 'بطيخ', 10, Color(0xFF2EE59D)),
  FruitSlot('🍋', 'ليمون', 5, Color(0xFFFFD84D)),
  FruitSlot('🍍', 'أناناس', 15, Color(0xFFFFB13D)),
  FruitSlot('🍇', 'عنب', 5, Color(0xFF9B6BFF)),
  FruitSlot('🥭', 'مانجو', 25, Color(0xFFFF8A3D)),
  FruitSlot('🍊', 'برتقال', 5, Color(0xFFFF9F1C)),
  FruitSlot('🍓', 'فراولة', 45, Color(0xFFFF2E63)),
];

/// احتمال كل فاكهة يتناسب عكسياً مع مضاعفها، فالعائد المتوقع ≈97% لكل فاكهة.
List<double> fruitChances() {
  final w = [for (final f in fruitSlots) 1 / f.mult];
  final sum = w.reduce((a, b) => a + b);
  return [for (final x in w) x / sum];
}

int pickFruit(Random r) {
  final c = fruitChances();
  var x = r.nextDouble();
  for (var i = 0; i < c.length; i++) {
    x -= c[i];
    if (x < 0) return i;
  }
  return c.length - 1;
}

enum FruitPhase { betting, spinning, result }

/// سوق الفواكه: راهن على الفاكهة اللي تتوقع يقف عندها المؤشر.
class FruitsScreen extends StatefulWidget {
  const FruitsScreen({super.key, this.betSeconds = 12, this.random, this.speed = 1.0});
  final int betSeconds;
  final Random? random;

  /// معامل سرعة الحركة (أصغر = أسرع، للاختبارات).
  final double speed;

  @override
  State<FruitsScreen> createState() => _FruitsScreenState();
}

/// موقع كل فاكهة في شبكة 3×3 (الوسط للعداد).
const _ringCells = [0, 1, 2, 5, 8, 7, 6, 3];

/// جولات الفواكه الموحدة: 12 ثانية رهان، والباقي للدوران والنتيجة.
const fruitRounds = FixedRounds(20000);
const fruitBetMs = 12000;

/// الفاكهة الفائزة في جولة موحدة (نفسها على كل الأجهزة).
int fruitWinnerFor(int round) => pickFruit(roundRng('fruits', round, 'win'));

class _FruitsScreenState extends State<FruitsScreen> {
  bool get _synced => widget.random == null;
  int _round = 0;
  Timer? _wait;

  late final Random _rng = widget.random ?? Random();
  FruitPhase phase = FruitPhase.betting;
  late int _left = widget.betSeconds;
  Timer? _clock;
  int _chip = 100;
  final _bets = List.filled(fruitSlots.length, 0);
  List<int> _lastBets = List.filled(fruitSlots.length, 0);
  int _lit = 0;
  int? _winner;
  int _lastPay = 0;
  final List<int> _history = [];
  bool _disposed = false;

  int get _total => _bets.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    if (_synced) {
      _round = fruitRounds.current;
      _history.addAll([for (var r = _round - 1; r > _round - 13; r--) fruitWinnerFor(r)]);
      if (fruitRounds.elapsedMs >= fruitBetMs) {
        // دخلت بعد ما قفل الرهان: نعرض نتيجة الجولة وننتظر الجاية
        phase = FruitPhase.result;
        _winner = fruitWinnerFor(_round);
        _lit = _winner!;
        _waitNext();
        return;
      }
    }
    _startRound();
  }

  void _waitNext() {
    _wait?.cancel();
    final ms = (fruitRounds.startOf(_round + 1) - SharedClock.nowMs()).clamp(0, 30000);
    _wait = Timer(Duration(milliseconds: ms), () {
      if (_disposed) return;
      _round = fruitRounds.current;
      _startRound();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _clock?.cancel();
    _wait?.cancel();
    super.dispose();
  }

  void _startRound() {
    setState(() {
      phase = FruitPhase.betting;
      _left = widget.betSeconds;
      _winner = null;
      _lastPay = 0;
    });
    _clock?.cancel();
    if (_synced) {
      int leftNow() => ((fruitRounds.startOf(_round) + fruitBetMs - SharedClock.nowMs()) / 1000).ceil();
      _left = leftNow().clamp(0, 99);
      _clock = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (_disposed) return;
        final l = leftNow();
        if (l != _left) {
          setState(() => _left = l.clamp(0, 99));
          if (_left <= 3 && _left > 0) Sfx.instance.tick();
        }
        if (l <= 0) {
          _clock?.cancel();
          _spin();
        }
      });
      return;
    }
    _clock = Timer.periodic(Duration(milliseconds: (1000 * widget.speed).round().clamp(1, 1000)), (_) {
      if (_disposed) return;
      setState(() => _left--);
      if (_left <= 3 && _left > 0) Sfx.instance.tick();
      if (_left <= 0) {
        _clock?.cancel();
        _spin();
      }
    });
  }

  void _bet(int i) {
    if (phase != FruitPhase.betting) {
      coinToast(context, 'انتظر الجولة الجاية للرهان');
      return;
    }
    if (!takeBet(context, _chip)) return;
    Haptics.selectionClick();
    setState(() => _bets[i] += _chip);
  }

  void _clear() {
    if (phase != FruitPhase.betting || _total == 0) return;
    Account.instance.earn(_total);
    setState(() => _bets.fillRange(0, _bets.length, 0));
  }

  void _repeat() {
    if (phase != FruitPhase.betting) return;
    final need = _lastBets.fold(0, (a, b) => a + b);
    if (need == 0) return;
    if (!takeBet(context, need)) return;
    setState(() {
      for (var i = 0; i < _bets.length; i++) {
        _bets[i] += _lastBets[i];
      }
    });
  }

  Future<void> _spin() async {
    final win = _synced ? fruitWinnerFor(_round) : pickFruit(_rng);
    setState(() => phase = FruitPhase.spinning);
    // ثلاث لفات كاملة ثم التوقف عند الفائز، مع تباطؤ تدريجي.
    final steps = 3 * 8 + ((win - _lit) % 8 + 8) % 8;
    for (var s = 1; s <= steps; s++) {
      final t = s / steps;
      final ms = (45 + 330 * t * t * t) * widget.speed;
      await Future.delayed(Duration(milliseconds: ms.round()));
      if (_disposed) return;
      setState(() => _lit = (_lit + 1) % 8);
      Sfx.instance.tick();
    }
    final pay = _bets[win] * fruitSlots[win].mult;
    final total = _total;
    if (pay > 0) {
      Account.instance.earn(pay);
      Sfx.instance.win();
      Haptics.heavyImpact();
    } else if (total > 0) {
      Sfx.instance.lose();
    }
    if (total > 0) Account.instance.recordCoinRound('fruits', bet: total, won: pay);
    setState(() {
      phase = FruitPhase.result;
      _winner = win;
      _lastPay = pay;
      _history.insert(0, win);
      if (_history.length > 12) _history.removeLast();
      if (total > 0) _lastBets = List.of(_bets);
      _bets.fillRange(0, _bets.length, 0);
    });
    if (_synced) {
      _waitNext();
      return;
    }
    await Future.delayed(Duration(milliseconds: (3200 * widget.speed).round()));
    if (_disposed) return;
    _startRound();
  }

  @override
  Widget build(BuildContext context) {
    return CoinGameScaffold(
      title: 'سوق الفواكه',
      colors: const [Color(0xFF0E7A55), Color(0xFF145C4A)],
      inPlay: _total > 0 && phase != FruitPhase.result,
      onHelp: () => showHowTo(
        context,
        'سوق الفواكه',
        'اختر قيمة الرقاقة ثم اضغط على الفاكهة اللي تتوقع يقف عندها المؤشر. '
            'تقدر تراهن على أكثر من فاكهة. لما يخلص العداد يلف المؤشر، '
            'ولو وقف على فاكهتك تربح رهانك مضروب في رقمها.\n\n'
            'كل ما كان المضاعف أعلى كانت الفاكهة أندر: الفراولة ×45 تطلع تقريباً مرة كل 46 جولة، والكرز ×5 تقريباً مرة كل 5 جولات.',
      ),
      child: Column(
        children: [
          _historyRow(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Center(child: AspectRatio(aspectRatio: 1, child: _board())),
            ),
          ),
          BetChips(value: _chip, enabled: phase == FruitPhase.betting, onChanged: (v) => setState(() => _chip = v)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('fruit-clear'),
                    onPressed: phase == FruitPhase.betting && _total > 0 ? _clear : null,
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('مسح', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('fruit-repeat'),
                    onPressed: phase == FruitPhase.betting && _lastBets.any((b) => b > 0) ? _repeat : null,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('كرر رهاني', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyRow() => SizedBox(
    height: 40,
    child: Row(
      children: [
        const SizedBox(width: 14),
        Text('آخر النتائج', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (i, h) in _history.indexed)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  width: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: i == 0 ? .45 : .25),
                    shape: BoxShape.circle,
                    border: i == 0 ? Border.all(color: AppColors.gold, width: 2) : null,
                  ),
                  child: Text(fruitSlots[h].emoji, style: const TextStyle(fontSize: 17)),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _board() => GridView.count(
    crossAxisCount: 3,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    physics: const NeverScrollableScrollPhysics(),
    children: [
      for (var cell = 0; cell < 9; cell++)
        cell == 4 ? _center() : _tile(_ringCells.indexOf(cell)),
    ],
  );

  Widget _center() {
    final Widget inner;
    if (phase == FruitPhase.betting) {
      inner = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('راهن الآن', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800, fontSize: 13)),
          Text('$_left', key: const ValueKey('fruit-timer'), style: AppTheme.display.copyWith(fontSize: 44, color: _left <= 3 ? const Color(0xFFFF7A7A) : Colors.white)),
          if (_total > 0)
            Text('رهانك ${fmtCoins(_total)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.gold)),
        ],
      );
    } else if (phase == FruitPhase.spinning) {
      inner = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(fruitSlots[_lit].emoji, style: const TextStyle(fontSize: 46)),
          const Text('...', style: TextStyle(fontWeight: FontWeight.w900)),
        ],
      );
    } else {
      final f = fruitSlots[_winner!];
      inner = Column(
        key: const ValueKey('fruit-result'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(f.emoji, style: const TextStyle(fontSize: 40)),
          if (_lastPay > 0)
            FittedBox(
              child: Text('+${fmtCoins(_lastPay)}', style: AppTheme.display.copyWith(fontSize: 30, color: AppColors.gold)),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut)
          else
            Text('${f.name} ${ltr('×${f.mult}')}', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      );
    }
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: .35),
        border: Border.all(color: AppColors.gold.withValues(alpha: .6), width: 3),
      ),
      child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.all(8), child: inner)),
    );
  }

  Widget _tile(int i) {
    final f = fruitSlots[i];
    final lit = phase == FruitPhase.spinning && _lit == i;
    final won = phase == FruitPhase.result && _winner == i;
    final bet = _bets[i];
    return GestureDetector(
      key: ValueKey('fruit-$i'),
      onTap: () => _bet(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [f.color.withValues(alpha: lit || won ? .95 : .45), f.color.withValues(alpha: lit || won ? .6 : .18)],
          ),
          border: Border.all(color: lit || won ? Colors.white : Colors.white24, width: lit || won ? 3.5 : 1.5),
          boxShadow: lit || won ? [BoxShadow(color: f.color.withValues(alpha: .8), blurRadius: 22, spreadRadius: 2)] : null,
        ),
        child: Stack(
          children: [
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(f.emoji, style: const TextStyle(fontSize: 44)),
                    Text(ltr('×${f.mult}'), style: AppTheme.display.copyWith(fontSize: 22)),
                  ],
                ),
              ),
            ),
            if (bet > 0)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
                  child: Text(fmtCoins(bet), style: const TextStyle(color: Color(0xFF4A2600), fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    ).animate(target: won ? 1 : 0).scaleXY(end: 1.06, duration: 300.ms);
  }
}
