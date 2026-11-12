import 'package:flutter/foundation.dart';

class UpdateCheck {
  UpdateCheck._();
  static final instance = UpdateCheck._();
  final available = ValueNotifier<bool>(false);
  void start() {}
  void reload() {}
}
