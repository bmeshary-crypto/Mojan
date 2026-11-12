import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/account/account.dart';
import '../../core/haptics.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import 'coin_ui.dart';
import 'slot_reels.dart';
import 'slot_shell.dart';
import 'win_fx.dart';

/// كنز السلطان: 5 بكرات × 3 صفوف و20 خط.
///
/// العائد محسوب بمحاكاة (≈95% مع اللفات المجانية).
class SultanSymbol {
  const SultanSymbol(this.id, this.name, this.weight, [this.pays = const (0, 0, 0)]);
  final String id;
  final String name;

  /// الوزن ×10 في كل خلية.
  final int weight;

  /// ربح 3 و4 و5 على الخط (مضروب في رهان الخط = الرهان ÷ 20).
  final (int, int, int) pays;

  bool get isCard => const {'A', 'K', 'Q', 'J', '10'}.contains(id);
}

const sultanSymbols = [
  SultanSymbol('wild', 'السلطان (جوكر)', 30, (75, 375, 1500)),
  SultanSymbol('lamp', 'المصباح', 30, (60, 225, 750)),
  SultanSymbol('palace', 'القصر', 40, (45, 150, 600)),
  SultanSymbol('falcon', 'الصقر', 50, (40, 120, 450)),
  SultanSymbol('camel', 'الجمل', 60, (30, 90, 375)),
  SultanSymbol('A', 'A', 90, (20, 60, 225)),
  SultanSymbol('K', 'K', 90, (20, 60, 225)),
  SultanSymbol('Q', 'Q', 100, (15, 40, 150)),
  SultanSymbol('J', 'J', 100, (15, 40, 150)),
  SultanSymbol('10', '10', 100, (15, 40, 150)),
  SultanSymbol('coin', 'العملة الذهبية', 40),
  SultanSymbol('key', 'المفتاح', 6),
];

SultanSymbol sultanById(String id) => sultanSymbols.firstWhere((s) => s.id == id);

/// ربح العملات (مضروب في الرهان كامل) حسب عددها في أي مكان.
const sultanCoinPays = {3: 1, 4: 2, 5: 5, 6: 15, 7: 50, 8: 200};

/// اسم درجات الجاكبوت (5 عملات وفوق).
const sultanJackpots = [(8, 'الكنز الأعظم'), (7, 'الكبير'), (6, 'الوسط'), (5, 'الصغير')];

const sultanKeysNeeded = 5;
const sultanFreeSpins = 10;
const sultanFreeMult = 2;
const sultanBets = [20, 40, 100, 200, 500, 1000, 2000, 5000];

/// الخطوط العشرين: الصف في كل بكرة (0 فوق، 1 وسط، 2 تحت).
const sultanLines = [
  [1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2],
  [0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [0, 1, 1, 1, 0],
  [2, 1, 1, 1, 2], [1, 0, 1, 2, 1], [1, 2, 1, 0, 1], [0, 1, 0, 1, 0], [2, 1, 2, 1, 2],
  [1, 1, 0, 1, 1], [1, 1, 2, 1, 1], [0, 2, 0, 2, 0], [2, 0, 2, 0, 2], [0, 2, 2, 2, 0],
];

/// رمز عشوائي لبكرة معينة: الجوكر ما يطلع في البكرة الأولى، والمفتاح بس في البكرات 2-4.
String pickSultan(Random r, int reel) {
  var total = 0;
  for (final s in sultanSymbols) {
    total += _weightOn(s, reel);
  }
  var x = r.nextInt(total);
  for (final s in sultanSymbols) {
    x -= _weightOn(s, reel);
    if (x < 0) return s.id;
  }
  return '10';
}

int _weightOn(SultanSymbol s, int reel) {
  if (s.id == 'wild' && reel == 0) return 0;
  if (s.id == 'key' && (reel == 0 || reel == 4)) return 0;
  return s.weight;
}

/// الشبكة: grid[بكرة][صف].
List<List<String>> sultanGrid(Random r) => [
  for (var reel = 0; reel < 5; reel++) [for (var row = 0; row < 3; row++) pickSultan(r, reel)],
];

class SultanLineWin {
  const SultanLineWin(this.line, this.symbol, this.count, this.pay);
  final int line;
  final String symbol;
  final int count;

  /// مضاعف رهان الخط.
  final int pay;
}

class SultanResult {
  const SultanResult(this.lines, this.coins, this.keys);
  final List<SultanLineWin> lines;
  final int coins;
  final int keys;

  int get coinPay => sultanCoinPays[min(coins, 8)] ?? 0;

  /// الربح كمضاعف للرهان الكامل.
  double get mult => lines.fold(0, (a, w) => a + w.pay) / 20 + coinPay;

  int winFor(int bet) => (bet * mult).floor();

  /// الخلايا الرابحة (بكرة، صف).
  Set<(int, int)> cells(List<List<String>> grid) => {
    for (final w in lines)
      for (var r = 0; r < w.count; r++) (r, sultanLines[w.line][r]),
    if (coinPay > 0)
      for (var r = 0; r < 5; r++)
        for (var row = 0; row < 3; row++)
          if (grid[r][row] == 'coin') (r, row),
  };
}

/// ربح خط واحد من اليسار لليمين (3 وفوق)، والجوكر يعوض كل شي إلا العملة والمفتاح.
SultanLineWin? sultanLinePay(int line, List<String> syms) {
  if (syms[0] == 'coin' || syms[0] == 'key') return null;
  var n = 0;
  while (n < 5 && syms[n] == 'wild') {
    n++;
  }
  final wild = sultanById('wild').pays;
  final wildPay = n >= 3 ? [wild.$1, wild.$2, wild.$3][n - 3] : 0;
  final target = syms.firstWhere((s) => s != 'wild', orElse: () => 'wild');
  var best = n >= 3 ? SultanLineWin(line, 'wild', n, wildPay) : null;
  if (target != 'wild' && target != 'coin' && target != 'key') {
    var m = 0;
    while (m < 5 && (syms[m] == target || syms[m] == 'wild')) {
      m++;
    }
    if (m >= 3) {
      final p = sultanById(target).pays;
      final pay = [p.$1, p.$2, p.$3][m - 3];
      if (pay > wildPay) best = SultanLineWin(line, target, m, pay);
    }
  }
  return best;
}

SultanResult sultanEvaluate(List<List<String>> grid) {
  final wins = <SultanLineWin>[];
  for (var l = 0; l < sultanLines.length; l++) {
    final w = sultanLinePay(l, [for (var r = 0; r < 5; r++) grid[r][sultanLines[l][r]]]);
    if (w != null) wins.add(w);
  }
  var coins = 0, keys = 0;
  for (final c in grid) {
    coins += c.where((s) => s == 'coin').length;
    keys += c.where((s) => s == 'key').length;
  }
  return SultanResult(wins, coins, keys);
}

class SultanScreen extends StatefulWidget {
  const SultanScreen({super.key, this.random, this.speed = 1.0});
  final Random? random;
  final double speed;

  @override
  State<SultanScreen> createState() => _SultanScreenState();
}

class _SultanScreenState extends State<SultanScreen> {
  static const _keysPref = 'sultan_keys';
  late final Random _rng = widget.random ?? Random();
  final _reels = SlotReelsController();
  late List<List<String>> _grid = sultanGrid(_rng);
  late final List<List<String>> _initial = [for (final c in _grid) List.of(c)];
  int _betIndex = 2;
  bool _spinning = false;
  bool _auto = false;
  bool _fast = false;
  int _keys = 0;
  int _free = 0;
  int _freeBet = 0;
  int _freeTotal = 0;
  SultanResult? _last;
  int _lastWin = 0;
  bool _disposed = false;
  int _winKey = 0;

  int get _bet => _free > 0 ? _freeBet : sultanBets[_betIndex];

  /// اللفات الجاية محسوبة مسبقاً (الأدمن يشوفها).
  final List<List<List<String>>> _queue = [];

  List<List<List<String>>> get _upcoming {
    _fill();
    return _queue;
  }

  void _fill() {
    while (_queue.length < 8) {
      _queue.add(sultanGrid(_rng));
    }
  }

  List<List<String>> _takeNext() {
    _fill();
    final g = _queue.removeAt(0);
    _fill();
    return g;
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!_disposed) setState(() => _keys = p.getInt(_keysPref) ?? 0);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _saveKeys() async => (await SharedPreferences.getInstance()).setInt(_keysPref, _keys);

  Future<void> _spin() async {
    if (_spinning) return;
    final freeSpin = _free > 0;
    if (!freeSpin && !takeBet(context, _bet)) {
      setState(() => _auto = false);
      return;
    }
    Haptics.selectionClick();
    final bet = _bet;
    final grid = _takeNext();
    setState(() {
      _spinning = true;
      _last = null;
      _lastWin = 0;
      if (freeSpin) _free--;
    });
    final base = _fast ? 300 : 650;
    final step = _fast ? 90 : 230;
    await _reels.spin(
      grid,
      filler: () => pickSultan(_rng, _rng.nextInt(5)),
      stopMs: [for (var i = 0; i < 5; i++) ((base + i * step) * widget.speed).round().clamp(1, 99999)],
    );
    if (_disposed) return;
    final res = sultanEvaluate(grid);
    var won = res.winFor(bet);
    if (freeSpin) won *= sultanFreeMult;
    final effMult = bet == 0 ? 0.0 : won / bet;
    var big = false;
    if (won > 0) {
      Account.instance.earn(won);
      Haptics.heavyImpact();
      final jackpot = res.coins >= 5 ? sultanJackpots.firstWhere((j) => min(res.coins, 8) >= j.$1).$2 : null;
      if ((winTier(effMult) != null || jackpot != null) && mounted) {
        big = true;
        unawaited(showBigWin(
          context,
          amount: won,
          mult: effMult,
          title: jackpot != null ? 'جاكبوت $jackpot!' : null,
          hero: SizedBox(width: 110, height: 110, child: _art(jackpot != null ? 'coin' : 'wild')),
        ));
      } else {
        Sfx.instance.lineWin();
        Sfx.instance.coins(effMult >= 2 ? 8 : 4);
      }
    }
    if (res.keys > 0) Sfx.instance.pickup();
    _winKey++;
    Account.instance.recordCoinRound('sultan', bet: freeSpin ? 0 : bet, won: won);
    var keys = _keys + res.keys;
    var unlocked = false;
    if (keys >= sultanKeysNeeded) {
      keys -= sultanKeysNeeded;
      unlocked = true;
    }
    setState(() {
      _grid = grid;
      _spinning = false;
      _last = res;
      _lastWin = won;
      _keys = keys;
      if (freeSpin) _freeTotal += won;
      if (unlocked) {
        if (_free == 0 && !freeSpin) {
          _freeBet = bet;
          _freeTotal = 0;
        }
        _free += sultanFreeSpins;
      }
    });
    unawaited(_saveKeys());
    if (unlocked && mounted) {
      Sfx.instance.bigWin();
      coinToast(context, '🗝️ فتحت الكنز! $sultanFreeSpins لفات مجانية وأرباحها ×$sultanFreeMult');
    }
    if (_auto || _free > 0) {
      final pause = big ? 3800 : (unlocked ? 1800 : (won > 0 ? 1000 : 500));
      await Future.delayed(Duration(milliseconds: (pause * widget.speed).round()));
      if (_disposed) return;
      if (_auto || _free > 0) unawaited(_spin());
    }
  }

  void _toggleAuto() {
    setState(() => _auto = !_auto);
    if (_auto && !_spinning) _spin();
  }

  @override
  Widget build(BuildContext context) {
    final locked = _spinning || _free > 0 || _auto;
    return SlotShell(
      background: 'assets/images/bg_palace.webp',
      logo: 'assets/images/logo_sultan.webp',
      title: 'كنز السلطان',
      accent: const Color(0xFF3B0A57),
      keyPrefix: 'sultan',
      inPlay: _spinning || _free > 0 || _auto,
      bet: _bet,
      lastWin: _lastWin,
      spinning: _spinning,
      auto: _auto,
      fast: _fast,
      spinLabel: _free > 0 ? '$_free' : 'لف',
      hint: _free > 0 ? '🎁 لفات مجانية ×$sultanFreeMult • ربحها ${fmtCoins(_freeTotal)}' : '20 خط • رهان الخط ${fmtCoins(_bet / 20)}',
      onSpin: _spinning || _auto || _free > 0 ? null : _spin,
      onAuto: _toggleAuto,
      onFast: () => setState(() => _fast = !_fast),
      onHelp: _paytable,
      onMinus: !locked && _betIndex > 0 ? () => setState(() => _betIndex--) : null,
      onPlus: !locked && _betIndex < sultanBets.length - 1 ? () => setState(() => _betIndex++) : null,
      header: Column(
        children: [
          _jackpots(),
          _keysBar(),
          AdminUpcoming(
            compact: true,
            items: [
              for (final g in _upcoming)
                () {
                  final r = sultanEvaluate(g);
                  final t = [
                    r.mult > 0 ? ltr('×${r.mult.toStringAsFixed(r.mult >= 10 ? 0 : 1)}') : '—',
                    if (r.coins >= 3) '🪙${r.coins}',
                    if (r.keys > 0) '🗝️${r.keys}',
                  ].join(' ');
                  return adminChip(t, color: r.mult >= 8 || r.coins >= 5 ? AppColors.gold : Colors.white);
                }(),
            ],
          ),
        ],
      ),
      floating: _lastWin > 0 && !_spinning && winTier(_lastWin / max(1, _bet)) == null ? FloatingWin(key: ValueKey('fw$_winKey'), amount: _lastWin) : null,
      machine: AspectRatio(aspectRatio: 5 / 3.55, child: _board()),
    );
  }

  Widget _jackpots() => Padding(
    padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
    child: Row(
      children: [
        for (final (n, name) in sultanJackpots)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: n == 8 ? const [Color(0xFFFFE07A), Color(0xFFC77A0A)] : const [Color(0xFF8A1020), Color(0xFF4A0610)],
                ),
                border: Border.all(color: const Color(0xFFFFC93C), width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
              ),
              child: Column(
                children: [
                  FittedBox(
                    child: Text(
                      '$name • $n🪙',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: n == 8 ? const Color(0xFF4A2600) : Colors.white70),
                    ),
                  ),
                  FittedBox(
                    child: Text(
                      fmtCoins(_bet * sultanCoinPays[n]!),
                      style: AppTheme.display.copyWith(fontSize: 16, color: n == 8 ? const Color(0xFF4A2600) : const Color(0xFFFFE07A)),
                    ),
                  ),
                ],
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(delay: (n * 400).ms, duration: 1600.ms, color: const Color(0x66FFFFFF)),
          ),
      ],
    ),
  );

  Widget _keysBar() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
    child: Row(
      children: [
        for (var i = 0; i < sultanKeysNeeded; i++)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Opacity(
              opacity: i < _keys ? 1 : .3,
              child: SizedBox(width: 26, height: 26, child: _art('key')),
            ),
          ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _free > 0
                ? '🎁 لفات مجانية: $_free  •  ربحها ${fmtCoins(_freeTotal)}'
                : 'اجمع $sultanKeysNeeded مفاتيح وافتح $sultanFreeSpins لفات مجانية',
            key: const ValueKey('sultan-keys'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _free > 0 ? AppColors.gold : Colors.white, shadows: const [Shadow(color: Colors.black, blurRadius: 4)]),
          ),
        ),
      ],
    ),
  );

  Widget _board() {
    final res = _spinning ? null : _last;
    return MachineFrame(
      inner: const Color(0xFF240637),
      lit: _lastWin > 0 && !_spinning || _free > 0,
      child: Stack(
        children: [
          SlotReels(
            initial: _initial,
            rows: 3,
            gap: 4,
            controller: _reels,
            symbol: _symbol,
            highlight: res?.cells(_grid) ?? const {},
            reelDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A0840), Color(0xFF4A1470), Color(0xFF2A0840)],
              ),
            ),
          ),
          if (res != null && res.lines.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _LinesPainter([for (final w in res.lines) w.line]))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 1, end: .35, duration: 600.ms),
              ),
            ),
        ],
      ),
    );
  }

  Widget _art(String id) => SymbolArt('assets/images/sl_$id.webp', fallback: const {'key': '🗝️', 'coin': '🪙'}[id] ?? '⭐');

  Widget _symbol(String id) {
    final s = sultanById(id);
    if (!s.isCard) return _art(id);
    const colors = {
      'A': [Color(0xFFFF5A5A), Color(0xFF9E1030)],
      'K': [Color(0xFF5AB8FF), Color(0xFF1A4FA0)],
      'Q': [Color(0xFF6DE38A), Color(0xFF13804A)],
      'J': [Color(0xFFFFB347), Color(0xFFB85A00)],
      '10': [Color(0xFFD38CFF), Color(0xFF6A1DA8)],
    };
    return FittedBox(
      child: ShaderMask(
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors[id]!,
        ).createShader(r),
        child: Text(
          id,
          style: const TextStyle(
            fontFamily: 'Lalezar',
            fontSize: 60,
            color: Colors.white,
            height: 1.1,
            shadows: [Shadow(color: Color(0xFFFFD36B), blurRadius: 0, offset: Offset(2, 2))],
          ),
        ),
      ),
    );
  }

  void _paytable() => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('كنز السلطان', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '20 خط من اليسار لليمين، يكفي 3 رموز متتالية من أول بكرة. الأرقام تحت مضروبة في رهان الخط (رهانك ÷ 20).',
                style: TextStyle(height: 1.6, fontSize: 13),
              ),
              const SizedBox(height: 8),
              for (final s in sultanSymbols.where((s) => s.pays.$1 > 0))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(width: 38, height: 38, child: _symbol(s.id)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.isCard ? 'ورقة ${s.name}' : s.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                      Text(ltr('3=${s.pays.$1}  4=${s.pays.$2}  5=${s.pays.$3}'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                ),
              const Divider(),
              Row(
                children: [
                  SizedBox(width: 38, height: 38, child: _art('wild')),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('السلطان جوكر: يعوض أي رمز إلا العملة والمفتاح، وما يطلع في البكرة الأولى.', style: TextStyle(fontSize: 12, height: 1.5))),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(width: 38, height: 38, child: _art('coin')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'العملات تربح في أي مكان: ${[for (final e in sultanCoinPays.entries) '${e.key}=${ltr('×${e.value}')}'].join('، ')} من رهانك. 5 عملات وفوق جاكبوت.',
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(width: 38, height: 38, child: _art('key')),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'المفتاح يطلع في البكرات الوسطى ويتجمع معك. 5 مفاتيح = 10 لفات مجانية بنفس رهانك وأرباحها مضاعفة ×2.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تمام'))],
    ),
  );
}

/// يرسم الخطوط الرابحة فوق البكرات بألوان مختلفة.
class _LinesPainter extends CustomPainter {
  _LinesPainter(this.lines);
  final List<int> lines;

  static const _colors = [Color(0xFFFFE04D), Color(0xFF4DE3FF), Color(0xFFFF5AA8), Color(0xFF7CFF6B), Color(0xFFFF9A3D)];

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 4.0;
    final rw = (size.width - gap * 4) / 5;
    final rh = size.height / 3;
    for (final (k, l) in lines.indexed) {
      final pts = [
        for (var r = 0; r < 5; r++) Offset(r * (rw + gap) + rw / 2, sultanLines[l][r] * rh + rh / 2),
      ];
      final path = Path()..moveTo(0, pts.first.dy);
      for (final p in pts) {
        path.lineTo(p.dx, p.dy);
      }
      path.lineTo(size.width, pts.last.dy);
      final color = _colors[k % _colors.length];
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: .45)..style = PaintingStyle.stroke..strokeWidth = 9..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(_LinesPainter o) => o.lines != lines;
}
