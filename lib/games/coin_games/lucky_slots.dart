import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/haptics.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import 'coin_ui.dart';
import 'slot_reels.dart';

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

  int get _bet => classicBets[_betIndex];

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
    final cols = [
      for (var i = 0; i < 3; i++) [pickClassic(_rng), pickClassic(_rng), pickClassic(_rng)],
    ];
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
      if (mult >= 4) {
        Sfx.instance.win();
        Haptics.heavyImpact();
      }
    }
    Account.instance.recordCoinRound('lucky_slots', bet: bet, won: won);
    setState(() {
      _spinning = false;
      _lastWin = won;
      _lastMult = mult;
    });
    if (_auto) {
      await Future.delayed(Duration(milliseconds: ((mult >= 10 ? 1400 : 450) * widget.speed).round()));
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
    return CoinGameScaffold(
      title: 'ماكينة الحظ',
      colors: const [Color(0xFF8A0F1E), Color(0xFF3A0710)],
      inPlay: _spinning,
      onHelp: _paytable,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _marquee(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
              child: Center(child: AspectRatio(aspectRatio: .95, child: _machine())),
            ),
          ),
          _winBar(),
          _controls(),
        ],
      ),
    );
  }

  Widget _marquee() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < 7; i++)
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFE07A)),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fadeOut(delay: (i * 90).ms, duration: 500.ms, begin: 1),
    ],
  );

  Widget _machine() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE8E8EE), Color(0xFF9EA2AE), Color(0xFFD9DBE3)],
      ),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8))],
    ),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFB3121F),
        border: Border.all(color: const Color(0xFF5E0910), width: 3),
      ),
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
                colors: [Color(0xFF9097A6), Colors.white, Colors.white, Color(0xFF9097A6)],
                stops: [0, .25, .75, 1],
              ),
            ),
          ),
          // خط الربح في الوسط
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(height: 3, color: const Color(0xFFFFC93C).withValues(alpha: .85)),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _winBar() => SizedBox(
    height: 40,
    child: Center(
      child: _lastWin > 0
          ? Text(
              'ربحت ${fmtCoins(_lastWin)}  ${ltr('×$_lastMult')}',
              key: const ValueKey('slots-win'),
              style: AppTheme.display.copyWith(fontSize: 24, color: AppColors.gold),
            ).animate().scale(duration: 350.ms, curve: Curves.elasticOut)
          : Text(
              _spinning ? 'بالتوفيق...' : 'اضغط لف وجرب حظك',
              style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800),
            ),
    ),
  );

  Widget _controls() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
    child: Column(
      children: [
        Row(
          children: [
            _round('slots-minus', Icons.remove_rounded, !_spinning && _betIndex > 0 ? () => setState(() => _betIndex--) : null),
            Expanded(
              child: Container(
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withValues(alpha: .5)),
                ),
                child: Text('الرهان ${fmtCoins(_bet)}', key: const ValueKey('slots-bet'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              ),
            ),
            _round('slots-plus', Icons.add_rounded, !_spinning && _betIndex < classicBets.length - 1 ? () => setState(() => _betIndex++) : null),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _toggle('slots-fast', '⚡ سريع', _fast, () => setState(() => _fast = !_fast)),
            const SizedBox(width: 8),
            Expanded(
              child: CoinActionButton(
                key: const ValueKey('slots-spin'),
                label: _spinning ? '...' : 'لف 🎰',
                color: const Color(0xFFFFC93C),
                onTap: _spinning || _auto ? null : _spin,
              ),
            ),
            const SizedBox(width: 8),
            _toggle('slots-auto', _auto ? '⏹ وقف' : '🔁 تلقائي', _auto, _toggleAuto),
          ],
        ),
      ],
    ),
  );

  Widget _round(String key, IconData icon, VoidCallback? onTap) => IconButton.filled(
    key: ValueKey(key),
    onPressed: onTap,
    style: IconButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: const Color(0xFF4A2600)),
    icon: Icon(icon),
  );

  Widget _toggle(String key, String label, bool on, VoidCallback onTap) => SizedBox(
    width: 78,
    height: 60,
    child: OutlinedButton(
      key: ValueKey(key),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: on ? AppColors.gold.withValues(alpha: .25) : null,
        side: BorderSide(color: on ? AppColors.gold : Colors.white24, width: on ? 2 : 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onTap,
      child: FittedBox(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
    ),
  );
}
