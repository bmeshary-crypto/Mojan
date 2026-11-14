import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// يعرض اللعبة في iframe ويستقبل رسائلها (نهاية المباراة، الانسحاب...).
class FootballView extends StatefulWidget {
  const FootballView({super.key, required this.config, required this.onMessage});

  /// إعدادات المباراة بصيغة رابط: home=eagle&away=lion&diff=normal&mins=4
  final String config;
  final void Function(Map<String, dynamic> msg) onMessage;

  @override
  State<FootballView> createState() => _FootballViewState();
}

class _FootballViewState extends State<FootballView> {
  StreamSubscription<web.MessageEvent>? _sub;
  web.HTMLIFrameElement? _frame;

  @override
  void initState() {
    super.initState();
    _sub = web.window.onMessage.listen((e) {
      final data = e.data;
      if (data == null || !data.isA<JSString>()) return;
      final s = (data as JSString).toDart;
      if (!s.contains('"mojan-football"')) return;
      try {
        final m = jsonDecode(s);
        if (m is Map<String, dynamic>) widget.onMessage(m);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (Object el) {
        final f = el as web.HTMLIFrameElement;
        _frame = f;
        f.src = '${ui_web.assetManager.getAssetUrl('assets/football/index.html')}#${widget.config}';
        f.style
          ..border = '0'
          ..width = '100%'
          ..height = '100%'
          ..backgroundColor = '#070b18';
        f.allow = 'autoplay; fullscreen';
        f.onLoad.listen((_) {
          try {
            _frame?.focus();
          } catch (_) {}
        });
      },
    );
  }
}
