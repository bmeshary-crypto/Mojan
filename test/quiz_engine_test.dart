import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/games/quiz/quiz_engine.dart';
import 'package:mojan/games/quiz/quiz_questions.dart';

QuizMatch match({String cat = 'mix', int n = 10}) => QuizMatch(
      players: [QuizPlayer('أنت'), QuizPlayer('بوت', isBot: true, skill: .5)],
      categoryId: cat,
      questionCount: n,
      random: Random(1),
    );

void main() {
  test('question bank is valid: 4 unique options, every category has 20', () {
    for (final q in quizQuestions) {
      expect(q.options.length, 4, reason: q.text);
      expect(q.options.toSet().length, 4, reason: q.text);
    }
    for (final c in quizCategories.where((c) => c.id != 'mix')) {
      expect(quizQuestions.where((q) => q.category == c.id).length, greaterThanOrEqualTo(20), reason: c.title);
    }
    expect(quizQuestions.map((q) => q.text).toSet().length, quizQuestions.length, reason: 'no duplicate questions');
  });

  test('match picks unique questions from the category with shuffled options', () {
    final m = match(cat: 'geo', n: 15);
    expect(m.questions.length, 15);
    expect(m.questions.every((q) => q.source.category == 'geo'), isTrue);
    expect(m.questions.map((q) => q.text).toSet().length, 15);
    for (final q in m.questions) {
      expect(q.options[q.correctIndex], q.source.options.first);
    }
  });

  test('faster correct answers score more; wrong scores zero; streak bonus', () {
    final m = match();
    m.answer(0, m.current.correctIndex, 1000);
    m.answer(1, m.current.correctIndex, 10000);
    m.reveal();
    expect(m.lastPoints[0]!, greaterThan(m.lastPoints[1]!));
    expect(m.lastPoints[0]!, inInclusiveRange(500, 1000));
    m.next();
    m.answer(0, m.current.correctIndex, 1000);
    m.answer(1, (m.current.correctIndex + 1) % 4, 1000);
    m.reveal();
    expect(m.lastPoints[1], 0);
    expect(m.players[1].streak, 0);
    expect(m.lastPoints[0]!, greaterThanOrEqualTo(500 + 100), reason: 'streak bonus');
  });

  test('answers after the time limit are ignored; extra time extends it', () {
    final m = match();
    m.answer(0, m.current.correctIndex, 16000);
    expect(m.answers.containsKey(0), isFalse);
    m.useLifeline(0, QuizLifeline.extraTime);
    m.answer(0, m.current.correctIndex, 16000);
    expect(m.answers.containsKey(0), isTrue);
  });

  test('lifelines: fifty-fifty hides two wrong answers, each usable once, bots have none', () {
    final m = match();
    final hide = m.useLifeline(0, QuizLifeline.fiftyFifty);
    expect(hide.length, 2);
    expect(hide.contains(m.current.correctIndex), isFalse);
    expect(m.useLifeline(0, QuizLifeline.fiftyFifty), isEmpty);
    expect(m.useLifeline(1, QuizLifeline.skip), isEmpty);
    m.useLifeline(0, QuizLifeline.skip);
    expect(m.answers[0]!.choice, isNull);
  });

  test('full match with bots finishes and ranks by score', () {
    final m = QuizMatch(
      players: [
        QuizPlayer('أنت'),
        for (var i = 0; i < 3; i++) QuizPlayer('بوت $i', isBot: true, skill: .3 + i * .3),
      ],
      categoryId: 'mix',
      random: Random(9),
    );
    while (!m.finished) {
      for (var i = 0; i < m.players.length; i++) {
        if (m.players[i].isBot) {
          final d = m.botDecision(i);
          m.answer(i, d.choice, d.ms);
        }
      }
      expect(m.everyoneAnswered, isFalse);
      m.reveal();
      m.next();
    }
    final r = m.ranking;
    for (var i = 1; i < r.length; i++) {
      expect(m.players[r[i - 1]].score, greaterThanOrEqualTo(m.players[r[i]].score));
    }
  });
}
