import 'dart:math';

import 'truth_dare_content.dart';

enum TdChoice { truth, dare }

class TdPlayer {
  TdPlayer(this.name);
  final String name;
  int score = 0;
  int done = 0;
  int refused = 0;
}

/// محرك صراحة أو جرأة: اختيار اللاعب بالزجاجة، وسحب أسئلة بدون تكرار.
class TruthDareGame {
  TruthDareGame({
    required List<String> names,
    required this.level,
    List<String> customTruths = const [],
    List<String> customDares = const [],
    Random? random,
  })  : assert(names.length >= 2),
        players = [for (final n in names) TdPlayer(n)],
        _random = random ?? Random(),
        _truthSource = [...tdTruths[level]!, ...customTruths],
        _dareSource = [...tdDares[level]!, ...customDares];

  final List<TdPlayer> players;
  final TdLevel level;
  final Random _random;
  final List<String> _truthSource;
  final List<String> _dareSource;
  final List<String> _truthPool = [];
  final List<String> _darePool = [];

  int? currentPlayer;
  int? _lastPlayer;
  String? currentPrompt;
  TdChoice? currentChoice;
  int round = 0;

  /// تدوير الزجاجة: لاعب عشوائي غير اللاعب السابق.
  int spin() {
    int next;
    do {
      next = _random.nextInt(players.length);
    } while (next == _lastPlayer);
    currentPlayer = next;
    currentPrompt = null;
    currentChoice = null;
    return next;
  }

  /// سحب سؤال أو تحدي. لا يتكرر حتى ينتهي كل المحتوى ثم يُعاد الخلط.
  String draw(TdChoice choice) {
    assert(currentPlayer != null);
    final pool = choice == TdChoice.truth ? _truthPool : _darePool;
    if (pool.isEmpty) {
      pool.addAll(choice == TdChoice.truth ? _truthSource : _dareSource);
      pool.shuffle(_random);
    }
    currentChoice = choice;
    currentPrompt = pool.removeLast();
    return currentPrompt!;
  }

  /// النتيجة: التنفيذ +1 للصراحة، +2 للجرأة. الرفض -1.
  void resolve({required bool completed}) {
    assert(currentPlayer != null && currentChoice != null);
    final p = players[currentPlayer!];
    if (completed) {
      p.score += currentChoice == TdChoice.dare ? 2 : 1;
      p.done++;
    } else {
      p.score -= 1;
      p.refused++;
    }
    _lastPlayer = currentPlayer;
    currentPlayer = null;
    currentPrompt = null;
    currentChoice = null;
    round++;
  }

  List<TdPlayer> get leaderboard => [...players]..sort((a, b) => b.score.compareTo(a.score));
}

/// عقوبات مرحة لمن يرفض.
const tdPenalties = [
  'عقوبة: قلّد صوت دجاجة 🐔',
  'عقوبة: امدح الجميع واحداً واحداً 🌹',
  'عقوبة: غنِّ اسمك بلحن حزين 🎤',
  'عقوبة: 10 قفزات الآن 🏃',
  'عقوبة: تكلم كالروبوت حتى دورك القادم 🤖',
  'عقوبة: لا تبتسم حتى الدور القادم 😐',
];
