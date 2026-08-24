import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import 'poker_card_widgets.dart';

class OfflineHotspotGuideSheet extends StatelessWidget {
  final List<String> detectedIps;

  const OfflineHotspotGuideSheet({super.key, required this.detectedIps});

  @override
  Widget build(BuildContext context) {
    final hasHotspotIp = detectedIps.any(
      (ip) => ip.startsWith('192.168.43.') || ip.startsWith('172.20.10.') || ip.startsWith('192.168.137.'),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: JokarzColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: JokarzColors.emerald.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_tethering, color: JokarzColors.emerald, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OFFLINE / ZERO-ROUTER PLAY',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: JokarzColors.gold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Play anywhere without home internet or Wi-Fi routers',
                      style: TextStyle(fontSize: 11, color: JokarzColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: hasHotspotIp ? JokarzColors.emerald.withAlpha(25) : JokarzColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasHotspotIp ? JokarzColors.emerald : JokarzColors.cardBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasHotspotIp ? Icons.check_circle : Icons.info_outline,
                  color: hasHotspotIp ? JokarzColors.emerald : JokarzColors.gold,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasHotspotIp
                      ? 'Personal Hotspot Subnet Detected! Direct connection ready.'
                      : 'Standard Wi-Fi Mode. Follow steps below for zero-router outdoor play.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasHotspotIp ? JokarzColors.emerald : JokarzColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: JokarzColors.divider),
          const SizedBox(height: 12),

          // Steps list
          Expanded(
            child: ListView(
              children: [
                _buildStepCard(
                  step: '1',
                  title: 'Turn on Personal Hotspot on Phone A',
                  description:
                      'Enable Portable Hotspot / Tethering in phone settings. Mobile data can be OFF — only local Wi-Fi tethering is needed.',
                  icon: Icons.phone_android,
                ),
                const SizedBox(height: 10),
                _buildStepCard(
                  step: '2',
                  title: 'Connect Phone B to the Hotspot',
                  description:
                      'Join Phone A\'s Hotspot Wi-Fi network from Phone B\'s Wi-Fi settings.',
                  icon: Icons.wifi,
                ),
                const SizedBox(height: 10),
                _buildStepCard(
                  step: '3',
                  title: 'Launch Jokarz Plays on Both Devices',
                  description:
                      'Set Phone A as "Jokarz Eye (Camera)" and Phone B as "Jokarz Table (VAR)". Auto-discovery will connect instantly!',
                  icon: Icons.flash_on,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return JokarzCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: JokarzColors.gold,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: JokarzColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: JokarzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
