import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_theme.dart';
import '../../state/telestrator_provider.dart';
import '../../state/var_replay_provider.dart';

class ReplayScrubberWidget extends StatelessWidget {
  const ReplayScrubberWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final varProvider = context.watch<VarReplayProvider>();

    if (!varProvider.isReplayActive) {
      return const SizedBox.shrink();
    }

    final totalFrames = varProvider.totalBufferedFrames;
    final currentIndex = varProvider.currentScrubIndex;
    final progress = totalFrames > 1 ? currentIndex / (totalFrames - 1) : 0.0;
    final fps = varProvider.captureFps > 0 ? varProvider.captureFps : 30.0;

    // Time based on the actual capture frame rate
    final currentSeconds = (currentIndex / fps);
    final totalSeconds = (totalFrames / fps);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: JokarzColors.surface.withAlpha(245),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JokarzColors.crimson.withAlpha(180), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: JokarzColors.crimson.withAlpha(50),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: DVR Tag + Time Readout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: JokarzColors.crimson,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'INSTANT REPLAY / VAR',
                    style: TextStyle(
                      color: JokarzColors.crimson,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Text(
                '${_formatDuration(currentSeconds)} / ${_formatDuration(totalSeconds)}  (F: $currentIndex)',
                style: const TextStyle(
                  color: JokarzColors.gold,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Timeline Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: JokarzColors.crimson,
              inactiveTrackColor: JokarzColors.surfaceLight,
              thumbColor: JokarzColors.gold,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 4,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (val) {
                varProvider.seekRatio(val);
              },
            ),
          ),

          // Controls Row: Play/Pause, Frame Stepping, Speed Pills, Back to Live
          Row(
            children: [
              // Step -1 Frame
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 22),
                color: JokarzColors.textPrimary,
                tooltip: 'Step -1 Frame',
                visualDensity: VisualDensity.compact,
                onPressed: () => varProvider.stepBackward(1),
              ),

              // Play / Pause
              IconButton(
                icon: Icon(
                  varProvider.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 32,
                  color: JokarzColors.gold,
                ),
                tooltip: varProvider.isPlaying ? 'Pause' : 'Play',
                onPressed: varProvider.togglePlayPause,
              ),

              // Step +1 Frame
              IconButton(
                icon: const Icon(Icons.skip_next, size: 22),
                color: JokarzColors.textPrimary,
                tooltip: 'Step +1 Frame',
                visualDensity: VisualDensity.compact,
                onPressed: () => varProvider.stepForward(1),
              ),

              const SizedBox(width: 4),

              // Feature #5: Animate / Slow Draw Markup
              Builder(
                builder: (context) {
                  final telestrator = context.watch<TelestratorProvider>();
                  return IconButton(
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    color: telestrator.paths.isNotEmpty ? JokarzColors.gold : JokarzColors.textMuted,
                    tooltip: 'Slow Draw / Animate Markup (#5)',
                    visualDensity: VisualDensity.compact,
                    onPressed: telestrator.paths.isNotEmpty ? telestrator.playSlowDrawAnimation : null,
                  );
                },
              ),

              const SizedBox(width: 4),

              // Speed Selector Pills
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: AppConstants.replaySpeeds.map((sp) {
                      final isSelected = (varProvider.playbackSpeed - sp).abs() < 0.01;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          label: Text(
                            '${sp}x',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : JokarzColors.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: JokarzColors.gold,
                          backgroundColor: JokarzColors.surfaceLight,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => varProvider.setPlaybackSpeed(sp),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Back to Live Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: JokarzColors.crimson,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.fiber_manual_record, size: 14, color: Colors.white),
                label: const Text('LIVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: varProvider.returnToLive,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final int mins = seconds ~/ 60;
    final int secs = (seconds % 60).toInt();
    final int ms = ((seconds % 1) * 10).toInt();
    return '$mins:${secs.toString().padLeft(2, '0')}.$ms';
  }
}
