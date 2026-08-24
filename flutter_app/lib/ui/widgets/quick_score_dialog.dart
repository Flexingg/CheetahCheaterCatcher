import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_theme.dart';
import '../../services/sound_effects_service.dart';
import 'poker_card_widgets.dart';

enum ScoreInputMode {
  quickType,
  chips,
}

class QuickScoreDialog extends StatefulWidget {
  final String playerName;
  final String suitIcon;
  final int round;
  final int initialScore;
  final ValueChanged<int> onSave;

  const QuickScoreDialog({
    super.key,
    required this.playerName,
    required this.suitIcon,
    required this.round,
    required this.initialScore,
    required this.onSave,
  });

  @override
  State<QuickScoreDialog> createState() => _QuickScoreDialogState();
}

class _QuickScoreDialogState extends State<QuickScoreDialog> {
  late int _currentScore;
  final TextEditingController _controller = TextEditingController();
  ScoreInputMode _mode = ScoreInputMode.quickType; // Default to lightning fast quick type
  bool _isNegative = false;

  @override
  void initState() {
    super.initState();
    _currentScore = widget.initialScore;
    _isNegative = _currentScore < 0;
    _controller.text = _currentScore.abs().toString();
  }

  void _adjust(int amount) {
    setState(() {
      _currentScore += amount;
      _isNegative = _currentScore < 0;
      _controller.text = _currentScore.abs().toString();
    });
    SoundEffectsService.playChipClick();
  }

  void _appendDigit(String digit) {
    setState(() {
      if (_controller.text == '0') {
        _controller.text = digit;
      } else {
        _controller.text += digit;
      }
      _syncScoreFromText();
    });
    SoundEffectsService.playScoreChange();
  }

  void _backspace() {
    setState(() {
      if (_controller.text.isNotEmpty) {
        _controller.text = _controller.text.substring(0, _controller.text.length - 1);
        if (_controller.text.isEmpty) {
          _controller.text = '0';
        }
      }
      _syncScoreFromText();
    });
    SoundEffectsService.playScoreChange();
  }

  void _toggleSign() {
    setState(() {
      _isNegative = !_isNegative;
      _syncScoreFromText();
    });
    SoundEffectsService.playScoreChange();
  }

  void _clear() {
    setState(() {
      _controller.text = '0';
      _currentScore = 0;
      _isNegative = false;
    });
    SoundEffectsService.playScoreChange();
  }

  void _syncScoreFromText() {
    final raw = int.tryParse(_controller.text) ?? 0;
    _currentScore = _isNegative ? -raw : raw;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: JokarzColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: JokarzColors.gold, width: 2),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Player & Round Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.suitIcon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.playerName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: JokarzColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: JokarzColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Round ${widget.round}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: JokarzColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Mode Selector: Quick-Type vs Chip Dial
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: JokarzColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: JokarzColors.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _mode = ScoreInputMode.quickType;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _mode == ScoreInputMode.quickType
                              ? JokarzColors.gold
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.keyboard,
                              size: 16,
                              color: _mode == ScoreInputMode.quickType
                                  ? Colors.black
                                  : JokarzColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'QUICK TYPE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _mode == ScoreInputMode.quickType
                                    ? Colors.black
                                    : JokarzColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _mode = ScoreInputMode.chips;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _mode == ScoreInputMode.chips
                              ? JokarzColors.gold
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.casino,
                              size: 16,
                              color: _mode == ScoreInputMode.chips
                                  ? Colors.black
                                  : JokarzColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'CHIP DIAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _mode == ScoreInputMode.chips
                                    ? Colors.black
                                    : JokarzColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Score Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: JokarzColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: JokarzColors.gold.withAlpha(120), width: 1.5),
              ),
              child: Center(
                child: Text(
                  '${_isNegative ? '-' : ''}${_controller.text}',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: JokarzColors.gold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Mode Content: QUICK-TYPE KEYPAD
            if (_mode == ScoreInputMode.quickType) ...[
              _buildKeypad(),
            ] else ...[
              // Mode Content: CHIP DIAL
              _buildChipDial(),
            ],

            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JokarzColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      _syncScoreFromText();
                      widget.onSave(_currentScore);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Save Score'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          children: [
            _buildKeypadBtn('1', () => _appendDigit('1')),
            const SizedBox(width: 8),
            _buildKeypadBtn('2', () => _appendDigit('2')),
            const SizedBox(width: 8),
            _buildKeypadBtn('3', () => _appendDigit('3')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildKeypadBtn('4', () => _appendDigit('4')),
            const SizedBox(width: 8),
            _buildKeypadBtn('5', () => _appendDigit('5')),
            const SizedBox(width: 8),
            _buildKeypadBtn('6', () => _appendDigit('6')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildKeypadBtn('7', () => _appendDigit('7')),
            const SizedBox(width: 8),
            _buildKeypadBtn('8', () => _appendDigit('8')),
            const SizedBox(width: 8),
            _buildKeypadBtn('9', () => _appendDigit('9')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildKeypadBtn('+/-', _toggleSign, color: JokarzColors.crimson),
            const SizedBox(width: 8),
            _buildKeypadBtn('0', () => _appendDigit('0')),
            const SizedBox(width: 8),
            _buildKeypadBtn('⌫', _backspace, color: JokarzColors.goldLight),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadBtn(String label, VoidCallback onTap, {Color? color}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: JokarzColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: JokarzColors.cardBorder),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color ?? JokarzColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipDial() {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'QUICK CHIPS (+)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: JokarzColors.textMuted,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: AppConstants.chipValues.map((val) {
            return PokerChipButton(
              label: '+$val',
              color: _getChipColor(val),
              onTap: () => _adjust(val),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'PENALTIES (-)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: JokarzColors.textMuted,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            PokerChipButton(
              label: '-1',
              color: JokarzColors.crimson,
              onTap: () => _adjust(-1),
            ),
            PokerChipButton(
              label: '-5',
              color: JokarzColors.crimson,
              onTap: () => _adjust(-5),
            ),
            PokerChipButton(
              label: '-10',
              color: JokarzColors.crimson,
              onTap: () => _adjust(-10),
            ),
            PokerChipButton(
              label: 'CLR',
              color: JokarzColors.textMuted,
              onTap: _clear,
            ),
          ],
        ),
      ],
    );
  }

  Color _getChipColor(int value) {
    if (value >= 100) return JokarzColors.velvetPurple;
    if (value >= 50) return JokarzColors.crimson;
    if (value >= 25) return JokarzColors.emerald;
    if (value >= 10) return JokarzColors.spade;
    if (value >= 5) return JokarzColors.gold;
    return JokarzColors.textPrimary;
  }
}
