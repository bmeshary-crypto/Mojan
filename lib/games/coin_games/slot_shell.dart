import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/account/account.dart';
import '../../core/theme.dart';
import '../../widgets/account_widgets.dart';
import '../../widgets/game_ui.dart';
import 'coin_ui.dart';
import 'win_fx.dart';

/// هيكل ماكينات السلوت: خلفية مرسومة، شعار، الماكينة، شاشة الربح، وأزرار التحكم.
class SlotShell extends StatelessWidget {
  const SlotShell({
    super.key,
    required this.background,
    required this.logo,
    required this.title,
    required this.accent,
    required this.machine,
    required this.bet,
    required this.lastWin,
    required this.spinning,
    required this.auto,
    required this.fast,
    required this.onSpin,
    required this.onAuto,
    required this.onFast,
    required this.onHelp,
    this.onMinus,
    this.onPlus,
    this.header,
    this.hint = '',
    this.spinLabel = 'لف',
    this.keyPrefix = 'slots',
    this.inPlay = false,
    this.floating,
  });

  final String background;
  final String logo;
  final String title;
  final Color accent;
  final Widget machine;
  final Widget? header;
  final int bet;
  final int lastWin;
  final bool spinning;
  final bool auto;
  final bool fast;
  final VoidCallback? onSpin;
  final VoidCallback onAuto;
  final VoidCallback onFast;
  final VoidCallback onHelp;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final String hint;
  final String spinLabel;
  final String keyPrefix;
  final bool inPlay;

  /// رقم ربح يطير فوق الماكينة.
  final Widget? floating;

  @override
  Widget build(BuildContext context) => LeaveGuard(
    enabled: inPlay,
    message: 'عندك لفات شغالة، وإذا خرجت تضيع عليك.',
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              background,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [accent, Colors.black]),
                ),
              ),
            ),
          ),
          // تعتيم خفيف تحت عشان الأزرار تبان
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x22000000), Color(0xCC000000)],
                  stops: [0, .55, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    _topBar(context),
                    SizedBox(
                      height: 74,
                      child: Image.asset(
                        logo,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Center(child: Text(title, style: AppTheme.display.copyWith(fontSize: 32))),
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.04, duration: 1400.ms, curve: Curves.easeInOut),
                    ?header,
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 6), child: Center(child: machine)),
                          ?floating,
                        ],
                      ),
                    ),
                    _winPanel(),
                    _controls(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _topBar(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
    child: Row(
      children: [
        _roundIcon(Icons.arrow_back_rounded, () => Navigator.maybePop(context), '$keyPrefix-back'),
        const Spacer(),
        ListenableBuilder(
          listenable: Account.instance,
          builder: (context, _) => Container(
            padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFC93C), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 24),
                const SizedBox(width: 6),
                Text(fmtCoins(myCoins), key: const ValueKey('coin-balance'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFFFFE07A))),
              ],
            ),
          ),
        ),
        const Spacer(),
        _roundIcon(Icons.menu_book_rounded, onHelp, 'coin-help'),
      ],
    ),
  );

  Widget _roundIcon(IconData icon, VoidCallback onTap, String key) => GestureDetector(
    key: ValueKey(key),
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: .5),
        border: Border.all(color: const Color(0xFFFFC93C), width: 1.5),
      ),
      child: Icon(icon, color: const Color(0xFFFFE07A), size: 22),
    ),
  );

  Widget _winPanel() => Container(
    height: 54,
    margin: const EdgeInsets.fromLTRB(40, 2, 40, 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1A0A2A), Color(0xFF05020A)]),
      border: Border.all(color: const Color(0xFFFFC93C), width: 2),
      boxShadow: lastWin > 0 && !spinning ? const [BoxShadow(color: Color(0xAAFFC93C), blurRadius: 18)] : null,
    ),
    child: Center(
      child: lastWin > 0 && !spinning
          ? Row(
              key: ValueKey('$keyPrefix-win'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ربح ', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white70)),
                CountUp(value: lastWin, style: AppTheme.display.copyWith(fontSize: 28, color: const Color(0xFFFFE07A))),
              ],
            )
          : Text(
              spinning ? 'بالتوفيق... 🍀' : hint,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
            ),
    ),
  );

  Widget _controls() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _goldRound('$keyPrefix-minus', Icons.remove_rounded, onMinus),
                  Expanded(
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFC93C).withValues(alpha: .7)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('الرهان', style: TextStyle(fontSize: 10, color: Colors.white60, height: 1.1)),
                          Text(fmtCoins(bet), key: ValueKey('$keyPrefix-bet'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, height: 1.1)),
                        ],
                      ),
                    ),
                  ),
                  _goldRound('$keyPrefix-plus', Icons.add_rounded, onPlus),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _pill('$keyPrefix-fast', '⚡ سريع', fast, onFast)),
                  const SizedBox(width: 8),
                  Expanded(child: _pill('$keyPrefix-auto', auto ? '⏹ وقف' : '🔁 تلقائي', auto, onAuto)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _spinButton(),
      ],
    ),
  );

  Widget _spinButton() {
    final enabled = onSpin != null;
    Widget b = GestureDetector(
      key: ValueKey('$keyPrefix-spin'),
      onTap: onSpin,
      onLongPress: onAuto,
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(0, -.4),
            colors: enabled ? const [Color(0xFF9CFF7A), Color(0xFF2FB53A), Color(0xFF136B1C)] : const [Color(0xFF888888), Color(0xFF555555), Color(0xFF333333)],
          ),
          border: Border.all(color: const Color(0xFFFFE07A), width: 4),
          boxShadow: [
            const BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5)),
            if (enabled) const BoxShadow(color: Color(0x8844FF55), blurRadius: 22),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              spinning ? '...' : spinLabel,
              style: AppTheme.display.copyWith(fontSize: 30, color: Colors.white, shadows: const [Shadow(color: Color(0xFF0A4A10), offset: Offset(2, 3))]),
            ),
            if (!spinning) const Text('مطوّل = تلقائي', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white70)),
          ],
        ),
      ),
    );
    if (enabled && !spinning) {
      b = b.animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.05, duration: 800.ms, curve: Curves.easeInOut);
    }
    return b;
  }

  Widget _goldRound(String key, IconData icon, VoidCallback? onTap) => GestureDetector(
    key: ValueKey(key),
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: onTap != null ? const [Color(0xFFFFE07A), Color(0xFFE09A12)] : const [Color(0xFF777777), Color(0xFF444444)],
        ),
        border: Border.all(color: Colors.white54),
      ),
      child: Icon(icon, color: const Color(0xFF4A2600)),
    ),
  );

  Widget _pill(String key, String label, bool on, VoidCallback onTap) => GestureDetector(
    key: ValueKey(key),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: on ? const Color(0xFFFFC93C).withValues(alpha: .3) : Colors.black.withValues(alpha: .5),
        border: Border.all(color: on ? const Color(0xFFFFC93C) : Colors.white24, width: on ? 2 : 1),
      ),
      child: FittedBox(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
    ),
  );
}

/// إطار ماكينة فخم: حواف ذهبية ولمبات تومض حوالين البكرات.
class MachineFrame extends StatelessWidget {
  const MachineFrame({super.key, required this.child, required this.inner, this.top, this.lit = false});
  final Widget child;
  final Color inner;
  final Widget? top;
  final bool lit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF0A8), Color(0xFFE0A21A), Color(0xFF8A5206), Color(0xFFFFD86B), Color(0xFFB87A10)],
      ),
      boxShadow: [
        const BoxShadow(color: Colors.black87, blurRadius: 24, offset: Offset(0, 10)),
        if (lit) const BoxShadow(color: Color(0xCCFFC93C), blurRadius: 30, spreadRadius: 2),
      ],
    ),
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(19), color: inner),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (top != null) ...[top!, const SizedBox(height: 6)],
          _bulbs(),
          const SizedBox(height: 4),
          Flexible(child: child),
          const SizedBox(height: 4),
          _bulbs(offset: 1),
        ],
      ),
    ),
  );

  Widget _bulbs({int offset = 0}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      for (var i = 0; i < 13; i++)
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFF3B0),
            boxShadow: [BoxShadow(color: Color(0xFFFFC93C), blurRadius: 6)],
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 1, end: .25, delay: (((i + offset) % 2) * 450).ms, duration: 450.ms),
    ],
  );
}
