import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get color => text()(); // Hex color string
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  RealColumn get budgetLimit => real().nullable()();
  // Envelope budgeting: when true, unspent budget carries into the next month.
  BoolColumn get rolloverEnabled => boolean().withDefault(const Constant(false))();

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
  TextColumn get accountId => text().nullable()(); // Wallet/account the income was paid into
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
  TextColumn get accountId => text().nullable()(); // Wallet/account the expense was paid from
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A money source — Cash, a bank account, a credit card, a UPI wallet, etc.
/// Each expense/income is attributed to one account so balances can be tracked
/// per source, and money can be moved between them via [Transfers].
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // AccountType enum string (cash, bank, card, upi, wallet, other)
  TextColumn get color => text()(); // Hex color string
  RealColumn get openingBalance => real().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A movement of money from one account to another. Transfers don't change
/// net worth — they only shift balance between accounts — so they're kept
/// separate from incomes and expenses.
class Transfers extends Table {
  TextColumn get id => text()();
  TextColumn get fromAccountId => text()();
  TextColumn get toAccountId => text()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A template that auto-creates an expense or income on a schedule (rent,
/// salary, subscriptions…). On each app launch the app posts any occurrences
/// that have come due and advances [nextDueDate].
class RecurringRules extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // 'expense' | 'income'
  TextColumn get title => text()(); // label, e.g. "Rent", "Netflix"
  RealColumn get amount => real()();
  TextColumn get categoryId => text().nullable()(); // expenses
  TextColumn get source => text().nullable()(); // incomes
  TextColumn get accountId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get frequency => text()(); // daily | weekly | monthly | yearly
  IntColumn get intervalCount => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextDueDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get lastPostedDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

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

class ProactiveInsights extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get triggerType => text()();
  TextColumn get category => text().nullable()();
  TextColumn get message => text()();
  TextColumn get tone => text()(); // 'positive' | 'neutral' | 'caution'
  TextColumn get suggestedAction => text().nullable()();
  TextColumn get actionLabel => text().nullable()();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class HealthScores extends Table {
  TextColumn get id => text()();
  TextColumn get month => text()(); // "YYYY-MM"
  RealColumn get score => real()();
  TextColumn get breakdownJson => text()(); // JSON string of all factor data
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Default accounts seeded on first install and back-filled during the v7
/// migration. The 'acc_cash' account is the fallback every legacy transaction
/// is attributed to, so it must always exist.
const List<AccountsCompanion> _defaultAccounts = [
  AccountsCompanion(
    id: Value('acc_cash'),
    name: Value('Cash'),
    type: Value('cash'),
    color: Value('#4F5B56'),
    sortOrder: Value(0),
  ),
  AccountsCompanion(
    id: Value('acc_bank'),
    name: Value('Bank Account'),
    type: Value('bank'),
    color: Value('#2F6F5E'),
    sortOrder: Value(1),
  ),
  AccountsCompanion(
    id: Value('acc_card'),
    name: Value('Credit Card'),
    type: Value('card'),
    color: Value('#B5634A'),
    sortOrder: Value(2),
  ),
  AccountsCompanion(
    id: Value('acc_upi'),
    name: Value('UPI Wallet'),
    type: Value('upi'),
    color: Value('#617C8F'),
    sortOrder: Value(3),
  ),
];

@DriftDatabase(tables: [Categories, Incomes, Expenses, SavingsGoals, Bills, ProactiveInsights, HealthScores, Accounts, Transfers, RecurringRules])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'smart_wallet'));

  @override
  int get schemaVersion => 9;

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
        if (from < 3) {
          // Check if column already exists (handles partial migrations)
          final cols = await customSelect(
            "PRAGMA table_info('categories')",
          ).get();
          final hasColumn = cols.any((row) => row.read<String>('name') == 'budget_limit');
          if (!hasColumn) {
            await m.addColumn(categories, categories.budgetLimit);
          }
        }
        if (from < 4) {
          await m.createTable(proactiveInsights);
        }
        if (from < 5) {
          await m.createTable(healthScores);
        }
        if (from < 6) {
          final newCats = [
            const CategoriesCompanion(
              id: Value('cat_healthcare'),
              name: Value('Healthcare & Hospital'),
              icon: Value('local_hospital'),
              color: Value('#5D9B9B'),
              isDefault: Value(true),
            ),
            const CategoriesCompanion(
              id: Value('cat_loans'),
              name: Value('Loans & Debts'),
              icon: Value('account_balance'),
              color: Value('#A47449'),
              isDefault: Value(true),
            ),
          ];
          for (final cat in newCats) {
            await into(categories).insert(cat, mode: InsertMode.insertOrIgnore);
          }
        }
        if (from < 7) {
          // Multi-account support: create the accounts + transfers tables,
          // seed the default accounts, attach an accountId to each transaction
          // and back-fill every existing transaction onto the Cash account.
          await m.createTable(accounts);
          await m.createTable(transfers);
          for (final acc in _defaultAccounts) {
            await into(accounts).insert(acc, mode: InsertMode.insertOrIgnore);
          }
          await m.addColumn(expenses, expenses.accountId);
          await m.addColumn(incomes, incomes.accountId);
          await customStatement(
            "UPDATE expenses SET account_id = 'acc_cash' WHERE account_id IS NULL",
          );
          await customStatement(
            "UPDATE incomes SET account_id = 'acc_cash' WHERE account_id IS NULL",
          );
        }
        if (from < 8) {
          // Envelope budgeting: per-category rollover flag.
          final cols = await customSelect("PRAGMA table_info('categories')").get();
          final hasColumn = cols.any((row) => row.read<String>('name') == 'rollover_enabled');
          if (!hasColumn) {
            await m.addColumn(categories, categories.rolloverEnabled);
          }
        }
        if (from < 9) {
          // Recurring transactions: rule templates auto-posted on a schedule.
          await m.createTable(recurringRules);
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
            const CategoriesCompanion(
              id: Value('cat_healthcare'),
              name: Value('Healthcare & Hospital'),
              icon: Value('local_hospital'),
              color: Value('#5D9B9B'),
              isDefault: Value(true),
            ),
            const CategoriesCompanion(
              id: Value('cat_loans'),
              name: Value('Loans & Debts'),
              icon: Value('account_balance'),
              color: Value('#A47449'),
              isDefault: Value(true),
            ),
          ];
          for (final cat in defaultCategories) {
            await into(categories).insert(cat);
          }
          // Seed default accounts on a fresh install.
          for (final acc in _defaultAccounts) {
            await into(accounts).insert(acc);
          }
        }
      },
    );
  }
}
