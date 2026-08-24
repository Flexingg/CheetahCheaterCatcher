import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_night_var/main.dart';
import 'package:game_night_var/models/game_model.dart';
import 'package:game_night_var/services/dvr_replay_manager.dart';

void main() {
  testWidgets('Jokarz Plays app launches and shows role selection', (WidgetTester tester) async {
    await tester.pumpWidget(const JokarzPlaysApp());
    await tester.pumpAndSettle();

    expect(find.text('Jokarz Plays'), findsOneWidget);
    expect(find.text('Jokarz Table (VAR & Controller)'), findsOneWidget);
    expect(find.text('Jokarz Eye (Camera Streamer)'), findsOneWidget);
  });

  test('GameModel ranks players correctly for lowest win condition', () {
    final player1 = JokarzPlayer(id: 'p1', gameId: 'g1', name: 'Alice');
    final player2 = JokarzPlayer(id: 'p2', gameId: 'g1', name: 'Bob');

    final game = JokarzGame(
      id: 'g1',
      name: 'Hearts',
      winCondition: WinCondition.lowest,
      players: [player1, player2],
      scores: [
        JokarzScore(id: 's1', playerId: 'p1', round: 1, score: 20),
        JokarzScore(id: 's2', playerId: 'p2', round: 1, score: 5),
      ],
    );

    expect(game.totalScoreForPlayer('p1'), 20);
    expect(game.totalScoreForPlayer('p2'), 5);
    expect(game.rankedPlayers.first.id, 'p2'); // Bob wins with 5 points in Lowest score wins
    expect(game.getRank('p2'), 1);
    expect(game.getRank('p1'), 2);
  });

  test('GameModel ranks players correctly for highest win condition', () {
    final player1 = JokarzPlayer(id: 'p1', gameId: 'g1', name: 'Alice');
    final player2 = JokarzPlayer(id: 'p2', gameId: 'g1', name: 'Bob');

    final game = JokarzGame(
      id: 'g1',
      name: 'Poker',
      winCondition: WinCondition.highest,
      players: [player1, player2],
      scores: [
        JokarzScore(id: 's1', playerId: 'p1', round: 1, score: 50),
        JokarzScore(id: 's2', playerId: 'p2', round: 1, score: 100),
      ],
    );

    expect(game.totalScoreForPlayer('p1'), 50);
    expect(game.totalScoreForPlayer('p2'), 100);
    expect(game.rankedPlayers.first.id, 'p2'); // Bob wins with 100 points
  });

  test('DvrReplayManager handles rolling ring buffer and instant replay', () {
    final dvr = DvrReplayManager(maxCapacity: 10);
    for (int i = 0; i < 15; i++) {
      dvr.pushFrame(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]));
    }

    expect(dvr.totalBufferedFrames, 10); // Clamped to max capacity
    dvr.enterReplayMode();
    expect(dvr.isReplayActive, true);
    expect(dvr.currentScrubIndex, 9);

    dvr.stepBackward(2);
    expect(dvr.currentScrubIndex, 7);

    dvr.returnToLive();
    expect(dvr.isReplayActive, false);
  });
}
