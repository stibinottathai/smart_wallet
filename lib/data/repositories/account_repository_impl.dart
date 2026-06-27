import 'package:drift/drift.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/repositories/account_repository.dart';
import '../services/database.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AppDatabase _db;

  AccountRepositoryImpl(this._db);

  domain.Account _mapToDomain(Account row) {
    return domain.Account(
      id: row.id,
      name: row.name,
      type: domain.AccountType.fromJson(row.type),
      color: row.color,
      openingBalance: row.openingBalance,
      archived: row.archived,
      sortOrder: row.sortOrder,
    );
  }

  AccountsCompanion _mapToCompanion(domain.Account account) {
    return AccountsCompanion(
      id: Value(account.id),
      name: Value(account.name),
      type: Value(account.type.toJson()),
      color: Value(account.color),
      openingBalance: Value(account.openingBalance),
      archived: Value(account.archived),
      sortOrder: Value(account.sortOrder),
    );
  }

  @override
  Stream<List<domain.Account>> watchAllAccounts() {
    final query = _db.select(_db.accounts)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    return query.watch().map((list) => list.map(_mapToDomain).toList());
  }

  @override
  Future<List<domain.Account>> getAllAccounts() async {
    final query = _db.select(_db.accounts)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    final rows = await query.get();
    return rows.map(_mapToDomain).toList();
  }

  @override
  Future<void> addAccount(domain.Account account) async {
    await _db.into(_db.accounts).insert(_mapToCompanion(account));
  }

  @override
  Future<void> updateAccount(domain.Account account) async {
    await _db.update(_db.accounts).replace(_mapToCompanion(account));
  }

  @override
  Future<void> deleteAccount(String id) async {
    await (_db.delete(_db.accounts)..where((t) => t.id.equals(id))).go();
  }
}
