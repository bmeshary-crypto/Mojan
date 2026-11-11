import 'dart:math';

/// ألوان اللاعبين بترتيب اللعب (مع عقارب الساعة على اللوح).
/// الأحمر أسفل اليسار، الأخضر أعلى اليسار، الأصفر أعلى اليمين، الأزرق أسفل اليمين.
enum LudoColor { red, green, yellow, blue }

/// أدوات وضع الباور.
enum LudoItem {
  /// تحرك ضعف رقم النرد (لا تعطي رمية إضافية للستة).
  doubleDistance,

  /// تختار رقم النرد بنفسك.
  diceControl,

  /// قطعك لا تؤكل حتى يرجع دورك.
  shield,
}

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

  /// خانات الرمية الإضافية في وضع الباور.
  static const bonusIndices = {5, 18, 31, 44};
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
    this.bonusRoll = false,
  });
  final bool bonusRoll;
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
    this.teams = false,
    this.power = false,
    Map<LudoColor, Map<LudoItem, int>>? items,
    Random? random,
  })  : assert(players.length >= 2 && players.length <= 4),
        assert(!teams || players.length == 4, 'الفرق تحتاج 4 لاعبين'),
        _random = random ?? Random() {
    for (final p in players) {
      tokens[p] = List.generate(rules.tokensPerPlayer, (i) => LudoToken(p, i));
      this.items[p] = {for (final i in LudoItem.values) i: power ? (items?[p]?[i] ?? 0) : 0};
    }
  }

  /// 2 ضد 2: الأحمر والأصفر ضد الأخضر والأزرق (اللاعبان المتقابلان قطرياً).
  final bool teams;

  /// وضع الباور: أدوات وخانات رمية إضافية.
  final bool power;

  /// الأدوات المتبقية لكل لاعب في هذه المباراة.
  final Map<LudoColor, Map<LudoItem, int>> items = {};

  /// الأدوات المفعلة للدور الحالي.
  bool doubleActive = false;
  int? controlledValue;

  /// الألوان المحمية بالدرع حتى يرجع دورها.
  final Set<LudoColor> shielded = {};

  /// الفريق الفائز في وضع الفرق.
  int? winnerTeam;

  static int teamOf(LudoColor c) => c.index % 2;
  bool allies(LudoColor a, LudoColor b) => a == b || (teams && teamOf(a) == teamOf(b));

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
    final d = controlledValue ?? value ?? _random.nextInt(6) + 1;
    controlledValue = null;
    dice = d;
    if (d == 6 && !doubleActive) {
      _sixesInRow++;
      if (rules.threeSixesLosesTurn && _sixesInRow == 3) {
        legalMoves = const [];
        _endTurn(extra: false);
        return false;
      }
    } else {
      _sixesInRow = 0;
    }
    legalMoves = movesFor(current, d, doubled: doubleActive);
    if (legalMoves.isEmpty) {
      _endTurn(extra: false);
      return false;
    }
    phase = LudoPhase.waitingMove;
    return true;
  }

  int itemCount(LudoColor c, LudoItem i) => items[c]?[i] ?? 0;

  /// يستخدم أداة قبل رمي النرد. [value] مطلوب للتحكم بالنرد (1..6).
  /// ترجع false إذا لم تكن الأداة متاحة الآن.
  bool useItem(LudoItem item, {int? value}) {
    if (!power || phase != LudoPhase.waitingRoll || itemCount(current, item) <= 0) return false;
    switch (item) {
      case LudoItem.doubleDistance:
        if (doubleActive) return false;
        doubleActive = true;
      case LudoItem.diceControl:
        if (controlledValue != null || value == null || value < 1 || value > 6) return false;
        controlledValue = value;
      case LudoItem.shield:
        if (shielded.contains(current)) return false;
        shielded.add(current);
    }
    items[current]![item] = itemCount(current, item) - 1;
    return true;
  }

  bool isProtected(LudoToken t) => shielded.contains(t.color);

  List<LudoMove> movesFor(LudoColor c, int d, {bool doubled = false}) {
    final out = <LudoMove>[];
    for (final t in tokens[c]!) {
      if (t.finished) continue;
      if (t.inYard) {
        if (!rules.sixToLeaveYard || d == 6) {
          out.add(LudoMove(token: t, from: LudoGeo.yard, to: 0));
        }
        continue;
      }
      final to = t.pos + (doubled ? d * 2 : d);
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
        if (!allies(o.color, t.color) && o.globalIndex == g && !isProtected(o)) {
          o.pos = LudoGeo.yard;
          captured.add(o);
        }
      }
    }
    final bonus = power && g != null && LudoGeo.bonusIndices.contains(g) && m.from != LudoGeo.yard;

    var playerFinished = false;
    if (hasFinished(t.color) && !ranking.contains(t.color)) {
      ranking.add(t.color);
      playerFinished = true;
    }

    if (teams) {
      for (final team in [0, 1]) {
        final members = players.where((p) => teamOf(p) == team);
        if (members.every(hasFinished)) {
          winnerTeam = team;
          // الفائزون أولاً بترتيب وصولهم، ثم الخاسرون حسب تقدمهم
          final losers = players.where((p) => teamOf(p) != team).toList()
            ..sort((a, b) => _progress(b).compareTo(_progress(a)));
          ranking
            ..removeWhere((p) => teamOf(p) != team)
            ..addAll(members.where((p) => !ranking.contains(p)))
            ..addAll(losers);
          return _gameOver(m, captured, playerFinished);
        }
      }
    } else {
      final remaining = players.where((p) => !ranking.contains(p)).toList();
      if (remaining.length <= 1) {
        ranking.addAll(remaining);
        return _gameOver(m, captured, playerFinished);
      }
    }

    final extra = !playerFinished &&
        ((dice == 6 && !doubleActive) ||
            bonus ||
            (captured.isNotEmpty && rules.extraTurnOnCapture) ||
            (m.to == LudoGeo.finished && rules.extraTurnOnFinish));
    _endTurn(extra: extra);
    return LudoMoveResult(move: m, captured: captured, extraTurn: extra, playerFinished: playerFinished, bonusRoll: bonus);
  }

  LudoMoveResult _gameOver(LudoMove m, List<LudoToken> captured, bool playerFinished) {
    phase = LudoPhase.gameOver;
    legalMoves = const [];
    doubleActive = false;
    return LudoMoveResult(move: m, captured: captured, extraTurn: false, playerFinished: playerFinished);
  }

  /// مجموع تقدم قطع اللاعب (لترتيب الخاسرين).
  int _progress(LudoColor c) => tokens[c]!.fold(0, (a, t) => a + t.pos + 1);

  void _endTurn({required bool extra}) {
    legalMoves = const [];
    phase = LudoPhase.waitingRoll;
    doubleActive = false;
    controlledValue = null;
    if (extra && !hasFinished(current)) return;
    _sixesInRow = 0;
    do {
      _turn = (_turn + 1) % players.length;
    } while (ranking.contains(players[_turn]));
    // الدرع ينتهي عند رجوع الدور لصاحبه
    shielded.remove(current);
  }

  /// يقرر الكمبيوتر أي أداة يستخدم قبل الرمي (وضع الباور فقط).
  /// يرجع الأداة المستخدمة أو null.
  LudoItem? aiUseItem() {
    if (!power || phase != LudoPhase.waitingRoll) return null;
    final me = current;
    final mine = tokens[me]!;
    // درع إذا كانت قطعة متقدمة مهددة
    if (itemCount(me, LudoItem.shield) > 0 && !shielded.contains(me)) {
      final threatened = mine.any((t) {
        final g = t.globalIndex;
        return g != null && !LudoGeo.isSafeGlobal(g) && t.pos > 12 && _threatAt(me, g) > 0;
      });
      if (threatened && useItem(LudoItem.shield)) return LudoItem.shield;
    }
    // تحكم بالنرد: لأكل قطعة أو لإخراج قطعة إذا كانت كل القطع في البيت
    if (itemCount(me, LudoItem.diceControl) > 0) {
      for (var v = 6; v >= 1; v--) {
        final moves = movesFor(me, v);
        final eats = moves.any((m) {
          final g = LudoGeo.globalIndex(me, m.to);
          return g != null &&
              !LudoGeo.isSafeGlobal(g) &&
              allTokens.any((o) => !allies(o.color, me) && o.globalIndex == g && !isProtected(o));
        });
        if (eats && useItem(LudoItem.diceControl, value: v)) return LudoItem.diceControl;
      }
      if (mine.every((t) => t.inYard) && useItem(LudoItem.diceControl, value: 6)) return LudoItem.diceControl;
    }
    // مسافة مضاعفة أحياناً عندما تكون قطعة بعيدة على المسار
    if (itemCount(me, LudoItem.doubleDistance) > 0 &&
        mine.any((t) => t.pos >= 0 && t.pos < 30) &&
        _random.nextDouble() < .25 &&
        useItem(LudoItem.doubleDistance)) {
      return LudoItem.doubleDistance;
    }
    return null;
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
      final captures = allTokens.where((o) => !allies(o.color, c) && o.globalIndex == g && !isProtected(o)).toList();
      if (power && LudoGeo.bonusIndices.contains(g)) s += 25;
      if (captures.isNotEmpty && !LudoGeo.isSafeGlobal(g)) {
        s += 60 + captures.fold<int>(0, (a, o) => a + o.pos);
      }
      if (LudoGeo.isSafeGlobal(g)) s += 15;
      if (!LudoGeo.isSafeGlobal(g) && !shielded.contains(c)) s -= 30 * _threatAt(c, g);
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
      if (allies(o.color, me)) continue;
      final og = o.globalIndex;
      if (og == null) continue;
      final dist = (g - og) % LudoGeo.trackLength;
      // يجب ألا يكون الخصم قد تجاوز مدخل ممره قبل الوصول
      if (dist >= 1 && dist <= 6 && o.pos + dist <= LudoGeo.lastTrack) n++;
    }
    return n;
  }
}
