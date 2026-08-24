import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../models/game_model.dart';
import '../../state/game_provider.dart';
import '../widgets/highlight_reel_sheet.dart';
import '../widgets/poker_card_widgets.dart';

class GameHistoryScreen extends StatelessWidget {
  const GameHistoryScreen({super.key});

  void _showGameDetails(BuildContext context, JokarzGame game) {
    final ranked = game.rankedPlayers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: JokarzColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: JokarzColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    game.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: JokarzColors.gold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: JokarzColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    game.winCondition.shortBadge,
                    style: const TextStyle(fontSize: 10, color: JokarzColors.goldLight, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('MMMM d, y • h:mm a').format(game.date),
              style: const TextStyle(fontSize: 12, color: JokarzColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text(
              'FINAL STANDINGS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: JokarzColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            ...ranked.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              final total = game.totalScoreForPlayer(p.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: idx == 0 ? JokarzColors.gold.withAlpha(25) : JokarzColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: idx == 0 ? JokarzColors.gold : JokarzColors.cardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    PlayerRankBadge(rank: idx + 1),
                    const SizedBox(width: 10),
                    Text(p.suitIcon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: JokarzColors.textPrimary),
                      ),
                    ),
                    Text(
                      '$total pts',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: idx == 0 ? JokarzColors.gold : JokarzColors.emerald,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JokarzColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.movie_filter, size: 18),
                    label: const Text('Highlight Reel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => HighlightReelSheet(game: game),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: JokarzColors.crimson),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete Match'),
                    onPressed: () {
                      context.read<GameProvider>().deleteGame(game.id);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Resume / Set Active'),
                    onPressed: () {
                      context.read<GameProvider>().setActiveGame(game.id);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final games = gameProvider.games;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Night History'),
      ),
      body: SafeArea(
        child: games.isEmpty
            ? const Center(
                child: Text(
                  'No previous game matches recorded yet.',
                  style: TextStyle(color: JokarzColors.textSecondary),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: games.length,
                itemBuilder: (context, index) {
                  final game = games[index];
                  final ranked = game.rankedPlayers;
                  final winner = ranked.isNotEmpty ? ranked.first : null;
                  final isActive = gameProvider.activeGame?.id == game.id;

                  return JokarzCard(
                    borderColor: isActive ? JokarzColors.gold : JokarzColors.cardBorder,
                    onTap: () => _showGameDetails(context, game),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              game.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: JokarzColors.textPrimary,
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: JokarzColors.gold.withAlpha(40),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: JokarzColors.gold),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: JokarzColors.gold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            else if (game.isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: JokarzColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'COMPLETED',
                                  style: TextStyle(
                                    color: JokarzColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, y • h:mm a').format(game.date),
                          style: const TextStyle(fontSize: 12, color: JokarzColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text(
                              'Players: ',
                              style: TextStyle(fontSize: 12, color: JokarzColors.textMuted),
                            ),
                            Expanded(
                              child: Text(
                                game.players.map((p) => '${p.suitIcon} ${p.name}').join(', '),
                                style: const TextStyle(fontSize: 12, color: JokarzColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (winner != null && game.scores.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text(
                                'Leader / Winner: ',
                                style: TextStyle(fontSize: 12, color: JokarzColors.textMuted),
                              ),
                              Text(
                                '${winner.suitIcon} ${winner.name} (${game.totalScoreForPlayer(winner.id)} pts)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: JokarzColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
