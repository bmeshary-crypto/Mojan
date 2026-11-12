import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/shop.dart';
import '../../core/theme.dart';
import '../../core/voice/voice.dart';
import '../../widgets/account_widgets.dart';
export '../../core/num_format.dart';
import '../../core/num_format.dart';

/// اختصار الأرقام الكبيرة: 950 ← 950، 1500 ← 1.5K، 2300000 ← 2.3M.

/// شارة قيمة الهدايا المستلمة تحت اسم الشخص.
class GiftBadge extends StatelessWidget {
  const GiftBadge(this.value, {super.key, this.small = false});
  final int value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 7, vertical: 1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xCCFF4D9D), Color(0xCC8E6CFF)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: .8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/gift_box.webp',
            width: small ? 11 : 13,
            height: small ? 11 : 13,
            errorBuilder: (_, _, _) => Icon(
              Icons.card_giftcard_rounded,
              size: small ? 10 : 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            fmtK(value),
            style: TextStyle(
              fontSize: small ? 9.5 : 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

Widget artImage(
  String name,
  double size, {
  IconData fallback = Icons.mic_rounded,
}) => Image.asset(
  name.startsWith('assets/') ? name : 'assets/images/$name.webp',
  width: size,
  height: size,
  fit: BoxFit.contain,
  filterQuality: FilterQuality.medium,
  errorBuilder: (_, _, _) =>
      Icon(fallback, size: size * .7, color: Colors.white70),
);

/// صورة المتحدث مع إطاره وحلقة الصوت.
class VoiceAvatar extends StatelessWidget {
  const VoiceAvatar({
    super.key,
    required this.user,
    required this.size,
    this.speaking = false,
    this.muted = false,
  });
  final VoiceUser user;
  final double size;
  final bool speaking;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final shopFrame = user.frameArt;
    final frame = shopFrame != null
        ? 'fr_$shopFrame'
        : switch (user.frame) {
            SeatFrame.host => 'frame_host',
            SeatFrame.party => 'frame_party',
            SeatFrame.vip => 'frame_vip',
            SeatFrame.none => null,
          };
    // إطارات المتجر مقصوصة بنفس المقاس (الحلقة في المنتصف تماماً)،
    // والإطار المذهب للمضيف أعرض بسبب الأجنحة.
    final frameScale = shopFrame != null
        ? 1.8
        : (user.frame == SeatFrame.host ? 1.75 : 1.42);
    final lift = shopFrame == null && user.frame == SeatFrame.host
        ? size * .1
        : 0.0;
    final ripple = speaking && !muted;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (ripple)
            Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF7CF5FF),
                      width: 2.5,
                    ),
                  ),
                )
                .animate(onPlay: (c) => c.repeat())
                .scaleXY(begin: 1, end: 1.35, duration: 900.ms)
                .fadeOut(duration: 900.ms),
          PlayerAvatar(
            index: user.avatar,
            size: size * (frame == null ? 1 : .86),
            ring: frame == null,
          ),
          if (frame != null)
            Positioned(
              left: -size * (frameScale - 1) / 2,
              top: -size * (frameScale - 1) / 2 - lift,
              width: size * frameScale,
              height: size * frameScale,
              child: IgnorePointer(child: artImage(frame, size * frameScale)),
            ),
          if (muted)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5A5F),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic_off_rounded,
                  size: size * .2,
                  color: Colors.white,
                ),
              ),
            ),
          if (user.reaction != null)
            Positioned(
              top: -size * .35,
              child:
                  Text(user.reaction!, style: TextStyle(fontSize: size * .45))
                      .animate(key: ValueKey('${user.id}${user.reaction}'))
                      .moveY(
                        begin: size * .3,
                        end: 0,
                        duration: 500.ms,
                        curve: Curves.easeOutBack,
                      )
                      .fadeIn(),
            ),
        ],
      ),
    );
  }
}

/// مقعد مايك.
class SeatTile extends StatelessWidget {
  const SeatTile({
    super.key,
    required this.seat,
    required this.size,
    required this.onTap,
    this.party = false,
    this.gifts = 0,
    this.chair,
  });

  /// شكل الكرسي تحت المايك (من متجر المضيف).
  final String? chair;

  /// قيمة الهدايا التي استلمها الجالس في هذه الغرفة.
  final int gifts;
  final VoiceSeat seat;
  final double size;
  final VoidCallback onTap;
  final bool party;

  @override
  Widget build(BuildContext context) {
    final u = seat.user;
    return GestureDetector(
      key: ValueKey('seat-${seat.index}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _onChair(u != null
            ? VoiceAvatar(
              user: u,
              size: size,
              speaking: u.isMe ? VoiceService.instance.micOn : u.speaking,
              muted: seat.muted,
            )
          : Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chair != null
                    ? const Color(0xFF1E1446).withValues(alpha: .4)
                    : Colors.white.withValues(alpha: party ? .14 : .07),
                border: Border.all(
                  color: party
                      ? Colors.white.withValues(alpha: .35)
                      : const Color(0xFF6C5CE7).withValues(alpha: .6),
                  width: 1.5,
                ),
                boxShadow: party
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF6C5CE7).withValues(alpha: .25),
                          blurRadius: 10,
                        ),
                      ],
              ),
              child: Icon(
                seat.locked ? Icons.lock_rounded : Icons.mic_rounded,
                color: seat.locked ? const Color(0xFFFFC23D) : Colors.white70,
                size: size * .42,
              ),
            )),
          const SizedBox(height: 4),
          SizedBox(
            width: size + 14,
            child: Text(
              u?.name ?? (party ? 'NO.${seat.index + 1}' : '${seat.index + 1}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: u == null
                    ? AppColors.textMuted
                    : (u.vip ? AppColors.gold : Colors.white),
              ),
            ),
          ),
          if (u != null) ...[
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: GiftBadge(
                gifts,
                small: true,
                key: ValueKey('gifts-${seat.index}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension on SeatTile {
  /// المايك جالس على الكرسي: الكرسي خلفه وأسفل منه قليلاً.
  Widget _onChair(Widget seatCircle) {
    final c = chair;
    if (c == null) return seatCircle;
    final w = size * 1.5;
    // الكرسي خلف المايك: ظهره خلف الدائرة، والمقعدة والأرجل تحتها
    return SizedBox(
      width: w,
      height: size * 1.55,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            child: Image.asset(
              chairAsset(c),
              key: ValueKey('chair-${seat.index}'),
              width: w,
              height: w,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          Positioned(top: size * .16, child: seatCircle),
        ],
      ),
    );
  }
}

/// مؤشر "مباشر" بأعمدة صوت متحركة.
class LiveBars extends StatelessWidget {
  const LiveBars({super.key, this.color = const Color(0xFFFF4D9D)});
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (var i = 0; i < 3; i++)
        Container(
              width: 3,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            )
            .animate(
              onPlay: (c) => c.repeat(reverse: true),
              delay: (i * 150).ms,
            )
            .scaleY(
              begin: .3,
              end: 1,
              alignment: Alignment.bottomCenter,
              duration: 400.ms,
            ),
    ],
  );
}

/// شارة صغيرة (عدد المتواجدين، الشعبية...).
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.text,
    this.color = Colors.white70,
  });
  final Widget icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      const SizedBox(width: 3),
      Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    ],
  );
}
