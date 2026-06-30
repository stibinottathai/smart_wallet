import 'package:drift/drift.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/repositories/investment_repository.dart';
import '../services/database.dart';

class InvestmentRepositoryImpl implements InvestmentRepository {
  final AppDatabase _db;

  InvestmentRepositoryImpl(this._db);

  domain.Investment _mapToDomain(Investment row) {
    return domain.Investment(
      id: row.id,
      name: row.name,
      type: domain.InvestmentType.fromJson(row.type),
      investedAmount: row.investedAmount,
      currentValue: row.currentValue,
      units: row.units,
      purchaseDate: row.purchaseDate,
      lastValueUpdate: row.lastValueUpdate,
      platform: row.platform,
      accountId: row.accountId,
      color: row.color,
      isClosed: row.isClosed,
      note: row.note,
    );
  }

  InvestmentsCompanion _mapToCompanion(domain.Investment inv) {
    return InvestmentsCompanion(
      id: Value(inv.id),
      name: Value(inv.name),
      type: Value(inv.type.toJson()),
      investedAmount: Value(inv.investedAmount),
      currentValue: Value(inv.currentValue),
      units: Value(inv.units),
      purchaseDate: Value(inv.purchaseDate),
      lastValueUpdate: Value(inv.lastValueUpdate),
      platform: Value(inv.platform),
      accountId: Value(inv.accountId),
      color: Value(inv.color),
      isClosed: Value(inv.isClosed),
      note: Value(inv.note),
    );
  }

  @override
  Stream<List<domain.Investment>> watchAllInvestments() {
    final query = _db.select(_db.investments)
      ..orderBy([(t) => OrderingTerm(expression: t.purchaseDate, mode: OrderingMode.desc)]);
    return query.watch().map((list) => list.map(_mapToDomain).toList());
  }

  @override
  Future<List<domain.Investment>> getAllInvestments() async {
    final rows = await _db.select(_db.investments).get();
    return rows.map(_mapToDomain).toList();
  }

  @override
  Future<void> addInvestment(domain.Investment investment) async {
    await _db.into(_db.investments).insert(_mapToCompanion(investment));
  }

  @override
  Future<void> updateInvestment(domain.Investment investment) async {
    await _db.update(_db.investments).replace(_mapToCompanion(investment));
  }

  @override
  Future<void> deleteInvestment(String id) async {
    await (_db.delete(_db.investments)..where((t) => t.id.equals(id))).go();
  }
}
