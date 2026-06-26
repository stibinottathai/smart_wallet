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

    test('InsightsService askAssistant throws on empty API key', () async {
      final service = InsightsService();
      expect(
        () => service.askAssistant(
          expenses: [],
          incomes: [],
          categories: [],
          chatHistory: [],
          userQuery: 'How can I save money?',
          apiKey: '',
          aiModel: 'test',
          aiProvider: domain.AiProvider.openRouter,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('BillFrequency serialization and deserialization', () {
      expect(domain.BillFrequency.fromJson('weekly'), domain.BillFrequency.weekly);
      expect(domain.BillFrequency.fromJson('monthly'), domain.BillFrequency.monthly);
      expect(domain.BillFrequency.fromJson('yearly'), domain.BillFrequency.yearly);
      expect(domain.BillFrequency.fromJson('oneOff'), domain.BillFrequency.oneOff);
      expect(domain.BillFrequency.fromJson('invalid'), domain.BillFrequency.oneOff); // fallback
      expect(domain.BillFrequency.weekly.toJson(), 'weekly');
    });

    test('BillFrequency displayNames', () {
      expect(domain.BillFrequency.weekly.displayName, 'Weekly');
      expect(domain.BillFrequency.monthly.displayName, 'Monthly');
      expect(domain.BillFrequency.yearly.displayName, 'Yearly');
      expect(domain.BillFrequency.oneOff.displayName, 'One-off');
    });

    test('SavingsGoal copyWith', () {
      final now = DateTime.now();
      final goal = domain.SavingsGoal(
        id: 'goal_1',
        name: 'New Car',
        targetAmount: 5000,
        currentAmount: 1000,
        targetDate: now,
        color: '#FF0000',
      );
      final updated = goal.copyWith(currentAmount: 1500);
      expect(updated.currentAmount, 1500);
      expect(updated.name, 'New Car');
    });

    test('Bill copyWith', () {
      final now = DateTime.now();
      final bill = domain.Bill(
        id: 'bill_1',
        name: 'Netflix',
        amount: 15,
        dueDate: now,
        isPaid: false,
        frequency: domain.BillFrequency.monthly,
      );
      final updated = bill.copyWith(isPaid: true);
      expect(updated.isPaid, true);
      expect(updated.name, 'Netflix');
    });
  });
}
