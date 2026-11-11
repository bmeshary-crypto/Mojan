import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/game_module.dart';
import '../../core/theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/bouncy_button.dart';
import 'ludo_board.dart';
import 'ludo_engine.dart';
import '../../core/haptics.dart';
import '../../widgets/account_widgets.dart';
import '../../core/account/account.dart';

/// شاشة لعبة لودو: إعداد سريع ثم اللوح.
class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key, required this.mode});
  final PlayMode mode;

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> {
  int _players = 2;
  bool _quick = false;
  bool _started = false;
  int _gameKey = 0;

  bool get _vsAi => widget.mode == PlayMode.vsComputer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: _started
              ? _LudoTable(
                  key: ValueKey(_gameKey),
                  players: _playerColors,
                  humans: _vsAi ? {LudoColor.red} : _playerColors.toSet(),
                  rules: LudoRules(tokensPerPlayer: _quick ? 2 : 4),
                  onRestart: () => setState(() => _gameKey++),
                  onSetup: () => setState(() => _started = false),
                )
              : _setup(context),
        ),
      ),
    );
  }

  List<LudoColor> get _playerColors => switch (_players) {
        2 => const [LudoColor.red, LudoColor.yellow],
        3 => const [LudoColor.red, LudoColor.green, LudoColor.yellow],
        _ => LudoColor.values,
      };

  Widget _setup(BuildContext context) {
    Widget choice(String label, bool selected, VoidCallback onTap) => Expanded(
          child: BouncyButton(
            tilt: false,
            onTap: onTap,
            child: AnimatedContainer(
              duration: 250.ms,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.gold : Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected ? AppColors.gold : Colors.white24),
              ),
              child: Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: selected ? AppColors.bgTop : Colors.white,
                  )),
            ),
          ),
        );

    return Column(
      children: [
        _BackBar(title: 'لودو', subtitle: widget.mode.label),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: SizedBox(
                        width: 150,
                        height: 150,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: CustomPaint(painter: LudoBoardPainter(active: _playerColors.toSet())),
                          ),
                        ),
                      ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms),
                    ),
                    const SizedBox(height: 24),
                    Text(_vsAi ? 'عدد اللاعبين (أنت + الكمبيوتر)' : 'عدد اللاعبين',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    Row(children: [
                      for (final n in [2, 3, 4]) ...[
                        choice('$n', _players == n, () => setState(() => _players = n)),
                        if (n != 4) const SizedBox(width: 10),
                      ],
                    ]),
                    const SizedBox(height: 20),
                    const Text('نوع اللعبة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    Row(children: [
                      choice('كلاسيك (4 قطع)', !_quick, () => setState(() => _quick = false)),
                      const SizedBox(width: 10),
                      choice('سريع (قطعتان)', _quick, () => setState(() => _quick = true)),
                    ]),
                    const SizedBox(height: 32),
                    BouncyButton(
                      tilt: false,
                      onTap: () => setState(() => _started = true),
                      child: Container(
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B85), AppColors.ludo, Color(0xFFC9184A)]),
                          border: const Border(bottom: BorderSide(color: Color(0xFF8A0F33), width: 5)),
                          boxShadow: [BoxShadow(color: AppColors.ludo.withValues(alpha: .5), blurRadius: 20)],
                        ),
                        child: const Text('ابدأ اللعب',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 1, end: 1.03, duration: 900.ms),
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

class _BackBar extends StatelessWidget {
  const _BackBar({required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 28),
          ),
          Text(title, style: AppTheme.display.copyWith(fontSize: 28)),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(subtitle!, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// طاولة اللعب نفسها.
class _LudoTable extends StatefulWidget {
  const _LudoTable({
    super.key,
    required this.players,
    required this.humans,
    required this.rules,
    required this.onRestart,
    required this.onSetup,
  });
  final List<LudoColor> players;
  final Set<LudoColor> humans;
  final LudoRules rules;
  final VoidCallback onRestart;
  final VoidCallback onSetup;

  @override
  State<_LudoTable> createState() => _LudoTableState();
}

class _LudoTableState extends State<_LudoTable> {
  late final LudoGame game = LudoGame(players: widget.players, rules: widget.rules);
  final _rng = Random();

  /// مواقع مؤقتة للقطع أثناء الأنميشن (القطعة تمشي خانة خانة).
  final Map<LudoToken, int> _shown = {};
  bool _busy = false;
  bool _rolling = false;
  int _diceFace = 6;
  String _status = '';
  LudoToken? _hopping;
  bool _disposed = false;

  bool get _humanTurn => widget.humans.contains(game.current);

  String _nameOf(LudoColor c) {
    if (widget.humans.length == 1) {
      if (widget.humans.contains(c)) return 'أنت';
      final aiIndex = widget.players.where((p) => !widget.humans.contains(p)).toList().indexOf(c) + 1;
      return 'كمبيوتر $aiIndex';
    }
    return 'لاعب ${ludoNames[c]}';
  }

  @override
  void initState() {
    super.initState();
    _status = _turnText();
    _scheduleAi();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _wait(int ms) => Future.delayed(Duration(milliseconds: ms));

  String _turnText() => _humanTurn
      ? (widget.humans.length == 1 ? 'دورك! اضغط على النرد' : 'دور ${_nameOf(game.current)}: اضغط على النرد')
      : 'دور ${_nameOf(game.current)}…';

  void _scheduleAi() {
    if (!_humanTurn && game.phase == LudoPhase.waitingRoll) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!_disposed && !_humanTurn && game.phase == LudoPhase.waitingRoll && !_busy) _roll();
      });
    }
  }

  Future<void> _roll() async {
    if (_busy || game.phase != LudoPhase.waitingRoll) return;
    _busy = true;
    Haptics.mediumImpact();
    setState(() => _rolling = true);
    for (var i = 0; i < 8; i++) {
      await _wait(70);
      if (_disposed) return;
      setState(() => _diceFace = _rng.nextInt(6) + 1);
    }
    final player = game.current;
    final hasMoves = game.roll();
    if (_disposed) return;
    setState(() {
      _rolling = false;
      _diceFace = game.dice!;
    });

    if (!hasMoves) {
      final threeSixes = game.dice == 6;
      setState(() => _status = threeSixes ? 'ثلاث ستات! خسرت الدور' : 'لا توجد حركة متاحة');
      await _wait(900);
      if (_disposed) return;
      _busy = false;
      setState(() => _status = _turnText());
      _scheduleAi();
      return;
    }

    if (!widget.humans.contains(player)) {
      await _wait(450);
      if (_disposed) return;
      await _doMove(game.chooseAiMove());
      return;
    }

    // لاعب بشري: حركة تلقائية إن كانت كل الخيارات متطابقة
    final moves = game.legalMoves;
    final distinct = moves.map((m) => '${m.from}').toSet();
    if (moves.length == 1 || distinct.length == 1) {
      await _wait(300);
      if (_disposed) return;
      await _doMove(moves.first);
      return;
    }
    _busy = false;
    setState(() => _status = 'اختر القطعة التي تريد تحريكها');
  }

  Future<void> _doMove(LudoMove m) async {
    _busy = true;
    final before = {for (final t in game.allTokens) t: t.pos};
    final result = game.move(m);
    // نعرض الحالة القديمة ثم نحرك خطوة خطوة
    _shown
      ..clear()
      ..addAll(before);
    _hopping = m.token;
    setState(() {});
    for (final p in m.path) {
      _shown[m.token] = p;
      Haptics.selectionClick();
      setState(() {});
      await _wait(170);
      if (_disposed) return;
    }
    _hopping = null;
    for (final c in result.captured) {
      _shown.remove(c);
    }
    if (result.captured.isNotEmpty) {
      Haptics.heavyImpact();
      setState(() => _status = '${_nameOf(m.token.color)} أكل قطعة ${_nameOf(result.captured.first.color)}!');
      await _wait(700);
      if (_disposed) return;
    }
    _shown.clear();
    setState(() {});

    if (game.phase == LudoPhase.gameOver) {
      await _wait(400);
      if (!_disposed) _showResults();
      return;
    }
    if (result.playerFinished) {
      setState(() => _status = '${_nameOf(m.token.color)} أنهى كل القطع!');
      await _wait(900);
    } else if (result.extraTurn) {
      setState(() => _status = '${_nameOf(game.current)} يلعب مرة أخرى');
      await _wait(500);
    }
    if (_disposed) return;
    _busy = false;
    setState(() => _status = _turnText());
    _scheduleAi();
  }

  void _onTokenTap(LudoToken t) {
    if (_busy || !_humanTurn || game.phase != LudoPhase.waitingMove) return;
    final m = game.legalMoves.where((m) => m.token == t).firstOrNull;
    if (m != null) _doMove(m);
  }

  void _showResults() {
    final solo = widget.humans.length == 1;
    final place = solo ? game.ranking.indexOf(widget.humans.first) : -1;
    final reward = Account.instance.recordGame(
      'ludo',
      won: solo && place == 0,
      points: solo && place >= 0 ? const [400, 200, 100, 0][place.clamp(0, 3)] : 0,
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResultsDialog(
        reward: reward,
        ranking: game.ranking,
        nameOf: _nameOf,
        humanWon: widget.humans.contains(game.ranking.first),
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
    return Column(
      children: [
        _BackBar(
          title: 'لودو',
          trailing: IconButton(
            tooltip: 'إعدادات اللعبة',
            onPressed: widget.onSetup,
            icon: const Icon(Icons.tune_rounded),
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final boardSize = min(c.maxWidth - 24, c.maxHeight - 210).clamp(240.0, 640.0);
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: SizedBox(
                  width: boardSize,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _playersRow(LudoColor.green, LudoColor.yellow),
                      const SizedBox(height: 10),
                      _board(boardSize),
                      const SizedBox(height: 10),
                      _playersRow(LudoColor.red, LudoColor.blue),
                      const SizedBox(height: 14),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: AnimatedSwitcher(
                          duration: 250.ms,
                          child: Text(
                            _status,
                            key: ValueKey(_status),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _playersRow(LudoColor left, LudoColor right) {
    return Row(
      children: [
        Expanded(child: _panel(left, alignEnd: false)),
        const SizedBox(width: 10),
        Expanded(child: _panel(right, alignEnd: true)),
      ],
    );
  }

  Widget _panel(LudoColor c, {required bool alignEnd}) {
    if (!widget.players.contains(c)) return const SizedBox(height: 64);
    final active = game.current == c && game.phase != LudoPhase.gameOver;
    final color = ludoColors[c]!;
    final done = game.tokens[c]!.where((t) => t.finished).length;
    final isHuman = widget.humans.contains(c);

    final avatar = AnimatedContainer(
      duration: 300.ms,
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : Colors.white24,
        boxShadow: active ? [BoxShadow(color: color, blurRadius: 16)] : null,
      ),
      child: CircleAvatar(
        backgroundColor: Color.lerp(color, Colors.black, .35),
        child: Icon(isHuman ? Icons.face_rounded : Icons.smart_toy_rounded, color: Colors.white),
      ),
    );

    final info = Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_nameOf(c),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          Text('🏁 $done/${widget.rules.tokensPerPlayer}',
              maxLines: 1,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
        ],
      ),
    );

    final dice = active ? _dice(isHuman) : const SizedBox(width: 52);

    final children = [avatar, const SizedBox(width: 6), Expanded(child: info), dice];
    return SizedBox(
      height: 64,
      child: Row(children: alignEnd ? children.reversed.toList() : children),
    );
  }

  Widget _dice(bool isHuman) {
    final canTap = isHuman && !_busy && game.phase == LudoPhase.waitingRoll;
    Widget d = DiceFace(value: _diceFace, size: 46);
    if (_rolling) {
      d = d
          .animate(onPlay: (c) => c.repeat())
          .rotate(duration: 280.ms, begin: 0, end: 1)
          .scaleXY(begin: .9, end: 1.1, duration: 140.ms)
          .then()
          .scaleXY(begin: 1.1, end: .9, duration: 140.ms);
    } else if (canTap) {
      d = d.animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: -5, duration: 450.ms).scaleXY(
            begin: 1,
            end: 1.08,
            duration: 450.ms,
          );
    }
    return GestureDetector(
      onTap: canTap ? _roll : null,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: canTap
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .7), blurRadius: 14)],
              )
            : null,
        child: d,
      ),
    );
  }

  Widget _board(double size) {
    final movable = (_humanTurn && game.phase == LudoPhase.waitingMove && !_busy)
        ? game.legalMoves.map((m) => m.token).toSet()
        : <LudoToken>{};

    // تجميع القطع حسب الخانة لترتيب المتراكب منها
    final positions = <LudoToken, Offset>{};
    final groups = <String, List<LudoToken>>{};
    for (final t in game.allTokens) {
      final pos = _shown[t] ?? t.pos;
      final ctr = LudoLayout.tokenCenter(t.color, t.id, pos);
      positions[t] = ctr;
      if (pos != LudoGeo.yard) groups.putIfAbsent('${ctr.dx},${ctr.dy}', () => []).add(t);
    }

    final sorted = game.allTokens.toList()
      ..sort((a, b) {
        int rank(LudoToken t) => t == _hopping ? 2 : (movable.contains(t) ? 1 : 0);
        return rank(a).compareTo(rank(b));
      });

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .025),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .05),
        gradient: const LinearGradient(colors: [Color(0xFFA9713D), Color(0xFF7A4A22)]),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .03),
        child: LayoutBuilder(builder: (context, c) {
          final inner = c.maxWidth;
          final cs = inner / LudoLayout.grid;
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: LudoBoardPainter(active: widget.players.toSet()))),
              for (final t in sorted) _tokenWidget(t, positions[t]!, groups, cs, movable.contains(t)),
            ],
          );
        }),
      ),
    ).animate().fadeIn(duration: 400.ms).scaleXY(begin: .9, end: 1, curve: Curves.easeOutBack, duration: 500.ms);
  }

  Widget _tokenWidget(LudoToken t, Offset ctr, Map<String, List<LudoToken>> groups, double cs, bool movable) {
    final group = groups['${ctr.dx},${ctr.dy}'];
    var size = cs * .82;
    var offset = Offset.zero;
    if (group != null && group.length > 1) {
      final i = group.indexOf(t);
      size = cs * .6;
      const spread = [Offset(-.2, -.2), Offset(.2, -.2), Offset(-.2, .2), Offset(.2, .2)];
      offset = spread[i % 4] * cs;
    }
    if (t.inYard && !_shown.containsKey(t)) size = cs * 1.0;
    final center = ctr * cs + offset;
    final hopping = t == _hopping;

    Widget pawn = LudoPawn(color: t.color, size: size, highlight: movable);
    if (movable) {
      pawn = pawn
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -cs * .18, duration: 380.ms, curve: Curves.easeInOut);
    }
    if (hopping) {
      pawn = pawn.animate(key: ValueKey(_shown[t])).scaleXY(begin: 1.25, end: 1, duration: 160.ms);
    }

    return AnimatedPositioned(
      key: ValueKey('${t.color}-${t.id}'),
      duration: Duration(milliseconds: hopping ? 150 : 450),
      curve: hopping ? Curves.easeOut : Curves.easeInOutBack,
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTokenTap(t),
        child: pawn,
      ),
    );
  }
}

class _ResultsDialog extends StatelessWidget {
  const _ResultsDialog({
    required this.ranking,
    required this.nameOf,
    required this.humanWon,
    required this.onAgain,
    required this.onHome,
    this.reward,
  });
  final Reward? reward;
  final List<LudoColor> ranking;
  final String Function(LudoColor) nameOf;
  final bool humanWon;
  final VoidCallback onAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    const medals = ['🥇', '🥈', '🥉', '4'];
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.gold, width: 2),
          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .4), blurRadius: 30)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(humanWon ? '🏆' : '🎲', style: const TextStyle(fontSize: 56))
                .animate()
                .scale(duration: 700.ms, curve: Curves.elasticOut, begin: Offset.zero),
            Text(
              '${nameOf(ranking.first)} ${nameOf(ranking.first) == 'أنت' ? 'فزت' : 'فاز'}!',
              style: AppTheme.display.copyWith(fontSize: 32, color: AppColors.gold),
            ),
            const SizedBox(height: 14),
            for (final (i, c) in ranking.indexed)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: ludoColors[c]!.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text(medals[i], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 10),
                    LudoPawn(color: c, size: 24),
                    const SizedBox(width: 10),
                    Text(nameOf(c), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ).animate().fadeIn(delay: (200 + i * 120).ms).slideX(begin: .3, end: 0),
            if (reward != null) ...[const SizedBox(height: 6), RewardBanner(reward: reward!)],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgTop,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onAgain,
                    child: const Text('العب مرة أخرى', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onHome,
                    child: const Text('الرئيسية', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
