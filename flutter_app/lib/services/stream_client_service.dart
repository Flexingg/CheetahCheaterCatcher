import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import '../models/camera_device_info.dart';

typedef FrameCallback = void Function(Uint8List frame);

/// The Jokarz Table (viewer) WebRTC client.
///
/// Connects to a Jokarz Eye over local Wi-Fi using WebRTC (hardware H.264
/// decode). Signaling is a simple offer/answer HTTP exchange against the Eye's
/// signaling server, with non-trickle ICE (all candidates gathered before the
/// answer is returned) so no separate candidate channel is needed.
///
/// Keeps the same public surface as the legacy MJPEG client so
/// [VarReplayProvider] and the UI are largely unchanged. Live video is exposed
/// via [remoteRenderer]; the instant-replay DVR is fed through [addDvrFrame]
/// from snapshots captured off the rendered view.
class StreamClientService {
  RTCVideoRenderer? _remoteRenderer;
  RTCPeerConnection? _pc;
  RTCDataChannel? _controlChannel;
  Timer? _fpsTimer;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  CameraDeviceInfo? _connectedDevice;
  int _receivedFramesCount = 0;
  int _currentFps = 0;
  String? _offerSdp;
  String? _sessionId;

  final StreamController<Uint8List> _frameStreamController =
      StreamController<Uint8List>.broadcast();
  final StreamController<Map<String, dynamic>> _telemetryController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Uint8List> get frameStream => _frameStreamController.stream;
  Stream<Map<String, dynamic>> get telemetryStream =>
      _telemetryController.stream;
  bool get isConnected => _isConnected;
  int get currentFps => _currentFps;
  CameraDeviceInfo? get connectedDevice => _connectedDevice;
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;

  /// Connect to a Jokarz Eye via WebRTC offer/answer over HTTP.
  Future<void> connect(CameraDeviceInfo device) async {
    await disconnect();
    _connectedDevice = device;

    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _currentFps = _receivedFramesCount;
      _receivedFramesCount = 0;
    });

    try {
      _remoteRenderer = RTCVideoRenderer();
      await _remoteRenderer!.initialize();

      _pc = await createPeerConnection(const {
        'iceServers': [
          {'urls': ['stun:stun.l.google.com:19302']},
        ],
        'sdpSemantics': 'unified-plan',
      });

      _pc!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteRenderer?.srcObject = event.streams[0];
        }
      };
      _pc!.onDataChannel = (channel) {
        _bindControlChannel(channel);
      };
      _pc!.onIceGatheringState = (_) {};

      // 1. Fetch the Eye's offer (it also creates the control data channel).
      final offerRes = await http
          .get(Uri.parse(
              'http://${device.ip}:${device.streamPort}/webrtc/offer'))
          .timeout(const Duration(seconds: 8));
      if (offerRes.statusCode != 200) {
        throw Exception('Eye offer failed (HTTP ${offerRes.statusCode})');
      }
      final offerBody = jsonDecode(offerRes.body) as Map<String, dynamic>;
      _sessionId = offerBody['sessionId'] as String?;
      _offerSdp = offerBody['sdp'] as String?;

      await _pc!.setRemoteDescription(RTCSessionDescription(_offerSdp!, 'offer'));

      // 2. Build our answer (gather all candidates first — non-trickle).
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      await _waitForGatheringComplete();

      final localDesc = await _pc!.getLocalDescription();
      final answerRes = await http
          .post(
            Uri.parse(
                'http://${device.ip}:${device.streamPort}/webrtc/answer'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'sessionId': _sessionId,
              'sdp': localDesc?.sdp ?? answer.sdp,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (answerRes.statusCode != 200 && answerRes.statusCode != 404) {
        throw Exception('Eye answer failed (HTTP ${answerRes.statusCode})');
      }

      _isConnected = true;
      debugPrint('[StreamClient] WebRTC connected to ${device.ip}');
    } catch (e) {
      debugPrint('[StreamClient] WebRTC connect failed: $e');
      await disconnect();
      rethrow;
    }
  }

  Future<void> _waitForGatheringComplete() async {
    final completer = Completer<void>();
    final pc = _pc;
    if (pc == null) return;
    void check() {
      if (pc.iceGatheringState ==
          RTCIceGatheringState.RTCIceGatheringStateComplete) {
        if (!completer.isCompleted) completer.complete();
      }
    }

    pc.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    };
    check();
    // Safety fallback: don't block forever if gathering is already done.
    Timer(const Duration(seconds: 4), () {
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;
  }

  void _bindControlChannel(RTCDataChannel channel) {
    _controlChannel = channel;
    channel.onMessage = (msg) {
      if (msg.isBinary) return;
      try {
        final json = jsonDecode(msg.text) as Map<String, dynamic>;
        if (json['type'] == 'telemetry') {
          _telemetryController.add(json);
        }
      } catch (_) {}
    };
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _controlChannel = null;
      }
    };
  }

  /// Feeds a captured frame (e.g. a snapshot of the rendered view) into the
  /// instant-replay DVR. Mirrors the old per-frame JPEG stream.
  void addDvrFrame(Uint8List frameBytes) {
    if (frameBytes.isEmpty || !_isConnected) return;
    _receivedFramesCount++;
    _frameStreamController.add(frameBytes);
  }

  void sendControlCommand(String action, dynamic value) {
    final ch = _controlChannel;
    if (ch != null && ch.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        ch.send(RTCDataChannelMessage(
            jsonEncode({'action': action, 'value': value})));
      } catch (e) {
        debugPrint('[StreamClient] control send error: $e');
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

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _fpsTimer?.cancel();
    _fpsTimer = null;

    _isConnected = false;
    _connectedDevice = null;
    _offerSdp = null;
    _sessionId = null;

    try {
      _controlChannel?.close();
    } catch (_) {}
    _controlChannel = null;

    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;

    final renderer = _remoteRenderer;
    _remoteRenderer = null;
    if (renderer != null) {
      try {
        await renderer.dispose();
      } catch (_) {}
    }
  }

  void dispose() {
    disconnect();
    _frameStreamController.close();
    _telemetryController.close();
  }
}
