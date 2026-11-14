import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/games/football/football_screen.dart';
import 'package:mojan/games/football/football_team_editor.dart';

void main() {
  test('custom team config carries name, colors and player names for the 3D game', () {
    final t = MyFootballTeam.fresh()
      ..name = 'نادي موكا'
      ..names[10] = 'سالم|10';
    final q = Uri.splitQueryString(t.toConfig());
    expect(q['home'], 'custom');
    expect(q['hname'], 'نادي موكا');
    expect(q['hc1'], '#2f7bff');
    final names = q['names']!.split('|');
    expect(names.length, 11);
    expect(names[10], 'سالم 10');
  });

  test('clubs are fictional and unique', () {
    final ids = footballClubs.map((c) => c.id).toSet();
    expect(ids.length, footballClubs.length);
    expect(ids, containsAll(['eagle', 'lion', 'falcon', 'camel']));
  });
}
