import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_theme.dart';
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

class _CameraBroadcasterScreenState extends State<CameraBroadcasterScreen> {
  final MjpegCameraServer _server = MjpegCameraServer();
  final NetworkDiscoveryService _discovery = NetworkDiscoveryService();

  List<String> _localIps = [];
  bool _isServerRunning = false;
  int _secondsStreaming = 0;
  Timer? _durationTimer;
  Timer? _uiRefreshTimer;

  bool _isSimulatorMode = true; // Default simulator frames ready on startup
  bool _torchOn = false;
  double _zoom = 1.0;
  bool _frontCam = false;

  @override
  void initState() {
    super.initState();
    _initBroadcasting();
  }

  Future<void> _initBroadcasting() async {
    _localIps = await NetworkDiscoveryService.getLocalIpAddresses();
    if (_localIps.isEmpty) {
      _localIps = ['127.0.0.1'];
    }

    final success = await _server.startServer();
    if (success) {
      _isServerRunning = true;
      if (_isSimulatorMode) {
        _server.startSimulatorStream();
      }

      await _discovery.startBroadcasting(
        deviceName: 'Jokarz Eye (${_localIps.first})',
        streamPort: AppConstants.defaultHttpPort,
        controlPort: AppConstants.defaultControlPort,
      );

      _server.onRemoteCommand = (action, value) {
        setState(() {
          if (action == 'torch' && value is bool) _torchOn = value;
          if (action == 'zoom' && value is num) _zoom = value.toDouble();
          if (action == 'flip_camera') _frontCam = !_frontCam;
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
        });
      };

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _secondsStreaming++;
        });
      });

      _uiRefreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() {});
      });
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
    _durationTimer?.cancel();
    _uiRefreshTimer?.cancel();
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
        title: const Text('Jokarz Eye Broadcaster'),
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
            tooltip: 'Refresh Network',
            onPressed: _initBroadcasting,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Broadcaster Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: JokarzColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isServerRunning ? JokarzColors.emerald : JokarzColors.crimson,
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isServerRunning ? JokarzColors.emerald : JokarzColors.crimson).withAlpha(50),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _isServerRunning ? JokarzColors.emerald : JokarzColors.crimson,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isServerRunning ? 'STREAMING ACTIVE' : 'OFFLINE',
                              style: TextStyle(
                                color: _isServerRunning ? JokarzColors.emerald : JokarzColors.crimson,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_server.currentFps} FPS',
                          style: const TextStyle(
                            color: JokarzColors.gold,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick Telemetry Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Viewers', '${_server.activeViewers}', Icons.people),
                        _buildStatItem('Duration', _formatTime(_secondsStreaming), Icons.timer),
                        _buildStatItem('Port', '${AppConstants.defaultHttpPort}', Icons.lan),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Fast Pairing Row (QR Code + Hotspot buttons)
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
                      '📡 Auto-discovery beacon broadcasting on UDP:45454. The controller app will detect this device automatically.',
                      style: TextStyle(fontSize: 11, color: JokarzColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Camera Hardware Controls & Sim Switch
              JokarzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CAMERA & LIGHT CONTROLS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: JokarzColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Torch / Flashlight Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
                        color: _torchOn ? JokarzColors.gold : JokarzColors.textMuted,
                      ),
                      title: const Text('Table Spotlight (Torch)'),
                      subtitle: const Text('Illuminates cards/dice in dim rooms', style: TextStyle(fontSize: 11)),
                      value: _torchOn,
                      activeColor: JokarzColors.gold,
                      onChanged: (val) {
                        setState(() {
                          _torchOn = val;
                        });
                      },
                    ),

                    const Divider(color: JokarzColors.divider),

                    // Front / Back Camera Flip
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _frontCam ? Icons.camera_front : Icons.camera_rear,
                        color: JokarzColors.gold,
                      ),
                      title: Text(_frontCam ? 'Front Camera (Selfie)' : 'Rear Camera (Overhead Table)'),
                      trailing: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _frontCam = !_frontCam;
                          });
                        },
                        child: const Text('Flip'),
                      ),
                    ),

                    const Divider(color: JokarzColors.divider),

                    // Digital Zoom Slider
                    Row(
                      children: [
                        const Icon(Icons.zoom_in, color: JokarzColors.gold),
                        const SizedBox(width: 10),
                        Text('Zoom: ${_zoom.toStringAsFixed(1)}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Slider(
                            value: _zoom,
                            min: 1.0,
                            max: 4.0,
                            divisions: 30,
                            activeColor: JokarzColors.gold,
                            onChanged: (val) {
                              setState(() {
                                _zoom = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const Divider(color: JokarzColors.divider),

                    // Simulator Test Pattern Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.pattern, color: JokarzColors.velvetPurple),
                      title: const Text('Poker Table Test Stream'),
                      subtitle: const Text('Generates high-fps simulated cards & chips feed', style: TextStyle(fontSize: 11)),
                      value: _isSimulatorMode,
                      activeColor: JokarzColors.velvetPurple,
                      onChanged: (val) {
                        setState(() {
                          _isSimulatorMode = val;
                          if (val) {
                            _server.startSimulatorStream();
                          } else {
                            _server.stopSimulatorStream();
                          }
                        });
                      },
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
