import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class CameraFrameConverter {
  /// Converts a CameraImage (YUV420 or BGRA8888) to a compressed JPEG Uint8List
  static Uint8List? convertCameraImageToJpeg(
    CameraImage cameraImage, {
    int quality = 60,
    int? targetWidth,
    int? targetHeight,
  }) {
    try {
      img.Image? converted;

      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        converted = _convertYUV420ToImage(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        converted = _convertBGRA8888ToImage(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.nv21) {
        converted = _convertNV21ToImage(cameraImage);
      } else {
        // Fallback for planes
        converted = _convertGenericYuv(cameraImage);
      }

      if (converted == null) return null;

      // Optional resize if needed for higher network throughput
      if (targetWidth != null && targetHeight != null && (converted.width > targetWidth || converted.height > targetHeight)) {
        converted = img.copyResize(converted, width: targetWidth, height: targetHeight);
      }

      return Uint8List.fromList(img.encodeJpg(converted, quality: quality));
    } catch (e) {
      debugPrint('Camera frame conversion error: $e');
      return null;
    }
  }

  /// Fast Android YUV420 to RGB Image conversion
  static img.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final img.Image rgbImage = img.Image(width: width, height: height);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel ?? 1;

    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int h = 0; h < height; h++) {
      final int uvh = h >> 1;
      for (int w = 0; w < width; w++) {
        final int uvw = w >> 1;

        final int yIndex = (h * yRowStride) + (w * yPixelStride);
        final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

        if (yIndex >= yBytes.length || uvIndex >= uBytes.length || uvIndex >= vBytes.length) {
          continue;
        }

        final int y = yBytes[yIndex];
        final int u = uBytes[uvIndex];
        final int v = vBytes[uvIndex];

        // Standard YUV to RGB formula
        int r = (y + (1.370705 * (v - 128))).round().clamp(0, 255);
        int g = (y - (0.337633 * (u - 128)) - (0.698001 * (v - 128))).round().clamp(0, 255);
        int b = (y + (1.732446 * (u - 128))).round().clamp(0, 255);

        rgbImage.setPixelRgb(w, h, r, g, b);
      }
    }

    return rgbImage;
  }

  /// iOS BGRA8888 to Image conversion
  static img.Image _convertBGRA8888ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final bytes = image.planes[0].bytes;

    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  /// Android NV21 format
  static img.Image _convertNV21ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image rgbImage = img.Image(width: width, height: height);

    final yPlane = image.planes[0];
    final vuPlane = image.planes[1];

    final yBytes = yPlane.bytes;
    final vuBytes = vuPlane.bytes;

    for (int h = 0; h < height; h++) {
      for (int w = 0; w < width; w++) {
        final int yIndex = h * width + w;
        final int vuIndex = (h ~/ 2) * width + (w & ~1);

        if (yIndex < yBytes.length && vuIndex + 1 < vuBytes.length) {
          final int y = yBytes[yIndex];
          final int v = vuBytes[vuIndex];
          final int u = vuBytes[vuIndex + 1];

          int r = (y + 1.402 * (v - 128)).round().clamp(0, 255);
          int g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).round().clamp(0, 255);
          int b = (y + 1.772 * (u - 128)).round().clamp(0, 255);

          rgbImage.setPixelRgb(w, h, r, g, b);
        }
      }
    }

    return rgbImage;
  }

  static img.Image? _convertGenericYuv(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final int width = image.width;
    final int height = image.height;
    final img.Image rgbImage = img.Image(width: width, height: height);

    final yBytes = image.planes[0].bytes;
    for (int h = 0; h < height; h++) {
      for (int w = 0; w < width; w++) {
        final idx = h * width + w;
        if (idx < yBytes.length) {
          final y = yBytes[idx];
          rgbImage.setPixelRgb(w, h, y, y, y);
        }
      }
    }
    return rgbImage;
  }
}
