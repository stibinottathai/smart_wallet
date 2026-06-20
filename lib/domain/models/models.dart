enum IncomeFrequency {
  monthly,
  weekly,
  oneOff;

  String toJson() => name;

  static IncomeFrequency fromJson(String value) {
    return IncomeFrequency.values.firstWhere(
      (e) => e.name == value,
      orElse: () => IncomeFrequency.oneOff,
    );
  }

  String get displayName {
    switch (this) {
      case IncomeFrequency.monthly:
        return 'Monthly';
      case IncomeFrequency.weekly:
        return 'Weekly';
      case IncomeFrequency.oneOff:
        return 'One-off';
    }
  }
}

enum ExpenseSource {
  manual,
  aiScan;

  String toJson() => name;

  static ExpenseSource fromJson(String value) {
    return ExpenseSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ExpenseSource.manual,
    );
  }
}

class Category {
  final String id;
  final String name;
  final String icon; // Icon name / identifier (e.g. 'food', 'transport')
  final String color; // Hex string (e.g. '#2F6F5E')
  final bool isDefault;
  final double? budgetLimit;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
    this.budgetLimit,
  });

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    bool? isDefault,
    double? budgetLimit,
    bool clearBudgetLimit = false,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      budgetLimit: clearBudgetLimit ? null : (budgetLimit ?? this.budgetLimit),
    );
  }
}

class Income {
  final String id;
  final double amount;
  final String source;
  final DateTime date;
  final bool isRecurring;
  final IncomeFrequency frequency;
  final bool isSynced;
  final String? remoteId;

  const Income({
    required this.id,
    required this.amount,
    required this.source,
    required this.date,
    required this.isRecurring,
    required this.frequency,
    this.isSynced = false,
    this.remoteId,
  });

  Income copyWith({
    String? id,
    double? amount,
    String? source,
    DateTime? date,
    bool? isRecurring,
    IncomeFrequency? frequency,
    bool? isSynced,
    String? remoteId,
  }) {
    return Income(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      source: source ?? this.source,
      date: date ?? this.date,
      isRecurring: isRecurring ?? this.isRecurring,
      frequency: frequency ?? this.frequency,
      isSynced: isSynced ?? this.isSynced,
      remoteId: remoteId ?? this.remoteId,
    );
  }
}

class Expense {
  final String id;
  final double amount;
  final String categoryId;
  final DateTime date;
  final String? note;
  final String? receiptImagePath;
  final ExpenseSource source;
  final double? aiConfidence;
  final bool isSynced;
  final String? remoteId;

  const Expense({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.note,
    this.receiptImagePath,
    this.source = ExpenseSource.manual,
    this.aiConfidence,
    this.isSynced = false,
    this.remoteId,
  });

  Expense copyWith({
    String? id,
    double? amount,
    String? categoryId,
    DateTime? date,
    String? note,
    String? receiptImagePath,
    ExpenseSource? source,
    double? aiConfidence,
    bool? isSynced,
    String? remoteId,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      note: note ?? this.note,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      source: source ?? this.source,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      isSynced: isSynced ?? this.isSynced,
      remoteId: remoteId ?? this.remoteId,
    );
  }
}

enum BillFrequency {
  daily,
  weekly,
  monthly,
  yearly,
  oneOff;

  String toJson() => name;

  static BillFrequency fromJson(String value) {
    return BillFrequency.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BillFrequency.oneOff,
    );
  }

  String get displayName {
    switch (this) {
      case BillFrequency.daily:
        return 'Daily';
      case BillFrequency.weekly:
        return 'Weekly';
      case BillFrequency.monthly:
        return 'Monthly';
      case BillFrequency.yearly:
        return 'Yearly';
      case BillFrequency.oneOff:
        return 'One-off';
    }
  }
}

class SavingsGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final String color;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.color,
  });

  SavingsGoal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? color,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      color: color ?? this.color,
    );
  }
}

class Bill {
  final String id;
  final String name;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final BillFrequency frequency;
  final String? categoryId;

  const Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.isPaid,
    required this.frequency,
    this.categoryId,
  });

  Bill copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? dueDate,
    bool? isPaid,
    BillFrequency? frequency,
    String? categoryId,
  }) {
    return Bill(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      frequency: frequency ?? this.frequency,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}

