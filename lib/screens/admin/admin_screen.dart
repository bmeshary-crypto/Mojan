import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/admin/admin.dart';
import '../../core/firebase/cloud.dart';
import '../../core/firebase/support.dart';
import '../../core/theme.dart';
import '../../core/voice/voice.dart';
import '../../widgets/account_widgets.dart';
import '../support_screen.dart';
import '../voice/voice_room_screen.dart';
import '../voice/voice_widgets.dart';

/// يطلب رمز الأدمن ثم يفتح لوحة التحكم.
Future<void> openAdmin(BuildContext context) async {
  final admin = AdminService.instance;
  if (admin.isAdmin) admin.enterAsAdmin();
  if (!admin.unlocked) {
    final pin = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'دخول الإدارة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('admin-pin'),
              controller: pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'رمز الأدمن'),
            ),
            const SizedBox(height: 8),
            const Text(
              'وضع تجريبي: الرمز ${AdminService.demoPin}. بعد ربط السيرفر تكون الصلاحية مربوطة بحسابات الأدمن فقط.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const ValueKey('admin-enter'),
            onPressed: () => Navigator.pop(ctx, admin.unlock(pin.text)),
            child: const Text('دخول'),
          ),
        ],
      ),
    );
    if (ok != true) {
      if (ok == false && context.mounted && pin.text.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('الرمز غير صحيح')));
      }
      return;
    }
  }
  if (!context.mounted) return;
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const AdminScreen()));
}

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminService.instance;
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0A24),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16103A),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: AppColors.gold),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'لوحة تحكم MOJAN',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'قفل اللوحة',
              onPressed: () {
                admin.lock();
                Navigator.maybePop(context);
              },
              icon: const Icon(Icons.lock_rounded),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
            tabs: [
              Tab(key: ValueKey('admin-tab-overview'), text: 'نظرة عامة'),
              Tab(key: ValueKey('admin-tab-matches'), text: 'المباريات'),
              Tab(key: ValueKey('admin-tab-rooms'), text: 'الغرف الصوتية'),
              Tab(key: ValueKey('admin-tab-reports'), text: 'البلاغات'),
              Tab(key: ValueKey('admin-tab-users'), text: 'المستخدمون'),
              Tab(key: ValueKey('admin-tab-support'), text: 'الدعم'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([admin, VoiceService.instance]),
          builder: (context, _) => const TabBarView(
            children: [_Overview(), _Matches(), _Rooms(), _Reports(), _Users(), _SupportInbox()],
          ),
        ),
      ),
    );
  }
}

Widget _card({required Widget child, Color? border, Key? key}) => Container(
  key: key,
  margin: const EdgeInsets.only(bottom: 10),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: const Color(0xFF1B1446),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: border ?? Colors.white10,
      width: border == null ? 1 : 1.5,
    ),
  ),
  child: child,
);

Widget _list(List<Widget> children) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 820),
    child: ListView(padding: const EdgeInsets.all(14), children: children),
  ),
);

String _ago(DateTime t) {
  final m = DateTime.now().difference(t).inMinutes;
  return m < 1 ? 'الآن' : (m < 60 ? 'قبل $m د' : 'قبل ${m ~/ 60} س');
}

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    final admin = AdminService.instance;
    final svc = VoiceService.instance;
    final stats = [
      (
        'المتواجدون الآن',
        '${admin.onlineNow}',
        Icons.people_alt_rounded,
        AppColors.quiz,
      ),
      (
        'غرف صوتية حية',
        '${svc.live.length}',
        Icons.mic_rounded,
        const Color(0xFFFF4D9D),
      ),
      (
        'مباريات جارية',
        '${admin.liveMatches.length}',
        Icons.sports_esports_rounded,
        AppColors.seeko,
      ),
      (
        'بلاغات مفتوحة',
        '${admin.openReports}',
        Icons.flag_rounded,
        const Color(0xFFFF7A7A),
      ),
      (
        'مباريات هذا الجهاز',
        '${Account.instance.matchLog.length}',
        Icons.history_rounded,
        AppColors.gold,
      ),
      (
        'محظورون',
        '${svc.bannedUsers.length}',
        Icons.block_rounded,
        Colors.white70,
      ),
    ];
    final flagged = svc.live.where((r) => r.flagged).toList();
    return _list([
      GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: [
          for (final (i, (label, value, icon, color)) in stats.indexed)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: .28),
                    color.withValues(alpha: .08),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: .4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color),
                  Flexible(
                    child: FittedBox(
                      child: Text(
                        value,
                        key: ValueKey('stat-$i'),
                        style: AppTheme.display.copyWith(fontSize: 26),
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (50 * i).ms).scaleXY(begin: .95, end: 1),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        '⚠️ غرف تحتاج مراقبة',
        style: AppTheme.display.copyWith(fontSize: 18),
      ),
      const SizedBox(height: 8),
      if (flagged.isEmpty)
        _card(
          child: const Text(
            'كل الغرف هادئة ✅',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      for (final r in flagged) _RoomRow(room: r),
      const SizedBox(height: 10),
      Text('سجل الإجراءات', style: AppTheme.display.copyWith(fontSize: 18)),
      const SizedBox(height: 8),
      _card(
        child: admin.log.isEmpty
            ? const Text(
                'لا توجد إجراءات بعد',
                style: TextStyle(color: AppColors.textMuted),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in admin.log.take(15))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        l,
                        key: const ValueKey('audit-line'),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                ],
              ),
      ),
      const Text(
        'البيانات حالياً من هذا الجهاز مع غرف ومباريات تجريبية. بعد ربط السيرفر تعرض اللوحة كل المستخدمين لحظياً.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
      ),
    ]);
  }
}

class _Matches extends StatelessWidget {
  const _Matches();

  @override
  Widget build(BuildContext context) {
    final admin = AdminService.instance;
    final log = Account.instance.matchLog;
    return _list([
      Text('مباريات جارية', style: AppTheme.display.copyWith(fontSize: 18)),
      const SizedBox(height: 8),
      for (final m in admin.matches)
        _card(
          key: ValueKey('match-${m.id}'),
          border: m.status == 'voided'
              ? Colors.white24
              : (m.entry >= 1000 ? AppColors.gold.withValues(alpha: .6) : null),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: m.status == 'live'
                      ? const Color(0xFF2EE59D)
                      : Colors.white30,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${gameTitles[m.game]} · ${m.id}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      m.players.join('، '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '${m.entry > 0 ? 'رهان ${m.entry} · ' : ''}بدأت ${_ago(m.started)}${m.status == 'voided' ? ' · ملغاة' : ''}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (m.status == 'live')
                TextButton(
                  key: ValueKey('void-${m.id}'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF7A7A),
                  ),
                  onPressed: () => admin.voidMatch(m),
                  child: Text(m.entry > 0 ? 'إلغاء وإرجاع الرهان' : 'إنهاء'),
                ),
            ],
          ),
        ),
      const SizedBox(height: 10),
      Text(
        'آخر المباريات على هذا الجهاز',
        style: AppTheme.display.copyWith(fontSize: 18),
      ),
      const SizedBox(height: 8),
      if (log.isEmpty)
        _card(
          child: const Text(
            'لم تُلعب مباريات بعد',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      for (final r in log.take(30))
        _card(
          child: Row(
            children: [
              Icon(
                r.won
                    ? Icons.emoji_events_rounded
                    : Icons.sports_esports_rounded,
                color: r.won ? AppColors.gold : Colors.white54,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${gameTitles[r.game] ?? r.game} · ${r.player}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${r.won ? 'فوز' : 'خسارة'} · ${r.points} نقطة · ${_ago(r.at)}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
    ]);
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.room});
  final VoiceRoom room;

  @override
  Widget build(BuildContext context) {
    final admin = AdminService.instance;
    final r = room;
    return _card(
      key: ValueKey('admin-room-${r.id}'),
      border: r.flagged ? const Color(0xFFFF5A5F) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(index: r.host.avatar, size: 40, ring: false),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'المضيف ${r.host.name} · ID ${r.id} · ${r.online} متواجد · ${r.onSeats}/${r.seats.length} مايك',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              if (r.reports > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A5F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${r.reports} بلاغ',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              if (r.warned)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text('⚠️'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                key: ValueKey('monitor-${r.id}'),
                onPressed: () => openVoiceRoom(context, r),
                icon: const Icon(Icons.headphones_rounded, size: 18),
                label: const Text('دخول للمراقبة'),
              ),
              OutlinedButton.icon(
                key: ValueKey('warn-${r.id}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold,
                ),
                onPressed: () => admin.warnRoom(r),
                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                label: const Text('تحذير'),
              ),
              OutlinedButton.icon(
                key: ValueKey('muteall-${r.id}'),
                onPressed: () => admin.muteRoom(r),
                icon: const Icon(Icons.mic_off_rounded, size: 18),
                label: const Text('كتم الكل'),
              ),
              FilledButton.icon(
                key: ValueKey('close-${r.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A5F),
                ),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: Text(
                        'إغلاق "${r.title}"؟',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      content: const Text(
                        'يخرج كل الموجودين وتظهر لهم رسالة من الإدارة.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          key: const ValueKey('confirm-admin-close'),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('أغلق'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) admin.closeRoom(r);
                },
                icon: const Icon(Icons.block_rounded, size: 18),
                label: const Text('إغلاق الغرفة'),
              ),
            ],
          ),
          if (r.messages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'آخر رسالة: ${r.messages.last.user?.name ?? 'النظام'}: ${r.messages.last.text}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Rooms extends StatelessWidget {
  const _Rooms();

  @override
  Widget build(BuildContext context) {
    final rooms = VoiceService.instance.live
      ..sort((a, b) => b.reports.compareTo(a.reports));
    final closed = VoiceService.instance.rooms.where((r) => r.closed).toList();
    return _list([
      for (final r in rooms) _RoomRow(room: r),
      if (closed.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('غرف مغلقة', style: AppTheme.display.copyWith(fontSize: 18)),
        const SizedBox(height: 6),
        for (final r in closed)
          _card(
            child: Text(
              '${r.title} · ${r.messages.last.text}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
      ],
    ]);
  }
}

class _Reports extends StatelessWidget {
  const _Reports();

  @override
  Widget build(BuildContext context) {
    final admin = AdminService.instance;
    final reports = VoiceService.instance.reports;
    return _list([
      if (Cloud.instance.isAdmin) const _CloudReports(),
      if (reports.isEmpty)
        _card(
          child: const Text(
            'لا توجد بلاغات 🎉',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      for (final (i, rep) in reports.indexed)
        _card(
          key: ValueKey('report-row-$i'),
          border: rep.status == 'open' ? const Color(0xFFFF7A7A) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.flag_rounded,
                    color: Color(0xFFFF7A7A),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rep.reason,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    _ago(rep.at),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'الغرفة: ${rep.roomTitle}${rep.target != null ? ' · المبلَّغ عنه: ${rep.target}' : ''} · من: ${rep.reporter}',
                style: const TextStyle(fontSize: 12.5, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              if (rep.status == 'open')
                Wrap(
                  spacing: 6,
                  children: [
                    TextButton(
                      key: ValueKey('rep-dismiss-$i'),
                      onPressed: () => admin.resolveReport(rep, 'dismissed'),
                      child: const Text('تجاهل'),
                    ),
                    OutlinedButton(
                      key: ValueKey('rep-warn-$i'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                      ),
                      onPressed: () => admin.resolveReport(rep, 'warned'),
                      child: const Text('تحذير الغرفة'),
                    ),
                    if (rep.target != null)
                      FilledButton(
                        key: ValueKey('rep-ban-$i'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A5F),
                        ),
                        onPressed: () => admin.resolveReport(rep, 'banned'),
                        child: Text('حظر ${rep.target}'),
                      ),
                  ],
                )
              else
                Text(
                  switch (rep.status) {
                    'banned' => '✅ تم الحظر',
                    'warned' => '✅ تم التحذير',
                    _ => 'تم التجاهل',
                  },
                  style: const TextStyle(
                    color: AppColors.seeko,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
    ]);
  }
}

class _Users extends StatefulWidget {
  const _Users();

  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final admin = AdminService.instance;
    final banned = VoiceService.instance.bannedUsers;
    final users = admin.users.where((u) => u.contains(_q)).toList();
    final me = Account.instance.profile;
    return _list([
      if (Cloud.instance.isAdmin) const _CloudUsers(),
      if (me != null)
        _card(
          border: AppColors.gold,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const CoinIcon(size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('رصيد تجريبي لحسابي (${me.name})',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                ListenableBuilder(
                  listenable: Account.instance,
                  builder: (_, _) => Text('${Account.instance.profile?.coins ?? 0}',
                      key: const ValueKey('grant-balance'),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final n in const [10000, 100000, 1000000])
                  FilledButton(
                    key: ValueKey('grant-$n'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgTop),
                    onPressed: () {
                      admin.grantCoins(n);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text('تمت إضافة $n عملة لحسابك ✅'),
                      ));
                    },
                    child: Text('+$n', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
              ]),
            ],
          ),
        ),
      const SizedBox(height: 10),
      TextField(
        key: const ValueKey('user-search'),
        onChanged: (v) => setState(() => _q = v.trim()),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: 'ابحث باسم المستخدم',
          filled: true,
          fillColor: const Color(0xFF1B1446),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 10),
      for (final u in users)
        _card(
          border: banned.contains(u) ? const Color(0xFFFF5A5F) : null,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white12,
                child: Text(u.characters.first),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  u,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (banned.contains(u))
                const Text(
                  'محظور',
                  style: TextStyle(
                    color: Color(0xFFFF7A7A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              const SizedBox(width: 8),
              TextButton(
                key: ValueKey('ban-$u'),
                onPressed: () => admin.toggleBan(u),
                child: Text(banned.contains(u) ? 'إلغاء الحظر' : 'حظر'),
              ),
            ],
          ),
        ),
      if (users.isEmpty) artImage('voice_mic', 60),
    ]);
  }
}


/// اللاعبون الحقيقيون من السيرفر: الرصيد، شحن عملات، إيقاف.
class _CloudUsers extends StatefulWidget {
  const _CloudUsers();

  @override
  State<_CloudUsers> createState() => _CloudUsersState();
}

class _CloudUsersState extends State<_CloudUsers> {
  late Future<List<Map<String, dynamic>>> _users = Cloud.instance.adminUsers();

  void _reload() => setState(() => _users = Cloud.instance.adminUsers());

  void _snack(String t) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(t)));

  Future<void> _grant(Map<String, dynamic> u) async {
    final c = TextEditingController(text: '1000');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('شحن عملات لـ ${u['name'] ?? 'لاعب'}', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          key: const ValueKey('cloud-grant-amount'),
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'عدد العملات'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim())),
            child: const Text('شحن'),
          ),
        ],
      ),
    );
    if (n == null || n <= 0) return;
    try {
      await Cloud.instance.adminGrant(u['uid'] as String, n);
      _snack('تم إرسال $n عملة، تصل للاعب فور فتحه التطبيق ✅');
      _reload();
    } catch (e) {
      _snack('تعذر الشحن: $e');
    }
  }

  Future<void> _edit(Map<String, dynamic> u, int sameDevice) async {
    final name = TextEditingController(text: '${u['name'] ?? ''}');
    final bio = TextEditingController(text: '${(u['profile'] as Map?)?['bio'] ?? ''}');
    var resetAvatar = false;
    final device = u['device'] as String?;
    final ok = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('تعديل الملف الشخصي', style: TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(key: const ValueKey('edit-name'), controller: name, maxLength: 18, decoration: const InputDecoration(labelText: 'الاسم')),
              TextField(key: const ValueKey('edit-bio'), controller: bio, maxLength: 80, decoration: const InputDecoration(labelText: 'النبذة')),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: resetAvatar,
                onChanged: (v) => set(() => resetAvatar = v ?? false),
                title: const Text('إرجاع الصورة للافتراضية'),
              ),
              const Divider(),
              Text('الجهاز: ${device ?? 'غير معروف'}', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('المنطقة الزمنية: ${u['tz'] ?? '-'}  •  اللغة: ${u['lang'] ?? '-'}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Text('حسابات على نفس الجهاز: $sameDevice',
                  style: TextStyle(color: sameDevice > 1 ? const Color(0xFFFF7A7A) : AppColors.textMuted, fontWeight: FontWeight.w800)),
              if (device != null && sameDevice > 1)
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'ban-device'),
                  icon: const Icon(Icons.phonelink_lock_rounded, color: Color(0xFFFF7A7A)),
                  label: const Text('إيقاف كل حسابات هذا الجهاز', style: TextStyle(color: Color(0xFFFF7A7A))),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    try {
      if (ok == 'save') {
        await Cloud.instance.adminEdit(
          u['uid'] as String,
          name: name.text.trim().isEmpty ? null : name.text.trim(),
          bio: bio.text.trim(),
          avatar: resetAvatar ? 0 : null,
        );
        _snack('تم الحفظ، يتحدث ملف اللاعب عند فتحه التطبيق ✅');
      } else if (ok == 'ban-device' && device != null) {
        await Cloud.instance.adminBanDevice(device, true);
        _snack('تم إيقاف $sameDevice حسابات على نفس الجهاز');
      } else {
        return;
      }
      _reload();
    } catch (e) {
      _snack('تعذر التنفيذ: $e');
    }
  }

  Future<void> _ban(Map<String, dynamic> u) async {
    final ban = u['banned'] != true;
    try {
      await Cloud.instance.adminBan(u['uid'] as String, ban);
      _snack(ban ? 'تم إيقاف ${u['name']}' : 'تم رفع الإيقاف عن ${u['name']}');
      _reload();
    } catch (e) {
      _snack('تعذر التنفيذ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _users,
      builder: (context, snap) {
        final users = snap.data ?? const [];
        final perDevice = <String, int>{};
        for (final u in users) {
          final d = u['device'] as String?;
          if (d != null) perDevice[d] = (perDevice[d] ?? 0) + 1;
        }
        int same(Map<String, dynamic> u) => perDevice[u['device']] ?? 1;
        return _card(
          key: const ValueKey('cloud-users'),
          border: AppColors.quiz,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.cloud_done_rounded, color: AppColors.quiz),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('اللاعبون الحقيقيون (${users.length})',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
              ]),
              if (snap.connectionState != ConnectionState.done) const LinearProgressIndicator(),
              if (snap.hasError) Text('تعذر التحميل: ${snap.error}', style: const TextStyle(color: Color(0xFFFF7A7A))),
              for (final u in users)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    PlayerAvatar(index: ((u['avatar'] as num?)?.toInt() ?? 0) % avatars.length, size: 36, ring: false),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          '${u['name'] ?? 'لاعب'}${adminUidsLabel(u['uid'] as String)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: u['banned'] == true ? const Color(0xFFFF7A7A) : Colors.white,
                          ),
                        ),
                        Text(
                          '🪙 ${(u['profile'] as Map?)?['coins'] ?? 0}  •  ⭐ ${(u['s'] as Map?)?['all'] ?? 0}'
                          '${same(u) > 1 ? '  •  ⚠️ ${same(u)} حسابات بنفس الجهاز' : ''}${u['banned'] == true ? '  •  موقوف' : ''}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'تعديل الملف',
                      onPressed: () => _edit(u, same(u)),
                      icon: const Icon(Icons.edit_rounded, color: Colors.white70),
                    ),
                    IconButton(
                      tooltip: 'شحن عملات',
                      onPressed: () => _grant(u),
                      icon: const Icon(Icons.add_card_rounded, color: AppColors.gold),
                    ),
                    IconButton(
                      tooltip: u['banned'] == true ? 'رفع الإيقاف' : 'إيقاف',
                      onPressed: () => _ban(u),
                      icon: Icon(u['banned'] == true ? Icons.lock_open_rounded : Icons.block_rounded,
                          color: const Color(0xFFFF7A7A)),
                    ),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }
}

String adminUidsLabel(String uid) => Cloud.instance.uid == uid ? ' (أنت)' : '';

DateTime? _ts(Object? v) => v is Timestamp ? v.toDate() : null;

/// بلاغات اللاعبين الحقيقية مع صورة الشاشة كدليل.
class _CloudReports extends StatelessWidget {
  const _CloudReports();

  void _showShot(BuildContext context, Uint8List bytes) => showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: InkWell(
            onTap: () => Navigator.pop(c),
            child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Support.instance.reports(),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('بلاغات اللاعبين (مع صورة الشاشة)', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
          ),
          if (list.isEmpty) _card(child: Text(snap.hasError ? 'تعذر تحميل البلاغات' : 'لا توجد بلاغات من اللاعبين')),
          for (final r in list) _row(context, r),
          const Divider(color: Colors.white12, height: 24),
        ]);
      },
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> r) {
    Uint8List? shot;
    try {
      if (r['shot'] is String) shot = base64Decode(r['shot'] as String);
    } catch (_) {}
    final at = _ts(r['at']);
    final open = r['status'] == 'open';
    final id = r['id'] as String;
    return _card(
      border: open ? const Color(0xFFFF7A7A) : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (shot != null)
          GestureDetector(
            onTap: () => _showShot(context, shot!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(shot, width: 76, height: 120, fit: BoxFit.cover),
            ),
          )
        else
          Container(
            width: 76,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            child: const Text('بدون صورة', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${r['reason'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900))),
              if (at != null) Text(_ago(at), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 4),
            Text(
              [
                if (r['roomTitle'] != null) 'الغرفة: ${r['roomTitle']}',
                if (r['target'] != null) 'المبلَّغ عنه: ${r['target']}',
                'من: ${r['byName'] ?? '-'}',
              ].join(' · '),
              style: const TextStyle(fontSize: 12.5, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              if (shot != null)
                TextButton(onPressed: () => _showShot(context, shot!), child: const Text('عرض الصورة')),
              if (open) ...[
                OutlinedButton(
                  onPressed: () => Support.instance.setReportStatus(id, 'done'),
                  child: const Text('تمت المعالجة'),
                ),
                TextButton(
                  onPressed: () => Support.instance.setReportStatus(id, 'dismissed'),
                  child: const Text('تجاهل'),
                ),
              ] else
                Text(r['status'] == 'done' ? '✅ تمت المعالجة' : 'تم التجاهل',
                    style: const TextStyle(color: AppColors.seeko, fontWeight: FontWeight.w800)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// صندوق رسائل الدعم: محادثات اللاعبين مع الإدارة (طلبات الشحن وغيرها).
class _SupportInbox extends StatelessWidget {
  const _SupportInbox();

  @override
  Widget build(BuildContext context) {
    if (!Cloud.instance.isAdmin || !Support.instance.available) {
      return _list([
        _card(child: const Text('رسائل اللاعبين تظهر هنا في الموقع الرسمي عند الدخول بحساب الأدمن.', style: TextStyle(fontWeight: FontWeight.w700))),
      ]);
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Support.instance.inbox(),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        return _list([
          if (list.isEmpty) _card(child: Text(snap.hasError ? 'تعذر تحميل الرسائل' : 'لا توجد رسائل بعد')),
          for (final c in list)
            _card(
              border: c['unreadAdmin'] == true ? AppColors.gold : null,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: PlayerAvatar(index: (c['avatar'] as num?)?.toInt() ?? 0, size: 44, ring: false),
                title: Text('${c['name'] ?? 'لاعب'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${c['lastText'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (_ts(c['lastAt']) != null)
                    Text(_ago(_ts(c['lastAt'])!), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  if (c['unreadAdmin'] == true)
                    const Text('جديد', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 12)),
                ]),
                onTap: () => openSupport(context, userId: c['uid'] as String, userName: c['name'] as String?),
              ),
            ),
        ]);
      },
    );
  }
}
