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
  // One shared player keeps play-trigger overhead near zero; we use a single
  // `AudioPlayer` and swap sources. `releaseMode` lets short SFX be replayed
  // rapidly without the underlying player being torn down each time.
  static final AudioPlayer _player = AudioPlayer()
    ..setReleaseMode(ReleaseMode.release);

  static Future<void> _playAsset(String asset, {bool haptic = false}) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$asset'));
    } catch (e) {
      debugPrint('Audio playback failed for $asset: $e');
    }
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
