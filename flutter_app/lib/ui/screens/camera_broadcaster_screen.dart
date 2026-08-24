import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:torch_light/torch_light.dart';
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
  bool _hasPermission = false;
  String? _errorMessage;
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
  bool _showAlignmentGrid = true;
  bool _isFullScreenPreview = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAll();
  }

  Future<void> _initAll() async {
    setState(() {
      _errorMessage = null;
    });
    await _initBroadcasting();
    await _checkPermissionsAndInitCamera();
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

  Future<void> _checkPermissionsAndInitCamera() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
        _errorMessage = null;
      });
      await _initCamera();
    } else {
      setState(() {
        _hasPermission = false;
        _errorMessage = 'Camera permission required to see and stream tabletop video.';
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera hardware found on this device.';
        });
        return;
      }

      // Default to back camera for overhead tabletop viewing
      _selectedCameraIndex = 0;
      for (int i = 0; i < _availableCameras.length; i++) {
        if (_availableCameras[i].lensDirection == CameraLensDirection.back) {
          _selectedCameraIndex = i;
          break;
        }
      }

      await _startCameraInstance(_availableCameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('Error finding cameras: $e');
      setState(() {
        _errorMessage = 'Camera search error: $e';
      });
    }
  }

  Future<void> _startCameraInstance(CameraDescription description) async {
    try {
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }

      _isCameraInitialized = false;
      if (mounted) setState(() {});

      final controller = CameraController(
        description,
        ResolutionPreset.medium, // 720p/480p ideal balance for ultra-low latency & 30fps Wi-Fi streaming
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _cameraController = controller;
      await controller.initialize();

      if (!mounted) return;

      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = (await controller.getMaxZoomLevel()).clamp(1.0, 8.0);
      _zoom = _minZoom;

      // Start image stream for network broadcasting
      await controller.startImageStream(_handleCameraImage);

      setState(() {
        _isCameraInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('Camera startup error: $e');
      setState(() {
        _errorMessage = 'Camera initialization error: $e';
      });
    }
  }

  void _handleCameraImage(CameraImage image) {
    final now = DateTime.now();
    // Throttle to target ~25-30 FPS (35ms interval) to keep phone cool and stream ultra-smooth
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
      debugPrint('Frame processing error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _setTorch(bool enable) async {
    // 1. Try native TorchLight plugin (Android CameraManager.setTorchMode)
    try {
      if (enable) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
      if (mounted) setState(() => _torchOn = enable);
      return;
    } catch (e) {
      debugPrint('TorchLight plugin notice: $e');
    }

    // 2. Fallback to CameraController flash mode
    if (_cameraController != null && _isCameraInitialized) {
      try {
        await _cameraController!.setFlashMode(enable ? FlashMode.torch : FlashMode.off);
        if (mounted) setState(() => _torchOn = enable);
      } catch (_) {}
    }
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
      _checkPermissionsAndInitCamera();
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
    _setTorch(false);
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
        title: const Text('Jokarz Eye (Camera Streamer)'),
        actions: [
          IconButton(
            icon: Icon(
              _showAlignmentGrid ? Icons.grid_on : Icons.grid_off,
              color: _showAlignmentGrid ? JokarzColors.gold : JokarzColors.textMuted,
            ),
            tooltip: 'Toggle Table Grid',
            onPressed: () => setState(() => _showAlignmentGrid = !_showAlignmentGrid),
          ),
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
            tooltip: 'Refresh Camera',
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
              // Large Tabletop Viewfinder Monitor
              Container(
                height: _isFullScreenPreview ? 460 : 320,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isServerRunning && _server.currentFps > 0
                        ? JokarzColors.emerald
                        : JokarzColors.gold,
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isServerRunning && _server.currentFps > 0
                              ? JokarzColors.emerald
                              : JokarzColors.gold)
                          .withAlpha(80),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Live Camera Viewport (Always visible on phone screen)
                    if (_isCameraInitialized && _cameraController != null)
                      Center(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize?.height ?? 640,
                            height: _cameraController!.value.previewSize?.width ?? 480,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      )
                    else if (!_hasPermission)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_off, size: 48, color: JokarzColors.crimson),
                              const SizedBox(height: 12),
                              const Text(
                                'CAMERA PERMISSION REQUIRED',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: JokarzColors.gold, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Allow camera access so Jokarz Eye can broadcast your game table.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: JokarzColors.textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton(
                                onPressed: _checkPermissionsAndInitCamera,
                                child: const Text('Grant Camera Permission'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_errorMessage != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_off, size: 44, color: JokarzColors.crimson),
                              const SizedBox(height: 10),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: JokarzColors.gold, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Retry Camera'),
                                onPressed: _initCamera,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: JokarzColors.gold),
                            SizedBox(height: 14),
                            Text(
                              'CONNECTING TABLETOP CAMERA...',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: JokarzColors.gold, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                    // Framing Alignment Grid Overlay
                    if (_showAlignmentGrid && _isCameraInitialized)
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _TableAlignmentGridPainter(),
                          child: const SizedBox.expand(),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(220),
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
                                  _server.currentFps > 0 ? 'STREAMING LIVE' : 'INITIALIZING SENSOR',
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
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isFullScreenPreview ? Icons.fullscreen_exit : Icons.fullscreen,
                                  color: JokarzColors.gold,
                                  size: 22,
                                ),
                                tooltip: 'Expand Viewfinder',
                                onPressed: () => setState(() => _isFullScreenPreview = !_isFullScreenPreview),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(220),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: JokarzColors.gold),
                                ),
                                child: Text(
                                  '${_server.currentFps} FPS',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: JokarzColors.gold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Bottom Viewfinder Floating Controls
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Table Spotlight Torch Toggle
                          FloatingActionButton.small(
                            heroTag: 'torchBtn',
                            backgroundColor: _torchOn ? JokarzColors.gold : Colors.black87,
                            foregroundColor: _torchOn ? Colors.black : JokarzColors.gold,
                            onPressed: () => _setTorch(!_torchOn),
                            tooltip: 'Toggle Table Spotlight (Flash)',
                            child: Icon(_torchOn ? Icons.flashlight_on : Icons.flashlight_off),
                          ),
                          // Viewers Connected Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(220),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: JokarzColors.cardBorder),
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
                          // Flip Camera Button
                          FloatingActionButton.small(
                            heroTag: 'flipBtn',
                            backgroundColor: Colors.black87,
                            foregroundColor: JokarzColors.gold,
                            onPressed: _flipCamera,
                            tooltip: 'Flip Lens',
                            child: const Icon(Icons.flip_camera_ios),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Fast 1-Sec Pairing & Hotspot Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JokarzColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      label: const Text(
                        '1-Sec QR Pair',
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      ),
                      onPressed: _showQrDialog,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: JokarzColors.emerald,
                        side: const BorderSide(color: JokarzColors.emerald, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.wifi_tethering, size: 20),
                      label: const Text(
                        '0-Router Guide',
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      ),
                      onPressed: _showOfflineHotspotGuide,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Telemetry Stats Row
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
                    _buildStatItem('Active Viewers', '${_server.activeViewers}', Icons.people),
                    _buildStatItem('Uptime', _formatTime(_secondsStreaming), Icons.timer),
                    _buildStatItem('Port', '${AppConstants.defaultHttpPort}', Icons.lan),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Direct Wi-Fi Connection Information Box
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

              // Tabletop Zoom Control Card
              JokarzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TABLETOP OPTICAL / DIGITAL ZOOM',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: JokarzColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.zoom_in, color: JokarzColors.gold),
                        const SizedBox(width: 10),
                        Text(
                          'Zoom: ${_zoom.toStringAsFixed(1)}x',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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

/// Custom painter that draws a subtle table framing grid to align the camera over cards
class _TableAlignmentGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JokarzColors.gold.withAlpha(70)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 3x3 Rule of Thirds Grid
    final thirdW = size.width / 3;
    final thirdH = size.height / 3;

    canvas.drawLine(Offset(thirdW, 0), Offset(thirdW, size.height), paint);
    canvas.drawLine(Offset(thirdW * 2, 0), Offset(thirdW * 2, size.height), paint);
    canvas.drawLine(Offset(0, thirdH), Offset(size.width, thirdH), paint);
    canvas.drawLine(Offset(0, thirdH * 2), Offset(size.width, thirdH * 2), paint);

    // Center Crosshair
    final centerPaint = Paint()
      ..color = JokarzColors.emerald.withAlpha(120)
      ..strokeWidth = 1.5;

    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx - 15, cy), Offset(cx + 15, cy), centerPaint);
    canvas.drawLine(Offset(cx, cy - 15), Offset(cx, cy + 15), centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
