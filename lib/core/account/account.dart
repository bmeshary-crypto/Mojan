import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../games/ludo/ludo_engine.dart';
import '../ban.dart';
import '../firebase/cloud.dart';
import '../shop.dart';
import '../vip.dart';

enum AuthMethod { guest, google, phone }

/// إحصائيات اللاعب في لعبة واحدة.
class GameStats {
  GameStats({this.played = 0, this.wins = 0, this.points = 0, this.best = 0});
  int played;
  int wins;
  int points;
  int best;

  double get winRate => played == 0 ? 0 : wins / played;

  Map<String, dynamic> toJson() => {
    'p': played,
    'w': wins,
    'pt': points,
    'b': best,
  };
  factory GameStats.fromJson(Map<String, dynamic> j) => GameStats(
    played: j['p'] ?? 0,
    wins: j['w'] ?? 0,
    points: j['pt'] ?? 0,
    best: j['b'] ?? 0,
  );
}

/// إنجاز يفتح عند تحقق شرط على الملف الشخصي.
class Achievement {
  const Achievement(
    this.id,
    this.emoji,
    this.title,
    this.description,
    this.test,
  );
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
  'blocks': 'مكعبات',
  'arena': 'ساحة البقاء',
  'sky_wheel': 'عجلة السماء',
  'fruits': 'سوق الفواكه',
  'star_league': 'دوري النجوم',
  'lucky_slots': 'ماكينة الحظ',
  'sultan': 'كنز السلطان',
  'treasure': 'صناديق الكنز',
  'pegs': 'هرم المسامير',
  'rocket': 'صاروخ المجرة',
};

/// ألعاب الرهان بالعملات لا تدخل في مجموع المباريات والنقاط العام
/// (نقاطها = العملات المربوحة، فتطغى على باقي الألعاب).
const coinGames = {'sky_wheel', 'fruits', 'treasure', 'pegs', 'rocket', 'star_league', 'lucky_slots', 'sultan'};

final achievements = <Achievement>[
  Achievement(
    'first_game',
    '🎮',
    'البداية',
    'العب أول مباراة',
    (p) => p.totalPlayed >= 1,
  ),
  Achievement(
    'first_win',
    '🏅',
    'أول فوز',
    'افز في أي لعبة',
    (p) => p.totalWins >= 1,
  ),
  Achievement(
    'wins_10',
    '🔥',
    'لا يُهزم',
    'اجمع 10 انتصارات',
    (p) => p.totalWins >= 10,
  ),
  Achievement(
    'ludo_5',
    '🎲',
    'ملك اللودو',
    'افز 5 مرات في لودو',
    (p) => p.statsFor('ludo').wins >= 5,
  ),
  Achievement(
    'seeko_5',
    '🃏',
    'خبير سيكو',
    'افز 5 مرات في سيكو',
    (p) => p.statsFor('seeko').wins >= 5,
  ),
  Achievement(
    'quiz_5',
    '🧠',
    'العبقري',
    'افز 5 مسابقات أسئلة',
    (p) => p.statsFor('quiz').wins >= 5,
  ),
  Achievement(
    'brave',
    '⚡',
    'الجريء',
    'العب 5 جولات صراحة أو جرأة',
    (p) => p.statsFor('truth_dare').played >= 5,
  ),
  Achievement(
    'all_games',
    '🌟',
    'متعدد المواهب',
    'العب كل الألعاب',
    (p) => gameTitles.keys
        .where((g) => !coinGames.contains(g))
        .every((g) => p.statsFor(g).played > 0),
  ),
  Achievement('level_5', '🚀', 'صاعد', 'صل للمستوى 5', (p) => p.level >= 5),
  Achievement(
    'daily_7',
    '📅',
    'وفيّ',
    'اجمع الهدية اليومية 7 أيام متتالية',
    (p) => p.dailyStreak >= 7,
  ),
];

/// مباراة منتهية في سجل الجهاز.
class MatchRecord {
  const MatchRecord({
    required this.game,
    required this.player,
    required this.won,
    required this.points,
    required this.at,
  });
  final String game;
  final String player;
  final bool won;
  final int points;
  final DateTime at;
}

/// الصور الرمزية المتاحة (رمز + لون).
/// صور الشخصيات الكرتونية (assets/images/av_N.webp): من 0 إلى 15 الزوجي بنات
/// والفردي أولاد، و16 و17 بنات.
const avatars = [
  ('👧', 0xFF26A69A),
  ('👦', 0xFFFFB13D),
  ('👧', 0xFFFF4D9D),
  ('👦', 0xFF5C6BC0),
  ('👧', 0xFFB86CFF),
  ('👦', 0xFF78909C),
  ('👧', 0xFF26A69A),
  ('👦', 0xFFFFB13D),
  ('👧', 0xFFFF4D9D),
  ('👦', 0xFF5C6BC0),
  ('👧', 0xFFB86CFF),
  ('👦', 0xFF78909C),
  ('👧', 0xFF26A69A),
  ('👦', 0xFFFFB13D),
  ('👧', 0xFFFF4D9D),
  ('👦', 0xFF5C6BC0),
  ('👧', 0xFFB86CFF),
  ('👦', 0xFF78909C),
];

bool avatarIsGirl(int i) => i >= 16 || i % 2 == 0;

/// منشور في الملف الشخصي.
class ProfilePost {
  ProfilePost({
    required this.id,
    required this.text,
    this.mood = 0,
    DateTime? at,
    this.likes = 0,
    this.liked = false,
    this.comments = 0,
  }) : at = at ?? DateTime.now();
  final String id;
  String text;

  /// خلفية المنشور (رقم من postMoods).
  int mood;
  final DateTime at;
  int likes;
  bool liked;
  int comments;

  Map<String, dynamic> toJson() => {
    'id': id,
    't': text,
    'm': mood,
    'at': at.toIso8601String(),
    'l': likes,
    'ld': liked,
    'c': comments,
  };
  factory ProfilePost.fromJson(Map<String, dynamic> j) => ProfilePost(
    id: j['id'] ?? '',
    text: j['t'] ?? '',
    mood: j['m'] ?? 0,
    at: DateTime.tryParse(j['at'] ?? ''),
    likes: j['l'] ?? 0,
    liked: j['ld'] ?? false,
    comments: j['c'] ?? 0,
  );
}

/// حدث في سجل نشاط اللاعب (يظهر للإدارة في صفحة المستخدم).
/// k: game (مباراة)، bet (جولات ألعاب العملات)، buy، gift، reward، admin، room، login، diamonds.
class ActEntry {
  ActEntry({required this.kind, required this.text, this.coins = 0, this.game, DateTime? at, this.count = 1, this.bet = 0, this.won = 0})
      : at = at ?? DateTime.now();
  final String kind;
  String text;
  /// التغير في العملات بسبب هذا الحدث (موجب = دخل، سالب = صرف).
  int coins;
  final String? game;
  DateTime at;
  /// لجولات ألعاب العملات المتتالية: عدد الجولات ومجموع الرهان والربح.
  int count;
  int bet;
  int won;

  Map<String, dynamic> toJson() => {
    'k': kind,
    'x': text,
    if (coins != 0) 'c': coins,
    'g': ?game,
    't': at.millisecondsSinceEpoch,
    if (count != 1) 'n': count,
    if (bet != 0) 'b': bet,
    if (won != 0) 'w': won,
  };

  static ActEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final t = j['t'];
    return ActEntry(
      kind: j['k'] as String? ?? 'other',
      text: j['x'] as String? ?? '',
      coins: (j['c'] as num?)?.toInt() ?? 0,
      game: j['g'] as String?,
      at: t is num ? DateTime.fromMillisecondsSinceEpoch(t.toInt()) : null,
      count: (j['n'] as num?)?.toInt() ?? 1,
      bet: (j['b'] as num?)?.toInt() ?? 0,
      won: (j['w'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlayerProfile {
  PlayerProfile({
    required this.id,
    required this.name,
    required this.method,
    this.avatar = 0,
    this.contact,
    this.coins = 500,
    this.diamonds = 0,
    this.xp = 0,
    Map<String, GameStats>? stats,
    Set<String>? unlocked,
    this.dailyStreak = 0,
    this.lastDaily,
    DateTime? createdAt,
    Map<String, int>? inventory,
    Set<String>? owned,
    this.diceSkin = 'classic',
    this.boardTheme = 'classic',
    this.lastChest,
    this.frame = 'none',
    this.entrance = 'none',
    this.bubble = 'none',
    this.chair = 'none',
    this.bio = '',
    List<ProfilePost>? posts,
    this.vipPoints = 0,
    this.lastVipDaily,
    this.specialId,
    List<ActEntry>? activity,
  }) : posts = posts ?? [],
       activity = activity ?? [],
       stats = stats ?? {},
       unlocked = unlocked ?? {},
       inventory = inventory ?? {},
       owned = owned ?? {},
       createdAt = createdAt ?? DateTime.now();

  /// الأدوات المملوكة (حقيبة اللاعب) حسب اسم الأداة.
  final Map<String, int> inventory;

  /// السكنات والثيمات المشتراة (مثل dice.gold).
  final Set<String> owned;
  String diceSkin;
  String boardTheme;

  /// المظهر في الغرف الصوتية: الإطار والدخولية وفقاعة الدردشة ('none' = بدون).
  String frame;
  String entrance;
  String bubble;

  /// شكل كراسي المايكات في الغرف التي يستضيفها.
  String chair;

  /// نقاط VIP (من الشحن والهدايا والمتجر) وآخر يوم استُلمت فيه مكافأة VIP اليومية.
  int vipPoints;
  String? lastVipDaily;
  int get vipLevel => vipLevelFor(vipPoints);

  /// ID مميز محجوز (VIP3 فأعلى)، وإلا يظهر الـ ID العادي من 8 أرقام.
  String? specialId;
  String get displayId => specialId ?? defaultPlayerId(id);

  /// سجل النشاط (آخر [maxActivity] حدث، الأحدث أولاً).
  final List<ActEntry> activity;
  static const maxActivity = 120;

  /// الملف الشخصي: النبذة والمنشورات.
  String bio;
  final List<ProfilePost> posts;

  /// آخر مرة فُتح فيها صندوق العملات المجاني.
  DateTime? lastChest;

  int itemCount(LudoItem i) => inventory[i.name] ?? 0;
  bool owns(String id) =>
      id.endsWith('.classic') || id.endsWith('.none') || owned.contains(id);

  final String id;
  String name;
  AuthMethod method;
  int avatar;

  /// البريد أو رقم الهاتف حسب طريقة الدخول.
  String? contact;
  int coins;

  /// الماسات: 30% من قيمة الهدايا اللي توصلك من الناس (غير الكوينز المشحونة).
  int diamonds;
  int xp;
  final Map<String, GameStats> stats;
  final Set<String> unlocked;
  int dailyStreak;
  String? lastDaily;
  final DateTime createdAt;

  GameStats statsFor(String game) => stats.putIfAbsent(game, GameStats.new);
  Iterable<GameStats> get _skillStats => stats.entries
      .where((e) => !coinGames.contains(e.key))
      .map((e) => e.value);
  int get totalPlayed => _skillStats.fold(0, (a, s) => a + s.played);
  int get totalWins => _skillStats.fold(0, (a, s) => a + s.wins);
  int get totalPoints => _skillStats.fold(0, (a, s) => a + s.points);

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
    'diamonds': diamonds,
    'xp': xp,
    'stats': stats.map((k, v) => MapEntry(k, v.toJson())),
    'unlocked': unlocked.toList(),
    'dailyStreak': dailyStreak,
    'lastDaily': lastDaily,
    'createdAt': createdAt.toIso8601String(),
    'inventory': inventory,
    'owned': owned.toList(),
    'diceSkin': diceSkin,
    'boardTheme': boardTheme,
    'lastChest': lastChest?.toIso8601String(),
    'frame': frame,
    'entrance': entrance,
    'bubble': bubble,
    'chair': chair,
    'bio': bio,
    'posts': posts.map((e) => e.toJson()).toList(),
    'vp': vipPoints,
    'vd': lastVipDaily,
    'sid': specialId,
    'act': activity.map((e) => e.toJson()).toList(),
  };

  factory PlayerProfile.fromJson(Map<String, dynamic> j) => PlayerProfile(
    id: j['id'],
    name: j['name'],
    method: AuthMethod.values.byName(j['method'] ?? 'guest'),
    avatar: j['avatar'] ?? 0,
    contact: j['contact'],
    coins: j['coins'] ?? 0,
    diamonds: (j['diamonds'] as num?)?.toInt() ?? 0,
    xp: j['xp'] ?? 0,
    stats: (j['stats'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, GameStats.fromJson(v as Map<String, dynamic>)),
    ),
    unlocked: {...(j['unlocked'] as List? ?? []).cast<String>()},
    dailyStreak: j['dailyStreak'] ?? 0,
    lastDaily: j['lastDaily'],
    createdAt: DateTime.tryParse(j['createdAt'] ?? ''),
    inventory: (j['inventory'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as int),
    ),
    owned: {...(j['owned'] as List? ?? []).cast<String>()},
    diceSkin: j['diceSkin'] ?? 'classic',
    boardTheme: j['boardTheme'] ?? 'classic',
    lastChest: DateTime.tryParse(j['lastChest'] ?? ''),
    frame: j['frame'] ?? 'none',
    entrance: j['entrance'] ?? 'none',
    bubble: j['bubble'] ?? 'none',
    chair: j['chair'] ?? 'none',
    bio: j['bio'] ?? '',
    posts: [
      for (final e in (j['posts'] as List? ?? []))
        ProfilePost.fromJson(e as Map<String, dynamic>),
    ],
    vipPoints: (j['vp'] as num?)?.toInt() ?? 0,
    lastVipDaily: j['vd'] as String?,
    specialId: j['sid'] as String?,
    activity: [
      for (final e in (j['act'] as List? ?? const []))
        ?ActEntry.fromJson(e),
    ],
  );
}

/// ما يكسبه اللاعب بعد مباراة.
class Reward {
  const Reward({
    required this.xp,
    required this.coins,
    required this.levelUp,
    required this.newLevel,
    required this.unlocked,
  });
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
        Cloud.instance.scheduleSave(profile!);
      }
      await prefs.setString(
        _settingsKey,
        jsonEncode({'haptics': haptics, 'sounds': sounds}),
      );
    } catch (e) {
      debugPrint('Account.save failed: $e');
    }
  }

  static PlayerProfile _fromCloud(Map<String, dynamic> j, String id) =>
      PlayerProfile.fromJson({
        ...jsonDecode(jsonEncode(j)) as Map<String, dynamic>,
        'id': id,
      });

  /// بعد تشغيل Firebase: ربط الملف المحلي بحساب السيرفر.
  /// - لا يوجد ملف محلي لكن المتصفح ما زال مسجلاً: نسترجع الملف من السيرفر.
  /// - يوجد ملف محلي: نسجل دخولاً صامتاً كضيف إن لزم ونرفع التقدم بنفس المعرّف.
  Future<void> attachCloud() async {
    final cloud = Cloud.instance;
    if (!cloud.enabled) return;
    if (profile == null) {
      final uid = cloud.uid;
      if (uid == null) return;
      final saved = await cloud.fetchProfile(uid);
      if (saved != null) {
        profile = _fromCloud(saved, uid);
        await _save();
        cloud.watchMe(uid);
      }
      return;
    }
    final uid = await cloud.ensureUser();
    if (uid == null) return;
    final saved = await cloud.fetchProfile(uid);
    if (profile!.id != uid) {
      profile = saved != null
          ? _fromCloud(saved, uid)
          : _fromCloud(profile!.toJson(), uid);
    }
    await _save();
    await cloud.saveNow(profile!);
    cloud.watchMe(uid);
  }

  /// استرجاع ملف لاعب سبق له الدخول بهذا الحساب (من جهاز آخر مثلاً).
  Future<bool> restore(String uid) async {
    final saved = await Cloud.instance.fetchProfile(uid);
    if (saved == null) return false;
    profile = _fromCloud(saved, uid);
    await _save();
    return true;
  }

  static String _newId() {
    final r = Random();
    return List.generate(8, (_) => r.nextInt(10)).join();
  }

  Future<void> signIn({
    required AuthMethod method,
    required String name,
    String? contact,
    String? id,
  }) async {
    profile = PlayerProfile(
      id: id ?? _newId(),
      name: name.trim().isEmpty
          ? 'لاعب ${_newId().substring(0, 4)}'
          : name.trim(),
      method: method,
      contact: contact,
      avatar: Random().nextInt(avatars.length),
    );
    await _save();
    // أول حفظ على السيرفر مباشرة ليظهر اللاعب في المتصدرين
    await Cloud.instance.saveNow(profile!);
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
    await Cloud.instance.signOut();
    await _save();
  }

  Future<void> rename(String name) async {
    if (profile == null || name.trim().isEmpty) return;
    profile!.name = name.trim().length > 18
        ? name.trim().substring(0, 18)
        : name.trim();
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

  // ---- سجل النشاط ----

  /// يضيف حدثاً لسجل نشاط اللاعب (يُرفع للسحابة مع الملف ويظهر للإدارة).
  void log(String kind, String text, {int coins = 0, String? game, bool save = false}) {
    final p = profile;
    if (p == null) return;
    p.activity.insert(0, ActEntry(kind: kind, text: text, coins: coins, game: game));
    _trimActivity(p);
    if (save) _save();
  }

  void _trimActivity(PlayerProfile p) {
    while (p.activity.length > PlayerProfile.maxActivity) {
      p.activity.removeLast();
    }
  }

  /// جولات ألعاب العملات المتتالية لنفس اللعبة خلال 15 دقيقة تُجمع في سطر واحد.
  void _logRound(PlayerProfile p, String game, int bet, int won) {
    final now = DateTime.now();
    final last = p.activity.isEmpty ? null : p.activity.first;
    if (last != null && last.kind == 'bet' && last.game == game && now.difference(last.at).inMinutes < 15) {
      last
        ..count += 1
        ..bet += bet
        ..won += won
        ..coins = last.won - last.bet
        ..at = now;
    } else {
      p.activity.insert(0, ActEntry(kind: 'bet', text: '', game: game, bet: bet, won: won, coins: won - bet));
      _trimActivity(p);
    }
    final e = p.activity.first;
    e.text = '${gameTitles[game] ?? game}: ${e.count} جولة، راهن ${e.bet} وربح ${e.won}';
  }

  /// سجل مباريات هذا الجهاز (تعرضه لوحة الأدمن).
  final List<MatchRecord> matchLog = [];

  /// يسجل نتيجة مباراة ويرجع المكافأة. لا يفعل شيئاً إن لم يكن هناك حساب.
  Reward? recordGame(String game, {required bool won, int points = 0}) {
    final p = profile;
    if (p == null) return null;
    final s = p.statsFor(game)
      ..played += 1
      ..points += points;
    if (won) s.wins += 1;
    if (points > s.best) s.best = points;

    matchLog.insert(
      0,
      MatchRecord(
        game: game,
        player: p.name,
        won: won,
        points: points,
        at: DateTime.now(),
      ),
    );
    if (matchLog.length > 100) matchLog.removeLast();

    final before = p.level;
    final int xp = (won ? 60 : 20) + min<int>(points ~/ 200, 40);
    final coins = won ? 100 : 25;
    p.xp += xp;
    p.coins += coins;
    p.activity.insert(0, ActEntry(
      kind: 'game',
      game: game,
      coins: coins,
      text: 'لعب ${gameTitles[game] ?? game}: ${won ? 'فاز 🏆' : 'خسر'}${points > 0 ? ' ($points نقطة)' : ''}',
    ));
    _trimActivity(p);
    final unlocked = _checkAchievements();
    _save();
    return Reward(
      xp: xp,
      coins: coins,
      levelUp: p.level > before,
      newLevel: p.level,
      unlocked: unlocked,
    );
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

  bool get dailyAvailable =>
      profile != null && profile!.lastDaily != _day(DateTime.now());

  /// يوم البونص القادم في دورة الأيام السبعة (0..6).
  int get nextDailyIndex {
    final p = profile;
    if (p == null) return 0;
    final yesterday = _day(DateTime.now().subtract(const Duration(days: 1)));
    final today = _day(DateTime.now());
    if (p.lastDaily == today) return (p.dailyStreak - 1) % 7;
    return p.lastDaily == yesterday ? p.dailyStreak % 7 : 0;
  }

  /// البونص اليومي: تقويم 7 أيام بجوائز متصاعدة، ويرجع لليوم الأول إذا فاتك يوم.
  DailyGift? claimDaily({DateTime? now}) {
    final p = profile;
    now ??= DateTime.now();
    if (p == null || p.lastDaily == _day(now)) return null;
    final yesterday = _day(now.subtract(const Duration(days: 1)));
    p.dailyStreak = p.lastDaily == yesterday ? p.dailyStreak + 1 : 1;
    p.lastDaily = _day(now);
    final gift = dailyGifts[(p.dailyStreak - 1) % 7];
    p.coins += gift.coins;
    log('reward', 'استلم بونص اليوم ${p.dailyStreak}', coins: gift.coins);
    gift.items.forEach((i, n) => p.inventory[i.name] = p.itemCount(i) + n);
    if (gift.skin != null) {
      // إذا كان يملكه يأخذ قيمته عملات
      if (p.owns(gift.skin!)) {
        p.coins += 800;
      } else {
        p.owned.add(gift.skin!);
      }
    }
    _checkAchievements();
    _save();
    return gift;
  }

  // ---- العملات والمتجر ----

  static const chestCoins = 300;
  static const chestEvery = Duration(hours: 4);

  Duration chestWait({DateTime? now}) {
    final last = profile?.lastChest;
    if (last == null) return Duration.zero;
    final left = last.add(chestEvery).difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// صندوق عملات مجاني كل 4 ساعات.
  int? claimChest({DateTime? now}) {
    final p = profile;
    now ??= DateTime.now();
    if (p == null || chestWait(now: now) > Duration.zero) return null;
    p.lastChest = now;
    p.coins += chestCoins;
    log('reward', 'فتح الصندوق المجاني', coins: chestCoins);
    _save();
    return chestCoins;
  }

  bool spend(int coins, {String? reason, String kind = 'spend', String? game}) {
    if (coins > 0 && Restrictions.instance.check('coins') != null) return false;
    final p = profile;
    if (p == null || coins < 0 || p.coins < coins) return false;
    p.coins -= coins;
    if (reason != null) log(kind, reason, coins: -coins, game: game);
    _save();
    return true;
  }

  /// نتيجة جولة عجلة السماء: النقاط = العملات المربوحة (بدون مكافآت إضافية).
  void recordSkyRound({required int bet, required int won}) {
    final p = profile;
    if (p == null || bet <= 0) return;
    _logRound(p, 'sky_wheel', bet, won);
    final s = p.statsFor('sky_wheel')
      ..played += 1
      ..points += won;
    if (won > bet) s.wins += 1;
    if (won > s.best) s.best = won;
    _save();
  }

  /// نتيجة جولة في ألعاب العملات الجديدة (الفواكه، الكنز، المسامير، الصاروخ).
  void recordCoinRound(String game, {required int bet, required int won}) {
    final p = profile;
    if (p == null || bet <= 0) return;
    _logRound(p, game, bet, won);
    final s = p.statsFor(game)
      ..played += 1
      ..points += won;
    if (won > bet) s.wins += 1;
    if (won > s.best) s.best = won;
    _save();
  }

  void earn(int coins) {
    if (profile == null || coins <= 0) return;
    profile!.coins += coins;
    _save();
  }

  /// ماسات من هدايا الناس.
  void addDiamonds(int n, {String? from}) {
    if (profile == null || n <= 0) return;
    profile!.diamonds += n;
    log('diamonds', 'وصله $n 💎 من هدية${from == null ? '' : ' $from'}');
    _save();
  }

  /// تبديل ماسات بكوينز بنفس القيمة (ماسة = كوين).
  bool exchangeDiamonds(int n) {
    final p = profile;
    if (p == null || n <= 0 || p.diamonds < n) return false;
    p.diamonds -= n;
    p.coins += n;
    log('diamonds', 'بدّل $n 💎 إلى عملات', coins: n);
    _save();
    notifyListeners();
    return true;
  }

  /// سعر القطعة بالماسات (خصم 30% عن سعرها بالكوينز).
  int diamondPriceFor(ShopItem item) => (item.price * (1 - diamondDiscount)).round();

  /// شراء قطعة مميزة بالماسات. يرجع رسالة خطأ أو null.
  String? buyWithDiamonds(ShopItem item) {
    final p = profile;
    if (p == null) return 'سجّل دخولك أولاً';
    if (p.owns(item.id)) return 'تملكه بالفعل';
    final price = diamondPriceFor(item);
    if (p.diamonds < price) return 'ماساتك لا تكفي';
    p.diamonds -= price;
    p.owned.add(item.id);
    log('buy', 'اشترى ${item.title} بـ $price 💎');
    _save();
    return null;
  }

  /// حجز ID مميز. يرجع رسالة خطأ أو null عند النجاح.
  Future<String?> setSpecialId(String id) async {
    final p = profile;
    if (p == null) return 'سجّل دخولك أولاً';
    final bad = checkSpecialId(id, p.vipLevel);
    if (bad != null) return bad;
    if (id == p.specialId) return null;
    final err = await Cloud.instance.claimId(id, release: p.specialId);
    if (err != null) return err;
    p.specialId = id;
    _save();
    return null;
  }

  /// ID مميز أعطته الإدارة (محجوز من جهتها).
  void adoptSpecialId(String id) {
    final p = profile;
    if (p == null) return;
    p.specialId = id.isEmpty ? null : id;
    _save();
  }

  /// سعر غرض المتجر بعد خصم VIP.
  int priceFor(ShopItem item) {
    final d = vipTier(profile?.vipLevel ?? 0)?.discount ?? 0;
    return d == 0 ? item.price : (item.price * (100 - d) / 100).round();
  }

  /// إضافة نقاط VIP. عند الترقية تُفتح مظاهر المستوى مجاناً.
  /// يرجع المستوى الجديد لو صار ترقية، وإلا null.
  int? addVip(int points, {bool save = true}) {
    final p = profile;
    if (p == null || points <= 0) return null;
    final before = p.vipLevel;
    p.vipPoints += points;
    final after = p.vipLevel;
    _grantVipUnlocks(p);
    if (save) _save();
    if (after > before) {
      vipUp.value = after;
      return after;
    }
    return null;
  }

  /// ترقية VIP جديدة (للاحتفال في الواجهة).
  final vipUp = ValueNotifier<int?>(null);

  void _grantVipUnlocks(PlayerProfile p) {
    for (final t in vipTiers) {
      if (t.level > p.vipLevel) continue;
      for (final id in t.unlocks) {
        if (!p.owned.add(id)) continue;
        // يلبس الهدية تلقائياً لو ما عنده شي من نفس النوع.
        final name = id.split('.').last;
        if (id.startsWith('frame.') && p.frame == 'none') p.frame = name;
        if (id.startsWith('entrance.') && p.entrance == 'none') p.entrance = name;
        if (id.startsWith('bubble.') && p.bubble == 'none') p.bubble = name;
        if (id.startsWith('chair.') && p.chair == 'none') p.chair = name;
      }
    }
  }

  String _today([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  bool get vipDailyReady {
    final p = profile;
    return p != null && p.vipLevel > 0 && p.lastVipDaily != _today();
  }

  /// استلام مكافأة VIP اليومية. يرجع العملات أو null لو ما يحق.
  int? claimVipDaily({DateTime? now}) {
    final p = profile;
    if (p == null || p.vipLevel == 0 || p.lastVipDaily == _today(now)) return null;
    final coins = vipTier(p.vipLevel)!.daily;
    p.lastVipDaily = _today(now);
    p.coins += coins;
    log('reward', 'مكافأة VIP${p.vipLevel} اليومية', coins: coins);
    _save();
    return coins;
  }

  /// شراء من المتجر. يرجع رسالة خطأ أو null عند النجاح.
  String? buy(ShopItem item) {
    final p = profile;
    if (p == null) return 'سجّل دخولك أولاً';
    final limited = Restrictions.instance.check('coins');
    if (limited != null) return limited;
    final cosmetic = item.kind != ShopKind.item && item.kind != ShopKind.bundle;
    if (cosmetic && p.owns(item.id)) return 'تملكه بالفعل';
    final price = priceFor(item);
    if (p.coins < price) return 'عملاتك لا تكفي';
    p.coins -= price;
    log('buy', 'اشترى ${item.title} من المتجر', coins: -price);
    addVip(price, save: false);
    switch (item.kind) {
      case ShopKind.dice:
      case ShopKind.board:
      case ShopKind.frame:
      case ShopKind.entrance:
      case ShopKind.bubble:
      case ShopKind.chair:
        p.owned.add(item.id);
      case ShopKind.item:
        final i = LudoItem.values.byName(item.id.split('.').last);
        p.inventory[i.name] = p.itemCount(i) + item.amount;
      case ShopKind.bundle:
        for (final i in LudoItem.values) {
          p.inventory[i.name] = p.itemCount(i) + item.amount;
        }
    }
    _save();
    return null;
  }

  /// تُنادى عند تغيير شكل الكراسي (لتحديث غرفتي المفتوحة).
  void Function(String chair)? onChairChanged;

  void equip(String id) {
    final p = profile;
    if (p == null || !p.owns(id)) return;
    final name = id.split('.').last;
    if (id.startsWith('dice.')) p.diceSkin = name;
    if (id.startsWith('board.')) p.boardTheme = name;
    if (id.startsWith('frame.')) p.frame = name;
    if (id.startsWith('entrance.')) p.entrance = name;
    if (id.startsWith('bubble.')) p.bubble = name;
    if (id.startsWith('chair.')) {
      p.chair = name;
      onChairChanged?.call(name);
    }
    _save();
    notifyListeners();
  }

  // ---------- الملف الشخصي ----------

  /// حفظ وتحديث الواجهة بعد تعديل مباشر على الملف (مثل تعديلات الإدارة).
  void touch() => _save();

  void setBio(String bio) {
    final p = profile;
    if (p == null) return;
    p.bio = bio.trim();
    _save();
    notifyListeners();
  }

  void addPost(String text, {int mood = 0}) {
    final p = profile;
    if (p == null || text.trim().isEmpty) return;
    p.posts.insert(
      0,
      ProfilePost(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: text.trim(),
        mood: mood,
      ),
    );
    _save();
    notifyListeners();
  }

  void deletePost(String id) {
    profile?.posts.removeWhere((e) => e.id == id);
    _save();
    notifyListeners();
  }

  void toggleLike(ProfilePost post) {
    post.liked = !post.liked;
    post.likes += post.liked ? 1 : -1;
    _save();
    notifyListeners();
  }

  /// يستهلك أداة من الحقيبة (عند استخدامها في المباراة).
  bool consumeItem(LudoItem i) {
    final p = profile;
    if (p == null || p.itemCount(i) <= 0) return false;
    p.inventory[i.name] = p.itemCount(i) - 1;
    _save();
    return true;
  }

  @visibleForTesting
  void reset() {
    profile = null;
    matchLog.clear();
    haptics = true;
    sounds = true;
  }
}
