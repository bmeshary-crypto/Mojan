import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/game_module.dart';
import '../../core/theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/game_ui.dart';
import 'seeko_engine.dart';

const seekoTeamColors = [Color(0xFF2EBD59), Color(0xFF2F8BF5), Color(0xFFF2453D)];

class SeekoScreen extends StatefulWidget {
  const SeekoScreen({super.key, required this.mode});
  final PlayMode mode;

  @override
  State<SeekoScreen> createState() => _SeekoScreenState();
}

class _SeekoScreenState extends State<SeekoScreen> {
  int _players = 2;
  bool _started = false;
  int _key = 0;

  bool get _vsAi => widget.mode == PlayMode.vsComputer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: _started
              ? _SeekoTable(
                  key: ValueKey(_key),
                  playerCount: _players,
                  humans: _vsAi ? {0} : {for (var i = 0; i < _players; i++) i},
                  onRestart: () => setState(() => _key++),
                  onSetup: () => setState(() => _started = false),
                )
              : _setup(),
        ),
      ),
    );
  }

  Widget _setup() {
    return Column(
      children: [
        GameTopBar(title: 'سيكو', subtitle: widget.mode.label),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _RulesCard(),
                    const SizedBox(height: 22),
                    Text(_vsAi ? 'عدد اللاعبين (أنت + الكمبيوتر)' : 'عدد اللاعبين',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    ChoiceRow<int>(
                      options: const [(2, '2'), (3, '3'), (4, '4 (فريقان)')],
                      value: _players,
                      onChanged: (v) => setState(() => _players = v),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _players == 3 ? 'الفوز بصف واحد من 5' : 'الفوز بصفين من 5',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 28),
                    BigButton(
                      label: 'ابدأ اللعب',
                      colors: const [Color(0xFF5CF2B5), AppColors.seeko, Color(0xFF0E9F64)],
                      onTap: () => setState(() => _started = true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.seeko),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4))),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.seeko.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('طريقة اللعب', style: AppTheme.display.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          line(Icons.style_rounded, 'العب ورقة من يدك وضع قطعتك على نفس الورقة في اللوح.'),
          line(Icons.linear_scale_rounded, 'كوّن 5 قطع في صف: أفقي أو عمودي أو مائل. الزوايا حرة للجميع.'),
          line(Icons.auto_awesome_rounded, 'الولد بعينين (♦ ♣) يوضع في أي خانة فارغة.'),
          line(Icons.remove_circle_outline_rounded, 'الولد بعين واحدة (♠ ♥) يزيل قطعة خصم.'),
          line(Icons.autorenew_rounded, 'الورقة الميتة (خاناتها مشغولة) تستبدلها مرة كل دور.'),
        ],
      ),
    );
  }
}

class _SeekoTable extends StatefulWidget {
  const _SeekoTable({
    super.key,
    required this.playerCount,
    required this.humans,
    required this.onRestart,
    required this.onSetup,
  });
  final int playerCount;
  final Set<int> humans;
  final VoidCallback onRestart;
  final VoidCallback onSetup;

  @override
  State<_SeekoTable> createState() => _SeekoTableState();
}

class _SeekoTableState extends State<_SeekoTable> {
  late final SeekoGame game = SeekoGame(playerCount: widget.playerCount);
  int? _selected;
  bool _busy = false;
  bool _disposed = false;
  bool _covered = false;
  Cell? _lastCell;
  Set<Cell> _flash = {};
  String _status = '';

  /// اللاعب الذي نعرض أوراقه (البشري الحالي، أو أول بشري).
  int get _viewer => widget.humans.contains(game.current) ? game.current : widget.humans.first;
  bool get _humanTurn => widget.humans.contains(game.current) && game.phase == SeekoPhase.playing;

  String nameOf(int p) {
    if (widget.humans.length == 1) {
      if (p == 0) return 'أنت';
      return p == 2 && widget.playerCount == 4 ? 'شريكك' : 'كمبيوتر $p';
    }
    return 'لاعب ${p + 1}';
  }

  String teamName(int t) {
    if (widget.playerCount == 4) {
      final members = [for (var p = 0; p < 4; p++) if (game.teamOf(p) == t) nameOf(p)];
      return members.join(' و');
    }
    return nameOf(t);
  }

  @override
  void initState() {
    super.initState();
    _status = _turnText();
    _afterTurnChange(first: true);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String _turnText() =>
      _humanTurn ? (widget.humans.length == 1 ? 'دورك: اختر ورقة' : 'دور ${nameOf(game.current)}: اختر ورقة') : 'دور ${nameOf(game.current)}…';

  void _afterTurnChange({bool first = false}) {
    if (game.phase != SeekoPhase.playing) return;
    if (_humanTurn) {
      if (widget.humans.length > 1 && !first) _covered = true;
      _busy = false;
      setState(() => _status = _turnText());
    } else {
      _busy = true;
      setState(() => _status = _turnText());
      Future.delayed(const Duration(milliseconds: 900), _aiTurn);
    }
  }

  Future<void> _aiTurn() async {
    if (_disposed || game.phase != SeekoPhase.playing) return;
    var a = game.chooseAi();
    if (a.exchange != null) {
      game.exchangeDead(a.exchange!);
      a = game.chooseAi();
      if (a.exchange != null) a = (play: game.legalPlays().first, exchange: null);
    }
    await _apply(a.play!);
  }

  Future<void> _apply(SeekoPlay p) async {
    _busy = true;
    final player = game.current;
    final card = game.hands[player][p.handIndex];
    final res = game.play(p);
    HapticFeedback.mediumImpact();
    _selected = null;
    _lastCell = p.cell;
    final verb = p.type == SeekoActionType.remove ? 'أزال قطعة بـ' : 'لعب';
    setState(() => _status = '${nameOf(player)} $verb ${card.rank}${card.symbol}');
    await Future.delayed(const Duration(milliseconds: 500));
    if (_disposed) return;

    if (res.newSequences.isNotEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _flash = res.newSequences.expand((s) => s).toSet();
        _status = '🎉 صف كامل لـ${teamName(game.teamOf(player))}!';
      });
      await Future.delayed(const Duration(milliseconds: 1300));
      if (_disposed) return;
      setState(() => _flash = {});
    }

    if (game.phase == SeekoPhase.gameOver) {
      _showResults();
      return;
    }
    _afterTurnChange();
  }

  void _onCardTap(int i) {
    if (_busy || !_humanTurn) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = _selected == i ? null : i);
  }

  void _onCellTap(Cell cell) {
    if (_busy || !_humanTurn || _selected == null) return;
    final card = game.hands[game.current][_selected!];
    final type = card.isOneEyedJack ? SeekoActionType.remove : SeekoActionType.place;
    final p = SeekoPlay(handIndex: _selected!, cell: cell, type: type);
    if (game.isLegal(p)) _apply(p);
  }

  void _exchange() {
    if (_selected == null || !game.canExchange(_selected!)) return;
    final old = game.hands[game.current][_selected!];
    final drawn = game.exchangeDead(_selected!);
    setState(() {
      _selected = null;
      _status = 'استبدلت ${old.rank}${old.symbol} بـ ${drawn.rank}${drawn.symbol}';
    });
  }

  void _showResults() {
    final w = game.winner;
    final humanWon = w != null && widget.humans.any((p) => game.teamOf(p) == w);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GameResultDialog(
        emoji: w == null ? '🤝' : (humanWon || widget.humans.length > 1 ? '🏆' : '🃏'),
        title: w == null ? 'تعادل!' : '${teamName(w)} ${w == 0 && widget.humans.length == 1 && widget.playerCount != 4 ? 'فزت' : 'فاز'}!',
        rows: [
          for (var t = 0; t < game.teamCount; t++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: seekoTeamColors[t].withValues(alpha: .25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _Chip(team: t, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(teamName(t), style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text('${game.sequenceCount[t]} صف', style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
        ],
        onAgain: () {
          Navigator.pop(ctx);
          widget.onRestart();
        },
        onHome: () {
          Navigator.pop(ctx);
          Navigator.maybePop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            GameTopBar(
              title: 'سيكو',
              trailing: IconButton(onPressed: widget.onSetup, icon: const Icon(Icons.tune_rounded)),
            ),
            _scores(),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final size = min(c.maxWidth - 16, c.maxHeight - 150).clamp(260.0, 640.0);
                return Column(
                  children: [
                    const SizedBox(height: 6),
                    _board(size),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: 250.ms,
                      child: Text(_status,
                          key: ValueKey(_status),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    const Spacer(),
                    _hand(min(c.maxWidth, 640)),
                    const SizedBox(height: 8),
                  ],
                );
              }),
            ),
          ],
        ),
        if (_covered)
          Positioned.fill(
            child: PassDeviceCover(
              name: nameOf(game.current),
              color: seekoTeamColors[game.currentTeam],
              onReady: () => setState(() => _covered = false),
            ),
          ),
      ],
    );
  }

  Widget _scores() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (var p = 0; p < widget.playerCount; p++)
            Expanded(
              child: AnimatedContainer(
                duration: 300.ms,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: game.current == p ? seekoTeamColors[game.teamOf(p)].withValues(alpha: .35) : Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: game.current == p ? seekoTeamColors[game.teamOf(p)] : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Chip(team: game.teamOf(p), size: 16),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(nameOf(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    Text('${game.sequenceCount[game.teamOf(p)]}/${game.sequencesToWin}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.gold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _board(double size) {
    final targets = <Cell>{};
    if (_humanTurn && _selected != null && !_busy) {
      targets.addAll(game.targetsFor(game.hands[game.current][_selected!], game.currentTeam));
    }
    final cell = (size - 16) / SeekoBoard.size; // حشوة 6 + إطار 2 من كل جهة
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [Color(0xFF0F6B47), Color(0xFF0A4A31)]),
          border: Border.all(color: AppColors.gold.withValues(alpha: .6), width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))],
        ),
        child: Column(
          children: [
            for (var r = 0; r < SeekoBoard.size; r++)
              Row(
                children: [
                  for (var c = 0; c < SeekoBoard.size; c++)
                    SizedBox(
                      width: cell,
                      height: cell,
                      child: GestureDetector(
                        onTap: () => _onCellTap((r, c)),
                        child: SeekoBoardCell(
                          cell: (r, c),
                          team: game.chips[r][c],
                          locked: game.locked.contains((r, c)),
                          target: targets.contains((r, c)),
                          last: _lastCell == (r, c),
                          flash: _flash.contains((r, c)),
                          size: cell,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _hand(double width) {
    final hand = game.hands[_viewer];
    final cardW = min(64.0, (width - 24) / max(hand.length, 1) - 6);
    final canAct = _humanTurn && !_busy;
    final selCard = _selected != null && _selected! < hand.length ? hand[_selected!] : null;
    final dead = selCard != null && canAct && game.canExchange(_selected!);
    return Column(
      children: [
        AnimatedSwitcher(
          duration: 200.ms,
          child: dead
              ? TextButton.icon(
                  key: const ValueKey('dead'),
                  onPressed: _exchange,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bgTop,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: const Icon(Icons.autorenew_rounded),
                  label: const Text('ورقة ميتة: استبدلها', style: TextStyle(fontWeight: FontWeight.w900)),
                )
              : Text(
                  selCard == null
                      ? (canAct ? 'اختر ورقة من يدك' : 'أوراقك')
                      : selCard.isTwoEyedJack
                          ? 'ولد بعينين: ضعه في أي خانة فارغة'
                          : selCard.isOneEyedJack
                              ? 'ولد بعين واحدة: اختر قطعة خصم لإزالتها'
                              : 'اختر خانة مضيئة على اللوح',
                  key: ValueKey('${selCard?.code}'),
                  style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(height: 20),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < hand.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => _onCardTap(i),
                    child: AnimatedContainer(
                      duration: 200.ms,
                      curve: Curves.easeOutBack,
                      transform: Matrix4.translationValues(0, _selected == i ? -14 : 0, 0),
                      child: CardFace(
                        card: hand[i],
                        width: cardW,
                        selected: _selected == i,
                        dimmed: !canAct,
                      ),
                    ),
                  ).animate(key: ValueKey('${hand[i].code}-$i')).fadeIn(duration: 250.ms).slideY(begin: .4, end: 0),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.team, required this.size, this.locked = false});
  final int team;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final c = seekoTeamColors[team];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: size * .2, offset: Offset(0, size * .08))],
      ),
      foregroundDecoration: locked
          ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.gold, width: max(1.5, size * .12)))
          : null,
      child: Image.asset(
        'assets/images/chip_$team.webp',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-.3, -.4),
              colors: [Color.lerp(c, Colors.white, .45)!, c, Color.lerp(c, Colors.black, .35)!],
            ),
            border: Border.all(color: Colors.white, width: max(1.5, size * .1)),
          ),
        ),
      ),
    );
  }
}

class SeekoBoardCell extends StatelessWidget {
  const SeekoBoardCell({
    super.key,
    required this.cell,
    required this.team,
    required this.locked,
    required this.target,
    required this.last,
    required this.flash,
    required this.size,
  });
  final Cell cell;
  final int? team;
  final bool locked, target, last, flash;
  final double size;

  @override
  Widget build(BuildContext context) {
    final card = SeekoBoard.cardAt(cell);
    Widget face;
    if (card == null) {
      face = Container(
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(size * .12),
        ),
        child: Icon(Icons.star_rounded, color: Colors.white, size: size * .7),
      );
    } else {
      final color = card.isRed ? const Color(0xFFD62839) : const Color(0xFF1A1033);
      face = Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * .12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(card.rank,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w900, fontSize: size * .34, height: 1, fontFamily: 'Cairo')),
            Text(card.symbol, style: TextStyle(color: color, fontSize: size * .34, height: 1)),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(size * .04),
      child: Stack(
        fit: StackFit.expand,
        children: [
          face,
          if (target)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * .12),
                color: AppColors.gold.withValues(alpha: .35),
                border: Border.all(color: AppColors.gold, width: 2.5),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: .45, end: 1, duration: 500.ms),
          if (team != null)
            Center(
              child: _Chip(team: team!, size: size * .78, locked: locked)
                  .animate(key: ValueKey('$team-${cell.$1}-${cell.$2}'))
                  .scale(begin: const Offset(1.8, 1.8), end: const Offset(1, 1), duration: 350.ms, curve: Curves.bounceOut)
                  .fadeIn(duration: 150.ms),
            ),
          if (last)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * .12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          if (flash)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * .12),
                  color: AppColors.gold.withValues(alpha: .6),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 250.ms),
            ),
        ],
      ),
    );
  }
}

/// وجه ورقة في اليد.
class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.card, required this.width, this.selected = false, this.dimmed = false});
  final SeekoCard card;
  final double width;
  final bool selected;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.4;
    final color = card.isRed ? const Color(0xFFD62839) : const Color(0xFF1A1033);
    return AnimatedOpacity(
      duration: 200.ms,
      opacity: dimmed ? .7 : 1,
      child: Container(
        width: width,
        height: h,
        padding: EdgeInsets.all(width * .08),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(width * .14),
          border: Border.all(color: selected ? AppColors.gold : Colors.white, width: selected ? 3 : 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: .4), blurRadius: 8, offset: const Offset(0, 4)),
            if (selected) BoxShadow(color: AppColors.gold.withValues(alpha: .8), blurRadius: 14),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.rank,
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: width * .3, height: 1)),
            Expanded(
              child: Center(
                child: card.isJack
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(card.symbol, style: TextStyle(color: color, fontSize: width * .32, height: 1)),
                          Text(card.isTwoEyedJack ? '👀' : '👁',
                              style: TextStyle(fontSize: width * .22, height: 1.2)),
                        ],
                      )
                    : Text(card.symbol, style: TextStyle(color: color, fontSize: width * .5, height: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
