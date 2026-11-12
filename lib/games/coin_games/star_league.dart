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

/// نادي خيالي (أسماء وشعارات من تصميمنا، بدون أي علامة تجارية حقيقية).
class StarClub {
  const StarClub(this.name, this.emoji, this.mult, this.c1, this.c2);
  final String name;
  final String emoji;
  final int mult;
  final Color c1;
  final Color c2;
}

const starClubs = [
  StarClub('النسور', '🦅', 5, Color(0xFF2F7BFF), Color(0xFF0B2A6B)),
  StarClub('الأسود', '🦁', 5, Color(0xFFFFC21A), Color(0xFFB3261E)),
  StarClub('الذئاب', '🐺', 5, Color(0xFF8C9AB0), Color(0xFF1E2A44)),
  StarClub('النمور', '🐯', 6, Color(0xFFFF8A1F), Color(0xFF2A1A0A)),
  StarClub('الخيول', '🐎', 10, Color(0xFFC98A4B), Color(0xFF4A2A12)),
  StarClub('القروش', '🦈', 15, Color(0xFF1FC6C9), Color(0xFF0A4048)),
  StarClub('الأفاعي', '🐍', 20, Color(0xFF3DDC6A), Color(0xFF0E2E18)),
  StarClub('الدببة', '🐻', 25, Color(0xFFB0413E), Color(0xFF3A0E12)),
  StarClub('الثعالب', '🦊', 50, Color(0xFFFF6A2B), Color(0xFFF2F2F2)),
  StarClub('الثيران', '🐂', 100, Color(0xFFE02424), Color(0xFFFFC93C)),
];

/// احتمال كل نادي يتناسب عكسياً مع مضاعفه، فالعائد ≈95% لأي نادي.
List<double> starChances() {
  final w = [for (final c in starClubs) 1 / c.mult];
  final sum = w.reduce((a, b) => a + b);
  return [for (final x in w) x / sum];
}

int pickStarClub(Random r) {
  final c = starChances();
  var x = r.nextDouble();
  for (var i = 0; i < c.length; i++) {
    x -= c[i];
    if (x < 0) return i;
  }
  return c.length - 1;
}

/// جولات موحدة: 15 ثانية رهان ثم الدوران والنتيجة.
const starRounds = FixedRounds(25000);
const starBetMs = 15000;
int starWinnerFor(int round) => pickStarClub(roundRng('star_league', round, 'win'));

/// الحلقة الخارجية: 20 خانة (7 فوق، 3 يمين، 7 تحت، 3 يسار) وكل نادي له خانتين.
const starRingCols = 7;
const starRingRows = 5;
const starRing = [0, 5, 2, 8, 1, 6, 3, 9, 4, 7, 1, 6, 3, 9, 0, 5, 2, 8, 4, 7];

/// موقع خانة الحلقة (عمود، صف) مع عقارب الساعة من أعلى اليسار.
(int, int) starRingCell(int i) {
  const c = starRingCols, r = starRingRows;
  if (i < c) return (i, 0);
  i -= c;
  if (i < r - 2) return (c - 1, i + 1);
  i -= r - 2;
  if (i < c) return (c - 1 - i, r - 1);
  i -= c;
  return (0, r - 2 - i);
}

const starChips = [100, 200, 500, 1000, 5000];

enum StarPhase { betting, spinning, result }

class StarLeagueScreen extends StatefulWidget {
  const StarLeagueScreen({super.key, this.betSeconds = 15, this.random, this.speed = 1.0});
  final int betSeconds;
  final Random? random;
  final double speed;

  @override
  State<StarLeagueScreen> createState() => _StarLeagueScreenState();
}

class _StarLeagueScreenState extends State<StarLeagueScreen> {
  bool get _synced => widget.random == null;
  int _round = 0;
  Timer? _wait;
  Timer? _clock;
  late final Random _rng = widget.random ?? Random();
  StarPhase phase = StarPhase.betting;
  late int _left = widget.betSeconds;
  int _chip = 100;
  final _bets = List.filled(starClubs.length, 0);
  List<int> _lastBets = List.filled(starClubs.length, 0);
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
      _round = starRounds.current;
      _history.addAll([for (var r = _round - 1; r > _round - 13; r--) starWinnerFor(r)]);
      if (starRounds.elapsedMs >= starBetMs) {
        phase = StarPhase.result;
        _winner = starWinnerFor(_round);
        _lit = _landingCell(_winner!, _round);
        _waitNext();
        return;
      }
    }
    _startRound();
  }

  /// أي خانة من خانتي النادي يقف عليها الضوء.
  int _landingCell(int club, int round) {
    final cells = [for (var i = 0; i < starRing.length; i++) if (starRing[i] == club) i];
    return cells[round % cells.length];
  }

  void _waitNext() {
    _wait?.cancel();
    final ms = (starRounds.startOf(_round + 1) - SharedClock.nowMs()).clamp(0, 30000);
    _wait = Timer(Duration(milliseconds: ms), () {
      if (_disposed) return;
      _round = starRounds.current;
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
      phase = StarPhase.betting;
      _left = widget.betSeconds;
      _winner = null;
      _lastPay = 0;
    });
    _clock?.cancel();
    if (_synced) {
      int leftNow() => ((starRounds.startOf(_round) + starBetMs - SharedClock.nowMs()) / 1000).ceil();
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
    if (phase != StarPhase.betting) {
      coinToast(context, 'انتظر الجولة الجاية للرهان');
      return;
    }
    if (!takeBet(context, _chip)) return;
    Haptics.selectionClick();
    setState(() => _bets[i] += _chip);
  }

  void _clear() {
    if (phase != StarPhase.betting || _total == 0) return;
    Account.instance.earn(_total);
    setState(() => _bets.fillRange(0, _bets.length, 0));
  }

  void _repeat() {
    if (phase != StarPhase.betting) return;
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
    final win = _synced ? starWinnerFor(_round) : pickStarClub(_rng);
    final land = _landingCell(win, _synced ? _round : _rng.nextInt(2));
    setState(() => phase = StarPhase.spinning);
    final n = starRing.length;
    final steps = 2 * n + ((land - _lit) % n + n) % n;
    for (var s = 1; s <= steps; s++) {
      final t = s / steps;
      final ms = (35 + 300 * t * t * t) * widget.speed;
      await Future.delayed(Duration(milliseconds: ms.round()));
      if (_disposed) return;
      setState(() => _lit = (_lit + 1) % n);
      Sfx.instance.tick();
    }
    final pay = _bets[win] * starClubs[win].mult;
    final total = _total;
    if (pay > 0) {
      Account.instance.earn(pay);
      Sfx.instance.win();
      Haptics.heavyImpact();
    } else if (total > 0) {
      Sfx.instance.lose();
    }
    if (total > 0) Account.instance.recordCoinRound('star_league', bet: total, won: pay);
    setState(() {
      phase = StarPhase.result;
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
    await Future.delayed(Duration(milliseconds: (3500 * widget.speed).round()));
    if (_disposed) return;
    _startRound();
  }

  @override
  Widget build(BuildContext context) {
    return CoinGameScaffold(
      title: 'دوري النجوم',
      colors: const [Color(0xFF0D5C2E), Color(0xFF073A1D)],
      inPlay: _total > 0 && phase != StarPhase.result,
      onHelp: () => showHowTo(
        context,
        'دوري النجوم',
        'اختر قيمة الرقاقة واضغط على النادي اللي تتوقع يفوز. تقدر تراهن على أكثر من نادي. '
            'لما يخلص العداد تدور الأضواء حول الملعب، والنادي اللي يقف عنده الضوء يفوز ويدفع رهانك مضروب في رقمه.\n\n'
            'كل ما كان المضاعف أعلى كان الفوز أندر: الثيران ×100 تقريباً مرة كل 105 جولات، والنسور ×5 تقريباً مرة كل 5 جولات.\n\n'
            'الجولات مباشرة ونفسها عند كل اللاعبين. الأندية وشعاراتها من تصميم موجان.',
      ),
      child: Column(
        children: [
          _status(),
          _historyRow(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Center(child: AspectRatio(aspectRatio: 1, child: _board())),
            ),
          ),
          BetChips(value: _chip, steps: starChips, enabled: phase == StarPhase.betting, onChanged: (v) => setState(() => _chip = v)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('star-clear'),
                    onPressed: phase == StarPhase.betting && _total > 0 ? _clear : null,
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('مسح', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('star-repeat'),
                    onPressed: phase == StarPhase.betting && _lastBets.any((b) => b > 0) ? _repeat : null,
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

  Widget _status() {
    final Widget child;
    if (phase == StarPhase.betting) {
      child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⚽ راهن الآن', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _left <= 3 ? const Color(0xFFE02424) : Colors.black.withValues(alpha: .4),
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Text('$_left', key: const ValueKey('star-timer'), style: AppTheme.display.copyWith(fontSize: 20)),
          ),
          if (_total > 0) ...[
            const SizedBox(width: 10),
            Text('رهانك ${fmtCoins(_total)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold)),
          ],
        ],
      );
    } else if (phase == StarPhase.spinning) {
      child = const Text('🏟️ المباراة جارية...', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16));
    } else {
      final c = starClubs[_winner!];
      child = Row(
        key: const ValueKey('star-result'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🏆 فاز ${c.name} ${ltr('×${c.mult}')}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          if (_lastPay > 0) ...[
            const SizedBox(width: 10),
            Text('+${fmtCoins(_lastPay)}', style: AppTheme.display.copyWith(fontSize: 22, color: AppColors.gold))
                .animate()
                .scale(duration: 400.ms, curve: Curves.elasticOut),
          ],
        ],
      );
    }
    return SizedBox(height: 48, child: Center(child: FittedBox(child: child)));
  }

  Widget _historyRow() => SizedBox(
    height: 38,
    child: Row(
      children: [
        const SizedBox(width: 14),
        Text('النتائج', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (i, h) in _history.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                  child: Opacity(opacity: i == 0 ? 1 : .75, child: ClubCrest(club: starClubs[h], size: 30)),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _board() => LayoutBuilder(
    builder: (context, c) {
      final cw = c.maxWidth / starRingCols;
      final ch = c.maxHeight / starRingRows;
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [Color(0xFF1C2B4A), Color(0xFF0B1426)]),
          border: Border.all(color: AppColors.gold, width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
        ),
        child: Stack(
          children: [
            for (var i = 0; i < starRing.length; i++)
              () {
                final (x, y) = starRingCell(i);
                return Positioned(left: x * cw, top: y * ch, width: cw, height: ch, child: _ringCell(i));
              }(),
            Positioned(left: cw, top: ch, width: cw * (starRingCols - 2), height: ch * (starRingRows - 2), child: _pitch()),
          ],
        ),
      );
    },
  );

  Widget _ringCell(int i) {
    final club = starRing[i];
    final lit = _lit == i && phase != StarPhase.betting;
    final won = phase == StarPhase.result && _lit == i;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: AnimatedContainer(
        key: ValueKey('star-ring-$i'),
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lit ? const Color(0xFFFFF3B0) : Colors.black.withValues(alpha: .35),
          border: Border.all(color: lit ? Colors.white : AppColors.gold.withValues(alpha: .35), width: lit ? 2.5 : 1),
          boxShadow: lit ? const [BoxShadow(color: Color(0xFFFFD84D), blurRadius: 16, spreadRadius: 2)] : null,
        ),
        child: Padding(padding: const EdgeInsets.all(4), child: ClubCrest(club: starClubs[club], size: 40)),
      ),
    ).animate(target: won ? 1 : 0).scaleXY(end: 1.15, duration: 300.ms);
  }

  Widget _pitch() => Container(
    margin: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2FA65A), Color(0xFF1D7A3E)],
      ),
      border: Border.all(color: Colors.white54, width: 1.5),
    ),
    child: CustomPaint(
      painter: _PitchLines(),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            for (var row = 0; row < 2; row++)
              Expanded(
                child: Row(
                  children: [for (var col = 0; col < 5; col++) Expanded(child: _clubTile(row * 5 + col))],
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _clubTile(int i) {
    final c = starClubs[i];
    final bet = _bets[i];
    final won = phase == StarPhase.result && _winner == i;
    final litNow = phase == StarPhase.spinning && starRing[_lit] == i;
    return GestureDetector(
      key: ValueKey('star-club-$i'),
      onTap: () => _bet(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.black.withValues(alpha: won || litNow ? .1 : .28),
          border: Border.all(color: won ? AppColors.gold : (litNow ? Colors.white : Colors.white24), width: won ? 3 : 1.2),
          boxShadow: won ? const [BoxShadow(color: Color(0xCCFFC93C), blurRadius: 16, spreadRadius: 1)] : null,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Column(
                  children: [
                    Expanded(child: FittedBox(child: ClubCrest(club: c, size: 40))),
                    FittedBox(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, height: 1.3))),
                    FittedBox(child: Text(ltr('×${c.mult}'), style: AppTheme.display.copyWith(fontSize: 14, color: AppColors.gold, height: 1))),
                  ],
                ),
              ),
            ),
            if (bet > 0)
              Positioned(
                top: 2,
                left: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
                  child: Text(fmtCoins(bet), style: const TextStyle(color: Color(0xFF4A2600), fontWeight: FontWeight.w900, fontSize: 10)),
                ),
              ),
          ],
        ),
      ),
    ).animate(target: won ? 1 : 0).scaleXY(end: 1.08, duration: 300.ms);
  }
}

class _PitchLines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), p);
    canvas.drawCircle(size.center(Offset.zero), size.height * .22, p);
    final bh = size.height * .5;
    canvas.drawRect(Rect.fromLTWH(0, (size.height - bh) / 2, size.width * .1, bh), p);
    canvas.drawRect(Rect.fromLTWH(size.width * .9, (size.height - bh) / 2, size.width * .1, bh), p);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// شعار النادي: درع بلونين وحيوان النادي ونجمة.
class ClubCrest extends StatelessWidget {
  const ClubCrest({super.key, required this.club, this.size = 40});
  final StarClub club;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 1.12,
    child: CustomPaint(
      painter: _CrestPainter(club.c1, club.c2),
      child: Padding(
        padding: EdgeInsets.only(top: size * .2, bottom: size * .22),
        child: Center(child: Text(club.emoji, style: TextStyle(fontSize: size * .46, height: 1))),
      ),
    ),
  );
}

class _CrestPainter extends CustomPainter {
  _CrestPainter(this.c1, this.c2);
  final Color c1, c2;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final shield = Path()
      ..moveTo(w * .5, h * .02)
      ..cubicTo(w * .7, h * .1, w * .85, h * .1, w * .96, h * .08)
      ..lineTo(w * .94, h * .55)
      ..cubicTo(w * .9, h * .8, w * .7, h * .9, w * .5, h * .98)
      ..cubicTo(w * .3, h * .9, w * .1, h * .8, w * .06, h * .55)
      ..lineTo(w * .04, h * .08)
      ..cubicTo(w * .15, h * .1, w * .3, h * .1, w * .5, h * .02)
      ..close();
    canvas.drawShadow(shield, Colors.black, 2, false);
    canvas.save();
    canvas.clipPath(shield);
    canvas.drawRect(Offset.zero & s, Paint()..color = c2);
    // شريطين قطريين بلون النادي
    final band = Path()
      ..moveTo(0, h * .2)
      ..lineTo(w * .5, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * .35)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(band, Paint()..color = c1);
    canvas.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x55FFFFFF), Color(0x00FFFFFF), Color(0x33000000)],
        ).createShader(Offset.zero & s),
    );
    canvas.restore();
    canvas.drawPath(
      shield,
      Paint()
        ..color = const Color(0xFFFFD36B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, w * .06),
    );
    // نجمة صغيرة فوق
    final star = Path();
    final cx = w * .5, cy = h * .14, r = w * .07;
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * .45;
      final pt = Offset(cx + rr * cos(a), cy + rr * sin(a));
      i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(star..close(), Paint()..color = const Color(0xFFFFE07A));
  }

  @override
  bool shouldRepaint(_CrestPainter o) => o.c1 != c1 || o.c2 != c2;
}
