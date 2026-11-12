import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/theme.dart';
import '../../core/voice/live_voice.dart';
import '../../core/voice/voice.dart';
import '../../games/game_registry.dart';
import 'voice_room_screen.dart';
import 'voice_sheets.dart';
import 'voice_widgets.dart';

enum _Filter { all, music, games, party, fresh, popular, following }

/// الصفحة الرئيسية للغرف الصوتية: بانر، أقسام، الغرف الحية.
class VoiceHome extends StatefulWidget {
  const VoiceHome({super.key});

  @override
  State<VoiceHome> createState() => _VoiceHomeState();
}

class _VoiceHomeState extends State<VoiceHome> {
  final svc = VoiceService.instance;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    svc.ensureDemo();
    // الغرف الحقيقية من السيرفر تظهر أعلى القائمة
    LiveVoice.instance.startListing();
  }

  List<VoiceRoom> get _rooms {
    final all = svc.live;
    return switch (_filter) {
      _Filter.all => all,
      _Filter.music =>
        all.where((r) => r.category == VoiceCategory.music).toList(),
      _Filter.games =>
        all
            .where((r) => r.category == VoiceCategory.games || r.game != null)
            .toList(),
      _Filter.party =>
        all
            .where(
              (r) =>
                  r.category == VoiceCategory.party ||
                  r.theme == VoiceTheme.party,
            )
            .toList(),
      _Filter.fresh => svc.rooms.where((r) => !r.closed).toList(),
      _Filter.popular => all.where((r) => r.heat >= 2000).toList(),
      _Filter.following =>
        all.where((r) => svc.following.contains(r.id)).toList(),
    };
  }

  Future<void> _create() async {
    if (Account.instance.profile == null) return;
    final r = await showCreateRoom(context);
    if (r != null && mounted) openVoiceRoom(context, r);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final rooms = _rooms;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            _banner(),
            const SizedBox(height: 16),
            _categories(),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'الغرف الحية',
                  style: AppTheme.display.copyWith(fontSize: 22),
                ),
                const SizedBox(width: 8),
                const LiveBars(),
                const Spacer(),
                Text(
                  '${rooms.length} غرفة',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (rooms.isEmpty)
              Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    artImage('voice_mic', 80),
                    const SizedBox(height: 8),
                    Text(
                      _filter == _Filter.following
                          ? 'ما تتابع أي غرفة حتى الآن'
                          : 'لا توجد غرف في هذا القسم الآن',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextButton(
                      onPressed: _create,
                      child: const Text('أنشئ أول غرفة'),
                    ),
                  ],
                ),
              ),
            for (final (i, r) in rooms.indexed)
              _RoomCard(
                room: r,
                onTap: () => openVoiceRoom(context, r),
              ).animate().fadeIn(delay: (60 * i).ms).slideX(begin: .08, end: 0),
            const SizedBox(height: 8),
            const Text(
              'الغرف والأشخاص فيها تجريبيون، والصوت الحقيقي يشتغل بعد ربط سيرفر الصوت.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
            ),
          ],
        );
      },
    );
  }

  Widget _banner() => GestureDetector(
    key: const ValueKey('voice-create'),
    onTap: _create,
    child: Container(
      height: 130,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4D9D), Color(0xFF8E6CFF), Color(0xFF5B3BD6)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D9D).withValues(alpha: .35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'اكتشف غرف جديدة',
                    style: AppTheme.display.copyWith(fontSize: 24),
                  ),
                  const Text(
                    'تحدث، استمع، تفاعل',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: Color(0xFFB0207A),
                          size: 18,
                        ),
                        Text(
                          'أنشئ غرفتك',
                          style: TextStyle(
                            color: Color(0xFFB0207A),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          artImage('voice_mic', 110)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: 0,
                end: -6,
                duration: 1400.ms,
                curve: Curves.easeInOut,
              ),
        ],
      ),
    ),
  ).animate().fadeIn().slideY(begin: .1, end: 0);

  Widget _categories() {
    final cats = [
      (_Filter.all, 'الكل', 'voice_mic'),
      (_Filter.music, 'موسيقى', 'cat_music'),
      (_Filter.games, 'ألعاب', 'cat_games'),
      (_Filter.party, 'حفلات', 'cat_party'),
      (_Filter.fresh, 'الجديدة', 'cat_new'),
      (_Filter.popular, 'الأكثر شعبية', 'cat_popular'),
      (_Filter.following, 'أتابعها', 'gift_heart'),
    ];
    return SizedBox(
      height: 92,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (f, label, art) in cats)
              GestureDetector(
                key: ValueKey('voice-cat-${f.name}'),
                onTap: () => setState(() => _filter = f),
                child: Container(
                  width: 76,
                  margin: const EdgeInsets.only(left: 8),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: 250.ms,
                        width: 62,
                        height: 62,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: _filter == f ? .18 : .07,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _filter == f
                                ? AppColors.gold
                                : Colors.white12,
                            width: _filter == f ? 2 : 1,
                          ),
                        ),
                        child: artImage(art, 46),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _filter == f ? AppColors.gold : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});
  final VoiceRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final party = room.theme == VoiceTheme.party;
    final game = room.game == null
        ? null
        : GameRegistry.games.where((g) => g.id == room.game).firstOrNull;
    return GestureDetector(
      key: ValueKey('voice-room-${room.id}'),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: party
                ? [
                    const Color(0xFF5B1E8C).withValues(alpha: .9),
                    const Color(0xFF2B1466).withValues(alpha: .9),
                  ]
                : [
                    const Color(0xFF231A55).withValues(alpha: .92),
                    const Color(0xFF181040).withValues(alpha: .92),
                  ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: party
                ? const Color(0xFFFF4D9D).withValues(alpha: .5)
                : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: VoiceAvatar(user: room.host, size: 54, speaking: true),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          room.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                          ),
                        ),
                      ),
                      if (room.locked) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: AppColors.gold,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      artImage(room.category.art, 18),
                      const SizedBox(width: 4),
                      Text(
                        room.category.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (game != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: game.colors[1],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🎮 ${game.title}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                      if (room.live) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: const Color(0xFFFF3B5C), borderRadius: BorderRadius.circular(8)),
                          child: const Text('● مباشر',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ],
                      if (party && game == null) ...[
                        const SizedBox(width: 8),
                        const Text(
                          '🎉 حفلة',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF7AB6),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.mic_rounded,
                        size: 14,
                        color: Color(0xFF8E9BFF),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${room.onSeats + 1}/${room.seats.length + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.headphones_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${room.online}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                const LiveBars(),
                const SizedBox(height: 10),
                InfoChip(
                  icon: const Text('🔥', style: TextStyle(fontSize: 13)),
                  text: fmtK(room.heat),
                  color: const Color(0xFFFFB13D),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
