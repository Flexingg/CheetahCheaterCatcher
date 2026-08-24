import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../models/game_model.dart';
import '../../state/game_provider.dart';
import '../widgets/highlight_reel_sheet.dart';
import '../widgets/poker_card_widgets.dart';
import '../widgets/quick_score_dialog.dart';
import 'game_setup_screen.dart';

class ScoreboardScreen extends StatelessWidget {
  const ScoreboardScreen({super.key});

  void _openHighlightReel(BuildContext context, JokarzGame game) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HighlightReelSheet(game: game),
    );
  }

  void _openGameSetup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameSetupScreen()),
    );
  }

  void _showScoreDialog(
    BuildContext context,
    GameProvider gameProvider,
    JokarzPlayer player,
    int round,
    int currentScore,
  ) {
    showDialog(
      context: context,
      builder: (_) => QuickScoreDialog(
        playerName: player.name,
        suitIcon: player.suitIcon,
        round: round,
        initialScore: currentScore,
        onSave: (newScore) {
          gameProvider.setScore(
            playerId: player.id,
            round: round,
            score: newScore,
          );
        },
      ),
    );
  }

  void _showVictoryPodium(BuildContext context, JokarzGame game) {
    final ranked = game.rankedPlayers;
    final winner = ranked.isNotEmpty ? ranked.first : null;
    final winnerScore = winner != null ? game.totalScoreForPlayer(winner.id) : 0;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: JokarzColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: JokarzColors.gold, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 54)),
              const SizedBox(height: 10),
              const Text(
                'GAME OVER - WINNER!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: JokarzColors.gold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              if (winner != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: JokarzColors.gold.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: JokarzColors.gold),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${winner.suitIcon} ${winner.name}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: JokarzColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Final Score: $winnerScore pts',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: JokarzColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Full Standings:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: JokarzColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ...ranked.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                final s = game.totalScoreForPlayer(p.id);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${idx + 1}. ${p.suitIcon} ${p.name}'),
                      Text('$s pts', style: const TextStyle(fontWeight: FontWeight.bold, color: JokarzColors.goldLight)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  context.read<GameProvider>().finishGame();
                  Navigator.of(ctx).pop();
                },
                child: const Text('Save & Archive Match'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final activeGame = gameProvider.activeGame;

    if (activeGame == null || activeGame.players.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scoreboard')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: JokarzColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: JokarzColors.gold, width: 2),
                  ),
                  child: const Text('🃏', style: TextStyle(fontSize: 48)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No Active Game Night',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: JokarzColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start a new poker or board game match to begin live scorekeeping.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: JokarzColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Create New Game'),
                  onPressed: () => _openGameSetup(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final maxRound = activeGame.maxRound > 0 ? activeGame.maxRound : 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(activeGame.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.movie_filter, color: JokarzColors.gold),
            tooltip: 'Highlight Reel & Recap',
            onPressed: () => _openHighlightReel(context, activeGame),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: JokarzColors.gold),
            tooltip: 'New Game',
            onPressed: () => _openGameSetup(context),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events, color: JokarzColors.gold),
            tooltip: 'Declare Winner',
            onPressed: () => _showVictoryPodium(context, activeGame),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Game Info Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: JokarzColors.surface,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: JokarzColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: JokarzColors.gold.withAlpha(150)),
                    ),
                    child: Text(
                      activeGame.winCondition.shortBadge,
                      style: const TextStyle(
                        color: JokarzColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${activeGame.players.length} Players • $maxRound Rounds',
                    style: const TextStyle(
                      fontSize: 12,
                      color: JokarzColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Scoreboard Matrix Table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildMatrixTable(context, gameProvider, activeGame, maxRound),
                  ),
                ),
              ),
            ),

            // Bottom Round Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: JokarzColors.surface,
              child: Row(
                children: [
                  if (maxRound > 1) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: JokarzColors.crimson,
                        side: const BorderSide(color: JokarzColors.crimson),
                      ),
                      icon: const Icon(Icons.remove, size: 16),
                      label: const Text('Delete Round'),
                      onPressed: () => gameProvider.deleteRound(maxRound),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JokarzColors.gold,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        '+ ADD ROUND ${maxRound + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: gameProvider.addRound,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatrixTable(
    BuildContext context,
    GameProvider gameProvider,
    JokarzGame game,
    int maxRound,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: JokarzColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JokarzColors.cardBorder),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(JokarzColors.surfaceLight),
        dataRowColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
          return JokarzColors.card;
        }),
        columnSpacing: 24,
        horizontalMargin: 16,
        columns: [
          const DataColumn(
            label: Text(
              'ROUND',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: JokarzColors.gold,
                fontSize: 12,
              ),
            ),
          ),
          ...game.players.map((p) {
            final isLeader = game.isLeader(p.id);
            return DataColumn(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.suitIcon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    p.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isLeader ? JokarzColors.gold : JokarzColors.textPrimary,
                    ),
                  ),
                  if (isLeader) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.star, color: JokarzColors.gold, size: 14),
                  ],
                ],
              ),
            );
          }),
        ],
        rows: [
          // Round-by-Round Rows
          for (int r = 1; r <= maxRound; r++)
            DataRow(
              cells: [
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: JokarzColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'R$r',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: JokarzColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                ...game.players.map((p) {
                  final score = game.scoreForPlayerRound(p.id, r) ?? 0;
                  return DataCell(
                    InkWell(
                      onTap: () => _showScoreDialog(context, gameProvider, p, r, score),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: JokarzColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: JokarzColors.cardBorder),
                        ),
                        child: Text(
                          '$score',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: JokarzColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),

          // Total Sum Row
          DataRow(
            color: WidgetStateProperty.all(JokarzColors.surfaceLight),
            cells: [
              const DataCell(
                Text(
                  'TOTAL',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: JokarzColors.gold,
                    fontSize: 13,
                  ),
                ),
              ),
              ...game.players.map((p) {
                final total = game.totalScoreForPlayer(p.id);
                final isLeader = game.isLeader(p.id);
                return DataCell(
                  Text(
                    '$total',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isLeader ? JokarzColors.gold : JokarzColors.emerald,
                    ),
                  ),
                );
              }),
            ],
          ),

          // Player Rank Row
          DataRow(
            color: WidgetStateProperty.all(JokarzColors.surface),
            cells: [
              const DataCell(
                Text(
                  'RANK',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: JokarzColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              ...game.players.map((p) {
                final rank = game.getRank(p.id);
                return DataCell(
                  PlayerRankBadge(rank: rank),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
