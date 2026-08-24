import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/camera_device_info.dart';
import '../services/dvr_replay_manager.dart';
import '../services/network_discovery_service.dart';
import '../services/sound_effects_service.dart';
import '../services/stream_client_service.dart';

class VarReplayProvider extends ChangeNotifier {
  final NetworkDiscoveryService _discoveryService = NetworkDiscoveryService();
  final StreamClientService _streamClient = StreamClientService();
  final DvrReplayManager _dvrManager = DvrReplayManager();

  StreamSubscription? _frameSub;
  StreamSubscription? _discoverySub;
  StreamSubscription? _telemetrySub;

  List<CameraDeviceInfo> _discoveredCameras = [];
  CameraDeviceInfo? _activeCamera;
  bool _isConnecting = false;
  String? _errorMessage;

  // Remote telemetry state
  bool _isRemoteTorchOn = false;
  double _remoteZoom = 1.0;
  bool _isFrontCamera = false;

  // Canvas zoom/pan for referee inspection
  double _refZoomScale = 1.0;
  Offset _refPanOffset = Offset.zero;

  VarReplayProvider() {
    _initListeners();
  }

  NetworkDiscoveryService get discoveryService => _discoveryService;
  StreamClientService get streamClient => _streamClient;
  DvrReplayManager get dvrManager => _dvrManager;

  List<CameraDeviceInfo> get discoveredCameras => _discoveredCameras;
  CameraDeviceInfo? get activeCamera => _activeCamera;
  bool get isConnected => _streamClient.isConnected;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;

  bool get isReplayActive => _dvrManager.isReplayActive;
  bool get isPlaying => _dvrManager.isPlaying;
  double get playbackSpeed => _dvrManager.playbackSpeed;
  int get currentScrubIndex => _dvrManager.currentScrubIndex;
  int get totalBufferedFrames => _dvrManager.totalBufferedFrames;
  int get currentFps => _streamClient.currentFps;
  Uint8List? get currentFrameBytes => _dvrManager.currentFrame?.jpegBytes;

  bool get isRemoteTorchOn => _isRemoteTorchOn;
  double get remoteZoom => _remoteZoom;
  bool get isFrontCamera => _isFrontCamera;

  double get refZoomScale => _refZoomScale;
  Offset get refPanOffset => _refPanOffset;

  void _initListeners() {
    _discoverySub = _discoveryService.discoveredCamerasStream.listen((cams) {
      _discoveredCameras = cams;
      notifyListeners();
    });

    _frameSub = _streamClient.frameStream.listen((frame) {
      _dvrManager.pushFrame(frame);
      if (!_dvrManager.isReplayActive) {
        notifyListeners();
      }
    });

    _telemetrySub = _streamClient.telemetryStream.listen((telemetry) {
      if (telemetry['torch'] != null) _isRemoteTorchOn = telemetry['torch'] as bool;
      if (telemetry['zoom'] != null) _remoteZoom = (telemetry['zoom'] as num).toDouble();
      if (telemetry['frontCamera'] != null) _isFrontCamera = telemetry['frontCamera'] as bool;
      notifyListeners();
    });

    _dvrManager.addListener(notifyListeners);
  }

  /// Start scanning for cameras on local network
  void startDiscovery() {
    _discoveryService.startListening();
  }

  void stopDiscovery() {
    _discoveryService.stopListening();
  }

  /// Connect to selected camera
  Future<void> connectToCamera(CameraDeviceInfo camera) async {
    _isConnecting = true;
    _errorMessage = null;
    _activeCamera = camera;
    notifyListeners();

    try {
      await _streamClient.connect(camera);
      _isConnecting = false;
      notifyListeners();
    } catch (e) {
      _isConnecting = false;
      _errorMessage = 'Could not connect to camera: $e';
      notifyListeners();
    }
  }

  /// Connect to custom manual IP
  Future<void> connectToManualIp(String ip, {int port = 8080}) async {
    final customDevice = CameraDeviceInfo(
      id: 'manual_$ip',
      ip: ip,
      streamPort: port,
      controlPort: port + 1,
      deviceName: 'Manual IP ($ip)',
    );
    await connectToCamera(customDevice);
  }

  void disconnect() {
    _streamClient.disconnect();
    _dvrManager.clear();
    _activeCamera = null;
    _isConnecting = false;
    _resetCanvasZoom();
    notifyListeners();
  }

  // --- VAR Instant Replay Controls ---
  void enterReplayMode() {
    SoundEffectsService.playVarWhistle();
    _dvrManager.enterReplayMode();
  }

  void returnToLive() {
    SoundEffectsService.playScoreChange();
    _resetCanvasZoom();
    _dvrManager.returnToLive();
  }

  void seekRatio(double ratio) {
    _dvrManager.seekRatio(ratio);
  }

  void seekIndex(int index) {
    _dvrManager.seekToIndex(index);
  }

  void stepBackward([int steps = 1]) {
    SoundEffectsService.playChipClick();
    _dvrManager.stepBackward(steps);
  }

  void stepForward([int steps = 1]) {
    SoundEffectsService.playChipClick();
    _dvrManager.stepForward(steps);
  }

  void togglePlayPause() {
    SoundEffectsService.playScoreChange();
    _dvrManager.togglePlayPause();
  }

  void setPlaybackSpeed(double speed) {
    SoundEffectsService.playScoreChange();
    _dvrManager.setSpeed(speed);
  }

  // --- Remote Camera Commands ---
  void toggleRemoteTorch() {
    _isRemoteTorchOn = !_isRemoteTorchOn;
    _streamClient.toggleRemoteTorch(_isRemoteTorchOn);
    notifyListeners();
  }

  void setRemoteZoom(double zoom) {
    _remoteZoom = zoom;
    _streamClient.setRemoteZoom(zoom);
    notifyListeners();
  }

  void flipRemoteCamera() {
    _isFrontCamera = !_isFrontCamera;
    _streamClient.flipRemoteCamera();
    notifyListeners();
  }

  // --- Referee Zoom / Pan Inspection ---
  void updateRefereeZoom(double scale, Offset pan) {
    _refZoomScale = scale.clamp(1.0, 5.0);
    _refPanOffset = pan;
    notifyListeners();
  }

  void _resetCanvasZoom() {
    _refZoomScale = 1.0;
    _refPanOffset = Offset.zero;
  }

  @override
  void dispose() {
    _frameSub?.cancel();
    _discoverySub?.cancel();
    _telemetrySub?.cancel();
    _discoveryService.dispose();
    _streamClient.dispose();
    _dvrManager.dispose();
    super.dispose();
  }
}
