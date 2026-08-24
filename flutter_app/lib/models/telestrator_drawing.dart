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
  final Duration relativeTime;

  TelestratorPoint(this.offset, {this.relativeTime = Duration.zero});
}

class TelestratorPath {
  final String id;
  final TelestratorTool tool;
  final Color color;
  final double strokeWidth;
  final List<Offset> points;
  final List<Duration> pointOffsets;
  final int? frameIndex;
  final bool isClosed;

  TelestratorPath({
    required this.id,
    required this.tool,
    required this.color,
    required this.strokeWidth,
    required this.points,
    List<Duration>? pointOffsets,
    this.frameIndex,
    this.isClosed = false,
  }) : pointOffsets = pointOffsets ?? List.filled(points.length, Duration.zero);

  TelestratorPath copyWith({
    String? id,
    TelestratorTool? tool,
    Color? color,
    double? strokeWidth,
    List<Offset>? points,
    List<Duration>? pointOffsets,
    int? frameIndex,
    bool? isClosed,
  }) {
    return TelestratorPath(
      id: id ?? this.id,
      tool: tool ?? this.tool,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      points: points ?? this.points,
      pointOffsets: pointOffsets ?? this.pointOffsets,
      frameIndex: frameIndex ?? this.frameIndex,
      isClosed: isClosed ?? this.isClosed,
    );
  }

  /// Returns a sub-path trimmed to a progressive fraction (0.0 to 1.0) for Slow Draw animation
  TelestratorPath trimProgress(double progress) {
    if (points.isEmpty || progress >= 1.0) return this;
    if (progress <= 0.0) return copyWith(points: [], pointOffsets: []);

    final count = (points.length * progress).ceil().clamp(1, points.length);
    return copyWith(
      points: points.sublist(0, count),
      pointOffsets: pointOffsets.length >= count ? pointOffsets.sublist(0, count) : [],
    );
  }
}
