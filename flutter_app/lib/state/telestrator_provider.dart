import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/telestrator_drawing.dart';

class TelestratorProvider extends ChangeNotifier {
  bool _isDrawingEnabled = false;
  TelestratorTool _currentTool = TelestratorTool.pen;
  Color _currentColor = JokarzColors.telestratorPalette.first;
  double _strokeWidth = 5.0;

  final List<TelestratorPath> _paths = [];
  final List<TelestratorPath> _redoStack = [];
  TelestratorPath? _currentDrawingPath;

  bool get isDrawingEnabled => _isDrawingEnabled;
  TelestratorTool get currentTool => _currentTool;
  Color get currentColor => _currentColor;
  double get strokeWidth => _strokeWidth;
  List<TelestratorPath> get paths => List.unmodifiable(_paths);
  TelestratorPath? get currentDrawingPath => _currentDrawingPath;
  bool get canUndo => _paths.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

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

  void onPanStart(Offset position) {
    if (!_isDrawingEnabled) return;
    _redoStack.clear();
    _currentDrawingPath = TelestratorPath(
      id: 'path_${DateTime.now().microsecondsSinceEpoch}',
      tool: _currentTool,
      color: _currentColor,
      strokeWidth: _strokeWidth,
      points: [position],
    );
    notifyListeners();
  }

  void onPanUpdate(Offset position) {
    if (!_isDrawingEnabled || _currentDrawingPath == null) return;
    final updatedPoints = List<Offset>.from(_currentDrawingPath!.points);

    if (_currentTool == TelestratorTool.pen || _currentTool == TelestratorTool.highlighter) {
      updatedPoints.add(position);
    } else {
      // For shapes (line, circle, arrow), we keep [startPoint, currentPoint]
      if (updatedPoints.length > 1) {
        updatedPoints[1] = position;
      } else {
        updatedPoints.add(position);
      }
    }

    _currentDrawingPath = _currentDrawingPath!.copyWith(points: updatedPoints);
    notifyListeners();
  }

  void onPanEnd() {
    if (!_isDrawingEnabled || _currentDrawingPath == null) return;
    if (_currentDrawingPath!.points.isNotEmpty) {
      _paths.add(_currentDrawingPath!);
    }
    _currentDrawingPath = null;
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
    notifyListeners();
  }
}
