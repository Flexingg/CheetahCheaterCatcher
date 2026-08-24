import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_theme.dart';
import '../widgets/poker_card_widgets.dart';
import 'camera_broadcaster_screen.dart';
import 'controller_main_screen.dart';

class SplashRoleScreen extends StatelessWidget {
  const SplashRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: JokarzColors.background,
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.2,
            colors: [
              JokarzColors.surfaceLight.withAlpha(200),
              JokarzColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 1),

                // Brand Emblem & Title
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: JokarzColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: JokarzColors.gold, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: JokarzColors.gold.withAlpha(90),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Text(
                    '🃏',
                    style: TextStyle(fontSize: 48),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: JokarzColors.gold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'HIGH-ROLLER GAME NIGHT VAR & SCOREBOARD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: JokarzColors.textSecondary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('♠️ ', style: TextStyle(fontSize: 18, color: JokarzColors.spade)),
                    Text('♥️ ', style: TextStyle(fontSize: 18, color: JokarzColors.heart)),
                    Text('♦️ ', style: TextStyle(fontSize: 18, color: JokarzColors.diamond)),
                    Text('♣️', style: TextStyle(fontSize: 18, color: JokarzColors.club)),
                  ],
                ),

                const Spacer(flex: 2),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SELECT THIS DEVICE ROLE:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: JokarzColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Role Option 1: Jokarz Table (Referee & Scoreboard)
                JokarzCard(
                  borderColor: JokarzColors.gold,
                  backgroundColor: JokarzColors.surface,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ControllerMainScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: JokarzColors.gold.withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: JokarzColors.gold.withAlpha(120)),
                        ),
                        child: const Icon(
                          Icons.sports,
                          color: JokarzColors.gold,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jokarz Table (VAR & Controller)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: JokarzColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Live VAR feed, instant replay DVR, telestrator drawing, scoreboard & trophies.',
                              style: TextStyle(
                                fontSize: 12,
                                color: JokarzColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: JokarzColors.gold,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Role Option 2: Jokarz Eye (Camera Broadcaster)
                JokarzCard(
                  borderColor: JokarzColors.emerald,
                  backgroundColor: JokarzColors.surface,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CameraBroadcasterScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: JokarzColors.emerald.withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: JokarzColors.emerald.withAlpha(120)),
                        ),
                        child: const Icon(
                          Icons.videocam,
                          color: JokarzColors.emerald,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jokarz Eye (Camera Streamer)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: JokarzColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Streams video directly over local Wi-Fi to the table controller device.',
                              style: TextStyle(
                                fontSize: 12,
                                color: JokarzColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: JokarzColors.emerald,
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Footer Tip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: JokarzColors.surfaceLight.withAlpha(120),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi, size: 16, color: JokarzColors.gold),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Place both devices on the same Wi-Fi network for instant auto-discovery.',
                          style: TextStyle(fontSize: 11, color: JokarzColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
