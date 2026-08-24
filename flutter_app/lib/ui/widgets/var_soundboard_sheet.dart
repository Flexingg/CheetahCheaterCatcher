import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../services/sound_effects_service.dart';

class VarSoundboardSheet extends StatelessWidget {
  final ValueChanged<VarSoundType>? onTriggerRemote;

  const VarSoundboardSheet({super.key, this.onTriggerRemote});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: JokarzColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('📢', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text(
                'VAR REFEREE SOUNDBOARD',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: JokarzColors.gold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Triggers synchronized haptics & table alert cues',
            style: TextStyle(fontSize: 12, color: JokarzColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Soundboard Buttons Grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildSoundPad(
                context,
                title: 'VAR SIREN',
                icon: '🚨',
                color: JokarzColors.crimson,
                soundType: VarSoundType.siren,
              ),
              _buildSoundPad(
                context,
                title: 'WHISTLE',
                icon: '⚽',
                color: JokarzColors.gold,
                soundType: VarSoundType.whistle,
              ),
              _buildSoundPad(
                context,
                title: 'BUZZER',
                icon: '📢',
                color: JokarzColors.velvetPurple,
                soundType: VarSoundType.buzzer,
              ),
              _buildSoundPad(
                context,
                title: 'CHIPS',
                icon: '🎰',
                color: JokarzColors.emerald,
                soundType: VarSoundType.chips,
              ),
              _buildSoundPad(
                context,
                title: 'ROUND BELL',
                icon: '🔔',
                color: JokarzColors.spade,
                soundType: VarSoundType.bell,
              ),
              _buildSoundPad(
                context,
                title: 'VICTORY',
                icon: '👑',
                color: JokarzColors.amber,
                soundType: VarSoundType.victory,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSoundPad(
    BuildContext context, {
    required String title,
    required String icon,
    required Color color,
    required VarSoundType soundType,
  }) {
    return InkWell(
      onTap: () {
        SoundEffectsService.playSound(soundType);
        onTriggerRemote?.call(soundType);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$icon Soundboard: $title triggered!'),
            backgroundColor: color,
            duration: const Duration(milliseconds: 1200),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: JokarzColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(140), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(40),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
