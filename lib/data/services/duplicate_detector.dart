import '../../domain/models/models.dart';
import '../../domain/repositories/sms_import_repository.dart';

class DuplicateDetector {
  final SmsImportRepository _smsImportRepository;

  DuplicateDetector(this._smsImportRepository);

  Future<bool> isDuplicateSms({
    required String hash,
    required String? referenceNumber,
    required double amount,
    required DateTime date,
    required String sender,
    required List<Expense> existingExpenses,
    required List<Income> existingIncomes,
  }) async {
    // 1. Check if the SMS hash has already been imported
    final isHashProcessed = await _smsImportRepository.isHashProcessed(hash);
    if (isHashProcessed) return true;

    // 2. Check if the reference number has already been imported
    if (referenceNumber != null && referenceNumber.isNotEmpty) {
      final isRefProcessed = await _smsImportRepository.isReferenceNumberProcessed(referenceNumber);
      if (isRefProcessed) return true;
    }

    // 3. Compare with existing expenses in database
    for (final expense in existingExpenses) {
      if ((expense.amount - amount).abs() < 0.01) {
        final timeDiff = expense.date.difference(date).inHours.abs();
        if (timeDiff <= 24) {
          // If reference number matches notes
          if (referenceNumber != null &&
              referenceNumber.isNotEmpty &&
              expense.note != null &&
              expense.note!.contains(referenceNumber)) {
            return true;
          }
          // If notes mention sender
          if (expense.note != null &&
              expense.note!.toLowerCase().contains(sender.toLowerCase())) {
            return true;
          }
        }
      }
    }

    // 4. Compare with existing incomes in database
    for (final income in existingIncomes) {
      if ((income.amount - amount).abs() < 0.01) {
        final timeDiff = income.date.difference(date).inHours.abs();
        if (timeDiff <= 24) {
          if (referenceNumber != null &&
              referenceNumber.isNotEmpty &&
              income.source.toLowerCase().contains(referenceNumber.toLowerCase())) {
            return true;
          }
          if (income.source.toLowerCase().contains(sender.toLowerCase())) {
            return true;
          }
        }
      }
    }

    return false;
  }
}
