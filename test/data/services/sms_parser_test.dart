import 'package:flutter_test/flutter_test.dart';
import 'package:smart_wallet/data/services/sms_parser.dart';
import 'package:smart_wallet/data/services/merchant_normalizer.dart';
import 'package:smart_wallet/data/services/category_predictor.dart';
import 'package:smart_wallet/data/services/duplicate_detector.dart';
import 'package:smart_wallet/domain/repositories/sms_import_repository.dart';
import 'package:smart_wallet/domain/models/models.dart';

class MockSmsImportRepository implements SmsImportRepository {
  final Set<String> processedHashes = {};
  final Set<String> processedRefNumbers = {};

  @override
  Future<bool> isHashProcessed(String hash) async => processedHashes.contains(hash);

  @override
  Future<bool> isReferenceNumberProcessed(String referenceNumber) async =>
      processedRefNumbers.contains(referenceNumber);

  @override
  Future<void> markAsProcessed({
    required String hash,
    required String sender,
    required DateTime date,
    String? referenceNumber,
    double? amount,
  }) async {
    processedHashes.add(hash);
    if (referenceNumber != null) {
      processedRefNumbers.add(referenceNumber);
    }
  }
}

void main() {
  group('SmsParser & GenericSmsParser', () {
    test('detects transaction SMS and ignores promotional/OTPs', () {
      expect(
        GenericSmsParser.isTransactionSms('AD-HDFCBK', 'Rs.450 spent on HDFC Card at Amazon'),
        isTrue,
      );
      expect(
        GenericSmsParser.isTransactionSms('AD-HDFCBK', 'Salary Rs.45000 credited to account'),
        isTrue,
      );
      expect(
        GenericSmsParser.isTransactionSms('AD-KOTAK', 'Your OTP for transaction is 123456. Do not share.'),
        isFalse,
      );
      expect(
        GenericSmsParser.isTransactionSms('AD-SBIINB', 'Get 50% discount on credit card apply now.'),
        isFalse,
      );
    });

    test('parses spent/debit transaction details correctly', () {
      final date = DateTime(2026, 7, 1, 12, 0);
      final parsed = GenericSmsParser.parse('AD-HDFCBK', 'Rs.450 spent on HDFC Card at Amazon', date, 'INR');

      expect(parsed.amount, equals(450.0));
      expect(parsed.currency, equals('INR'));
      expect(parsed.type, equals(SmsTransactionType.debit));
      expect(parsed.merchant, equals('Amazon'));
      expect(parsed.bankName, equals('HDFC'));
      expect(parsed.paymentMethod, equals('Card'));
    });

    test('parses credit/salary transaction details correctly', () {
      final date = DateTime(2026, 7, 1, 12, 0);
      final parsed = GenericSmsParser.parse('AD-SBIINB', 'Salary Rs.45000 credited to account Ref:TXN987654', date, 'INR');

      expect(parsed.amount, equals(45000.0));
      expect(parsed.type, equals(SmsTransactionType.credit));
      expect(parsed.merchant, equals('Salary'));
      expect(parsed.bankName, equals('SBI'));
      expect(parsed.referenceNumber, equals('TXN987654'));
    });

    test('extracts UPI transactions correctly', () {
      final date = DateTime(2026, 7, 1, 12, 0);
      final parsed = GenericSmsParser.parse('AD-ICICIB', 'UPI Payment of Rs.120 to Swiggy, UPI Ref:12345678, user@okhdfcbank', date, 'INR');

      expect(parsed.amount, equals(120.0));
      expect(parsed.paymentMethod, equals('UPI'));
      expect(parsed.upiId, equals('user@okhdfcbank'));
      expect(parsed.referenceNumber, equals('12345678'));
    });
  });

  group('MerchantNormalizer', () {
    test('normalizes raw merchant names', () {
      expect(MerchantNormalizer.normalize('AMAZON PAY INDIA PRIVATE LIMITED'), equals('Amazon'));
      expect(MerchantNormalizer.normalize('SWIGGY LIMITED'), equals('Swiggy'));
      expect(MerchantNormalizer.normalize('UBER INDIA SYSTEMS'), equals('Uber'));
      expect(MerchantNormalizer.normalize('ZOMATO ONLINE SERVICES'), equals('Zomato'));
      expect(MerchantNormalizer.normalize('PHONEPE PVT LTD'), equals('PhonePe'));
      expect(MerchantNormalizer.normalize('GOOGLE PAY'), equals('Google Pay'));
    });
  });

  group('CategoryPredictor', () {
    final categories = [
      const Category(id: 'cat_dining', name: 'Dining & Drinks', icon: 'restaurant', color: '#1'),
      const Category(id: 'cat_transport', name: 'Transport', icon: 'directions_car', color: '#2'),
      const Category(id: 'cat_income', name: 'Income & Salary', icon: 'attach_money', color: '#3'),
      const Category(id: 'cat_uncategorized', name: 'Uncategorized', icon: 'help_outline', color: '#4'),
    ];

    test('predicts correct categories', () {
      expect(CategoryPredictor.predict('Swiggy', categories, true), equals('cat_dining'));
      expect(CategoryPredictor.predict('Uber', categories, true), equals('cat_transport'));
      expect(CategoryPredictor.predict('Salary', categories, false), equals('cat_income'));
      expect(CategoryPredictor.predict('Unknown Merchant', categories, true), equals('cat_uncategorized'));
    });
  });

  group('DuplicateDetector', () {
    late MockSmsImportRepository mockRepo;
    late DuplicateDetector detector;

    setUp(() {
      mockRepo = MockSmsImportRepository();
      detector = DuplicateDetector(mockRepo);
    });

    test('flags duplicates based on hash and reference number', () async {
      final date = DateTime(2026, 7, 1);
      final hash = 'unique_hash_123';
      
      // Initially, not duplicate
      final isDup1 = await detector.isDuplicateSms(
        hash: hash,
        referenceNumber: 'REF111',
        amount: 100.0,
        date: date,
        sender: 'HDFC',
        existingExpenses: [],
        existingIncomes: [],
      );
      expect(isDup1, isFalse);

      // Mark as processed
      await mockRepo.markAsProcessed(hash: hash, sender: 'HDFC', date: date, referenceNumber: 'REF111');

      // Now, should flag duplicate by hash
      final isDup2 = await detector.isDuplicateSms(
        hash: hash,
        referenceNumber: 'REF222',
        amount: 100.0,
        date: date,
        sender: 'HDFC',
        existingExpenses: [],
        existingIncomes: [],
      );
      expect(isDup2, isTrue);

      // Should also flag duplicate by reference number even with different hash
      final isDup3 = await detector.isDuplicateSms(
        hash: 'different_hash',
        referenceNumber: 'REF111',
        amount: 100.0,
        date: date,
        sender: 'HDFC',
        existingExpenses: [],
        existingIncomes: [],
      );
      expect(isDup3, isTrue);
    });
  });
}
