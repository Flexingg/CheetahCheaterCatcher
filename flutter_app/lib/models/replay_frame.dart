import 'dart:typed_data';

class ReplayFrame {
  final int frameIndex;
  final DateTime timestamp;
  final Uint8List jpegBytes;
  final int width;
  final int height;

  ReplayFrame({
    required this.frameIndex,
    required this.timestamp,
    required this.jpegBytes,
    this.width = 640,
    this.height = 480,
  });

  Duration get age => DateTime.now().difference(timestamp);
}
