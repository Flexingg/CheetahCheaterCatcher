import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum VarSoundType {
  whistle,
  siren,
  buzzer,
  chips,
  victory,
  bell,
}

class SoundEffectsService {
  // A fresh AudioPlayer per trigger: reusing one player with stop->play can
  // fail to switch sources (so every pad sounded the same). Each player is
  // disposed after it finishes playing.
  static Future<void> _playAsset(String asset, {bool haptic = false}) async {
    final player = AudioPlayer();
    try {
      await player.setSource(AssetSource('sounds/$asset'));
      await player.resume();
    } catch (e) {
      debugPrint('Audio playback failed for $asset: $e');
      await player.dispose();
      return;
    }
    // Free the native player once playback completes.
    player.onPlayerComplete.first.then((_) => player.dispose());
    // Safety net so we never leak if completion never fires (dispose is idempotent).
    Future.delayed(const Duration(seconds: 6), () => player.dispose());
    if (haptic) {
      HapticFeedback.heavyImpact();
    }
  }

  static Future<void> playSound(VarSoundType type) async {
    switch (type) {
      case VarSoundType.whistle:
        await playVarWhistle();
        break;
      case VarSoundType.siren:
        await playSirenAlarm();
        break;
      case VarSoundType.buzzer:
        await playStadiumBuzzer();
        break;
      case VarSoundType.chips:
        await playChipClick();
        break;
      case VarSoundType.victory:
        await playVictoryPodium();
        break;
      case VarSoundType.bell:
        await playRoundBell();
        break;
    }
  }

  static Future<void> playChipClick() async {
    await _playAsset('chips.wav');
    HapticFeedback.lightImpact();
  }

  static Future<void> playScoreChange() async {
    HapticFeedback.selectionClick();
  }

  static Future<void> playVarWhistle() async {
    await _playAsset('whistle.wav');
  }

  static Future<void> playSirenAlarm() async {
    await _playAsset('siren.wav');
  }

  static Future<void> playStadiumBuzzer() async {
    await _playAsset('buzzer.wav', haptic: true);
  }

  static Future<void> playRoundBell() async {
    await _playAsset('bell.wav');
  }

  static Future<void> playVictoryPodium() async {
    await _playAsset('victory.wav');
  }

  static Future<void> playTelestratorStroke() async {
    HapticFeedback.selectionClick();
  }
}
