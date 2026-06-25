import 'package:drift/drift.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/repositories/savings_goal_repository.dart';
import '../services/database.dart';

class SavingsGoalRepositoryImpl implements SavingsGoalRepository {
  final AppDatabase _db;

  SavingsGoalRepositoryImpl(this._db);

  domain.SavingsGoal _mapGoalToDomain(SavingsGoal dbGoal) {
    return domain.SavingsGoal(
      id: dbGoal.id,
      name: dbGoal.name,
      targetAmount: dbGoal.targetAmount,
      currentAmount: dbGoal.currentAmount,
      targetDate: dbGoal.targetDate,
      color: dbGoal.color,
    );
  }

  SavingsGoalsCompanion _mapGoalToCompanion(domain.SavingsGoal goal) {
    return SavingsGoalsCompanion(
      id: Value(goal.id),
      name: Value(goal.name),
      targetAmount: Value(goal.targetAmount),
      currentAmount: Value(goal.currentAmount),
      targetDate: Value(goal.targetDate),
      color: Value(goal.color),
    );
  }

  @override
  Stream<List<domain.SavingsGoal>> watchAllGoals() {
    return _db.select(_db.savingsGoals).watch().map(
      (list) => list.map(_mapGoalToDomain).toList(),
    );
  }

  @override
  Future<List<domain.SavingsGoal>> getAllGoals() async {
    final rows = await _db.select(_db.savingsGoals).get();
    return rows.map(_mapGoalToDomain).toList();
  }

  @override
  Future<void> addGoal(domain.SavingsGoal goal) async {
    await _db.into(_db.savingsGoals).insert(_mapGoalToCompanion(goal));
  }

  @override
  Future<void> updateGoal(domain.SavingsGoal goal) async {
    await _db.update(_db.savingsGoals).replace(_mapGoalToCompanion(goal));
  }

  @override
  Future<void> deleteGoal(String id) async {
    await (_db.delete(_db.savingsGoals)..where((t) => t.id.equals(id))).go();
  }
}
