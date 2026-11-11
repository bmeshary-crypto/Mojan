import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthMethod { guest, google, phone }

/// إحصائيات اللاعب في لعبة واحدة.
class GameStats {
  GameStats({this.played = 0, this.wins = 0, this.points = 0, this.best = 0});
  int played;
  int wins;
  int points;
  int best;

  double get winRate => played == 0 ? 0 : wins / played;

  Map<String, dynamic> toJson() => {'p': played, 'w': wins, 'pt': points, 'b': best};
  factory GameStats.fromJson(Map<String, dynamic> j) =>
      GameStats(played: j['p'] ?? 0, wins: j['w'] ?? 0, points: j['pt'] ?? 0, best: j['b'] ?? 0);
}

/// إنجاز يفتح عند تحقق شرط على الملف الشخصي.
class Achievement {
  const Achievement(this.id, this.emoji, this.title, this.description, this.test);
  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool Function(PlayerProfile p) test;
}

const gameTitles = {
  'ludo': 'لودو',
  'seeko': 'سيكو',
  'quiz': 'أسئلة وأجوبة',
  'truth_dare': 'صراحة أو جرأة',
};

final achievements = <Achievement>[
  Achievement('first_game', '🎮', 'البداية', 'العب أول مباراة', (p) => p.totalPlayed >= 1),
  Achievement('first_win', '🏅', 'أول فوز', 'افز في أي لعبة', (p) => p.totalWins >= 1),
  Achievement('wins_10', '🔥', 'لا يُهزم', 'اجمع 10 انتصارات', (p) => p.totalWins >= 10),
  Achievement('ludo_5', '🎲', 'ملك اللودو', 'افز 5 مرات في لودو', (p) => p.statsFor('ludo').wins >= 5),
  Achievement('seeko_5', '🃏', 'خبير سيكو', 'افز 5 مرات في سيكو', (p) => p.statsFor('seeko').wins >= 5),
  Achievement('quiz_5', '🧠', 'العبقري', 'افز 5 مسابقات أسئلة', (p) => p.statsFor('quiz').wins >= 5),
  Achievement('brave', '⚡', 'الجريء', 'العب 5 جولات صراحة أو جرأة', (p) => p.statsFor('truth_dare').played >= 5),
  Achievement('all_games', '🌟', 'متعدد المواهب', 'العب كل الألعاب', (p) => gameTitles.keys.every((g) => p.statsFor(g).played > 0)),
  Achievement('level_5', '🚀', 'صاعد', 'صل للمستوى 5', (p) => p.level >= 5),
  Achievement('daily_7', '📅', 'وفيّ', 'اجمع الهدية اليومية 7 أيام متتالية', (p) => p.dailyStreak >= 7),
];

/// الصور الرمزية المتاحة (رمز + لون).
const avatars = [
  ('🦁', 0xFFFFB13D),
  ('🐯', 0xFFFF7A3D),
  ('🦊', 0xFFFF5A5F),
  ('🐼', 0xFF8E8E9E),
  ('🐸', 0xFF2EBD59),
  ('🦄', 0xFFB86CFF),
  ('🐙', 0xFFFF4D9D),
  ('🦅', 0xFF8D6E63),
  ('🐺', 0xFF5C6BC0),
  ('🐻', 0xFFA1665E),
  ('🐨', 0xFF78909C),
  ('🐲', 0xFF26A69A),
];

class PlayerProfile {
  PlayerProfile({
    required this.id,
    required this.name,
    required this.method,
    this.avatar = 0,
    this.contact,
    this.coins = 500,
    this.xp = 0,
    Map<String, GameStats>? stats,
    Set<String>? unlocked,
    this.dailyStreak = 0,
    this.lastDaily,
    DateTime? createdAt,
  })  : stats = stats ?? {},
        unlocked = unlocked ?? {},
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  AuthMethod method;
  int avatar;

  /// البريد أو رقم الهاتف حسب طريقة الدخول.
  String? contact;
  int coins;
  int xp;
  final Map<String, GameStats> stats;
  final Set<String> unlocked;
  int dailyStreak;
  String? lastDaily;
  final DateTime createdAt;

  GameStats statsFor(String game) => stats.putIfAbsent(game, GameStats.new);
  int get totalPlayed => stats.values.fold(0, (a, s) => a + s.played);
  int get totalWins => stats.values.fold(0, (a, s) => a + s.wins);
  int get totalPoints => stats.values.fold(0, (a, s) => a + s.points);

  /// المستوى: يحتاج المستوى n إلى 100 + 50×(n-1) نقطة خبرة.
  static (int level, int into, int need) levelOf(int xp) {
    var level = 1, need = 100, left = xp;
    while (left >= need) {
      left -= need;
      level++;
      need += 50;
    }
    return (level, left, need);
  }

  int get level => levelOf(xp).$1;
  double get levelProgress {
    final (_, into, need) = levelOf(xp);
    return into / need;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'method': method.name,
        'avatar': avatar,
        'contact': contact,
        'coins': coins,
        'xp': xp,
        'stats': stats.map((k, v) => MapEntry(k, v.toJson())),
        'unlocked': unlocked.toList(),
        'dailyStreak': dailyStreak,
        'lastDaily': lastDaily,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> j) => PlayerProfile(
        id: j['id'],
        name: j['name'],
        method: AuthMethod.values.byName(j['method'] ?? 'guest'),
        avatar: j['avatar'] ?? 0,
        contact: j['contact'],
        coins: j['coins'] ?? 0,
        xp: j['xp'] ?? 0,
        stats: (j['stats'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, GameStats.fromJson(v as Map<String, dynamic>))),
        unlocked: {...(j['unlocked'] as List? ?? []).cast<String>()},
        dailyStreak: j['dailyStreak'] ?? 0,
        lastDaily: j['lastDaily'],
        createdAt: DateTime.tryParse(j['createdAt'] ?? ''),
      );
}

/// ما يكسبه اللاعب بعد مباراة.
class Reward {
  const Reward({required this.xp, required this.coins, required this.levelUp, required this.newLevel, required this.unlocked});
  final int xp;
  final int coins;
  final bool levelUp;
  final int newLevel;
  final List<Achievement> unlocked;
}

/// حساب اللاعب الحالي وإعداداته، محفوظة على الجهاز.
class Account extends ChangeNotifier {
  Account._();
  static final Account instance = Account._();

  static const _profileKey = 'mojan.profile';
  static const _settingsKey = 'mojan.settings';

  PlayerProfile? profile;
  bool haptics = true;
  bool sounds = true;
  bool loaded = false;

  bool get signedIn => profile != null;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profileKey);
      if (raw != null) profile = PlayerProfile.fromJson(jsonDecode(raw));
      final s = prefs.getString(_settingsKey);
      if (s != null) {
        final m = jsonDecode(s) as Map<String, dynamic>;
        haptics = m['haptics'] ?? true;
        sounds = m['sounds'] ?? true;
      }
    } catch (e) {
      debugPrint('Account.load failed: $e');
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (profile == null) {
        await prefs.remove(_profileKey);
      } else {
        await prefs.setString(_profileKey, jsonEncode(profile!.toJson()));
      }
      await prefs.setString(_settingsKey, jsonEncode({'haptics': haptics, 'sounds': sounds}));
    } catch (e) {
      debugPrint('Account.save failed: $e');
    }
  }

  static String _newId() {
    final r = Random();
    return List.generate(8, (_) => r.nextInt(10)).join();
  }

  Future<void> signIn({required AuthMethod method, required String name, String? contact, String? id}) async {
    profile = PlayerProfile(
      id: id ?? _newId(),
      name: name.trim().isEmpty ? 'لاعب ${_newId().substring(0, 4)}' : name.trim(),
      method: method,
      contact: contact,
      avatar: Random().nextInt(avatars.length),
    );
    await _save();
  }

  /// ربط حساب الضيف بجوجل أو الهاتف مع الاحتفاظ بالتقدم.
  Future<void> link({required AuthMethod method, String? contact}) async {
    if (profile == null) return;
    profile!
      ..method = method
      ..contact = contact;
    await _save();
  }

  Future<void> signOut() async {
    profile = null;
    await _save();
  }

  Future<void> rename(String name) async {
    if (profile == null || name.trim().isEmpty) return;
    profile!.name = name.trim().length > 18 ? name.trim().substring(0, 18) : name.trim();
    await _save();
  }

  Future<void> setAvatar(int i) async {
    if (profile == null) return;
    profile!.avatar = i % avatars.length;
    await _save();
  }

  Future<void> setHaptics(bool v) async {
    haptics = v;
    await _save();
  }

  Future<void> setSounds(bool v) async {
    sounds = v;
    await _save();
  }

  /// يسجل نتيجة مباراة ويرجع المكافأة. لا يفعل شيئاً إن لم يكن هناك حساب.
  Reward? recordGame(String game, {required bool won, int points = 0}) {
    final p = profile;
    if (p == null) return null;
    final s = p.statsFor(game)
      ..played += 1
      ..points += points;
    if (won) s.wins += 1;
    if (points > s.best) s.best = points;

    final before = p.level;
    final int xp = (won ? 60 : 20) + min<int>(points ~/ 200, 40);
    final coins = won ? 100 : 25;
    p.xp += xp;
    p.coins += coins;
    final unlocked = _checkAchievements();
    _save();
    return Reward(xp: xp, coins: coins, levelUp: p.level > before, newLevel: p.level, unlocked: unlocked);
  }

  List<Achievement> _checkAchievements() {
    final p = profile!;
    final fresh = <Achievement>[];
    for (final a in achievements) {
      if (!p.unlocked.contains(a.id) && a.test(p)) {
        p.unlocked.add(a.id);
        p.coins += 50;
        fresh.add(a);
      }
    }
    return fresh;
  }

  static String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

  bool get dailyAvailable => profile != null && profile!.lastDaily != _day(DateTime.now());

  /// الهدية اليومية: 100 عملة × أيام السلسلة (حتى 7).
  int? claimDaily({DateTime? now}) {
    final p = profile;
    now ??= DateTime.now();
    if (p == null || p.lastDaily == _day(now)) return null;
    final yesterday = _day(now.subtract(const Duration(days: 1)));
    p.dailyStreak = p.lastDaily == yesterday ? p.dailyStreak + 1 : 1;
    p.lastDaily = _day(now);
    final int amount = 100 * min<int>(p.dailyStreak, 7);
    p.coins += amount;
    _checkAchievements();
    _save();
    return amount;
  }

  @visibleForTesting
  void reset() {
    profile = null;
    haptics = true;
    sounds = true;
  }
}
