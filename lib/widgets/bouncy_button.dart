import 'package:flutter/material.dart';
import '../core/haptics.dart';

/// يغلف أي عنصر ليصبح زراً ينضغط للداخل ويميل قليلاً عند اللمس، مع اهتزاز خفيف.
class BouncyButton extends StatefulWidget {
  const BouncyButton({super.key, required this.child, required this.onTap, this.tilt = true});
  final Widget child;
  final VoidCallback onTap;
  final bool tilt;

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> {
  bool _down = false;
  Offset _tilt = Offset.zero;

  void _update(Offset local, Size size) {
    if (!widget.tilt) return;
    setState(() {
      _tilt = Offset(
        (local.dx / size.width - .5) * 2,
        (local.dy / size.height - .5) * 2,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight.isFinite ? c.maxHeight : c.maxWidth);
      return GestureDetector(
        onTapDown: (d) {
          Haptics.lightImpact();
          _update(d.localPosition, size);
          setState(() => _down = true);
        },
        onTapUp: (_) {
          setState(() {
            _down = false;
            _tilt = Offset.zero;
          });
          widget.onTap();
        },
        onTapCancel: () => setState(() {
          _down = false;
          _tilt = Offset.zero;
        }),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: _down ? .94 : 1),
          duration: Duration(milliseconds: _down ? 90 : 380),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          builder: (context, scale, child) {
            final m = Matrix4.identity()
              ..setEntry(3, 2, .0015)
              ..rotateX(_down ? -_tilt.dy * .12 : 0)
              ..rotateY(_down ? _tilt.dx * .12 : 0)
              ..scaleByDouble(scale, scale, 1, 1);
            return Transform(alignment: Alignment.center, transform: m, child: child);
          },
          child: widget.child,
        ),
      );
    });
  }
}
