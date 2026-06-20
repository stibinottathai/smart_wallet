import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get color => text()(); // Hex color string
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Incomes extends Table {
  TextColumn get id => text()();
  RealColumn get amount => real()();
  TextColumn get source => text()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get frequency => text()(); // Stored as Enum string (monthly, weekly, oneOff)
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()();
  RealColumn get amount => real()();
  TextColumn get categoryId => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get receiptImagePath => text().nullable()();
  TextColumn get source => text()(); // Stored as Enum string (manual, aiScan)
  RealColumn get aiConfidence => real().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SavingsGoals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real()();
  DateTimeColumn get targetDate => dateTime()();
  TextColumn get color => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Bills extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  DateTimeColumn get dueDate => dateTime()();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  TextColumn get frequency => text()();
  TextColumn get categoryId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Categories, Incomes, Expenses, SavingsGoals, Bills])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'smart_wallet'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(savingsGoals);
          await m.createTable(bills);
        }
      },
      beforeOpen: (details) async {
        if (details.wasCreated) {
          // Seed default categories
          final defaultCategories = [
            const CategoriesCompanion(
              id: Value('cat_uncategorized'),
              name: Value('Uncategorized'),
              icon: Value('help_outline'),
              color: Value('#9E9E9E'), // neutral grey
              isDefault: Value(true),
            ),
            const CategoriesCompanion(
              id: Value('cat_dining'),
              name: Value('Dining & Drinks'),
              icon: Value('restaurant'),
              color: Value('#B5634A'), // terracotta
              isDefault: Value(true),
            ),
            const CategoriesCompanion(
              id: Value('cat_groceries'),
              name: Value('Groceries'),
              icon: Value('shopping_basket'),
              color: Value('#A3A89E'), // muted grey-green
              isDefault: Value(true),
            ),
            const CategoriesCompanion(
              id: Value('cat_transport'),
              name: Value('Transport'),
              icon: Value('directions_car'),
              color: Value('#688F80'), // lighter pine
              isDefault: Value(true),
            ),
            const CategoriesCompanion(
              id: Value('cat_housing'),
              name: Value('Housing & Rent'),
              icon: Value('home'),
              color: Value('#4F5B56'), // dark slate
              isDefault: Value(true),
            ),
            const CategoriesCompanion(
              id: Value('cat_entertainment'),
              name: Value('Entertainment'),
              icon: Value('movie'),
              color: Value('#D39B82'), // light warm orange
              isDefault: Value(true),
            ),
            const CategoriesCompanion(
              id: Value('cat_utilities'),
              name: Value('Utilities'),
              icon: Value('power'),
              color: Value('#617C8F'), // steel blue
              isDefault: Value(true),
            ),
            const CategoriesCompanion(
              id: Value('cat_income'),
              name: Value('Income & Salary'),
              icon: Value('attach_money'),
              color: Value('#2F6F5E'), // deep pine green
              isDefault: Value(true),
            ),
          ];
          for (final cat in defaultCategories) {
            await into(categories).insert(cat);
          }
        }
      },
    );
  }
}
