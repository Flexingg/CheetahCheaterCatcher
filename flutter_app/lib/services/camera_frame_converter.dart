import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class CameraFrameConverter {
  /// Converts a CameraImage (YUV420 or BGRA8888) to a crystal-clear compressed JPEG Uint8List
  static Uint8List? convertCameraImageToJpeg(
    CameraImage cameraImage, {
    int quality = 85,
    int strideStep = 1,
    int rotationAngle = 0,
    int? targetWidth,
    int? targetHeight,
  }) {
    try {
      img.Image? converted;

      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        converted = _convertYUV420Accurate(cameraImage, strideStep: strideStep);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        converted = _convertBGRA8888Fast(cameraImage, strideStep: strideStep);
      } else if (cameraImage.format.group == ImageFormatGroup.nv21) {
        converted = _convertNV21Accurate(cameraImage, strideStep: strideStep);
      } else {
        converted = _convertGenericYuv(cameraImage);
      }

      if (converted == null) return null;

      // Rotate image upright if sensor has rotation angle (e.g. 90 on Android back camera)
      if (rotationAngle != 0) {
        converted = img.copyRotate(converted, angle: rotationAngle);
      }

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

  /// High-accuracy, fast Android YUV420 to RGB conversion with individual plane strides
  static img.Image _convertYUV420Accurate(CameraImage image, {int strideStep = 1}) {
    final int origWidth = image.width;
    final int origHeight = image.height;

    final int width = origWidth ~/ strideStep;
    final int height = origHeight ~/ strideStep;

    final img.Image rgbImage = img.Image(width: width, height: height);

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

    for (int outY = 0; outY < height; outY++) {
      final int inY = outY * strideStep;
      final int uvh = inY >> 1;
      final int yRowOffset = inY * yRowStride;
      final int uRowOffset = uvh * uRowStride;
      final int vRowOffset = uvh * vRowStride;

      for (int outX = 0; outX < width; outX++) {
        final int inX = outX * strideStep;
        final int uvw = inX >> 1;

        final int yIndex = yRowOffset + (inX * yPixelStride);
        final int uIndex = uRowOffset + (uvw * uPixelStride);
        final int vIndex = vRowOffset + (uvw * vPixelStride);

        if (yIndex >= yBytes.length || uIndex >= uBytes.length || vIndex >= vBytes.length) {
          continue;
        }

        final int y = yBytes[yIndex];
        final int u = uBytes[uIndex] - 128;
        final int v = vBytes[vIndex] - 128;

        // Accurate BT.601 full-range integer calculation
        final int r = (y + ((359 * v) >> 8)).clamp(0, 255);
        final int g = (y - ((88 * u + 183 * v) >> 8)).clamp(0, 255);
        final int b = (y + ((454 * u) >> 8)).clamp(0, 255);

        rgbImage.setPixelRgb(outX, outY, r, g, b);
      }
    }

    return rgbImage;
  }

  /// Fast iOS BGRA8888 to Image conversion
  static img.Image _convertBGRA8888Fast(CameraImage image, {int strideStep = 1}) {
    final int width = image.width;
    final int height = image.height;
    final bytes = image.planes[0].bytes;

    if (strideStep <= 1) {
      return img.Image.fromBytes(
        width: width,
        height: height,
        bytes: bytes.buffer,
        order: img.ChannelOrder.bgra,
      );
    }

    final int outW = width ~/ strideStep;
    final int outH = height ~/ strideStep;
    final img.Image out = img.Image(width: outW, height: outH);

    for (int y = 0; y < outH; y++) {
      final int inY = y * strideStep;
      for (int x = 0; x < outW; x++) {
        final int inX = x * strideStep;
        final int idx = (inY * width + inX) * 4;
        if (idx + 3 < bytes.length) {
          final b = bytes[idx];
          final g = bytes[idx + 1];
          final r = bytes[idx + 2];
          out.setPixelRgb(x, y, r, g, b);
        }
      }
    }
    return out;
  }

  /// Fast NV21
  static img.Image _convertNV21Accurate(CameraImage image, {int strideStep = 1}) {
    final int width = image.width ~/ strideStep;
    final int height = image.height ~/ strideStep;
    final img.Image rgbImage = img.Image(width: width, height: height);

    final yPlane = image.planes[0];
    final vuPlane = image.planes[1];

    final yBytes = yPlane.bytes;
    final vuBytes = vuPlane.bytes;
    final int origW = image.width;

    for (int outY = 0; outY < height; outY++) {
      final int inY = outY * strideStep;
      for (int outX = 0; outX < width; outX++) {
        final int inX = outX * strideStep;
        final int yIndex = inY * origW + inX;
        final int vuIndex = (inY ~/ 2) * origW + (inX & ~1);

        if (yIndex < yBytes.length && vuIndex + 1 < vuBytes.length) {
          final int y = yBytes[yIndex];
          final int v = vuBytes[vuIndex] - 128;
          final int u = vuBytes[vuIndex + 1] - 128;

          final int r = (y + ((359 * v) >> 8)).clamp(0, 255);
          final int g = (y - ((88 * u + 183 * v) >> 8)).clamp(0, 255);
          final int b = (y + ((454 * u) >> 8)).clamp(0, 255);

          rgbImage.setPixelRgb(outX, outY, r, g, b);
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
