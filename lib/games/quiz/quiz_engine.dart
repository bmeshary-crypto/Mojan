import 'dart:math';

import 'quiz_questions.dart';

class QuizPlayer {
  QuizPlayer(this.name, {this.isBot = false, this.skill = .6});
  final String name;
  final bool isBot;

  /// احتمال أن يجيب الكمبيوتر إجابة صحيحة.
  final double skill;
  int score = 0;
  int streak = 0;
  int correct = 0;
}

class QuizRoundQuestion {
  QuizRoundQuestion(this.source, this.options, this.correctIndex);
  final QuizQuestion source;
  final List<String> options;
  final int correctIndex;
  String get text => source.text;
}

class QuizAnswer {
  const QuizAnswer(this.choice, this.ms);

  /// null = تخطي.
  final int? choice;
  final int ms;
}

enum QuizLifeline { fiftyFifty, extraTime, skip }

/// مباراة أسئلة: يرى الجميع نفس السؤال في نفس الوقت، والأسرع يأخذ نقاطاً أكثر.
class QuizMatch {
  QuizMatch({
    required this.players,
    required String categoryId,
    this.questionCount = 10,
    this.secondsPerQuestion = 15,
    Random? random,
  }) : _random = random ?? Random() {
    final pool = quizQuestions.where((q) => categoryId == 'mix' || q.category == categoryId).toList()
      ..shuffle(_random);
    final picked = pool.take(min(questionCount, pool.length));
    for (final q in picked) {
      final opts = [...q.options]..shuffle(_random);
      questions.add(QuizRoundQuestion(q, opts, opts.indexOf(q.options.first)));
    }
    for (var i = 0; i < players.length; i++) {
      if (!players[i].isBot) lifelines[i] = {...QuizLifeline.values};
    }
  }

  final List<QuizPlayer> players;
  final int questionCount;
  final int secondsPerQuestion;
  final Random _random;
  final List<QuizRoundQuestion> questions = [];
  final Map<int, Set<QuizLifeline>> lifelines = {};

  int index = 0;
  final Map<int, QuizAnswer> answers = {};
  final Map<int, int> lastPoints = {};
  final Map<int, int> extraMs = {};
  bool revealed = false;

  QuizRoundQuestion get current => questions[index];
  bool get isLast => index == questions.length - 1;
  bool get finished => index >= questions.length;
  int get limitMs => secondsPerQuestion * 1000;
  int limitFor(int player) => limitMs + (extraMs[player] ?? 0);

  bool get everyoneAnswered => answers.length == players.length;

  void answer(int player, int? choice, int ms) {
    if (revealed || answers.containsKey(player)) return;
    if (ms > limitFor(player)) return;
    answers[player] = QuizAnswer(choice, ms);
  }

  /// يستخدم وسيلة مساعدة. للحذف يرجع خيارين خاطئين للإخفاء.
  List<int> useLifeline(int player, QuizLifeline l) {
    final left = lifelines[player];
    if (left == null || !left.remove(l)) return const [];
    switch (l) {
      case QuizLifeline.fiftyFifty:
        final wrong = [for (var i = 0; i < 4; i++) if (i != current.correctIndex) i]..shuffle(_random);
        return wrong.take(2).toList();
      case QuizLifeline.extraTime:
        extraMs[player] = (extraMs[player] ?? 0) + 10000;
        return const [];
      case QuizLifeline.skip:
        answers[player] = const QuizAnswer(null, 0);
        return const [];
    }
  }

  /// قرار الكمبيوتر: متى يجيب وما إجابته.
  ({int ms, int choice}) botDecision(int player) {
    final p = players[player];
    final ms = 2000 + _random.nextInt(max(1, limitMs - 4000));
    final right = _random.nextDouble() < p.skill;
    final choice = right
        ? current.correctIndex
        : ([for (var i = 0; i < 4; i++) if (i != current.correctIndex) i]..shuffle(_random)).first;
    return (ms: ms, choice: choice);
  }

  /// كشف الإجابة وحساب النقاط: 500 للصحيحة + حتى 500 حسب السرعة + مكافأة سلسلة.
  void reveal() {
    if (revealed) return;
    revealed = true;
    lastPoints.clear();
    for (var i = 0; i < players.length; i++) {
      final p = players[i];
      final a = answers[i];
      if (a == null || a.choice == null) {
        if (a == null) p.streak = 0; // التخطي لا يكسر السلسلة
        lastPoints[i] = 0;
        continue;
      }
      if (a.choice == current.correctIndex) {
        final speed = 1 - (a.ms / limitFor(i)).clamp(0.0, 1.0);
        final bonus = min(p.streak, 3) * 100;
        final pts = 500 + (speed * 500).round() + bonus;
        p.score += pts;
        p.streak++;
        p.correct++;
        lastPoints[i] = pts;
      } else {
        p.streak = 0;
        lastPoints[i] = 0;
      }
    }
  }

  void next() {
    assert(revealed);
    index++;
    answers.clear();
    extraMs.clear();
    revealed = false;
  }

  List<int> get ranking => [for (var i = 0; i < players.length; i++) i]
    ..sort((a, b) => players[b].score.compareTo(players[a].score));
}
