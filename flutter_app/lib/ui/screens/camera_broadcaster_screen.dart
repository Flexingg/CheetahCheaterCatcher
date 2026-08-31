import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../constants/app_constants.dart';
import '../../constants/app_theme.dart';
import '../../services/eye_webrtc_service.dart';
import '../../services/network_discovery_service.dart';
import '../../services/sound_effects_service.dart';
import '../widgets/offline_hotspot_guide_sheet.dart';
import '../widgets/poker_card_widgets.dart';
import '../widgets/qr_pairing_dialog.dart';

enum VideoQualityPreset {
  ultra4k1080p, // 1080p @ 30fps
  highSpeed60, // 720p @ 60fps
  balanced720p, // 720p @ 30fps
}

/// The Jokarz Eye — captures the camera via WebRTC (hardware H.264 on Android)
/// and broadcasts it peer-to-peer over local Wi-Fi to Table viewers.
class CameraBroadcasterScreen extends StatefulWidget {
  const CameraBroadcasterScreen({super.key});

  @override
  State<CameraBroadcasterScreen> createState() => _CameraBroadcasterScreenState();
}

class _CameraBroadcasterScreenState extends State<CameraBroadcasterScreen>
    with WidgetsBindingObserver {
  final EyeWebRtcService _eye = EyeWebRtcService();
  final NetworkDiscoveryService _discovery = NetworkDiscoveryService();

  bool _hasPermission = false;
  String? _errorMessage;

  VideoQualityPreset _qualityPreset = VideoQualityPreset.ultra4k1080p;
  bool _torchOn = false;
  bool _showAlignmentGrid = true;
  bool _isFullScreenPreview = false;

  final double _minZoom = 1.0;
  final double _maxZoom = 8.0;
  double _zoom = 1.0;

  List<String> _localIps = [];
  int _secondsStreaming = 0;
  Timer? _durationTimer;
  Timer? _uiRefreshTimer;

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

    _localIps = await NetworkDiscoveryService.getLocalIpAddresses();
    if (_localIps.isEmpty) {
      _localIps = ['127.0.0.1'];
    }

    await _checkPermissionsAndStart();
  }

  Future<void> _checkPermissionsAndStart() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    if (!status.isGranted) {
      setState(() {
        _hasPermission = false;
        _errorMessage = 'Camera permission required to stream tabletop video.';
      });
      return;
    }
    setState(() => _hasPermission = true);

    try {
      await _eye.start(streamPort: AppConstants.defaultHttpPort);
      _eye.onSoundAlert = (soundType) {
        if (!mounted) return;
        if (soundType == 'whistle') SoundEffectsService.playVarWhistle();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              soundType == 'whistle'
                  ? '🚨 REMOTE VAR REFEREE WHISTLE TRIGGERED!'
                  : '🔊 Remote sound alert: $soundType',
            ),
            backgroundColor: JokarzColors.crimsonDark,
            duration: const Duration(seconds: 2),
          ),
        );
      };

      await _discovery.startBroadcasting(
        deviceName: 'Jokarz Eye (${_localIps.first})',
        streamPort: AppConstants.defaultHttpPort,
        controlPort: AppConstants.defaultControlPort,
      );

      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _secondsStreaming++);
        }
      });
      _uiRefreshTimer?.cancel();
      _uiRefreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() {});
      });

      setState(() => _errorMessage = null);
    } catch (e) {
      setState(() => _errorMessage = 'Camera startup error: $e');
    }
  }

  Future<void> _applyPreset(VideoQualityPreset preset) async {
    if (preset == _qualityPreset) return;
    setState(() => _qualityPreset = preset);
    final name = switch (preset) {
      VideoQualityPreset.ultra4k1080p => 'ultra4k1080p',
      VideoQualityPreset.highSpeed60 => 'highSpeed60',
      VideoQualityPreset.balanced720p => 'balanced720p',
    };
    await _eye.setQualityPreset(name);
  }

  Future<void> _setTorch(bool enable) async {
    await _eye.setTorch(enable);
    if (mounted) setState(() => _torchOn = enable);
  }

  Future<void> _setZoom(double value) async {
    setState(() => _zoom = value.clamp(_minZoom, _maxZoom));
    await _eye.setZoom(_zoom);
  }

  Future<void> _flipCamera() async {
    await _eye.flipCamera();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsAndStart();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _durationTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _eye.dispose();
    _discovery.stopBroadcasting();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryIp = _localIps.isNotEmpty ? _localIps.first : '127.0.0.1';
    final signalUrl = 'http://$primaryIp:${AppConstants.defaultHttpPort}/webrtc/offer';
    final isLive = _eye.isStreaming;
    final fps = _eye.currentFps;

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
            tooltip: 'Restart Stream',
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
                    color: isLive ? JokarzColors.emerald : JokarzColors.gold,
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isLive ? JokarzColors.emerald : JokarzColors.gold)
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
                    // Live WebRTC viewfinder
                    if (_hasPermission && isLive)
                      RTCVideoView(
                        _eye.localRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    else if (!_hasPermission)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_off,
                                  size: 48, color: JokarzColors.crimson),
                              const SizedBox(height: 12),
                              const Text(
                                'CAMERA PERMISSION REQUIRED',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: JokarzColors.gold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Allow camera access so Jokarz Eye can broadcast your game table.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: JokarzColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton(
                                onPressed: _checkPermissionsAndStart,
                                child: const Text('Grant Camera Permission'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: JokarzColors.gold),
                            const SizedBox(height: 14),
                            Text(
                              _errorMessage ?? 'STARTING TABLETOP CAMERA...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _errorMessage != null
                                    ? JokarzColors.crimson
                                    : JokarzColors.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Framing Alignment Grid Overlay
                    if (_showAlignmentGrid && isLive)
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(220),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isLive
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
                                    color: isLive
                                        ? JokarzColors.emerald
                                        : JokarzColors.crimson,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isLive
                                      ? 'H.264 WEBRTC LIVE'
                                      : 'STARTING SENSOR',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: isLive
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
                                  _isFullScreenPreview
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen,
                                  color: JokarzColors.gold,
                                  size: 22,
                                ),
                                tooltip: 'Expand Viewfinder',
                                onPressed: () => setState(
                                    () => _isFullScreenPreview =
                                        !_isFullScreenPreview),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(220),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: JokarzColors.gold),
                                ),
                                child: Text(
                                  '$fps FPS',
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
                    if (isLive)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'torchBtn',
                              backgroundColor:
                                  _torchOn ? JokarzColors.gold : Colors.black87,
                              foregroundColor:
                                  _torchOn ? Colors.black : JokarzColors.gold,
                              onPressed: () => _setTorch(!_torchOn),
                              tooltip: 'Toggle Table Spotlight (Flash)',
                              child: Icon(_torchOn
                                  ? Icons.flashlight_on
                                  : Icons.flashlight_off),
                            ),
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

              const SizedBox(height: 14),

              // Resolution & High-Speed FPS Preset Selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: JokarzColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: JokarzColors.gold.withAlpha(120)),
                ),
                child: Row(
                  children: [
                    _presetPill(
                      VideoQualityPreset.ultra4k1080p,
                      Icons.four_k,
                      '💎 4K / 1080p CRISP',
                      JokarzColors.gold,
                    ),
                    _presetPill(
                      VideoQualityPreset.highSpeed60,
                      Icons.bolt,
                      '🚀 60 FPS TURBO',
                      JokarzColors.crimson,
                    ),
                    _presetPill(
                      VideoQualityPreset.balanced720p,
                      Icons.speed,
                      '⚡ 720p FAST',
                      JokarzColors.emerald,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

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
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      ),
                      onPressed: _showQrDialog,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: JokarzColors.emerald,
                        side: const BorderSide(
                            color: JokarzColors.emerald, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.wifi_tethering, size: 20),
                      label: const Text(
                        '0-Router Guide',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 0.8),
                      ),
                      onPressed: _showOfflineHotspotGuide,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

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
                    _buildStatItem(
                        'Active Viewers', '${_eye.viewerCount}', Icons.people),
                    _buildStatItem('Codec', 'H.264', Icons.memory),
                    _buildStatItem(
                        'Uptime', _formatTime(_secondsStreaming), Icons.timer),
                  ],
                ),
              ),

              const SizedBox(height: 14),

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
                          'DIRECT WI-FI WEBRTC SIGNAL URL',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: JokarzColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: JokarzColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              signalUrl,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: JokarzColors.emerald,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy,
                                size: 18, color: JokarzColors.gold),
                            tooltip: 'Copy URL',
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: signalUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Signal URL copied to clipboard!'),
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
                      '📡 Auto-discovery beacon active on UDP:45454. The table controller app links automatically over WebRTC (hardware H.264).',
                      style: TextStyle(fontSize: 11, color: JokarzColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

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
                            onChanged: _setZoom,
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

  Widget _presetPill(
    VideoQualityPreset preset,
    IconData icon,
    String label,
    Color activeColor,
  ) {
    final isActive = _qualityPreset == preset;
    final fg = isActive ? Colors.black : JokarzColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: () => _applyPreset(preset),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: fg,
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
          style: const TextStyle(fontSize: 11, color: JokarzColors.textSecondary),
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

    final thirdW = size.width / 3;
    final thirdH = size.height / 3;

    canvas.drawLine(Offset(thirdW, 0), Offset(thirdW, size.height), paint);
    canvas.drawLine(Offset(thirdW * 2, 0), Offset(thirdW * 2, size.height), paint);
    canvas.drawLine(Offset(0, thirdH), Offset(size.width, thirdH), paint);
    canvas.drawLine(Offset(0, thirdH * 2), Offset(size.width, thirdH * 2), paint);

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
