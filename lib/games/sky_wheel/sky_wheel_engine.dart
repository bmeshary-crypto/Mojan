import 'dart:math';

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
  SkyWheelGame({Random? random, this.round = 1}) : _rng = random ?? Random();
  final Random _rng;

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
    for (var i = 0; i < 3; i++) {
      final key = _rng.nextDouble() < .2
          ? skyGroups[_rng.nextInt(skyGroups.length)].id
          : skyPods[_rng.nextInt(skyPods.length)].id;
      totals[key] = (totals[key] ?? 0) + skyChips[_rng.nextInt(3)] * (1 + _rng.nextInt(5));
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

  /// يبدأ السحب ويحدد الكابينة الفائزة.
  String startSpin({String? forced}) {
    phase = SkyPhase.spinning;
    winner = forced ?? pickWinner();
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
      for (var i = 0; i < 3 + _rng.nextInt(3); i++)
        () {
          final (name, av) = botPool[_rng.nextInt(botPool.length)];
          final stake = skyChips[_rng.nextInt(4)] * (1 + _rng.nextInt(4));
          return SkyWinner(name, av, stake * skyPod(w).mult);
        }(),
      if (lastPayout > 0) SkyWinner(myName, myAvatar, lastPayout, isMe: true),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    roundWinners = winners.take(3).toList();
    for (final x in winners) {
      final prev = hourly[x.name];
      hourly[x.name] = SkyWinner(x.name, x.avatar, (prev?.amount ?? 0) + x.amount, isMe: x.isMe);
    }
    return lastPayout;
  }

  List<SkyWinner> get hourlyTop {
    final l = hourly.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
    return l.take(20).toList();
  }

  /// جولة جديدة.
  void next() {
    round++;
    phase = SkyPhase.betting;
    myBets.clear();
    totals.clear();
    winner = null;
    lastPayout = 0;
  }
}
