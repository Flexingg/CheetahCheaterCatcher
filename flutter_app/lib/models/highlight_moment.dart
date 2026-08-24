enum HighlightType {
  varReview,
  hugeScore,
  epicBlunder,
  winningMoment,
  custom,
}

class HighlightMoment {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final int? frameIndex;
  final int? roundNumber;
  final String? playerName;
  final HighlightType type;

  HighlightMoment({
    required this.id,
    required this.title,
    required this.description,
    DateTime? timestamp,
    this.frameIndex,
    this.roundNumber,
    this.playerName,
    this.type = HighlightType.varReview,
  }) : timestamp = timestamp ?? DateTime.now();

  String get typeIcon {
    switch (type) {
      case HighlightType.varReview:
        return '🚨';
      case HighlightType.hugeScore:
        return '🔥';
      case HighlightType.epicBlunder:
        return '💀';
      case HighlightType.winningMoment:
        return '👑';
      case HighlightType.custom:
        return '⭐';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'frameIndex': frameIndex,
        'roundNumber': roundNumber,
        'playerName': playerName,
        'type': type.name,
      };

  factory HighlightMoment.fromJson(Map<String, dynamic> json) => HighlightMoment(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        frameIndex: json['frameIndex'] as int?,
        roundNumber: json['roundNumber'] as int?,
        playerName: json['playerName'] as String?,
        type: HighlightType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => HighlightType.varReview,
        ),
      );
}
