class PlayerStatsItem {
  final String name;
  final num value;
  final String? gameName;
  final String? subtitle;

  PlayerStatsItem({
    required this.name,
    required this.value,
    this.gameName,
    this.subtitle,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'gameName': gameName,
        'subtitle': subtitle,
      };

  factory PlayerStatsItem.fromJson(Map<String, dynamic> json) => PlayerStatsItem(
        name: json['name'] as String,
        value: json['value'] as num,
        gameName: json['gameName'] as String?,
        subtitle: json['subtitle'] as String?,
      );
}

class JokarzTrophyStats {
  final List<PlayerStatsItem> mostGamesPlayed;
  final PlayerStatsItem? highestSingleRound;
  final PlayerStatsItem? lowestSingleRound;
  final PlayerStatsItem? mostZeroRounds;
  final List<PlayerStatsItem> bestAverageScores;
  final int totalGamesCount;
  final int totalRoundsCount;

  JokarzTrophyStats({
    required this.mostGamesPlayed,
    this.highestSingleRound,
    this.lowestSingleRound,
    this.mostZeroRounds,
    required this.bestAverageScores,
    this.totalGamesCount = 0,
    this.totalRoundsCount = 0,
  });

  factory JokarzTrophyStats.empty() {
    return JokarzTrophyStats(
      mostGamesPlayed: [],
      bestAverageScores: [],
    );
  }
}
