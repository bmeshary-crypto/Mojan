import 'dart:math';

/// ألوان اللاعبين بترتيب اللعب (مع عقارب الساعة على اللوح).
/// الأحمر أسفل اليسار، الأخضر أعلى اليسار، الأصفر أعلى اليمين، الأزرق أسفل اليمين.
enum LudoColor { red, green, yellow, blue }

/// إعدادات القواعد القابلة للتغيير.
class LudoRules {
  const LudoRules({
    this.tokensPerPlayer = 4,
    this.sixToLeaveYard = true,
    this.extraTurnOnCapture = true,
    this.extraTurnOnFinish = true,
    this.threeSixesLosesTurn = true,
  });

  final int tokensPerPlayer;
  final bool sixToLeaveYard;
  final bool extraTurnOnCapture;
  final bool extraTurnOnFinish;
  final bool threeSixesLosesTurn;
}

/// موقع القطعة نسبةً لبداية صاحبها:
///  -1 في البيت (الساحة)، 0..50 على المسار الرئيسي،
///  51..55 في ممر البيت، 56 وصلت (انتهت).
class LudoGeo {
  static const yard = -1;
  static const lastTrack = 50;
  static const finished = 56;
  static const trackLength = 52;

  /// خانة البداية لكل لون على المسار العام (0..51).
  static const startIndex = {
    LudoColor.green: 1,
    LudoColor.yellow: 14,
    LudoColor.blue: 27,
    LudoColor.red: 40,
  };

  /// الخانات الآمنة على المسار العام: خانات البداية والنجوم.
  static const safeIndices = {1, 9, 14, 22, 27, 35, 40, 48};

  /// تحويل موقع نسبي إلى خانة على المسار العام، أو null إن لم تكن على المسار.
  static int? globalIndex(LudoColor c, int pos) {
    if (pos < 0 || pos > lastTrack) return null;
    return (startIndex[c]! + pos) % trackLength;
  }

  static bool isSafeGlobal(int g) => safeIndices.contains(g);
}

class LudoToken {
  LudoToken(this.color, this.id, [this.pos = LudoGeo.yard]);
  final LudoColor color;
  final int id;
  int pos;

  bool get inYard => pos == LudoGeo.yard;
  bool get finished => pos == LudoGeo.finished;
  int? get globalIndex => LudoGeo.globalIndex(color, pos);

  LudoToken copy() => LudoToken(color, id, pos);
}

class LudoMove {
  const LudoMove({required this.token, required this.from, required this.to});
  final LudoToken token;
  final int from;
  final int to;

  /// المواقع التي تمر بها القطعة خطوة بخطوة (بدون نقطة البداية).
  List<int> get path => from == LudoGeo.yard ? [0] : [for (var p = from + 1; p <= to; p++) p];
}

class LudoMoveResult {
  const LudoMoveResult({
    required this.move,
    required this.captured,
    required this.extraTurn,
    required this.playerFinished,
  });
  final LudoMove move;
  final List<LudoToken> captured;
  final bool extraTurn;
  final bool playerFinished;
}

enum LudoPhase { waitingRoll, waitingMove, gameOver }

/// محرك قواعد لودو. لا يعرف شيئاً عن الرسم، ويمكن تشغيله على السيرفر لاحقاً.
class LudoGame {
  LudoGame({
    required this.players,
    this.rules = const LudoRules(),
    Random? random,
  })  : assert(players.length >= 2 && players.length <= 4),
        _random = random ?? Random() {
    for (final p in players) {
      tokens[p] = List.generate(rules.tokensPerPlayer, (i) => LudoToken(p, i));
    }
  }

  final List<LudoColor> players;
  final LudoRules rules;
  final Random _random;
  final Map<LudoColor, List<LudoToken>> tokens = {};

  int _turn = 0;
  int? dice;
  int _sixesInRow = 0;
  LudoPhase phase = LudoPhase.waitingRoll;
  List<LudoMove> legalMoves = const [];

  /// ترتيب من أنهوا اللعب.
  final List<LudoColor> ranking = [];

  LudoColor get current => players[_turn];

  Iterable<LudoToken> get allTokens => tokens.values.expand((t) => t);

  bool hasFinished(LudoColor c) => tokens[c]!.every((t) => t.finished);

  /// رمي النرد. يمكن تمرير قيمة محددة للاختبار أو لنتيجة قادمة من السيرفر.
  /// ترجع true إذا كان للاعب حركة متاحة.
  bool roll([int? value]) {
    assert(phase == LudoPhase.waitingRoll);
    final d = value ?? _random.nextInt(6) + 1;
    dice = d;
    if (d == 6) {
      _sixesInRow++;
      if (rules.threeSixesLosesTurn && _sixesInRow == 3) {
        legalMoves = const [];
        _endTurn(extra: false);
        return false;
      }
    } else {
      _sixesInRow = 0;
    }
    legalMoves = movesFor(current, d);
    if (legalMoves.isEmpty) {
      _endTurn(extra: false);
      return false;
    }
    phase = LudoPhase.waitingMove;
    return true;
  }

  List<LudoMove> movesFor(LudoColor c, int d) {
    final out = <LudoMove>[];
    for (final t in tokens[c]!) {
      if (t.finished) continue;
      if (t.inYard) {
        if (!rules.sixToLeaveYard || d == 6) {
          out.add(LudoMove(token: t, from: LudoGeo.yard, to: 0));
        }
        continue;
      }
      final to = t.pos + d;
      if (to > LudoGeo.finished) continue; // يحتاج رقماً مضبوطاً للوصول
      out.add(LudoMove(token: t, from: t.pos, to: to));
    }
    return out;
  }

  /// تنفيذ حركة من الحركات المتاحة.
  LudoMoveResult move(LudoMove m) {
    assert(phase == LudoPhase.waitingMove);
    assert(legalMoves.contains(m), 'حركة غير مسموحة');
    final t = m.token;
    t.pos = m.to;

    final captured = <LudoToken>[];
    final g = t.globalIndex;
    if (g != null && !LudoGeo.isSafeGlobal(g)) {
      for (final o in allTokens) {
        if (o.color != t.color && o.globalIndex == g) {
          o.pos = LudoGeo.yard;
          captured.add(o);
        }
      }
    }

    var playerFinished = false;
    if (hasFinished(t.color) && !ranking.contains(t.color)) {
      ranking.add(t.color);
      playerFinished = true;
    }

    final remaining = players.where((p) => !ranking.contains(p)).toList();
    if (remaining.length <= 1) {
      ranking.addAll(remaining);
      phase = LudoPhase.gameOver;
      legalMoves = const [];
      return LudoMoveResult(move: m, captured: captured, extraTurn: false, playerFinished: playerFinished);
    }

    final extra = !playerFinished &&
        (dice == 6 ||
            (captured.isNotEmpty && rules.extraTurnOnCapture) ||
            (m.to == LudoGeo.finished && rules.extraTurnOnFinish));
    _endTurn(extra: extra);
    return LudoMoveResult(move: m, captured: captured, extraTurn: extra, playerFinished: playerFinished);
  }

  void _endTurn({required bool extra}) {
    legalMoves = const [];
    phase = LudoPhase.waitingRoll;
    if (extra && !hasFinished(current)) return;
    _sixesInRow = 0;
    do {
      _turn = (_turn + 1) % players.length;
    } while (ranking.contains(players[_turn]));
  }

  /// اختيار حركة الكمبيوتر: يفضّل الوصول، ثم الأكل، ثم الخروج من البيت،
  /// ثم الهروب من الخطر والدخول للخانات الآمنة، ثم تقديم القطعة الأبعد.
  LudoMove chooseAiMove() {
    assert(legalMoves.isNotEmpty);
    LudoMove? best;
    var bestScore = double.negativeInfinity;
    for (final m in legalMoves) {
      final s = _scoreMove(m) + _random.nextDouble() * .5;
      if (s > bestScore) {
        bestScore = s;
        best = m;
      }
    }
    return best!;
  }

  double _scoreMove(LudoMove m) {
    final c = m.token.color;
    var s = 0.0;
    if (m.to == LudoGeo.finished) s += 100;
    if (m.from == LudoGeo.yard) s += 40;
    if (m.to > LudoGeo.lastTrack && m.from <= LudoGeo.lastTrack) s += 35; // دخل ممر البيت

    final g = LudoGeo.globalIndex(c, m.to);
    if (g != null) {
      final captures = allTokens.where((o) => o.color != c && o.globalIndex == g).toList();
      if (captures.isNotEmpty && !LudoGeo.isSafeGlobal(g)) {
        s += 60 + captures.fold<int>(0, (a, o) => a + o.pos);
      }
      if (LudoGeo.isSafeGlobal(g)) s += 15;
      if (!LudoGeo.isSafeGlobal(g)) s -= 30 * _threatAt(c, g);
    }
    final fromG = m.token.globalIndex;
    if (fromG != null && !LudoGeo.isSafeGlobal(fromG)) {
      s += 20 * _threatAt(c, fromG); // الهروب من قطعة تطارده
    }
    s += m.to * .3;
    return s;
  }

  /// عدد قطع الخصوم التي تستطيع الوصول لهذه الخانة برمية واحدة.
  int _threatAt(LudoColor me, int g) {
    var n = 0;
    for (final o in allTokens) {
      if (o.color == me) continue;
      final og = o.globalIndex;
      if (og == null) continue;
      final dist = (g - og) % LudoGeo.trackLength;
      // يجب ألا يكون الخصم قد تجاوز مدخل ممره قبل الوصول
      if (dist >= 1 && dist <= 6 && o.pos + dist <= LudoGeo.lastTrack) n++;
    }
    return n;
  }
}
