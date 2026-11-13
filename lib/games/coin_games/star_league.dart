import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/haptics.dart';
import '../../core/rounds/shared_rounds.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../widgets/account_widgets.dart';
import '../../widgets/game_ui.dart';
import 'coin_ui.dart';
import 'win_fx.dart';

/// نادي خيالي (أسماء وشعارات من تصميمنا عبر Gemini، بدون أي علامة تجارية حقيقية).
class StarClub {
  const StarClub(this.name, this.art, this.emoji, this.mult, this.c1, this.c2);
  final String name;
  final String art;
  final String emoji;
  final int mult;
  final Color c1;
  final Color c2;
}

/// بترتيب خانات الملعب: خانتين في كل سطر (يسار، يمين).
const starClubs = [
  StarClub('النسور', 'eagle', '🦅', 2, Color(0xFF2F7BFF), Color(0xFF0B2A6B)),
  StarClub('الأسود', 'lion', '🦁', 5, Color(0xFFFFC21A), Color(0xFFB3261E)),
  StarClub('الذئاب', 'wolf', '🐺', 8, Color(0xFF8C9AB0), Color(0xFF1E2A44)),
  StarClub('النمور', 'tiger', '🐯', 18, Color(0xFFFF8A1F), Color(0xFF2A1A0A)),
  StarClub('الخيول', 'horse', '🐎', 66, Color(0xFFC98A4B), Color(0xFF4A2A12)),
  StarClub('القروش', 'shark', '🦈', 50, Color(0xFF1FC6C9), Color(0xFF0A4048)),
  StarClub('الثيران', 'bull', '🐂', 100, Color(0xFFE02424), Color(0xFFFFC93C)),
  StarClub('الأفاعي', 'cobra', '🐍', 88, Color(0xFF3DDC6A), Color(0xFF0E2E18)),
  StarClub('الدببة', 'bear', '🐻', 30, Color(0xFFB0413E), Color(0xFF3A0E12)),
  StarClub('الثعالب', 'fox', '🦊', 20, Color(0xFFFF6A2B), Color(0xFFF2F2F2)),
];

/// احتمال كل نادي يتناسب عكسياً مع مضاعفه، فالعائد ≈98% لأي نادي.
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

/// اختيار الفائز بنفس فكرة اللعبة المرجعية: الفرصة عكس المضاعف، لكن الجولة ما تخسّر الصندوق،
/// فأي نادي لو فاز يدفع أكثر من 95% من مجموع الرهانات يطلع من السحب (لو كل النوادي كده يفوز الأقل دفعاً).
/// [pool] = مجموع الرهانات على كل نادي.
int pickStarSafe(Random r, List<int> pool) {
  final total = pool.fold(0, (a, b) => a + b);
  if (total == 0) return pickStarClub(r);
  final ok = [for (var i = 0; i < starClubs.length; i++) if (pool[i] * starClubs[i].mult <= total * .95) i];
  if (ok.isEmpty) {
    var best = 0;
    for (var i = 1; i < starClubs.length; i++) {
      if (pool[i] * starClubs[i].mult < pool[best] * starClubs[best].mult) best = i;
    }
    return best;
  }
  final w = [for (final i in ok) 1 / starClubs[i].mult];
  var x = r.nextDouble() * w.fold(0.0, (a, b) => a + b);
  for (var k = 0; k < ok.length; k++) {
    x -= w[k];
    if (x < 0) return ok[k];
  }
  return ok.last;
}

/// جولات موحدة زي المرجع: 30 ثانية رهان، ثانيتين "توقف الرهان/استعد"، الدوران، ثم النتيجة. الجولة 45 ثانية.
const starRounds = FixedRounds(45000);
const starBetMs = 30000;
const starReadyMs = 2200;
List<int> starCrowdFull(int round) => [for (var i = 0; i < starClubs.length; i++) starCrowd(round, i, 1)];
int starWinnerFor(int round) => pickStarSafe(roundRng('star_league', round, 'win'), starCrowdFull(round));

/// الحلقة الخارجية: 20 شعار حول الدائرة (من فوق مع عقارب الساعة) وكل نادي له خانتين.
const starRing = [6, 1, 9, 2, 5, 0, 3, 7, 4, 8, 1, 6, 0, 9, 3, 5, 8, 2, 7, 4];

const starChips = [100, 200, 500, 1000, 5000];

const _crowdNames = ['أبو فهد', 'نورة', 'ملك الحظ', 'سلطان', 'ريم', 'أبو خالد', 'جود', 'الذيب', 'لمى', 'فارس', 'دانة', 'أبو نايف', 'هيا', 'الصقر', 'مشاعل', 'تركي'];

/// رهانات باقي اللاعبين على كل نادي في الجولة (نفس الأرقام على كل الأجهزة).
/// النوادي ذات المضاعف الصغير يراهن عليها الناس أكثر. [f] = كم مضى من وقت الرهان (0..1).
int starCrowd(int round, int club, double f) {
  final r = roundRng('star_league', round, 'crowd$club');
  final cap = max(2, (110 / sqrt(starClubs[club].mult)).round());
  var full = 200 * (1 + r.nextInt(cap));
  // أحياناً لاعب كبير يحط مبلغ ضخم على نادي واحد (زي اللي بيحصل في المرجع)
  final wr = roundRng('star_league', round, 'whale');
  final whale = wr.nextDouble() < .35;
  final wc = wr.nextInt(starClubs.length);
  final wa = 100 * (60 + wr.nextInt(340));
  if (whale && wc == club) full += wa;
  // كل نادي يتعبى بسرعة مختلفة شوي
  final speed = .6 + r.nextDouble() * .8;
  final g = pow(f.clamp(0.0, 1.0), speed).toDouble();
  return (full * g / 100).round() * 100;
}

enum StarPhase { betting, spinning, result }

class StarLeagueScreen extends StatefulWidget {
  const StarLeagueScreen({super.key, this.betSeconds = 30, this.random, this.speed = 1.0});
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

  /// شريط "ابدأ الرهان / توقف الرهان / استعد" فوق الدائرة.
  String? _banner;
  int _bannerSeq = 0;

  void _showBanner(String text, int ms) {
    final seq = ++_bannerSeq;
    setState(() => _banner = text);
    Future.delayed(Duration(milliseconds: (ms * widget.speed).round()), () {
      if (!_disposed && _bannerSeq == seq) setState(() => _banner = null);
    });
  }

  int get _total => _bets.fold(0, (a, b) => a + b);

  int get _crowdRound => _synced ? _round : _history.length + 1;
  double get _betFraction => phase == StarPhase.betting ? 1 - _left / max(1, _synced ? starBetMs ~/ 1000 : widget.betSeconds) : 1;
  int _cellTotal(int i) => starCrowd(_crowdRound, i, _betFraction) + _bets[i];
  int get _allTotal => [for (var i = 0; i < starClubs.length; i++) _cellTotal(i)].fold(0, (a, b) => a + b);

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
    if (!_synced || starRounds.elapsedMs < 1500) {
      _showBanner('ابدأ الرهان', 1300);
      Sfx.instance.whistle();
    }
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
    final win = _synced
        ? starWinnerFor(_round)
        : pickStarSafe(_rng, [for (var i = 0; i < starClubs.length; i++) starCrowd(_crowdRound, i, 1) + _bets[i]]);
    final land = _landingCell(win, _synced ? _round : _rng.nextInt(2));
    setState(() => phase = StarPhase.spinning);
    // توقف الرهان ثم استعد، وبعدها تبدأ الأضواء تلف
    _showBanner('توقف الرهان', 1100);
    Sfx.instance.whistle();
    await Future.delayed(Duration(milliseconds: (1100 * widget.speed).round()));
    if (_disposed) return;
    _showBanner('استعد', 1000);
    await Future.delayed(Duration(milliseconds: (1100 * widget.speed).round()));
    if (_disposed) return;
    Sfx.instance.spinStart();
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
    Sfx.instance.cheer();
    if (pay > 0) {
      Account.instance.earn(pay);
      Haptics.heavyImpact();
      if (starClubs[win].mult >= 18 && mounted) {
        unawaited(showBigWin(context, amount: pay, mult: starClubs[win].mult.toDouble(), hero: ClubCrest(club: starClubs[win], size: 120)));
      } else {
        Sfx.instance.win();
        Sfx.instance.coins(8);
      }
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

  void _help() => showHowTo(
    context,
    'دوري النجوم',
    'اختر قيمة الرقاقة من تحت واضغط على النادي اللي تتوقع يفوز. تقدر تراهن على أكثر من نادي وأكثر من مرة. '
        'لما يخلص العداد تدور الأضواء على شعارات الأندية حول الملعب، والنادي اللي يقف عنده الضوء يفوز ويدفع رهانك مضروب في رقمه.\n\n'
        'كل ما كان المضاعف أعلى كان الفوز أندر: النسور ×2 تقريباً مرة كل جولتين، والثيران ×100 تقريباً مرة كل 100 جولة.\n\n'
        'كل جولة 30 ثانية رهان، وبعدها "توقف الرهان" ثم الدوران. والجولة ما تطلّع نادي يدفع أكثر من مجموع رهانات الجولة.\n\n'
        'الجولات مباشرة ونفسها عند كل اللاعبين. الأندية وشعاراتها خيالية من تصميم موجان.',
  );

  @override
  Widget build(BuildContext context) {
    return LeaveGuardScaffold(
      inPlay: _total > 0 && phase != StarPhase.result,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/sl_stadium.webp',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0B2A6B), Color(0xFF1D7A3E), Color(0xFF0E4A24)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    _logo(),
                    _topBar(),
                    if (_synced)
                      AdminUpcoming(
                        compact: true,
                        items: [
                          for (var k = phase == StarPhase.betting ? 0 : 1; k < 8; k++)
                            () {
                              final c = starClubs[starWinnerFor(_round + k)];
                              return Row(mainAxisSize: MainAxisSize.min, children: [ClubCrest(club: c, size: 22), adminChip(ltr('×${c.mult}'))]);
                            }(),
                        ],
                      ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final size = min(c.maxWidth - 8, c.maxHeight - 4);
                          return Center(child: SizedBox(width: size, height: size, child: _circle(size)));
                        },
                      ),
                    ),
                    _infoRow(),
                    _historyStrip(),
                    _chipsRow(),
                  ],
                ),
              ),
            ),
          ),
          if (phase == StarPhase.result && _winner != null) _resultPanel(),
        ],
      ),
    );
  }

  Widget _logo() => SizedBox(
    height: 78,
    child: Image.asset(
      'assets/images/sl_logo.webp',
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Center(child: Text('⚽ دوري النجوم', style: AppTheme.display.copyWith(fontSize: 30))),
    ),
  );

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
    child: Row(
      children: [
        _greenRound(Icons.reply_rounded, () => Navigator.maybePop(context), 'star-back'),
        const SizedBox(width: 8),
        Expanded(
          child: ListenableBuilder(
            listenable: Account.instance,
            builder: (context, _) => Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6BE36B), Color(0xFF1F9A2E)]),
                border: Border.all(color: Colors.white54),
              ),
              child: Row(
                children: [
                  const Text('الرصيد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const Spacer(),
                  const CoinIcon(size: 20),
                  const SizedBox(width: 6),
                  Text(fmtCoins(myCoins), key: const ValueKey('coin-balance'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFFFE07A))),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _greenRound(Icons.question_mark_rounded, _help, 'coin-help'),
      ],
    ),
  );

  Widget _greenRound(IconData icon, VoidCallback onTap, String key) => GestureDetector(
    key: ValueKey(key),
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7BEA6B), Color(0xFF1F8A2E)]),
        border: Border.all(color: Colors.white70, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );

  /// الدائرة الكبيرة: إطار ذهبي بالأضواء، حلقة الشعارات، والملعب بخانات المضاعفات.
  Widget _circle(double s) {
    final cx = s / 2;
    final ringR = s * .425;
    final crest = s * .092;
    final inner = s * .355;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: CustomPaint(painter: _RimPainter(_bulbPhase))),
        for (var i = 0; i < starRing.length; i++)
          () {
            final a = -pi / 2 + i * 2 * pi / starRing.length;
            final x = cx + ringR * cos(a), y = cx + ringR * sin(a);
            final n = starRing.length;
            final back = ((_lit - i) % n + n) % n; // كام خانة ورا الضوء
            final lit = _lit == i && phase != StarPhase.betting;
            final trail = phase == StarPhase.spinning && !lit && back <= 2 && back > 0;
            return Positioned(
              left: x - crest / 2 - 3,
              top: y - crest / 2 - 3,
              width: crest + 6,
              height: crest + 6,
              child: AnimatedContainer(
                key: ValueKey('star-ring-$i'),
                duration: const Duration(milliseconds: 70),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: lit
                      ? Border.all(color: const Color(0xFFFFF59A), width: 2.5)
                      : trail
                          ? Border.all(color: const Color(0xFFFFF59A).withValues(alpha: back == 1 ? .7 : .4), width: 2)
                          : null,
                  boxShadow: lit
                      ? const [BoxShadow(color: Color(0xFFFFE04D), blurRadius: 18, spreadRadius: 4)]
                      : trail
                          ? [BoxShadow(color: const Color(0xFFFFE04D).withValues(alpha: back == 1 ? .55 : .3), blurRadius: 12, spreadRadius: 2)]
                          : null,
                ),
                child: ClubCrest(club: starClubs[starRing[i]], size: crest),
              ),
            );
          }(),
        // الملعب
        Positioned(
          left: cx - inner,
          top: cx - inner,
          width: inner * 2,
          height: inner * 2,
          child: _pitch(inner),
        ),
        if (phase == StarPhase.betting)
          Positioned(right: s * .02, top: s * .02, child: _alarm()),
        if (_banner != null)
          Positioned.fill(child: IgnorePointer(child: Center(child: _bannerWidget(_banner!, s)))),
      ],
    );
  }

  Widget _bannerWidget(String t, double s) {
    final ready = t == 'استعد';
    final start = t == 'ابدأ الرهان';
    final text = Text(
      t,
      style: AppTheme.display.copyWith(
        fontSize: s * (ready ? .12 : .085),
        color: ready ? const Color(0xFFFFD84D) : Colors.white,
        shadows: const [Shadow(color: Colors.black54, offset: Offset(2, 3), blurRadius: 6)],
      ),
    );
    if (ready) {
      return text.animate(key: ValueKey(t)).scale(begin: const Offset(.3, .3), duration: 450.ms, curve: Curves.elasticOut);
    }
    return Container(
      key: ValueKey('star-banner-$t'),
      width: s,
      padding: EdgeInsets.symmetric(vertical: s * .03),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: start
              ? const [Color(0x00C62828), Color(0xEEE53935), Color(0xEEE53935), Color(0x00C62828)]
              : const [Color(0x003949AB), Color(0xEE3949AB), Color(0xEE5E35B1), Color(0x005E35B1)],
          stops: const [0, .2, .8, 1],
        ),
        border: Border.symmetric(horizontal: BorderSide(color: Colors.white.withValues(alpha: .7), width: 2)),
      ),
      child: Align(
        heightFactor: 1,
        child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(start ? '⚽ ' : '✋ ', style: TextStyle(fontSize: s * .07)),
          text,
        ]),
      ),
      ),
    ).animate(key: ValueKey(t)).slideX(begin: start ? -1 : 1, duration: 350.ms, curve: Curves.easeOutBack).fadeIn(duration: 200.ms);
  }

  int get _bulbPhase => phase == StarPhase.spinning ? _lit : (_left % 2);

  Widget _pitch(double r) {
    const rows = 5;
    final rowH = r * 2 * .9 / rows;
    final top0 = r * .1;
    return ClipOval(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(colors: [Color(0xFF6CC56A), Color(0xFF3E9A48)]),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _GridPainter(rows, rowH, top0))),
            for (var row = 0; row < rows; row++)
              for (var side = 0; side < 2; side++) _cell(row * 2 + side, row, side, r, rowH, top0),
          ],
        ),
      ),
    );
  }

  Widget _cell(int i, int row, int side, double r, double rowH, double top0) {
    final c = starClubs[i];
    final yMid = top0 + rowH * (row + .5);
    final dy = (yMid - r).abs() + rowH * .25;
    final half = sqrt(max(0, r * r - dy * dy));
    final left = side == 0;
    final x0 = left ? r - half : r;
    final w = half;
    final crest = min(rowH * .72, w * .42);
    final won = phase == StarPhase.result && _winner == i;
    final litNow = phase == StarPhase.spinning && starRing[_lit] == i;
    final bet = _bets[i];
    final crestW = SizedBox(width: crest, height: crest, child: ClubCrest(club: c, size: crest));
    final multW = Text(
      ltr('X${c.mult}'),
      style: AppTheme.display.copyWith(
        fontSize: rowH * .42,
        color: won || litNow ? Colors.white : Colors.white.withValues(alpha: .6),
        shadows: const [Shadow(color: Colors.black26, offset: Offset(1, 2))],
      ),
    );
    return Positioned(
      left: x0,
      top: top0 + rowH * row,
      width: w,
      height: rowH,
      child: GestureDetector(
        key: ValueKey('star-club-$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _bet(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: won ? const Color(0x55FFE04D) : (litNow ? const Color(0x33FFFFFF) : Colors.transparent),
            border: won ? Border.all(color: const Color(0xFFFFE04D), width: 3) : null,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * .06, vertical: rowH * .08),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      textDirection: TextDirection.ltr,
                      mainAxisSize: MainAxisSize.min,
                      children: left ? [crestW, SizedBox(width: w * .1), multW] : [multW, SizedBox(width: w * .1), crestW],
                    ),
                  ),
                ),
              ),
              // رقائق باقي اللاعبين تنزل على الخانة كل ما زادت رهاناتهم
              ..._crowdChips(i, w, rowH),
              if (_cellTotal(i) > 0)
                Positioned(
                  bottom: 1,
                  left: left ? 2 : null,
                  right: left ? null : 2,
                  child: Text(
                    fmtCoins(_cellTotal(i)),
                    key: ValueKey('star-total-$i'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 3)]),
                  ),
                ),
              if (bet > 0)
                Positioned(
                  top: rowH * .38 + 2,
                  left: left ? null : crest * .45,
                  right: left ? crest * .45 : null,
                  child: Text(
                    fmtCoins(bet),
                    key: ValueKey('star-bet-$i'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFFFFE07A), shadows: [Shadow(color: Colors.black, blurRadius: 3)]),
                  ),
                ),
              if (bet > 0)
                Positioned(
                  top: 1,
                  left: left ? null : crest * .6,
                  right: left ? crest * .6 : null,
                  child: _chipIcon(_chipFor(bet), rowH * .38),
                ),
            ],
          ),
        ),
      ),
    ).animate(target: won ? 1 : 0).shimmer(duration: 900.ms, color: const Color(0xFFFFF59A));
  }

  List<Widget> _crowdChips(int i, double w, double rowH) {
    final amount = starCrowd(_crowdRound, i, _betFraction);
    if (amount == 0) return const [];
    final n = min(4, 1 + amount ~/ 1500);
    final r = roundRng('star_league', _crowdRound, 'chips$i');
    final size = rowH * .34;
    return [
      for (var k = 0; k < n; k++)
        () {
          final x = (.25 + r.nextDouble() * .5) * (w - size);
          final y = (.1 + r.nextDouble() * .5) * (rowH - size);
          final v = starChips[r.nextInt(starChips.length)];
          return Positioned(
            key: ValueKey('crowd-chip-$_crowdRound-$i-$k'),
            left: x,
            top: y,
            child: IgnorePointer(
              child: Opacity(opacity: .85, child: _chipIcon(v, size))
                  .animate()
                  .moveY(begin: -rowH * 1.2, end: 0, duration: 380.ms, curve: Curves.easeOutBack)
                  .fadeIn(duration: 200.ms),
            ),
          );
        }(),
    ];
  }

  /// أكبر رقاقة تناسب المبلغ (للشكل فقط).
  int _chipFor(int amount) => starChips.lastWhere((c) => c <= amount, orElse: () => starChips.first);

  Widget _alarm() => Container(
    width: 50,
    height: 50,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(colors: [Color(0xFF2FAE4A), Color(0xFF0E5A22)]),
      border: Border.all(color: const Color(0xFFFFB13D), width: 4),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
    ),
    child: Text(
      '${_left}s',
      key: const ValueKey('star-timer'),
      style: AppTheme.display.copyWith(fontSize: 18, color: _left <= 3 ? const Color(0xFFFF6B6B) : Colors.white),
    ),
  );

  Widget _infoRow() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ltr('NO.${_synced ? _round : _history.length + 1}'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              Text('مجموع الرهانات: ${fmtCoins(_allTotal)}', key: const ValueKey('star-all-total'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              Text('رهانك: ${fmtCoins(_total)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFFFE07A))),
            ],
          ),
        ),
        if (_total > 0 && phase == StarPhase.betting)
          TextButton(key: const ValueKey('star-clear'), onPressed: _clear, child: const Text('مسح', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))),
        GestureDetector(
          key: const ValueKey('star-repeat'),
          onTap: phase == StarPhase.betting && _lastBets.any((b) => b > 0) ? _repeat : null,
          child: Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: phase == StarPhase.betting && _lastBets.any((b) => b > 0)
                    ? const [Color(0xFFFFE07A), Color(0xFFE59A12)]
                    : const [Color(0xFFE6E6E6), Color(0xFF9A9A9A)],
              ),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: const Text('كرر', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF5A3A00))),
          ),
        ),
      ],
    ),
  );

  Widget _historyStrip() => Container(
    height: 40,
    margin: const EdgeInsets.fromLTRB(10, 2, 10, 6),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF0E3A2A).withValues(alpha: .85),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFFFC93C), width: 2),
    ),
    child: Row(
      children: [
        const Text('◀', style: TextStyle(color: Color(0xFFFFC93C), fontSize: 12)),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              for (final (i, h) in _history.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClubCrest(club: starClubs[h], size: 30),
                      if (i == 0)
                        Positioned(
                          bottom: -3,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: const Color(0xFF2F7BFF),
                            child: const Text('جديد', textAlign: TextAlign.center, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900)),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Text('▶', style: TextStyle(color: Color(0xFFFFC93C), fontSize: 12)),
      ],
    ),
  );

  Widget _chipsRow() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
    child: Row(
      textDirection: TextDirection.ltr,
      children: [
        for (final v in starChips)
          Expanded(
            child: GestureDetector(
              key: ValueKey('chip-$v'),
              onTap: phase == StarPhase.betting ? () => setState(() => _chip = v) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF15233F).withValues(alpha: .9),
                  border: Border.all(color: v == _chip ? const Color(0xFFFFE04D) : Colors.white24, width: v == _chip ? 3 : 1),
                  boxShadow: v == _chip ? const [BoxShadow(color: Color(0x99FFE04D), blurRadius: 12)] : null,
                ),
                child: AspectRatio(aspectRatio: 1.1, child: Center(child: _chipIcon(v, 54))),
              ),
            ),
          ),
      ],
    ),
  );

  static const _chipColors = {
    100: Color(0xFF2DB84A),
    200: Color(0xFF2F7BFF),
    500: Color(0xFF8E3DE0),
    1000: Color(0xFFE5A50F),
    5000: Color(0xFFD82A2A),
  };

  Widget _chipIcon(int v, double size) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/sl_chip_${starChips.indexOf(v)}.webp',
          width: size,
          height: size,
          errorBuilder: (_, _, _) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _chipColors[v],
              border: Border.all(color: Colors.white, width: size * .08),
            ),
          ),
        ),
        FittedBox(
          child: Padding(
            padding: EdgeInsets.all(size * .22),
            child: Text(
              v >= 1000 ? '${v ~/ 1000}K' : '$v',
              style: AppTheme.display.copyWith(color: _chipColors[v], shadows: const [Shadow(color: Colors.white, blurRadius: 3)]),
            ),
          ),
        ),
      ],
    ),
  );

  /// أبطال الجولة: أكثر 3 كسبوا (أنت لو كسبت + لاعبين من رهانات الجولة).
  Widget _victors() {
    final w = _winner!;
    final pot = starCrowd(_synced ? _round : _history.length, w, 1) * starClubs[w].mult;
    final r = roundRng('star_league', _synced ? _round : _history.length, 'victors');
    final list = <(String, int, int?)>[];
    if (pot > 0) {
      final shares = [.55 + r.nextDouble() * .2, .15 + r.nextDouble() * .1, .05 + r.nextDouble() * .05];
      final used = <int>{};
      for (final sh in shares) {
        var k = r.nextInt(_crowdNames.length);
        while (used.contains(k)) {
          k = (k + 1) % _crowdNames.length;
        }
        used.add(k);
        final amt = (pot * sh / 100).round() * 100;
        if (amt > 0) list.add((_crowdNames[k], amt, k % 18));
      }
    }
    if (_lastPay > 0) list.add(('أنت', _lastPay, Account.instance.profile?.avatar));
    list.sort((a, b) => b.$2.compareTo(a.$2));
    final top = list.take(3).toList();
    return Container(
      key: const ValueKey('star-victors'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .22), borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('— أبطال الجولة —', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 6),
        if (top.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('محدش راهن على الفايز الجولة دي', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
          )
        else
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (var k = 0; k < top.length; k++)
              Column(mainAxisSize: MainAxisSize.min, children: [
                Stack(clipBehavior: Clip.none, children: [
                  PlayerAvatar(index: top[k].$3 ?? 0, size: 42),
                  Positioned(
                    left: -6,
                    top: -8,
                    child: Text(k == 0 ? '👑' : (k == 1 ? '🥈' : '🥉'), style: const TextStyle(fontSize: 16)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(top[k].$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const CoinIcon(size: 14),
                  const SizedBox(width: 3),
                  Text(fmtCoins(top[k].$2), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFFFE07A))),
                ]),
              ]).animate(delay: (150 * k).ms).fadeIn().slideY(begin: .3),
          ]),
      ]),
    );
  }

  Widget _resultPanel() {
    final c = starClubs[_winner!];
    final mine = _lastBets[_winner!] > 0 && _lastPay > 0;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        key: const ValueKey('star-result'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF0186B2E), Color(0xF00B3A18)]),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFB0306A), Color(0xFF7A1A48)]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFC93C), width: 2),
                ),
                child: Text(ltr('NO. ${_synced ? _round : _history.length}'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(width: 160, height: 120, child: CustomPaint(painter: _RaysPainter())),
                ClubCrest(club: c, size: 100).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              ],
            ),
            Text(ltr('X${c.mult}'), style: AppTheme.display.copyWith(fontSize: 44, color: const Color(0xFFFFE04D))),
            Text('فاز ${c.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            const SizedBox(height: 2),
            if (mine)
              Text('ربحت +${fmtCoins(_lastPay)} 🎉', style: AppTheme.display.copyWith(fontSize: 26, color: const Color(0xFFFFE07A)))
                  .animate()
                  .scale(duration: 400.ms, curve: Curves.elasticOut)
            else
              Text(
                _lastBets.any((b) => b > 0) && _lastPay == 0 && _history.isNotEmpty ? 'حظ أوفر الجولة الجاية' : 'ما راهنت في هذه الجولة',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 10),
            _victors(),
          ],
        ),
      ).animate().slideY(begin: 1, duration: 350.ms, curve: Curves.easeOutCubic),
    );
  }
}

/// إطار الدائرة: حلقة برتقالية ذهبية بلمبات تومض، وحلقة خضراء للشعارات.
class _RimPainter extends CustomPainter {
  _RimPainter(this.phase);
  final int phase;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..shader = const RadialGradient(colors: [Color(0xFFFFD36B), Color(0xFFE07A10), Color(0xFF9A3A05)], stops: [.85, .95, 1]).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(c, r * .955, Paint()..color = const Color(0xFFB8460A));
    canvas.drawCircle(c, r * .935, Paint()..shader = const RadialGradient(colors: [Color(0xFF2F8A3A), Color(0xFF1C5E26)], stops: [.75, 1]).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(
      c,
      r * .935,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFE07A),
    );
    // لمبات تومض بالتناوب
    const n = 40;
    for (var i = 0; i < n; i++) {
      final a = -pi / 2 + i * 2 * pi / n;
      final p = c + Offset(cos(a), sin(a)) * r * .975;
      final on = (i + phase) % 2 == 0;
      if (on) canvas.drawCircle(p, r * .03, Paint()..color = const Color(0x88FFF3A0)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(p, r * .016, Paint()..color = on ? const Color(0xFFFFFBE0) : const Color(0xFFE0A030));
    }
  }

  @override
  bool shouldRepaint(_RimPainter o) => o.phase != phase;
}

/// خطوط الملعب داخل الدائرة: خط بالنص وخطوط بين الصفوف.
class _GridPainter extends CustomPainter {
  _GridPainter(this.rows, this.rowH, this.top0);
  final int rows;
  final double rowH, top0;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x553A6B3A)
      ..strokeWidth = 2;
    // خطوط عشب فاتحة وغامقة
    for (var i = 0; i < rows; i++) {
      if (i.isOdd) {
        canvas.drawRect(Rect.fromLTWH(0, top0 + rowH * i, size.width, rowH), Paint()..color = const Color(0x14000000));
      }
    }
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), p);
    for (var i = 0; i <= rows; i++) {
      final y = top0 + rowH * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter o) => false;
}

class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()..color = const Color(0x22FFFFFF);
    for (var i = 0; i < 16; i += 2) {
      final a1 = i * pi / 8, a2 = (i + 1) * pi / 8;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + cos(a1) * 200, c.dy + sin(a1) * 200)
        ..lineTo(c.dx + cos(a2) * 200, c.dy + sin(a2) * 200)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

/// شعار النادي: صورة الشعار، وبديل مرسوم لو ما انحملت.
class ClubCrest extends StatelessWidget {
  const ClubCrest({super.key, required this.club, this.size = 40});
  final StarClub club;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Image.asset(
      'assets/images/fc_${club.art}.webp',
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [club.c1, club.c2]),
          border: Border.all(color: const Color(0xFFFFD36B), width: 2),
        ),
        child: Text(club.emoji, style: TextStyle(fontSize: size * .5)),
      ),
    ),
  );
}

/// شاشة بدون شريط علوي مع منع الخروج أثناء رهان.
class LeaveGuardScaffold extends StatelessWidget {
  const LeaveGuardScaffold({super.key, required this.inPlay, required this.child});
  final bool inPlay;
  final Widget child;

  @override
  Widget build(BuildContext context) => LeaveGuard(
    enabled: inPlay,
    message: 'عندك رهان في هذه الجولة، وإذا خرجت يضيع عليك.',
    child: Scaffold(backgroundColor: const Color(0xFF0E4A24), body: child),
  );
}
