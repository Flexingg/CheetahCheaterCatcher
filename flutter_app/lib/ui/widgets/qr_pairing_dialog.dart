import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../constants/app_theme.dart';

class QrPairingDialog extends StatelessWidget {
  final String deviceName;
  final String ip;
  final int streamPort;
  final int controlPort;

  const QrPairingDialog({
    super.key,
    required this.deviceName,
    required this.ip,
    required this.streamPort,
    required this.controlPort,
  });

  String get qrPayload => 'jokarz://connect?ip=$ip&streamPort=$streamPort&controlPort=$controlPort&name=${Uri.encodeComponent(deviceName)}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: JokarzColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: JokarzColors.gold, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: JokarzColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.qr_code_scanner, size: 20, color: Colors.black),
                ),
                const SizedBox(width: 10),
                const Text(
                  '1-SECOND QR PAIRING',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: JokarzColors.gold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Scan this code with Jokarz Table controller to pair instantly',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: JokarzColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // High-Contrast QR Code Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: JokarzColors.gold.withAlpha(80),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0D1117),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0D1117),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // IP & Port Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: JokarzColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: JokarzColors.cardBorder),
              ),
              child: Text(
                '$ip:$streamPort',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: JokarzColors.emerald,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
