import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/game_module.dart';
import '../core/theme.dart';
import '../games/game_registry.dart';
import '../widgets/account_widgets.dart';
import '../widgets/bouncy_button.dart';
import '../core/voice/voice.dart';
import 'voice/voice_home.dart';
import 'voice/voice_room_screen.dart';

/// تبويب "الغرف": الانضمام برمز، إنشاء غرفة لكل لعبة، والغرف العامة.
class RoomsTab extends StatefulWidget {
  const RoomsTab({super.key});

  @override
  State<RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends State<RoomsTab> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _join() {
    if (_code.text.length != 6) return;
    VoiceService.instance.ensureDemo();
    final room = VoiceService.instance.byId(_code.text);
    if (room != null) {
      openVoiceRoom(context, room);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(duration: Duration(seconds: 2), 
          behavior: SnackBarBehavior.floating,
          content: Text(
            'الانضمام لغرفة صديق برمزها يعمل بعد تشغيل السيرفر',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  /// أفضل طريقة لعب جماعي متاحة الآن لكل لعبة.
  static PlayMode _roomMode(GameModule g) {
    if (g.modes.contains(PlayMode.rooms)) return PlayMode.rooms;
    if (g.modes.contains(PlayMode.local)) return PlayMode.local;
    return g.modes.first;
  }

  static String _modeHint(PlayMode m) => switch (m) {
    PlayMode.rooms => 'غرفة برمز مع منافسين',
    PlayMode.local => 'مع أصحابك على نفس الجهاز',
    PlayMode.vsComputer => 'ضد الكمبيوتر',
    PlayMode.online => 'أونلاين',
    PlayMode.live => 'جولات مباشرة مع الجميع',
    PlayMode.solo => 'العب بعملاتك',
  };

  void _open(GameModule g) {
    final mode = _roomMode(g);
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, _, _) => g.screenBuilder(context, mode),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  bool _voice = true;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Text('الغرف', style: AppTheme.display.copyWith(fontSize: 30)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _seg('rooms-voice', '🎙️ صوتية', _voice, () => setState(() => _voice = true)),
              _seg('rooms-games', '🎮 ألعاب', !_voice, () => setState(() => _voice = false)),
            ]),
          ),
        ]),
      ),
      Expanded(child: _voice ? const VoiceHome() : _gamesBody(context)),
    ]);
  }

  Widget _seg(String key, String label, bool on, VoidCallback onTap) => GestureDetector(
        key: ValueKey(key),
        onTap: onTap,
        child: AnimatedContainer(
          duration: 250.ms,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: on ? const LinearGradient(colors: [Color(0xFF8E6CFF), Color(0xFFFF4D9D)]) : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: on ? Colors.white : AppColors.textMuted)),
        ),
      );

  Widget _gamesBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB13D), Color(0xFFFF7A1A)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text(
                'انضم لغرفة صديق',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 10),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('room-code'),
                        controller: _code,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                          color: AppColors.bgTop,
                        ),
                        decoration: InputDecoration(
                          hintText: '000000',
                          hintStyle: TextStyle(
                            color: AppColors.bgTop.withValues(alpha: .25),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _join(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      key: const ValueKey('room-join'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.bgTop,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                      onPressed: _code.text.length == 6 ? _join : null,
                      child: const Text(
                        'ادخل',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: .1, end: 0),
        const SizedBox(height: 22),
        Text('أنشئ غرفة', style: AppTheme.display.copyWith(fontSize: 22)),
        const SizedBox(height: 10),
        for (final (i, g) in GameRegistry.games.indexed)
          Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BouncyButton(
                  tilt: false,
                  onTap: () => _open(g),
                  child: Container(
                    key: ValueKey('room-${g.id}'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          g.colors[1].withValues(alpha: .55),
                          g.colors[2].withValues(alpha: .35),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .15),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: g.iconBuilder(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                _modeHint(_roomMode(g)),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'إنشاء',
                            style: TextStyle(
                              color: g.colors[2],
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: (100 + i * 70).ms)
              .slideX(begin: .15, end: 0),
        const SizedBox(height: 18),
        Text('الغرف العامة', style: AppTheme.display.copyWith(fontSize: 22)),
        const SizedBox(height: 10),
        const GlassCard(
          child: Column(
            children: [
              Text('🌍', style: TextStyle(fontSize: 40)),
              SizedBox(height: 6),
              Text(
                'لا توجد غرف عامة الآن',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'الغرف العامة مع لاعبين من كل مكان تظهر هنا بعد تشغيل السيرفر',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
