import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/telestrator_drawing.dart';
import '../services/sound_effects_service.dart';

class TelestratorProvider extends ChangeNotifier {
  bool _isDrawingEnabled = false;
  TelestratorTool _currentTool = TelestratorTool.pen;
  Color _currentColor = JokarzColors.telestratorPalette.first;
  double _strokeWidth = 5.0;

  final List<TelestratorPath> _paths = [];
  final List<TelestratorPath> _redoStack = [];
  TelestratorPath? _currentDrawingPath;
  DateTime? _strokeStartTime;

  // Animated Slow Draw Engine (#5)
  bool _isSlowDrawing = false;
  double _slowDrawProgress = 1.0;
  Timer? _slowDrawTimer;

  bool get isDrawingEnabled => _isDrawingEnabled;
  TelestratorTool get currentTool => _currentTool;
  Color get currentColor => _currentColor;
  double get strokeWidth => _strokeWidth;
  List<TelestratorPath> get paths => List.unmodifiable(_paths);
  TelestratorPath? get currentDrawingPath => _currentDrawingPath;
  bool get canUndo => _paths.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isSlowDrawing => _isSlowDrawing;
  double get slowDrawProgress => _slowDrawProgress;

  /// Returns paths rendered with progressive slow-draw trimming if animating
  List<TelestratorPath> get visiblePaths {
    if (!_isSlowDrawing || _slowDrawProgress >= 1.0) {
      return _paths;
    }
    return _paths.map((p) => p.trimProgress(_slowDrawProgress)).toList();
  }

  void toggleDrawing() {
    _isDrawingEnabled = !_isDrawingEnabled;
    notifyListeners();
  }

  void setDrawingEnabled(bool enabled) {
    _isDrawingEnabled = enabled;
    notifyListeners();
  }

  void setTool(TelestratorTool tool) {
    _currentTool = tool;
    notifyListeners();
  }

  void setColor(Color color) {
    _currentColor = color;
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    _strokeWidth = width;
    notifyListeners();
  }

  void onPanStart(Offset position, {int? activeFrameIndex}) {
    if (!_isDrawingEnabled) return;
    _redoStack.clear();
    _strokeStartTime = DateTime.now();
    _currentDrawingPath = TelestratorPath(
      id: 'path_${DateTime.now().microsecondsSinceEpoch}',
      tool: _currentTool,
      color: _currentColor,
      strokeWidth: _strokeWidth,
      points: [position],
      pointOffsets: [Duration.zero],
      frameIndex: activeFrameIndex,
    );
    notifyListeners();
  }

  void onPanUpdate(Offset position) {
    if (!_isDrawingEnabled || _currentDrawingPath == null) return;
    final updatedPoints = List<Offset>.from(_currentDrawingPath!.points);
    final updatedOffsets = List<Duration>.from(_currentDrawingPath!.pointOffsets);

    final offsetFromStart = _strokeStartTime != null
        ? DateTime.now().difference(_strokeStartTime!)
        : Duration.zero;

    if (_currentTool == TelestratorTool.pen || _currentTool == TelestratorTool.highlighter) {
      updatedPoints.add(position);
      updatedOffsets.add(offsetFromStart);
    } else {
      // For geometric shapes (line, circle, arrow), we keep [startPoint, currentPoint]
      if (updatedPoints.length > 1) {
        updatedPoints[1] = position;
        updatedOffsets[1] = offsetFromStart;
      } else {
        updatedPoints.add(position);
        updatedOffsets.add(offsetFromStart);
      }
    }

    _currentDrawingPath = _currentDrawingPath!.copyWith(
      points: updatedPoints,
      pointOffsets: updatedOffsets,
    );
    notifyListeners();
  }

  void onPanEnd() {
    if (!_isDrawingEnabled || _currentDrawingPath == null) return;
    if (_currentDrawingPath!.points.isNotEmpty) {
      _paths.add(_currentDrawingPath!);
    }
    _currentDrawingPath = null;
    _strokeStartTime = null;
    notifyListeners();
  }

  /// Feature #5: Trigger Animated "Slow Draw" Replay Stamp
  void playSlowDrawAnimation({Duration duration = const Duration(milliseconds: 1400)}) {
    if (_paths.isEmpty) return;

    _slowDrawTimer?.cancel();
    _isSlowDrawing = true;
    _slowDrawProgress = 0.0;
    SoundEffectsService.playTelestratorStroke();
    notifyListeners();

    const frameIntervalMs = 16; // ~60fps
    final totalSteps = duration.inMilliseconds / frameIntervalMs;
    int currentStep = 0;

    _slowDrawTimer = Timer.periodic(const Duration(milliseconds: frameIntervalMs), (timer) {
      currentStep++;
      _slowDrawProgress = (currentStep / totalSteps).clamp(0.0, 1.0);
      notifyListeners();

      if (_slowDrawProgress >= 1.0) {
        timer.cancel();
        _isSlowDrawing = false;
        _slowDrawProgress = 1.0;
        notifyListeners();
      }
    });
  }

  void stopSlowDraw() {
    _slowDrawTimer?.cancel();
    _isSlowDrawing = false;
    _slowDrawProgress = 1.0;
    notifyListeners();
  }

  void undo() {
    if (_paths.isNotEmpty) {
      final last = _paths.removeLast();
      _redoStack.add(last);
      notifyListeners();
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      final restored = _redoStack.removeLast();
      _paths.add(restored);
      notifyListeners();
    }
  }

  void clearAll() {
    _paths.clear();
    _redoStack.clear();
    _currentDrawingPath = null;
    _isSlowDrawing = false;
    _slowDrawProgress = 1.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _slowDrawTimer?.cancel();
    super.dispose();
  }
}
