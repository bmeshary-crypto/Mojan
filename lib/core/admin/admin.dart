import 'dart:math';

import 'package:flutter/foundation.dart';

import '../account/account.dart';
import '../firebase/cloud.dart';
import 'staff.dart';
import '../voice/voice.dart';

/// مباراة جارية تظهر في لوحة الأدمن.
class LiveMatch {
  LiveMatch({required this.id, required this.game, required this.players, required this.entry, required this.started});
  final String id;
  final String game;
  final List<String> players;
  final int entry;
  final DateTime started;
  String status = 'live'; // live, ended, voided
}

/// صلاحيات وبيانات لوحة التحكم. قبل السيرفر: رمز دخول تجريبي وبيانات من هذا الجهاز + محاكاة.
class AdminService extends ChangeNotifier {
  AdminService._();
  static final instance = AdminService._();

  /// رمز تجريبي حتى تُربط صلاحيات الأدمن بحسابات السيرفر.
  static const demoPin = '1234';

  bool unlocked = false;

  /// للاختبارات ووضع التجربة.
  @visibleForTesting
  bool? adminOverride;

  /// زر لوحة التحكم يظهر للأدمن فقط (المالك وفريق الإدارة).
  bool get isAdmin => adminOverride ?? Cloud.instance.isAdmin;

  /// المالك: كل الصلاحيات وإدارة الفريق.
  bool get isOwner => adminOverride ?? Cloud.instance.isOwner;

  /// هل الحساب الحالي يملك صلاحية [perm] (انظر staffPerms).
  /// وضع التجربة بالرمز (بدون سيرفر) يفتح كل شيء.
  bool can(String perm) {
    if (isOwner) return true;
    final s = Staff.instance.current.value;
    if (s != null) return s.perms.contains(perm);
    return unlocked && !Cloud.instance.enabled;
  }

  /// الأدمن الحقيقي يدخل مباشرة بدون رمز.
  void enterAsAdmin() {
    if (!isAdmin) return;
    unlocked = true;
    _seed();
    notifyListeners();
  }
  final List<LiveMatch> matches = [];
  final List<String> log = [];

  bool unlock(String pin) {
    unlocked = pin == demoPin;
    if (unlocked) _seed();
    notifyListeners();
    return unlocked;
  }

  void lock() {
    unlocked = false;
    notifyListeners();
  }

  void _seed() {
    VoiceService.instance.ensureRooms();
    if (matches.isNotEmpty) return;
    final r = Random(7);
    const names = ['نورة', 'فيصل', 'جود', 'تركي', 'لمى', 'سلطان', 'ريم', 'خالد', 'هيا', 'ماجد'];
    const games = ['ludo', 'ludo', 'seeko', 'quiz', 'ludo', 'truth_dare'];
    for (var i = 0; i < games.length; i++) {
      final n = games[i] == 'quiz' ? 6 : (games[i] == 'truth_dare' ? 5 : 2 + r.nextInt(3));
      matches.add(LiveMatch(
        id: 'M${4100 + i}',
        game: games[i],
        players: [for (var k = 0; k < n; k++) names[(i * 3 + k) % names.length]],
        entry: games[i] == 'ludo' ? const [0, 200, 500, 1000][r.nextInt(4)] : 0,
        started: DateTime.now().subtract(Duration(minutes: 1 + r.nextInt(25))),
      ));
    }
  }

  /// تسجيل إجراء في سجل الإدارة (ويُرفع لسجل الفريق اللي يشوفه المالك).
  void audit(String s) {
    _audit(s);
    Cloud.instance.logAdminAction(s);
    notifyListeners();
  }

  void _audit(String s) {
    log.insert(0, '${_hm(DateTime.now())}  $s');
    if (log.length > 50) log.removeLast();
  }

  static String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// شحن رصيد تجريبي لحساب اللاعب الحالي (للتجربة فقط قبل ربط السيرفر).
  void grantCoins(int amount) {
    final p = Account.instance.profile;
    if (p == null || amount <= 0) return;
    Account.instance.earn(amount);
    _audit('شحن $amount عملة تجريبية لحساب ${p.name}');
    notifyListeners();
  }

  /// إلغاء مباراة وإرجاع الرهان للاعبين.
  void voidMatch(LiveMatch m) {
    m.status = 'voided';
    _audit('ألغى مباراة ${m.id} (${gameTitles[m.game]}) وأرجع ${m.entry} لكل لاعب');
    notifyListeners();
  }

  List<LiveMatch> get liveMatches => matches.where((m) => m.status == 'live').toList();

  int get openReports => VoiceService.instance.reports.where((r) => r.status == 'open').length;

  int get onlineNow => VoiceService.instance.live.fold(0, (a, r) => a + r.online) + liveMatches.fold(0, (a, m) => a + m.players.length);

  /// كل المستخدمين المعروفين (من الغرف + هذا الحساب).
  List<String> get users {
    final set = <String>{};
    final me = Account.instance.profile?.name;
    if (me != null) set.add(me);
    for (final r in VoiceService.instance.rooms) {
      set.add(r.host.name);
      for (final s in r.seats) {
        if (s.user != null) set.add(s.user!.name);
      }
    }
    for (final m in matches) {
      set.addAll(m.players);
    }
    return set.toList()..sort();
  }

  void toggleBan(String name) {
    final b = VoiceService.instance.bannedUsers;
    if (b.contains(name)) {
      b.remove(name);
      _audit('ألغى حظر $name');
    } else {
      b.add(name);
      _audit('حظر $name من الغرف الصوتية');
      // يُنزل المحظور من أي مايك
      for (final r in VoiceService.instance.rooms) {
        for (final s in r.seats) {
          if (s.user?.name == name) s.user = null;
        }
      }
    }
    VoiceService.instance.notify();
    notifyListeners();
  }

  void warnRoom(VoiceRoom r) {
    VoiceService.instance.adminWarn(r);
    _audit('أرسل تحذيراً لغرفة ${r.title}');
    notifyListeners();
  }

  void muteRoom(VoiceRoom r) {
    VoiceService.instance.adminMuteAll(r);
    _audit('كتم كل المايكات في ${r.title}');
    notifyListeners();
  }

  void closeRoom(VoiceRoom r) {
    VoiceService.instance.adminClose(r);
    _audit('أغلق غرفة ${r.title}');
    notifyListeners();
  }

  void resolveReport(VoiceReport rep, String status) {
    VoiceService.instance.setReportStatus(rep, status);
    final what = switch (status) { 'banned' => 'حظر ${rep.target ?? ''}', 'warned' => 'حذّر الغرفة', _ => 'تجاهل البلاغ' };
    if (status == 'warned') {
      final room = VoiceService.instance.byId(rep.roomId);
      if (room != null) VoiceService.instance.adminWarn(room);
    }
    _audit('بلاغ "${rep.reason}" في ${rep.roomTitle}: $what');
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    unlocked = false;
    matches.clear();
    log.clear();
  }
}
