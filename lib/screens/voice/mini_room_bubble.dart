import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/voice/voice.dart';
import '../../widgets/account_widgets.dart';
import 'voice_room_screen.dart';
import 'voice_widgets.dart';

/// مفتاح الملاحة العام حتى تفتح الفقاعة الغرفة من أي شاشة.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// فقاعة عائمة للغرفة المصغّرة: اضغط للرجوع، أو × للخروج.
class MiniRoomBubble extends StatefulWidget {
  const MiniRoomBubble({super.key});

  @override
  State<MiniRoomBubble> createState() => _MiniRoomBubbleState();
}

class _MiniRoomBubbleState extends State<MiniRoomBubble> {
  Offset? _pos;

  @override
  Widget build(BuildContext context) {
    final svc = VoiceService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final room = svc.minimized;
        if (room == null) return const SizedBox.shrink();
        final size = MediaQuery.sizeOf(context);
        const d = 68.0;
        final pos = _pos ?? Offset(14, size.height - 200);
        final clamped = Offset(
          pos.dx.clamp(6, size.width - d - 6),
          pos.dy.clamp(40, size.height - d - 90),
        );
        return Positioned(
          left: clamped.dx,
          top: clamped.dy,
          child: Material(
            type: MaterialType.transparency,
            child: GestureDetector(
              key: const ValueKey('mini-room'),
              onPanUpdate: (e) => setState(() => _pos = clamped + e.delta),
              onTap: () => appNavigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => VoiceRoomScreen(room: room)),
              ),
              child: SizedBox(
                width: d + 10,
                height: d + 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                          width: d,
                          height: d,
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Color(0xFFFF4D9D),
                                Color(0xFF8E6CFF),
                                Color(0xFF7CC8FF),
                                Color(0xFFFF4D9D),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: PlayerAvatar(
                            index: room.host.avatar,
                            size: d - 6,
                            ring: false,
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 1, end: 1.06, duration: 900.ms),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 84),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1446),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const LiveBars(),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                room.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: -2,
                      child: GestureDetector(
                        key: const ValueKey('mini-room-close'),
                        onTap: () => svc.leave(room),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFF5A5F),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
