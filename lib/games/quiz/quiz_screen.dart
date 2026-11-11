import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/game_module.dart';
import '../../core/theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/bouncy_button.dart';
import '../../widgets/game_ui.dart';
import 'quiz_engine.dart';
import 'quiz_questions.dart';
import '../../core/haptics.dart';
import '../../core/account/account.dart';

/// ألوان أزرار الإجابات الأربعة.
const _answerColors = [Color(0xFFE63946), Color(0xFF2F8BF5), Color(0xFFFFB703), Color(0xFF2EBD59)];
const _answerShapes = [Icons.change_history_rounded, Icons.circle, Icons.square_rounded, Icons.star_rounded];

const _botNames = ['سهم', 'برق', 'نجمة', 'صقر', 'ذكي', 'فلاش', 'قمر'];

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.mode});
  final PlayMode mode;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

enum _Stage { lobby, waiting, playing }

class _QuizScreenState extends State<QuizScreen> {
  _Stage _stage = _Stage.lobby;
  String _category = 'mix';
  int _count = 10;
  int _bots = 3;
  double _skill = .6;
  late String _roomCode;
  final List<QuizPlayer> _joined = [];
  Timer? _joinTimer;
  int _matchKey = 0;

  @override
  void dispose() {
    _joinTimer?.cancel();
    super.dispose();
  }

  void _createRoom() {
    final r = Random();
    _roomCode = List.generate(6, (_) => r.nextInt(10)).join();
    final names = [..._botNames]..shuffle(r);
    _joined
      ..clear()
      ..add(QuizPlayer('أنت'));
    setState(() => _stage = _Stage.waiting);
    var i = 0;
    _joinTimer?.cancel();
    _joinTimer = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (i >= _bots) {
        t.cancel();
        return;
      }
      setState(() => _joined.add(QuizPlayer('كمبيوتر ${names[i]}',
          isBot: true, skill: (_skill + (r.nextDouble() - .5) * .2).clamp(.1, .95))));
      i++;
    });
  }

  void _startMatch() {
    setState(() {
      _stage = _Stage.playing;
      _matchKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: 400.ms,
            child: KeyedSubtree(
              key: ValueKey('$_stage-$_matchKey'),
              child: switch (_stage) {
                _Stage.lobby => _lobby(),
                _Stage.waiting => _waiting(),
                _Stage.playing => _QuizPlay(
                    players: [
                      for (final p in _joined) QuizPlayer(p.name, isBot: p.isBot, skill: p.skill),
                    ],
                    category: _category,
                    count: _count,
                    onAgain: _startMatch,
                    onLobby: () => setState(() => _stage = _Stage.lobby),
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _lobby() {
    return Column(
      children: [
        GameTopBar(title: 'أسئلة وأجوبة', subtitle: widget.mode.label),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _JoinBox(),
                    const SizedBox(height: 20),
                    const Text('اختر موضوع غرفتك', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.6,
                      children: [
                        for (final (i, c) in quizCategories.indexed)
                          BouncyButton(
                            tilt: false,
                            onTap: () => setState(() => _category = c.id),
                            child: AnimatedContainer(
                              duration: 200.ms,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Color(c.color).withValues(alpha: _category == c.id ? 1 : .28),
                                border: Border.all(
                                  color: _category == c.id ? Colors.white : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(c.emoji, style: const TextStyle(fontSize: 24)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(c.title,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                  ),
                                  if (_category == c.id) const Icon(Icons.check_circle_rounded, size: 20),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: (i * 50).ms).slideY(begin: .3, end: 0),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('عدد الأسئلة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    ChoiceRow<int>(
                      options: const [(5, '5'), (10, '10'), (15, '15')],
                      value: _count,
                      onChanged: (v) => setState(() => _count = v),
                    ),
                    const SizedBox(height: 20),
                    const Text('المنافسون من الكمبيوتر', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    ChoiceRow<int>(
                      options: const [(1, '1'), (3, '3'), (5, '5')],
                      value: _bots,
                      onChanged: (v) => setState(() => _bots = v),
                    ),
                    const SizedBox(height: 10),
                    ChoiceRow<double>(
                      options: const [(.4, 'سهل'), (.6, 'متوسط'), (.85, 'صعب')],
                      value: _skill,
                      onChanged: (v) => setState(() => _skill = v),
                    ),
                    const SizedBox(height: 26),
                    BigButton(
                      label: 'أنشئ غرفة',
                      colors: const [Color(0xFF6CCBFF), AppColors.quiz, Color(0xFF1B7FD1)],
                      onTap: _createRoom,
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

  Widget _waiting() {
    final cat = quizCategories.firstWhere((c) => c.id == _category);
    final ready = _joined.length == _bots + 1;
    return Column(
      children: [
        GameTopBar(title: 'غرفة الانتظار', subtitle: '${cat.emoji} ${cat.title}'),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.quiz,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: AppColors.quiz.withValues(alpha: .5), blurRadius: 24)],
                      ),
                      child: Column(
                        children: [
                          const Text('رمز الغرفة', style: TextStyle(fontWeight: FontWeight.w800)),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              _roomCode.split('').join(' '),
                              style: AppTheme.display.copyWith(fontSize: 44, letterSpacing: 4),
                            ),
                          ),
                          Text('$_count أسئلة • ${quizCategories.firstWhere((c) => c.id == _category).title}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms),
                    const SizedBox(height: 18),
                    Text('اللاعبون (${_joined.length}/${_bots + 1})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final (i, p) in _joined.indexed)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  _Avatar(name: p.name, index: i, bot: p.isBot),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                                  Text(i == 0 ? 'المنشئ' : 'انضم ✓',
                                      style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ).animate().fadeIn(duration: 300.ms).slideX(begin: -.4, end: 0, curve: Curves.easeOutBack),
                          if (!ready)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text('بانتظار المنافسين…',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700))
                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                  .fade(begin: .4, end: 1),
                            ),
                        ],
                      ),
                    ),
                    AnimatedOpacity(
                      duration: 300.ms,
                      opacity: ready ? 1 : .4,
                      child: IgnorePointer(
                        ignoring: !ready,
                        child: BigButton(
                          label: 'ابدأ المسابقة',
                          colors: const [Color(0xFFFFE08A), AppColors.gold, AppColors.goldDeep],
                          onTap: _startMatch,
                          pulse: ready,
                        ),
                      ),
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

/// مربع الانضمام بالكود (يحتاج السيرفر في المرحلة القادمة).
class _JoinBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF9F1C), Color(0xFFFF7B00)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Text('انضم لغرفة صديق', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 4),
          const Text('أدخل الرمز الذي أرسله لك منشئ الغرفة', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i == 3) const SizedBox(width: 12),
                  Container(
                    width: 36,
                    height: 42,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('الغرف مع الأصدقاء أونلاين تعمل بعد تجهيز السيرفر',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: .85))),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.index, required this.bot, this.size = 38});
  final String name;
  final int index;
  final bool bot;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = _answerColors[index % 4];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: bot
          ? Icon(Icons.smart_toy_rounded, size: size * .55, color: Colors.white)
          : Icon(Icons.face_rounded, size: size * .6, color: Colors.white),
    );
  }
}

// ======================= اللعب =======================

class _QuizPlay extends StatefulWidget {
  const _QuizPlay({
    required this.players,
    required this.category,
    required this.count,
    required this.onAgain,
    required this.onLobby,
  });
  final List<QuizPlayer> players;
  final String category;
  final int count;
  final VoidCallback onAgain;
  final VoidCallback onLobby;

  @override
  State<_QuizPlay> createState() => _QuizPlayState();
}

enum _Phase { countdown, question, reveal, leaderboard }

class _QuizPlayState extends State<_QuizPlay> {
  late final QuizMatch m = QuizMatch(
    players: widget.players,
    categoryId: widget.category,
    questionCount: widget.count,
  );

  _Phase _phase = _Phase.countdown;
  int _countdown = 3;
  /// الوقت المنقضي في السؤال، يتقدم مع المؤقت (يعمل كذلك في الاختبارات).
  int _elapsedMs = 0;
  Timer? _ticker;
  final List<Timer> _botTimers = [];
  Set<int> _hidden = {};
  int? _myChoice;
  bool _disposed = false;
  List<int> _prevRanking = [];

  static const me = 0;

  @override
  void initState() {
    super.initState();
    _runCountdown();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    for (final t in _botTimers) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _runCountdown() async {
    for (var i = 3; i >= 1; i--) {
      if (_disposed) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(milliseconds: 800));
    }
    if (!_disposed) _startQuestion();
  }

  void _startQuestion() {
    _hidden = {};
    _myChoice = null;
    _prevRanking = m.ranking;
    setState(() => _phase = _Phase.question);
    _elapsedMs = 0;
    for (var i = 0; i < m.players.length; i++) {
      if (!m.players[i].isBot) continue;
      final d = m.botDecision(i);
      _botTimers.add(Timer(Duration(milliseconds: d.ms), () {
        if (_disposed || _phase != _Phase.question) return;
        m.answer(i, d.choice, d.ms);
        setState(() {});
        _checkDone();
      }));
    }
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_disposed) return;
      _elapsedMs += 100;
      setState(() {});
      if (_elapsedMs >= m.limitFor(me) && !m.answers.containsKey(me)) {
        _reveal();
      } else if (_elapsedMs >= m.limitMs + 10000) {
        _reveal();
      }
    });
  }

  void _checkDone() {
    if (m.everyoneAnswered) _reveal();
  }

  void _answer(int i) {
    if (_phase != _Phase.question || m.answers.containsKey(me) || _hidden.contains(i)) return;
    Haptics.mediumImpact();
    m.answer(me, i, _elapsedMs);
    setState(() => _myChoice = i);
    _checkDone();
  }

  void _lifeline(QuizLifeline l) {
    if (_phase != _Phase.question || m.answers.containsKey(me)) return;
    final hide = m.useLifeline(me, l);
    Haptics.selectionClick();
    setState(() => _hidden = {..._hidden, ...hide});
    if (l == QuizLifeline.skip) _checkDone();
  }

  Future<void> _reveal() async {
    if (_phase != _Phase.question) return;
    _ticker?.cancel();
    for (final t in _botTimers) {
      t.cancel();
    }
    _botTimers.clear();
    m.reveal();
    final mine = m.answers[me]?.choice;
    if (mine != null) {
      mine == m.current.correctIndex ? Haptics.lightImpact() : Haptics.heavyImpact();
    }
    setState(() => _phase = _Phase.reveal);
    await Future.delayed(const Duration(milliseconds: 2200));
    if (_disposed) return;
    setState(() => _phase = _Phase.leaderboard);
    await Future.delayed(const Duration(milliseconds: 2400));
    if (_disposed) return;
    if (m.isLast) {
      m.next();
      _showResults();
      return;
    }
    m.next();
    _startQuestion();
  }

  void _showResults() {
    final r = m.ranking;
    final iWon = r.first == me;
    final reward = Account.instance.recordGame('quiz', won: iWon, points: m.players[me].score);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GameResultDialog(
        reward: reward,
        emoji: iWon ? '🏆' : '🎯',
        title: iWon ? 'أنت البطل!' : '${m.players[r.first].name} فاز!',
        rows: [
          for (final (pos, i) in r.indexed)
            _RankRow(pos: pos, player: m.players[i], index: i, highlight: i == me, sub: '${m.players[i].correct}/${m.questions.length} صحيحة'),
        ],
        onAgain: () {
          Navigator.pop(ctx);
          widget.onAgain();
        },
        onHome: () {
          Navigator.pop(ctx);
          widget.onLobby();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LeaveGuard(
        message: 'المسابقة ما خلصت، وإذا انسحبت تضيع نقاطك.',
        child: _body(context),
      );

  Widget _body(BuildContext context) {
    if (_phase == _Phase.countdown) {
      return Center(
        child: Text('$_countdown', key: ValueKey(_countdown), style: AppTheme.display.copyWith(fontSize: 140))
            .animate(key: ValueKey(_countdown))
            .scale(begin: const Offset(2, 2), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOutBack)
            .fadeIn(),
      );
    }
    if (m.finished) return const SizedBox();
    return Column(
      children: [
        _header(),
        Expanded(
          child: AnimatedSwitcher(
            duration: 350.ms,
            child: _phase == _Phase.leaderboard
                ? _leaderboard()
                : KeyedSubtree(key: ValueKey('q${m.index}'), child: _questionBody()),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    final elapsed = _elapsedMs;
    final limit = m.limitFor(me);
    final left = ((limit - elapsed) / 1000).clamp(0, 99).ceil();
    final frac = (1 - elapsed / limit).clamp(0.0, 1.0);
    final urgent = left <= 5 && _phase == _Phase.question;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close_rounded)),
          Text('سؤال ${m.index + 1}/${m.questions.length}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
            child: Text('⭐ ${m.players[me].score}',
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _phase == _Phase.question ? frac : 0,
                  strokeWidth: 5,
                  color: urgent ? AppColors.dare : AppColors.gold,
                  backgroundColor: Colors.white12,
                ),
                Text('${_phase == _Phase.question ? left : 0}',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 17, color: urgent ? AppColors.dare : Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionBody() {
    final q = m.current;
    final reveal = _phase == _Phase.reveal;
    final myLast = m.lastPoints[me] ?? 0;
    return LayoutBuilder(builder: (context, c) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                // من أجاب
                SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < m.players.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Opacity(
                                opacity: m.answers.containsKey(i) || reveal ? 1 : .45,
                                child: _Avatar(name: m.players[i].name, index: i, bot: m.players[i].isBot, size: 34),
                              ),
                              if (m.answers.containsKey(i))
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(1),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: Icon(
                                      reveal
                                          ? (m.answers[i]!.choice == q.correctIndex
                                              ? Icons.check_circle
                                              : Icons.cancel)
                                          : Icons.check_circle,
                                      size: 14,
                                      color: reveal
                                          ? (m.answers[i]!.choice == q.correctIndex ? Colors.green : Colors.red)
                                          : AppColors.quiz,
                                    ),
                                  ).animate().scale(curve: Curves.elasticOut, duration: 500.ms),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 130),
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, 10))],
                  ),
                  child: Text(q.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.bgTop, fontSize: 22, fontWeight: FontWeight.w900, height: 1.5)),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: -.2, end: 0, curve: Curves.easeOutBack),
                const SizedBox(height: 14),
                if (reveal)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      m.answers[me]?.choice == null
                          ? (m.answers.containsKey(me) ? 'تخطيت السؤال' : 'انتهى الوقت ⏰')
                          : (myLast > 0 ? 'صح! +$myLast' : 'خطأ 😅'),
                      style: AppTheme.display.copyWith(
                          fontSize: 30, color: myLast > 0 ? const Color(0xFF6EF0A0) : AppColors.dare),
                    ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
                  ),
                GridView.count(
                  crossAxisCount: c.maxWidth > 500 ? 2 : 1,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: c.maxWidth > 500 ? 3.4 : 5.4,
                  children: [
                    for (var i = 0; i < 4; i++) _answerButton(i, q, reveal),
                  ],
                ),
                const SizedBox(height: 14),
                if (_phase == _Phase.question) _lifelines(),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _answerButton(int i, QuizRoundQuestion q, bool reveal) {
    final hidden = _hidden.contains(i);
    final isCorrect = i == q.correctIndex;
    final mine = _myChoice == i;
    var color = _answerColors[i];
    var opacity = 1.0;
    if (hidden) opacity = .15;
    if (reveal) {
      if (isCorrect) {
        color = const Color(0xFF2EBD59);
      } else {
        opacity = mine ? 1 : .35;
        if (mine) color = const Color(0xFFB0203A);
      }
    } else if (_myChoice != null && !mine) {
      opacity = .45;
    }
    final pickers = [
      for (var p = 0; p < m.players.length; p++)
        if (reveal && m.answers[p]?.choice == i) p,
    ];

    Widget b = AnimatedOpacity(
      duration: 250.ms,
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: mine ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: [BoxShadow(color: Color.lerp(color, Colors.black, .35)!, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Icon(_answerShapes[i], color: Colors.white70, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(q.options[i],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Colors.white)),
            ),
            for (final p in pickers)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: _Avatar(name: m.players[p].name, index: p, bot: m.players[p].isBot, size: 22),
              ),
            if (reveal && isCorrect) const Icon(Icons.check_circle_rounded, color: Colors.white),
          ],
        ),
      ),
    );
    if (reveal && isCorrect) {
      b = b.animate().shake(hz: 3, rotation: .02, duration: 500.ms);
    }
    return GestureDetector(
      key: ValueKey('answer-$i'),
      onTap: () => _answer(i),
      child: b,
    ).animate().fadeIn(delay: (i * 70).ms).slideX(begin: i.isEven ? .3 : -.3, end: 0, curve: Curves.easeOutBack);
  }

  Widget _lifelines() {
    final left = m.lifelines[me] ?? {};
    final locked = m.answers.containsKey(me);
    Widget btn(QuizLifeline l, String label, IconData icon) {
      final ok = left.contains(l) && !locked;
      return Expanded(
        child: Opacity(
          opacity: ok ? 1 : .35,
          child: BouncyButton(
            tilt: false,
            onTap: ok ? () => _lifeline(l) : () {},
            child: Container(
              height: 46,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        btn(QuizLifeline.fiftyFifty, 'حذف إجابتين', Icons.content_cut_rounded),
        btn(QuizLifeline.extraTime, '+10 ثواني', Icons.timer_rounded),
        btn(QuizLifeline.skip, 'تخطي', Icons.skip_next_rounded),
      ],
    );
  }

  Widget _leaderboard() {
    final r = m.ranking;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الترتيب', style: AppTheme.display.copyWith(fontSize: 34)),
              const SizedBox(height: 12),
              for (final (pos, i) in r.indexed)
                _RankRow(
                  pos: pos,
                  player: m.players[i],
                  index: i,
                  highlight: i == me,
                  sub: (m.lastPoints[i] ?? 0) > 0 ? '+${m.lastPoints[i]}' : '',
                  moved: _prevRanking.indexOf(i) - pos,
                ).animate().fadeIn(delay: (pos * 90).ms).slideY(begin: .5, end: 0, curve: Curves.easeOutBack),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.pos,
    required this.player,
    required this.index,
    required this.highlight,
    this.sub = '',
    this.moved = 0,
  });
  final int pos;
  final QuizPlayer player;
  final int index;
  final bool highlight;
  final String sub;
  final int moved;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? AppColors.gold.withValues(alpha: .25) : Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? AppColors.gold : Colors.transparent, width: 2),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(pos < 3 ? ['🥇', '🥈', '🥉'][pos] : '${pos + 1}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          _Avatar(name: player.name, index: index, bot: player.isBot, size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Text(player.name,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (moved > 0) const Icon(Icons.arrow_upward_rounded, color: Color(0xFF6EF0A0), size: 18),
          if (moved < 0) const Icon(Icons.arrow_downward_rounded, color: AppColors.dare, size: 18),
          if (sub.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(sub, style: const TextStyle(color: Color(0xFF6EF0A0), fontWeight: FontWeight.w800)),
            ),
          Text('${player.score}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
        ],
      ),
    );
  }
}
