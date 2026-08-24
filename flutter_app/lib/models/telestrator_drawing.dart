import 'package:flutter/material.dart';

enum TelestratorTool {
  pen,
  line,
  circle,
  arrow,
  highlighter,
}

class TelestratorPoint {
  final Offset offset;
  final double pressure;

  TelestratorPoint(this.offset, {this.pressure = 1.0});
}

class TelestratorPath {
  final String id;
  final TelestratorTool tool;
  final Color color;
  final double strokeWidth;
  final List<Offset> points;
  final bool isClosed;

  TelestratorPath({
    required this.id,
    required this.tool,
    required this.color,
    required this.strokeWidth,
    required this.points,
    this.isClosed = false,
  });

  TelestratorPath copyWith({
    String? id,
    TelestratorTool? tool,
    Color? color,
    double? strokeWidth,
    List<Offset>? points,
    bool? isClosed,
  }) {
    return TelestratorPath(
      id: id ?? this.id,
      tool: tool ?? this.tool,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      points: points ?? this.points,
      isClosed: isClosed ?? this.isClosed,
    );
  }
}
