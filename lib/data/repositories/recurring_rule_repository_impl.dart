import 'package:drift/drift.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/repositories/recurring_rule_repository.dart';
import '../services/database.dart';

class RecurringRuleRepositoryImpl implements RecurringRuleRepository {
  final AppDatabase _db;

  RecurringRuleRepositoryImpl(this._db);

  domain.RecurringRule _mapToDomain(RecurringRule row) {
    return domain.RecurringRule(
      id: row.id,
      type: domain.RecurringType.fromJson(row.type),
      title: row.title,
      amount: row.amount,
      categoryId: row.categoryId,
      source: row.source,
      accountId: row.accountId,
      note: row.note,
      frequency: domain.RecurrenceFrequency.fromJson(row.frequency),
      intervalCount: row.intervalCount,
      nextDueDate: row.nextDueDate,
      endDate: row.endDate,
      lastPostedDate: row.lastPostedDate,
      isActive: row.isActive,
    );
  }

  RecurringRulesCompanion _mapToCompanion(domain.RecurringRule rule) {
    return RecurringRulesCompanion(
      id: Value(rule.id),
      type: Value(rule.type.toJson()),
      title: Value(rule.title),
      amount: Value(rule.amount),
      categoryId: Value(rule.categoryId),
      source: Value(rule.source),
      accountId: Value(rule.accountId),
      note: Value(rule.note),
      frequency: Value(rule.frequency.toJson()),
      intervalCount: Value(rule.intervalCount),
      nextDueDate: Value(rule.nextDueDate),
      endDate: Value(rule.endDate),
      lastPostedDate: Value(rule.lastPostedDate),
      isActive: Value(rule.isActive),
    );
  }

  @override
  Stream<List<domain.RecurringRule>> watchAllRules() {
    final query = _db.select(_db.recurringRules)
      ..orderBy([(t) => OrderingTerm(expression: t.nextDueDate)]);
    return query.watch().map((list) => list.map(_mapToDomain).toList());
  }

  @override
  Future<List<domain.RecurringRule>> getAllRules() async {
    final rows = await _db.select(_db.recurringRules).get();
    return rows.map(_mapToDomain).toList();
  }

  @override
  Future<void> addRule(domain.RecurringRule rule) async {
    await _db.into(_db.recurringRules).insert(_mapToCompanion(rule));
  }

  @override
  Future<void> updateRule(domain.RecurringRule rule) async {
    await _db.update(_db.recurringRules).replace(_mapToCompanion(rule));
  }

  @override
  Future<void> deleteRule(String id) async {
    await (_db.delete(_db.recurringRules)..where((t) => t.id.equals(id))).go();
  }
}
