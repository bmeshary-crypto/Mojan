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

  int get _bet => _free > 0 ? _freeBet : sultanBets[_betIndex];

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
    final grid = sultanGrid(_rng);
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
    if (won > 0) {
      Account.instance.earn(won);
      if (res.mult >= 2) {
        Sfx.instance.win();
        Haptics.heavyImpact();
      }
    }
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
      Sfx.instance.win();
      coinToast(context, '🗝️ فتحت الكنز! $sultanFreeSpins لفات مجانية وأرباحها ×$sultanFreeMult');
    }
    if (_auto || _free > 0) {
      final pause = res.coinPay >= 5 || res.mult >= 10 ? 1600 : (unlocked ? 1800 : 500);
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
    return CoinGameScaffold(
      title: 'كنز السلطان',
      colors: const [Color(0xFF3B0A57), Color(0xFF1C0530)],
      inPlay: _spinning || _free > 0,
      leaveMessage: 'عندك لفات شغالة، وإذا خرجت تضيع عليك.',
      onHelp: _paytable,
      child: Column(
        children: [
          _jackpots(),
          _keysBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Center(child: AspectRatio(aspectRatio: 5 / 3.15, child: _board())),
            ),
          ),
          _winBar(),
          _controls(),
        ],
      ),
    );
  }

  Widget _jackpots() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
    child: Row(
      children: [
        for (final (n, name) in sultanJackpots)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: n == 8
                      ? const [Color(0xFFFFE07A), Color(0xFFC77A0A)]
                      : const [Color(0xFF6A1D8E), Color(0xFF3A0F55)],
                ),
                border: Border.all(color: AppColors.gold.withValues(alpha: .7)),
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
                      style: AppTheme.display.copyWith(fontSize: 16, color: n == 8 ? const Color(0xFF4A2600) : AppColors.gold),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _keysBar() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
    child: Row(
      children: [
        for (var i = 0; i < sultanKeysNeeded; i++)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Opacity(
              opacity: i < _keys ? 1 : .25,
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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _free > 0 ? AppColors.gold : Colors.white70),
          ),
        ),
      ],
    ),
  );

  Widget _board() => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(colors: [Color(0xFFFFE07A), Color(0xFFB8741A), Color(0xFFFFE07A)]),
      boxShadow: [BoxShadow(color: (_free > 0 ? AppColors.gold : Colors.black).withValues(alpha: .6), blurRadius: 18)],
    ),
    child: Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF240637),
      ),
      child: SlotReels(
        initial: _initial,
        rows: 3,
        gap: 4,
        controller: _reels,
        symbol: _symbol,
        highlight: _last?.cells(_grid) ?? const {},
        reelDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF3A0F55),
        ),
      ),
    ),
  );

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

  Widget _winBar() {
    final r = _last;
    return SizedBox(
      height: 44,
      child: Center(
        child: _lastWin > 0
            ? Column(
                key: const ValueKey('sultan-win'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ربحت ${fmtCoins(_lastWin)}', style: AppTheme.display.copyWith(fontSize: 22, color: AppColors.gold)),
                  Text(
                    [
                      if (r!.lines.isNotEmpty) '${r.lines.length} خط',
                      if (r.coinPay > 0) '${r.coins} عملات',
                    ].join(' + '),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70),
                  ),
                ],
              ).animate().scale(duration: 350.ms, curve: Curves.elasticOut)
            : Text(
                _spinning ? 'بالتوفيق...' : '20 خط • رهان الخط ${fmtCoins(_bet / 20)}',
                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }

  Widget _controls() {
    final locked = _spinning || _free > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        children: [
          Row(
            children: [
              _round('sultan-minus', Icons.remove_rounded, !locked && _betIndex > 0 ? () => setState(() => _betIndex--) : null),
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
                  child: Text('الرهان ${fmtCoins(_bet)}', key: const ValueKey('sultan-bet'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                ),
              ),
              _round('sultan-plus', Icons.add_rounded, !locked && _betIndex < sultanBets.length - 1 ? () => setState(() => _betIndex++) : null),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _toggle('sultan-fast', '⚡ سريع', _fast, () => setState(() => _fast = !_fast)),
              const SizedBox(width: 8),
              Expanded(
                child: CoinActionButton(
                  key: const ValueKey('sultan-spin'),
                  label: _free > 0 ? 'مجانية ($_free)' : (_spinning ? '...' : 'لف ✨'),
                  color: const Color(0xFFFFC93C),
                  onTap: _spinning || _auto || _free > 0 ? null : _spin,
                ),
              ),
              const SizedBox(width: 8),
              _toggle('sultan-auto', _auto ? '⏹ وقف' : '🔁 تلقائي', _auto, _toggleAuto),
            ],
          ),
        ],
      ),
    );
  }

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
