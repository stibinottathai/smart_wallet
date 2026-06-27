import 'package:drift/drift.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/repositories/debt_repository.dart';
import '../services/database.dart';

class DebtRepositoryImpl implements DebtRepository {
  final AppDatabase _db;

  DebtRepositoryImpl(this._db);

  domain.Debt _mapToDomain(Debt row) {
    return domain.Debt(
      id: row.id,
      name: row.name,
      type: domain.DebtType.fromJson(row.type),
      counterparty: row.counterparty,
      principalAmount: row.principalAmount,
      paidAmount: row.paidAmount,
      interestRate: row.interestRate,
      emiAmount: row.emiAmount,
      startDate: row.startDate,
      dueDate: row.dueDate,
      color: row.color,
      isClosed: row.isClosed,
      note: row.note,
    );
  }

  DebtsCompanion _mapToCompanion(domain.Debt debt) {
    return DebtsCompanion(
      id: Value(debt.id),
      name: Value(debt.name),
      type: Value(debt.type.toJson()),
      counterparty: Value(debt.counterparty),
      principalAmount: Value(debt.principalAmount),
      paidAmount: Value(debt.paidAmount),
      interestRate: Value(debt.interestRate),
      emiAmount: Value(debt.emiAmount),
      startDate: Value(debt.startDate),
      dueDate: Value(debt.dueDate),
      color: Value(debt.color),
      isClosed: Value(debt.isClosed),
      note: Value(debt.note),
    );
  }

  @override
  Stream<List<domain.Debt>> watchAllDebts() {
    final query = _db.select(_db.debts)
      ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]);
    return query.watch().map((list) => list.map(_mapToDomain).toList());
  }

  @override
  Future<List<domain.Debt>> getAllDebts() async {
    final rows = await _db.select(_db.debts).get();
    return rows.map(_mapToDomain).toList();
  }

  @override
  Future<void> addDebt(domain.Debt debt) async {
    await _db.into(_db.debts).insert(_mapToCompanion(debt));
  }

  @override
  Future<void> updateDebt(domain.Debt debt) async {
    await _db.update(_db.debts).replace(_mapToCompanion(debt));
  }

  @override
  Future<void> deleteDebt(String id) async {
    await (_db.delete(_db.debts)..where((t) => t.id.equals(id))).go();
  }
}
