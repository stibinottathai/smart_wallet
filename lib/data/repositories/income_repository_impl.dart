import 'package:drift/drift.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/repositories/income_repository.dart';
import '../services/database.dart';

class IncomeRepositoryImpl implements IncomeRepository {
  final AppDatabase _db;

  IncomeRepositoryImpl(this._db);

  @override
  Future<List<domain.Income>> getIncomesBetween(DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.incomes)
      ..where((t) => t.date.isBetweenValues(start, end))).get();
    return rows.map(_mapToDomain).toList();
  }

  @override
  Future<List<domain.Income>> getAllIncomes() async {
    final rows = await _db.select(_db.incomes).get();
    return rows.map(_mapToDomain).toList();
  }

  domain.Income _mapToDomain(Income dbIncome) {
    return domain.Income(
      id: dbIncome.id,
      amount: dbIncome.amount,
      source: dbIncome.source,
      date: dbIncome.date,
      isRecurring: dbIncome.isRecurring,
      frequency: domain.IncomeFrequency.fromJson(dbIncome.frequency),
      accountId: dbIncome.accountId,
      originalCurrency: dbIncome.originalCurrency,
      originalAmount: dbIncome.originalAmount,
      isSynced: dbIncome.isSynced,
      remoteId: dbIncome.remoteId,
    );
  }

  IncomesCompanion _mapToCompanion(domain.Income income) {
    return IncomesCompanion(
      id: Value(income.id),
      amount: Value(income.amount),
      source: Value(income.source),
      date: Value(income.date),
      isRecurring: Value(income.isRecurring),
      frequency: Value(income.frequency.toJson()),
      accountId: Value(income.accountId),
      originalCurrency: Value(income.originalCurrency),
      originalAmount: Value(income.originalAmount),
      isSynced: Value(income.isSynced),
      remoteId: Value(income.remoteId),
    );
  }

  @override
  Stream<List<domain.Income>> watchAllIncomes() {
    return _db.select(_db.incomes).watch().map(
      (list) => list.map(_mapToDomain).toList(),
    );
  }

  @override
  Future<void> addIncome(domain.Income income) async {
    await _db.into(_db.incomes).insert(_mapToCompanion(income));
  }

  @override
  Future<void> updateIncome(domain.Income income) async {
    await _db.update(_db.incomes).replace(_mapToCompanion(income));
  }

  @override
  Future<void> deleteIncome(String id) async {
    await (_db.delete(_db.incomes)..where((t) => t.id.equals(id))).go();
  }
}
