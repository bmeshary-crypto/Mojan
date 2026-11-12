import 'dart:js_interop';

import 'package:web/web.dart' as web;

String siteUrl() {
  final l = web.window.location;
  return '${l.origin}${l.pathname}';
}

void clearJoinParam() {
  try {
    web.window.history.replaceState(null, '', siteUrl());
  } catch (_) {}
}

Future<bool> shareNative(String text) async {
  try {
    final nav = web.window.navigator;
    final data = web.ShareData(text: text);
    if (!nav.canShare(data)) return false;
    await nav.share(data).toDart;
    return true;
  } catch (_) {
    return false;
  }
}

void openExternal(String url) => web.window.open(url, '_blank');
