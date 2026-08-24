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

            // Video Player + Telestrator Interactive Viewport
            Expanded(
              child: Stack(
                children: [
                  // Video Viewport with Pinch-To-Zoom and Pan
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 1.0,
                        maxScale: 5.0,
                        panEnabled: !telestrator.isDrawingEnabled,
                        scaleEnabled: !telestrator.isDrawingEnabled,
                        child: Center(
                          child: _buildVideoFrameDisplay(varProvider),
                        ),
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
                ],
              ),
            ),

            // Bottom Replay Scrubber (Appears when Replay is active)
            if (varProvider.isReplayActive)
              const Padding(
                padding: EdgeInsets.all(10),
                child: ReplayScrubberWidget(),
              ),

            // Bottom Bar: Replay / Telestrator / Ref Actions (when Replay is NOT active)
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
        fit: BoxFit.contain,
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
        color: Colors.black.withAlpha(190),
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
            isReplay ? 'VAR REPLAY' : 'LIVE ${varProvider.currentFps} FPS',
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
        color: Colors.black.withAlpha(190),
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
            tooltip: 'Remote Table Torch',
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
              icon: const Icon(Icons.history, size: 20),
              label: const Text(
                'INSTANT REPLAY',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              onPressed: varProvider.enterReplayMode,
            ),
          ),
          const SizedBox(width: 12),

          // Reset Zoom button (if zoomed)
          if (varProvider.refZoomScale > 1.05)
            IconButton(
              icon: const Icon(Icons.zoom_out_map, color: JokarzColors.gold),
              tooltip: 'Reset Zoom',
              onPressed: () {
                _transformController.value = Matrix4.identity();
              },
            ),
        ],
      ),
    );
  }
}
