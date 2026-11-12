import 'dart:math';

import '../../core/rounds/shared_rounds.dart';

/// كابينة في عجلة السماء: صورة ومضاعف ربح.
class SkyPod {
  const SkyPod(this.id, this.title, this.art, this.mult);
  final String id;
  final String title;
  final String art;
  final int mult;
}

/// الكبائن بترتيبها حول العجلة (التاج في الأعلى). التاج هو أعلى ربح.
const skyPods = <SkyPod>[
  SkyPod('crown', 'التاج', 'sw_crown', 45),
  SkyPod('lollipop', 'مصاصة', 'sw_lollipop', 5),
  SkyPod('teddy', 'دبدوب', 'sw_teddy', 15),
  SkyPod('donut', 'دونات', 'sw_donut', 5),
  SkyPod('balloons', 'بالونات', 'sw_balloons', 10),
  SkyPod('icecream', 'آيس كريم', 'sw_icecream', 5),
  SkyPod('ring', 'خاتم', 'gift_ring', 25),
  SkyPod('cupcake', 'كب كيك', 'sw_cupcake', 5),
];

SkyPod skyPod(String id) => skyPods.firstWhere((p) => p.id == id);

/// رهانات المجموعات: تربح إذا وقف السهم على أي كابينة منها.
class SkyGroup {
  const SkyGroup(this.id, this.title, this.pods, this.payout);
  final String id;
  final String title;
  final List<String> pods;

  /// المضاعف (عشري، مثل 1.2).
  final double payout;
}

const skyGroups = <SkyGroup>[
  SkyGroup('g.sweets', 'الحلويات', ['lollipop', 'donut', 'icecream', 'cupcake'], 1.2),
  SkyGroup('g.toys', 'الألعاب', ['balloons', 'teddy'], 5.5),
];

/// قيم الرهان المتاحة.
const skyChips = [10, 100, 1000, 10000];

/// أقصى مشاركة أو ربح للاعبين الآليين (حتى لا يصير تضخم في العملات).
const skyBotCap = 50000;

enum SkyPhase { betting, spinning, result }

class SkyWinner {
  SkyWinner(this.name, this.avatar, this.amount, {this.isMe = false});
  final String name;
  final int avatar;
  final int amount;
  final bool isMe;
}

/// منطق عجلة السماء بدون أي رسم.
///
/// احتمال كل كابينة يتناسب عكسياً مع مضاعفها، فيرجع للاعبين في المتوسط
/// قرابة 97٪ من رهاناتهم. هذه عملات افتراضية داخل اللعبة فقط.
class SkyWheelGame {
  SkyWheelGame({Random? random, this.round = 1, this.synced = false}) : _rng = random ?? Random();
  final Random _rng;

  /// جولات موحدة لكل الأجهزة: النتيجة والرهانات الآلية والفائزين محسوبة من رقم الجولة.
  final bool synced;
  int _botTick = 0;

  /// طول الجولة الموحدة: 15 ثانية رهان + دوران + عرض النتيجة.
  static const rounds = FixedRounds(25000);
  static const betMs = 15000;
  static const spinMs = 5200;

  /// الكابينة الفائزة في جولة موحدة معينة (نفسها على كل الأجهزة).
  static String winnerFor(int round) => _pick(roundRng('sky', round, 'win'));

  static String _pick(Random r) {
    var x = r.nextDouble() * totalWeight;
    for (final p in skyPods) {
      x -= weightOf(p);
      if (x <= 0) return p.id;
    }
    return skyPods.last.id;
  }

  /// كبار الفائزين الآليين في جولة (نفس الأسماء على كل الأجهزة في الوضع الموحد).
  static List<SkyWinner> botWinners(Random r, String win, List<(String, int)> botPool) => [
        for (var i = 0, n = 3 + r.nextInt(3); i < n; i++)
          () {
            final (name, av) = botPool[r.nextInt(botPool.length)];
            final stake = skyChips[r.nextInt(3)] * (1 + r.nextInt(4));
            return SkyWinner(name, av, min(stake * skyPod(win).mult, skyBotCap));
          }(),
      ];

  void _addHourly(List<SkyWinner> winners) {
    for (final x in winners) {
      final prev = hourly[x.name];
      final sum = (prev?.amount ?? 0) + x.amount;
      hourly[x.name] = SkyWinner(x.name, x.avatar, x.isMe ? sum : min(sum, skyBotCap), isMe: x.isMe);
    }
  }

  /// يجهز اللعبة لجولة موحدة: آخر النتائج وترتيب الساعة من الجولات السابقة.
  void loadShared(int current, List<(String, int)> botPool, {required int hourStartRound}) {
    round = current;
    history
      ..clear()
      ..addAll([for (var r = current - 1; r > current - 9; r--) winnerFor(r)]);
    hourly.clear();
    for (var r = hourStartRound; r < current; r++) {
      final w = winnerFor(r);
      _addHourly(botWinners(roundRng('sky', r, 'top'), w, botPool));
    }
  }

  int round;
  SkyPhase phase = SkyPhase.betting;

  /// رهاناتي في الجولة الحالية (معرف الكابينة أو المجموعة ← المبلغ).
  final Map<String, int> myBets = {};

  /// مجموع رهانات الجميع على كل خانة (للعرض).
  final Map<String, int> totals = {};

  /// آخر النتائج (الأحدث أولاً).
  final List<String> history = [];

  /// ربحي اليوم ومجموع ما راهنت به.
  int todayWin = 0;
  int todayBet = 0;

  String? winner;
  int lastPayout = 0;
  List<SkyWinner> roundWinners = [];

  /// ترتيب الفائزين في الساعة (الاسم ← المجموع).
  final Map<String, SkyWinner> hourly = {};

  static double weightOf(SkyPod p) => 1 / p.mult;
  static double get totalWeight => skyPods.fold(0.0, (a, p) => a + weightOf(p));
  static double chanceOf(String podId) => weightOf(skyPod(podId)) / totalWeight;

  int get myTotal => myBets.values.fold(0, (a, b) => a + b);

  /// يسجل رهاناً (بعد خصم العملات من الرصيد). يرجع false خارج وقت الرهان.
  bool bet(String key, int amount) {
    if (phase != SkyPhase.betting || amount <= 0) return false;
    assert(skyPods.any((p) => p.id == key) || skyGroups.any((g) => g.id == key));
    myBets[key] = (myBets[key] ?? 0) + amount;
    totals[key] = (totals[key] ?? 0) + amount;
    todayBet += amount;
    return true;
  }

  /// رهانات اللاعبين الآخرين (محاكاة حتى يشتغل السيرفر).
  void botsBet() {
    if (phase != SkyPhase.betting) return;
    final rng = synced ? roundRng('sky', round, 'bets${_botTick++}') : _rng;
    for (var i = 0; i < 3; i++) {
      final key = rng.nextDouble() < .2
          ? skyGroups[rng.nextInt(skyGroups.length)].id
          : skyPods[rng.nextInt(skyPods.length)].id;
      totals[key] = min((totals[key] ?? 0) + skyChips[rng.nextInt(3)] * (1 + rng.nextInt(5)), skyBotCap);
    }
  }

  String pickWinner() {
    var r = _rng.nextDouble() * totalWeight;
    for (final p in skyPods) {
      r -= weightOf(p);
      if (r <= 0) return p.id;
    }
    return skyPods.last.id;
  }

  /// ربح رهانات معينة إذا فازت كابينة معينة.
  static int payoutFor(Map<String, int> bets, String win) {
    var total = 0.0;
    bets.forEach((k, v) {
      if (k == win) total += v * skyPod(win).mult;
      for (final g in skyGroups) {
        if (k == g.id && g.pods.contains(win)) total += v * g.payout;
      }
    });
    return total.floor();
  }

  /// النتائج القادمة محسوبة مسبقاً (يشوفها الأدمن فقط).
  final List<String> upcoming = [];

  List<String> peekUpcoming([int n = 6]) {
    if (synced) return [for (var i = 0; i < n; i++) winnerFor(round + i)];
    while (upcoming.length < n) {
      upcoming.add(pickWinner());
    }
    return upcoming.take(n).toList();
  }

  /// يبدأ السحب ويحدد الكابينة الفائزة.
  String startSpin({String? forced}) {
    phase = SkyPhase.spinning;
    if (synced) {
      winner = forced ?? winnerFor(round);
      return winner!;
    }
    peekUpcoming();
    final next = upcoming.removeAt(0);
    winner = forced ?? next;
    return winner!;
  }

  /// ينهي الجولة: يحسب ربحي وكبار الفائزين. يرجع ربحي (يضاف للرصيد خارج المحرك).
  int settle(List<(String, int)> botPool, {required String myName, required int myAvatar}) {
    final w = winner!;
    phase = SkyPhase.result;
    lastPayout = payoutFor(myBets, w);
    todayWin += lastPayout;
    history.insert(0, w);
    if (history.length > 20) history.removeLast();

    final winners = <SkyWinner>[
      ...botWinners(synced ? roundRng('sky', round, 'top') : _rng, w, botPool),
      if (lastPayout > 0) SkyWinner(myName, myAvatar, lastPayout, isMe: true),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    roundWinners = winners.take(3).toList();
    _addHourly(winners);
    return lastPayout;
  }

  List<SkyWinner> get hourlyTop {
    final l = hourly.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
    return l.take(20).toList();
  }

  /// جولة جديدة.
  void next() {
    round++;
    _botTick = 0;
    phase = SkyPhase.betting;
    myBets.clear();
    totals.clear();
    winner = null;
    lastPayout = 0;
  }
}
