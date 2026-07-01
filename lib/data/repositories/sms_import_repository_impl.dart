import 'package:drift/drift.dart';
import '../../domain/repositories/sms_import_repository.dart';
import '../services/database.dart';

class SmsImportRepositoryImpl implements SmsImportRepository {
  final AppDatabase _db;

  SmsImportRepositoryImpl(this._db);

  @override
  Future<bool> isHashProcessed(String hash) async {
    final query = _db.select(_db.importedSms)..where((t) => t.hash.equals(hash));
    final row = await query.getSingleOrNull();
    return row != null;
  }

  @override
  Future<bool> isReferenceNumberProcessed(String referenceNumber) async {
    final query = _db.select(_db.importedSms)
      ..where((t) => t.referenceNumber.equals(referenceNumber));
    final row = await query.getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> markAsProcessed({
    required String hash,
    required String sender,
    required DateTime date,
    String? referenceNumber,
    double? amount,
  }) async {
    await _db.into(_db.importedSms).insert(
      ImportedSmsCompanion(
        hash: Value(hash),
        sender: Value(sender),
        date: Value(date),
        referenceNumber: Value(referenceNumber),
        amount: Value(amount),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }
}
