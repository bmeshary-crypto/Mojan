import 'dart:math';

import 'package:flutter/foundation.dart';

import '../account/account.dart';

/// أقسام الغرف الصوتية.
enum VoiceCategory {
  music('موسيقى', 'cat_music'),
  chat('دردشة', 'voice_mic'),
  games('ألعاب', 'cat_games'),
  party('حفلات', 'cat_party');

  const VoiceCategory(this.label, this.art);
  final String label;
  final String art;
}

/// شكل الغرفة: عادية (مقاعد) أو حفلة (مسرح وإطارات ذهبية).
enum VoiceTheme { classic, party }

/// هدايا الغرف الصوتية.
class VoiceGift {
  const VoiceGift(this.id, this.title, this.price);
  final String id;
  final String title;
  final int price;
  String get art => 'assets/images/gift_$id.webp';
}

const voiceGifts = [
  VoiceGift('rose', 'وردة', 10),
  VoiceGift('heart', 'قلب', 30),
  VoiceGift('mic', 'مايك ذهبي', 99),
  VoiceGift('trophy', 'كأس', 199),
  VoiceGift('lamp', 'فانوس سحري', 299),
  VoiceGift('crown', 'تاج', 499),
  VoiceGift('ring', 'خاتم ألماس', 999),
  VoiceGift('car', 'سيارة', 1999),
  VoiceGift('rocket', 'صاروخ', 4999),
];

VoiceGift giftById(String id) => voiceGifts.firstWhere((g) => g.id == id);

/// إطار الصورة حول المتحدث.
enum SeatFrame { none, host, party, vip }

class VoiceUser {
  VoiceUser({
    required this.id,
    required this.name,
    required this.avatar,
    this.level = 1,
    this.vip = false,
    this.frame = SeatFrame.none,
    this.isMe = false,
    this.isBot = true,
  });
  final String id;
  String name;
  int avatar;
  int level;
  bool vip;
  SeatFrame frame;
  final bool isMe;
  final bool isBot;

  /// هل يتكلم الآن (حلقة الصوت).
  bool speaking = false;

  /// إيموجي يطير فوق مقعده.
  String? reaction;
}

class VoiceSeat {
  VoiceSeat(this.index);
  final int index;
  VoiceUser? user;
  bool locked = false;

  /// كتم من المضيف.
  bool muted = false;
  bool get empty => user == null;
}

enum VoiceMsgKind { chat, system, gift, join }

class VoiceMessage {
  VoiceMessage({required this.kind, required this.text, this.user, this.gift, this.count = 1});
  final VoiceMsgKind kind;
  final String text;
  final VoiceUser? user;
  final VoiceGift? gift;
  final int count;
}

/// طلب صعود للمايك ينتظر موافقة المضيف.
class MicRequest {
  MicRequest(this.user, this.seat);
  final VoiceUser user;
  final int seat;
}

/// بلاغ من مستخدم عن غرفة أو شخص (يظهر في لوحة الأدمن).
class VoiceReport {
  VoiceReport({required this.roomId, required this.roomTitle, required this.reason, this.target, this.reporter = 'مستخدم', DateTime? at})
      : at = at ?? DateTime.now();
  final String roomId;
  final String roomTitle;
  final String reason;
  final String? target;
  final String reporter;
  final DateTime at;
  String status = 'open'; // open, warned, banned, dismissed
}

const reportReasons = ['كلام مسيء أو سب', 'محتوى غير لائق', 'إزعاج وتخريب', 'احتيال أو طلب فلوس', 'سبب آخر'];

class VoiceRoom {
  VoiceRoom({
    required this.id,
    required this.title,
    required this.host,
    required this.category,
    int seats = 12,
    this.theme = VoiceTheme.classic,
    this.announcement = 'أهلاً بالجميع، احترموا بعض واستمتعوا 🌹',
    this.listeners = 0,
    this.heat = 0,
  }) : seats = List.generate(seats, VoiceSeat.new);

  final String id;
  String title;
  VoiceUser host;
  VoiceCategory category;
  VoiceTheme theme;
  String announcement;
  List<VoiceSeat> seats;

  /// المستمعون غير الجالسين على المايك.
  int listeners;

  /// شعبية الغرفة (تزيد مع الهدايا والتفاعل).
  int heat;
  bool hostSpeaking = false;
  bool locked = false;
  bool closed = false;
  bool chatMuted = false;

  /// لعبة الصالة إن تحولت الغرفة لصالة لعب.
  String? game;

  /// لمراقبة الأدمن: عدد البلاغات والتحذير.
  int reports = 0;
  bool warned = false;

  final List<VoiceMessage> messages = [];
  final List<MicRequest> requests = [];
  final Set<String> kicked = {};

  int get onSeats => seats.where((s) => !s.empty).length;
  int get online => listeners + onSeats + 1;
  bool get flagged => reports >= 2;
}

const _botNames = [
  'سهرة', 'نورة', 'أحمد', 'كاتو', 'ريم', 'فيصل', 'جود', 'تركي', 'لمى', 'سلطان', 'دانة', 'يوسف',
  'مها', 'راكان', 'غلا', 'عمر', 'هيا', 'ماجد', 'شهد', 'بندر', 'لين', 'سعود', 'رهف', 'ناصر',
];

const _botChat = [
  'صوتك جميل جداً ❤️', 'منورين يا جماعة', 'السلام عليكم', 'أبي مايك 🙋', 'كمّل كمّل 👏', 'هههههه',
  'مين يلعب لودو بعدين؟', 'تحية للمضيف 🌹', 'الأغنية الجاية من اختياري', 'وش الموضوع اليوم؟',
  'مساء الخير للجميع', 'أبدعت 🔥', 'ممكن ترحيب بالجدد', 'يا هلا والله',
];

/// الغرف الصوتية. قبل ربط سيرفر الصوت كل الغرف محلية: المستخدمون الآخرون محاكاة،
/// والمايك لا ينقل صوتاً حقيقياً.
class VoiceService extends ChangeNotifier {
  VoiceService._();
  static final instance = VoiceService._();

  final _rng = Random(42);
  final List<VoiceRoom> rooms = [];
  final List<VoiceReport> reports = [];
  final Set<String> following = {};
  final Set<String> bannedUsers = {};

  /// هل المايك مفتوح للمستخدم (يتطلب الجلوس على مقعد).
  bool micOn = false;
  bool speakerOn = true;

  void notify() => notifyListeners();

  VoiceUser me() {
    final p = Account.instance.profile;
    return VoiceUser(
      id: p?.id ?? 'me',
      name: p?.name ?? 'أنا',
      avatar: p?.avatar ?? 0,
      level: p?.level ?? 1,
      isMe: true,
      isBot: false,
      frame: SeatFrame.vip,
    );
  }

  VoiceUser _bot([int? i]) {
    final n = i ?? _rng.nextInt(_botNames.length);
    return VoiceUser(
      id: 'bot$n-${_rng.nextInt(9999)}',
      name: _botNames[n % _botNames.length],
      avatar: (n * 5 + 3) % avatars.length,
      level: 1 + _rng.nextInt(40),
      vip: _rng.nextDouble() < .25,
    );
  }

  String _newId() => (100000 + _rng.nextInt(899999)).toString();

  /// غرف تجريبية تملأ القائمة حتى يشتغل السيرفر.
  void ensureDemo() {
    if (rooms.isNotEmpty) return;
    final specs = [
      ('سهرة طرب', VoiceCategory.music, 20, VoiceTheme.party, 4800, 14),
      ('صوتك أحلى', VoiceCategory.chat, 12, VoiceTheme.classic, 3200, 9),
      ('Friends Forever', VoiceCategory.chat, 8, VoiceTheme.classic, 2100, 6),
      ('صالة اللودو', VoiceCategory.games, 8, VoiceTheme.classic, 1500, 5),
      ('حفلة الخميس 🎉', VoiceCategory.party, 12, VoiceTheme.party, 6900, 10),
      ('سوالف آخر الليل', VoiceCategory.chat, 12, VoiceTheme.classic, 900, 4),
    ];
    for (final (i, (title, cat, seats, theme, heat, filled)) in specs.indexed) {
      final host = _bot(i * 3)..frame = SeatFrame.host;
      final room = VoiceRoom(
        id: _newId(),
        title: title,
        host: host,
        category: cat,
        seats: seats,
        theme: theme,
        heat: heat,
        listeners: 20 + _rng.nextInt(300),
      );
      for (var s = 0; s < filled && s < seats; s++) {
        if (_rng.nextDouble() < .8) room.seats[s].user = _bot(s + i)..frame = theme == VoiceTheme.party ? SeatFrame.party : SeatFrame.none;
      }
      if (seats > 8) room.seats.last.locked = true;
      if (cat == VoiceCategory.games) room.game = 'ludo';
      if (i == 5) {
        room.reports = 2; // غرفة عليها بلاغات للمراقبة
        room.seats.first.user ??= _bot(7);
      }
      room.messages.addAll([
        VoiceMessage(kind: VoiceMsgKind.system, text: room.announcement),
        VoiceMessage(kind: VoiceMsgKind.chat, text: _botChat[i % _botChat.length], user: room.seats.first.user ?? host),
      ]);
      rooms.add(room);
    }
    reports.add(VoiceReport(
      roomId: rooms[5].id,
      roomTitle: rooms[5].title,
      reason: reportReasons[0],
      target: rooms[5].seats.first.user?.name,
      reporter: 'ريم',
      at: DateTime.now().subtract(const Duration(minutes: 12)),
    ));
    reports.add(VoiceReport(
      roomId: rooms[5].id,
      roomTitle: rooms[5].title,
      reason: reportReasons[2],
      reporter: 'فيصل',
      at: DateTime.now().subtract(const Duration(minutes: 4)),
    ));
  }

  List<VoiceRoom> get live => rooms.where((r) => !r.closed).toList()..sort((a, b) => b.heat.compareTo(a.heat));

  VoiceRoom? byId(String id) => rooms.where((r) => r.id == id).firstOrNull;

  /// المستخدم ينشئ غرفته ويصبح مضيفها.
  VoiceRoom create({
    required String title,
    required VoiceCategory category,
    int seats = 12,
    VoiceTheme theme = VoiceTheme.classic,
    String? announcement,
  }) {
    final room = VoiceRoom(
      id: _newId(),
      title: title.trim().isEmpty ? 'غرفة ${me().name}' : title.trim(),
      host: me()..frame = SeatFrame.host,
      category: category,
      seats: seats,
      theme: theme,
      announcement: announcement?.trim().isNotEmpty == true ? announcement!.trim() : 'أهلاً بالجميع، احترموا بعض واستمتعوا 🌹',
    );
    room.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: room.announcement));
    rooms.insert(0, room);
    notifyListeners();
    return room;
  }

  bool isHost(VoiceRoom r) => r.host.isMe;
  int? mySeat(VoiceRoom r) => r.seats.where((s) => s.user?.isMe == true).firstOrNull?.index;
  bool onMic(VoiceRoom r) => isHost(r) || mySeat(r) != null;

  /// الدخول للغرفة. يرجع رسالة خطأ إن لم يُسمح.
  String? join(VoiceRoom r) {
    if (r.closed) return 'هذه الغرفة مغلقة';
    final id = me().id;
    if (bannedUsers.contains(me().name)) return 'حسابك موقوف من الغرف الصوتية';
    if (r.kicked.contains(id)) return 'تم طردك من هذه الغرفة';
    if (r.locked && !isHost(r)) return 'الغرفة مقفلة من المضيف';
    if (!isHost(r)) {
      r.listeners++;
      r.messages.add(VoiceMessage(kind: VoiceMsgKind.join, text: 'دخل الغرفة', user: me()));
    }
    notifyListeners();
    return null;
  }

  void leave(VoiceRoom r) {
    final s = mySeat(r);
    if (s != null) r.seats[s].user = null;
    micOn = false;
    if (!isHost(r) && r.listeners > 0) r.listeners--;
    notifyListeners();
  }

  /// الجلوس على مقعد. المضيف يجلس مباشرة، الآخرون يجلسون على المقاعد الفارغة غير المقفلة.
  String? takeSeat(VoiceRoom r, int i) {
    final seat = r.seats[i];
    if (!seat.empty) return 'المقعد مشغول';
    if (seat.locked && !isHost(r)) return 'المقعد مقفل';
    if (isHost(r)) return 'أنت المضيف ومكانك في الأعلى';
    final old = mySeat(r);
    if (old != null) r.seats[old].user = null;
    seat.user = me();
    if (r.listeners > 0 && old == null) r.listeners--;
    micOn = true;
    notifyListeners();
    return null;
  }

  void leaveSeat(VoiceRoom r) {
    final s = mySeat(r);
    if (s == null) return;
    r.seats[s].user = null;
    r.listeners++;
    micOn = false;
    notifyListeners();
  }

  void toggleMic(VoiceRoom r) {
    if (!onMic(r)) return;
    final s = mySeat(r);
    if (s != null && r.seats[s].muted) return;
    micOn = !micOn;
    notifyListeners();
  }

  // ---- أدوات المضيف ----

  void toggleLock(VoiceRoom r, int i) {
    if (!isHost(r)) return;
    final seat = r.seats[i];
    if (!seat.empty) return;
    seat.locked = !seat.locked;
    notifyListeners();
  }

  void toggleMute(VoiceRoom r, int i) {
    final seat = r.seats[i];
    seat.muted = !seat.muted;
    if (seat.user?.isMe == true && seat.muted) micOn = false;
    seat.user?.speaking = false;
    notifyListeners();
  }

  /// إنزال من المايك.
  void removeFromSeat(VoiceRoom r, int i) {
    final u = r.seats[i].user;
    if (u == null) return;
    r.seats[i].user = null;
    r.seats[i].muted = false;
    r.listeners++;
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: 'تم إنزال ${u.name} من المايك'));
    notifyListeners();
  }

  /// طرد من الغرفة.
  void kick(VoiceRoom r, VoiceUser u) {
    for (final s in r.seats) {
      if (s.user?.id == u.id) {
        s.user = null;
        s.muted = false;
      }
    }
    r.kicked.add(u.id);
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: 'تم طرد ${u.name} من الغرفة'));
    notifyListeners();
  }

  /// دعوة مستمع للمايك (يجلس بوت على أول مقعد فارغ).
  void invite(VoiceRoom r) {
    final free = r.seats.where((s) => s.empty && !s.locked).firstOrNull;
    if (free == null) return;
    free.user = _bot()..frame = r.theme == VoiceTheme.party ? SeatFrame.party : SeatFrame.none;
    if (r.listeners > 0) r.listeners--;
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: '${free.user!.name} صعد للمايك ${free.index + 1}'));
    notifyListeners();
  }

  void acceptRequest(VoiceRoom r, MicRequest q) {
    r.requests.remove(q);
    final seat = r.seats[q.seat].empty && !r.seats[q.seat].locked ? r.seats[q.seat] : r.seats.where((s) => s.empty && !s.locked).firstOrNull;
    if (seat != null) {
      seat.user = q.user;
      if (r.listeners > 0) r.listeners--;
      r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: '${q.user.name} صعد للمايك ${seat.index + 1}'));
    }
    notifyListeners();
  }

  void rejectRequest(VoiceRoom r, MicRequest q) {
    r.requests.remove(q);
    notifyListeners();
  }

  void setSeatCount(VoiceRoom r, int n) {
    if (n == r.seats.length) return;
    final old = r.seats;
    r.seats = List.generate(n, (i) {
      if (i < old.length) return old[i];
      return VoiceSeat(i);
    });
    for (final s in old.skip(n)) {
      if (s.user != null) r.listeners++;
      if (s.user?.isMe == true) micOn = false;
    }
    notifyListeners();
  }

  void update(VoiceRoom r, {String? title, String? announcement, VoiceTheme? theme, bool? locked, bool? chatMuted, VoiceCategory? category}) {
    if (title != null && title.trim().isNotEmpty) r.title = title.trim();
    if (announcement != null && announcement.trim().isNotEmpty && announcement.trim() != r.announcement) {
      r.announcement = announcement.trim();
      r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: '📢 ${r.announcement}'));
    }
    if (theme != null) {
      r.theme = theme;
      for (final s in r.seats) {
        if (s.user != null && !s.user!.isMe) s.user!.frame = theme == VoiceTheme.party ? SeatFrame.party : SeatFrame.none;
      }
    }
    if (locked != null) r.locked = locked;
    if (chatMuted != null) r.chatMuted = chatMuted;
    if (category != null) r.category = category;
    notifyListeners();
  }

  /// تحويل الغرفة لصالة لعب (أو إرجاعها غرفة صوتية بـ null).
  void setGame(VoiceRoom r, String? game) {
    r.game = game;
    r.messages.add(VoiceMessage(
      kind: VoiceMsgKind.system,
      text: game == null ? 'رجعت الغرفة لغرفة صوتية' : '🎮 تحولت الغرفة لصالة ${gameTitles[game] ?? game}، اجلسوا على المايك للمشاركة',
    ));
    notifyListeners();
  }

  void close(VoiceRoom r, {String reason = 'أغلق المضيف الغرفة'}) {
    r.closed = true;
    for (final s in r.seats) {
      s.user = null;
    }
    micOn = false;
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: reason));
    notifyListeners();
  }

  // ---- التفاعل ----

  String? sendMessage(VoiceRoom r, String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    if (r.chatMuted && !isHost(r)) return 'الدردشة مقفلة من المضيف';
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.chat, text: t, user: me()));
    notifyListeners();
    return null;
  }

  void react(VoiceRoom r, String emoji) {
    final s = mySeat(r);
    final u = s != null ? r.seats[s].user! : (isHost(r) ? r.host : null);
    if (u == null) {
      r.messages.add(VoiceMessage(kind: VoiceMsgKind.chat, text: emoji, user: me()));
    } else {
      u.reaction = emoji;
    }
    notifyListeners();
  }

  /// إرسال هدية: تُخصم العملات وتزيد شعبية الغرفة.
  String? sendGift(VoiceRoom r, VoiceGift g, VoiceUser to, {int count = 1}) {
    final cost = g.price * count;
    if (!Account.instance.spend(cost)) return 'عملاتك لا تكفي';
    r.heat += cost;
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.gift, text: 'أرسل ${g.title} ×$count إلى ${to.name}', user: me(), gift: g, count: count));
    notifyListeners();
    return null;
  }

  void toggleFollow(VoiceRoom r) {
    following.contains(r.id) ? following.remove(r.id) : following.add(r.id);
    notifyListeners();
  }

  void report(VoiceRoom r, String reason, {String? target}) {
    r.reports++;
    reports.insert(0, VoiceReport(roomId: r.id, roomTitle: r.title, reason: reason, target: target, reporter: me().name));
    notifyListeners();
  }

  /// نبضة محاكاة: البوتات تتكلم وتكتب وترسل هدايا وتطلب المايك.
  /// يرجع الهدية إن أرسل أحدهم هدية (لعرض التأثير).
  VoiceMessage? tick(VoiceRoom r) {
    if (r.closed) return null;
    VoiceMessage? gift;
    for (final s in r.seats) {
      final u = s.user;
      if (u == null || u.isMe) continue;
      u.speaking = !s.muted && _rng.nextDouble() < .35;
      if (u.reaction != null && _rng.nextDouble() < .5) u.reaction = null;
    }
    if (!r.host.isMe) r.hostSpeaking = _rng.nextDouble() < .5;
    final meSeat = mySeat(r);
    if (meSeat != null) {
      final u = r.seats[meSeat].user!;
      if (u.reaction != null && _rng.nextDouble() < .5) u.reaction = null;
    }
    if (r.host.isMe && r.host.reaction != null && _rng.nextDouble() < .5) r.host.reaction = null;
    final roll = _rng.nextDouble();
    final bots = r.seats.where((s) => s.user != null && !s.user!.isMe).map((s) => s.user!).toList();
    if (roll < .22 && !r.chatMuted) {
      r.messages.add(VoiceMessage(kind: VoiceMsgKind.chat, text: _botChat[_rng.nextInt(_botChat.length)], user: bots.isEmpty ? _bot() : bots[_rng.nextInt(bots.length)]));
    } else if (roll < .30) {
      final g = voiceGifts[_rng.nextInt(5)];
      final from = _bot();
      final to = bots.isNotEmpty && _rng.nextBool() ? bots[_rng.nextInt(bots.length)] : r.host;
      gift = VoiceMessage(kind: VoiceMsgKind.gift, text: 'أرسل ${g.title} إلى ${to.name}', user: from, gift: g);
      r.messages.add(gift);
      r.heat += g.price;
    } else if (roll < .36) {
      r.listeners++;
      r.messages.add(VoiceMessage(kind: VoiceMsgKind.join, text: 'دخل الغرفة', user: _bot()));
    } else if (roll < .40 && r.host.isMe && r.requests.length < 3) {
      final free = r.seats.where((s) => s.empty && !s.locked).firstOrNull;
      if (free != null) r.requests.add(MicRequest(_bot(), free.index));
    }
    if (r.messages.length > 80) r.messages.removeRange(0, r.messages.length - 80);
    notifyListeners();
    return gift;
  }

  // ---- الأدمن ----

  void adminWarn(VoiceRoom r) {
    r.warned = true;
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: '⚠️ تحذير من إدارة MOJAN: الرجاء الالتزام بقوانين الغرف'));
    notifyListeners();
  }

  void adminMuteAll(VoiceRoom r) {
    for (final s in r.seats) {
      if (s.user != null) {
        s.muted = true;
        s.user!.speaking = false;
      }
    }
    if (mySeat(r) != null) micOn = false;
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: '🔇 الإدارة كتمت كل المايكات'));
    notifyListeners();
  }

  void adminClose(VoiceRoom r) => close(r, reason: '⛔ أغلقت الإدارة الغرفة لمخالفة القوانين');

  void setReportStatus(VoiceReport rep, String status) {
    rep.status = status;
    if (status == 'banned' && rep.target != null) bannedUsers.add(rep.target!);
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    rooms.clear();
    reports.clear();
    following.clear();
    bannedUsers.clear();
    micOn = false;
  }
}
