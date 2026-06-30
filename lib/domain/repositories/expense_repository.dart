import '../models/models.dart';

abstract class ExpenseRepository {
  Stream<List<Expense>> watchAllExpenses();
  Future<void> addExpense(Expense expense);
  Future<void> updateExpense(Expense expense);
  Future<void> deleteExpense(String id);
  Stream<List<Category>> watchAllCategories();
  Future<void> addCategory(Category category);
  Future<void> updateCategory(Category category);
  Future<void> deleteCategory(String id);
  Future<Category?> getCategoryById(String id);
  Future<List<Expense>> getAllExpenses();
  Future<List<Expense>> getExpensesBetween(DateTime start, DateTime end);
  Future<List<Category>> getAllCategories();
}
