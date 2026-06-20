import 'package:flutter_test/flutter_test.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/data/services/receipt_scan_service.dart';
import 'package:smart_wallet/data/services/insights_service.dart';

void main() {
  group('Smart Wallet Domain and Services Tests', () {
    test('IncomeFrequency serialization and deserialization', () {
      expect(domain.IncomeFrequency.fromJson('monthly'), domain.IncomeFrequency.monthly);
      expect(domain.IncomeFrequency.fromJson('weekly'), domain.IncomeFrequency.weekly);
      expect(domain.IncomeFrequency.fromJson('oneOff'), domain.IncomeFrequency.oneOff);
      expect(domain.IncomeFrequency.fromJson('invalid'), domain.IncomeFrequency.oneOff); // fallback
    });

    test('ExpenseSource serialization and deserialization', () {
      expect(domain.ExpenseSource.fromJson('manual'), domain.ExpenseSource.manual);
      expect(domain.ExpenseSource.fromJson('aiScan'), domain.ExpenseSource.aiScan);
      expect(domain.ExpenseSource.fromJson('invalid'), domain.ExpenseSource.manual); // fallback
    });

    test('Category fuzzy matching rules', () {
      final scanService = ReceiptScanService();
      
      final mockCategories = [
        const domain.Category(id: 'cat_uncategorized', name: 'Uncategorized', icon: 'help', color: '#999'),
        const domain.Category(id: 'cat_dining', name: 'Dining & Drinks', icon: 'rest', color: '#B56'),
        const domain.Category(id: 'cat_groceries', name: 'Groceries', icon: 'shop', color: '#A3A'),
        const domain.Category(id: 'cat_transport', name: 'Transport', icon: 'car', color: '#688'),
      ];

      // Exact matches and sub-strings
      expect(scanService.matchCategory('dining at restaurant', mockCategories), 'cat_dining');
      expect(scanService.matchCategory('groceries purchase', mockCategories), 'cat_groceries');
      expect(scanService.matchCategory('uber taxi ride', mockCategories), 'cat_transport');
      expect(scanService.matchCategory('unknown billing category', mockCategories), 'cat_uncategorized');
    });

    test('InsightsService askAssistant returns error on empty API key', () async {
      final service = InsightsService();
      final response = await service.askAssistant(
        expenses: [],
        incomes: [],
        categories: [],
        chatHistory: [],
        userQuery: 'How can I save money?',
        apiKey: '',
      );
      expect(response.contains('Error contacting financial assistant:'), isTrue);
    });
  });
}
