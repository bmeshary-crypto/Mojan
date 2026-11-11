import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/game_module.dart';
import '../../core/theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/bouncy_button.dart';
import '../../widgets/game_ui.dart';
import 'truth_dare_content.dart';
import 'truth_dare_engine.dart';
import '../../core/haptics.dart';
import '../../core/account/account.dart';

const _blue = AppColors.truth;
const _red = AppColors.dare;

class TruthDareScreen extends StatefulWidget {
  const TruthDareScreen({super.key, required this.mode});
  final PlayMode mode;

  @override
  State<TruthDareScreen> createState() => _TruthDareScreenState();
}

enum _Stage { setup, spin, choose, prompt }

class _TruthDareScreenState extends State<TruthDareScreen> with SingleTickerProviderStateMixin {
  final List<String> _names = ['لاعب 1', 'لاعب 2'];
  final List<String> _customTruths = [];
  final List<String> _customDares = [];
  final _nameCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  TdLevel _level = TdLevel.friends;

  TruthDareGame? _game;
  _Stage _stage = _Stage.setup;
  final _rng = Random();

  late final AnimationController _spinCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  double _angleFrom = 0, _angleTo = 0;
  bool _spinning = false;
  bool _recorded = false;
  String? _penalty;

  @override
  void dispose() {
    _spinCtrl.dispose();
    _nameCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  void _addName() {
    final n = _nameCtrl.text.trim();
    if (n.isEmpty || _names.length >= 12) return;
    setState(() {
      _names.add(n);
      _nameCtrl.clear();
    });
  }

  void _start() {
    if (_names.length < 2) return;
    setState(() {
      _recorded = false;
      _game = TruthDareGame(
        names: _names,
        level: _level,
        customTruths: _customTruths,
        customDares: _customDares,
      );
      _stage = _Stage.spin;
      _angleFrom = _angleTo = 0;
    });
  }

  double _playerAngle(int i, int n) => 2 * pi * i / n - pi / 2;

  Future<void> _spin() async {
    final g = _game!;
    if (_spinning || _stage != _Stage.spin) return;
    Haptics.mediumImpact();
    final target = g.spin();
    final n = g.players.length;
    // الزجاجة ترسم متجهة للأعلى، فنديرها لتشير للاعب
    final targetAngle = _playerAngle(target, n) + pi / 2;
    final base = _angleTo - (_angleTo % (2 * pi));
    setState(() {
      _spinning = true;
      _angleFrom = _angleTo;
      _angleTo = base + (4 + _rng.nextInt(3)) * 2 * pi + targetAngle;
    });
    await _spinCtrl.forward(from: 0);
    if (!mounted) return;
    Haptics.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _spinning = false;
      _stage = _Stage.choose;
    });
  }

  void _choose(TdChoice c) {
    Haptics.selectionClick();
    setState(() {
      _game!.draw(c);
      _penalty = null;
      _stage = _Stage.prompt;
    });
  }

  void _resolve(bool completed) {
    if (!completed && _penalty == null) {
      setState(() => _penalty = tdPenalties[_rng.nextInt(tdPenalties.length)]);
      return;
    }
    setState(() {
      _game!.resolve(completed: completed);
      _penalty = null;
      _stage = _Stage.spin;
    });
  }

  void _finish() {
    final g = _game!;
    final board = g.leaderboard;
    final reward = _recorded ? null : Account.instance.recordGame('truth_dare', won: false);
    _recorded = true;
    showDialog(
      context: context,
      builder: (ctx) => GameResultDialog(
        reward: reward,
        emoji: '🏆',
        title: '${board.first.name} الأشجع!',
        rows: [
          for (final (i, p) in board.indexed)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: i == 0 ? .18 : .07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text('✓${p.done}  ✗${p.refused}  ', style: TextStyle(color: AppColors.textMuted)),
                  Text('${p.score}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
                ],
              ),
            ),
        ],
        onAgain: () {
          Navigator.pop(ctx);
          _start();
        },
        onHome: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: 450.ms,
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(a), child: child),
            ),
            child: KeyedSubtree(
              key: ValueKey(_stage),
              child: LeaveGuard(
                enabled: _stage != _Stage.setup,
                message: 'اللعبة ما خلصت، وإذا خرجت تضيع الجولة على الجميع.',
                child: switch (_stage) {
                  _Stage.setup => _setup(),
                  _Stage.spin => _spinView(),
                  _Stage.choose => _chooseView(),
                  _Stage.prompt => _promptView(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- الإعداد ----------------

  Widget _setup() {
    return Column(
      children: [
        GameTopBar(title: 'صراحة أو جرأة', subtitle: widget.mode.label),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('اللاعبون (${_names.length}/12)',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (i, n) in _names.indexed)
                          Chip(
                            label: Text(n, style: const TextStyle(fontWeight: FontWeight.w700)),
                            backgroundColor: (i.isEven ? _blue : _red).withValues(alpha: .3),
                            side: BorderSide.none,
                            onDeleted: _names.length > 2 ? () => setState(() => _names.removeAt(i)) : null,
                          ).animate().scale(duration: 250.ms, curve: Curves.easeOutBack),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            maxLength: 16,
                            onSubmitted: (_) => _addName(),
                            decoration: InputDecoration(
                              hintText: 'اسم لاعب جديد',
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: .08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _addName,
                          style: IconButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgTop),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text('المستوى', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    ChoiceRow<TdLevel>(
                      options: [for (final l in TdLevel.values) (l, '${l.emoji} ${l.label}')],
                      value: _level,
                      onChanged: (v) => setState(() => _level = v),
                    ),
                    const SizedBox(height: 22),
                    _customSection(),
                    const SizedBox(height: 26),
                    BigButton(
                      label: 'ابدأ اللعب',
                      colors: const [_blue, Color(0xFF8F6BFF), _red],
                      onTap: _start,
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

  Widget _customSection() {
    void add(bool truth) {
      final t = _customCtrl.text.trim();
      if (t.isEmpty) return;
      setState(() {
        (truth ? _customTruths : _customDares).add(t);
        _customCtrl.clear();
      });
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('أضف أسئلتكم الخاصة (اختياري) • ${_customTruths.length} صراحة • ${_customDares.length} جرأة',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _customCtrl,
            maxLength: 140,
            decoration: InputDecoration(
              hintText: 'اكتب سؤالاً أو تحدياً…',
              counterText: '',
              filled: true,
              fillColor: Colors.white.withValues(alpha: .08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _blue),
                  onPressed: () => add(true),
                  child: const Text('+ صراحة', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _red),
                  onPressed: () => add(false),
                  child: const Text('+ جرأة', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- الزجاجة ----------------

  Widget _spinView() {
    final g = _game!;
    final n = g.players.length;
    return Column(
      children: [
        GameTopBar(
          title: 'صراحة أو جرأة',
          subtitle: 'الجولة ${g.round + 1}',
          trailing: TextButton.icon(
            onPressed: _finish,
            icon: const Icon(Icons.flag_rounded, color: AppColors.gold),
            label: const Text('إنهاء', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800)),
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final size = min(c.maxWidth, c.maxHeight - 80).clamp(260.0, 560.0);
            final radius = size / 2 - 44;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: radius * 2,
                        height: radius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            Colors.white.withValues(alpha: .12),
                            Colors.white.withValues(alpha: .02),
                          ]),
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                      ),
                      for (var i = 0; i < n; i++)
                        Transform.translate(
                          offset: Offset(cos(_playerAngle(i, n)) * radius, sin(_playerAngle(i, n)) * radius),
                          child: _seat(g, i),
                        ),
                      GestureDetector(
                        key: const ValueKey('td-bottle'),
                        onTap: _spin,
                        child: AnimatedBuilder(
                          animation: _spinCtrl,
                          builder: (_, child) {
                            final t = Curves.easeOutQuart.transform(_spinCtrl.value);
                            final a = _angleFrom + (_angleTo - _angleFrom) * (_spinCtrl.isAnimating || _spinCtrl.value > 0 ? t : 1);
                            return Transform.rotate(angle: a, child: child);
                          },
                          child: _Bottle(height: radius * 1.1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(_spinning ? 'تدور…' : 'اضغط على الزجاجة لتدور',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: .5, end: 1, duration: 800.ms),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _seat(TruthDareGame g, int i) {
    final p = g.players[i];
    final selected = !_spinning && g.currentPlayer == i;
    final color = i.isEven ? _blue : _red;
    return AnimatedScale(
      duration: 300.ms,
      scale: selected ? 1.25 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: selected ? AppColors.gold : Colors.white, width: 3),
              boxShadow: selected ? [const BoxShadow(color: AppColors.gold, blurRadius: 18)] : null,
            ),
            child: Text(p.name.characters.first,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 76,
            child: Text('${p.name} · ${p.score}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ---------------- اختيار صراحة أو جرأة ----------------

  Widget _chooseView() {
    final g = _game!;
    final name = g.players[g.currentPlayer!].name;
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) => GestureDetector(
              key: const ValueKey('td-split'),
              onTapUp: (d) {
                // القطر من أعلى اليسار لأسفل اليمين: فوقه صراحة وتحته جرأة
                final above = d.localPosition.dy < d.localPosition.dx * box.maxHeight / box.maxWidth;
                _choose(above ? TdChoice.truth : TdChoice.dare);
              },
              child: CustomPaint(painter: _SplitPainter(), size: Size(box.maxWidth, box.maxHeight)),
            ),
          ),
        ),
        IgnorePointer(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Align(
                  alignment: const Alignment(.55, -.55),
                  child: _bigWord('صراحة', '🤔').animate().slideX(begin: .6, end: 0, curve: Curves.easeOutBack),
                ),
                Align(
                  alignment: const Alignment(-.55, .55),
                  child: _bigWord('جرأة', '🔥').animate().slideX(begin: -.6, end: 0, curve: Curves.easeOutBack),
                ),
                Center(
                  child: Transform.rotate(
                    angle: -pi / 14,
                    child: Text(
                      'VS',
                      style: AppTheme.display.copyWith(
                        fontSize: 96,
                        shadows: const [Shadow(color: Color(0xFF1A1033), offset: Offset(5, 6))],
                      ),
                    ),
                  ).animate().scale(duration: 600.ms, curve: Curves.elasticOut, begin: const Offset(.2, .2)),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgTop.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text('$name، اختر!', style: AppTheme.display.copyWith(fontSize: 24)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bigWord(String w, String emoji) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 44)),
          Text(w,
              style: AppTheme.display.copyWith(
                fontSize: 56,
                shadows: const [Shadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 6)],
              )),
        ],
      );

  // ---------------- السؤال ----------------

  Widget _promptView() {
    final g = _game!;
    final truth = g.currentChoice == TdChoice.truth;
    final color = truth ? _blue : _red;
    final name = g.players[g.currentPlayer!].name;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, Color.lerp(color, AppColors.bgTop, .6)!],
        ),
      ),
      child: Column(
        children: [
          GameTopBar(title: truth ? 'صراحة' : 'جرأة', subtitle: name),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      _FlipCard(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 30, offset: Offset(0, 14)),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(truth ? '🤔' : '🔥', style: const TextStyle(fontSize: 48)),
                              const SizedBox(height: 10),
                              Text(
                                g.currentPrompt!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.bgTop,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(truth ? '+1 نقطة إذا جاوبت' : '+2 نقطة إذا نفّذت',
                                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                      if (_penalty != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.bgTop.withValues(alpha: .7),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.gold),
                          ),
                          child: Text(_penalty!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                        ).animate().shake(hz: 4, duration: 500.ms),
                      ],
                      const SizedBox(height: 26),
                      if (_penalty == null)
                        Row(
                          children: [
                            Expanded(
                              child: _ActionBtn(
                                label: truth ? 'جاوبت ✓' : 'نفّذت ✓',
                                color: const Color(0xFF2EBD59),
                                onTap: () => _resolve(true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionBtn(
                                label: 'أرفض ✗',
                                color: AppColors.bgTop,
                                onTap: () => _resolve(false),
                              ),
                            ),
                          ],
                        )
                      else
                        _ActionBtn(label: 'تم، الدور التالي', color: AppColors.gold, onTap: () => _resolve(false)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      tilt: false,
      onTap: onTap,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          border: Border(bottom: BorderSide(color: Color.lerp(color, Colors.black, .4)!, width: 5)),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color == AppColors.gold ? AppColors.bgTop : Colors.white,
            )),
      ),
    );
  }
}

/// بطاقة تنقلب لتكشف السؤال.
class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: pi / 2, end: 0),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutBack,
      builder: (_, a, c) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0012)
          ..rotateY(a),
        child: c,
      ),
      child: child,
    );
  }
}

class _Bottle extends StatelessWidget {
  const _Bottle({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final w = height * .28;
    return SizedBox(
      width: w,
      height: height,
      child: Column(
        children: [
          // غطاء
          Container(
            width: w * .34,
            height: height * .07,
            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4)),
          ),
          // عنق
          Container(
            width: w * .3,
            height: height * .25,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1E9E5A), Color(0xFF39D98A), Color(0xFF1E9E5A)]),
            ),
          ),
          // جسم
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14814A), Color(0xFF3BE08F), Color(0xFF14814A)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(w * .5), bottom: Radius.circular(w * .25)),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 8))],
              ),
              child: Center(
                child: Container(
                  width: w * .7,
                  height: height * .18,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Text('MOJAN', style: AppTheme.display.copyWith(color: AppColors.bgBottom)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..close(),
      Paint()..color = _blue,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = _red,
    );
    canvas.drawLine(
      Offset.zero,
      Offset(size.width, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 6,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
