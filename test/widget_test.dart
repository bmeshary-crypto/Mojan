import 'package:flutter_test/flutter_test.dart';
import 'package:mojan/games/game_registry.dart';

void main() {
  test('registry has all games', () {
    expect(GameRegistry.games.map((g) => g.id), ['ludo', 'seeko', 'quiz', 'truth_dare', 'arena', 'sky_wheel', 'fruits', 'treasure', 'pegs', 'rocket', 'star_league', 'lucky_slots', 'sultan', 'blocks']);
  });
}
