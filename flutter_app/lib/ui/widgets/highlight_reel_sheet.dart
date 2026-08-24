import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../models/game_model.dart';
import '../../models/highlight_moment.dart';
import '../../state/game_provider.dart';
import 'poker_card_widgets.dart';

class HighlightReelSheet extends StatelessWidget {
  final JokarzGame game;

  const HighlightReelSheet({super.key, required this.game});

  String _generateShareText() {
    final ranked = game.rankedPlayers;
    final maxRound = game.maxRound > 0 ? game.maxRound : 1;

    final buffer = StringBuffer();
    buffer.writeln('🃏 *JOKARZ PLAYS — GAME NIGHT RECAP* 🃏');
    buffer.writeln('🏆 *Match:* ${game.name}');
    buffer.writeln('📅 *Date:* ${DateFormat('MMM d, y • h:mm a').format(game.date)}');
    buffer.writeln('⚖️ *Rule:* ${game.winCondition.label}');
    buffer.writeln('🎯 *Total Rounds:* $maxRound');
    buffer.writeln('');
    buffer.writeln('👑 *FINAL STANDINGS:*');

    for (int i = 0; i < ranked.length; i++) {
      final p = ranked[i];
      final score = game.totalScoreForPlayer(p.id);
      final medal = i == 0 ? '🥇' : (i == 1 ? '🥈' : (i == 2 ? '🥉' : '${i + 1}.'));
      buffer.writeln('$medal ${p.suitIcon} *${p.name}* — $score pts');
    }

    if (game.highlights.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('🚨 *VAR HIGHLIGHTS & CONTROVERSIES:*');
      for (final hl in game.highlights) {
        final roundStr = hl.roundNumber != null ? ' (R${hl.roundNumber})' : '';
        buffer.writeln('${hl.typeIcon} *${hl.title}*$roundStr: ${hl.description}');
      }
    }

    buffer.writeln('');
    buffer.writeln('⚡ _Tracked live with Jokarz Plays VAR & Scoreboard_');
    return buffer.toString();
  }

  void _showAddHighlightDialog(BuildContext context) {
    final titleController = TextEditingController(text: 'Controversial Card Play');
    final descController = TextEditingController(text: 'VAR check confirmed card was played out of turn.');
    HighlightType selectedType = HighlightType.varReview;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Dialog(
          backgroundColor: JokarzColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: JokarzColors.gold, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BOOKMARK HIGHLIGHT MOMENT',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: JokarzColors.gold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Highlight Title',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Details / Referee Decision',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('TYPE:', style: TextStyle(fontSize: 11, color: JokarzColors.textMuted, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: HighlightType.values.map((t) {
                    final isSel = selectedType == t;
                    return ChoiceChip(
                      label: Text(t.name.toUpperCase()),
                      selected: isSel,
                      selectedColor: JokarzColors.gold,
                      backgroundColor: JokarzColors.surfaceLight,
                      labelStyle: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.black : JokarzColors.textSecondary,
                      ),
                      onSelected: (_) {
                        setState(() {
                          selectedType = t;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (titleController.text.trim().isNotEmpty) {
                            context.read<GameProvider>().addHighlightMoment(
                                  title: titleController.text.trim(),
                                  description: descController.text.trim(),
                                  type: selectedType,
                                  roundNumber: game.maxRound,
                                );
                            Navigator.of(ctx).pop();
                          }
                        },
                        child: const Text('Save Moment'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ranked = game.rankedPlayers;
    final winner = ranked.isNotEmpty ? ranked.first : null;
    final maxRound = game.maxRound > 0 ? game.maxRound : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: JokarzColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: JokarzColors.gold.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Text('🎬', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MATCH HIGHLIGHT REEL',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: JokarzColors.gold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '${game.name} • $maxRound Rounds',
                      style: const TextStyle(fontSize: 12, color: JokarzColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_add, color: JokarzColors.gold),
                tooltip: 'Add Controversy Bookmark',
                onPressed: () => _showAddHighlightDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Scrollable Content
          Expanded(
            child: ListView(
              children: [
                // Winner Podium Card
                if (winner != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2C2205), Color(0xFF1A2234)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: JokarzColors.gold, width: 1.8),
                    ),
                    child: Row(
                      children: [
                        const Text('🏆', style: TextStyle(fontSize: 36)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MATCH MVP / WINNER',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: JokarzColors.gold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                '${winner.suitIcon} ${winner.name}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: JokarzColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Total Score: ${game.totalScoreForPlayer(winner.id)} pts',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: JokarzColors.emerald,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Standings Summary
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
                      color: idx == 0 ? JokarzColors.gold.withAlpha(20) : JokarzColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: idx == 0 ? JokarzColors.gold : JokarzColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        PlayerRankBadge(rank: idx + 1),
                        const SizedBox(width: 8),
                        Text(p.suitIcon),
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
                            fontWeight: FontWeight.w800,
                            color: idx == 0 ? JokarzColors.gold : JokarzColors.emerald,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Bookmarked Highlights & VAR Moments
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'BOOKMARKED VAR MOMENTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: JokarzColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '${game.highlights.length} Moments',
                      style: const TextStyle(fontSize: 11, color: JokarzColors.gold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (game.highlights.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: JokarzColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'No VAR moments bookmarked yet. Tap the bookmark icon to record key moves & disputes!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: JokarzColors.textMuted),
                      ),
                    ),
                  )
                else
                  ...game.highlights.map((hl) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: JokarzColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: JokarzColors.cardBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hl.typeIcon, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      hl.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: JokarzColors.textPrimary),
                                    ),
                                    if (hl.roundNumber != null)
                                      Text(
                                        'Round ${hl.roundNumber}',
                                        style: const TextStyle(fontSize: 10, color: JokarzColors.gold, fontWeight: FontWeight.bold),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hl.description,
                                  style: const TextStyle(fontSize: 12, color: JokarzColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Share Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: JokarzColors.gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.share, size: 18),
            label: const Text(
              'SHARE RECAP (WHATSAPP / DISCORD)',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            onPressed: () {
              final shareText = _generateShareText();
              Clipboard.setData(ClipboardData(text: shareText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📋 Match Highlight Recap copied to clipboard ready to paste!'),
                  backgroundColor: JokarzColors.emeraldDark,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
