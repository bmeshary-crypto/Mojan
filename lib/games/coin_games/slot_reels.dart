import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/sfx.dart';

/// يتحكم في دوران البكرات من شاشة اللعبة.
class SlotReelsController {
  _SlotReelsState? _state;

  /// يلف البكرات وينتهي على [finalCols] (لكل بكرة: الرموز من فوق لتحت).
  /// [fillers] رموز عشوائية تمر أثناء الدوران.
  Future<void> spin(List<List<String>> finalCols, {required String Function() filler, List<int>? stopMs}) =>
      _state?._spin(finalCols, filler, stopMs) ?? Future.value();
}

/// بكرات ماكينة: كل بكرة شريط رموز يتحرك عمودياً ويقف على النتيجة.
class SlotReels extends StatefulWidget {
  const SlotReels({
    super.key,
    required this.initial,
    required this.rows,
    required this.symbol,
    required this.controller,
    this.highlight = const {},
    this.gap = 6,
    this.reelDecoration,
  });

  final List<List<String>> initial;
  final int rows;
  final Widget Function(String id) symbol;
  final SlotReelsController controller;

  /// خلايا رابحة (بكرة، صف) تضيء بعد التوقف.
  final Set<(int, int)> highlight;
  final double gap;
  final BoxDecoration? reelDecoration;

  @override
  State<SlotReels> createState() => _SlotReelsState();
}

class _SlotReelsState extends State<SlotReels> with SingleTickerProviderStateMixin {
  late List<List<String>> _strips = [for (final c in widget.initial) List.of(c)];
  late List<double> _pos = List.filled(widget.initial.length, 0);
  List<int> _stop = [];
  late final Ticker _ticker = createTicker(_onTick);
  Completer<void>? _done;
  final Set<int> _landed = {};

  bool get spinning => _ticker.isActive;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void didUpdateWidget(SlotReels old) {
    super.didUpdateWidget(old);
    widget.controller._state = this;
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (!(_done?.isCompleted ?? true)) _done!.complete();
    super.dispose();
  }

  Future<void> _spin(List<List<String>> finals, String Function() filler, List<int>? stopMs) {
    final n = finals.length;
    final rows = widget.rows;
    _stop = stopMs ?? [for (var i = 0; i < n; i++) 700 + i * 260];
    _strips = [
      for (var i = 0; i < n; i++)
        [
          ..._visible(i),
          for (var k = 0; k < 10 + i * 4 + (_stop[i] ~/ 120); k++) filler(),
          ...finals[i],
        ],
    ];
    _pos = List.filled(n, 0);
    _landed.clear();
    _done = Completer<void>();
    _ticker
      ..stop()
      ..start();
    setState(() {});
    assert(finals.every((c) => c.length == rows));
    return _done!.future;
  }

  List<String> _visible(int i) {
    final s = _strips[i];
    final p = _pos[i].round().clamp(0, max(0, s.length - widget.rows)).toInt();
    return s.sublist(p, min<int>(s.length, p + widget.rows));
  }

  void _onTick(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    var all = true;
    for (var i = 0; i < _strips.length; i++) {
      final end = (_strips[i].length - widget.rows).toDouble();
      final t = (ms / _stop[i]).clamp(0.0, 1.0);
      // تسارع سريع ثم تباطؤ مع ارتداد خفيف عند التوقف.
      _pos[i] = end * Curves.easeOutCubic.transform(t);
      if (t < 1) {
        all = false;
      } else if (_landed.add(i)) {
        Sfx.instance.tick();
      }
    }
    setState(() {});
    if (all) {
      _ticker.stop();
      _strips = [for (var i = 0; i < _strips.length; i++) _strips[i].sublist(_strips[i].length - widget.rows)];
      _pos = List.filled(_strips.length, 0);
      _done?.complete();
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < _strips.length; i++) ...[
        if (i > 0) SizedBox(width: widget.gap),
        Expanded(child: _reel(i)),
      ],
    ],
  );

  Widget _reel(int i) => Container(
    decoration: widget.reelDecoration,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LayoutBuilder(
        builder: (context, c) {
          final h = c.maxHeight / widget.rows;
          final s = _strips[i];
          final p = _pos[i];
          final first = p.floor();
          final moving = _ticker.isActive && !_landed.contains(i);
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (var j = first; j <= first + widget.rows && j < s.length; j++)
                Positioned(
                  key: ValueKey('reel-$i-cell-${j - first}'),
                  top: (j - p) * h,
                  left: 0,
                  right: 0,
                  height: h,
                  child: _cell(i, j - first, s[j], moving),
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _cell(int reel, int row, String id, bool moving) {
    final lit = !_ticker.isActive && widget.highlight.contains((reel, row));
    Widget child = Padding(padding: const EdgeInsets.all(3), child: widget.symbol(id));
    if (moving) child = Opacity(opacity: .75, child: child);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: lit ? Border.all(color: const Color(0xFFFFE07A), width: 3) : null,
        boxShadow: lit ? const [BoxShadow(color: Color(0xAAFFC93C), blurRadius: 14, spreadRadius: 1)] : null,
      ),
      child: child,
    );
  }
}

/// صورة رمز مع بديل نصي لو ما انحملت.
class SymbolArt extends StatelessWidget {
  const SymbolArt(this.asset, {super.key, required this.fallback});
  final String asset;
  final String fallback;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => FittedBox(child: Text(fallback, style: const TextStyle(fontSize: 40))),
  );
}
