import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../services/dvr_replay_manager.dart';

class CameraReplayTesterSheet extends StatefulWidget {
  final DvrReplayManager dvrManager;
  final int captureFps;

  const CameraReplayTesterSheet({
    super.key,
    required this.dvrManager,
    required this.captureFps,
  });

  @override
  State<CameraReplayTesterSheet> createState() => _CameraReplayTesterSheetState();
}

class _CameraReplayTesterSheetState extends State<CameraReplayTesterSheet> {
  Timer? _playbackTimer;
  double _playbackSpeed = 0.25; // Default to smooth 0.25x slow motion
  bool _isPlaying = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.dvrManager.enterReplayMode();
    _currentIndex = widget.dvrManager.currentScrubIndex;
    _startPlayback();
  }

  void _startPlayback() {
    _playbackTimer?.cancel();
    _isPlaying = true;

    final baseIntervalMs = (1000 / (widget.captureFps > 0 ? widget.captureFps : 30)).round();
    final intervalMs = (baseIntervalMs / _playbackSpeed).round().clamp(10, 1000);

    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!mounted) return;
      if (widget.dvrManager.totalBufferedFrames == 0) return;

      setState(() {
        if (_currentIndex < widget.dvrManager.totalBufferedFrames - 1) {
          _currentIndex++;
        } else {
          _currentIndex = 0; // Loop replay
        }
        widget.dvrManager.seekToIndex(_currentIndex);
      });
    });
  }

  void _pausePlayback() {
    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  void _setSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    if (_isPlaying) {
      _startPlayback();
    }
  }

  void _step(int delta) {
    _pausePlayback();
    setState(() {
      _currentIndex = (_currentIndex + delta).clamp(0, widget.dvrManager.totalBufferedFrames - 1);
      widget.dvrManager.seekToIndex(_currentIndex);
    });
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    widget.dvrManager.returnToLive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.dvrManager.currentFrame;
    final totalFrames = widget.dvrManager.totalBufferedFrames;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: JokarzColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
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
          const SizedBox(height: 12),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: JokarzColors.crimson.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.slow_motion_video, color: JokarzColors.crimson, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CAMERA SLOW-MO REPLAY TESTER',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: JokarzColors.gold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'Captured at ${widget.captureFps} FPS • $totalFrames Frames in DVR',
                        style: const TextStyle(fontSize: 11, color: JokarzColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: JokarzColors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Replay Frame Viewport with Pinch-to-Zoom
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: JokarzColors.gold, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: frame != null
                  ? InteractiveViewer(
                      maxScale: 6.0,
                      minScale: 1.0,
                      child: Center(
                        child: Image.memory(
                          frame.jpegBytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'Buffering rolling frames...',
                        style: TextStyle(color: JokarzColors.textMuted),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Scrubber Timeline Slider
          Row(
            children: [
              Text(
                'F#$_currentIndex',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: JokarzColors.gold,
                ),
              ),
              Expanded(
                child: Slider(
                  value: totalFrames > 0 ? _currentIndex.toDouble().clamp(0.0, (totalFrames - 1).toDouble()) : 0.0,
                  min: 0.0,
                  max: totalFrames > 1 ? (totalFrames - 1).toDouble() : 1.0,
                  activeColor: JokarzColors.crimson,
                  inactiveColor: JokarzColors.surfaceLight,
                  onChanged: (val) {
                    _pausePlayback();
                    setState(() {
                      _currentIndex = val.round();
                      widget.dvrManager.seekToIndex(_currentIndex);
                    });
                  },
                ),
              ),
              Text(
                '/${totalFrames > 0 ? totalFrames - 1 : 0}',
                style: const TextStyle(fontSize: 11, color: JokarzColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Playback & Frame Step Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Step -5 Frames
              IconButton(
                icon: const Icon(Icons.fast_rewind, size: 22),
                color: JokarzColors.textPrimary,
                tooltip: 'Step -5 Frames',
                onPressed: () => _step(-5),
              ),
              // Step -1 Frame
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 24),
                color: JokarzColors.textPrimary,
                tooltip: 'Step -1 Frame',
                onPressed: () => _step(-1),
              ),
              const SizedBox(width: 8),

              // Play / Pause Button
              FloatingActionButton.small(
                backgroundColor: JokarzColors.gold,
                foregroundColor: Colors.black,
                onPressed: _isPlaying ? _pausePlayback : _startPlayback,
                child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 26),
              ),

              const SizedBox(width: 8),
              // Step +1 Frame
              IconButton(
                icon: const Icon(Icons.skip_next, size: 24),
                color: JokarzColors.textPrimary,
                tooltip: 'Step +1 Frame',
                onPressed: () => _step(1),
              ),
              // Step +5 Frames
              IconButton(
                icon: const Icon(Icons.fast_forward, size: 22),
                color: JokarzColors.textPrimary,
                tooltip: 'Step +5 Frames',
                onPressed: () => _step(5),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Slow-Mo Speed Selector Pills
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: JokarzColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: JokarzColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [0.1, 0.25, 0.5, 1.0, 2.0].map((spd) {
                final isSel = _playbackSpeed == spd;
                return InkWell(
                  onTap: () => _setSpeed(spd),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSel ? JokarzColors.crimson : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${spd}x',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : JokarzColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
