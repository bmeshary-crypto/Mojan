import 'package:flutter/material.dart';

/// طرق اللعب التي قد تدعمها اللعبة.
enum PlayMode {
  vsComputer('ضد الكمبيوتر', Icons.smart_toy_rounded),
  local('على نفس الجهاز', Icons.groups_rounded),
  online('أونلاين', Icons.public_rounded),
  rooms('غرف', Icons.meeting_room_rounded),
  live('جولات مباشرة', Icons.bolt_rounded),
  solo('العب الآن', Icons.play_arrow_rounded);

  const PlayMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// العقد الذي تلتزم به كل لعبة داخل MOJAN.
///
/// لإضافة لعبة جديدة: أنشئ مجلداً تحت lib/games، عرّف GameModule،
/// ثم أضفه إلى [GameRegistry.games]. الواجهة الرئيسية تعرضها تلقائياً.
class GameModule {
  const GameModule({
    required this.id,
    required this.title,
    required this.tagline,
    required this.colors,
    required this.players,
    required this.modes,
    required this.iconBuilder,
    required this.screenBuilder,
  });

  final String id;
  final String title;
  final String tagline;

  /// تدرج لون البطاقة (من الأعلى للأسفل).
  final List<Color> colors;

  /// نص عدد اللاعبين، مثل "2-4".
  final String players;
  final List<PlayMode> modes;

  /// رسمة اللعبة على بطاقتها.
  final WidgetBuilder iconBuilder;

  /// شاشة اللعبة بعد اختيار طريقة اللعب.
  final Widget Function(BuildContext context, PlayMode mode) screenBuilder;
}
