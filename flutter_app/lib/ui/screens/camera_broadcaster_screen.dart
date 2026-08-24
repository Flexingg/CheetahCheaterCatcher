import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_theme.dart';
import '../../services/camera_frame_converter.dart';
import '../../services/mjpeg_camera_server.dart';
import '../../services/network_discovery_service.dart';
import '../../services/sound_effects_service.dart';
import '../widgets/offline_hotspot_guide_sheet.dart';
import '../widgets/poker_card_widgets.dart';
import '../widgets/qr_pairing_dialog.dart';

class CameraBroadcasterScreen extends StatefulWidget {
  const CameraBroadcasterScreen({super.key});

  @override
  State<CameraBroadcasterScreen> createState() => _CameraBroadcasterScreenState();
}

class _CameraBroadcasterScreenState extends State<CameraBroadcasterScreen> with WidgetsBindingObserver {
  final MjpegCameraServer _server = MjpegCameraServer();
  final NetworkDiscoveryService _discovery = NetworkDiscoveryService();

  List<CameraDescription> _availableCameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  DateTime _lastFrameTime = DateTime.now();

  List<String> _localIps = [];
  bool _isServerRunning = false;
  int _secondsStreaming = 0;
  Timer? _durationTimer;
  Timer? _uiRefreshTimer;

  bool _torchOn = false;
  double _zoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 4.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAll();
  }

  Future<void> _initAll() async {
    await _initBroadcasting();
    await _initCamera();
  }

  Future<void> _initBroadcasting() async {
    _localIps = await NetworkDiscoveryService.getLocalIpAddresses();
    if (_localIps.isEmpty) {
      _localIps = ['127.0.0.1'];
    }

    final success = await _server.startServer();
    if (success) {
      _isServerRunning = true;

      await _discovery.startBroadcasting(
        deviceName: 'Jokarz Eye (${_localIps.first})',
        streamPort: AppConstants.defaultHttpPort,
        controlPort: AppConstants.defaultControlPort,
      );

      _server.onRemoteCommand = (action, value) {
        if (!mounted) return;
        if (action == 'torch' && value is bool) _setTorch(value);
        if (action == 'zoom' && value is num) _setZoom(value.toDouble());
        if (action == 'flip_camera') _flipCamera();
        if (action == 'sound_alert') {
          SoundEffectsService.playVarWhistle();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚨 REMOTE VAR REFEREE WHISTLE TRIGGERED!'),
              backgroundColor: JokarzColors.crimsonDark,
              duration: Duration(seconds: 2),
            ),
          );
        }
      };

      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _secondsStreaming++;
          });
        }
      });

      _uiRefreshTimer?.cancel();
      _uiRefreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        debugPrint('No cameras available on this device');
        return;
      }

      // Default to back camera
      _selectedCameraIndex = 0;
      for (int i = 0; i < _availableCameras.length; i++) {
        if (_availableCameras[i].lensDirection == CameraLensDirection.back) {
          _selectedCameraIndex = i;
          break;
        }
      }

      await _startCameraInstance(_availableCameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _startCameraInstance(CameraDescription description) async {
    await _cameraController?.dispose();
    _cameraController = null;
    _isCameraInitialized = false;
    if (mounted) setState(() {});

    final controller = CameraController(
      description,
      ResolutionPreset.medium, // 720p/480p is ideal for 25-30 FPS low latency WiFi
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = (await controller.getMaxZoomLevel()).clamp(1.0, 8.0);
      _zoom = _minZoom;

      // Start live image stream for network broadcasting
      await controller.startImageStream(_handleCameraImage);

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Camera start error: $e');
    }
  }

  void _handleCameraImage(CameraImage image) {
    // Throttle frame processing to target ~25 FPS (40ms interval) to keep device cool and smooth
    final now = DateTime.now();
    if (_isProcessingFrame || now.difference(_lastFrameTime).inMilliseconds < 35) {
      return;
    }

    _isProcessingFrame = true;
    _lastFrameTime = now;

    try {
      final jpeg = CameraFrameConverter.convertCameraImageToJpeg(
        image,
        quality: 60,
        targetWidth: 640,
        targetHeight: 480,
      );

      if (jpeg != null && jpeg.isNotEmpty) {
        _server.injectFrame(jpeg);
      }
    } catch (e) {
      debugPrint('Frame conversion error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _setTorch(bool enable) async {
    if (_cameraController == null || !_isCameraInitialized) return;
    try {
      await _cameraController!.setFlashMode(enable ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchOn = enable);
    } catch (_) {}
  }

  Future<void> _setZoom(double zoomVal) async {
    if (_cameraController == null || !_isCameraInitialized) return;
    try {
      final clamped = zoomVal.clamp(_minZoom, _maxZoom);
      await _cameraController!.setZoomLevel(clamped);
      if (mounted) setState(() => _zoom = clamped);
    } catch (_) {}
  }

  Future<void> _flipCamera() async {
    if (_availableCameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _startCameraInstance(_availableCameras[_selectedCameraIndex]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  void _showQrDialog() {
    final primaryIp = _localIps.isNotEmpty ? _localIps.first : '127.0.0.1';
    showDialog(
      context: context,
      builder: (_) => QrPairingDialog(
        deviceName: 'Jokarz Eye',
        ip: primaryIp,
        streamPort: AppConstants.defaultHttpPort,
        controlPort: AppConstants.defaultControlPort,
      ),
    );
  }

  void _showOfflineHotspotGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfflineHotspotGuideSheet(detectedIps: _localIps),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _durationTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _cameraController?.dispose();
    _server.stopServer();
    _discovery.stopBroadcasting();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryIp = _localIps.isNotEmpty ? _localIps.first : '127.0.0.1';
    final streamUrl = 'http://$primaryIp:${AppConstants.defaultHttpPort}/live';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jokarz Eye (Camera Broadcaster)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2, color: JokarzColors.gold),
            tooltip: 'Show Pairing QR',
            onPressed: _showQrDialog,
          ),
          IconButton(
            icon: const Icon(Icons.wifi_tethering, color: JokarzColors.emerald),
            tooltip: 'Offline Hotspot Guide',
            onPressed: _showOfflineHotspotGuide,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Network & Camera',
            onPressed: _initAll,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live Camera Viewfinder
              Container(
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isServerRunning && _server.currentFps > 0
                        ? JokarzColors.emerald
                        : JokarzColors.gold,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isServerRunning && _server.currentFps > 0
                              ? JokarzColors.emerald
                              : JokarzColors.gold)
                          .withAlpha(60),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isCameraInitialized && _cameraController != null)
                      Center(
                        child: CameraPreview(_cameraController!),
                      )
                    else
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: JokarzColors.gold),
                            SizedBox(height: 12),
                            Text(
                              'STARTING HARDWARE CAMERA...',
                              style: TextStyle(color: JokarzColors.gold, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                    // Top Viewfinder HUD Overlay
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(200),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _server.currentFps > 0
                                    ? JokarzColors.emerald
                                    : JokarzColors.crimson,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _server.currentFps > 0
                                        ? JokarzColors.emerald
                                        : JokarzColors.crimson,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _server.currentFps > 0 ? 'LIVE BROADCAST' : 'INITIALIZING',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: _server.currentFps > 0
                                        ? JokarzColors.emerald
                                        : JokarzColors.crimson,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(200),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: JokarzColors.gold.withAlpha(150)),
                            ),
                            child: Text(
                              '${_server.currentFps} FPS',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: JokarzColors.gold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom Quick Overlay Actions
                    Positioned(
                      bottom: 10,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Torch Toggle
                          FloatingActionButton.small(
                            heroTag: 'torchBtn',
                            backgroundColor: _torchOn ? JokarzColors.gold : Colors.black87,
                            foregroundColor: _torchOn ? Colors.black : JokarzColors.gold,
                            onPressed: () => _setTorch(!_torchOn),
                            child: Icon(_torchOn ? Icons.flashlight_on : Icons.flashlight_off),
                          ),
                          // Viewers Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(200),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.remove_red_eye, color: JokarzColors.emerald, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  '${_server.activeViewers} Viewers Connected',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          // Flip Camera
                          FloatingActionButton.small(
                            heroTag: 'flipBtn',
                            backgroundColor: Colors.black87,
                            foregroundColor: JokarzColors.gold,
                            onPressed: _flipCamera,
                            child: const Icon(Icons.flip_camera_ios),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Fast Pairing Buttons (QR Code + Hotspot)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JokarzColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('1-Sec QR Pair'),
                      onPressed: _showQrDialog,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: JokarzColors.emerald,
                        side: const BorderSide(color: JokarzColors.emerald),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.wifi_tethering, size: 18),
                      label: const Text('0-Router Guide'),
                      onPressed: _showOfflineHotspotGuide,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Telemetry Stats Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: JokarzColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: JokarzColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Viewers', '${_server.activeViewers}', Icons.people),
                    _buildStatItem('Duration', _formatTime(_secondsStreaming), Icons.timer),
                    _buildStatItem('Port', '${AppConstants.defaultHttpPort}', Icons.lan),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Network Connection Information Box
              JokarzCard(
                borderColor: JokarzColors.gold.withAlpha(150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi, color: JokarzColors.gold, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'DIRECT WI-FI STREAM URL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: JokarzColors.goldLight,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: JokarzColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: JokarzColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              streamUrl,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: JokarzColors.emerald,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18, color: JokarzColors.gold),
                            tooltip: 'Copy URL',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: streamUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Stream URL copied to clipboard!'),
                                  backgroundColor: JokarzColors.emeraldDark,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '📡 Auto-discovery beacon active on UDP:45454. The table controller app will link automatically.',
                      style: TextStyle(fontSize: 11, color: JokarzColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Hardware Controls
              JokarzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TABLETOP ZOOM & LIGHTING',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: JokarzColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Digital Zoom Slider
                    Row(
                      children: [
                        const Icon(Icons.zoom_in, color: JokarzColors.gold),
                        const SizedBox(width: 10),
                        Text('Zoom: ${_zoom.toStringAsFixed(1)}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Slider(
                            value: _zoom.clamp(_minZoom, _maxZoom),
                            min: _minZoom,
                            max: _maxZoom,
                            divisions: 20,
                            activeColor: JokarzColors.gold,
                            onChanged: (val) => _setZoom(val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: JokarzColors.textMuted, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: JokarzColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: JokarzColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
