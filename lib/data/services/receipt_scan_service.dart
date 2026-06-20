import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path/path.dart' as p;
import '../../domain/models/models.dart' as domain;

class ReceiptScanResult {
  final String merchant;
  final double total;
  final String currency;
  final DateTime date;
  final String categoryGuess;
  final List<String> lineItems;

  ReceiptScanResult({
    required this.merchant,
    required this.total,
    required this.currency,
    required this.date,
    required this.categoryGuess,
    required this.lineItems,
  });

  factory ReceiptScanResult.fromJson(Map<String, dynamic> json) {
    double parseTotal(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    DateTime parseDate(dynamic val) {
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ReceiptScanResult(
      merchant: json['merchant'] ?? '',
      total: parseTotal(json['total']),
      currency: json['currency'] ?? 'USD',
      date: parseDate(json['date']),
      categoryGuess: json['category_guess'] ?? '',
      lineItems: List<String>.from(json['line_items'] ?? []),
    );
  }
}

class ReceiptScanService {
  Future<ReceiptScanResult?> scanReceipt({
    required String imagePath,
    required String apiKey,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      final extension = p.extension(imagePath).toLowerCase();
      final mimeType = (extension == '.png') ? 'image/png' : 'image/jpeg';

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      );

      final prompt = 'Analyze this receipt image and extract structured transaction details. '
          'Provide the output in JSON format matching this schema exactly:\n'
          '{\n'
          '  "merchant": "string (name of the store/merchant)",\n'
          '  "total": "number (the final total paid amount, numeric e.g. 24.50)",\n'
          '  "currency": "string (3 letter currency code e.g. USD, EUR, etc.)",\n'
          '  "date": "string (ISO-8601 date YYYY-MM-DD)",\n'
          '  "category_guess": "string (your best guess of the expense category, e.g. Dining, Groceries, transport, housing, utilities, entertainment)",\n'
          '  "line_items": [\n'
          '    "string (item name and price/quantity)"\n'
          '  ]\n'
          '}';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, bytes),
        ])
      ];

      final response = await model.generateContent(content);
      final responseText = response.text;
      if (responseText == null) {
        return null;
      }

      final Map<String, dynamic> decoded = jsonDecode(responseText);
      return ReceiptScanResult.fromJson(decoded);
    } catch (e) {
      // Return null on failure instead of throwing so form fallback can be pre-filled as empty.
      return null;
    }
  }

  String matchCategory(String categoryGuess, List<domain.Category> categories) {
    final guess = categoryGuess.toLowerCase();

    // Semantic maps for common financial concepts
    if (guess.contains('food') ||
        guess.contains('restaurant') ||
        guess.contains('dining') ||
        guess.contains('drink') ||
        guess.contains('cafe') ||
        guess.contains('coffee') ||
        guess.contains('bar') ||
        guess.contains('eat') ||
        guess.contains('bistro')) {
      final match = categories.firstWhere((c) => c.id == 'cat_dining', orElse: () => categories.first);
      return match.id;
    }

    if (guess.contains('grocery') ||
        guess.contains('groceries') ||
        guess.contains('supermarket') ||
        guess.contains('market') ||
        guess.contains('mart') ||
        guess.contains('walmart') ||
        guess.contains('costco')) {
      final match = categories.firstWhere((c) => c.id == 'cat_groceries', orElse: () => categories.first);
      return match.id;
    }

    if (guess.contains('transport') ||
        guess.contains('car') ||
        guess.contains('travel') ||
        guess.contains('gas') ||
        guess.contains('fuel') ||
        guess.contains('taxi') ||
        guess.contains('uber') ||
        guess.contains('bus') ||
        guess.contains('metro') ||
        guess.contains('train') ||
        guess.contains('flight') ||
        guess.contains('airline')) {
      final match = categories.firstWhere((c) => c.id == 'cat_transport', orElse: () => categories.first);
      return match.id;
    }

    if (guess.contains('rent') ||
        guess.contains('housing') ||
        guess.contains('home') ||
        guess.contains('house') ||
        guess.contains('apartment') ||
        guess.contains('stay') ||
        guess.contains('hotel') ||
        guess.contains('airbnb')) {
      final match = categories.firstWhere((c) => c.id == 'cat_housing', orElse: () => categories.first);
      return match.id;
    }

    if (guess.contains('utility') ||
        guess.contains('electricity') ||
        guess.contains('water') ||
        guess.contains('internet') ||
        guess.contains('wifi') ||
        guess.contains('bill') ||
        guess.contains('phone') ||
        guess.contains('mobile') ||
        guess.contains('power')) {
      final match = categories.firstWhere((c) => c.id == 'cat_utilities', orElse: () => categories.first);
      return match.id;
    }

    if (guess.contains('movie') ||
        guess.contains('show') ||
        guess.contains('entertainment') ||
        guess.contains('fun') ||
        guess.contains('game') ||
        guess.contains('play') ||
        guess.contains('music') ||
        guess.contains('concert') ||
        guess.contains('ticket') ||
        guess.contains('netflix') ||
        guess.contains('spotify') ||
        guess.contains('hobby')) {
      final match = categories.firstWhere((c) => c.id == 'cat_entertainment', orElse: () => categories.first);
      return match.id;
    }

    // Exact / substring fallback match
    for (final category in categories) {
      final name = category.name.toLowerCase();
      if (guess.contains(name) || name.contains(guess)) {
        return category.id;
      }
    }

    // Fall back to Uncategorized
    final uncategorized = categories.firstWhere(
      (c) => c.id == 'cat_uncategorized',
      orElse: () => categories.first,
    );
    return uncategorized.id;
  }
}
