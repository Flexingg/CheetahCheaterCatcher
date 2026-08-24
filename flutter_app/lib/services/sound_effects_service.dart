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
  static void playSound(VarSoundType type) {
    switch (type) {
      case VarSoundType.whistle:
        playVarWhistle();
        break;
      case VarSoundType.siren:
        playSirenAlarm();
        break;
      case VarSoundType.buzzer:
        playStadiumBuzzer();
        break;
      case VarSoundType.chips:
        playChipClick();
        break;
      case VarSoundType.victory:
        playVictoryPodium();
        break;
      case VarSoundType.bell:
        playRoundBell();
        break;
    }
  }

  static void playChipClick() {
    HapticFeedback.lightImpact();
  }

  static void playScoreChange() {
    HapticFeedback.selectionClick();
  }

  static void playVarWhistle() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.heavyImpact();
    });
  }

  static void playSirenAlarm() {
    for (int i = 0; i < 4; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        HapticFeedback.heavyImpact();
      });
    }
  }

  static void playStadiumBuzzer() {
    HapticFeedback.vibrate();
  }

  static void playRoundBell() {
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 120), () {
      HapticFeedback.lightImpact();
    });
  }

  static void playVictoryPodium() {
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      HapticFeedback.heavyImpact();
    });
  }

  static void playTelestratorStroke() {
    HapticFeedback.selectionClick();
  }
}
