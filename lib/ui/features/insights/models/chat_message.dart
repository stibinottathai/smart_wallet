class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  /// Whether this message is an error notification (should not be sent to the API).
  final bool isError;
  /// Whether this message was generated locally by the app (e.g. welcome message)
  /// and should not be included in API chat history.
  final bool isSystemGenerated;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.isSystemGenerated = false,
  });

  /// Returns true if this message should be included in API chat history.
  bool get shouldIncludeInHistory => !isError && !isSystemGenerated;
}
