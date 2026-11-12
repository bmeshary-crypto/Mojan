import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/account/account.dart';
import 'package:mojan/core/theme.dart';
import 'package:mojan/games/blocks/blocks_engine.dart';
import 'package:mojan/games/blocks/blocks_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('placing pieces clears full rows and columns and scores', () {
    final g = BlocksGame(random: Random(1));
    // املأ الصف الأول إلا خانة
    for (var c = 0; c < 7; c++) {
      g.board[0][c] = 0;
    }
    g.tray[0] = const BlockPiece([(0, 0)], 2);
    expect(g.canPlace(g.tray[0]!, 0, 7), isTrue);
    expect(g.canPlace(g.tray[0]!, 0, 6), isFalse);
    expect(g.canPlace(const BlockPiece([(0, 0), (0, 1)], 0), 3, 7), isFalse);
    final r = g.place(0, 0, 7)!;
    expect(r.rows, [0]);
    expect(g.board[0].every((v) => v == -1), isTrue);
    expect(g.score, 1 + 10 + 300); // كانت اللوحة فاضية بعد المسح
    expect(g.tray[0], isNull);
    // صف وعمود مع بعض
    for (var i = 0; i < 8; i++) {
      if (i != 4) {
        g.board[4][i] = 1;
        g.board[i][4] = 1;
      }
    }
    g.tray[1] = const BlockPiece([(0, 0)], 3);
    final r2 = g.place(1, 4, 4)!;
    expect(r2.lines, 2);
    expect(g.combo, 2);
    expect(r2.points, 1 + 40 + 20 + 300);
    // كل القطع انستخدمت = ثلاث جديدة
    g.place(2, 7, 7) ?? g.place(2, 0, 0);
    expect(g.tray.whereType<BlockPiece>().length, 3);
  });

  test('modes: easy undo, pro boxes and powers, rotation', () {
    final e = BlocksGame(random: Random(4), mode: BlocksMode.easy);
    expect(e.tray.every((p) => p!.cells.length <= 4), isTrue);
    final p0 = e.tray[0]!;
    e.place(0, 0, 0);
    expect(e.canUndo, isTrue);
    e.undo();
    expect(e.tray[0], p0);
    expect(e.undos, 2);
    final pro = BlocksGame(random: Random(5), mode: BlocksMode.pro);
    expect(pro.size, 9);
    for (var i = 0; i < 8; i++) {
      pro.board[i ~/ 3 + 3][i % 3 + 3] = 0; // المربع الأوسط إلا خانة
    }
    pro.tray[0] = const BlockPiece([(0, 0)], 1);
    final r = pro.place(0, 5, 5)!;
    expect(r.boxes, [4]);
    final bombs = pro.powers[BlockPower.bomb]!;
    expect(pro.bomb(0, 0), isEmpty);
    expect(pro.powers[BlockPower.bomb], bombs - 1);
    const l = BlockPiece([(0, 0), (1, 0), (2, 0), (2, 1)], 0);
    expect(l.rotated().rows, 2);
    expect(l.rotated().cols, 3);
    expect(l.rotated().rotated().rotated().rotated().cells.toSet(), l.cells.toSet());
  });

  test('game is over when nothing fits', () {
    final g = BlocksGame(random: Random(2));
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        g.board[r][c] = (r + c).isEven ? 0 : -1;
      }
    }
    g.tray = [const BlockPiece([(0, 0), (0, 1)], 0), const BlockPiece([(0, 0), (1, 0)], 0), null];
    expect(g.over, isTrue);
    g.tray[2] = const BlockPiece([(0, 0)], 1);
    expect(g.over, isFalse);
  });

  testWidgets('drag a piece onto the board', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Account.instance.reset();
    await Account.instance.signIn(method: AuthMethod.guest, name: 'موكا');
    tester.view.physicalSize = const Size(420 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: BlocksScreen(random: Random(3), mode: BlocksMode.classic)));
    await tester.pump(const Duration(milliseconds: 300));
    final piece = find.byKey(const ValueKey('blocks-piece-0'));
    final board = tester.getRect(find.byType(AspectRatio).first);
    final from = tester.getCenter(piece);
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 50));
    // نسحب الإصبع لنص اللوحة (القطعة تطلع فوق الإصبع)
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, board.center + const Offset(0, 120), i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(int.parse(tester.widget<Text>(find.byKey(const ValueKey('blocks-score'))).data!), greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
