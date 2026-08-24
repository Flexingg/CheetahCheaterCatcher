import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../models/telestrator_drawing.dart';
import '../../state/telestrator_provider.dart';

class TelestratorCanvasWidget extends StatelessWidget {
  const TelestratorCanvasWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final telestrator = context.watch<TelestratorProvider>();

    return Stack(
      children: [
        // Touch & Draw Layer
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !telestrator.isDrawingEnabled,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) => telestrator.onPanStart(details.localPosition),
              onPanUpdate: (details) => telestrator.onPanUpdate(details.localPosition),
              onPanEnd: (_) => telestrator.onPanEnd(),
              child: CustomPaint(
                painter: _TelestratorPainter(
                  paths: telestrator.visiblePaths,
                  activePath: telestrator.currentDrawingPath,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),

        // Floating Telestrator Toolbar (when drawing mode is ON)
        if (telestrator.isDrawingEnabled)
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: _buildFloatingToolbar(context, telestrator),
          ),
      ],
    );
  }

  Widget _buildFloatingToolbar(BuildContext context, TelestratorProvider telestrator) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: JokarzColors.surface.withAlpha(240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JokarzColors.gold.withAlpha(150), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(180),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tools & Action Row
          Row(
            children: [
              // Tool Selector Pills
              _buildToolButton(
                icon: Icons.edit,
                tooltip: 'Pen',
                isSelected: telestrator.currentTool == TelestratorTool.pen,
                onTap: () => telestrator.setTool(TelestratorTool.pen),
              ),
              const SizedBox(width: 4),
              _buildToolButton(
                icon: Icons.arrow_right_alt,
                tooltip: 'Arrow',
                isSelected: telestrator.currentTool == TelestratorTool.arrow,
                onTap: () => telestrator.setTool(TelestratorTool.arrow),
              ),
              const SizedBox(width: 4),
              _buildToolButton(
                icon: Icons.radio_button_unchecked,
                tooltip: 'Circle / Chip',
                isSelected: telestrator.currentTool == TelestratorTool.circle,
                onTap: () => telestrator.setTool(TelestratorTool.circle),
              ),
              const SizedBox(width: 4),
              _buildToolButton(
                icon: Icons.horizontal_rule,
                tooltip: 'Line',
                isSelected: telestrator.currentTool == TelestratorTool.line,
                onTap: () => telestrator.setTool(TelestratorTool.line),
              ),
              const SizedBox(width: 4),
              _buildToolButton(
                icon: Icons.highlight,
                tooltip: 'Highlighter',
                isSelected: telestrator.currentTool == TelestratorTool.highlighter,
                onTap: () => telestrator.setTool(TelestratorTool.highlighter),
              ),
              const Spacer(),

              // Feature #5: Slow Draw / Animate Markup Button
              IconButton(
                icon: const Icon(Icons.auto_awesome, size: 20),
                color: telestrator.paths.isNotEmpty ? JokarzColors.gold : JokarzColors.textMuted,
                onPressed: telestrator.paths.isNotEmpty ? telestrator.playSlowDrawAnimation : null,
                tooltip: 'Slow Draw / Animate Markup (#5)',
                visualDensity: VisualDensity.compact,
              ),

              // Undo
              IconButton(
                icon: const Icon(Icons.undo, size: 20),
                color: telestrator.canUndo ? JokarzColors.textPrimary : JokarzColors.textMuted,
                onPressed: telestrator.canUndo ? telestrator.undo : null,
                tooltip: 'Undo',
                visualDensity: VisualDensity.compact,
              ),

              // Clear All
              IconButton(
                icon: const Icon(Icons.delete_sweep, size: 22),
                color: JokarzColors.crimson,
                onPressed: telestrator.clearAll,
                tooltip: 'Clear Markup',
                visualDensity: VisualDensity.compact,
              ),

              // Close / Done
              IconButton(
                icon: const Icon(Icons.check_circle, size: 24),
                color: JokarzColors.emerald,
                onPressed: () => telestrator.setDrawingEnabled(false),
                tooltip: 'Exit Telestrator',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Color Palette Swatches
          Row(
            children: [
              ...JokarzColors.telestratorPalette.map((c) {
                final isSelected = telestrator.currentColor == c;
                return GestureDetector(
                  onTap: () => telestrator.setColor(c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: c.withAlpha(200),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const Spacer(),
              // Stroke Width Indicator
              Text(
                'Size: ${telestrator.strokeWidth.toInt()}px',
                style: const TextStyle(fontSize: 11, color: JokarzColors.textSecondary),
              ),
              SizedBox(
                width: 90,
                child: Slider(
                  value: telestrator.strokeWidth,
                  min: 2,
                  max: 16,
                  activeColor: telestrator.currentColor,
                  inactiveColor: JokarzColors.surfaceLight,
                  onChanged: (val) => telestrator.setStrokeWidth(val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected ? JokarzColors.gold : JokarzColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.black : JokarzColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _TelestratorPainter extends CustomPainter {
  final List<TelestratorPath> paths;
  final TelestratorPath? activePath;

  _TelestratorPainter({
    required this.paths,
    this.activePath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in paths) {
      _drawPath(canvas, p);
    }
    if (activePath != null) {
      _drawPath(canvas, activePath!);
    }
  }

  void _drawPath(Canvas canvas, TelestratorPath item) {
    if (item.points.isEmpty) return;

    final isHighlighter = item.tool == TelestratorTool.highlighter;
    final paint = Paint()
      ..color = isHighlighter ? item.color.withAlpha(120) : item.color
      ..strokeWidth = isHighlighter ? item.strokeWidth * 2.5 : item.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Glowing shadow for Vegas sports broadcast feel
    if (!isHighlighter) {
      final shadowPaint = Paint()
        ..color = Colors.black.withAlpha(160)
        ..strokeWidth = item.strokeWidth + 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      _renderGeometry(canvas, item, shadowPaint);
    }

    _renderGeometry(canvas, item, paint);
  }

  void _renderGeometry(Canvas canvas, TelestratorPath item, Paint paint) {
    switch (item.tool) {
      case TelestratorTool.pen:
      case TelestratorTool.highlighter:
        final path = Path();
        path.moveTo(item.points.first.dx, item.points.first.dy);
        for (int i = 1; i < item.points.length; i++) {
          path.lineTo(item.points[i].dx, item.points[i].dy);
        }
        canvas.drawPath(path, paint);
        break;

      case TelestratorTool.line:
        if (item.points.length >= 2) {
          canvas.drawLine(item.points.first, item.points.last, paint);
        }
        break;

      case TelestratorTool.circle:
        if (item.points.length >= 2) {
          final start = item.points.first;
          final end = item.points.last;
          final rect = Rect.fromPoints(start, end);
          canvas.drawOval(rect, paint);
        }
        break;

      case TelestratorTool.arrow:
        if (item.points.length >= 2) {
          final start = item.points.first;
          final end = item.points.last;
          canvas.drawLine(start, end, paint);

          // Draw arrowhead
          final dx = end.dx - start.dx;
          final dy = end.dy - start.dy;
          final angle = math.atan2(dy, dx);
          const arrowSize = 18.0;
          const arrowAngle = math.pi / 6;

          final p1 = Offset(
            end.dx - arrowSize * math.cos(angle - arrowAngle),
            end.dy - arrowSize * math.sin(angle - arrowAngle),
          );
          final p2 = Offset(
            end.dx - arrowSize * math.cos(angle + arrowAngle),
            end.dy - arrowSize * math.sin(angle + arrowAngle),
          );

          final arrowHeadPath = Path()
            ..moveTo(end.dx, end.dy)
            ..lineTo(p1.dx, p1.dy)
            ..moveTo(end.dx, end.dy)
            ..lineTo(p2.dx, p2.dy);

          canvas.drawPath(arrowHeadPath, paint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _TelestratorPainter oldDelegate) => true;
}
