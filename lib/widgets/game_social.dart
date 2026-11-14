import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/account/account.dart';
import '../core/firebase/cloud.dart';
import '../core/gifts/diamonds.dart';
import '../core/theme.dart';

/// إيموجي وهدايا رمزية داخل الألعاب.
class GameGift {
  const GameGift(this.emoji, this.title, this.price);
  final String emoji;
  final String title;
  final int price;
  bool get isEmoji => price <= 5;
}

const gameEmojis = [
  GameGift('😂', 'ضحك', 5),
  GameGift('😍', 'حب', 5),
  GameGift('👏', 'تصفيق', 5),
  GameGift('🔥', 'نار', 5),
  GameGift('😡', 'زعل', 5),
  GameGift('😭', 'بكاء', 5),
  GameGift('🎉', 'احتفال', 5),
  GameGift('👍', 'تمام', 5),
];

const gameGifts = [
  GameGift('🌹', 'وردة', 10),
  GameGift('❤️', 'قلب', 30),
  GameGift('🍫', 'شوكولاتة', 50),
  GameGift('💐', 'باقة ورد', 100),
  GameGift('👑', 'تاج', 200),
  GameGift('🚀', 'صاروخ', 500),
];

GameGift? gameGiftByEmoji(String e) => [...gameEmojis, ...gameGifts].where((g) => g.emoji == e).firstOrNull;

/// يختار إيموجي أو هدية لشخص. يرجع ما اختاره بعد خصم السعر، أو null.
Future<GameGift?> pickGameGift(BuildContext context, String toName) async {
  final g = await showModalBottomSheet<GameGift>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      Widget tile(GameGift g) => GestureDetector(
            key: ValueKey('gg-${g.title}'),
            onTap: () => Navigator.pop(ctx, g),
            child: Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(16)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(g.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 2),
                Text('${g.price} 🪙', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.gold)),
              ]),
            ),
          );
      return SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('أرسل لـ$toName', style: AppTheme.display.copyWith(fontSize: 20)),
              const SizedBox(height: 4),
              Text('رصيدك ${Account.instance.profile?.coins ?? 0} 🪙  •  اللي يستلم الهدية ياخذ 30% منها ماسات 💎',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 10),
              const Text('إيموجي', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final g in gameEmojis) tile(g)]),
              const SizedBox(height: 12),
              const Text('هدايا', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final g in gameGifts) tile(g)]),
            ]),
          ),
        ),
      );
    },
  );
  if (g == null) return null;
  if (!Account.instance.spend(g.price, reason: 'أرسل هدية داخل لعبة', kind: 'gift')) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عملاتك ما تكفي'), behavior: SnackBarBehavior.floating));
    }
    return null;
  }
  return g;
}

/// إيموجي أو هدية تطير فوق صورة اللاعب لثواني.
class GameFxBubble extends StatelessWidget {
  const GameFxBubble({super.key, required this.emoji, this.from});
  final String emoji;
  final String? from;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 34))
              .animate()
              .scaleXY(begin: .2, end: 1.25, duration: 320.ms, curve: Curves.easeOutBack)
              .then()
              .scaleXY(begin: 1.25, end: 1, duration: 200.ms)
              .then(delay: 1400.ms)
              .moveY(begin: 0, end: -24, duration: 500.ms)
              .fadeOut(duration: 500.ms),
          if (from != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Text('من $from', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)),
            ).animate().fadeIn().then(delay: 1700.ms).fadeOut(),
        ]),
      );
}

/// قناة الإيموجي والهدايا في المباريات الأونلاين: matches/{id}/fx.
class GameFxChannel {
  GameFxChannel(this.matchId);
  final String matchId;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  final _started = DateTime.now();

  Future<void> send({required String to, String? toUid, required GameGift g}) async {
    final me = Cloud.instance.uid;
    if (me == null) return;
    try {
      await _db.collection('matches').doc(matchId).collection('fx').add({
        'by': me,
        'name': Account.instance.profile?.name ?? 'لاعب',
        'to': to,
        'e': g.emoji,
        'price': g.price,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('fx: $e');
    }
    if (toUid != null) unawaited(Diamonds.instance.send(to: toUid, coins: g.price, gift: g.emoji, where: 'game'));
  }

  /// الجديد فقط (بعد دخولي)، وبدون اللي أرسلته أنا (يظهر عندي فوراً).
  Stream<({String to, String emoji, String from})> stream() => _db
      .collection('matches')
      .doc(matchId)
      .collection('fx')
      .orderBy('at', descending: true)
      .limit(10)
      .snapshots()
      .expand((s) => s.docChanges)
      .where((c) => c.type == DocumentChangeType.added)
      .map((c) => c.doc.data() ?? {})
      .where((d) {
        final at = (d['at'] as Timestamp?)?.toDate();
        return d['by'] != Cloud.instance.uid && (at == null || at.isAfter(_started.subtract(const Duration(seconds: 5))));
      })
      .map((d) => (to: '${d['to']}', emoji: '${d['e']}', from: '${d['name'] ?? 'لاعب'}'));
}

