import '../models/models.dart';

abstract class SavingsGoalRepository {
  Stream<List<SavingsGoal>> watchAllGoals();
  Future<void> addGoal(SavingsGoal goal);
  Future<void> updateGoal(SavingsGoal goal);
  Future<void> deleteGoal(String id);
}
