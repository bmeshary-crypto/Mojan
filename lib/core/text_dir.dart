import 'package:flutter/widgets.dart';

final _rtl = RegExp(r'[֐-ࣿיִ-﷿ﹰ-﻿]');
final _ltr = RegExp(r'[A-Za-zÀ-ɏ]');

/// اتجاه النص على حسب أول حرف قوي فيه (العربي يمين لشمال). الفاضي يعتبر عربي.
TextDirection textDirOf(String s) {
  for (final ch in s.characters) {
    if (_rtl.hasMatch(ch)) return TextDirection.rtl;
    if (_ltr.hasMatch(ch)) return TextDirection.ltr;
  }
  return TextDirection.rtl;
}
