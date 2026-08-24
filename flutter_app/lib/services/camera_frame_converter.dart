import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class CameraFrameConverter {
  /// Converts a CameraImage (YUV420, BGRA8888, or NV21) to a crystal-clear compressed JPEG Uint8List
  /// with zero-cost single-pass sensor rotation.
  static Uint8List? convertCameraImageToJpeg(
    CameraImage cameraImage, {
    int quality = 80,
    int strideStep = 1,
    int rotationAngle = 0,
    int? targetWidth,
    int? targetHeight,
  }) {
    try {
      img.Image? converted;

      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        converted = _convertYUV420SinglePass(cameraImage, strideStep: strideStep, rotationAngle: rotationAngle);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        converted = _convertBGRA8888SinglePass(cameraImage, strideStep: strideStep, rotationAngle: rotationAngle);
      } else if (cameraImage.format.group == ImageFormatGroup.nv21) {
        converted = _convertNV21SinglePass(cameraImage, strideStep: strideStep, rotationAngle: rotationAngle);
      } else {
        converted = _convertGenericYuv(cameraImage);
      }

      if (converted == null) return null;

      // Optional resize if requested
      if (targetWidth != null && targetHeight != null && (converted.width > targetWidth || converted.height > targetHeight)) {
        converted = img.copyResize(converted, width: targetWidth, height: targetHeight, interpolation: img.Interpolation.linear);
      }

      return Uint8List.fromList(img.encodeJpg(converted, quality: quality));
    } catch (e) {
      debugPrint('Camera frame conversion error: $e');
      return null;
    }
  }

  /// High-accuracy, fast Android YUV420 to RGB conversion with single-pass rotation (0ms extra cost)
  static img.Image _convertYUV420SinglePass(
    CameraImage image, {
    int strideStep = 1,
    int rotationAngle = 0,
  }) {
    final int origWidth = image.width;
    final int origHeight = image.height;

    final int width = origWidth ~/ strideStep;
    final int height = origHeight ~/ strideStep;

    final bool isRotated = (rotationAngle == 90 || rotationAngle == 270);
    final int outW = isRotated ? height : width;
    final int outH = isRotated ? width : height;

    final img.Image rgbImage = img.Image(width: outW, height: outH);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel ?? 1;

    final int uRowStride = uPlane.bytesPerRow;
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;

    final int vRowStride = vPlane.bytesPerRow;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (int inY = 0; inY < height; inY++) {
      final int actualY = inY * strideStep;
      final int uvh = actualY >> 1;
      final int yRowOffset = actualY * yRowStride;
      final int uRowOffset = uvh * uRowStride;
      final int vRowOffset = uvh * vRowStride;

      for (int inX = 0; inX < width; inX++) {
        final int actualX = inX * strideStep;
        final int uvw = actualX >> 1;

        final int yIndex = yRowOffset + (actualX * yPixelStride);
        final int uIndex = uRowOffset + (uvw * uPixelStride);
        final int vIndex = vRowOffset + (uvw * vPixelStride);

        if (yIndex >= yBytes.length || uIndex >= uBytes.length || vIndex >= vBytes.length) {
          continue;
        }

        final int y = yBytes[yIndex];
        final int u = uBytes[uIndex] - 128;
        final int v = vBytes[vIndex] - 128;

        // Accurate integer BT.601 full-range calculation
        final int r = (y + ((359 * v) >> 8)).clamp(0, 255);
        final int g = (y - ((88 * u + 183 * v) >> 8)).clamp(0, 255);
        final int b = (y + ((454 * u) >> 8)).clamp(0, 255);

        // Compute rotated target coordinates in single pass
        int targetX;
        int targetY;

        if (rotationAngle == 90) {
          targetX = height - 1 - inY;
          targetY = inX;
        } else if (rotationAngle == 270) {
          targetX = inY;
          targetY = width - 1 - inX;
        } else if (rotationAngle == 180) {
          targetX = width - 1 - inX;
          targetY = height - 1 - inY;
        } else {
          targetX = inX;
          targetY = inY;
        }

        rgbImage.setPixelRgb(targetX, targetY, r, g, b);
      }
    }

    return rgbImage;
  }

  /// Fast iOS BGRA8888 single-pass conversion
  static img.Image _convertBGRA8888SinglePass(
    CameraImage image, {
    int strideStep = 1,
    int rotationAngle = 0,
  }) {
    final int width = image.width ~/ strideStep;
    final int height = image.height ~/ strideStep;
    final bytes = image.planes[0].bytes;
    final int origW = image.width;

    final bool isRotated = (rotationAngle == 90 || rotationAngle == 270);
    final int outW = isRotated ? height : width;
    final int outH = isRotated ? width : height;
    final img.Image out = img.Image(width: outW, height: outH);

    for (int inY = 0; inY < height; inY++) {
      final int actualY = inY * strideStep;
      for (int inX = 0; inX < width; inX++) {
        final int actualX = inX * strideStep;
        final int idx = (actualY * origW + actualX) * 4;

        if (idx + 3 < bytes.length) {
          final b = bytes[idx];
          final g = bytes[idx + 1];
          final r = bytes[idx + 2];

          int targetX = inX;
          int targetY = inY;
          if (rotationAngle == 90) {
            targetX = height - 1 - inY;
            targetY = inX;
          } else if (rotationAngle == 270) {
            targetX = inY;
            targetY = width - 1 - inX;
          } else if (rotationAngle == 180) {
            targetX = width - 1 - inX;
            targetY = height - 1 - inY;
          }

          out.setPixelRgb(targetX, targetY, r, g, b);
        }
      }
    }
    return out;
  }

  /// Fast NV21 single-pass conversion
  static img.Image _convertNV21SinglePass(
    CameraImage image, {
    int strideStep = 1,
    int rotationAngle = 0,
  }) {
    final int width = image.width ~/ strideStep;
    final int height = image.height ~/ strideStep;

    final bool isRotated = (rotationAngle == 90 || rotationAngle == 270);
    final int outW = isRotated ? height : width;
    final int outH = isRotated ? width : height;
    final img.Image rgbImage = img.Image(width: outW, height: outH);

    final yPlane = image.planes[0];
    final vuPlane = image.planes[1];

    final yBytes = yPlane.bytes;
    final vuBytes = vuPlane.bytes;
    final int origW = image.width;

    for (int inY = 0; inY < height; inY++) {
      final int actualY = inY * strideStep;
      for (int inX = 0; inX < width; inX++) {
        final int actualX = inX * strideStep;
        final int yIndex = actualY * origW + actualX;
        final int vuIndex = (actualY ~/ 2) * origW + (actualX & ~1);

        if (yIndex < yBytes.length && vuIndex + 1 < vuBytes.length) {
          final int y = yBytes[yIndex];
          final int v = vuBytes[vuIndex] - 128;
          final int u = vuBytes[vuIndex + 1] - 128;

          final int r = (y + ((359 * v) >> 8)).clamp(0, 255);
          final int g = (y - ((88 * u + 183 * v) >> 8)).clamp(0, 255);
          final int b = (y + ((454 * u) >> 8)).clamp(0, 255);

          int targetX = inX;
          int targetY = inY;
          if (rotationAngle == 90) {
            targetX = height - 1 - inY;
            targetY = inX;
          } else if (rotationAngle == 270) {
            targetX = inY;
            targetY = width - 1 - inX;
          } else if (rotationAngle == 180) {
            targetX = width - 1 - inX;
            targetY = height - 1 - inY;
          }

          rgbImage.setPixelRgb(targetX, targetY, r, g, b);
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
