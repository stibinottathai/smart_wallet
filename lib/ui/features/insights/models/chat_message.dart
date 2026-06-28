import 'package:smart_wallet/data/services/insights_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  /// Whether this message is an error notification (should not be sent to the API).
  final bool isError;
  /// Whether this message was generated locally by the app (e.g. welcome message)
  /// and should not be included in API chat history.
  final bool isSystemGenerated;

  /// When non-null, this bubble renders an interactive confirmation card so the
  /// user can pick the account (and category) before the expense/income is
  /// actually saved. Resolved cards keep the action for reference but render as
  /// a plain confirmation.
  final AssistantAction? pendingAction;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.isSystemGenerated = false,
    this.pendingAction,
  });

  /// Returns true if this message should be included in API chat history.
  bool get shouldIncludeInHistory => !isError && !isSystemGenerated && pendingAction == null;
}
