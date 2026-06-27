import 'package:drift/drift.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/repositories/expense_repository.dart';
import '../services/database.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final AppDatabase _db;

  ExpenseRepositoryImpl(this._db);

  @override
  Future<List<domain.Expense>> getExpensesBetween(DateTime start, DateTime end) async {
    final rows = await (_db.select(_db.expenses)
      ..where((t) => t.date.isBetweenValues(start, end))).get();
    return rows.map(_mapExpenseToDomain).toList();
  }

  @override
  Future<List<domain.Expense>> getAllExpenses() async {
    final rows = await _db.select(_db.expenses).get();
    return rows.map(_mapExpenseToDomain).toList();
  }

  @override
  Future<List<domain.Category>> getAllCategories() async {
    final rows = await _db.select(_db.categories).get();
    return rows.map(_mapCategoryToDomain).toList();
  }

  domain.Expense _mapExpenseToDomain(Expense dbExpense) {
    return domain.Expense(
      id: dbExpense.id,
      amount: dbExpense.amount,
      categoryId: dbExpense.categoryId,
      date: dbExpense.date,
      note: dbExpense.note,
      receiptImagePath: dbExpense.receiptImagePath,
      source: domain.ExpenseSource.fromJson(dbExpense.source),
      aiConfidence: dbExpense.aiConfidence,
      accountId: dbExpense.accountId,
      isSynced: dbExpense.isSynced,
      remoteId: dbExpense.remoteId,
    );
  }

  ExpensesCompanion _mapExpenseToCompanion(domain.Expense expense) {
    return ExpensesCompanion(
      id: Value(expense.id),
      amount: Value(expense.amount),
      categoryId: Value(expense.categoryId),
      date: Value(expense.date),
      note: Value(expense.note),
      receiptImagePath: Value(expense.receiptImagePath),
      source: Value(expense.source.toJson()),
      aiConfidence: Value(expense.aiConfidence),
      accountId: Value(expense.accountId),
      isSynced: Value(expense.isSynced),
      remoteId: Value(expense.remoteId),
    );
  }

  domain.Category _mapCategoryToDomain(Category dbCategory) {
    return domain.Category(
      id: dbCategory.id,
      name: dbCategory.name,
      icon: dbCategory.icon,
      color: dbCategory.color,
      isDefault: dbCategory.isDefault,
      budgetLimit: dbCategory.budgetLimit,
      rolloverEnabled: dbCategory.rolloverEnabled,
    );
  }

  CategoriesCompanion _mapCategoryToCompanion(domain.Category category) {
    return CategoriesCompanion(
      id: Value(category.id),
      name: Value(category.name),
      icon: Value(category.icon),
      color: Value(category.color),
      isDefault: Value(category.isDefault),
      budgetLimit: Value(category.budgetLimit),
      rolloverEnabled: Value(category.rolloverEnabled),
    );
  }

  @override
  Stream<List<domain.Expense>> watchAllExpenses() {
    return _db.select(_db.expenses).watch().map(
      (list) => list.map(_mapExpenseToDomain).toList(),
    );
  }

  @override
  Future<void> addExpense(domain.Expense expense) async {
    await _db.into(_db.expenses).insert(_mapExpenseToCompanion(expense));
  }

  @override
  Future<void> updateExpense(domain.Expense expense) async {
    await _db.update(_db.expenses).replace(_mapExpenseToCompanion(expense));
  }

  @override
  Future<void> deleteExpense(String id) async {
    await (_db.delete(_db.expenses)..where((t) => t.id.equals(id))).go();
  }

  @override
  Stream<List<domain.Category>> watchAllCategories() {
    return _db.select(_db.categories).watch().map(
      (list) => list.map(_mapCategoryToDomain).toList(),
    );
  }

  @override
  Future<void> addCategory(domain.Category category) async {
    await _db.into(_db.categories).insert(_mapCategoryToCompanion(category));
  }

  @override
  Future<void> updateCategory(domain.Category category) async {
    await _db.update(_db.categories).replace(_mapCategoryToCompanion(category));
  }

  @override
  Future<domain.Category?> getCategoryById(String id) async {
    final query = _db.select(_db.categories)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _mapCategoryToDomain(row);
  }
}
