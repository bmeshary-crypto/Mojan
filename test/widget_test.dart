import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/games/game_registry.dart';

void main() {
  test('registry has the four launch games', () {
    expect(GameRegistry.games.map((g) => g.id), ['ludo', 'seeko', 'quiz', 'truth_dare']);
  });
}
