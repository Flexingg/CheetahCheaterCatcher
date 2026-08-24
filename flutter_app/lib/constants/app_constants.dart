class AppConstants {
  static const String appName = "Jokarz Plays";
  static const String appTagline = "Game Night VAR & High-Roller Scoreboard";

  // Networking
  static const int defaultHttpPort = 8080;
  static const int defaultControlPort = 8081;
  static const int discoveryPort = 45454;
  static const String discoverySignature = "JOKARZ_CAMERA_BEACON_V1";

  // DVR & Replay
  static const int maxDvrFrames = 900; // ~30 seconds @ 30fps or ~60s @ 15fps
  static const List<double> replaySpeeds = [0.1, 0.25, 0.5, 1.0, 2.0];

  // Quick Chips
  static const List<int> chipValues = [1, 5, 10, 25, 50, 100];
  static const List<int> penaltyChipValues = [-1, -5, -10, -25];

  // Game Presets
  static const List<Map<String, dynamic>> gamePresets = [
    {
      "name": "Texas Hold'em / Poker",
      "winCondition": "highest",
      "icon": "🃏",
      "defaultChips": 500,
    },
    {
      "name": "Hearts",
      "winCondition": "lowest",
      "icon": "♥️",
      "defaultChips": 0,
    },
    {
      "name": "Golf (Card Game)",
      "winCondition": "lowest",
      "icon": "⛳",
      "defaultChips": 0,
    },
    {
      "name": "Settlers of Catan",
      "winCondition": "highest",
      "icon": "🏰",
      "defaultChips": 0,
    },
    {
      "name": "Uno",
      "winCondition": "lowest",
      "icon": "🎴",
      "defaultChips": 0,
    },
    {
      "name": "Spades",
      "winCondition": "highest",
      "icon": "♠️",
      "defaultChips": 0,
    },
    {
      "name": "Scrabble / Wordplay",
      "winCondition": "highest",
      "icon": "🔤",
      "defaultChips": 0,
    },
    {
      "name": "Dominoes",
      "winCondition": "lowest",
      "icon": "🀄",
      "defaultChips": 0,
    },
    {
      "name": "Custom Game",
      "winCondition": "highest",
      "icon": "🎲",
      "defaultChips": 0,
    },
  ];
}
