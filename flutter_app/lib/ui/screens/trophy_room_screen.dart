import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../state/game_provider.dart';
import '../widgets/poker_card_widgets.dart';

class TrophyRoomScreen extends StatelessWidget {
  const TrophyRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final stats = gameProvider.trophyStats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trophy Room & Hall of Fame'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // High-Roller Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C2205), Color(0xFF161B26)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: JokarzColors.gold, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: JokarzColors.gold.withAlpha(40),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: JokarzColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🏆', style: TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'JOKARZ HALL OF FAME',
                            style: TextStyle(
                              color: JokarzColors.gold,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${stats.totalGamesCount} Matches • ${stats.totalRoundsCount} Rounds Recorded',
                            style: const TextStyle(
                              color: JokarzColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Single Match Record Cards
              Row(
                children: [
                  Expanded(
                    child: LuxuryTrophyCard(
                      title: 'Highest Round',
                      value: stats.highestSingleRound != null
                          ? '${stats.highestSingleRound!.value} pts'
                          : '--',
                      player: stats.highestSingleRound?.name ?? 'No data yet',
                      subtitle: stats.highestSingleRound?.gameName,
                      icon: Icons.trending_up,
                      accentColor: JokarzColors.gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LuxuryTrophyCard(
                      title: 'Lowest Round',
                      value: stats.lowestSingleRound != null
                          ? '${stats.lowestSingleRound!.value} pts'
                          : '--',
                      player: stats.lowestSingleRound?.name ?? 'No data yet',
                      subtitle: stats.lowestSingleRound?.gameName,
                      icon: Icons.trending_down,
                      accentColor: JokarzColors.emerald,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: LuxuryTrophyCard(
                      title: 'Most Zeros (0)',
                      value: stats.mostZeroRounds != null
                          ? '${stats.mostZeroRounds!.value} times'
                          : '--',
                      player: stats.mostZeroRounds?.name ?? 'No data yet',
                      icon: Icons.exposure_zero,
                      accentColor: JokarzColors.spade,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LuxuryTrophyCard(
                      title: 'Total Matches',
                      value: '${stats.totalGamesCount}',
                      player: 'Lifetime Log',
                      icon: Icons.casino,
                      accentColor: JokarzColors.velvetPurple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Most Games Played Leaderboard
              _buildLeaderboardCard(
                title: 'MOST ACTIVE HIGH-ROLLERS (GAMES PLAYED)',
                icon: Icons.military_tech,
                items: stats.mostGamesPlayed,
                valueSuffix: 'games',
                accentColor: JokarzColors.gold,
              ),

              const SizedBox(height: 16),

              // Best Career Averages
              _buildLeaderboardCard(
                title: 'BEST CAREER AVERAGE SCORE (PER ROUND)',
                icon: Icons.insights,
                items: stats.bestAverageScores,
                valueSuffix: 'avg pts',
                accentColor: JokarzColors.emerald,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardCard({
    required String title,
    required IconData icon,
    required List<dynamic> items,
    required String valueSuffix,
    required Color accentColor,
  }) {
    return JokarzCard(
      borderColor: accentColor.withAlpha(80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Complete game rounds to build player career stats.',
                  style: TextStyle(fontSize: 12, color: JokarzColors.textMuted),
                ),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: JokarzColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    PlayerRankBadge(rank: rank),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.name as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: JokarzColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${item.value} $valueSuffix',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
