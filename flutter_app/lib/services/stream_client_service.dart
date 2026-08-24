import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/camera_device_info.dart';

typedef FrameCallback = void Function(Uint8List frame);

class StreamClientService {
  WebSocket? _binaryStreamSocket;
  http.Client? _httpClient;
  WebSocket? _controlSocket;
  StreamSubscription? _streamSubscription;
  Timer? _reconnectTimer;
  Timer? _fpsTimer;

  bool _isConnected = false;
  CameraDeviceInfo? _connectedDevice;
  int _receivedFramesCount = 0;
  int _currentFps = 0;

  final StreamController<Uint8List> _frameStreamController =
      StreamController<Uint8List>.broadcast();
  final StreamController<Map<String, dynamic>> _telemetryController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Uint8List> get frameStream => _frameStreamController.stream;
  Stream<Map<String, dynamic>> get telemetryStream => _telemetryController.stream;
  bool get isConnected => _isConnected;
  int get currentFps => _currentFps;
  CameraDeviceInfo? get connectedDevice => _connectedDevice;

  /// Connect to camera device using ultra-low latency binary WebSocket (with HTTP MJPEG fallback)
  Future<void> connect(CameraDeviceInfo device) async {
    disconnect();
    _connectedDevice = device;

    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _currentFps = _receivedFramesCount;
      _receivedFramesCount = 0;
    });

    _connectBinaryWsStream(device);
    _connectControlWs(device);
  }

  void _connectBinaryWsStream(CameraDeviceInfo device) async {
    final wsStreamUrl = 'ws://${device.ip}:${device.streamPort}/ws/live';
    debugPrint('[StreamClient] Connecting to binary stream at $wsStreamUrl');

    try {
      _binaryStreamSocket = await WebSocket.connect(wsStreamUrl).timeout(
        const Duration(seconds: 4),
      );
      _isConnected = true;
      debugPrint('[StreamClient] Connected to binary live WebSocket!');

      _binaryStreamSocket?.listen(
        (data) {
          if (data is List<int>) {
            _receivedFramesCount++;
            final frameBytes = data is Uint8List ? data : Uint8List.fromList(data);
            _frameStreamController.add(frameBytes);
          } else if (data is String) {
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              _telemetryController.add(json);
            } catch (_) {}
          }
        },
        onDone: () {
          debugPrint('[StreamClient] Binary WS stream closed, falling back to HTTP...');
          _binaryStreamSocket = null;
          _handleStreamDrop();
        },
        onError: (err) {
          debugPrint('[StreamClient] Binary WS error: $err');
          _binaryStreamSocket = null;
          _handleStreamDrop();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[StreamClient] WS connection failed ($e), falling back to HTTP MJPEG...');
      _connectHttpStream(device);
    }
  }

  void _connectHttpStream(CameraDeviceInfo device) async {
    try {
      _httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(device.streamUrl));
      request.headers['Connection'] = 'keep-alive';
      request.headers['Accept'] = '*/*';

      final response = await _httpClient!.send(request);

      if (response.statusCode == 200) {
        _isConnected = true;
        final buffer = BytesBuilder(copy: false);

        _streamSubscription = response.stream.listen(
          (chunk) {
            buffer.add(chunk);
            final currentBytes = buffer.toBytes();

            // Extract frames by boundary or SOI/EOI
            final frames = _extractJpegFrames(currentBytes);
            if (frames.extractedFrames.isNotEmpty) {
              buffer.clear();
              if (frames.lastRemainder.isNotEmpty) {
                buffer.add(frames.lastRemainder);
              }

              for (final frame in frames.extractedFrames) {
                _receivedFramesCount++;
                _frameStreamController.add(frame);
              }
            }
          },
          onError: (err) {
            debugPrint('[StreamClient] HTTP Stream error: $err');
            _handleStreamDrop();
          },
          onDone: () {
            debugPrint('[StreamClient] HTTP Stream finished');
            _handleStreamDrop();
          },
          cancelOnError: true,
        );
      } else {
        _handleStreamDrop();
      }
    } catch (e) {
      debugPrint('[StreamClient] Failed to connect HTTP stream: $e');
      _handleStreamDrop();
    }
  }

  void _connectControlWs(CameraDeviceInfo device) async {
    try {
      _controlSocket = await WebSocket.connect(device.controlWsUrl).timeout(
        const Duration(seconds: 4),
      );
      _controlSocket?.listen((message) {
        if (message is String) {
          try {
            final json = jsonDecode(message) as Map<String, dynamic>;
            _telemetryController.add(json);
          } catch (_) {}
        }
      }, onDone: () {
        _controlSocket = null;
      }, onError: (_) {
        _controlSocket = null;
      });
    } catch (e) {
      debugPrint('WS control connection failed (optional): $e');
    }
  }

  void sendControlCommand(String action, dynamic value) {
    if (_controlSocket != null && _controlSocket?.readyState == WebSocket.open) {
      try {
        final payload = jsonEncode({'action': action, 'value': value});
        _controlSocket?.add(payload);
      } catch (e) {
        debugPrint('Error sending WS control command: $e');
      }
    }
  }

  void toggleRemoteTorch(bool enable) {
    sendControlCommand('torch', enable);
  }

  void setRemoteZoom(double zoom) {
    sendControlCommand('zoom', zoom);
  }

  void flipRemoteCamera() {
    sendControlCommand('flip_camera', true);
  }

  void _handleStreamDrop() {
    _isConnected = false;
    _reconnectTimer?.cancel();
    if (_connectedDevice != null) {
      _reconnectTimer = Timer(const Duration(seconds: 2), () {
        if (_connectedDevice != null && !_isConnected) {
          debugPrint('Attempting stream reconnection...');
          _connectBinaryWsStream(_connectedDevice!);
        }
      });
    }
  }

  static _JpegExtractionResult _extractJpegFrames(Uint8List data) {
    final frames = <Uint8List>[];
    int start = -1;

    for (int i = 0; i < data.length - 1; i++) {
      // SOI: 0xFF, 0xD8
      if (data[i] == 0xFF && data[i + 1] == 0xD8) {
        start = i;
      }
      // EOI: 0xFF, 0xD9
      else if (data[i] == 0xFF && data[i + 1] == 0xD9 && start != -1) {
        final end = i + 2;
        frames.add(Uint8List.sublistView(data, start, end));
        start = -1;
      }
    }

    Uint8List remainder = Uint8List(0);
    if (start != -1 && start < data.length) {
      remainder = Uint8List.sublistView(data, start);
    }

    return _JpegExtractionResult(frames, remainder);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _fpsTimer?.cancel();
    _fpsTimer = null;

    try {
      _binaryStreamSocket?.close();
    } catch (_) {}
    _binaryStreamSocket = null;

    _streamSubscription?.cancel();
    _streamSubscription = null;

    _httpClient?.close();
    _httpClient = null;

    try {
      _controlSocket?.close();
    } catch (_) {}
    _controlSocket = null;

    _isConnected = false;
    _connectedDevice = null;
  }

  void dispose() {
    disconnect();
    _frameStreamController.close();
    _telemetryController.close();
  }
}

class _JpegExtractionResult {
  final List<Uint8List> extractedFrames;
  final Uint8List lastRemainder;

  _JpegExtractionResult(this.extractedFrames, this.lastRemainder);
}
