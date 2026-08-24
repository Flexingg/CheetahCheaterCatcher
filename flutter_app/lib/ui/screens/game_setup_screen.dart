import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_theme.dart';
import '../../models/game_model.dart';
import '../../state/game_provider.dart';
import '../widgets/poker_card_widgets.dart';

class GameSetupScreen extends StatefulWidget {
  const GameSetupScreen({super.key});

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  final TextEditingController _nameController = TextEditingController(text: "Texas Hold'em Night");
  WinCondition _winCondition = WinCondition.highest;
  final List<TextEditingController> _playerControllers = [
    TextEditingController(text: 'Player 1'),
    TextEditingController(text: 'Player 2'),
    TextEditingController(text: 'Player 3'),
    TextEditingController(text: 'Player 4'),
  ];

  final List<String> _suits = ['♠️', '♥️', '♦️', '♣️', '🃏', '👑', '⭐', '🎲'];

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      _nameController.text = preset['name'] as String;
      _winCondition = WinConditionExtension.fromKey(preset['winCondition'] as String);
    });
  }

  void _addPlayer() {
    if (_playerControllers.length < 12) {
      setState(() {
        _playerControllers.add(
          TextEditingController(text: 'Player ${_playerControllers.length + 1}'),
        );
      });
    }
  }

  void _removePlayer(int index) {
    if (_playerControllers.length > 2) {
      setState(() {
        _playerControllers[index].dispose();
        _playerControllers.removeAt(index);
      });
    }
  }

  void _startGame() async {
    final names = _playerControllers
        .map((c) => c.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    if (names.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 2 players to start a game.'),
          backgroundColor: JokarzColors.crimson,
        ),
      );
      return;
    }

    await context.read<GameProvider>().createGame(
          name: _nameController.text.trim().isEmpty ? 'Game Night Match' : _nameController.text.trim(),
          winCondition: _winCondition,
          playerNames: names,
        );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _playerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup New Game'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Presets Carousel
              const Text(
                'QUICK GAME PRESETS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: JokarzColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppConstants.gamePresets.map((preset) {
                    final isSelected = _nameController.text.startsWith(preset['name'] as String);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Text(preset['icon'] as String, style: const TextStyle(fontSize: 14)),
                        label: Text(
                          preset['name'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.black : JokarzColors.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: JokarzColors.gold,
                        backgroundColor: JokarzColors.card,
                        onSelected: (_) => _applyPreset(preset),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Game Name & Win Condition
              JokarzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Game Title',
                        hintText: 'e.g. High Stakes Poker, Hearts Final',
                        prefixIcon: Icon(Icons.casino, color: JokarzColors.gold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'WIN CONDITION RULE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: JokarzColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Highest Score Wins')),
                            selected: _winCondition == WinCondition.highest,
                            selectedColor: JokarzColors.gold,
                            backgroundColor: JokarzColors.surfaceLight,
                            labelStyle: TextStyle(
                              color: _winCondition == WinCondition.highest
                                  ? Colors.black
                                  : JokarzColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _winCondition = WinCondition.highest;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Lowest Score Wins')),
                            selected: _winCondition == WinCondition.lowest,
                            selectedColor: JokarzColors.gold,
                            backgroundColor: JokarzColors.surfaceLight,
                            labelStyle: TextStyle(
                              color: _winCondition == WinCondition.lowest
                                  ? Colors.black
                                  : JokarzColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _winCondition = WinCondition.lowest;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Player Roster
              JokarzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PLAYER ROSTER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: JokarzColors.textMuted,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          '${_playerControllers.length} Players',
                          style: const TextStyle(fontSize: 12, color: JokarzColors.gold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._playerControllers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controller = entry.value;
                      final suit = _suits[index % _suits.length];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: JokarzColors.surfaceLight,
                                shape: BoxShape.circle,
                                border: Border.all(color: JokarzColors.cardBorder),
                              ),
                              child: Center(
                                child: Text(suit, style: const TextStyle(fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  hintText: 'Player ${index + 1} Name',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            if (_playerControllers.length > 2)
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: JokarzColors.crimson, size: 20),
                                onPressed: () => _removePlayer(index),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('+ Add Another Player'),
                      onPressed: _addPlayer,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Start Game Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.play_arrow, size: 22),
                label: const Text(
                  'START GAME NIGHT',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                onPressed: _startGame,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
