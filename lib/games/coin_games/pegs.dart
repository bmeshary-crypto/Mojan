import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/account/account.dart';
import '../../core/haptics.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import 'coin_ui.dart';

const pegRows = 16;

/// مستوى المخاطرة يحدد جدول المضاعفات في الخانات السفلية (17 خانة).
enum PegRisk {
  low('منخفض', [16, 9, 2, 1.4, 1.4, 1.2, 1.1, 1, 0.4, 1, 1.1, 1.2, 1.4, 1.4, 2, 9, 16]),
  mid('متوسط', [110, 41, 10, 5, 3, 1.5, 1, 0.5, 0.2, 0.5, 1, 1.5, 3, 5, 10, 41, 110]),
  high('عالي', [1000, 130, 26, 8, 4, 2, 0.2, 0.2, 0.2, 0.2, 0.2, 2, 4, 8, 26, 130, 1000]);

  const PegRisk(this.label, this.slots);
  final String label;
  final List<double> slots;

  /// العائد المتوقع (توزيع ثنائي: كل مسمار يميل يمين أو يسار بالتساوي).
  double get rtp {
    var sum = 0.0;
    var c = 1.0;
    for (var k = 0; k <= pegRows; k++) {
      sum += c * slots[k];
      c = c * (pegRows - k) / (k + 1);
    }
    return sum / pow(2, pegRows);
  }
}

class _Ball {
  _Ball(this.path, this.bet, this.start);
  final List<bool> path;
  final int bet;
  final Duration start;
  bool settled = false;
  int get slot => path.where((r) => r).length;
}

/// هرم المسامير: كرة تنزل بين المسامير وتقع في خانة مضاعف.
class PegsScreen extends StatefulWidget {
  const PegsScreen({super.key, this.random, this.rowMs = 110});
  final Random? random;

  /// زمن نزول الكرة صفاً واحداً.
  final int rowMs;

  @override
  State<PegsScreen> createState() => _PegsScreenState();
}

class _PegsScreenState extends State<PegsScreen> with SingleTickerProviderStateMixin {
  late final Random _rng = widget.random ?? Random();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _now = Duration.zero;
  PegRisk _risk = PegRisk.mid;
  int _chip = 100;
  final List<_Ball> _balls = [];
  final List<(int slot, double mult, Duration at)> _hits = [];
  final List<double> _history = [];
  int _lastWin = 0;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// مسارات الكرات الجاية محسوبة مسبقاً (الأدمن يشوفها).
  final List<List<bool>> _queue = [];

  List<List<bool>> get _upcoming {
    _fill();
    return _queue;
  }

  void _fill() {
    while (_queue.length < 8) {
      _queue.add([for (var i = 0; i < pegRows; i++) _rng.nextBool()]);
    }
  }

  List<bool> _takeNext() {
    _fill();
    final p = _queue.removeAt(0);
    _fill();
    return p;
  }

  Duration get _fall => Duration(milliseconds: widget.rowMs * (pegRows + 1));

  void _drop() {
    if (_balls.length >= 12) return;
    if (!takeBet(context, _chip)) return;
    Haptics.lightImpact();
    Sfx.instance.tap();
    final path = _takeNext();
    final start = _ticker.isActive ? _now : Duration.zero;
    if (!_ticker.isActive) {
      _now = Duration.zero;
      _ticker.start();
    }
    setState(() => _balls.add(_Ball(path, _chip, start)));
  }

  void _onTick(Duration t) {
    _now = t;
    for (final b in _balls) {
      if (!b.settled && t - b.start >= _fall) {
        b.settled = true;
        final m = _risk.slots[b.slot];
        final pay = (b.bet * m).floor();
        Account.instance.earn(pay);
        Account.instance.recordCoinRound('pegs', bet: b.bet, won: pay);
        _hits.add((b.slot, m, t));
        _history.insert(0, m);
        if (_history.length > 10) _history.removeLast();
        _lastWin = pay;
        if (m >= 10) {
          Sfx.instance.win();
          Haptics.heavyImpact();
        } else {
          Sfx.instance.tone(m >= 1 ? 880 : 330, m >= 1 ? 1320 : 260, .12, type: 'triangle', vol: .12);
        }
      }
    }
    _balls.removeWhere((b) => b.settled);
    _hits.removeWhere((h) => t - h.$3 > const Duration(milliseconds: 600));
    if (_balls.isEmpty && _hits.isEmpty) _ticker.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final busy = _balls.isNotEmpty;
    return CoinGameScaffold(
      title: 'هرم المسامير',
      colors: const [Color(0xFF1F3B8F), Color(0xFF162A66)],
      inPlay: busy,
      leaveMessage: 'في كرات لسه نازلة، استنى توصل قبل ما تخرج.',
      onHelp: () => showHowTo(
        context,
        'هرم المسامير',
        'اختر الرهان واضغط "أسقط الكرة". الكرة تنزل وتصطدم بالمسامير يميناً ويساراً '
            'لين تقع في خانة تحت، وتربح رهانك مضروب في رقم الخانة.\n\n'
            'الخانات اللي على الأطراف أعلى بكثير لكنها نادرة جداً. '
            'في المخاطرة العالية توصل لـ ×1000 (فرصتها تقريباً مرة من كل 32 ألف كرة)، والوسط يرجّع جزء من الرهان. '
            'تقدر تسقط أكثر من كرة مع بعض.',
      ),
      child: Column(
        children: [
          AdminUpcoming(
            items: [
              for (final path in _upcoming)
                () {
                  final m = _risk.slots[path.where((r) => r).length];
                  return adminChip(fmtMult(m), color: m >= 10 ? AppColors.gold : (m >= 1 ? const Color(0xFF2EE59D) : const Color(0xFFFF7A7A)));
                }(),
            ],
          ),
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
                    decoration: BoxDecoration(color: _slotColor(m).withValues(alpha: .8), borderRadius: BorderRadius.circular(10)),
                    child: Text(fmtMult(m), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: LayoutBuilder(
                builder: (context, c) => CustomPaint(
                  key: const ValueKey('pegs-board'),
                  size: Size(c.maxWidth, c.maxHeight),
                  painter: _PegsPainter(
                    risk: _risk,
                    balls: _balls,
                    now: _now,
                    rowMs: widget.rowMs,
                    hits: _hits,
                  ),
                ),
              ),
            ),
          ),
          if (_lastWin > 0 || _history.isNotEmpty)
            Text(
              'آخر كرة: ${fmtCoins(_lastWin)}',
              key: const ValueKey('pegs-last'),
              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SegmentedButton<PegRisk>(
              segments: [for (final r in PegRisk.values) ButtonSegment(value: r, label: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w800)))],
              selected: {_risk},
              showSelectedIcon: false,
              onSelectionChanged: busy ? null : (s) => setState(() => _risk = s.first),
            ),
          ),
          BetChips(value: _chip, onChanged: (v) => setState(() => _chip = v)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: CoinActionButton(
              key: const ValueKey('pegs-drop'),
              label: 'أسقط الكرة',
              sub: 'الرهان ${fmtCoins(_chip)}',
              onTap: _drop,
            ),
          ),
        ],
      ),
    );
  }
}

Color _slotColor(double m) => m >= 100
    ? const Color(0xFFFF2E63)
    : m >= 10
    ? const Color(0xFFFF7A3D)
    : m >= 2
    ? const Color(0xFFFFB13D)
    : m >= 1
    ? const Color(0xFFE0C341)
    : const Color(0xFF6B7BD9);

class _PegsPainter extends CustomPainter {
  _PegsPainter({required this.risk, required this.balls, required this.now, required this.rowMs, required this.hits});
  final PegRisk risk;
  final List<_Ball> balls;
  final Duration now;
  final int rowMs;
  final List<(int, double, Duration)> hits;

  @override
  void paint(Canvas canvas, Size size) {
    final slots = pegRows + 1;
    final sp = size.width / (slots + 0.4);
    final slotH = min(30.0, sp * 1.1);
    final rowH = min(sp * .95, (size.height - slotH - 16) / (pegRows + 0.5));
    final top = (size.height - slotH - rowH * (pegRows + 0.5)) / 2 + rowH * .4;
    final cx = size.width / 2;
    final pegR = max(1.6, sp * .09);

    // المسامير: الصف r فيه r+3 مسامير.
    final peg = Paint()..color = Colors.white.withValues(alpha: .85);
    for (var r = 0; r < pegRows; r++) {
      final n = r + 3;
      for (var i = 0; i < n; i++) {
        canvas.drawCircle(Offset(cx + (i - (n - 1) / 2) * sp, top + r * rowH), pegR, peg);
      }
    }

    // الخانات.
    final slotTop = top + (pegRows - 0.3) * rowH + rowH * .5;
    for (var k = 0; k < slots; k++) {
      final m = risk.slots[k];
      final hit = hits.any((h) => h.$1 == k);
      final x = cx + (k - pegRows / 2) * sp;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, slotTop + slotH / 2 + (hit ? 4 : 0)), width: sp * .92, height: slotH),
        const Radius.circular(5),
      );
      canvas.drawRRect(rect, Paint()..color = _slotColor(m).withValues(alpha: hit ? 1 : .85));
      final tp = TextPainter(
        text: TextSpan(
          text: m >= 100 ? '${m.round()}' : (m == m.roundToDouble() ? '${m.round()}' : '$m'),
          style: TextStyle(fontSize: min(11, sp * .34), fontWeight: FontWeight.w900, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: sp);
      tp.paint(canvas, Offset(x - tp.width / 2, slotTop + slotH / 2 - tp.height / 2 + (hit ? 4 : 0)));
    }

    // الكرات.
    final ballPaint = Paint()
      ..shader = const RadialGradient(colors: [Color(0xFFFFF3B0), AppColors.goldDeep]).createShader(Rect.fromCircle(center: Offset.zero, radius: 8));
    for (final b in balls) {
      final t = (now - b.start).inMicroseconds / 1000 / rowMs;
      final row = t.floor().clamp(0, pegRows);
      final f = (t - row).clamp(0.0, 1.0);
      double offAt(int k) {
        var rights = 0;
        for (var i = 0; i < k; i++) {
          if (b.path[i]) rights++;
        }
        return (rights - k / 2) * sp;
      }

      final x0 = offAt(row);
      final x1 = row < pegRows ? offAt(row + 1) : x0;
      final x = cx + x0 + (x1 - x0) * f;
      final y = top - rowH * .55 + row * rowH + rowH * f * f - sin(f * pi) * rowH * .25;
      final r = max(3.5, sp * .2);
      canvas.save();
      canvas.translate(x, y);
      canvas.drawCircle(Offset.zero, r, ballPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PegsPainter old) => true;
}
