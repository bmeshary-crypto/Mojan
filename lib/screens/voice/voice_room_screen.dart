import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/game_module.dart';
import '../../core/haptics.dart';
import '../../core/shop.dart';
import '../../core/theme.dart';
import '../../core/voice/voice.dart';
import '../../games/game_registry.dart';
import '../../games/sky_wheel/sky_wheel_screen.dart';
import '../../widgets/account_widgets.dart';
import 'voice_sheets.dart';
import 'voice_widgets.dart';

/// داخل الغرفة الصوتية: المضيف، المايكات، الدردشة، الهدايا، وصالة اللعب.
class VoiceRoomScreen extends StatefulWidget {
  const VoiceRoomScreen({super.key, required this.room, this.simulate = true});
  final VoiceRoom room;

  /// تشغيل محاكاة المستخدمين الآخرين (تُطفأ في بعض الاختبارات).
  final bool simulate;

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  final svc = VoiceService.instance;
  VoiceRoom get room => widget.room;
  Timer? _timer;
  final _chat = TextEditingController();
  final _chatFocus = FocusNode();
  bool _typing = false;

  /// الهدية المعروضة الآن في منتصف الشاشة.
  VoiceMessage? _giftFx;
  int _giftKey = 0;

  VoiceUser? _entryFx;
  int _entryKey = 0;

  // أماكن الأشخاص على الشاشة لتطير الهدية إليها
  final _stackKey = GlobalKey();
  final _hostKey = GlobalKey();
  final _peopleKey = GlobalKey();
  final Map<int, GlobalKey> _seatKeys = {};
  GlobalKey _seatKey(int i) => _seatKeys.putIfAbsent(i, GlobalKey.new);
  final List<_Flight> _flights = [];
  int _flightId = 0;

  /// عند التصغير لا نخرج من الغرفة.
  bool _minimizing = false;
  late int _seen = room.messages.length;

  @override
  void initState() {
    super.initState();
    if (svc.minimized == room) {
      // رجوع من الفقاعة المصغّرة
      Future.microtask(svc.restore);
    }
    // دخوليتي أنا عند فتح الغرفة
    final me = svc.me();
    if (me.entrance != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showEntry(me);
      });
    }
    if (widget.simulate) {
      _timer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
        if (!mounted) return;
        final g = svc.tick(room);
        // كل هدية تطير لصاحبها، والكبيرة فقط تظهر بشريطها في الوسط
        if (g != null) {
          if (g.gift!.price >= 99) {
            _showGift(g);
          } else {
            _launch(g);
          }
        }
        _checkEntries();
      });
    }
  }

  void _checkEntries() {
    final msgs = room.messages;
    final from = _seen.clamp(0, msgs.length);
    for (final m in msgs.skip(from)) {
      if (m.kind == VoiceMsgKind.join &&
          m.user?.entrance != null &&
          _giftFx == null) {
        _showEntry(m.user!);
      }
    }
    _seen = msgs.length;
  }

  void _showEntry(VoiceUser u) {
    setState(() {
      _entryFx = u;
      _entryKey++;
    });
    final k = _entryKey;
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted && _entryKey == k) setState(() => _entryFx = null);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chat.dispose();
    _chatFocus.dispose();
    // نخرج بعد انتهاء بناء الشجرة لأن الخروج ينبه المستمعين
    final r = room;
    final service = svc;
    if (!_minimizing) Future.microtask(() => service.leave(r));
    super.dispose();
  }

  /// مكان الشخص على الشاشة: كرسيه، أو مقعد المضيف، أو صندوق الأشخاص.
  GlobalKey _targetOf(VoiceUser u) {
    if (u.id == room.host.id) return _hostKey;
    for (final s in room.seats) {
      if (s.user?.id == u.id) return _seatKey(s.index);
    }
    return _peopleKey;
  }

  Offset? _centerOf(GlobalKey k, RenderBox stack) {
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return stack.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  /// الهدية تكبر في الوسط ثم تطير إلى مكان كل مستلم.
  void _launch(VoiceMessage m) {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || m.gift == null || m.to.isEmpty) return;
    final from = stack.size.center(Offset.zero) - const Offset(0, 40);
    final ids = <int>[];
    for (final (i, u) in m.to.indexed) {
      final to = _centerOf(_targetOf(u), stack) ?? from;
      final f = _Flight(++_flightId, m.gift!.art, from, to, i * 110);
      ids.add(f.id);
      _flights.add(f);
    }
    setState(() {});
    Future.delayed(Duration(milliseconds: 2300 + m.to.length * 110), () {
      if (!mounted) return;
      setState(() => _flights.removeWhere((f) => ids.contains(f.id)));
    });
  }

  void _openUser(VoiceUser u) {
    final seat = room.seats.where((s) => s.user?.id == u.id).firstOrNull;
    showUserSheet(
      context,
      room,
      u,
      seat: seat?.index,
      onGift: () => _gift(to: u),
    );
  }

  void _showGift(VoiceMessage m) {
    _launch(m);
    setState(() {
      _giftFx = m;
      _giftKey++;
    });
    final k = _giftKey;
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted && _giftKey == k) setState(() => _giftFx = null);
    });
  }

  /// يفتح عجلة السماء فوق الغرفة (الصوت والمحادثة يكملون).
  void _openSkyWheel() {
    final h = MediaQuery.sizeOf(context).height;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: SizedBox(height: h * .86, child: const SkyWheelScreen(key: ValueKey('room-sky-wheel'))),
        ),
      ),
    );
  }

  Future<void> _gift({VoiceUser? to}) async {
    final sent = await showGiftSheet(context, room, to: to);
    if (sent != null && mounted) {
      Haptics.heavyImpact();
      _showGift(room.messages.last);
    }
  }

  void _seatTap(VoiceSeat s) {
    final host = svc.isHost(room);
    if (s.user != null) {
      showUserSheet(
        context,
        room,
        s.user!,
        seat: s.index,
        onGift: () => _gift(to: s.user),
      );
      return;
    }
    if (host) {
      _hostSeatMenu(s);
      return;
    }
    final err = svc.takeSeat(room, s.index);
    if (err != null) {
      voiceToast(context, err);
    } else {
      Haptics.mediumImpact();
    }
  }

  void _hostSeatMenu(VoiceSeat s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1446),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('seat-lock'),
              leading: Icon(
                s.locked ? Icons.lock_open_rounded : Icons.lock_rounded,
                color: AppColors.gold,
              ),
              title: Text(
                s.locked
                    ? 'فتح المايك ${s.index + 1}'
                    : 'قفل المايك ${s.index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onTap: () {
                svc.toggleLock(room, s.index);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              key: const ValueKey('seat-invite'),
              leading: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.seeko,
              ),
              title: const Text(
                'دعوة مستمع لهذا المايك',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onTap: () {
                svc.invite(room);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pop() {
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _exit() async {
    if (room.closed) {
      _pop();
      return;
    }
    final host = svc.isHost(room);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1446),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        Widget opt(
          String key,
          IconData icon,
          String title,
          String sub,
          Color c,
        ) => ListTile(
          key: ValueKey(key),
          onTap: () => Navigator.pop(ctx, key),
          leading: CircleAvatar(
            backgroundColor: c.withValues(alpha: .18),
            child: Icon(icon, color: c),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            sub,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  host ? 'مغادرة غرفتك؟' : 'مغادرة الغرفة؟',
                  style: AppTheme.display.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 8),
                opt(
                  'exit-minimize',
                  Icons.picture_in_picture_alt_rounded,
                  'تصغير الغرفة',
                  'تبقى في الغرفة وتظهر كفقاعة عائمة ترجع لها متى شئت',
                  const Color(0xFF7CC8FF),
                ),
                opt(
                  host ? 'exit-keep' : 'exit-leave',
                  Icons.logout_rounded,
                  host ? 'اخرج وخلها مفتوحة' : 'خروج من الغرفة',
                  host
                      ? 'تخرج أنت والغرفة تبقى لأصحابك'
                      : 'تنزل من المايك وتخرج',
                  Colors.white,
                ),
                if (host)
                  opt(
                    'exit-close',
                    Icons.power_settings_new_rounded,
                    'أغلق الغرفة',
                    'تُغلق للجميع',
                    const Color(0xFFFF5A5F),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (choice == null || !mounted) return;
    if (choice == 'exit-minimize') {
      _minimizing = true;
      svc.minimize(room);
    } else if (choice == 'exit-close') {
      svc.close(room);
    }
    _pop();
  }

  void _menu() {
    if (svc.isHost(room)) {
      showRoomSettings(context, room, onClose: () => _pop());
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1446),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_rounded, color: AppColors.quiz),
              title: const Text(
                'شارك رقم الغرفة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('ID: ${room.id}'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: room.id));
                Navigator.pop(ctx);
                voiceToast(context, 'نسخنا رقم الغرفة ${room.id}');
              },
            ),
            ListTile(
              key: const ValueKey('menu-report'),
              leading: const Icon(Icons.flag_rounded, color: Color(0xFFFF7A7A)),
              title: const Text(
                'إبلاغ عن الغرفة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onTap: () {
                Navigator.pop(ctx);
                showReportSheet(context, room);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text(
                'مغادرة الغرفة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final err = svc.sendMessage(room, _chat.text);
    if (err != null) voiceToast(context, err);
    _chat.clear();
    setState(() => _typing = false);
    _chatFocus.unfocus();
  }

  void _raiseHand() {
    final free = room.seats.where((s) => s.empty && !s.locked).firstOrNull;
    if (free == null) {
      voiceToast(context, 'كل المايكات مشغولة');
      return;
    }
    svc.takeSeat(room, free.index);
    Haptics.mediumImpact();
  }

  Future<void> _startGame() async {
    final g = GameRegistry.games.firstWhere((m) => m.id == room.game);
    final mode = g.modes.contains(PlayMode.rooms)
        ? PlayMode.rooms
        : PlayMode.local;
    room.messages.add(
      VoiceMessage(
        kind: VoiceMsgKind.system,
        text: '🎮 بدأت مباراة ${g.title}!',
      ),
    );
    svc.notify();
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (c) => g.screenBuilder(c, mode)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // زر الرجوع في الجهاز يعرض نفس خيارات المغادرة (تصغير/خروج)
      onPopInvokedWithResult: (did, _) {
        if (!did) _exit();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: ListenableBuilder(
          listenable: svc,
          builder: (context, _) {
            final party = room.theme == VoiceTheme.party;
            return Stack(
              key: _stackKey,
              children: [
                Positioned.fill(child: _background(party)),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        children: [
                          _topBar(),
                          _announcement(),
                          if (room.closed)
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '🔒',
                                      style: TextStyle(fontSize: 56),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      room.messages.last.text,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton(
                                      onPressed: () => _pop(),
                                      child: const Text('رجوع'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, c) {
                                  return SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      4,
                                      12,
                                      8,
                                    ),
                                    child: Column(
                                      children: [
                                        _hostArea(party),
                                        if (room.game != null) _gameHall(),
                                        const SizedBox(height: 10),
                                        _seatsGrid(c.maxWidth - 24, party),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            _chatPanel(),
                            _bottomBar(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (_entryFx != null) _entryOverlay(_entryFx!),
                if (_giftFx != null) _giftOverlay(_giftFx!),
                for (final f in _flights) _flight(f),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _background(bool party) {
    if (party) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/party_bg.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF3B1466)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x22000000),
                  Color(0xCC12082E),
                ],
                stops: [0, .45, 1],
              ),
            ),
          ),
        ],
      );
    }
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.55),
          radius: 1.2,
          colors: [Color(0xFF2B1B6B), Color(0xFF120B33), Color(0xFF0B0722)],
          stops: [0, .55, 1],
        ),
      ),
    );
  }

  Widget _topBar() {
    final following = svc.following.contains(room.id);
    final host = svc.isHost(room);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
      child: Row(
        children: [
          PlayerAvatar(index: room.host.avatar, size: 42),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  room.title,
                  key: const ValueKey('room-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        key: const ValueKey('room-people'),
                        onTap: () =>
                            showAudienceSheet(context, room, onUser: _openUser),
                        child: InfoChip(
                          key: _peopleKey,
                          icon: const Icon(
                            Icons.groups_rounded,
                            size: 15,
                            color: Colors.white70,
                          ),
                          text: '${room.online}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        key: const ValueKey('room-heat'),
                        onTap: () => showGiftStats(context, room),
                        child: InfoChip(
                          icon: const Text(
                            '🔥',
                            style: TextStyle(fontSize: 12),
                          ),
                          text: fmtK(room.heat),
                          color: const Color(0xFFFFB13D),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ID ${room.id}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!host)
            GestureDetector(
              key: const ValueKey('room-follow'),
              onTap: () => svc.toggleFollow(room),
              child: AnimatedContainer(
                duration: 250.ms,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  gradient: following
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF8E6CFF), Color(0xFFB86CFF)],
                        ),
                  color: following ? Colors.white12 : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  following ? 'متابَعة ✓' : 'متابعة',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          IconButton(
            key: const ValueKey('room-stats'),
            tooltip: 'إحصائيات الهدايا',
            onPressed: () => showGiftStats(context, room),
            icon: const Icon(
              Icons.leaderboard_rounded,
              color: Color(0xFFFFD66B),
            ),
          ),
          IconButton(
            key: const ValueKey('room-menu'),
            onPressed: _menu,
            icon: Icon(host ? Icons.settings_rounded : Icons.more_vert_rounded),
          ),
          IconButton(
            key: const ValueKey('room-exit'),
            onPressed: _exit,
            icon: const Icon(
              Icons.power_settings_new_rounded,
              color: Color(0xFFFF7A7A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _announcement() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black26,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.campaign_rounded, size: 16, color: AppColors.gold),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            room.announcement,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        if (room.locked)
          const Icon(Icons.lock_rounded, size: 14, color: AppColors.gold),
      ],
    ),
  );

  Widget _hostArea(bool party) {
    final h = room.host;
    final speaking = h.isMe ? svc.micOn : room.hostSpeaking;
    return GestureDetector(
      key: const ValueKey('host-seat'),
      onTap: () => showUserSheet(context, room, h, onGift: () => _gift(to: h)),
      child: Padding(
        padding: EdgeInsets.only(top: party ? 26 : 22),
        child: Column(
          children: [
            KeyedSubtree(
              key: _hostKey,
              child: VoiceAvatar(
                user: h,
                size: party ? 92 : 84,
                speaking: speaking,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👑', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  h.isMe ? 'أنت المضيف' : h.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'المضيف',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.bgTop,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            GiftBadge(room.receivedBy(h.id), key: const ValueKey('gifts-host')),
          ],
        ),
      ),
    );
  }

  Widget _gameHall() {
    final g = GameRegistry.games.firstWhere((m) => m.id == room.game);
    final players = [
      room.host,
      ...room.seats.where((s) => s.user != null).map((s) => s.user!),
    ];
    final max = switch (g.id) {
      'ludo' || 'seeko' => 4,
      'quiz' => 8,
      _ => 10,
    };
    final host = svc.isHost(room);
    return Container(
      key: const ValueKey('game-hall'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            g.colors[1].withValues(alpha: .85),
            g.colors[2].withValues(alpha: .7),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(color: g.colors[1].withValues(alpha: .4), blurRadius: 20),
        ],
      ),
      child: Row(
        children: [
          SizedBox(width: 70, height: 70, child: g.iconBuilder(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'صالة ${g.title}',
                  style: AppTheme.display.copyWith(fontSize: 20),
                ),
                Text(
                  'اللاعبون ${min(players.length, max)}/$max · الباقي يتفرجون',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 26,
                  child: Row(
                    children: [
                      for (final p in players.take(max).take(6))
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: PlayerAvatar(
                            index: p.avatar,
                            size: 24,
                            ring: false,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            key: const ValueKey('hall-start'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: g.colors[2],
            ),
            onPressed: host || svc.onMic(room) ? _startGame : null,
            child: Text(
              host ? 'ابدأ' : 'العب',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: .2, end: 0);
  }

  Widget _seatsGrid(double width, bool party) {
    final n = room.seats.length;
    final cols = n >= 20 ? 5 : 4;
    final size = ((width / cols) - 22).clamp(36.0, party ? 64.0 : 58.0);
    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 10,
      children: [
        for (final s in room.seats)
          SizedBox(
            width: width / cols,
            child: Center(
              child: KeyedSubtree(
                key: _seatKey(s.index),
                child: SeatTile(
                  seat: s,
                  size: size,
                  party: party,
                  gifts: s.user == null ? 0 : room.receivedBy(s.user!.id),
                  onTap: () => _seatTap(s),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chatPanel() {
    final msgs = room.messages.reversed.take(30).toList();
    return Container(
      key: const ValueKey('room-chat'),
      height: 150,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: ListView.builder(
        reverse: true,
        itemCount: msgs.length,
        itemBuilder: (_, i) {
          final m = msgs[i];
          final row = _messageRow(m);
          if (m.user == null) return row;
          return GestureDetector(
            key: ValueKey('chat-user-$i'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _openUser(m.user!),
            child: row,
          );
        },
      ),
    );
  }

  Widget _messageRow(VoiceMessage m) {
    switch (m.kind) {
      case VoiceMsgKind.system:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            m.text,
            style: const TextStyle(
              color: Color(0xFFFFD66B),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case VoiceMsgKind.join:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '${m.user!.name} ${m.text} 👋',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        );
      case VoiceMsgKind.gift:
      case VoiceMsgKind.chat:
        final u = m.user!;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlayerAvatar(index: u.avatar, size: 24, ring: false),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: m.kind == VoiceMsgKind.gift
                        ? const Color(0x55FF4D9D)
                        : (u.bubble == null
                              ? Colors.white.withValues(alpha: .08)
                              : null),
                    gradient: m.kind != VoiceMsgKind.gift && u.bubble != null
                        ? LinearGradient(
                            colors: [
                              for (final c in bubbleStyles[u.bubble]!)
                                c.withValues(alpha: .75),
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${u.name}: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: u.isMe
                                ? (u.bubble != null
                                      ? Colors.white
                                      : AppColors.seeko)
                                : (u.bubble != null
                                      ? Colors.white
                                      : u.vip
                                      ? AppColors.gold
                                      : const Color(0xFFB9A9E8)),
                          ),
                        ),
                        TextSpan(
                          text: m.text,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
              if (m.gift != null) ...[
                const SizedBox(width: 4),
                artImage(m.gift!.art, 26),
              ],
            ],
          ),
        );
    }
  }

  Widget _round(
    String key,
    Widget icon,
    VoidCallback? onTap, {
    List<Color>? colors,
    int badge = 0,
  }) => GestureDetector(
    key: ValueKey(key),
    onTap: onTap,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: colors == null ? null : LinearGradient(colors: colors),
            color: colors == null ? Colors.white.withValues(alpha: .12) : null,
          ),
          child: icon,
        ),
        if (badge > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFFF4D6D),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _bottomBar() {
    final host = svc.isHost(room);
    final seat = svc.mySeat(room);
    final onMic = svc.onMic(room);
    final mutedByHost = seat != null && room.seats[seat].muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: _typing
                ? TextField(
                    key: const ValueKey('chat-field'),
                    controller: _chat,
                    focusNode: _chatFocus,
                    autofocus: true,
                    maxLength: 150,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      hintText: 'اكتب رسالة…',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: .1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        key: const ValueKey('chat-send'),
                        onPressed: _send,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('chat-open'),
                    onTap: () => setState(() => _typing = true),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: AlignmentDirectional.centerStart,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        room.chatMuted && !host
                            ? 'الدردشة مقفلة'
                            : 'اكتب رسالة…',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          _round(
            'btn-speaker',
            Icon(
              svc.speakerOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: svc.speakerOn ? Colors.white : const Color(0xFFFF7A7A),
            ),
            () {
              svc.toggleSpeaker();
              voiceToast(
                context,
                svc.speakerOn
                    ? 'تم تشغيل صوت الغرفة'
                    : 'تم كتم صوت الغرفة عندك',
              );
            },
          ),
          const SizedBox(width: 6),
          _round(
            'btn-emoji',
            const Icon(Icons.emoji_emotions_rounded, color: Color(0xFFFFD66B)),
            () => showEmojiSheet(context, room),
          ),
          const SizedBox(width: 6),
          if (host) ...[
            _round(
              'btn-requests',
              const Icon(Icons.front_hand_rounded, color: Colors.white),
              () => showRequestsSheet(context, room),
              badge: room.requests.length,
            ),
            const SizedBox(width: 6),
          ],
          if (onMic)
            _round(
              'btn-mic',
              Icon(
                svc.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: Colors.white,
              ),
              mutedByHost
                  ? () => voiceToast(context, 'المضيف كتم مايكك')
                  : () => svc.toggleMic(room),
              colors: svc.micOn
                  ? const [Color(0xFF2EE59D), Color(0xFF14955E)]
                  : const [Color(0xFF6B5B95), Color(0xFF4B3B75)],
            )
          else
            _round(
              'btn-hand',
              const Icon(Icons.mic_external_on_rounded, color: Colors.white),
              _raiseHand,
              colors: const [Color(0xFF8E6CFF), Color(0xFF5B3BD6)],
            ),
          const SizedBox(width: 6),
          // عجلة السماء بإطار أصغر وأنت داخل الغرفة
          _round(
            'btn-sky-wheel',
            artImage('sw_crown', 34, fallback: Icons.attractions_rounded),
            _openSkyWheel,
            colors: const [Color(0xFF7CC8FF), Color(0xFF5B49C9)],
          ),
          const SizedBox(width: 6),
          _round(
            'btn-gift',
            artImage('gift_box', 34, fallback: Icons.card_giftcard_rounded),
            () => _gift(),
            colors: const [Color(0xFFFF7AB6), Color(0xFFFF4D9D)],
          ),
        ],
      ),
    );
  }

  /// دخولية مستخدم: المركبة تعبر الشاشة مع شريط اسمه.
  Widget _entryOverlay(VoiceUser u) {
    final w = MediaQuery.sizeOf(context).width;
    return Positioned(
      left: 0,
      right: 0,
      top: MediaQuery.sizeOf(context).height * .28,
      child: IgnorePointer(
        key: const ValueKey('entry-fx'),
        child: SizedBox(
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 6,
                child:
                    Container(
                          padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xEEFFC23D),
                                Color(0xEEFF4D9D),
                                Color(0xEE8E6CFF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x88FF4D9D),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PlayerAvatar(
                                index: u.avatar,
                                size: 30,
                                ring: false,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${u.name} دخل بـ${entranceTitle(u.entrance!)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate(key: ValueKey('eb$_entryKey'))
                        .fadeIn(duration: 300.ms)
                        .scaleXY(begin: .6, end: 1, curve: Curves.easeOutBack)
                        .then(delay: 2200.ms)
                        .fadeOut(),
              ),
              Positioned(
                top: 0,
                child: artImage(entranceArt(u.entrance!), 150)
                    .animate(key: ValueKey('ev$_entryKey'))
                    // تدخل من اليسار وتقف في المنتصف ثم تخرج يميناً
                    .moveX(
                      begin: -w,
                      end: 0,
                      duration: 900.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .then(delay: 1300.ms)
                    .moveX(
                      begin: 0,
                      end: w,
                      duration: 800.ms,
                      curve: Curves.easeInCubic,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _giftOverlay(VoiceMessage m) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black26,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // الهدية نفسها ترسم في _flight وتطير للمستلم
              const SizedBox(height: 170),
              Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4D9D), Color(0xFF8E6CFF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${m.user!.name} ${m.text}${m.count > 1 ? '' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  )
                  .animate(key: ValueKey('t$_giftKey'))
                  .fadeIn()
                  .slideY(begin: .5, end: 0)
                  .then(delay: 1800.ms)
                  .fadeOut(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Flight {
  _Flight(this.id, this.art, this.from, this.to, this.delay);
  final int id;
  final String art;
  final Offset from;
  final Offset to;
  final int delay;
}

extension on _VoiceRoomScreenState {
  Widget _flight(_Flight f) {
    const s = 130.0;
    return Positioned(
      key: ValueKey('flight-${f.id}'),
      left: f.from.dx - s / 2,
      top: f.from.dy - s / 2,
      width: s,
      height: s,
      child: IgnorePointer(
        child: artImage(f.art, s, fallback: Icons.card_giftcard_rounded)
            .animate(delay: f.delay.ms)
            .fadeIn(duration: 120.ms)
            .scale(
              begin: const Offset(.2, .2),
              end: const Offset(1.15, 1.15),
              duration: 550.ms,
              curve: Curves.elasticOut,
            )
            .then(delay: 350.ms)
            .move(
              begin: Offset.zero,
              end: f.to - f.from,
              duration: 750.ms,
              curve: Curves.easeInCubic,
            )
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(.28, .28),
              duration: 750.ms,
              curve: Curves.easeIn,
            )
            .then()
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.6, 1.6),
              duration: 220.ms,
            )
            .fadeOut(duration: 220.ms),
      ),
    );
  }
}

/// يدخل غرفة صوتية مع التحقق من السماح بالدخول.
Future<void> openVoiceRoom(BuildContext context, VoiceRoom room) async {
  final svc = VoiceService.instance;
  final mini = svc.minimized;
  if (mini == room) {
    // نفس الغرفة المصغّرة: نرجع لها بدون دخول جديد
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VoiceRoomScreen(room: room)));
    return;
  }
  // غرفة واحدة فقط في نفس الوقت: دخول غرفة أخرى يخرجك من المصغّرة
  if (mini != null) svc.leave(mini);
  final err = svc.join(room);
  if (err != null) {
    voiceToast(context, err);
    return;
  }
  if (Account.instance.profile == null) return;
  await Navigator.of(context).push(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) => VoiceRoomScreen(room: room),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: .96, end: 1.0).animate(a),
          child: child,
        ),
      ),
    ),
  );
}
