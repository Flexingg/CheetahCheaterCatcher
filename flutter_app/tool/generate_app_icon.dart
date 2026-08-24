// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  final image = img.Image(width: size, height: size);

  // Colors
  final bg = img.ColorRgba8(13, 17, 23, 255); // Midnight Obsidian #0D1117
  final cardBg = img.ColorRgba8(22, 27, 34, 255); // #161B22
  final gold = img.ColorRgba8(255, 179, 0, 255); // #FFB300
  final emerald = img.ColorRgba8(0, 230, 118, 255); // #00E676
  final crimson = img.ColorRgba8(255, 51, 102, 255); // #FF3366
  final white = img.ColorRgba8(240, 246, 252, 255);

  // Fill background
  img.fill(image, color: bg);

  // Draw Poker Card Outline (Rounded Rectangle)
  final cardLeft = 112;
  final cardTop = 80;
  final cardRight = size - 112;
  final cardBottom = size - 80;

  // Fill Card Area
  for (int y = cardTop; y <= cardBottom; y++) {
    for (int x = cardLeft; x <= cardRight; x++) {
      image.setPixel(x, y, cardBg);
    }
  }

  // Draw Card Outer Gold Border
  for (int w = 0; w < 16; w++) {
    img.drawRect(
      image,
      x1: cardLeft + w,
      y1: cardTop + w,
      x2: cardRight - w,
      y2: cardBottom - w,
      color: gold,
    );
  }

  // Draw Card Inner Trim
  for (int w = 0; w < 4; w++) {
    img.drawRect(
      image,
      x1: cardLeft + 32 + w,
      y1: cardTop + 32 + w,
      x2: cardRight - 32 - w,
      y2: cardBottom - 32 - w,
      color: gold,
    );
  }

  // Center Emblem: Diamond Shape
  final centerX = size ~/ 2;
  final centerY = size ~/ 2;
  final diamondSize = 220;

  for (int dy = -diamondSize; dy <= diamondSize; dy++) {
    final span = ((diamondSize - dy.abs()) * 0.85).round();
    for (int dx = -span; dx <= span; dx++) {
      final dist = (dx.abs() + dy.abs()).toDouble() / diamondSize;
      if (dist <= 0.95) {
        // Gradient from crimson to emerald
        final r = (255 * (1.0 - dist * 0.5)).round().clamp(0, 255);
        final g = (179 * dist).round().clamp(0, 255);
        final b = (102 * dist).round().clamp(0, 255);
        image.setPixel(centerX + dx, centerY + dy, img.ColorRgba8(r, g, b, 255));
      }
    }
  }

  // Draw Center Gold Ring
  img.drawCircle(image, x: centerX, y: centerY, radius: 140, color: gold);
  img.drawCircle(image, x: centerX, y: centerY, radius: 142, color: gold);
  img.drawCircle(image, x: centerX, y: centerY, radius: 144, color: gold);

  // Corner Suit Badges & Letter 'J' for Joker
  // Top-Left J
  _drawBlockLetterJ(image, cardLeft + 60, cardTop + 60, gold, 3);
  _drawBlockSuitSpade(image, cardLeft + 72, cardTop + 140, crimson, 3);

  // Bottom-Right J (Inverted position)
  _drawBlockLetterJ(image, cardRight - 100, cardBottom - 180, gold, 3);
  _drawBlockSuitSpade(image, cardRight - 88, cardBottom - 100, emerald, 3);

  // Top-Right & Bottom-Left Suit accents
  _drawBlockSuitSpade(image, cardRight - 88, cardTop + 80, gold, 2);
  _drawBlockSuitSpade(image, cardLeft + 72, cardBottom - 120, gold, 2);

  // Center Crown / Joker Hat Triangles
  _drawCrownTriangles(image, centerX, centerY - 20, white, gold);

  // Save Icon
  final dir = Directory('assets/icon');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final pngBytes = img.encodePng(image);
  File('assets/icon/app_icon.png').writeAsBytesSync(pngBytes);
  print('Generated luxury Joker card app icon: assets/icon/app_icon.png (${pngBytes.length} bytes)');
}

void _drawBlockLetterJ(img.Image image, int startX, int startY, img.Color color, int scale) {
  // Simple bold 5x7 block font for 'J'
  const jPattern = [
    [0, 1, 1, 1, 1],
    [0, 0, 0, 1, 0],
    [0, 0, 0, 1, 0],
    [0, 0, 0, 1, 0],
    [1, 0, 0, 1, 0],
    [1, 0, 0, 1, 0],
    [0, 1, 1, 0, 0],
  ];

  for (int r = 0; r < jPattern.length; r++) {
    for (int c = 0; c < jPattern[r].length; c++) {
      if (jPattern[r][c] == 1) {
        for (int dy = 0; dy < scale * 4; dy++) {
          for (int dx = 0; dx < scale * 4; dx++) {
            image.setPixel(startX + (c * scale * 4) + dx, startY + (r * scale * 4) + dy, color);
          }
        }
      }
    }
  }
}

void _drawBlockSuitSpade(img.Image image, int centerX, int centerY, img.Color color, int scale) {
  img.fillCircle(image, x: centerX, y: centerY, radius: scale * 6, color: color);
}

void _drawCrownTriangles(img.Image image, int centerX, int centerY, img.Color white, img.Color gold) {
  // Draw 3 peaks of the Joker's crown / jester points
  for (int y = -60; y <= 60; y++) {
    for (int x = -100; x <= 100; x++) {
      // 3 peaks: left, center, right
      final inCenterPeak = (y >= (x.abs() * 0.8) - 40) && y <= 40;
      final inLeftPeak = (y >= ((x + 60).abs() * 0.9) - 30) && y <= 40;
      final inRightPeak = (y >= ((x - 60).abs() * 0.9) - 30) && y <= 40;

      if (inCenterPeak || inLeftPeak || inRightPeak) {
        image.setPixel(centerX + x, centerY + y, gold);
      }
    }
  }

  // Jester bells on crown points
  img.fillCircle(image, x: centerX, y: centerY - 50, radius: 14, color: white);
  img.fillCircle(image, x: centerX - 60, y: centerY - 40, radius: 12, color: white);
  img.fillCircle(image, x: centerX + 60, y: centerY - 40, radius: 12, color: white);
}
