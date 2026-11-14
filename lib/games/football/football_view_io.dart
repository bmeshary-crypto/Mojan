import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// يعرض اللعبة في WebView ويستقبل رسائلها عبر قناة FootballChannel.
class FootballView extends StatefulWidget {
  const FootballView({super.key, required this.config, required this.onMessage});

  final String config;
  final void Function(Map<String, dynamic> msg) onMessage;

  @override
  State<FootballView> createState() => _FootballViewState();
}

class _FootballViewState extends State<FootballView> {
  late final WebViewController _c;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF070B18))
      ..addJavaScriptChannel('FootballChannel', onMessageReceived: (m) {
        try {
          final d = jsonDecode(m.message);
          if (d is Map<String, dynamic>) widget.onMessage(d);
        } catch (_) {}
      });
    _load();
  }

  Future<String> _crest(String id) async {
    try {
      final b = await rootBundle.load('assets/images/fc_$id.webp');
      return 'data:image/webp;base64,${base64Encode(b.buffer.asUint8List())}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _load() async {
    var html = await rootBundle.loadString('assets/football/index.html');
    final q = Uri.splitQueryString(widget.config);
    final crests = {'home': await _crest(q['home'] ?? ''), 'away': await _crest(q['away'] ?? '')};
    // نحقن الإعدادات قبل سكربت اللعبة
    final inject = '<script>window.MOJAN_FB_CFG=${jsonEncode(widget.config)};'
        'window.MOJAN_FB_CRESTS=${jsonEncode(crests)};</script>';
    html = html.replaceFirst('<head>', '<head>$inject');
    await _c.loadHtmlString(
      html,
      baseUrl: defaultTargetPlatform == TargetPlatform.android ? 'file:///android_asset/flutter_assets/assets/football/' : null,
    );
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) => _loaded ? WebViewWidget(controller: _c) : const SizedBox.expand();
}
