import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/haptics.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import 'coin_ui.dart';

/// صعوبة صناديق الكنز: عدد الصناديق في كل طابق، وواحد منها فيه الوحش.
enum TreasureLevel {
  easy('سهل', 4),
  medium('متوسط', 3),
  hard('صعب', 2);

  const TreasureLevel(this.label, this.boxes);
  final String label;
  final int boxes;

  /// المضاعف بعد [step] خطوات ناجحة. العائد المتوقع ≈97% مهما كان وقت الانسحاب.
  double multAt(int step) {
    if (step <= 0) return 1;
    final survive = (boxes - 1) / boxes;
    return (0.97 * pow(1 / survive, step) * 100).floor() / 100;
  }
}

const treasureFloors = 10;

/// صناديق الكنز: افتح صندوقاً في كل طابق، واسحب أرباحك قبل أن يطلع لك الوحش.
class TreasureScreen extends StatefulWidget {
  const TreasureScreen({super.key, this.random});
  final Random? random;

  @override
  State<TreasureScreen> createState() => _TreasureScreenState();
}

class _TreasureScreenState extends State<TreasureScreen> {
  late final Random _rng = widget.random ?? Random();
  TreasureLevel _level = TreasureLevel.medium;
  int _chip = 100;

  bool _playing = false;
  int _bet = 0;
  int _step = 0;

  /// مكان الوحش في كل طابق (يُحدد عند بداية الجولة).
  List<int> _monsters = [];

  /// الصندوق الذي اختاره اللاعب في كل طابق.
  final Map<int, int> _picked = {};
  bool _revealAll = false;
  String? _outcome;

  double get _mult => _level.multAt(_step);
  int get _cashout => (_bet * _mult).floor();

  void _start() {
    if (!takeBet(context, _chip)) return;
    Haptics.mediumImpact();
    setState(() {
      _playing = true;
      _bet = _chip;
      _step = 0;
      _picked.clear();
      _revealAll = false;
      _outcome = null;
      _monsters = [for (var i = 0; i < treasureFloors; i++) _rng.nextInt(_level.boxes)];
    });
  }

  void _open(int floor, int box) {
    if (!_playing || floor != _step) return;
    setState(() => _picked[floor] = box);
    if (_monsters[floor] == box) {
      Sfx.instance.lose();
      Haptics.heavyImpact();
      Account.instance.recordCoinRound('treasure', bet: _bet, won: 0);
      setState(() {
        _playing = false;
        _revealAll = true;
        _outcome = 'طلع لك الوحش 👹 خسرت ${fmtCoins(_bet)}';
      });
      return;
    }
    Sfx.instance.tone(660, 990, .15, type: 'triangle', vol: .14);
    Haptics.selectionClick();
    setState(() => _step++);
    if (_step == treasureFloors) _cashOut();
  }

  void _cashOut() {
    if (!_playing || _step == 0) return;
    final pay = _cashout;
    Account.instance.earn(pay);
    Account.instance.recordCoinRound('treasure', bet: _bet, won: pay);
    Sfx.instance.win();
    setState(() {
      _playing = false;
      _revealAll = true;
      _outcome = 'سحبت ${fmtCoins(pay)} 🎉 (${fmtMult(_mult)})';
    });
  }

  @override
  Widget build(BuildContext context) {
    return CoinGameScaffold(
      title: 'صناديق الكنز',
      colors: const [Color(0xFF6B3A12), Color(0xFF3D2410)],
      inPlay: _playing,
      leaveMessage: 'عندك جولة مفتوحة، وإذا خرجت يضيع رهانك. اسحب أرباحك أولاً.',
      onHelp: () => showHowTo(
        context,
        'صناديق الكنز',
        'اختر الرهان والصعوبة واضغط "ابدأ". في كل طابق صندوق واحد فيه وحش والباقي كنز. '
            'كل صندوق كنز تفتحه يكبّر المضاعف. تقدر تسحب أرباحك في أي وقت، '
            'لكن لو فتحت صندوق الوحش يضيع رهان الجولة كله.\n\n'
            'سهل: 4 صناديق وفيها وحش واحد.\nمتوسط: 3 صناديق.\nصعب: صندوقان، وأرباحه تتضاعف أسرع.',
      ),
      child: Column(
        children: [
          Expanded(child: _tower()),
          if (_outcome != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(_outcome!, key: const ValueKey('treasure-outcome'), style: AppTheme.display.copyWith(fontSize: 22, color: AppColors.gold)),
            ).animate().fadeIn().scale(),
          if (!_playing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SegmentedButton<TreasureLevel>(
                segments: [for (final l in TreasureLevel.values) ButtonSegment(value: l, label: Text(l.label, style: const TextStyle(fontWeight: FontWeight.w800)))],
                selected: {_level},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _level = s.first;
                  _picked.clear();
                  _revealAll = false;
                  _outcome = null;
                  _monsters = [];
                  _step = 0;
                }),
              ),
            ),
            BetChips(value: _chip, onChanged: (v) => setState(() => _chip = v)),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: _playing
                ? CoinActionButton(
                    key: const ValueKey('treasure-cashout'),
                    label: _step == 0 ? 'افتح أول صندوق' : 'اسحب ${fmtCoins(_cashout)}',
                    sub: _step == 0 ? null : 'المضاعف الحالي ${fmtMult(_mult)}',
                    color: const Color(0xFF2EE59D),
                    onTap: _step == 0 ? null : _cashOut,
                  )
                : CoinActionButton(
                    key: const ValueKey('treasure-start'),
                    label: 'ابدأ بـ ${fmtCoins(_chip)}',
                    onTap: _start,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tower() => LayoutBuilder(
    builder: (context, c) {
      final rowH = ((c.maxHeight - 16) / treasureFloors).clamp(30.0, 64.0);
      return ListView(
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        children: [for (var f = 0; f < treasureFloors; f++) SizedBox(height: rowH, child: _floor(f))],
      );
    },
  );

  Widget _floor(int f) {
    final active = _playing && f == _step;
    final passed = f < _step;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              fmtMult(_level.multAt(f + 1)),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: active ? AppColors.gold : (passed ? const Color(0xFF2EE59D) : Colors.white54),
              ),
            ),
          ),
          for (var b = 0; b < _level.boxes; b++)
            Expanded(
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _box(f, b, active)),
            ),
        ],
      ),
    );
  }

  Widget _box(int f, int b, bool active) {
    final picked = _picked[f] == b;
    final known = _monsters.isNotEmpty && (picked || _revealAll);
    final monster = _monsters.isNotEmpty && _monsters[f] == b;
    String face = '🧰';
    if (known) face = monster ? '👹' : '💎';
    return GestureDetector(
      key: ValueKey('box-$f-$b'),
      onTap: active ? () => _open(f, b) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: known
              ? (monster ? const Color(0xFFFF5A5F).withValues(alpha: picked ? .8 : .35) : const Color(0xFF2EE59D).withValues(alpha: picked ? .55 : .2))
              : (active ? const Color(0xFFFFC23D).withValues(alpha: .35) : Colors.black.withValues(alpha: .25)),
          border: Border.all(color: active ? AppColors.gold : Colors.white12, width: active ? 2 : 1),
        ),
        child: FittedBox(child: Padding(padding: const EdgeInsets.all(3), child: Text(face, style: TextStyle(fontSize: 26, color: Colors.white.withValues(alpha: active || known ? 1 : .5))))),
      ),
    );
  }
}
