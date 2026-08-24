import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';
import '../models/trophy_stats.dart';

class GameStorageService {
  static const String _keyActiveGames = 'jokarz_active_games_v1';

  /// Save all games (active and historical)
  Future<void> saveGames(List<JokarzGame> games) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = games.map((g) => g.toJson()).toList();
    await prefs.setString(_keyActiveGames, jsonEncode(jsonList));
  }

  /// Load all stored games
  Future<List<JokarzGame>> loadGames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyActiveGames);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((item) => JokarzGame.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Calculate lifetime trophy statistics across all recorded games and scores
  TrophyStats calculateTrophyStats(List<JokarzGame> games) {
    if (games.isEmpty) return TrophyStats.empty();

    final Map<String, int> playerGameCounts = {};
    final Map<String, List<int>> playerAllScores = {};
    final Map<String, int> playerZeroCounts = {};

    PlayerStatsItem? highestRound;
    PlayerStatsItem? lowestRound;
    int totalRounds = 0;

    for (final game in games) {
      for (final player in game.players) {
        playerGameCounts[player.name] = (playerGameCounts[player.name] ?? 0) + 1;
      }

      final playerMap = {for (final p in game.players) p.id: p.name};

      for (final score in game.scores) {
        totalRounds++;
        final playerName = playerMap[score.playerId] ?? 'Unknown Player';

        playerAllScores.putIfAbsent(playerName, () => []).add(score.score);

        if (score.score == 0) {
          playerZeroCounts[playerName] = (playerZeroCounts[playerName] ?? 0) + 1;
        }

        // Highest round check
        if (highestRound == null || score.score > highestRound.value) {
          highestRound = PlayerStatsItem(
            name: playerName,
            value: score.score,
            gameName: game.name,
            subtitle: 'Round ${score.round}',
          );
        }

        // Lowest round check
        if (lowestRound == null || score.score < lowestRound.value) {
          lowestRound = PlayerStatsItem(
            name: playerName,
            value: score.score,
            gameName: game.name,
            subtitle: 'Round ${score.round}',
          );
        }
      }
    }

    // Most games played leaderboard
    final mostGamesSorted = playerGameCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mostGamesList = mostGamesSorted.take(5).map((e) {
      return PlayerStatsItem(name: e.key, value: e.value, subtitle: 'games played');
    }).toList();

    // Most zeros
    PlayerStatsItem? mostZeros;
    if (playerZeroCounts.isNotEmpty) {
      final zeroSorted = playerZeroCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topZero = zeroSorted.first;
      mostZeros = PlayerStatsItem(
        name: topZero.key,
        value: topZero.value,
        subtitle: 'rounds with 0 score',
      );
    }

    // Best average scores (lowest avg)
    final List<PlayerStatsItem> bestAvgList = [];
    for (final entry in playerAllScores.entries) {
      if (entry.value.isNotEmpty) {
        final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        bestAvgList.add(PlayerStatsItem(
          name: entry.key,
          value: double.parse(avg.toStringAsFixed(1)),
          subtitle: '${entry.value.length} rounds recorded',
        ));
      }
    }
    bestAvgList.sort((a, b) => a.value.compareTo(b.value));

    return TrophyStats(
      mostGamesPlayed: mostGamesList,
      highestSingleRound: highestRound,
      lowestSingleRound: lowestRound,
      mostZeroRounds: mostZeros,
      bestAverageScores: bestAvgList.take(5).toList(),
      totalGamesCount: games.length,
      totalRoundsCount: totalRounds,
    );
  }
}

// Alias for models
typedef TrophyStats = JokarzTrophyStats;
