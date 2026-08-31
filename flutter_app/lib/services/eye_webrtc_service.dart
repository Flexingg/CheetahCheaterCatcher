import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:torch_light/torch_light.dart';

import '../constants/app_constants.dart';

/// Quality presets mirrored from the broadcaster UI.
enum EyeQualityPreset {
  ultra4k1080p, // 1920x1080 @ 30fps
  highSpeed60, // 1280x720 @ 60fps
  balanced720p, // 1280x720 @ 30fps
}

/// The Jokarz Eye (broadcaster) WebRTC service.
///
/// Captures the camera once via `getUserMedia` (hardware H.264 encoder on
/// Android) and streams it peer-to-peer over local Wi-Fi to any number of
/// "Table" viewers. Signaling is a tiny HTTP server on the stream port:
///   GET  /webrtc/offer   -> creates a fresh peer + offer (gathered SDP)
///   POST /webrtc/answer  -> {sessionId, sdp} completes the peer
/// Remote controls (torch / zoom / flip / quality / sound_alert) and
/// telemetry flow over a `control` RTCDataChannel per peer.
class EyeWebRtcService {
  MediaStream? _cameraStream;
  MediaStreamTrack? _videoTrack;
  HttpServer? _signalServer;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final Map<String, RTCPeerConnection> _peers = {};
  final Map<String, RTCDataChannel> _controlChannels = {};

  EyeQualityPreset _qualityPreset = EyeQualityPreset.ultra4k1080p;
  bool _isFrontCamera = false;
  bool _isTorchOn = false;
  double _zoom = 1.0;
  bool _isStreaming = false;
  int _viewerCount = 0;

  /// Fired when the Table triggers a remote sound alert (e.g. 'whistle').
  void Function(String soundType)? onSoundAlert;

  bool get isStreaming => _isStreaming;
  int get viewerCount => _viewerCount;
  bool get isFrontCamera => _isFrontCamera;
  double get zoom => _zoom;
  EyeQualityPreset get qualityPreset => _qualityPreset;
  MediaStreamTrack? get videoTrack => _videoTrack;

  int get currentFps => switch (_qualityPreset) {
        EyeQualityPreset.highSpeed60 => 60,
        _ => 30,
      };

  /// Boots the camera, local preview and the signaling HTTP server.
  Future<void> start({int streamPort = AppConstants.defaultHttpPort}) async {
    try {
      await localRenderer.initialize();
    } catch (e) {
      debugPrint('[EyeWebRtc] localRenderer.initialize error: $e');
    }

    await _startCamera();

    await _startSignalServer(streamPort);
    _isStreaming = _videoTrack != null;
    debugPrint('[EyeWebRtc] Eye service started on :$streamPort (H.264 WebRTC)');
  }

  Map<String, dynamic> _cameraConstraints(EyeQualityPreset preset, bool isFront) {
    final (int w, int h, int fps) = switch (preset) {
      EyeQualityPreset.ultra4k1080p => (1920, 1080, 30),
      EyeQualityPreset.highSpeed60 => (1280, 720, 60),
      EyeQualityPreset.balanced720p => (1280, 720, 30),
    };
    return {
      'audio': false,
      'video': {
        if (!isFront) 'facingMode': 'environment',
        if (isFront) 'facingMode': 'user',
        'width': {'ideal': w},
        'height': {'ideal': h},
        'frameRate': {'ideal': fps, 'max': fps},
      },
    };
  }

  Future<void> _startCamera() async {
    // Stop the previous track so we never hold the camera twice.
    await _stopCameraTrack();

    final constraints = _cameraConstraints(_qualityPreset, _isFrontCamera);
    try {
      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      final track = stream.getVideoTracks().isNotEmpty
          ? stream.getVideoTracks().first
          : null;
      _cameraStream = stream;
      _videoTrack = track;
      localRenderer.srcObject = stream;

      // Replace the track on every already-connected viewer (no renegotiation).
      for (final peer in _peers.values) {
        await _replaceVideoTrackOnPeer(peer);
      }
      _isStreaming = track != null;
      _broadcastTelemetry();
      final s = track?.getSettings() ?? <String, dynamic>{};
      debugPrint('[EyeWebRtc] Camera ready: ${s['width']}x'
          '${s['height']} @ ${s['frameRate']}fps');
    } catch (e) {
      _isStreaming = false;
      debugPrint('[EyeWebRtc] getUserMedia error: $e');
      rethrow;
    }
  }

  Future<void> _stopCameraTrack() async {
    try {
      _cameraStream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    _cameraStream = null;
    _videoTrack = null;
  }

  Future<void> _replaceVideoTrackOnPeer(RTCPeerConnection peer) async {
    if (_videoTrack == null) return;
    try {
      final senders = await peer.getSenders();
      for (final s in senders) {
        if (s.track?.kind == 'video') {
          await s.replaceTrack(_videoTrack);
          break;
        }
      }
    } catch (e) {
      debugPrint('[EyeWebRtc] replaceTrack error: $e');
    }
  }

  Future<void> _startSignalServer(int port) async {
    await _signalServer?.close(force: true);
    _signalServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _signalServer?.listen(_handleRequest);
    debugPrint('[EyeWebRtc] Signaling server listening on :$port');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    request.response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..set('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/webrtc/offer') {
        await _handleOffer(request);
      } else if (request.method == 'POST' && path == '/webrtc/answer') {
        await _handleAnswer(request);
      } else if (request.method == 'GET' && path == '/status') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'status': 'online',
          'viewers': _viewerCount,
          'fps': currentFps,
          'torch': _isTorchOn,
          'zoom': _zoom,
          'frontCamera': _isFrontCamera,
          'webrtc': true,
        }));
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      debugPrint('[EyeWebRtc] request error: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleOffer(HttpRequest request) async {
    final sessionId = 'viewer_${DateTime.now().millisecondsSinceEpoch}';

    final peer = await createPeerConnection(const {
      'iceServers': [
        {'urls': ['stun:stun.l.google.com:19302']},
      ],
      'sdpSemantics': 'unified-plan',
    });

    final gathering = Completer<void>();
    peer.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !gathering.isCompleted) {
        gathering.complete();
      }
    };
    // Safety fallback if gathering completes before the callback is wired.
    Timer(const Duration(seconds: 4), () {
      if (!gathering.isCompleted) gathering.complete();
    });

    peer.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        debugPrint('[EyeWebRtc] Viewer connected: $sessionId');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _dropPeer(sessionId);
      }
    };

    // The Eye is the offerer, so it owns the control data channel.
    final controlChannel =
        await peer.createDataChannel('control', RTCDataChannelInit());
    controlChannel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _broadcastTelemetry(channel: controlChannel);
      }
    };
    controlChannel.onMessage = (msg) {
      if (msg.isBinary) return;
      try {
        _handleControlMessage(
            jsonDecode(msg.text) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[EyeWebRtc] bad control message: $e');
      }
    };

    _peers[sessionId] = peer;
    _controlChannels[sessionId] = controlChannel;
    _viewerCount = _peers.length;

    if (_videoTrack != null && _cameraStream != null) {
      await peer.addTrack(_videoTrack!, _cameraStream!);
    }
    await _preferH264(peer);

    final offer = await peer.createOffer();
    await peer.setLocalDescription(offer);
    await gathering.future;

    final localDesc = await peer.getLocalDescription();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'sessionId': sessionId,
      'sdp': localDesc?.sdp ?? offer.sdp,
    }));
    await request.response.close();
  }

  Future<void> _handleAnswer(HttpRequest request) async {
    final body = jsonDecode(await utf8.decoder.bind(request).join())
        as Map<String, dynamic>;
    final sessionId = body['sessionId'] as String?;
    final sdp = body['sdp'] as String?;

    if (sessionId == null || sdp == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    final peer = _peers[sessionId];
    if (peer == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    await peer.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'ok': true}));
    await request.response.close();
  }

  Future<void> _preferH264(RTCPeerConnection peer) async {
    try {
      final caps = await getRtpSenderCapabilities('video');
      final h264 = caps.codecs
          ?.where((c) => c.mimeType.toUpperCase().contains('H264'))
          .toList();
      if (h264 == null || h264.isEmpty) return;
      final transceivers = await peer.getTransceivers();
      for (final t in transceivers) {
        if (t.sender.track?.kind == 'video') {
          await t.setCodecPreferences(h264);
        }
      }
    } catch (e) {
      debugPrint('[EyeWebRtc] H264 codec preference failed (falling back): $e');
    }
  }

  void _handleControlMessage(Map<String, dynamic> msg) {
    final action = msg['action'] as String?;
    final value = msg['value'];
    switch (action) {
      case 'torch':
        _setTorch(value == true);
        break;
      case 'zoom':
        if (value is num) _setZoom(value.toDouble());
        break;
      case 'flip_camera':
        _flipCamera();
        break;
      case 'quality_preset':
        if (value is String) setQualityPreset(value);
        break;
      case 'sound_alert':
        if (value is String) onSoundAlert?.call(value);
        break;
      default:
        break;
    }
  }

  /// Public control wrappers used by the Eye's own on-screen controls.
  Future<void> setTorch(bool on) => _setTorch(on);
  Future<void> setZoom(double value) => _setZoom(value);
  Future<void> flipCamera() => _flipCamera();

  Future<void> _setTorch(bool enable) async {
    _isTorchOn = enable;
    try {
      if (enable) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
    } catch (e) {
      debugPrint('[EyeWebRtc] TorchLight notice: $e');
      // Fall back to the camera track if the standalone torch plugin failed.
      final track = _videoTrack;
      if (track != null) {
        try {
          await track.setTorch(enable);
        } catch (_) {}
      }
    }
    _broadcastTelemetry();
  }

  Future<void> _setZoom(double value) async {
    _zoom = value.clamp(1.0, 8.0);
    final track = _videoTrack;
    if (track != null) {
      try {
        await Helper.setZoom(track, _zoom);
      } catch (e) {
        debugPrint('[EyeWebRtc] zoom error: $e');
      }
    }
    _broadcastTelemetry();
  }

  Future<void> _flipCamera() async {
    final track = _videoTrack;
    if (track == null) return;
    try {
      final ok = await Helper.switchCamera(track);
      if (ok) _isFrontCamera = !_isFrontCamera;
    } catch (e) {
      debugPrint('[EyeWebRtc] switchCamera error: $e');
    }
    _broadcastTelemetry();
  }

  /// Applies a quality preset by restarting the camera at new constraints.
  Future<void> setQualityPreset(String preset) async {
    final next = switch (preset) {
      'highSpeed60' => EyeQualityPreset.highSpeed60,
      'balanced720p' => EyeQualityPreset.balanced720p,
      _ => EyeQualityPreset.ultra4k1080p,
    };
    if (next == _qualityPreset) {
      _broadcastTelemetry();
      return;
    }
    _qualityPreset = next;
    await _startCamera();
    _broadcastTelemetry();
  }

  void _broadcastTelemetry({RTCDataChannel? channel}) {
    final payload = jsonEncode({
      'type': 'telemetry',
      'torch': _isTorchOn,
      'zoom': _zoom,
      'frontCamera': _isFrontCamera,
      'fps': currentFps,
      'viewers': _viewerCount,
      'quality': _qualityPreset.name,
    });
    if (channel != null) {
      channel.send(RTCDataChannelMessage(payload));
      return;
    }
    _sendToAllChannels(payload);
  }

  void _sendToAllChannels(String payload) {
    for (final ch in _controlChannels.values) {
      try {
        if (ch.state == RTCDataChannelState.RTCDataChannelOpen) {
          ch.send(RTCDataChannelMessage(payload));
        }
      } catch (_) {}
    }
  }

  void _dropPeer(String sessionId) {
    final peer = _peers.remove(sessionId);
    _controlChannels.remove(sessionId);
    if (peer != null) {
      try {
        peer.close();
      } catch (_) {}
    }
    _viewerCount = _peers.length;
    _broadcastTelemetry();
  }

  Future<void> dispose() async {
    for (final peer in _peers.values) {
      try {
        peer.close();
      } catch (_) {}
    }
    _peers.clear();
    _controlChannels.clear();
    _viewerCount = 0;
    await _stopCameraTrack();
    await _signalServer?.close(force: true);
    _signalServer = null;
    try {
      await localRenderer.dispose();
    } catch (_) {}
  }
}
