import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../models/camera_device_info.dart';
import '../../state/var_replay_provider.dart';
import 'offline_hotspot_guide_sheet.dart';

class DeviceScannerSheet extends StatefulWidget {
  const DeviceScannerSheet({super.key});

  @override
  State<DeviceScannerSheet> createState() => _DeviceScannerSheetState();
}

class _DeviceScannerSheetState extends State<DeviceScannerSheet> {
  final TextEditingController _ipController = TextEditingController(text: '192.168.1.');
  final TextEditingController _portController = TextEditingController(text: '8080');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VarReplayProvider>().startDiscovery();
    });
  }

  @override
  Widget build(BuildContext context) {
    final varProvider = context.watch<VarReplayProvider>();
    final cameras = varProvider.discoveredCameras;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: JokarzColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: JokarzColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.wifi_tethering, color: JokarzColors.gold, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Jokarz Eye Discovery',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: JokarzColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (varProvider.isConnecting)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: JokarzColors.gold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ensure the camera phone has selected "Jokarz Eye Broadcaster" on the same Wi-Fi network.',
            style: TextStyle(fontSize: 12, color: JokarzColors.textSecondary),
          ),
          const SizedBox(height: 12),

          // 0-Router Guide button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: JokarzColors.emerald,
              side: const BorderSide(color: JokarzColors.emerald),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size.fromHeight(38),
            ),
            icon: const Icon(Icons.wifi_tethering, size: 16),
            label: const Text('Offline / Hotspot 0-Router Guide', style: TextStyle(fontSize: 12)),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const OfflineHotspotGuideSheet(detectedIps: []),
              );
            },
          ),
          const SizedBox(height: 16),

          // Discovered Cameras List
          if (cameras.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: JokarzColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: JokarzColors.cardBorder),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: JokarzColors.gold,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Scanning local Wi-Fi for active Jokarz Eye cameras...',
                      style: TextStyle(color: JokarzColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...cameras.map((cam) => _buildCameraTile(context, cam, varProvider)),
          ],

          const SizedBox(height: 20),
          const Divider(color: JokarzColors.divider),
          const SizedBox(height: 12),

          // Manual IP Fallback
          const Text(
            'OR CONNECT VIA MANUAL IP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: JokarzColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: 'Camera IP Address',
                    hintText: '192.168.1.100',
                    prefixIcon: Icon(Icons.videocam, size: 20, color: JokarzColors.gold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '8080',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onPressed: () {
                  final ip = _ipController.text.trim();
                  final port = int.tryParse(_portController.text.trim()) ?? 8080;
                  if (ip.isNotEmpty) {
                    varProvider.connectToManualIp(ip, port: port);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Connect'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCameraTile(
    BuildContext context,
    CameraDeviceInfo cam,
    VarReplayProvider provider,
  ) {
    final isConnected = provider.activeCamera?.ip == cam.ip && provider.isConnected;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: JokarzColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? JokarzColors.emerald : JokarzColors.gold.withAlpha(100),
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isConnected ? JokarzColors.emerald.withAlpha(40) : JokarzColors.surfaceLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.camera_alt,
            color: isConnected ? JokarzColors.emerald : JokarzColors.gold,
            size: 20,
          ),
        ),
        title: Text(
          cam.deviceName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: JokarzColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${cam.ip}:${cam.streamPort}',
          style: const TextStyle(
            fontSize: 12,
            color: JokarzColors.textSecondary,
            fontFamily: 'monospace',
          ),
        ),
        trailing: isConnected
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: JokarzColors.emerald.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: JokarzColors.emerald),
                ),
                child: const Text(
                  'CONNECTED',
                  style: TextStyle(
                    color: JokarzColors.emerald,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: JokarzColors.gold,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                ),
                onPressed: () {
                  provider.connectToCamera(cam);
                  Navigator.of(context).pop();
                },
                child: const Text('Connect', style: TextStyle(fontSize: 12)),
              ),
      ),
    );
  }
}
