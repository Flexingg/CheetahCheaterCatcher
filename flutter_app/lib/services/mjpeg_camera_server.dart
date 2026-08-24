import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

typedef RemoteCommandHandler = void Function(String action, dynamic value);

class MjpegCameraServer {
  HttpServer? _httpServer;
  HttpServer? _wsControlServer;
  final List<HttpResponse> _mjpegClients = [];
  final List<WebSocket> _binaryWsClients = [];
  final List<WebSocket> _wsControlClients = [];

  Uint8List? _latestFrame;
  int _fpsCounter = 0;
  int _currentFps = 0;
  Timer? _fpsTimer;

  bool _isTorchOn = false;
  double _zoomLevel = 1.0;
  bool _isFrontCamera = false;

  RemoteCommandHandler? onRemoteCommand;

  bool get isRunning => _httpServer != null;
  int get activeViewers => _mjpegClients.length + _binaryWsClients.length;
  int get currentFps => _currentFps;
  bool get isTorchOn => _isTorchOn;
  double get zoomLevel => _zoomLevel;
  bool get isFrontCamera => _isFrontCamera;
  Uint8List? get latestFrame => _latestFrame;

  /// Start HTTP MJPEG and WebSocket servers
  Future<bool> startServer({
    int streamPort = AppConstants.defaultHttpPort,
    int controlPort = AppConstants.defaultControlPort,
  }) async {
    stopServer();
    try {
      // 1. Stream Server (handles both HTTP MJPEG & binary WebSockets /ws/live)
      _httpServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        streamPort,
        shared: true,
      );
      _httpServer?.listen(_handleHttpRequest);

      // 2. Control Server (handles remote torch, zoom, alerts)
      _wsControlServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        controlPort,
        shared: true,
      );
      _wsControlServer?.listen(_handleWsControlRequest);

      // FPS tracking
      _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _currentFps = _fpsCounter;
        _fpsCounter = 0;
        _broadcastTelemetry();
      });

      debugPrint('Jokarz Camera Server listening on :$streamPort (Stream) and :$controlPort (Control)');
      return true;
    } catch (e) {
      debugPrint('Failed to start camera server: $e');
      stopServer();
      return false;
    }
  }

  void _handleHttpRequest(HttpRequest request) async {
    final path = request.uri.path;

    // Set CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    // Binary WebSocket Live Stream (Ultra-low latency <100ms)
    if (path == '/ws/live' || path == '/ws/stream' || WebSocketTransformer.isUpgradeRequest(request)) {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        try {
          final ws = await WebSocketTransformer.upgrade(request);
          _binaryWsClients.add(ws);
          debugPrint('[CameraServer] Binary WebSocket client connected (Total: ${_binaryWsClients.length})');

          // Send immediate latest frame if available
          if (_latestFrame != null) {
            ws.add(_latestFrame!);
          }

          ws.listen(
            (data) {},
            onDone: () {
              _binaryWsClients.remove(ws);
              debugPrint('[CameraServer] Binary WS client disconnected');
            },
            onError: (_) {
              _binaryWsClients.remove(ws);
            },
            cancelOnError: true,
          );
          return;
        } catch (e) {
          debugPrint('WS Upgrade error: $e');
        }
      }
    }

    if (path == '/live') {
      // Standard HTTP Multipart MJPEG stream
      final response = request.response;
      response.statusCode = HttpStatus.ok;
      response.headers.set(
        'Content-Type',
        'multipart/x-mixed-replace; boundary=--frame',
      );
      response.headers.set('Cache-Control', 'no-cache, private');
      response.headers.set('Connection', 'close');

      _mjpegClients.add(response);

      // If client disconnects
      response.done.then((_) {
        _mjpegClients.remove(response);
      }).catchError((_) {
        _mjpegClients.remove(response);
      });
    } else if (path == '/snapshot') {
      final response = request.response;
      if (_latestFrame != null) {
        response.statusCode = HttpStatus.ok;
        response.headers.contentType = ContentType('image', 'jpeg');
        response.add(_latestFrame!);
      } else {
        response.statusCode = HttpStatus.notFound;
      }
      await response.close();
    } else if (path == '/status') {
      final response = request.response;
      response.statusCode = HttpStatus.ok;
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode({
        'status': 'online',
        'viewers': activeViewers,
        'fps': _currentFps,
        'torch': _isTorchOn,
        'zoom': _zoomLevel,
        'frontCamera': _isFrontCamera,
      }));
      await response.close();
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  void _handleWsControlRequest(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        final ws = await WebSocketTransformer.upgrade(request);
        _wsControlClients.add(ws);

        ws.listen((data) {
          if (data is String) {
            try {
              final msg = jsonDecode(data) as Map<String, dynamic>;
              final action = msg['action'] as String?;
              final value = msg['value'];

              if (action != null) {
                _processRemoteAction(action, value);
                onRemoteCommand?.call(action, value);
              }
            } catch (e) {
              debugPrint('Error parsing WS message: $e');
            }
          }
        }, onDone: () {
          _wsControlClients.remove(ws);
        }, onError: (_) {
          _wsControlClients.remove(ws);
        });
      } catch (_) {}
    }
  }

  void _processRemoteAction(String action, dynamic value) {
    switch (action) {
      case 'torch':
        if (value is bool) _isTorchOn = value;
        break;
      case 'zoom':
        if (value is num) _zoomLevel = value.toDouble();
        break;
      case 'flip_camera':
        _isFrontCamera = !_isFrontCamera;
        break;
    }
    _broadcastTelemetry();
  }

  void _broadcastTelemetry() {
    final payload = jsonEncode({
      'type': 'telemetry',
      'fps': _currentFps,
      'viewers': activeViewers,
      'torch': _isTorchOn,
      'zoom': _zoomLevel,
      'frontCamera': _isFrontCamera,
      'timestamp': DateTime.now().toIso8601String(),
    });

    for (final ws in List<WebSocket>.from(_wsControlClients)) {
      try {
        ws.add(payload);
      } catch (_) {}
    }
  }

  /// Ingests a new camera JPEG frame and broadcasts to all connected binary WS & HTTP clients
  void injectFrame(Uint8List jpegBytes) {
    _latestFrame = jpegBytes;
    _fpsCounter++;

    // 1. Binary WebSockets (Ultra-fast direct dispatch)
    if (_binaryWsClients.isNotEmpty) {
      final deadWs = <WebSocket>[];
      for (final ws in _binaryWsClients) {
        try {
          ws.add(jpegBytes);
        } catch (e) {
          deadWs.add(ws);
        }
      }
      if (deadWs.isNotEmpty) {
        for (final dead in deadWs) {
          _binaryWsClients.remove(dead);
        }
      }
    }

    // 2. HTTP Multipart MJPEG stream
    if (_mjpegClients.isNotEmpty) {
      final header = utf8.encode(
        '--frame\r\nContent-Type: image/jpeg\r\nContent-Length: ${jpegBytes.length}\r\n\r\n',
      );
      final footer = utf8.encode('\r\n');

      final deadClients = <HttpResponse>[];
      for (final client in _mjpegClients) {
        try {
          client.add(header);
          client.add(jpegBytes);
          client.add(footer);
        } catch (e) {
          deadClients.add(client);
        }
      }

      if (deadClients.isNotEmpty) {
        for (final dead in deadClients) {
          _mjpegClients.remove(dead);
        }
      }
    }
  }

  void stopServer() {
    _fpsTimer?.cancel();
    _fpsTimer = null;

    for (final c in _mjpegClients) {
      try {
        c.close();
      } catch (_) {}
    }
    _mjpegClients.clear();

    for (final ws in _binaryWsClients) {
      try {
        ws.close();
      } catch (_) {}
    }
    _binaryWsClients.clear();

    for (final ws in _wsControlClients) {
      try {
        ws.close();
      } catch (_) {}
    }
    _wsControlClients.clear();

    _httpServer?.close(force: true);
    _httpServer = null;

    _wsControlServer?.close(force: true);
    _wsControlServer = null;
  }
}
