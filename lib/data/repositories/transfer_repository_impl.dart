import 'package:drift/drift.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/repositories/transfer_repository.dart';
import '../services/database.dart';

class TransferRepositoryImpl implements TransferRepository {
  final AppDatabase _db;

  TransferRepositoryImpl(this._db);

  domain.Transfer _mapToDomain(Transfer row) {
    return domain.Transfer(
      id: row.id,
      fromAccountId: row.fromAccountId,
      toAccountId: row.toAccountId,
      amount: row.amount,
      date: row.date,
      note: row.note,
    );
  }

  TransfersCompanion _mapToCompanion(domain.Transfer transfer) {
    return TransfersCompanion(
      id: Value(transfer.id),
      fromAccountId: Value(transfer.fromAccountId),
      toAccountId: Value(transfer.toAccountId),
      amount: Value(transfer.amount),
      date: Value(transfer.date),
      note: Value(transfer.note),
    );
  }

  @override
  Stream<List<domain.Transfer>> watchAllTransfers() {
    return _db.select(_db.transfers).watch().map(
          (list) => list.map(_mapToDomain).toList(),
        );
  }

  @override
  Future<List<domain.Transfer>> getAllTransfers() async {
    final rows = await _db.select(_db.transfers).get();
    return rows.map(_mapToDomain).toList();
  }

  @override
  Future<void> addTransfer(domain.Transfer transfer) async {
    await _db.into(_db.transfers).insert(_mapToCompanion(transfer));
  }

  @override
  Future<void> updateTransfer(domain.Transfer transfer) async {
    await _db.update(_db.transfers).replace(_mapToCompanion(transfer));
  }

  @override
  Future<void> deleteTransfer(String id) async {
    await (_db.delete(_db.transfers)..where((t) => t.id.equals(id))).go();
  }
}
