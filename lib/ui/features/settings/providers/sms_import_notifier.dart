import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_wallet/data/services/sms_parser.dart';
import 'package:smart_wallet/ui/providers.dart';

class SmsImportNotifier extends StateNotifier<List<ParsedSmsTransaction>> {
  final Ref _ref;
  static const _channel = MethodChannel('com.example.smart_wallet/sms');

  SmsImportNotifier(this._ref) : super([]) {
    _init();
  }

  void _init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final map = Map<String, dynamic>.from(call.arguments);
        final sender = map['sender'] as String;
        final body = map['body'] as String;
        final dateMs = map['date'] as int;
        
        await handleIncomingSms(sender, body, dateMs);
      }
    });

    checkPendingImports();
  }

  Future<void> handleIncomingSms(String sender, String body, int dateMs) async {
    final enabled = await _ref.read(smsServiceProvider).isSmsImportEnabled();
    if (!enabled) return;

    final prefs = await SharedPreferences.getInstance();
    final excludedJson = prefs.getString('sms_import_excluded_senders');
    final excludedSenders = <String>[];
    if (excludedJson != null) {
      try {
        excludedSenders.addAll(List<String>.from(jsonDecode(excludedJson)));
      } catch (_) {}
    }

    final parsed = await _ref.read(smsServiceProvider).processIncomingSmsMessage(
      sender: sender,
      body: body,
      dateMs: dateMs,
      excludedSenders: excludedSenders,
    );

    if (parsed != null) {
      state = [...state, parsed];
    }
  }

  Future<void> checkPendingImports() async {
    final enabled = await _ref.read(smsServiceProvider).isSmsImportEnabled();
    if (!enabled) return;

    final prefs = await SharedPreferences.getInstance();
    final pendingJsonStr = prefs.getString('pending_sms_imports') ?? '[]';
    if (pendingJsonStr == '[]') return;

    final excludedJson = prefs.getString('sms_import_excluded_senders');
    final excludedSenders = <String>[];
    if (excludedJson != null) {
      try {
        excludedSenders.addAll(List<String>.from(jsonDecode(excludedJson)));
      } catch (_) {}
    }

    try {
      final list = jsonDecode(pendingJsonStr) as List;
      final parsedList = <ParsedSmsTransaction>[];

      for (final item in list) {
        final map = Map<String, dynamic>.from(item);
        final sender = map['sender'] as String;
        final body = map['body'] as String;
        final dateMs = map['date'] as int;

        final parsed = await _ref.read(smsServiceProvider).processIncomingSmsMessage(
          sender: sender,
          body: body,
          dateMs: dateMs,
          excludedSenders: excludedSenders,
        );

        if (parsed != null) {
          parsedList.add(parsed);
        }
      }

      await prefs.setString('pending_sms_imports', '[]');

      if (parsedList.isNotEmpty) {
        state = [...state, ...parsedList];
      }
    } catch (_) {}
  }

  void removeFirst() {
    if (state.isNotEmpty) {
      state = state.sublist(1);
    }
  }
}

final pendingSmsImportsProvider =
    StateNotifierProvider<SmsImportNotifier, List<ParsedSmsTransaction>>((ref) {
  return SmsImportNotifier(ref);
});
