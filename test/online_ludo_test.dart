import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/core/online/online_games.dart';

Timestamp _t(int s) => Timestamp.fromMillisecondsSinceEpoch(1700000000000 + s * 1000);

void main() {
  test('controller is the first connected human, AI seats are skipped', () {
    final m = OnlineMatch('x', {
      'size': 4,
      'status': 'playing',
      'host': 'a',
      'seats': {
        '0': {'ai': 'ai-noura', 'name': 'نورة 🤖', 'avatar': 2},
        '1': {'uid': 'a', 'name': 'A', 'avatar': 1},
        '2': {'uid': 'b', 'name': 'B', 'avatar': 3},
        '3': {'ai': 'ai-sultan', 'name': 'سلطان 🤖', 'avatar': 5},
      },
      'seen': {'a': _t(0), 'b': _t(10)},
    });
    expect(m.full, isTrue);
    expect(m.controllerSeat, 1);
    expect(m.seatOf('b'), 2);

    // A انقطع (آخر ظهور قبل 40 ثانية من B) فيصير B هو المتحكم
    final stale = OnlineMatch('x', {
      'size': 2,
      'seats': {
        '0': {'uid': 'a', 'name': 'A', 'avatar': 1},
        '1': {'uid': 'b', 'name': 'B', 'avatar': 3},
      },
      'seen': {'a': _t(0), 'b': _t(40)},
    });
    expect(stale.controllerSeat, 1);
  });

  test('waiting room counts empty seats', () {
    final m = OnlineMatch('x', {
      'size': 4,
      'status': 'waiting',
      'host': 'a',
      'seats': {
        '0': {'uid': 'a', 'name': 'Moka', 'avatar': 1},
      },
    });
    expect(m.filled, 1);
    expect(m.full, isFalse);
    expect(m.hostName, 'Moka');
  });
}
