import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../models/replay_frame.dart';

class DvrReplayManager extends ChangeNotifier {
  final int maxCapacity;
  final DoubleLinkedQueue<ReplayFrame> _ringBuffer = DoubleLinkedQueue<ReplayFrame>();

  int _frameSequence = 0;
  bool _isReplayActive = false;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _currentScrubIndex = 0;
  List<ReplayFrame> _frozenBuffer = [];

  Timer? _playbackTimer;

  DvrReplayManager({this.maxCapacity = AppConstants.maxDvrFrames});

  bool get isReplayActive => _isReplayActive;
  bool get isPlaying => _isPlaying;
  double get playbackSpeed => _playbackSpeed;
  int get currentScrubIndex => _currentScrubIndex;
  int get totalBufferedFrames => _isReplayActive ? _frozenBuffer.length : _ringBuffer.length;
  double get bufferDurationSeconds => (_ringBuffer.length / 30.0);

  ReplayFrame? get currentFrame {
    if (_isReplayActive && _frozenBuffer.isNotEmpty) {
      final safeIndex = _currentScrubIndex.clamp(0, _frozenBuffer.length - 1);
      return _frozenBuffer[safeIndex];
    }
    if (_ringBuffer.isNotEmpty) {
      return _ringBuffer.last;
    }
    return null;
  }

  /// Pushes a live frame into the rolling ring buffer
  void pushFrame(Uint8List jpegBytes) {
    _frameSequence++;
    final frame = ReplayFrame(
      frameIndex: _frameSequence,
      timestamp: DateTime.now(),
      jpegBytes: jpegBytes,
    );

    _ringBuffer.addLast(frame);
    if (_ringBuffer.length > maxCapacity) {
      _ringBuffer.removeFirst();
    }

    if (!_isReplayActive) {
      notifyListeners();
    }
  }

  /// Enter Instant Replay mode (freezes current rolling buffer)
  void enterReplayMode() {
    if (_ringBuffer.isEmpty) return;
    _frozenBuffer = _ringBuffer.toList();
    _isReplayActive = true;
    _isPlaying = false;
    _playbackTimer?.cancel();
    // Default to the most recent frame (end of buffer)
    _currentScrubIndex = _frozenBuffer.length - 1;
    notifyListeners();
  }

  /// Exit Replay mode and return to live stream
  void returnToLive() {
    _isReplayActive = false;
    _isPlaying = false;
    _playbackTimer?.cancel();
    _frozenBuffer = [];
    notifyListeners();
  }

  /// Seek to specific frame index
  void seekToIndex(int index) {
    if (!_isReplayActive || _frozenBuffer.isEmpty) return;
    _currentScrubIndex = index.clamp(0, _frozenBuffer.length - 1);
    notifyListeners();
  }

  /// Seek by normalized percentage 0.0 to 1.0
  void seekRatio(double ratio) {
    if (!_isReplayActive || _frozenBuffer.isEmpty) return;
    final index = (ratio * (_frozenBuffer.length - 1)).round();
    seekToIndex(index);
  }

  /// Step exactly one frame backward (VAR inspection)
  void stepBackward([int stepCount = 1]) {
    if (!_isReplayActive || _frozenBuffer.isEmpty) return;
    pause();
    seekToIndex(_currentScrubIndex - stepCount);
  }

  /// Step exactly one frame forward (VAR inspection)
  void stepForward([int stepCount = 1]) {
    if (!_isReplayActive || _frozenBuffer.isEmpty) return;
    pause();
    seekToIndex(_currentScrubIndex + stepCount);
  }

  /// Toggle play / pause during replay
  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    if (!_isReplayActive || _frozenBuffer.isEmpty) return;
    _isPlaying = true;
    _startPlaybackTimer();
    notifyListeners();
  }

  void pause() {
    _isPlaying = false;
    _playbackTimer?.cancel();
    notifyListeners();
  }

  /// Set slow motion or fast playback speed (e.g. 0.1x, 0.25x, 0.5x, 1x, 2x)
  void setSpeed(double speed) {
    _playbackSpeed = speed;
    if (_isPlaying) {
      _startPlaybackTimer();
    }
    notifyListeners();
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    // Base 30 FPS = ~33.3ms per frame
    final intervalMs = (33.33 / _playbackSpeed).round().clamp(5, 1000);
    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (_currentScrubIndex < _frozenBuffer.length - 1) {
        _currentScrubIndex++;
        notifyListeners();
      } else {
        // Reached end of replay buffer
        _currentScrubIndex = 0; // Loop or pause
        notifyListeners();
      }
    });
  }

  void clear() {
    _ringBuffer.clear();
    _frozenBuffer.clear();
    _playbackTimer?.cancel();
    _isReplayActive = false;
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }
}
