enum InsightTone {
  positive,
  neutral,
  caution;

  static InsightTone fromString(String v) {
    return InsightTone.values.firstWhere(
      (e) => e.name == v,
      orElse: () => InsightTone.neutral,
    );
  }
}

class ProactiveInsight {
  final String id;
  final DateTime createdAt;
  final String triggerType;
  final String? category;
  final String message;
  final InsightTone tone;
  final String? suggestedAction;
  final String? actionLabel;
  final bool dismissed;

  const ProactiveInsight({
    required this.id,
    required this.createdAt,
    required this.triggerType,
    this.category,
    required this.message,
    required this.tone,
    this.suggestedAction,
    this.actionLabel,
    this.dismissed = false,
  });

  ProactiveInsight copyWith({
    String? id,
    DateTime? createdAt,
    String? triggerType,
    String? category,
    String? message,
    InsightTone? tone,
    String? suggestedAction,
    String? actionLabel,
    bool? dismissed,
  }) {
    return ProactiveInsight(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      triggerType: triggerType ?? this.triggerType,
      category: category ?? this.category,
      message: message ?? this.message,
      tone: tone ?? this.tone,
      suggestedAction: suggestedAction ?? this.suggestedAction,
      actionLabel: actionLabel ?? this.actionLabel,
      dismissed: dismissed ?? this.dismissed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'triggerType': triggerType,
        'category': category,
        'message': message,
        'tone': tone.name,
        'suggestedAction': suggestedAction,
        'actionLabel': actionLabel,
        'dismissed': dismissed,
      };
}
