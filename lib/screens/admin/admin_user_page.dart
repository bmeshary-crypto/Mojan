part of 'admin_screen.dart';

/// يفتح صفحة لاعب كاملة في لوحة التحكم.
/// [user] مستند اللاعب كما وصل من القائمة (يتحدث مباشرة من السيرفر بعد الفتح).
void openAdminUser(BuildContext context, Map<String, dynamic> user) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminUserPage(user: user)));
}

/// مستند تجريبي من حسابي الحالي (بدون سيرفر) حتى تشتغل الصفحة في وضع التجربة.
Map<String, dynamic>? localUserDoc() {
  final p = Account.instance.profile;
  if (p == null) return null;
  return {
    'uid': p.id,
    'name': p.name,
    'avatar': p.avatar,
    'profile': jsonDecode(jsonEncode(p.toJson())),
    'state': 'on',
    'seen': Timestamp.now(),
    'where': 'لوحة التحكم',
    'method': p.method.name,
    'device': 'هذا الجهاز',
    'ua': deviceInfo(),
    'lang': PlatformDispatcher.instance.locale.toLanguageTag(),
    'tz': 'UTC${DateTime.now().timeZoneOffset.isNegative ? '-' : '+'}${DateTime.now().timeZoneOffset.inHours.abs()}',
    'local': true,
  };
}

const _red = Color(0xFFFF7A7A);
const _green = Color(0xFF2EE59D);

/// وصف واسم أي غرض من المتجر.
String _itemTitle(String id) {
  for (final i in [...shopCatalog, ...styleCatalog]) {
    if (i.id == id) return i.title;
  }
  return id;
}

/// علم الدولة من رمزها (SA → 🇸🇦).
String flagOf(String? cc) {
  if (cc == null || cc.length != 2) return '🌐';
  final up = cc.toUpperCase();
  return String.fromCharCodes(up.codeUnits.map((c) => 0x1F1E6 + c - 65));
}

class AdminUserPage extends StatefulWidget {
  const AdminUserPage({super.key, required this.user});
  final Map<String, dynamic> user;

  @override
  State<AdminUserPage> createState() => _AdminUserPageState();
}

class _AdminUserPageState extends State<AdminUserPage> {
  late Map<String, dynamic> _u = widget.user;
  StreamSubscription<Map<String, dynamic>?>? _sub;
  late Future<List<Map<String, dynamic>>> _linked;
  final _note = TextEditingController();
  String _filter = 'all';

  String get _uid => _u['uid'] as String;
  bool get _local => _u['local'] == true || !Cloud.instance.enabled;
  Map get _p => (_u['profile'] as Map?) ?? const {};
  int _int(Object? v) => (v as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    _note.text = '${_u['note'] ?? ''}';
    _loadLinked();
    if (!_local) {
      _sub = Cloud.instance.adminUser(_uid).listen((d) {
        if (d != null && mounted) setState(() => _u = d);
      });
    } else {
      Account.instance.addListener(_refreshLocal);
      // وضع التجربة: موقع هذا الجهاز نفسه
      lookupGeo().then((g) {
        if (g != null && mounted) setState(() => _u = {..._u, 'geo': g});
      }).catchError((Object _) {});
    }
  }

  void _refreshLocal() {
    final d = localUserDoc();
    if (d != null && mounted && d['uid'] == _uid) setState(() => _u = {..._u, ...d, 'geo': ?_u['geo']});
  }

  void _loadLinked() {
    _linked = _local
        ? Future.value(const [])
        : Cloud.instance.adminLinked(
            device: _u['device'] as String?,
            ip: (_u['geo'] as Map?)?['ip'] as String?,
            except: _uid,
          );
  }

  @override
  void dispose() {
    _sub?.cancel();
    Account.instance.removeListener(_refreshLocal);
    _note.dispose();
    super.dispose();
  }

  void _snack(String t) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating, content: Text(t)));

  /// يرسل تعديلاً للاعب. في وضع التجربة على حسابي يطبق فوراً.
  Future<void> _patch(Map<String, Object?> edit, String done) async {
    try {
      if (_local) {
        if (Account.instance.profile?.id != _uid) return _snack('وضع التجربة: التعديل متاح على حسابك فقط');
        await Cloud.instance.applyAdminEdit(edit);
        _refreshLocal();
      } else {
        await Cloud.instance.adminPatch(_uid, edit);
      }
      AdminService.instance.audit('$done — ${_u['name'] ?? 'لاعب'}');
      _snack('$done ✅');
    } catch (e) {
      _snack('تعذر التنفيذ: $e');
    }
  }

  Future<int?> _askNumber(String title, {String? hint, String initial = '', bool signed = false}) async {
    final c = TextEditingController(text: initial);
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          key: const ValueKey('admin-number'),
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(signed: signed),
          decoration: InputDecoration(labelText: 'العدد', helperText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            key: const ValueKey('admin-number-ok'),
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim().replaceAll(',', ''))),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return n;
  }

  Future<bool> _confirm(String title, String body, {String ok = 'نعم'}) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              key: const ValueKey('admin-confirm-ok'),
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ok),
            ),
          ],
        ),
      ) ==
      true;

  // ---- إجراءات الرصيد ----

  Future<void> _addCoins() async {
    final n = await _askNumber('إضافة عملات', hint: 'تنضاف فوق رصيده الحالي', initial: '1000');
    if (n == null || n <= 0) return;
    await _patch({'coinsAdd': n}, 'تمت إضافة $n عملة');
  }

  Future<void> _takeCoins() async {
    final n = await _askNumber('خصم عملات', hint: 'الرصيد ما ينزل تحت الصفر');
    if (n == null || n <= 0) return;
    await _patch({'coinsAdd': -n}, 'تم خصم $n عملة');
  }

  Future<void> _setCoins() async {
    final n = await _askNumber('تعيين الرصيد', hint: 'يصير رصيده هذا الرقم بالضبط', initial: '${_int(_p['coins'])}');
    if (n == null || n < 0) return;
    await _patch({'coinsSet': n}, 'تم تعيين الرصيد $n');
  }

  Future<void> _setDiamonds() async {
    final n = await _askNumber('تعيين الماسات', initial: '${_int(_p['diamonds'])}');
    if (n == null || n < 0) return;
    await _patch({'diamondsSet': n}, 'تم تعيين الماسات $n');
  }

  Future<void> _addVip() async {
    final n = await _askNumber('إضافة نقاط VIP', hint: 'VIP1 = 5000، VIP3 = 60000، VIP5 = 400000');
    if (n == null || n <= 0) return;
    await _patch({'vipAdd': n}, 'تمت إضافة $n نقطة VIP');
  }

  Future<void> _setLevel() async {
    final n = await _askNumber('تعيين المستوى', initial: '${PlayerProfile.levelOf(_int(_p['xp'])).$1}');
    if (n == null || n < 1) return;
    var xp = 0;
    for (var l = 1; l < n; l++) {
      xp += 100 + 50 * (l - 1);
    }
    await _patch({'xpSet': xp}, 'تم تعيين المستوى $n');
  }

  // ---- إجراءات الحساب ----

  Future<void> _editProfile() async {
    final name = TextEditingController(text: '${_u['name'] ?? ''}');
    final bio = TextEditingController(text: '${_p['bio'] ?? ''}');
    final sid = TextEditingController(text: '${_p['sid'] ?? ''}');
    final oldSid = _p['sid'] as String?;
    var resetAvatar = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('تعديل الملف الشخصي', style: TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(key: const ValueKey('edit-name'), controller: name, maxLength: 18, decoration: const InputDecoration(labelText: 'الاسم')),
              TextField(key: const ValueKey('edit-bio'), controller: bio, maxLength: 80, decoration: const InputDecoration(labelText: 'النبذة')),
              TextField(
                key: const ValueKey('edit-sid'),
                controller: sid,
                keyboardType: TextInputType.number,
                maxLength: 7,
                decoration: const InputDecoration(labelText: 'ID مميز (من 2 إلى 7 أرقام، فاضي = بدون)'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: resetAvatar,
                onChanged: (v) => set(() => resetAvatar = v ?? false),
                title: const Text('إرجاع الصورة للافتراضية'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final newSid = sid.text.trim();
    String? sidOut;
    if (newSid != (oldSid ?? '')) {
      if (newSid.isNotEmpty && !RegExp(r'^[1-9][0-9]{1,6}$').hasMatch(newSid)) {
        return _snack('الـ ID لازم من 2 إلى 7 أرقام وما يبدأ بصفر');
      }
      if (newSid.isEmpty && oldSid != null) await Cloud.instance.releaseId(oldSid);
      if (newSid.isNotEmpty) {
        final err = await Cloud.instance.claimId(newSid, release: oldSid, forUid: _uid);
        if (err != null) return _snack(err);
      }
      sidOut = newSid;
    }
    if (_local) {
      await _patch({
        'name': ?(name.text.trim().isEmpty ? null : name.text.trim()),
        'bio': bio.text.trim(),
        if (resetAvatar) 'avatar': 0,
        'sid': ?sidOut,
      }, 'تم حفظ الملف');
      return;
    }
    try {
      await Cloud.instance.adminEdit(
        _uid,
        name: name.text.trim().isEmpty ? null : name.text.trim(),
        bio: bio.text.trim(),
        avatar: resetAvatar ? 0 : null,
        sid: sidOut,
      );
      _snack('تم الحفظ، يتحدث ملف اللاعب عند فتحه التطبيق ✅');
    } catch (e) {
      _snack('تعذر الحفظ: $e');
    }
  }

  Future<void> _ban() async {
    final linked = await _linked.catchError((Object _) => <Map<String, dynamic>>[]);
    if (!mounted) return;
    final res = await showDialog<_BanResult>(
      context: context,
      builder: (_) => _BanDialog(target: _u, users: [_u, ...linked.map((l) => {...l, 'device': _u['device']})]),
    );
    if (res == null) return;
    if (_local) return _snack('وضع التجربة: الحظر يحتاج السيرفر');
    try {
      await Cloud.instance.adminSetBan(res.ids, res.ban);
      AdminService.instance.audit('${res.ban == null ? 'فك الحظر عن' : 'حظر/قيّد'} ${_u['name']}');
      _snack(res.ban == null ? 'تم فك الحظر والقيود ✅' : 'تم التنفيذ (${res.ban!.remaining()})');
    } catch (e) {
      _snack('تعذر التنفيذ: $e');
    }
  }

  Future<void> _message() async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('رسالة إلى ${_u['name'] ?? 'اللاعب'}', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: c, maxLines: 3, maxLength: 800, decoration: const InputDecoration(hintText: 'تصله في محادثة الدعم مع إشعار')),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in const ['⚠️ تحذير: الرجاء الالتزام بقوانين الغرف', 'مرحباً، نحتاج نتواصل معك بخصوص حسابك', '🎁 هدية من الإدارة، استمتع!'])
              ActionChip(label: Text(t, style: const TextStyle(fontSize: 11)), onPressed: () => c.text = t),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('إرسال')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    if (_local) return _snack('وضع التجربة: الرسائل تحتاج السيرفر');
    try {
      await Support.instance.send(_uid, text, asAdmin: true);
      _snack('تم إرسال الرسالة ✅');
    } catch (e) {
      _snack('تعذر الإرسال: $e');
    }
  }

  Future<void> _saveNote() async {
    if (_local) return _snack('وضع التجربة: الملاحظات تحتاج السيرفر');
    try {
      await Cloud.instance.adminNote(_uid, _note.text.trim());
      _snack('تم حفظ الملاحظة ✅');
    } catch (e) {
      _snack('تعذر الحفظ: $e');
    }
  }

  Future<void> _logout() async {
    if (!await _confirm('تسجيل خروج اللاعب', 'يطلع من حسابه على كل الأجهزة أول ما يفتح التطبيق.', ok: 'سجّل خروجه')) return;
    if (_local) return _snack('وضع التجربة: ما ينفع تسجل خروج نفسك من هنا');
    await _patch({'logout': true}, 'سيتم تسجيل خروجه');
  }

  Future<void> _resetStats() async {
    if (!await _confirm('تصفير الإحصائيات', 'تنحذف إحصائيات كل الألعاب (عدد المباريات والفوز وأفضل نتيجة).', ok: 'صفّر')) return;
    await _patch({'resetStats': true}, 'تم تصفير الإحصائيات');
  }

  Future<void> _clearPosts() async {
    if (!await _confirm('حذف المنشورات', 'تنحذف كل منشورات ملفه الشخصي.', ok: 'احذف')) return;
    await _patch({'clearPosts': true}, 'تم حذف المنشورات');
  }

  Future<void> _delete() async {
    if (!await _confirm('حذف ملف اللاعب نهائياً', 'ينحذف ملفه من السيرفر (الرصيد والترتيب والسجل). ما يمكن التراجع.', ok: 'احذف نهائياً')) return;
    if (_local) return _snack('وضع التجربة: الحذف يحتاج السيرفر');
    try {
      await Cloud.instance.adminDeleteUser(_uid);
      AdminService.instance.audit('حذف ملف ${_u['name']}');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('تعذر الحذف: $e');
    }
  }

  Future<void> _giveItem() async {
    final owned = {...(_p['owned'] as List? ?? const []).cast<String>()};
    final items = [...styleCatalog, ...shopCatalog.where((i) => i.kind == ShopKind.dice || i.kind == ShopKind.board)]
        .where((i) => !owned.contains(i.id))
        .toList();
    final pick = await showModalBottomSheet<ShopItem>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * .7,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          const Text('اختر غرضاً تهديه', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          for (final i in items)
            ListTile(
              dense: true,
              title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${i.id} • ${i.price} 🪙'),
              trailing: const Icon(Icons.card_giftcard_rounded, color: AppColors.gold),
              onTap: () => Navigator.pop(ctx, i),
            ),
        ]),
      ),
    );
    if (pick == null) return;
    await _patch({'own': [pick.id]}, 'تم إهداء ${pick.title}');
  }

  // ---- الواجهة ----

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0A24),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16103A),
          title: Text('${_u['name'] ?? 'لاعب'}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'محادثة الدعم',
              onPressed: _local ? null : () => openSupport(context, userId: _uid, userName: '${_u['name'] ?? ''}'),
              icon: const Icon(Icons.chat_rounded),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Cairo'),
            tabs: [
              Tab(key: ValueKey('user-tab-main'), text: 'الحساب'),
              Tab(key: ValueKey('user-tab-log'), text: 'السجل'),
              Tab(key: ValueKey('user-tab-games'), text: 'الألعاب'),
              Tab(key: ValueKey('user-tab-items'), text: 'الأغراض'),
              Tab(key: ValueKey('user-tab-device'), text: 'الجهاز والموقع'),
            ],
          ),
        ),
        body: TabBarView(children: [_mainTab(), _logTab(), _gamesTab(), _itemsTab(), _deviceTab()]),
      ),
    );
  }

  Widget _header() {
    final vp = _int(_p['vp']);
    final vip = vipLevelFor(vp);
    final presence = presenceOf(_u);
    final seen = _ts(_u['seen']);
    final ban = _banOf(_u);
    final (dot, label) = switch (presence) {
      PresenceState.online => (_green, 'داخل التطبيق الآن'),
      PresenceState.away => (AppColors.gold, 'التطبيق بالخلفية'),
      PresenceState.offline => (Colors.white38, seen == null ? 'خارج التطبيق' : 'آخر ظهور ${_ago(seen)}'),
    };
    final created = DateTime.tryParse('${_p['createdAt'] ?? ''}');
    final method = switch (_u['method'] ?? _p['method']) { 'google' => 'Google', 'phone' => 'هاتف', _ => 'ضيف' };
    return _card(
      border: ban != null ? _red : AppColors.gold,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          FramedAvatar(index: _int(_u['avatar']) % avatars.length, size: 64, frame: _p['frame'] as String?),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text('${_u['name'] ?? 'لاعب'}',
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                ),
                if (vip > 0) ...[const SizedBox(width: 6), VipBadge(vip, size: 14)],
              ]),
              SelectableText(
                'ID ${_p['sid'] ?? defaultPlayerId(_uid)}  •  المستوى ${PlayerProfile.levelOf(_int(_p['xp'])).$1}  •  $method',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Row(children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('$label${presence != PresenceState.offline && _u['where'] != null ? ' • ${_u['where']}' : ''}',
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        ]),
        if ('${_p['bio'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('${_p['bio']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
        const SizedBox(height: 6),
        Text(
          [
            if (created != null) 'سجّل ${created.year}/${created.month}/${created.day}',
            if ('${_p['contact'] ?? ''}'.isNotEmpty) '${_p['contact']}',
            if ((_u['geo'] as Map?)?['country'] != null) '${flagOf((_u['geo'] as Map)['cc'] as String?)} ${(_u['geo'] as Map)['country']}',
          ].join('  •  '),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        if (ban != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${ban.full ? '🚫' : '⛔'} ${ban.describe()}', style: const TextStyle(color: _red, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        SelectableText('UID: $_uid', style: const TextStyle(color: Colors.white24, fontSize: 10)),
      ]),
    );
  }

  Widget _stat(String label, String value, Widget icon, {Color color = Colors.white, Key? key}) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            icon,
            const SizedBox(height: 4),
            FittedBox(child: Text(value, key: key, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: color))),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ),
      );

  Widget _btn(String label, IconData icon, VoidCallback onTap, {Color color = Colors.white, Key? key}) => OutlinedButton.icon(
        key: key,
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: .45)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
      );

  Widget _title(String t, IconData icon, {Color color = AppColors.gold}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ]),
      );

  Widget _mainTab() {
    final coins = _int(_p['coins']);
    final diamonds = _int(_p['diamonds']);
    final vp = _int(_p['vp']);
    final pending = _pendingGrants(_u);
    final edit = _u['edit'];
    final stats = (_p['stats'] as Map?) ?? const {};
    var played = 0, wins = 0;
    for (final e in stats.entries) {
      if (coinGames.contains(e.key) || e.value is! Map) continue;
      played += _int((e.value as Map)['p']);
      wins += _int((e.value as Map)['w']);
    }
    return _list([
      _header(),
      _card(
        key: const ValueKey('user-balance'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('الرصيد', Icons.account_balance_wallet_rounded),
          Row(children: [
            _stat('عملات', fmtK(coins), const CoinIcon(size: 22), color: AppColors.gold, key: const ValueKey('user-coins')),
            const SizedBox(width: 8),
            _stat('ماسات', fmtK(diamonds), const Text('💎', style: TextStyle(fontSize: 18)), color: const Color(0xFF7FE3FF)),
            const SizedBox(width: 8),
            _stat('نقاط VIP', fmtK(vp), const Text('👑', style: TextStyle(fontSize: 18))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            _stat('مباريات', '$played', const Icon(Icons.sports_esports_rounded, size: 20, color: AppColors.quiz)),
            const SizedBox(width: 8),
            _stat('فوز', '$wins', const Icon(Icons.emoji_events_rounded, size: 20, color: _green)),
            const SizedBox(width: 8),
            _stat('نسبة الفوز', played == 0 ? '-' : '${(wins * 100 / played).round()}%', const Icon(Icons.percent_rounded, size: 20)),
          ]),
          if (pending > 0 || edit is Map)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '⏳ بانتظار فتح اللاعب للتطبيق: ${[
                  if (pending > 0) 'شحن $pending',
                  if (edit is Map && edit['coinsAdd'] is num) 'تعديل ${edit['coinsAdd']} عملة',
                  if (edit is Map && edit['coinsSet'] is num) 'تعيين الرصيد ${edit['coinsSet']}',
                  if (edit is Map && edit['diamondsSet'] is num) 'ماسات ${edit['diamondsSet']}',
                  if (edit is Map && edit['logout'] == true) 'تسجيل خروج',
                  if (edit is Map && edit.keys.any((k) => !const ['coinsAdd', 'coinsSet', 'diamondsSet', 'logout'].contains(k))) 'تعديلات أخرى',
                ].join('، ')}',
                style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _btn('إضافة عملات', Icons.add_circle_rounded, _addCoins, color: _green, key: const ValueKey('user-add-coins')),
            _btn('خصم عملات', Icons.remove_circle_rounded, _takeCoins, color: _red, key: const ValueKey('user-take-coins')),
            _btn('تعيين الرصيد', Icons.edit_rounded, _setCoins, color: AppColors.gold, key: const ValueKey('user-set-coins')),
            _btn('تعديل الماسات', Icons.diamond_rounded, _setDiamonds, color: const Color(0xFF7FE3FF)),
            _btn('نقاط VIP', Icons.workspace_premium_rounded, _addVip, color: AppColors.gold),
            _btn('المستوى', Icons.trending_up_rounded, _setLevel),
          ]),
        ]),
      ),
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('إدارة الحساب', Icons.manage_accounts_rounded),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _btn('تعديل الملف', Icons.edit_note_rounded, _editProfile, key: const ValueKey('user-edit-profile')),
            _btn('رسالة', Icons.mail_rounded, _message, color: AppColors.quiz),
            _btn(_banOf(_u) == null ? 'حظر أو تقييد' : 'الحظر (مفعل)', Icons.block_rounded, _ban, color: _red, key: const ValueKey('user-ban')),
            _btn('تسجيل خروجه', Icons.logout_rounded, _logout, color: AppColors.gold),
            _btn('تصفير الإحصائيات', Icons.restart_alt_rounded, _resetStats),
            _btn('حذف المنشورات', Icons.delete_sweep_rounded, _clearPosts),
            _btn('حذف الملف نهائياً', Icons.delete_forever_rounded, _delete, color: _red),
          ]),
        ]),
      ),
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('ملاحظات الإدارة', Icons.sticky_note_2_rounded),
          TextField(
            key: const ValueKey('user-note'),
            controller: _note,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'ملاحظة داخلية (مثلاً: حذّرناه مرة بسبب السب)',
              helperText: _ts(_u['noteAt']) == null ? null : 'آخر تعديل ${_ago(_ts(_u['noteAt'])!)}',
              filled: true,
              fillColor: Colors.white.withValues(alpha: .04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(onPressed: _saveNote, icon: const Icon(Icons.save_rounded), label: const Text('حفظ الملاحظة')),
          ),
        ]),
      ),
    ]);
  }

  static const _kinds = {
    'all': ('الكل', Icons.list_rounded, Colors.white),
    'game': ('مباريات', Icons.sports_esports_rounded, AppColors.quiz),
    'bet': ('رهانات', Icons.casino_rounded, AppColors.gold),
    'buy': ('شراء', Icons.shopping_bag_rounded, Color(0xFFB86CFF)),
    'gift': ('هدايا', Icons.card_giftcard_rounded, Color(0xFFFF4D9D)),
    'diamonds': ('ماسات', Icons.diamond_rounded, Color(0xFF7FE3FF)),
    'reward': ('مكافآت', Icons.redeem_rounded, _green),
    'room': ('غرف', Icons.mic_rounded, Color(0xFF26A69A)),
    'login': ('دخول', Icons.login_rounded, Color(0xFF78909C)),
    'admin': ('الإدارة', Icons.admin_panel_settings_rounded, _red),
  };

  Widget _logTab() {
    final all = [for (final e in (_p['act'] as List? ?? const [])) ?ActEntry.fromJson(e)];
    final list = _filter == 'all' ? all : all.where((e) => e.kind == _filter || (_filter == 'bet' && e.kind == 'spend')).toList();
    var spent = 0, earned = 0;
    for (final e in all) {
      if (e.coins < 0) spent += -e.coins;
      if (e.coins > 0) earned += e.coins;
    }
    return _list([
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('سجل النشاط', Icons.history_rounded),
          Text('آخر ${all.length} حدث  •  دخل +${fmtK(earned)} 🪙  •  صرف -${fmtK(spent)} 🪙',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in _kinds.entries)
              ChoiceChip(
                key: ValueKey('log-filter-${k.key}'),
                label: Text(k.value.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                selected: _filter == k.key,
                onSelected: (_) => setState(() => _filter = k.key),
              ),
          ]),
        ]),
      ),
      if (list.isEmpty)
        _card(
          child: const Text(
            'ما فيه نشاط مسجل بعد. السجل يبدأ من هذا التحديث، ويرتفع للسيرفر لما اللاعب يفتح التطبيق.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      for (final e in list) _logRow(e),
    ]);
  }

  Widget _logRow(ActEntry e) {
    final (_, icon, color) = _kinds[e.kind] ?? ('', Icons.circle_outlined, Colors.white54);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: const Color(0xFF1B1446), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: .15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(
              '${e.at.year}/${e.at.month}/${e.at.day}  ${e.at.hour.toString().padLeft(2, '0')}:${e.at.minute.toString().padLeft(2, '0')}  •  ${_ago(e.at)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ]),
        ),
        if (e.coins != 0)
          Text(
            '${e.coins > 0 ? '+' : ''}${fmtK(e.coins)}',
            textDirection: TextDirection.ltr,
            style: TextStyle(fontWeight: FontWeight.w900, color: e.coins > 0 ? _green : _red),
          ),
      ]),
    );
  }

  Widget _gamesTab() {
    final stats = (_p['stats'] as Map?) ?? const {};
    final rows = [
      for (final e in stats.entries)
        if (e.value is Map) (e.key as String, e.value as Map),
    ]..sort((a, b) => _int(b.$2['p']).compareTo(_int(a.$2['p'])));
    final skill = rows.where((r) => !coinGames.contains(r.$1)).toList();
    final coin = rows.where((r) => coinGames.contains(r.$1)).toList();
    final unlocked = (_p['unlocked'] as List?)?.length ?? 0;
    Widget table(List<(String, Map)> rs, bool isCoin) => Column(children: [
          for (final (g, s) in rs)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(flex: 3, child: Text(gameTitles[g] ?? g, style: const TextStyle(fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('${_int(s['p'])} ${isCoin ? 'جولة' : 'مباراة'}', style: const TextStyle(fontSize: 12))),
                Expanded(
                  flex: 2,
                  child: Text(
                    isCoin ? 'ربح ${_int(s['w'])}' : 'فاز ${_int(s['w'])} (${_int(s['p']) == 0 ? 0 : (_int(s['w']) * 100 / _int(s['p'])).round()}%)',
                    style: const TextStyle(fontSize: 12, color: _green),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(isCoin ? 'مجموع ${fmtK(_int(s['pt']))} 🪙' : 'أفضل ${_int(s['b'])}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
              ]),
            ),
        ]);
    return _list([
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('الألعاب', Icons.sports_esports_rounded, color: AppColors.quiz),
          Text('المستوى ${PlayerProfile.levelOf(_int(_p['xp'])).$1} (${_int(_p['xp'])} خبرة)  •  إنجازات $unlocked/${achievements.length}  •  سلسلة الدخول ${_int(_p['dailyStreak'])} يوم',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          if (skill.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('ما لعب ألعاب بعد')),
          table(skill, false),
        ]),
      ),
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('ألعاب العملات', Icons.casino_rounded),
          if (coin.isEmpty) const Text('ما راهن في ألعاب العملات بعد'),
          table(coin, true),
        ]),
      ),
    ]);
  }

  Widget _itemsTab() {
    final owned = [...(_p['owned'] as List? ?? const []).cast<String>()]..sort();
    final inv = (_p['inventory'] as Map?) ?? const {};
    String wear(String kind, Object? v) =>
        v == null || v == 'none' || v == 'classic' ? 'بدون' : _itemTitle('$kind.$v');
    final worn = {
      'الإطار': wear('frame', _p['frame']),
      'الدخولية': wear('entrance', _p['entrance']),
      'فقاعة الدردشة': wear('bubble', _p['bubble']),
      'الكراسي': wear('chair', _p['chair']),
      'النرد': wear('dice', _p['diceSkin']),
      'اللوحة': wear('board', _p['boardTheme']),
    };
    return _list([
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('يلبس الآن', Icons.checkroom_rounded),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final w in worn.entries)
              Chip(label: Text('${w.key}: ${w.value}', style: const TextStyle(fontSize: 12))),
          ]),
        ]),
      ),
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _title('المقتنيات (${owned.length})', Icons.inventory_2_rounded)),
            _btn('إهداء غرض', Icons.card_giftcard_rounded, _giveItem, color: AppColors.gold, key: const ValueKey('user-give-item')),
          ]),
          if (owned.isEmpty) const Text('ما عنده مقتنيات', style: TextStyle(color: AppColors.textMuted)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final id in owned)
              InputChip(
                label: Text(_itemTitle(id), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onDeleted: () async {
                  if (await _confirm('سحب غرض', 'سحب "${_itemTitle(id)}" من اللاعب؟', ok: 'اسحب')) {
                    await _patch({'unown': [id]}, 'تم سحب ${_itemTitle(id)}');
                  }
                },
              ),
          ]),
        ]),
      ),
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('أدوات لودو في الحقيبة', Icons.backpack_rounded),
          for (final i in LudoItem.values)
            Row(children: [
              Icon(itemInfo[i]?.$3 ?? Icons.extension_rounded, color: itemInfo[i]?.$4, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(itemInfo[i]?.$1 ?? i.name, style: const TextStyle(fontWeight: FontWeight.w700))),
              IconButton(
                onPressed: () => _patch({'inv': {i.name: -1}}, 'نقصت ${itemInfo[i]?.$1 ?? i.name}'),
                icon: const Icon(Icons.remove_circle_outline_rounded, color: _red),
              ),
              Text('${_int(inv[i.name])}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              IconButton(
                onPressed: () => _patch({'inv': {i.name: 5}}, 'أضفت 5 ${itemInfo[i]?.$1 ?? i.name}'),
                icon: const Icon(Icons.add_circle_outline_rounded, color: _green),
              ),
            ]),
        ]),
      ),
    ]);
  }

  Widget _kv(String k, String? v, {bool select = false}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5))),
          Expanded(
            child: select
                ? SelectableText(v == null || v.isEmpty ? '-' : v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))
                : Text(v == null || v.isEmpty ? '-' : v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ]),
      );

  Widget _deviceTab() {
    final geo = (_u['geo'] as Map?) ?? const {};
    return _list([
      _card(
        key: const ValueKey('user-location'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('الموقع', Icons.location_on_rounded, color: _red),
          if (geo.isEmpty)
            const Text('ما وصل موقع بعد. يتسجل أول ما يفتح اللاعب التحديث الجديد.', style: TextStyle(color: AppColors.textMuted)),
          if (geo.isNotEmpty) ...[
            Text('${flagOf(geo['cc'] as String?)}  ${geo['country'] ?? ''}${'${geo['city'] ?? ''}'.isEmpty ? '' : ' • ${geo['city']}'}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            _kv('المنطقة', '${geo['region'] ?? ''}'),
            _kv('عنوان IP', '${geo['ip'] ?? ''}', select: true),
            _kv('مزود الإنترنت', '${geo['isp'] ?? ''}'),
            _kv('توقيت الموقع', '${geo['tz'] ?? ''}'),
            const SizedBox(height: 4),
            const Text('الموقع تقريبي من عنوان الإنترنت (مو GPS)، والـ VPN يغيّره.', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ]),
      ),
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('الجهاز', Icons.phone_android_rounded, color: AppColors.quiz),
          _kv('نوع الجهاز', '${_u['ua'] ?? ''}'),
          _kv('رقم الجهاز', '${_u['device'] ?? ''}', select: true),
          _kv('توقيت الجهاز', '${_u['tz'] ?? ''}'),
          _kv('اللغة', '${_u['lang'] ?? ''}'),
          _kv('طريقة الدخول', switch (_u['method'] ?? _p['method']) { 'google' => 'Google', 'phone' => 'هاتف', _ => 'ضيف' }),
          _kv('آخر حفظ', _ts(_u['updatedAt']) == null ? null : _ago(_ts(_u['updatedAt'])!)),
        ]),
      ),
      _card(
        key: const ValueKey('user-linked'),
        border: const Color(0xFFFFB13D),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _linked,
          builder: (context, snap) {
            final list = snap.data ?? const [];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _title('الحسابات المتعددة (${list.length})', Icons.people_alt_rounded, color: const Color(0xFFFFB13D))),
                IconButton(onPressed: () => setState(_loadLinked), icon: const Icon(Icons.refresh_rounded)),
              ]),
              const Text('حسابات ثانية دخلت من نفس الجهاز أو نفس عنوان الإنترنت.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              if (snap.connectionState != ConnectionState.done) const LinearProgressIndicator(),
              if (snap.hasError) Text('تعذر البحث: ${snap.error}', style: const TextStyle(color: _red, fontSize: 12)),
              if (snap.connectionState == ConnectionState.done && list.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 8), child: Text('✅ ما فيه حسابات مرتبطة')),
              for (final l in list)
                InkWell(
                  onTap: () => openAdminUser(context, l),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      PlayerAvatar(index: _int(l['avatar']) % avatars.length, size: 34, ring: false),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${l['name'] ?? 'لاعب'}', style: TextStyle(fontWeight: FontWeight.w800, color: _banOf(l) != null ? _red : Colors.white)),
                          Text('${l['why']}  •  🪙 ${fmtK(_int((l['profile'] as Map?)?['coins']))}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                        ]),
                      ),
                      const Icon(Icons.chevron_left_rounded, color: Colors.white38),
                    ]),
                  ),
                ),
              if (list.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _btn('حظر هذا الحساب والمرتبطين', Icons.phonelink_lock_rounded, () async {
                    final res = await showDialog<_BanResult>(
                      context: context,
                      builder: (_) => _BanDialog(target: _u, users: [_u, ...list.map((l) => {...l, 'device': _u['device']})]),
                    );
                    if (res == null) return;
                    try {
                      await Cloud.instance.adminSetBan(res.ids, res.ban);
                      _snack('تم التنفيذ على ${res.ids.length} حساب ✅');
                    } catch (e) {
                      _snack('تعذر التنفيذ: $e');
                    }
                  }, color: _red),
                ),
            ]);
          },
        ),
      ),
    ]);
  }
}
