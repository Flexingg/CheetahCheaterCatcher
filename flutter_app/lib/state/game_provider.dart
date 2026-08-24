import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../models/highlight_moment.dart';
import '../services/game_storage_service.dart';
import '../services/sound_effects_service.dart';

class GameProvider extends ChangeNotifier {
  final GameStorageService _storageService = GameStorageService();

  List<JokarzGame> _games = [];
  JokarzGame? _activeGame;
  bool _isLoading = true;

  GameProvider() {
    _loadFromStorage();
  }

  List<JokarzGame> get games => List.unmodifiable(_games);
  JokarzGame? get activeGame => _activeGame;
  bool get isLoading => _isLoading;
  bool get hasActiveGame => _activeGame != null;

  TrophyStats get trophyStats => _storageService.calculateTrophyStats(_games);

  Future<void> _loadFromStorage() async {
    _isLoading = true;
    notifyListeners();
    try {
      _games = await _storageService.loadGames();
      if (_games.isNotEmpty) {
        // Default active game to the newest uncompleted game, or newest game
        final activeCandidates = _games.where((g) => !g.isCompleted).toList();
        _activeGame = activeCandidates.isNotEmpty ? activeCandidates.first : _games.first;
      }
    } catch (e) {
      debugPrint('Error loading games from storage: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    await _storageService.saveGames(_games);
  }

  /// Create a new game night match
  Future<JokarzGame> createGame({
    required String name,
    required WinCondition winCondition,
    required List<String> playerNames,
  }) async {
    final suits = ['♠️', '♥️', '♦️', '♣️', '🃏', '👑', '⭐', '🎲'];
    final gameId = 'game_${DateTime.now().millisecondsSinceEpoch}';

    final players = <JokarzPlayer>[];
    for (int i = 0; i < playerNames.length; i++) {
      final pName = playerNames[i].trim();
      if (pName.isNotEmpty) {
        players.add(JokarzPlayer(
          id: 'player_${gameId}_$i',
          gameId: gameId,
          name: pName,
          suitIcon: suits[i % suits.length],
        ));
      }
    }

    // Add round 1 with 0 score placeholder for each player
    final initialScores = <JokarzScore>[];
    for (final p in players) {
      initialScores.add(JokarzScore(
        id: 'score_${p.id}_1',
        playerId: p.id,
        round: 1,
        score: 0,
      ));
    }

    final newGame = JokarzGame(
      id: gameId,
      name: name.trim().isEmpty ? 'Game Night Match' : name.trim(),
      winCondition: winCondition,
      date: DateTime.now(),
      players: players,
      scores: initialScores,
    );

    _games.insert(0, newGame);
    _activeGame = newGame;
    await _persist();
    SoundEffectsService.playChipClick();
    notifyListeners();
    return newGame;
  }

  void setActiveGame(String gameId) {
    final match = _games.firstWhere(
      (g) => g.id == gameId,
      orElse: () => _games.first,
    );
    _activeGame = match;
    notifyListeners();
  }

  /// Update or add a player's score for a specific round
  Future<void> setScore({
    required String playerId,
    required int round,
    required int score,
  }) async {
    if (_activeGame == null) return;

    final updatedScores = List<JokarzScore>.from(_activeGame!.scores);
    final existingIdx = updatedScores.indexWhere(
      (s) => s.playerId == playerId && s.round == round,
    );

    if (existingIdx >= 0) {
      updatedScores[existingIdx] = JokarzScore(
        id: updatedScores[existingIdx].id,
        playerId: playerId,
        round: round,
        score: score,
      );
    } else {
      updatedScores.add(JokarzScore(
        id: 'score_${playerId}_$round',
        playerId: playerId,
        round: round,
        score: score,
      ));
    }

    _activeGame = _activeGame!.copyWith(scores: updatedScores);
    _updateGameInList(_activeGame!);
    await _persist();
    SoundEffectsService.playScoreChange();
    notifyListeners();
  }

  /// Add a new blank round for all players
  Future<void> addRound() async {
    if (_activeGame == null || _activeGame!.players.isEmpty) return;

    final nextRound = _activeGame!.maxRound + 1;
    final updatedScores = List<JokarzScore>.from(_activeGame!.scores);

    for (final player in _activeGame!.players) {
      updatedScores.add(JokarzScore(
        id: 'score_${player.id}_$nextRound',
        playerId: player.id,
        round: nextRound,
        score: 0,
      ));
    }

    _activeGame = _activeGame!.copyWith(scores: updatedScores);
    _updateGameInList(_activeGame!);
    await _persist();
    SoundEffectsService.playChipClick();
    notifyListeners();
  }

  /// Delete a round and shift subsequent rounds
  Future<void> deleteRound(int roundNum) async {
    if (_activeGame == null) return;

    final filtered = _activeGame!.scores.where((s) => s.round != roundNum).map((s) {
      if (s.round > roundNum) {
        return JokarzScore(
          id: s.id,
          playerId: s.playerId,
          round: s.round - 1,
          score: s.score,
        );
      }
      return s;
    }).toList();

    _activeGame = _activeGame!.copyWith(scores: filtered);
    _updateGameInList(_activeGame!);
    await _persist();
    notifyListeners();
  }

  /// Complete game and declare winner
  Future<void> finishGame() async {
    if (_activeGame == null) return;
    _activeGame = _activeGame!.copyWith(isCompleted: true);
    _updateGameInList(_activeGame!);
    await _persist();
    SoundEffectsService.playVictoryPodium();
    notifyListeners();
  }

  /// Add a bookmarked controversy or highlight moment
  Future<void> addHighlightMoment({
    required String title,
    required String description,
    HighlightType type = HighlightType.varReview,
    int? frameIndex,
    int? roundNumber,
    String? playerName,
  }) async {
    if (_activeGame == null) return;

    final moment = HighlightMoment(
      id: 'hl_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      timestamp: DateTime.now(),
      type: type,
      frameIndex: frameIndex,
      roundNumber: roundNumber,
      playerName: playerName,
    );

    final updatedHighlights = List<HighlightMoment>.from(_activeGame!.highlights)..add(moment);
    _activeGame = _activeGame!.copyWith(highlights: updatedHighlights);
    _updateGameInList(_activeGame!);
    await _persist();
    SoundEffectsService.playChipClick();
    notifyListeners();
  }

  /// Delete a game entirely
  Future<void> deleteGame(String gameId) async {
    _games.removeWhere((g) => g.id == gameId);
    if (_activeGame?.id == gameId) {
      _activeGame = _games.isNotEmpty ? _games.first : null;
    }
    await _persist();
    notifyListeners();
  }

  void _updateGameInList(JokarzGame updated) {
    final idx = _games.indexWhere((g) => g.id == updated.id);
    if (idx >= 0) {
      _games[idx] = updated;
    }
  }
}
