import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/games/arena/arena_engine.dart';
import 'package:mojan/games/arena/arena_screen.dart';

void main() {
  testWidgets('arena match rotates itself on a portrait phone', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    t.view.physicalSize = const Size(400, 860);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(const MaterialApp(home: ArenaMatchScreen(difficulty: Difficulty.easy, skin: 0, seed: 7)));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(RotatedBox), findsWidgets);
    await t.pump(const Duration(seconds: 11));
    await t.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
    t.view.reset();
  });

  testWidgets('arena match plays in landscape', (t) async {
    t.view.physicalSize = const Size(860, 400);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(const MaterialApp(home: ArenaMatchScreen(difficulty: Difficulty.easy, skin: 0, seed: 7)));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.tapAt(const Offset(660, 200));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(seconds: 9));
    for (var i = 0; i < 400; i++) {
      await t.pump(const Duration(milliseconds: 33));
    }
    await t.pumpWidget(const SizedBox());
    t.view.reset();
  });
}
