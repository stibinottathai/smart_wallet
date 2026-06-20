import '../models/models.dart';

abstract class IncomeRepository {
  Stream<List<Income>> watchAllIncomes();
  Future<void> addIncome(Income income);
  Future<void> updateIncome(Income income);
  Future<void> deleteIncome(String id);
  Future<List<Income>> getIncomesBetween(DateTime start, DateTime end);
}
