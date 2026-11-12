import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/theme.dart';
import '../../core/vip.dart';
import '../../core/firebase/support.dart';
import '../../core/screenshot.dart';
import '../../core/voice/rtc/rtc.dart';
import '../../core/voice/voice.dart';
import '../../games/game_registry.dart';
import '../../widgets/account_widgets.dart';
import '../shop_screen.dart';
import 'voice_widgets.dart';

Future<T?> _sheet<T>(
  BuildContext context,
  Widget Function(BuildContext) builder,
) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFF1E1446),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
  ),
  builder: (ctx) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ListenableBuilder(
        listenable: VoiceService.instance,
        builder: (c, _) => builder(c),
      ),
    ),
  ),
);

Widget _handle() => Center(
  child: Container(
    width: 44,
    height: 5,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(3),
    ),
  ),
);

Widget _title(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Text(t, style: AppTheme.display.copyWith(fontSize: 22)),
);

void voiceToast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(duration: const Duration(seconds: 2), 
        behavior: SnackBarBehavior.floating,
        content: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
}

// ---------------- الهدايا ----------------

/// يرجع (الهدية، العدد) عند الإرسال.
Future<(VoiceGift, int)?> showGiftSheet(
  BuildContext context,
  VoiceRoom room, {
  VoiceUser? to,
}) {
  final svc = VoiceService.instance;
  var target = to ?? room.host;
  var allMics = false;
  var selected = voiceGifts.first;
  var count = 1;
  return _sheet(context, (ctx) {
    final mics = room.onMics.where((u) => !u.isMe).toList();
    final people = [
      if (to != null && !mics.any((u) => u.id == to.id)) to,
      ...mics,
    ];
    return StatefulBuilder(
      builder: (ctx, set) {
        final coins = Account.instance.profile?.coins ?? 0;
        final targets = allMics ? mics : [target];
        final cost = selected.price * count * targets.length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _handle(),
              Row(
                children: [
                  Text(
                    'إرسال إلى',
                    style: AppTheme.display.copyWith(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          if (mics.length > 1)
                            GestureDetector(
                              key: const ValueKey('gift-to-all-mics'),
                              onTap: () => set(() => allMics = !allMics),
                              child: AnimatedContainer(
                                duration: 200.ms,
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: allMics
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFFFFE27A),
                                            AppColors.goldDeep,
                                          ],
                                        )
                                      : null,
                                  color: allMics ? null : Colors.white12,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: allMics
                                        ? Colors.white
                                        : Colors.white24,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.mic_rounded,
                                      size: 18,
                                      color: allMics
                                          ? AppColors.bgTop
                                          : Colors.white,
                                    ),
                                    Text(
                                      'كل المايكات',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: allMics
                                            ? AppColors.bgTop
                                            : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          for (final p in people)
                            GestureDetector(
                              key: ValueKey('gift-to-${p.id}'),
                              onTap: () => set(() {
                                target = p;
                                allMics = false;
                              }),
                              child: Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: allMics
                                        ? (mics.contains(p)
                                              ? AppColors.gold
                                              : Colors.transparent)
                                        : target.id == p.id
                                        ? AppColors.gold
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: PlayerAvatar(
                                  index: p.avatar,
                                  size: 44,
                                  ring: false,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                allMics
                    ? 'كل من على المايك (${mics.length}) · ${selected.price * count} لكل شخص'
                    : target.name,
                key: const ValueKey('gift-target-name'),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.05,
                children: [
                  for (final g in voiceGifts)
                    GestureDetector(
                      key: ValueKey('gift-${g.id}'),
                      onTap: () => set(() => selected = g),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: selected == g ? .14 : .05,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected == g
                                ? AppColors.gold
                                : Colors.white12,
                            width: selected == g ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: artImage(
                                g.art,
                                70,
                                fallback: Icons.card_giftcard_rounded,
                              ),
                            ),
                            Text(
                              g.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CoinIcon(size: 13),
                                const SizedBox(width: 3),
                                Text(
                                  '${g.price}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: () => openShop(context),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CoinIcon(size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '$coins',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Icon(
                              Icons.add_circle_rounded,
                              color: AppColors.gold,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  for (final n in [1, 5, 10])
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: GestureDetector(
                        key: ValueKey('gift-count-$n'),
                        onTap: () => set(() => count = n),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: count == n ? AppColors.gold : Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '×$n',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: count == n
                                  ? AppColors.bgTop
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  FilledButton(
                    key: const ValueKey('gift-send'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D9D),
                    ),
                    onPressed: () {
                      final err = svc.sendGiftTo(
                        room,
                        selected,
                        targets,
                        count: count,
                      );
                      if (err != null) {
                        voiceToast(context, err);
                        return;
                      }
                      Navigator.pop(ctx, (selected, count));
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'إرسال $cost',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  });
}

// ---------------- بطاقة المستخدم ----------------

Future<void> showUserSheet(
  BuildContext context,
  VoiceRoom room,
  VoiceUser u, {
  int? seat,
  required VoidCallback onGift,
}) {
  final svc = VoiceService.instance;
  final host = svc.isHost(room);
  return _sheet(context, (ctx) {
    final s = seat != null ? room.seats[seat] : null;
    Widget act(
      String key,
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color color = Colors.white,
    }) => Expanded(
      child: InkWell(
        key: ValueKey(key),
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.pop(ctx);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          VoiceAvatar(user: u, size: 76),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(u.name, style: AppTheme.display.copyWith(fontSize: 22)),
              if (u.vip) ...[
                const SizedBox(width: 6),
                VipBadge(u.vipLevel),
              ],
            ],
          ),
          if (!u.isAi) ...[
            const SizedBox(height: 4),
            PlayerIdTag(u.displayId, special: u.specialId, size: 11),
            const SizedBox(height: 2),
          ],
          Text(
            'المستوى ${u.level}${u.id == room.host.id ? ' · المضيف' : ''}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stat('استلم', room.receivedBy(u.id), const Color(0xFFFF7AB6)),
              const SizedBox(width: 10),
              _stat('أرسل', room.sent[u.id] ?? 0, AppColors.gold),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('user-bio'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              (u.isMe ? (Account.instance.profile?.bio ?? u.bio) : u.bio)
                      .trim()
                      .isEmpty
                  ? 'لا توجد نبذة بعد'
                  : (u.isMe ? (Account.instance.profile?.bio ?? u.bio) : u.bio),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          if (!u.isMe) ...[
            GestureDetector(
                  key: const ValueKey('user-gift'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onGift();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF7AB6),
                          Color(0xFFFF4D9D),
                          Color(0xFF8E6CFF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66FF4D9D),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        artImage(
                          'gift_box',
                          32,
                          fallback: Icons.card_giftcard_rounded,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'أرسل هدية إلى ${u.name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(
                  delay: 1200.ms,
                  duration: 1200.ms,
                  color: Colors.white54,
                ),
            Row(
              children: [
                act(
                  'user-mention',
                  Icons.alternate_email_rounded,
                  'منشن',
                  () => svc.sendMessage(room, '@${u.name} '),
                ),
                act(
                  'user-report',
                  Icons.flag_rounded,
                  'إبلاغ',
                  () => showReportSheet(context, room, target: u.name),
                  color: const Color(0xFFFF7A7A),
                ),
              ],
            ),
          ],
          if (host && !u.isMe && !u.isAi && s == null && !room.seats.any((x) => x.user?.id == u.id))
            Row(
              children: [
                act(
                  'host-invite',
                  Icons.mic_external_on_rounded,
                  'دعوة للمايك',
                  () {
                    final err = svc.inviteUser(room, u);
                    voiceToast(context, err ?? 'أرسلنا الدعوة لـ ${u.name} 📨');
                  },
                  color: AppColors.seeko,
                ),
              ],
            ),
          if (u.isMe && s != null)
            Row(
              children: [
                act(
                  'user-leave-seat',
                  Icons.arrow_downward_rounded,
                  'انزل من المايك',
                  () => svc.leaveSeat(room),
                ),
              ],
            ),
          if (host && !u.isMe && s != null) ...[
            const Divider(color: Colors.white12),
            Row(
              children: [
                act(
                  'host-mute',
                  s.muted ? Icons.mic_rounded : Icons.mic_off_rounded,
                  s.muted ? 'إلغاء الكتم' : 'كتم',
                  () => svc.toggleMute(room, s.index),
                ),
                act(
                  'host-down',
                  Icons.arrow_downward_rounded,
                  'إنزال',
                  () => svc.removeFromSeat(room, s.index),
                ),
                act(
                  'host-kick',
                  Icons.person_remove_rounded,
                  'طرد',
                  () {
                    final err = svc.kick(room, u);
                    if (err != null) voiceToast(context, err);
                  },
                  color: const Color(0xFFFF7A7A),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  });
}

Widget _stat(String label, int v, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: c.withValues(alpha: .14),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: c.withValues(alpha: .5)),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/images/gift_box.webp',
        width: 16,
        height: 16,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.card_giftcard_rounded, size: 14),
      ),
      const SizedBox(width: 4),
      Text(
        '$label ',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white70,
        ),
      ),
      Text(
        fmtK(v),
        style: TextStyle(fontWeight: FontWeight.w900, color: c),
      ),
    ],
  ),
);

// ---------------- صندوق الأشخاص ----------------

/// من في الغرفة: على المايك ثم الحضور.
Future<void> showAudienceSheet(
  BuildContext context,
  VoiceRoom room, {
  required void Function(VoiceUser) onUser,
}) => _sheet(context, (ctx) {
  Widget row(VoiceUser u, {String? tag}) => ListTile(
    key: ValueKey('aud-${u.id}'),
    contentPadding: EdgeInsets.zero,
    onTap: () {
      Navigator.pop(ctx);
      onUser(u);
    },
    leading: PlayerAvatar(index: u.avatar, size: 40, ring: false),
    title: Row(
      children: [
        Flexible(
          child: Text(
            u.isMe ? '${u.name} (أنت)' : u.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: u.vip ? AppColors.gold : Colors.white,
            ),
          ),
        ),
        if (tag != null) ...[
          const SizedBox(width: 6),
          Text(
            tag,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ],
    ),
    subtitle: Text(
      'المستوى ${u.level}',
      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
    ),
    trailing: GiftBadge(room.receivedBy(u.id)),
  );
  final svc = VoiceService.instance;
  final meListening = !svc.isHost(room) && svc.mySeat(room) == null;
  return ConstrainedBox(
    key: const ValueKey('audience-sheet'),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .7),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _handle(),
          _title('في الغرفة الآن · ${room.online}'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  '🎤 على المايك',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold,
                  ),
                ),
                for (final (i, u) in room.onMics.indexed)
                  row(u, tag: i == 0 ? '👑 المضيف' : null),
                const SizedBox(height: 8),
                const Text(
                  '👥 الحضور',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold,
                  ),
                ),
                if (meListening) row(svc.me()),
                for (final u in room.audience) row(u),
                if (room.listeners > room.audience.length + 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '+ ${room.listeners - room.audience.length - 1} آخرين يستمعون',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
});

// ---------------- إحصائيات الهدايا ----------------

Future<void> showGiftStats(
  BuildContext context,
  VoiceRoom room,
) => _sheet(context, (ctx) {
  Widget board(List<(VoiceUser, int)> list, String empty) => list.isEmpty
      ? Center(
          child: Text(
            empty,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        )
      : ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) {
            final (u, v) = list[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: i < 3
                    ? AppColors.gold.withValues(alpha: .12 - i * .03)
                    : Colors.white.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  PlayerAvatar(index: u.avatar, size: 36, ring: false),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      u.isMe ? '${u.name} (أنت)' : u.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const CoinIcon(size: 15),
                  const SizedBox(width: 3),
                  Text(
                    fmtK(v),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            );
          },
        );
  return SizedBox(
    key: const ValueKey('gift-stats-sheet'),
    height: MediaQuery.sizeOf(ctx).height * .72,
    child: DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _handle(),
            _title('إحصائيات هدايا الغرفة'),
            Row(
              children: [
                for (final (label, value, c) in [
                  ('قيمة الهدايا', fmtK(room.giftsValue), AppColors.gold),
                  (
                    'عدد الهدايا',
                    fmtK(room.giftsCount),
                    const Color(0xFFFF7AB6),
                  ),
                  ('الداعمون', '${room.sent.length}', const Color(0xFF7CC8FF)),
                ])
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.withValues(alpha: .4)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            value,
                            style: AppTheme.display.copyWith(
                              fontSize: 22,
                              color: c,
                            ),
                          ),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const TabBar(
              indicatorColor: AppColors.gold,
              labelStyle: TextStyle(fontWeight: FontWeight.w900),
              tabs: [
                Tab(text: 'الداعمون'),
                Tab(text: 'المستلمون'),
                Tab(text: 'الهدايا'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  board(room.top(room.sent), 'لا توجد هدايا بعد'),
                  board(room.top(room.received), 'لا توجد هدايا بعد'),
                  GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final g in voiceGifts)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .05),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            children: [
                              Expanded(
                                child: artImage(
                                  g.art,
                                  60,
                                  fallback: Icons.card_giftcard_rounded,
                                ),
                              ),
                              Text(
                                g.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '×${fmtK(room.giftCounts[g.id] ?? 0)}',
                                key: ValueKey('gift-count-stat-${g.id}'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
});

// ---------------- البلاغ ----------------

Future<void> showReportSheet(
  BuildContext context,
  VoiceRoom room, {
  String? target,
}) async {
  // صورة الشاشة قبل فتح نافذة البلاغ، تُرسل كدليل
  final shot = await captureScreen();
  if (!context.mounted) return;
  return _sheet(
    context,
    (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _handle(),
          _title(target == null ? 'الإبلاغ عن الغرفة' : 'الإبلاغ عن $target'),
          const Text(
            'يوصل البلاغ لفريق الإدارة ويراجعونه بسرعة.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          for (final (i, r) in reportReasons.indexed)
            ListTile(
              key: ValueKey('report-$i'),
              leading: const Icon(
                Icons.flag_outlined,
                color: Color(0xFFFF7A7A),
              ),
              title: Text(
                r,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                VoiceService.instance.report(room, r, target: target);
                Support.instance.report(reason: r, roomId: room.id, roomTitle: room.title, target: target, screenshot: shot);
                Navigator.pop(ctx);
                voiceToast(context, shot != null ? 'وصل بلاغك مع صورة الشاشة كدليل، شكراً لك 🙏' : 'وصل بلاغك، شكراً لك 🙏');
              },
            ),
        ],
      ),
    ),
  );
}

// ---------------- الإيموجي ----------------

const voiceEmojis = [
  '😂',
  '😍',
  '👏',
  '🔥',
  '❤️',
  '😮',
  '😢',
  '🎉',
  '🙏',
  '😎',
  '🤣',
  '💯',
  '👍',
  '🌹',
  '🥳',
  '😡',
];

Future<void> showEmojiSheet(BuildContext context, VoiceRoom room) => _sheet(
  context,
  (ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final (i, e) in voiceEmojis.indexed)
              GestureDetector(
                key: ValueKey('emoji-$i'),
                onTap: () {
                  VoiceService.instance.react(room, e);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 30)),
                ),
              ),
          ],
        ),
      ],
    ),
  ),
);

// ---------------- طلبات المايك ----------------

Future<void> showRequestsSheet(BuildContext context, VoiceRoom room) {
  final svc = VoiceService.instance;
  return _sheet(
    context,
    (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _handle(),
          _title('طلبات المايك'),
          if (room.requests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'لا توجد طلبات الآن',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          for (final (i, q) in room.requests.toList().indexed)
            ListTile(
              leading: PlayerAvatar(
                index: q.user.avatar,
                size: 42,
                ring: false,
              ),
              title: Text(
                q.user.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'يطلب المايك ${q.seat + 1} · المستوى ${q.user.level}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: ValueKey('req-accept-$i'),
                    onPressed: () => svc.acceptRequest(room, q),
                    icon: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.seeko,
                      size: 30,
                    ),
                  ),
                  IconButton(
                    key: ValueKey('req-reject-$i'),
                    onPressed: () => svc.rejectRequest(room, q),
                    icon: const Icon(
                      Icons.cancel_rounded,
                      color: Color(0xFFFF7A7A),
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: const ValueKey('invite-mic'),
            onPressed: () => svc.invite(room),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('ادعُ مستمعاً للمايك'),
          ),
        ],
      ),
    ),
  );
}

// ---------------- اختيار لعبة الصالة ----------------

Future<String?> showGamePicker(BuildContext context) => _sheet<String>(
  context,
  (ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _handle(),
        _title('حوّل الغرفة لصالة لعب'),
        const Text(
          'الجالسون على المايك يصيرون لاعبين، والباقي يتفرجون ويسولفون.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.3,
          children: [
            for (final g in GameRegistry.games.where((g) => !coinGames.contains(g.id) || g.id == 'sky_wheel'))
              GestureDetector(
                key: ValueKey('pick-game-${g.id}'),
                onTap: () => Navigator.pop(ctx, g.id),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [g.colors[1], g.colors[2]],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Expanded(child: g.iconBuilder(ctx)),
                      Text(
                        g.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  ),
);

// ---------------- إعدادات الغرفة (للمضيف) ----------------

Future<void> showRoomSettings(
  BuildContext context,
  VoiceRoom room, {
  required VoidCallback onClose,
}) {
  final svc = VoiceService.instance;
  final title = TextEditingController(text: room.title);
  final ann = TextEditingController(text: room.announcement);
  return _sheet(
    context,
    (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _handle(),
            _title('إعدادات الغرفة'),
            TextField(
              key: const ValueKey('room-title-field'),
              controller: title,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'اسم الغرفة'),
            ),
            TextField(
              key: const ValueKey('room-ann-field'),
              controller: ann,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'إعلان الغرفة'),
            ),
            const SizedBox(height: 6),
            const Text(
              'عدد المايكات',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final n in [8, 12, 20])
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      key: ValueKey('seats-$n'),
                      label: Text('$n مايك'),
                      selected: room.seats.length == n,
                      onSelected: (_) => svc.setSeatCount(room, n),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'شكل الغرفة',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  key: const ValueKey('theme-classic'),
                  label: const Text('غرفة عادية'),
                  selected: room.theme == VoiceTheme.classic,
                  onSelected: (_) =>
                      svc.update(room, theme: VoiceTheme.classic),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const ValueKey('theme-party'),
                  label: const Text('🎉 حفلة'),
                  selected: room.theme == VoiceTheme.party,
                  onSelected: (_) => svc.update(room, theme: VoiceTheme.party),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('lock-all-mics'),
                    onPressed: () => svc.lockAll(room, true),
                    icon: const Icon(Icons.lock_rounded, color: AppColors.gold),
                    label: const Text('قفل كل المايكات'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('open-all-mics'),
                    onPressed: () => svc.lockAll(room, false),
                    icon: const Icon(Icons.lock_open_rounded, color: AppColors.seeko),
                    label: const Text('فتح كل المايكات'),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              key: const ValueKey('lock-room'),
              contentPadding: EdgeInsets.zero,
              value: room.locked,
              onChanged: (v) => svc.update(room, locked: v),
              title: const Text(
                'قفل الغرفة (بدون دخول جديد)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            SwitchListTile(
              key: const ValueKey('mute-chat'),
              contentPadding: EdgeInsets.zero,
              value: room.chatMuted,
              onChanged: (v) => svc.update(room, chatMuted: v),
              title: const Text(
                'إيقاف الدردشة الكتابية',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              key: const ValueKey('room-game'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.sports_esports_rounded,
                color: AppColors.quiz,
              ),
              title: Text(
                room.game == null
                    ? 'حوّل الغرفة لصالة لعب'
                    : 'رجّع الغرفة لغرفة صوتية',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onTap: () async {
                if (room.game != null) {
                  svc.setGame(room, null);
                  return;
                }
                final g = await showGamePicker(ctx);
                if (g != null) svc.setGame(room, g);
              },
            ),
            const SizedBox(height: 4),
            FilledButton(
              key: const ValueKey('room-save'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgTop,
              ),
              onPressed: () {
                svc.update(room, title: title.text, announcement: ann.text);
                Navigator.pop(ctx);
              },
              child: const Text(
                'حفظ',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            TextButton.icon(
              key: const ValueKey('room-close'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF7A7A),
              ),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (d) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text(
                      'إغلاق الغرفة؟',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    content: const Text('سيخرج الجميع من الغرفة.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text('إلغاء'),
                      ),
                      FilledButton(
                        key: const ValueKey('confirm-close-room'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A5F),
                        ),
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('أغلق'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                svc.close(room);
                if (ctx.mounted) Navigator.pop(ctx);
                onClose();
              },
              icon: const Icon(Icons.power_settings_new_rounded),
              label: const Text(
                'إغلاق الغرفة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------- إنشاء غرفة ----------------

Future<VoiceRoom?> showCreateRoom(BuildContext context) {
  final title = TextEditingController();
  var cat = VoiceCategory.chat;
  var seats = 12;
  var theme = VoiceTheme.classic;
  return _sheet<VoiceRoom>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _handle(),
              _title('أنشئ غرفتك'),
              TextField(
                key: const ValueKey('create-title'),
                controller: title,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'اسم الغرفة',
                  hintText: 'مثلاً: سهرة طرب',
                ),
              ),
              const Text(
                'القسم',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in VoiceCategory.values)
                    ChoiceChip(
                      key: ValueKey('create-cat-${c.name}'),
                      avatar: artImage(c.art, 22),
                      label: Text(c.label),
                      selected: cat == c,
                      onSelected: (_) => set(() {
                        cat = c;
                        if (c == VoiceCategory.party) theme = VoiceTheme.party;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'عدد المايكات',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in [8, 12, 20])
                    ChoiceChip(
                      key: ValueKey('create-seats-$n'),
                      label: Text('$n مايك'),
                      selected: seats == n,
                      onSelected: (_) => set(() => seats = n),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'الشكل',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('غرفة عادية'),
                    selected: theme == VoiceTheme.classic,
                    onSelected: (_) => set(() => theme = VoiceTheme.classic),
                  ),
                  ChoiceChip(
                    key: const ValueKey('create-party'),
                    label: const Text('🎉 حفلة'),
                    selected: theme == VoiceTheme.party,
                    onSelected: (_) => set(() => theme = VoiceTheme.party),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('create-go'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D9D),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  final r = VoiceService.instance.create(
                    title: title.text,
                    category: cat,
                    seats: seats,
                    theme: theme,
                  );
                  Navigator.pop(ctx, r);
                },
                child: const Text(
                  'افتح الغرفة',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}


// ---------------- دعوة شخص للمايك ----------------

Future<void> showInvitePicker(BuildContext context, VoiceRoom room, {int? seat}) => _sheet(context, (ctx) {
  final svc = VoiceService.instance;
  final people = [for (final u in room.audience) if (!u.isMe && !u.isAi) u];
  return ConstrainedBox(
    key: const ValueKey('invite-picker'),
    constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .6),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _handle(),
          _title(seat == null ? 'ادعُ شخصاً للمايك' : 'ادعُ شخصاً للمايك ${seat + 1}'),
          if (people.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'ما فيه مستمعين في الغرفة الحين.\nشارك رقم الغرفة وادعُ أصحابك 👋',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, height: 1.6),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final u in people)
                    ListTile(
                      key: ValueKey('invite-${u.id}'),
                      contentPadding: EdgeInsets.zero,
                      leading: PlayerAvatar(index: u.avatar, size: 40, ring: false),
                      title: Text(
                        u.name,
                        style: TextStyle(fontWeight: FontWeight.w900, color: u.vip ? AppColors.gold : Colors.white),
                      ),
                      subtitle: Text('المستوى ${u.level}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                      trailing: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.seeko, foregroundColor: AppColors.bgTop),
                        onPressed: () {
                          Navigator.pop(ctx);
                          final err = svc.inviteUser(room, u, seat);
                          voiceToast(context, err ?? 'أرسلنا الدعوة لـ ${u.name} 📨');
                        },
                        icon: const Icon(Icons.mic_external_on_rounded, size: 18),
                        label: const Text('دعوة', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
});

// ---------------- تشغيل الموسيقى في الغرفة ----------------

Future<void> showMediaSheet(BuildContext context, VoiceRoom room) => _sheet(context, (ctx) {
  final svc = VoiceService.instance;
  return StatefulBuilder(
    builder: (ctx, setState) {
      final mine = svc.myMedia(room);
      final rtc = RtcMesh.instance;
      return Padding(
        key: const ValueKey('media-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _handle(),
            _title('🎵 شغّل للغرفة'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF5B3BD6), Color(0xFFB04DFF)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.music_note_rounded, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mine ? room.mediaTitle ?? '' : 'ما فيه شي شغال منك',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mine ? (rtc.mediaPaused ? 'متوقف مؤقتاً' : 'يسمعه كل اللي في الغرفة') : 'اختر أغنية أو أي ملف صوتي من جوالك',
                          style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (mine && !rtc.mediaPaused) const LiveBars(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (mine) ...[
              Row(
                children: [
                  const Icon(Icons.volume_down_rounded, color: Colors.white70),
                  Expanded(
                    child: Slider(
                      key: const ValueKey('media-volume'),
                      value: svc.mediaVolume,
                      activeColor: AppColors.gold,
                      onChanged: (v) {
                        svc.setMediaVolume(v);
                        setState(() {});
                      },
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, color: Colors.white70),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('media-pause'),
                      onPressed: () {
                        svc.toggleMediaPause(room);
                        setState(() {});
                      },
                      icon: Icon(rtc.mediaPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                      label: Text(rtc.mediaPaused ? 'تشغيل' : 'إيقاف مؤقت'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('media-stop'),
                      onPressed: () {
                        svc.stopMedia(room);
                        setState(() {});
                      },
                      icon: const Icon(Icons.stop_rounded, color: Color(0xFFFF7A7A)),
                      label: const Text('إيقاف'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              key: const ValueKey('media-pick'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgTop,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final err = await svc.playMedia(room);
                if (err != null && context.mounted) voiceToast(context, err);
                setState(() {});
              },
              icon: const Icon(Icons.library_music_rounded),
              label: Text(mine ? 'اختر ملف ثاني' : 'اختر ملف صوتي من جوالك', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 8),
            const Text(
              'الصوت يوصل لكل اللي في الغرفة مع صوت المايك. شغّل فقط شي تملك حق مشاركته.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    },
  );
});
