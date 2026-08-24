import 'highlight_moment.dart';

enum WinCondition {
  lowest,
  highest,
}

extension WinConditionExtension on WinCondition {
  String get key => this == WinCondition.lowest ? 'lowest' : 'highest';
  String get label => this == WinCondition.lowest ? 'Lowest Score Wins' : 'Highest Score Wins';
  String get shortBadge => this == WinCondition.lowest ? 'LOW SCORE WINS' : 'HIGH SCORE WINS';

  static WinCondition fromKey(String? key) {
    if (key == 'highest') return WinCondition.highest;
    return WinCondition.lowest;
  }
}

class JokarzScore {
  final String id;
  final String playerId;
  final int round;
  final int score;
  final DateTime timestamp;

  JokarzScore({
    required this.id,
    required this.playerId,
    required this.round,
    required this.score,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'playerId': playerId,
        'round': round,
        'score': score,
        'timestamp': timestamp.toIso8601String(),
      };

  factory JokarzScore.fromJson(Map<String, dynamic> json) => JokarzScore(
        id: json['id'] as String,
        playerId: json['playerId'] as String,
        round: json['round'] as int,
        score: json['score'] as int,
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      );
}

class JokarzPlayer {
  final String id;
  final String gameId;
  final String name;
  final String suitIcon; // ♠️, ♥️, ♦️, ♣️, 🃏

  JokarzPlayer({
    required this.id,
    required this.gameId,
    required this.name,
    this.suitIcon = '♠️',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'gameId': gameId,
        'name': name,
        'suitIcon': suitIcon,
      };

  factory JokarzPlayer.fromJson(Map<String, dynamic> json) => JokarzPlayer(
        id: json['id'] as String,
        gameId: json['gameId'] as String,
        name: json['name'] as String,
        suitIcon: json['suitIcon'] as String? ?? '♠️',
      );
}

class JokarzGame {
  final String id;
  final String name;
  final WinCondition winCondition;
  final DateTime date;
  final List<JokarzPlayer> players;
  final List<JokarzScore> scores;
  final List<HighlightMoment> highlights;
  final bool isCompleted;

  JokarzGame({
    required this.id,
    required this.name,
    required this.winCondition,
    DateTime? date,
    List<JokarzPlayer>? players,
    List<JokarzScore>? scores,
    List<HighlightMoment>? highlights,
    this.isCompleted = false,
  })  : date = date ?? DateTime.now(),
        players = players ?? [],
        scores = scores ?? [],
        highlights = highlights ?? [];

  int get maxRound {
    if (scores.isEmpty) return 0;
    return scores.map((s) => s.round).reduce((a, b) => a > b ? a : b);
  }

  int totalScoreForPlayer(String playerId) {
    return scores
        .where((s) => s.playerId == playerId)
        .fold(0, (sum, item) => sum + item.score);
  }

  int? scoreForPlayerRound(String playerId, int round) {
    final matches = scores.where((s) => s.playerId == playerId && s.round == round);
    if (matches.isEmpty) return null;
    return matches.first.score;
  }

  List<JokarzPlayer> get rankedPlayers {
    final list = List<JokarzPlayer>.from(players);
    list.sort((a, b) {
      final scoreA = totalScoreForPlayer(a.id);
      final scoreB = totalScoreForPlayer(b.id);
      if (winCondition == WinCondition.lowest) {
        return scoreA.compareTo(scoreB);
      } else {
        return scoreB.compareTo(scoreA);
      }
    });
    return list;
  }

  int getRank(String playerId) {
    final ranked = rankedPlayers;
    for (int i = 0; i < ranked.length; i++) {
      if (ranked[i].id == playerId) return i + 1;
    }
    return 1;
  }

  bool isLeader(String playerId) {
    final ranked = rankedPlayers;
    if (ranked.isEmpty) return false;
    final topScore = totalScoreForPlayer(ranked.first.id);
    return totalScoreForPlayer(playerId) == topScore && scores.isNotEmpty;
  }

  JokarzGame copyWith({
    String? id,
    String? name,
    WinCondition? winCondition,
    DateTime? date,
    List<JokarzPlayer>? players,
    List<JokarzScore>? scores,
    List<HighlightMoment>? highlights,
    bool? isCompleted,
  }) {
    return JokarzGame(
      id: id ?? this.id,
      name: name ?? this.name,
      winCondition: winCondition ?? this.winCondition,
      date: date ?? this.date,
      players: players ?? this.players,
      scores: scores ?? this.scores,
      highlights: highlights ?? this.highlights,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'winCondition': winCondition.key,
        'date': date.toIso8601String(),
        'players': players.map((p) => p.toJson()).toList(),
        'scores': scores.map((s) => s.toJson()).toList(),
        'highlights': highlights.map((h) => h.toJson()).toList(),
        'isCompleted': isCompleted,
      };

  factory JokarzGame.fromJson(Map<String, dynamic> json) {
    return JokarzGame(
      id: json['id'] as String,
      name: json['name'] as String,
      winCondition: WinConditionExtension.fromKey(json['winCondition'] as String?),
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      players: (json['players'] as List<dynamic>?)
              ?.map((p) => JokarzPlayer.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      scores: (json['scores'] as List<dynamic>?)
              ?.map((s) => JokarzScore.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      highlights: (json['highlights'] as List<dynamic>?)
              ?.map((h) => HighlightMoment.fromJson(h as Map<String, dynamic>))
              .toList() ??
          [],
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}
