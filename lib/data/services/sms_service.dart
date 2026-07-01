import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/repositories/income_repository.dart';
import 'sms_permission_service.dart';
import 'sms_parser.dart';
import 'duplicate_detector.dart';

class SmsService {
  final SmsPermissionService _permissionService;
  final ExpenseRepository _expenseRepository;
  final IncomeRepository _incomeRepository;
  final DuplicateDetector _duplicateDetector;
  final String _baseCurrency;

  static const _channel = MethodChannel('com.example.smart_wallet/sms');

  SmsService({
    required SmsPermissionService permissionService,
    required ExpenseRepository expenseRepository,
    required IncomeRepository incomeRepository,
    required DuplicateDetector duplicateDetector,
    required String baseCurrency,
  })  : _permissionService = permissionService,
        _expenseRepository = expenseRepository,
        _incomeRepository = incomeRepository,
        _duplicateDetector = duplicateDetector,
        _baseCurrency = baseCurrency;

  Future<bool> isSmsImportEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('sms_import_enabled') ?? false;
  }

  Future<void> setSmsImportEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_import_enabled', enabled);
  }

  Future<List<ParsedSmsTransaction>> scanInboxAndDetectTransactions({
    required int days,
    required List<String> excludedSenders,
  }) async {
    final hasPermission = await _permissionService.checkPermission();
    if (!hasPermission) {
      return [];
    }

    try {
      final List<dynamic>? rawSmsList =
          await _channel.invokeMethod('getSmsInbox', {'days': days});

      if (rawSmsList == null) return [];

      final existingExpenses = await _expenseRepository.getAllExpenses();
      final existingIncomes = await _incomeRepository.getAllIncomes();

      final parsedTransactions = <ParsedSmsTransaction>[];

      for (final rawSms in rawSmsList) {
        final map = Map<String, dynamic>.from(rawSms);
        final sender = map['sender'] as String;
        final body = map['body'] as String;
        final dateMs = map['date'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(dateMs);

        // Check if excluded sender
        if (excludedSenders.any((ex) => sender.toLowerCase().contains(ex.toLowerCase()))) {
          continue;
        }

        if (!GenericSmsParser.isTransactionSms(sender, body)) {
          continue;
        }

        final hash = GenericSmsParser.calculateHash('$sender|$body|$dateMs');
        final parsed = GenericSmsParser.parse(sender, body, date, _baseCurrency);

        final isDup = await _duplicateDetector.isDuplicateSms(
          hash: hash,
          referenceNumber: parsed.referenceNumber,
          amount: parsed.amount,
          date: date,
          sender: sender,
          existingExpenses: existingExpenses,
          existingIncomes: existingIncomes,
        );

        if (!isDup) {
          parsedTransactions.add(parsed);
        }
      }

      return parsedTransactions;
    } catch (e) {
      return [];
    }
  }

  Future<ParsedSmsTransaction?> processIncomingSmsMessage({
    required String sender,
    required String body,
    required int dateMs,
    required List<String> excludedSenders,
  }) async {
    // Check if excluded sender
    if (excludedSenders.any((ex) => sender.toLowerCase().contains(ex.toLowerCase()))) {
      return null;
    }

    if (!GenericSmsParser.isTransactionSms(sender, body)) {
      return null;
    }

    final date = DateTime.fromMillisecondsSinceEpoch(dateMs);
    final hash = GenericSmsParser.calculateHash('$sender|$body|$dateMs');

    final existingExpenses = await _expenseRepository.getAllExpenses();
    final existingIncomes = await _incomeRepository.getAllIncomes();

    final parsed = GenericSmsParser.parse(sender, body, date, _baseCurrency);

    final isDup = await _duplicateDetector.isDuplicateSms(
      hash: hash,
      referenceNumber: parsed.referenceNumber,
      amount: parsed.amount,
      date: date,
      sender: sender,
      existingExpenses: existingExpenses,
      existingIncomes: existingIncomes,
    );

    if (isDup) {
      return null;
    }

    return parsed;
  }
}
