import 'dart:math';

import 'package:flutter/foundation.dart';

import '../ai/ai_brain.dart';
import '../ai/speech.dart';
import 'live_voice.dart';
import 'system_rooms.dart';

import '../account/account.dart';
import '../admin/admin.dart';
import '../ban.dart';
import '../vip.dart';

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
    this.vipLevel = 0,
    this.sid,
    this.frame = SeatFrame.none,
    this.isMe = false,
    this.isBot = true,
    this.frameArt,
    this.entrance,
    this.bubble,
    this.bio = '',
    this.aiId,
  });
  final String id;

  /// شخصية ذكاء اصطناعي (تتكلم وتفهم عبر Gemini).
  final String? aiId;
  bool get isAi => aiId != null;

  /// النبذة التعريفية التي تظهر في بطاقة الشخص.
  String bio;

  /// إطار من المتجر (اسم مثل angel) يغطي الإطار الافتراضي.
  String? frameArt;

  /// دخولية الغرفة (مثل car) وفقاعة الدردشة (مثل gold).
  String? entrance;
  String? bubble;
  String name;
  int avatar;
  int level;

  /// مستوى VIP (0 = عادي).
  int vipLevel;
  bool get vip => vipLevel > 0;

  /// الـ ID الظاهر (مميز أو عادي).
  String? sid;
  String get displayId => sid ?? defaultPlayerId(id);
  bool get specialId => sid != null && sid!.length <= 7;
  SeatFrame frame;
  final bool isMe;
  final bool isBot;

  /// هل يتكلم الآن (حلقة الصوت).
  bool speaking = false;

  /// المايك مفتوح (في الغرف الحقيقية).
  bool mic = false;

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
  VoiceMessage({required this.kind, required this.text, this.user, this.gift, this.count = 1, this.to = const []});

  /// مستلمو الهدية (لرسم طيرانها إلى أماكنهم).
  final List<VoiceUser> to;
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

  /// غرفة حقيقية على السيرفر بصوت حقيقي (وليست محاكاة).
  bool live = false;

  /// غرف النظام الثابتة: 'welcome' (الترحيب بالأعضاء الجدد) أو 'podcast' (بودكاست موجان).
  String? system;
  bool get isPodcast => system == 'podcast';
  bool get isWelcome => system == 'welcome';

  /// ما يُقال الآن في البودكاست (يظهر كترجمة تحت المذيعين).
  String? caption;
  VoiceUser? captionBy;
  String? topic;
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

  /// الحضور غير الجالسين على المايك (صندوق الأشخاص).
  final List<VoiceUser> audience = [];

  // ---- إحصائيات الهدايا داخل الغرفة ----
  /// قيمة الهدايا (بالعملات) التي استلمها كل شخص، حسب المعرّف.
  final Map<String, int> received = {};

  /// قيمة الهدايا التي أرسلها كل شخص.
  final Map<String, int> sent = {};

  /// عدد كل نوع هدية أُرسل في الغرفة.
  final Map<String, int> giftCounts = {};

  /// آخر نسخة معروفة من كل شخص ظهر في الإحصائيات.
  final Map<String, VoiceUser> people = {};

  int get giftsValue => received.values.fold(0, (a, b) => a + b);
  int get giftsCount => giftCounts.values.fold(0, (a, b) => a + b);
  int receivedBy(String id) => received[id] ?? 0;

  void recordGift(VoiceUser from, List<VoiceUser> to, VoiceGift g, int count) {
    final each = g.price * count;
    people[from.id] = from;
    sent[from.id] = (sent[from.id] ?? 0) + each * to.length;
    for (final u in to) {
      people[u.id] = u;
      received[u.id] = (received[u.id] ?? 0) + each;
    }
    giftCounts[g.id] = (giftCounts[g.id] ?? 0) + count * to.length;
  }

  /// أكبر الداعمين أو المستلمين مرتبين.
  List<(VoiceUser, int)> top(Map<String, int> m) {
    final list = [for (final e in m.entries) if (people[e.key] != null) (people[e.key]!, e.value)];
    list.sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  /// الأشخاص على المايكات (المضيف ثم المقاعد).
  List<VoiceUser> get onMics => [host, for (final s in seats) if (s.user != null) s.user!];
  final Set<String> kicked = {};

  int get onSeats => seats.where((s) => !s.empty).length;
  int get online => listeners + onSeats + 1;
  bool get flagged => reports >= 2;
}

const _botNames = [
  'سهرة', 'أحمد', 'نورة', 'كاتو', 'ريم', 'فيصل', 'جود', 'تركي', 'لمى', 'سلطان', 'دانة', 'يوسف',
  'مها', 'راكان', 'غلا', 'عمر', 'هيا', 'ماجد', 'شهد', 'بندر', 'لين', 'سعود', 'رهف', 'ناصر',
];

const _botFrames = ['angel', 'hearts', 'ice', 'fire', 'jungle', 'royal', 'rainbow', 'demon', 'ramadan', 'galaxy', 'ocean', 'sakura', 'neon', 'emerald', 'phoenix'];
const _botEntrances = ['car', 'scooter', 'horse', 'carpet', 'dragon', 'yacht', 'rocket', 'lion', 'jet', 'falcon', 'supercar', 'unicorn', 'ufo', 'lamp', 'carriage'];
const _botBubbles = ['pink', 'ocean', 'gold', 'neon'];

const _botBios = [
  'أحب الطرب والسهرات الحلوة 🎶',
  'هنا للضحك والسوالف ☕',
  'لاعب لودو محترف 🎲 تحداني',
  'الهدوء سر الجمال 🌙',
  'صوتي على المايك كل ليلة 🎤',
  'لا تحكم من الصورة 😄',
  'محب للخير والناس الطيبة 🌹',
  'جديد هنا، رحبوا فيني 👋',
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

  /// كتم صوت الغرفة عندي فقط (السماعة).
  bool speakerOn = true;

  /// الغرفة المصغّرة في الخلفية (تظهر كفقاعة عائمة).
  VoiceRoom? minimized;

  void minimize(VoiceRoom r) {
    minimized = r;
    notifyListeners();
  }

  void restore() {
    minimized = null;
    notifyListeners();
  }
  void toggleSpeaker() {
    speakerOn = !speakerOn;
    LiveVoice.instance.speakerChanged(speakerOn);
    if (!speakerOn) Speech.instance.stopSpeaking();
    notifyListeners();
  }

  void notify() => notifyListeners();

  /// المتصفح رفض إذن المايك.
  void micDenied() {
    micOn = false;
    final r = minimized ?? rooms.where((r) => r.live && onMic(r)).firstOrNull;
    r?.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: '🎙️ اسمح للمتصفح باستخدام المايك حتى يسمعك الناس'));
    notifyListeners();
  }

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
      frameArt: p == null || p.frame == 'none' ? null : p.frame,
      entrance: p == null || p.entrance == 'none' ? null : p.entrance,
      bubble: p == null || p.bubble == 'none' ? null : p.bubble,
      bio: p?.bio ?? '',
      vipLevel: p?.vipLevel ?? 0,
      sid: p?.specialId,
    );
  }

  VoiceUser _bot([int? i]) {
    final n = i ?? _rng.nextInt(_botNames.length);
    final u = VoiceUser(
      id: 'bot$n-${_rng.nextInt(9999)}',
      name: _botNames[n % _botNames.length],
      // الأسماء الزوجية بنات والفردية أولاد، ومثلها الصور.
      avatar: 2 * ((n * 7 + 1) % 8) + n % 2,
      level: 1 + _rng.nextInt(40),
      vipLevel: _rng.nextDouble() < .25 ? 1 + _rng.nextInt(_rng.nextDouble() < .2 ? 8 : 4) : 0,
      bio: _botBios[(n + _rng.nextInt(3)) % _botBios.length],
    );
    if (u.vipLevel >= 3) {
      final d = specialIdDigits(u.vipLevel)!;
      u.sid = '${1 + _rng.nextInt(9)}' * d;
    }
    // بعض المستخدمين المميزين عندهم إطارات ودخوليات من المتجر
    if (u.vip) {
      u.frameArt = _botFrames[_rng.nextInt(_botFrames.length)];
      u.entrance = _botEntrances[_rng.nextInt(_botEntrances.length)];
      if (_rng.nextBool()) u.bubble = _botBubbles[_rng.nextInt(_botBubbles.length)];
    }
    return u;
  }

  VoiceUser aiUser(AiPersona p) => VoiceUser(
        id: p.id,
        name: '${p.name} 🤖',
        avatar: p.avatar,
        level: 50,
        bio: p.bio,
        aiId: p.id,
        frameArt: 'rainbow',
      );

  final Set<String> _aiBusy = {};

  /// أشخاص الذكاء الاصطناعي الجالسون على المايكات.
  List<VoiceUser> aiOnMics(VoiceRoom r) => [for (final u in r.onMics) if (u.isAi) u];

  /// رد شخصية AI على ما قاله المستخدم (كتابة أو كلام)، وتنطقه بصوت مسموع.
  Future<void> aiRespond(VoiceRoom r, String said) async {
    final ais = aiOnMics(r);
    if (ais.isEmpty || r.closed || _aiBusy.contains(r.id)) return;
    final addressed = ais.where((u) => said.contains(u.name.replaceAll(' 🤖', ''))).toList();
    final u = addressed.isNotEmpty ? addressed.first : ais[_rng.nextInt(ais.length)];
    final p = personaById(u.aiId!);
    if (p == null) return;
    _aiBusy.add(r.id);
    try {
      await Future.delayed(Duration(milliseconds: 700 + _rng.nextInt(900)));
      final history = [
        for (final m in r.messages.where((m) => m.kind == VoiceMsgKind.chat && m.user != null).toList().reversed.take(10).toList().reversed)
          AiLine(m.user!.isMe ? '${m.user!.name} (المستخدم)' : m.user!.name, m.text),
      ];
      final text = await AiBrain.instance.reply(
        p,
        about: 'غرفة صوتية اسمها "${r.title}" فيها ناس يسولفون، وأنت جالس على المايك',
        history: history,
      );
      if (r.closed || !aiOnMics(r).any((x) => x.aiId == u.aiId)) return;
      if (r.live) {
        // في الغرف الحقيقية تنشر الرسالة للجميع وكل جهاز ينطقها
        await LiveVoice.instance.postAi(r, p, text);
      } else {
        r.messages.add(VoiceMessage(kind: VoiceMsgKind.chat, text: text, user: u));
        if (speakerOn) Speech.instance.speak(text, female: p.female, voice: p.voice, egyptian: p.egyptian, naturalOnly: r.isWelcome);
      }
      u.speaking = true;
      notifyListeners();
      // الحلقة تبقى مضيئة بقدر طول الكلام تقريباً
      await Future.delayed(Duration(milliseconds: 600 + text.length * 70));
      u.speaking = false;
      notifyListeners();
    } finally {
      _aiBusy.remove(r.id);
    }
  }

  VoiceRoom? _listeningRoom;

  /// عندما يفتح المستخدم المايك وبجانبه AI: نسمع كلامه ونحوله لنص يفهمه الـ AI.
  void _syncListening(VoiceRoom r) {
    final want = micOn && onMic(r) && aiOnMics(r).isNotEmpty && Speech.instance.canListen && !r.closed;
    if (want && _listeningRoom != r) {
      Speech.instance.stopListening();
      _listeningRoom = r;
      Speech.instance.listen((t) {
        if (_listeningRoom != r) return;
        if (r.live) {
          LiveVoice.instance.sendChat(r, '🎤 $t');
          return;
        }
        r.messages.add(VoiceMessage(kind: VoiceMsgKind.chat, text: '🎤 $t', user: me()));
        notifyListeners();
        aiRespond(r, t);
      });
    } else if (!want && _listeningRoom != null) {
      Speech.instance.stopListening();
      _listeningRoom = null;
    }
  }

  /// إحصائيات هدايا تجريبية للغرف الجاهزة حتى لا تبدأ فارغة.
  void _seedGifts(VoiceRoom r, int heat) {
    for (var i = 0; i < 10; i++) {
      r.audience.add(_bot());
    }
    final mics = r.onMics;
    final senders = [...r.audience.take(6), ...mics.skip(1).take(3)];
    // المضيف يأخذ النصيب الأكبر وقد يصل للملايين
    final scale = heat * 40;
    for (final (i, u) in mics.indexed) {
      final v = i == 0 ? scale * (3 + _rng.nextInt(8)) : (scale * _rng.nextDouble() * 1.5).round() + _rng.nextInt(900);
      r.people[u.id] = u;
      r.received[u.id] = v;
    }
    var total = r.giftsValue;
    for (final (i, u) in senders.indexed) {
      final v = i == senders.length - 1 ? total : (total * (.15 + _rng.nextDouble() * .3)).round();
      total -= v;
      if (v <= 0) continue;
      r.people[u.id] = u;
      r.sent[u.id] = (r.sent[u.id] ?? 0) + v;
    }
    for (final g in voiceGifts) {
      r.giftCounts[g.id] = (heat / g.price * (.5 + _rng.nextDouble())).round() + _rng.nextInt(5);
    }
  }

  String _newId() => (100000 + _rng.nextInt(899999)).toString();

  /// غرفتا النظام (الترحيب والبودكاست). باقي الغرف ينشئها المستخدمون فقط.
  void ensureRooms() {
    for (final r in SystemRooms.instance.build()) {
      if (byId(r.id) == null) rooms.add(r);
    }
  }

  /// غرف وهمية للاختبارات فقط.
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
      // شخصية ذكاء اصطناعي تسولف مع الناس في كل غرفة
      room.seats[1].user = aiUser(aiPersonas[i % aiPersonas.length]);
      if (seats > 8) room.seats.last.locked = true;
      if (cat == VoiceCategory.games) room.game = 'ludo';
      if (i == 5) {
        room.reports = 2; // غرفة عليها بلاغات للمراقبة
        room.seats.first.user ??= _bot(7);
      }
      _seedGifts(room, heat);
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

  List<VoiceRoom> get live => rooms.where((r) => !r.closed).toList()
    ..sort((a, b) {
      // غرفتا النظام دائماً في الأعلى
      final s = (a.system == null ? 1 : 0).compareTo(b.system == null ? 1 : 0);
      return s != 0 ? s : b.heat.compareTo(a.heat);
    });

  VoiceRoom? byId(String id) => rooms.where((r) => r.id == id).firstOrNull;

  /// المستخدم ينشئ غرفته ويصبح مضيفها.
  VoiceRoom create({
    required String title,
    required VoiceCategory category,
    int seats = 12,
    VoiceTheme theme = VoiceTheme.classic,
    String? announcement,
  }) {
    final live = LiveVoice.instance.enabled;
    final room = VoiceRoom(
      id: live ? LiveVoice.instance.newId() : _newId(),
      title: title.trim().isEmpty ? 'غرفة ${me().name}' : title.trim(),
      host: me()..frame = SeatFrame.host,
      category: category,
      seats: seats,
      theme: theme,
      announcement: announcement?.trim().isNotEmpty == true ? announcement!.trim() : 'أهلاً بالجميع، احترموا بعض واستمتعوا 🌹',
    );
    room.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: room.announcement));
    rooms.insert(0, room);
    if (live) {
      room.live = true;
      LiveVoice.instance.publish(room);
    }
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
    final limited = Restrictions.instance.check('rooms');
    if (limited != null) return limited;
    if (r.kicked.contains(id)) return 'تم طردك من هذه الغرفة';
    if (r.locked && !isHost(r)) return 'الغرفة مقفلة من المضيف';
    if (r.system != null) r.live = LiveVoice.instance.enabled;
    if (r.live) {
      LiveVoice.instance.enter(r);
    } else if (!isHost(r)) {
      r.listeners++;
      r.messages.add(VoiceMessage(kind: VoiceMsgKind.join, text: 'دخل الغرفة', user: me()));
    }
    if (r.system != null) SystemRooms.instance.entered(r);
    notifyListeners();
    return null;
  }

  void leave(VoiceRoom r) {
    if (minimized == r) minimized = null;
    if (r.live) LiveVoice.instance.exit(r);
    if (r.system != null) SystemRooms.instance.left(r);
    final s = mySeat(r);
    if (s != null) r.seats[s].user = null;
    micOn = false;
    _syncListening(r);
    Speech.instance.stopSpeaking();
    if (!isHost(r) && r.listeners > 0) r.listeners--;
    notifyListeners();
  }

  /// الجلوس على مقعد. المضيف يجلس مباشرة، الآخرون يجلسون على المقاعد الفارغة غير المقفلة.
  String? takeSeat(VoiceRoom r, int i) {
    if (r.isPodcast) return 'المايكات في البودكاست للمذيعين فقط 🎙️ اكتب لهم في الدردشة';
    final seat = r.seats[i];
    if (!seat.empty) return 'المقعد مشغول';
    if (seat.locked && !isHost(r)) return 'المقعد مقفل';
    if (isHost(r)) return 'أنت المضيف ومكانك في الأعلى';
    final noMic = Restrictions.instance.check('mic');
    if (noMic != null) return noMic;
    final old = mySeat(r);
    if (old != null) r.seats[old].user = null;
    seat.user = me();
    if (r.listeners > 0 && old == null) r.listeners--;
    micOn = true;
    if (r.live) {
      LiveVoice.instance.claimSeat(r, i).then((err) {
        if (err != null) r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: err));
        LiveVoice.instance.micChanged();
        notifyListeners();
      });
    }
    _syncListening(r);
    notifyListeners();
    return null;
  }

  void leaveSeat(VoiceRoom r) {
    final s = mySeat(r);
    if (s == null) return;
    r.seats[s].user = null;
    r.listeners++;
    micOn = false;
    if (r.live) {
      LiveVoice.instance.releaseSeat(r, s);
      LiveVoice.instance.micChanged();
    }
    _syncListening(r);
    notifyListeners();
  }

  void toggleMic(VoiceRoom r) {
    if (!onMic(r)) return;
    final s = mySeat(r);
    if (s != null && r.seats[s].muted) return;
    if (!micOn && Restrictions.instance.check('mic') != null) return;
    micOn = !micOn;
    if (r.live) {
      if (s != null) LiveVoice.instance.setMicFlag(r, s, micOn);
      LiveVoice.instance.micChanged();
    }
    _syncListening(r);
    notifyListeners();
  }

  // ---- أدوات المضيف ----

  void toggleLock(VoiceRoom r, int i) {
    if (!isHost(r)) return;
    final seat = r.seats[i];
    if (!seat.empty) return;
    seat.locked = !seat.locked;
    if (r.live) LiveVoice.instance.setLocked(r);
    notifyListeners();
  }

  void toggleMute(VoiceRoom r, int i) {
    final seat = r.seats[i];
    seat.muted = !seat.muted;
    if (r.live) LiveVoice.instance.setSeatMuted(r, i, seat.muted);
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
    if (r.live) LiveVoice.instance.releaseSeat(r, i);
    r.listeners++;
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: 'تم إنزال ${u.name} من المايك'));
    notifyListeners();
  }

  /// طرد من الغرفة.
  String? kick(VoiceRoom r, VoiceUser u) {
    if (u.vipLevel >= 5 && !AdminService.instance.isAdmin) {
      return '${u.name} عنده VIP${u.vipLevel} ومحمي من الطرد';
    }
    for (final s in r.seats) {
      if (s.user?.id == u.id) {
        s.user = null;
        s.muted = false;
      }
    }
    r.kicked.add(u.id);
    if (r.live) LiveVoice.instance.kick(r, u);
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: 'تم طرد ${u.name} من الغرفة'));
    notifyListeners();
    return null;
  }

  /// دعوة مستمع للمايك (يجلس بوت على أول مقعد فارغ).
  void invite(VoiceRoom r) {
    final free = r.seats.where((s) => s.empty && !s.locked).firstOrNull;
    if (free == null) return;
    // في الغرف الحقيقية يصعد الناس بأنفسهم (شخصيات الـ AI في غرفتي الترحيب والبودكاست فقط)
    if (r.live || r.system != null) return;
    free.user = _bot()..frame = r.theme == VoiceTheme.party ? SeatFrame.party : SeatFrame.none;
    if (r.listeners > 0) r.listeners--;
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: '${free.user!.name} صعد للمايك ${free.index + 1}'));
    notifyListeners();
  }

  /// طلب مايك جديد. أصحاب VIP7 فأعلى يتقدمون الطابور.
  void addRequest(VoiceRoom r, MicRequest q) {
    if (q.user.vipLevel >= 7) {
      final i = r.requests.indexWhere((x) => x.user.vipLevel < 7);
      r.requests.insert(i < 0 ? r.requests.length : i, q);
    } else {
      r.requests.add(q);
    }
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
    if (r.live) LiveVoice.instance.update(r);
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
    if (r.live) LiveVoice.instance.update(r);
    notifyListeners();
  }

  /// تحويل الغرفة لصالة لعب (أو إرجاعها غرفة صوتية بـ null).
  void setGame(VoiceRoom r, String? game) {
    r.game = game;
    if (r.live) LiveVoice.instance.update(r);
    r.messages.add(VoiceMessage(
      kind: VoiceMsgKind.system,
      text: game == null ? 'رجعت الغرفة لغرفة صوتية' : '🎮 تحولت الغرفة لصالة ${gameTitles[game] ?? game}، اجلسوا على المايك للمشاركة',
    ));
    notifyListeners();
  }

  void close(VoiceRoom r, {String reason = 'أغلق المضيف الغرفة'}) {
    if (r.live) {
      LiveVoice.instance.close(r, reason);
      LiveVoice.instance.exit(r, hostClose: false);
    }
    r.closed = true;
    if (minimized == r) minimized = null;
    for (final s in r.seats) {
      s.user = null;
    }
    micOn = false;
    _syncListening(r);
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.system, text: reason));
    notifyListeners();
  }

  // ---- التفاعل ----

  String? sendMessage(VoiceRoom r, String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    if (r.chatMuted && !isHost(r)) return 'الدردشة مقفلة من المضيف';
    final noChat = Restrictions.instance.check('chat');
    if (noChat != null) return noChat;
    if (r.live) {
      LiveVoice.instance.sendChat(r, t);
      return null;
    }
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.chat, text: t, user: me()));
    notifyListeners();
    if (r.system != null) {
      SystemRooms.instance.onMyChat(r, t);
    } else {
      aiRespond(r, t);
    }
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
  String? sendGift(VoiceRoom r, VoiceGift g, VoiceUser to, {int count = 1}) => sendGiftTo(r, g, [to], count: count);

  /// إرسال هدية لعدة أشخاص (مثل كل من على المايكات). السعر × العدد × عدد المستلمين.
  String? sendGiftTo(VoiceRoom r, VoiceGift g, List<VoiceUser> to, {int count = 1}) {
    if (to.isEmpty) return 'اختر من ترسل له';
    final noCoins = Restrictions.instance.check('coins');
    if (noCoins != null) return noCoins;
    final cost = g.price * count * to.length;
    if (!Account.instance.spend(cost)) return 'عملاتك لا تكفي';
    Account.instance.addVip(cost);
    r.heat += cost;
    final from = me();
    r.recordGift(from, to, g, count);
    final names = to.length == 1 ? to.first.name : 'كل من على المايك (${to.length})';
    r.messages.add(VoiceMessage(kind: VoiceMsgKind.gift, text: 'أرسل ${g.title} ×$count إلى $names', user: from, gift: g, count: count, to: to));
    if (r.live) {
      LiveVoice.instance.sendGift(r, g, to, count, 'أرسل ${g.title} ×$count إلى $names');
    } else if (r.system != null) {
      SystemRooms.instance.onMyGift(r, r.messages.last);
    }
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
    if (r.live || r.system != null) {
      // غرفة حقيقية (أو غرفة نظام): لا محاكاة، فقط هدايا وصلت من الآخرين
      final fx = LiveVoice.instance.incomingFx;
      return fx.isEmpty ? null : fx.removeAt(0);
    }
    VoiceMessage? gift;
    for (final s in r.seats) {
      final u = s.user;
      if (u == null || u.isMe || u.isAi) continue;
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
    final bots = r.seats.where((s) => s.user != null && !s.user!.isMe && !s.user!.isAi).map((s) => s.user!).toList();
    if (roll < .22 && !r.chatMuted) {
      r.messages.add(VoiceMessage(kind: VoiceMsgKind.chat, text: _botChat[_rng.nextInt(_botChat.length)], user: bots.isEmpty ? _bot() : bots[_rng.nextInt(bots.length)]));
    } else if (roll < .30) {
      final g = voiceGifts[_rng.nextInt(5)];
      final from = _bot();
      final pool = [...bots, ...r.audience.take(4)];
      final to = pool.isNotEmpty && _rng.nextBool() ? pool[_rng.nextInt(pool.length)] : r.host;
      r.recordGift(from, [to], g, 1);
      gift = VoiceMessage(kind: VoiceMsgKind.gift, text: 'أرسل ${g.title} إلى ${to.name}', user: from, gift: g, to: [to]);
      r.messages.add(gift);
      r.heat += g.price;
    } else if (roll < .36) {
      r.listeners++;
      final u = _bot();
      r.audience.insert(0, u);
      if (r.audience.length > 40) r.audience.removeLast();
      r.messages.add(VoiceMessage(kind: VoiceMsgKind.join, text: 'دخل الغرفة', user: u));
    } else if (roll < .40 && r.host.isMe && r.requests.length < 3) {
      final free = r.seats.where((s) => s.empty && !s.locked).firstOrNull;
      if (free != null) addRequest(r, MicRequest(_bot(), free.index));
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
    minimized = null;
  }
}
