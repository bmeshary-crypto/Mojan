part of 'admin_screen.dart';

/// نافذة تعيين عضو في الفريق أو تعديل صلاحياته. ترجع true لو تغيّر شيء.
Future<bool> editStaffDialog(BuildContext context, {required String uid, required String name, StaffInfo? current}) async {
  var role = current?.role ?? 'supervisor';
  final perms = <String>{...(current?.perms ?? staffRoles[role]!.$2)};
  final res = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(current == null ? 'تعيين $name في الفريق' : 'صلاحيات $name',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('الدور', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in staffRoles.entries)
                  ChoiceChip(
                    key: ValueKey('staff-role-${r.key}'),
                    label: Text(r.value.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                    selected: role == r.key,
                    onSelected: (_) => set(() {
                      role = r.key;
                      perms
                        ..clear()
                        ..addAll(r.value.$2);
                    }),
                  ),
              ]),
              const SizedBox(height: 10),
              const Text('الصلاحيات (تقدر تعدلها لهذا الشخص)', style: TextStyle(fontWeight: FontWeight.w800)),
              for (final p in staffPerms.entries)
                CheckboxListTile(
                  key: ValueKey('staff-perm-${p.key}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: perms.contains(p.key),
                  onChanged: (v) => set(() => v == true ? perms.add(p.key) : perms.remove(p.key)),
                  title: Text(p.value, style: const TextStyle(fontSize: 13.5)),
                ),
              const Text('إدارة الفريق نفسها للمالك فقط.', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ]),
          ),
        ),
        actions: [
          if (current != null)
            TextButton(
              key: const ValueKey('staff-remove'),
              onPressed: () => Navigator.pop(ctx, 'remove'),
              child: const Text('شيله من الفريق', style: TextStyle(color: Color(0xFFFF7A7A))),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(key: const ValueKey('staff-save'), onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('حفظ')),
        ],
      ),
    ),
  );
  if (res == null) return false;
  final info = res == 'remove' ? null : StaffInfo(role: role, perms: perms, name: name);
  try {
    await Cloud.instance.setStaff(uid, info);
    if (info == null) {
      _staffCache.remove(uid);
    } else {
      _staffCache[uid] = info;
    }
    AdminService.instance.audit(info == null ? 'شال $name من الفريق' : 'عيّن $name ${roleTitle(role)} (${perms.length} صلاحيات)');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(info == null ? 'تم شيل $name من الفريق' : 'تم تعيين $name ${roleTitle(role)} ✅'),
      ));
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text('تعذر الحفظ: $e')));
    }
    return false;
  }
}

/// بطاقة في صفحة اللاعب (للمالك): دوره في الفريق وزر التعيين.
class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.uid, required this.name});
  final String uid;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (!AdminService.instance.isOwner || adminUids.contains(uid)) return const SizedBox.shrink();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Cloud.instance.staffList(),
      builder: (context, snap) {
        Map<String, dynamic>? doc;
        for (final d in snap.data ?? const <Map<String, dynamic>>[]) {
          if (d['uid'] == uid) doc = d;
        }
        final info = StaffInfo.parse(doc);
        return _card(
          key: const ValueKey('user-staff'),
          border: info == null ? null : const Color(0xFF7FE3FF),
          child: Row(children: [
            const Icon(Icons.shield_rounded, color: Color(0xFF7FE3FF)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info == null ? 'مو من فريق الإدارة' : '${roleTitle(info.role)} في الفريق',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                if (info != null)
                  Text(info.perms.map((p) => staffPerms[p] ?? p).join('، '),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
              ]),
            ),
            OutlinedButton(
              key: const ValueKey('user-make-staff'),
              onPressed: () => editStaffDialog(context, uid: uid, name: name, current: info),
              child: Text(info == null ? 'تعيين مشرف/مدير' : 'الصلاحيات'),
            ),
          ]),
        );
      },
    );
  }
}

/// تبويب الفريق (للمالك فقط): الأعضاء وصلاحياتهم، إضافة عضو، وسجل إجراءاتهم.
class _Team extends StatelessWidget {
  const _Team();

  Future<void> _add(BuildContext context) async {
    final users = await Cloud.instance.adminUsers().catchError((Object _) => <Map<String, dynamic>>[]);
    if (!context.mounted) return;
    final pick = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (ctx) => _PickPlayer(users: users.where((u) => !adminUids.contains(u['uid'])).toList()),
    );
    if (pick == null || !context.mounted) return;
    await editStaffDialog(context, uid: pick['uid'] as String, name: '${pick['name'] ?? 'لاعب'}');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Cloud.instance.staffList(),
      builder: (context, snap) {
        final staff = snap.data ?? const <Map<String, dynamic>>[];
        for (final d in staff) {
          final i = StaffInfo.parse(d);
          if (i != null) _staffCache[d['uid'] as String] = i;
        }
        return _list([
          _card(
            border: AppColors.gold,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.groups_rounded, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('فريق الإدارة (${staff.length})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                FilledButton.icon(
                  key: const ValueKey('team-add'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgTop),
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('إضافة عضو', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                'المدير: كل الصلاحيات ما عدا إدارة الفريق.  •  المشرف: اللاعبين والحظر والغرف والبلاغات والدعم.  •  خدمة العملاء: اللاعبين والدعم.  '
                'تقدر تخصص صلاحيات كل شخص. العضو يشوف لوحة التحكم من الإعدادات بحسابه.',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              if (snap.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
              if (staff.isEmpty && snap.connectionState != ConnectionState.waiting)
                const Padding(padding: EdgeInsets.only(top: 10), child: Text('ما فيه أحد في الفريق بعد. اضغط «إضافة عضو».')),
              for (final d in staff)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    const Icon(Icons.shield_rounded, color: Color(0xFF7FE3FF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${d['name'] ?? 'عضو'}  •  ${roleTitle(d['role'] as String?)}',
                            style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text(
                          (StaffInfo.parse(d)?.perms ?? const {}).map((p) => staffPerms[p] ?? p).join('، '),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                        ),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'تعديل الصلاحيات',
                      onPressed: () => editStaffDialog(context,
                          uid: d['uid'] as String, name: '${d['name'] ?? 'عضو'}', current: StaffInfo.parse(d)),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ]),
                ),
            ]),
          ),
          _card(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Cloud.instance.adminLogs(),
              builder: (context, logSnap) {
                final logs = logSnap.data ?? const <Map<String, dynamic>>[];
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.history_rounded, color: AppColors.gold),
                    SizedBox(width: 8),
                    Text('سجل إجراءات الفريق', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ]),
                  const Text('كل تعديل يسويه أي عضو (شحن، حظر، تعديل...) يظهر هنا باسمه.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  if (logs.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('ما فيه إجراءات بعد')),
                  for (final l in logs)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l['role'] == 'owner' ? '👑' : '🛡️'),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: '${l['byName'] ?? ''}: ', style: const TextStyle(fontWeight: FontWeight.w900)),
                            TextSpan(text: '${l['text'] ?? ''}'),
                          ])),
                        ),
                        if (_ts(l['at']) != null)
                          Text(_ago(_ts(l['at'])!), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ]),
                    ),
                ]);
              },
            ),
          ),
        ]);
      },
    );
  }
}

/// اختيار لاعب بالبحث (الاسم أو الـ ID).
class _PickPlayer extends StatefulWidget {
  const _PickPlayer({required this.users});
  final List<Map<String, dynamic>> users;

  @override
  State<_PickPlayer> createState() => _PickPlayerState();
}

class _PickPlayerState extends State<_PickPlayer> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.users.where((u) {
      final p = (u['profile'] as Map?) ?? const {};
      return _q.isEmpty ||
          '${u['name'] ?? ''}'.toLowerCase().contains(_q.toLowerCase()) ||
          '${p['sid'] ?? defaultPlayerId(u['uid'] as String)}'.contains(_q);
    }).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * .75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            key: const ValueKey('team-search'),
            autofocus: true,
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث بالاسم أو الـ ID'),
          ),
        ),
        Expanded(
          child: ListView(children: [
            for (final u in list)
              ListTile(
                leading: PlayerAvatar(index: ((u['avatar'] as num?)?.toInt() ?? 0) % avatars.length, size: 36, ring: false),
                title: Text('${u['name'] ?? 'لاعب'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('ID ${(u['profile'] as Map?)?['sid'] ?? defaultPlayerId(u['uid'] as String)}'),
                onTap: () => Navigator.pop(context, u),
              ),
          ]),
        ),
      ]),
    );
  }
}
