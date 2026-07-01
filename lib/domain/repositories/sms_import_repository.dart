abstract class SmsImportRepository {
  Future<bool> isHashProcessed(String hash);
  Future<bool> isReferenceNumberProcessed(String referenceNumber);
  Future<void> markAsProcessed({
    required String hash,
    required String sender,
    required DateTime date,
    String? referenceNumber,
    double? amount,
  });
}
