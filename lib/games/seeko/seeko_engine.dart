import 'dart:math';

/// ورقة لعب. الرتبة: A,2..10,J,Q,K والنوع: S ♠، H ♥، D ♦، C ♣.
class SeekoCard {
  const SeekoCard(this.rank, this.suit);
  final String rank;
  final String suit;

  static const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
  static const suits = ['S', 'H', 'D', 'C'];

  bool get isJack => rank == 'J';

  /// الولد بعينين (♦ و♣) يوضع في أي خانة فارغة.
  bool get isTwoEyedJack => isJack && (suit == 'D' || suit == 'C');

  /// الولد بعين واحدة (♠ و♥) يزيل قطعة خصم.
  bool get isOneEyedJack => isJack && (suit == 'S' || suit == 'H');

  bool get isRed => suit == 'H' || suit == 'D';

  String get symbol => const {'S': '♠', 'H': '♥', 'D': '♦', 'C': '♣'}[suit]!;

  String get code => '$rank$suit';

  @override
  bool operator ==(Object other) => other is SeekoCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}

typedef Cell = (int, int); // (صف، عمود)

/// لوح سيكو الخاص بنا: 10×10، الزوايا الأربع حرة،
/// وكل ورقة (ما عدا الأولاد) تظهر مرتين بترتيب ثابت خاص بـ MOJAN.
class SeekoBoard {
  static const size = 10;

  static final List<List<SeekoCard?>> layout = () {
    final cards = <SeekoCard>[];
    for (final s in SeekoCard.suits) {
      for (final r in SeekoCard.ranks) {
        if (r != 'J') cards.add(SeekoCard(r, s));
      }
    }
    // نسختان من كل ورقة، مرتبتان بخلط ثابت
    final all = [...cards, ...cards]..shuffle(Random(2026));
    final grid = List.generate(size, (_) => List<SeekoCard?>.filled(size, null));
    var i = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (isCorner((r, c))) continue;
        grid[r][c] = all[i++];
      }
    }
    return grid;
  }();

  static bool isCorner(Cell p) => (p.$1 == 0 || p.$1 == size - 1) && (p.$2 == 0 || p.$2 == size - 1);

  static SeekoCard? cardAt(Cell p) => layout[p.$1][p.$2];

  static final Map<SeekoCard, List<Cell>> cellsOf = () {
    final m = <SeekoCard, List<Cell>>{};
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final card = layout[r][c];
        if (card != null) m.putIfAbsent(card, () => []).add((r, c));
      }
    }
    return m;
  }();

  static bool inside(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;
}

enum SeekoActionType { place, remove }

class SeekoPlay {
  const SeekoPlay({required this.handIndex, required this.cell, required this.type});
  final int handIndex;
  final Cell cell;
  final SeekoActionType type;
}

class SeekoPlayResult {
  const SeekoPlayResult({required this.newSequences, required this.drew});
  final List<List<Cell>> newSequences;
  final SeekoCard? drew;
}

enum SeekoPhase { playing, gameOver }

/// محرك قواعد سيكو.
class SeekoGame {
  SeekoGame({required this.playerCount, Random? random})
      : assert(playerCount >= 2 && playerCount <= 4),
        _random = random ?? Random() {
    for (var d = 0; d < 2; d++) {
      for (final s in SeekoCard.suits) {
        for (final r in SeekoCard.ranks) {
          deck.add(SeekoCard(r, s));
        }
      }
    }
    deck.shuffle(_random);
    final handSize = playerCount == 2 ? 7 : 6;
    hands = List.generate(playerCount, (_) => [for (var i = 0; i < handSize; i++) deck.removeLast()]);
  }

  final int playerCount;
  final Random _random;
  final List<SeekoCard> deck = [];
  final List<SeekoCard> discard = [];
  late final List<List<SeekoCard>> hands;

  /// رقم الفريق في كل خانة، أو null.
  final chips = List.generate(SeekoBoard.size, (_) => List<int?>.filled(SeekoBoard.size, null));

  /// الخانات التي أصبحت جزءاً من صف مكتمل (لا يمكن إزالتها).
  final Set<Cell> locked = {};
  final List<List<Cell>> sequences = [];
  late final List<int> sequenceCount = List.filled(teamCount, 0);

  int current = 0;
  SeekoPhase phase = SeekoPhase.playing;
  int? winner; // رقم الفريق
  bool exchangedThisTurn = false;

  /// 4 لاعبين = فريقان، غير ذلك كل لاعب فريق.
  int get teamCount => playerCount == 4 ? 2 : playerCount;
  int teamOf(int player) => player % teamCount;

  /// عدد الصفوف المطلوبة للفوز.
  int get sequencesToWin => teamCount == 3 ? 1 : 2;

  int get currentTeam => teamOf(current);

  bool _ownedBy(int r, int c, int team) =>
      SeekoBoard.isCorner((r, c)) || chips[r][c] == team;

  /// الخانات الممكنة لورقة معينة.
  List<Cell> targetsFor(SeekoCard card, int team) {
    if (card.isTwoEyedJack) {
      return [
        for (var r = 0; r < SeekoBoard.size; r++)
          for (var c = 0; c < SeekoBoard.size; c++)
            if (!SeekoBoard.isCorner((r, c)) && chips[r][c] == null) (r, c),
      ];
    }
    if (card.isOneEyedJack) {
      return [
        for (var r = 0; r < SeekoBoard.size; r++)
          for (var c = 0; c < SeekoBoard.size; c++)
            if (chips[r][c] != null && chips[r][c] != team && !locked.contains((r, c))) (r, c),
      ];
    }
    return [for (final p in SeekoBoard.cellsOf[card]!) if (chips[p.$1][p.$2] == null) p];
  }

  /// الورقة "ميتة" إذا كانت كل خاناتها مشغولة: يمكن استبدالها.
  bool isDead(SeekoCard card) => !card.isJack && targetsFor(card, currentTeam).isEmpty;

  bool canExchange(int handIndex) =>
      phase == SeekoPhase.playing &&
      !exchangedThisTurn &&
      deck.isNotEmpty &&
      isDead(hands[current][handIndex]);

  /// استبدال ورقة ميتة بورقة جديدة (مرة واحدة في الدور).
  SeekoCard exchangeDead(int handIndex) {
    assert(canExchange(handIndex));
    final card = hands[current].removeAt(handIndex);
    discard.add(card);
    final drawn = deck.removeLast();
    hands[current].add(drawn);
    exchangedThisTurn = true;
    return drawn;
  }

  List<SeekoPlay> legalPlays() {
    if (phase != SeekoPhase.playing) return const [];
    final out = <SeekoPlay>[];
    final hand = hands[current];
    for (var i = 0; i < hand.length; i++) {
      final card = hand[i];
      final type = card.isOneEyedJack ? SeekoActionType.remove : SeekoActionType.place;
      for (final cell in targetsFor(card, currentTeam)) {
        out.add(SeekoPlay(handIndex: i, cell: cell, type: type));
      }
    }
    return out;
  }

  bool isLegal(SeekoPlay p) {
    if (phase != SeekoPhase.playing) return false;
    if (p.handIndex < 0 || p.handIndex >= hands[current].length) return false;
    final card = hands[current][p.handIndex];
    return targetsFor(card, currentTeam).contains(p.cell);
  }

  SeekoPlayResult play(SeekoPlay p) {
    assert(isLegal(p), 'حركة غير مسموحة');
    final team = currentTeam;
    final card = hands[current].removeAt(p.handIndex);
    discard.add(card);
    final (r, c) = p.cell;
    var newSeqs = <List<Cell>>[];
    if (card.isOneEyedJack) {
      chips[r][c] = null;
    } else {
      chips[r][c] = team;
      newSeqs = _detectSequences(p.cell, team);
      for (final s in newSeqs) {
        sequences.add(s);
        locked.addAll(s);
        sequenceCount[team]++;
      }
      if (sequenceCount[team] >= sequencesToWin) {
        phase = SeekoPhase.gameOver;
        winner = team;
      }
    }

    SeekoCard? drew;
    if (deck.isNotEmpty) {
      drew = deck.removeLast();
      hands[current].add(drew);
    }

    if (phase == SeekoPhase.playing) _nextTurn();
    return SeekoPlayResult(newSequences: newSeqs, drew: drew);
  }

  void _nextTurn() {
    exchangedThisTurn = false;
    for (var i = 0; i < playerCount; i++) {
      current = (current + 1) % playerCount;
      if (legalPlays().isNotEmpty) return;
    }
    // لا يستطيع أحد اللعب: تنتهي اللعبة بالتعادل
    phase = SeekoPhase.gameOver;
    winner = null;
  }

  static const _dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];

  /// يبحث عن صفوف جديدة من 5 تمر بالخانة. الصف الجديد يمكن أن يشارك
  /// صفاً سابقاً بخانة واحدة فقط.
  List<List<Cell>> _detectSequences(Cell at, int team) {
    final found = <List<Cell>>[];
    for (final (dr, dc) in _dirs) {
      // كل الخط المتصل الذي يملكه الفريق ويمر بالخانة
      var r = at.$1, c = at.$2;
      while (SeekoBoard.inside(r - dr, c - dc) && _ownedBy(r - dr, c - dc, team)) {
        r -= dr;
        c -= dc;
      }
      final run = <Cell>[];
      while (SeekoBoard.inside(r, c) && _ownedBy(r, c, team)) {
        run.add((r, c));
        r += dr;
        c += dc;
      }
      if (run.length < 5) continue;

      final used = <Cell>{};
      for (var start = 0; start + 5 <= run.length; start++) {
        final window = run.sublist(start, start + 5);
        if (!window.contains(at)) continue; // الصف الجديد يجب أن يشمل القطعة الجديدة
        final overlap = window.where((p) => locked.contains(p) || used.contains(p)).length;
        if (overlap > 1) continue;
        found.add(window);
        used.addAll(window);
      }
    }
    return found;
  }

  // ---------------- الذكاء الاصطناعي ----------------

  /// يرجع إما حركة، أو رقم ورقة ميتة لاستبدالها أولاً (exchange).
  ({SeekoPlay? play, int? exchange}) chooseAi() {
    for (var i = 0; i < hands[current].length; i++) {
      if (canExchange(i)) return (play: null, exchange: i);
    }
    final plays = legalPlays();
    final team = currentTeam;
    SeekoPlay? best;
    var bestScore = double.negativeInfinity;
    for (final p in plays) {
      final card = hands[current][p.handIndex];
      double s;
      if (p.type == SeekoActionType.remove) {
        final opp = chips[p.cell.$1][p.cell.$2]!;
        s = _potential(p.cell, opp, ignore: p.cell) * 1.1 - 400;
      } else {
        s = _potential(p.cell, team) + _potential(p.cell, null, blockFor: team) * .9;
        if (card.isTwoEyedJack) s -= 300; // نحتفظ بالولد للحظة المهمة
      }
      s += _random.nextDouble();
      if (s > bestScore) {
        bestScore = s;
        best = p;
      }
    }
    return (play: best, exchange: null);
  }

  /// قيمة الخانة لفريق: مجموع نوافذ الخمسة التي تمر بها ولا يقطعها خصم.
  /// إذا كان team == null يحسب أقوى تهديد للخصوم (للصد).
  double _potential(Cell at, int? team, {int? blockFor, Cell? ignore}) {
    if (team == null) {
      var best = 0.0;
      for (var t = 0; t < teamCount; t++) {
        if (t == blockFor) continue;
        best = max(best, _potential(at, t));
      }
      return best;
    }
    var total = 0.0;
    for (final (dr, dc) in _dirs) {
      for (var k = -4; k <= 0; k++) {
        var own = 0;
        var blocked = false;
        for (var j = 0; j < 5; j++) {
          final r = at.$1 + (k + j) * dr, c = at.$2 + (k + j) * dc;
          if (!SeekoBoard.inside(r, c)) {
            blocked = true;
            break;
          }
          if ((r, c) == at && ignore == null) continue;
          if (SeekoBoard.isCorner((r, c)) || chips[r][c] == team) {
            own++;
          } else if (chips[r][c] != null && (r, c) != ignore) {
            blocked = true;
            break;
          }
        }
        if (!blocked) total += pow(8, own).toDouble();
      }
    }
    return total;
  }
}
