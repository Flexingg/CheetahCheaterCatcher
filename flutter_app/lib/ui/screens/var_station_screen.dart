import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../services/sound_effects_service.dart';
import '../../state/telestrator_provider.dart';
import '../../state/var_replay_provider.dart';
import '../widgets/device_scanner_sheet.dart';
import '../widgets/replay_scrubber_widget.dart';
import '../widgets/telestrator_canvas_widget.dart';
import '../widgets/var_soundboard_sheet.dart';

class VarStationScreen extends StatefulWidget {
  const VarStationScreen({super.key});

  @override
  State<VarStationScreen> createState() => _VarStationScreenState();
}

class _VarStationScreenState extends State<VarStationScreen> {
  final TransformationController _transformController = TransformationController();
  BoxFit _videoFit = BoxFit.cover; // Default to full screen edge-to-edge

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _openDeviceScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DeviceScannerSheet(),
    );
  }

  void _toggleVideoFit() {
    setState(() {
      _videoFit = _videoFit == BoxFit.cover ? BoxFit.contain : BoxFit.cover;
    });
  }

  @override
  Widget build(BuildContext context) {
    final varProvider = context.watch<VarReplayProvider>();
    final telestrator = context.watch<TelestratorProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top VAR Referee Control Bar
            _buildTopActionBar(context, varProvider, telestrator),

            // Video Player + Telestrator + Alignment Grid Viewport
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Full-Screen Edge-to-Edge Video Viewport with Pinch-To-Zoom (up to 10.0x) and Pan
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 1.0,
                        maxScale: 10.0,
                        panEnabled: !telestrator.isDrawingEnabled,
                        scaleEnabled: !telestrator.isDrawingEnabled,
                        child: SizedBox.expand(
                          child: _buildVideoFrameDisplay(varProvider),
                        ),
                      ),
                    ),
                  ),

                  // Tabletop Framing Alignment Grid Overlay
                  if (varProvider.isAlignmentGridVisible && varProvider.isConnected)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _TableAlignmentGridPainter(),
                        ),
                      ),
                    ),

                  // Telestrator Drawing Layer
                  const Positioned.fill(
                    child: TelestratorCanvasWidget(),
                  ),

                  // Status HUD Overlay (Top-Left)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _buildHudBadge(varProvider),
                  ),

                  // Remote Camera Controls Pill (Top-Right)
                  if (varProvider.isConnected)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _buildRemoteControlsPill(varProvider),
                    ),

                  // Floating Quick Actions (Bottom-Right)
                  if (varProvider.isConnected && !varProvider.isReplayActive)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Toggle Full-Screen Fill vs Fit Aspect
                          FloatingActionButton.small(
                            heroTag: 'fitScreenBtn',
                            backgroundColor: Colors.black87,
                            foregroundColor: JokarzColors.gold,
                            tooltip: _videoFit == BoxFit.cover ? 'Fit Aspect Ratio' : 'Fill 100% Screen',
                            onPressed: _toggleVideoFit,
                            child: Icon(
                              _videoFit == BoxFit.cover ? Icons.fit_screen : Icons.fullscreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Reset Zoom
                          FloatingActionButton.small(
                            heroTag: 'resetZoomBtn',
                            backgroundColor: Colors.black87,
                            foregroundColor: JokarzColors.gold,
                            tooltip: 'Reset Viewport Zoom',
                            onPressed: () {
                              _transformController.value = Matrix4.identity();
                            },
                            child: const Icon(Icons.zoom_out_map, size: 20),
                          ),
                          const SizedBox(height: 8),
                          // Grid Overlay Toggle
                          FloatingActionButton.small(
                            heroTag: 'toggleOverlayBtn',
                            backgroundColor: Colors.black87,
                            foregroundColor: JokarzColors.gold,
                            tooltip: 'Toggle Table Grid',
                            onPressed: varProvider.toggleAlignmentGrid,
                            child: Icon(
                              varProvider.isAlignmentGridVisible ? Icons.grid_on : Icons.grid_off,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Remote Zoom & Quality Bar (When connected & NOT in replay)
            if (varProvider.isConnected && !varProvider.isReplayActive)
              _buildCameraSettingsBar(context, varProvider),

            // Bottom Replay Scrubber (Appears when Replay is active)
            if (varProvider.isReplayActive)
              const Padding(
                padding: EdgeInsets.all(10),
                child: ReplayScrubberWidget(),
              ),

            // Bottom Bar: Replay / Telestrator Actions (when Replay is NOT active)
            if (!varProvider.isReplayActive)
              _buildBottomControlsBar(context, varProvider, telestrator),
          ],
        ),
      ),
    );
  }

  Widget _buildTopActionBar(
    BuildContext context,
    VarReplayProvider varProvider,
    TelestratorProvider telestrator,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: JokarzColors.surface,
      child: Row(
        children: [
          // Device / Discovery Button
          InkWell(
            onTap: _openDeviceScanner,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: varProvider.isConnected
                    ? JokarzColors.emerald.withAlpha(30)
                    : JokarzColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: varProvider.isConnected ? JokarzColors.emerald : JokarzColors.cardBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: varProvider.isConnected ? JokarzColors.emerald : JokarzColors.gold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    varProvider.isConnected
                        ? (varProvider.activeCamera?.deviceName ?? 'Connected')
                        : 'Select Camera',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: varProvider.isConnected
                          ? JokarzColors.emerald
                          : JokarzColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Grid Toggle
          IconButton(
            icon: Icon(
              varProvider.isAlignmentGridVisible ? Icons.grid_on : Icons.grid_off,
              color: varProvider.isAlignmentGridVisible ? JokarzColors.gold : JokarzColors.textMuted,
              size: 22,
            ),
            tooltip: 'Toggle Table Grid',
            onPressed: varProvider.toggleAlignmentGrid,
          ),

          // Whistle & Soundboard Trigger
          IconButton(
            icon: const Icon(Icons.volume_up, color: JokarzColors.gold, size: 22),
            tooltip: 'VAR Referee Soundboard',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => VarSoundboardSheet(
                  onTriggerRemote: (soundType) {
                    varProvider.streamClient.sendControlCommand('sound_alert', soundType.name);
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 4),

          // Whistle / Foul VAR Check Trigger
          IconButton(
            icon: const Icon(Icons.sports, color: JokarzColors.crimson, size: 22),
            tooltip: 'VAR Whistle Check',
            onPressed: () {
              SoundEffectsService.playVarWhistle();
              varProvider.streamClient.sendControlCommand('sound_alert', 'whistle');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 VAR REVIEW IN PROGRESS!'),
                  backgroundColor: JokarzColors.crimsonDark,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),

          // Telestrator Toggle
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: telestrator.isDrawingEnabled ? JokarzColors.crimson : JokarzColors.gold,
              side: BorderSide(
                color: telestrator.isDrawingEnabled ? JokarzColors.crimson : JokarzColors.gold,
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
            icon: Icon(
              Icons.edit,
              size: 14,
              color: telestrator.isDrawingEnabled ? JokarzColors.crimson : JokarzColors.gold,
            ),
            label: Text(
              telestrator.isDrawingEnabled ? 'DRAW: ON' : 'TELESTRATOR',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onPressed: telestrator.toggleDrawing,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoFrameDisplay(VarReplayProvider varProvider) {
    final frameBytes = varProvider.currentFrameBytes;

    if (frameBytes != null && frameBytes.isNotEmpty) {
      return Image.memory(
        frameBytes,
        gaplessPlayback: true,
        fit: _videoFit,
        filterQuality: FilterQuality.high,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildPlaceholderFeed(varProvider),
      );
    }

    return _buildPlaceholderFeed(varProvider);
  }

  Widget _buildPlaceholderFeed(VarReplayProvider varProvider) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF070A0F),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: JokarzColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: JokarzColors.cardBorder, width: 2),
              ),
              child: const Icon(
                Icons.videocam_off,
                size: 40,
                color: JokarzColors.goldLight,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Live Feed Connected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: JokarzColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "Select Camera" to connect to Jokarz Eye on local Wi-Fi',
              style: TextStyle(fontSize: 12, color: JokarzColors.textSecondary),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              icon: const Icon(Icons.wifi_find, size: 18),
              label: const Text('Scan Local Cameras'),
              onPressed: _openDeviceScanner,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHudBadge(VarReplayProvider varProvider) {
    final isReplay = varProvider.isReplayActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isReplay ? JokarzColors.crimson : JokarzColors.emerald,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isReplay ? JokarzColors.crimson : JokarzColors.emerald,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isReplay
                ? 'VAR REPLAY (${varProvider.totalBufferedFrames}f)'
                : '1080p CRISP • ${varProvider.currentFps} FPS',
            style: TextStyle(
              color: isReplay ? JokarzColors.crimson : JokarzColors.emerald,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteControlsPill(VarReplayProvider varProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: JokarzColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Remote Torch Toggle
          IconButton(
            icon: Icon(
              varProvider.isRemoteTorchOn ? Icons.flashlight_on : Icons.flashlight_off,
              size: 18,
              color: varProvider.isRemoteTorchOn ? JokarzColors.gold : Colors.white70,
            ),
            tooltip: 'Remote Table Spotlight (Flash)',
            visualDensity: VisualDensity.compact,
            onPressed: varProvider.toggleRemoteTorch,
          ),
          // Remote Camera Flip
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, size: 18, color: Colors.white70),
            tooltip: 'Remote Camera Flip',
            visualDensity: VisualDensity.compact,
            onPressed: varProvider.flipRemoteCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSettingsBar(BuildContext context, VarReplayProvider varProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: JokarzColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode / Resolution Selector Row
          Row(
            children: [
              _buildQualityPill(
                varProvider,
                'ultra4k1080p',
                '💎 4K / 1080p CRISP',
                JokarzColors.gold,
              ),
              const SizedBox(width: 8),
              _buildQualityPill(
                varProvider,
                'highSpeed60',
                '🚀 60 FPS TURBO',
                JokarzColors.crimson,
              ),
              const SizedBox(width: 8),
              _buildQualityPill(
                varProvider,
                'balanced720p',
                '⚡ 720p FAST',
                JokarzColors.emerald,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Remote Zoom Slider Row
          Row(
            children: [
              const Icon(Icons.zoom_in, color: JokarzColors.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                'Remote Zoom: ${varProvider.remoteZoom.toStringAsFixed(1)}x',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Slider(
                  value: varProvider.remoteZoom.clamp(1.0, 4.0),
                  min: 1.0,
                  max: 4.0,
                  divisions: 15,
                  activeColor: JokarzColors.gold,
                  onChanged: (val) => varProvider.setRemoteZoom(val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityPill(
    VarReplayProvider varProvider,
    String presetKey,
    String label,
    Color activeColor,
  ) {
    final isSelected = varProvider.remoteQuality == presetKey;

    return Expanded(
      child: InkWell(
        onTap: () => varProvider.setRemoteQualityPreset(presetKey),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : JokarzColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : JokarzColors.cardBorder,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isSelected ? (activeColor == JokarzColors.gold ? Colors.black : Colors.white) : JokarzColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControlsBar(
    BuildContext context,
    VarReplayProvider varProvider,
    TelestratorProvider telestrator,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: JokarzColors.surface,
      child: Row(
        children: [
          // Instant Replay Trigger
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: JokarzColors.crimson,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.slow_motion_video, size: 20),
              label: const Text(
                'INSTANT SLOW-MO REPLAY',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              onPressed: varProvider.enterReplayMode,
            ),
          ),
        ],
      ),
    );
  }
}

/// Table alignment grid painter for referee alignment
class _TableAlignmentGridPainter extends CustomPainter {
  const _TableAlignmentGridPainter();

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
