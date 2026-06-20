import 'package:drift/drift.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/repositories/bill_repository.dart';
import '../services/database.dart';

class BillRepositoryImpl implements BillRepository {
  final AppDatabase _db;

  BillRepositoryImpl(this._db);

  domain.Bill _mapBillToDomain(Bill dbBill) {
    return domain.Bill(
      id: dbBill.id,
      name: dbBill.name,
      amount: dbBill.amount,
      dueDate: dbBill.dueDate,
      isPaid: dbBill.isPaid,
      frequency: domain.BillFrequency.fromJson(dbBill.frequency),
      categoryId: dbBill.categoryId,
    );
  }

  BillsCompanion _mapBillToCompanion(domain.Bill bill) {
    return BillsCompanion(
      id: Value(bill.id),
      name: Value(bill.name),
      amount: Value(bill.amount),
      dueDate: Value(bill.dueDate),
      isPaid: Value(bill.isPaid),
      frequency: Value(bill.frequency.toJson()),
      categoryId: Value(bill.categoryId),
    );
  }

  @override
  Stream<List<domain.Bill>> watchAllBills() {
    return _db.select(_db.bills).watch().map(
      (list) => list.map(_mapBillToDomain).toList(),
    );
  }

  @override
  Future<void> addBill(domain.Bill bill) async {
    await _db.into(_db.bills).insert(_mapBillToCompanion(bill));
  }

  @override
  Future<void> updateBill(domain.Bill bill) async {
    await _db.update(_db.bills).replace(_mapBillToCompanion(bill));
  }

  @override
  Future<void> deleteBill(String id) async {
    await (_db.delete(_db.bills)..where((t) => t.id.equals(id))).go();
  }
}
