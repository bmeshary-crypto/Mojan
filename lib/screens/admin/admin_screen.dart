import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/admin/admin.dart';
import '../../core/theme.dart';
import '../../core/voice/voice.dart';
import '../../widgets/account_widgets.dart';
import '../voice/voice_room_screen.dart';
import '../voice/voice_widgets.dart';

/// يطلب رمز الأدمن ثم يفتح لوحة التحكم.
Future<void> openAdmin(BuildContext context) async {
  final admin = AdminService.instance;
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
      length: 5,
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
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([admin, VoiceService.instance]),
          builder: (context, _) => const TabBarView(
            children: [_Overview(), _Matches(), _Rooms(), _Reports(), _Users()],
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
