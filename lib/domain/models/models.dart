export 'ai_provider.dart';

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
  final bool rolloverEnabled;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
    this.budgetLimit,
    this.rolloverEnabled = false,
  });

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    bool? isDefault,
    double? budgetLimit,
    bool clearBudgetLimit = false,
    bool? rolloverEnabled,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      budgetLimit: clearBudgetLimit ? null : (budgetLimit ?? this.budgetLimit),
      rolloverEnabled: rolloverEnabled ?? this.rolloverEnabled,
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
  final String? accountId;
  final bool isSynced;
  final String? remoteId;

  const Income({
    required this.id,
    required this.amount,
    required this.source,
    required this.date,
    required this.isRecurring,
    required this.frequency,
    this.accountId,
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
    String? accountId,
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
      accountId: accountId ?? this.accountId,
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
  final String? accountId;
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
    this.accountId,
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
    String? accountId,
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
      accountId: accountId ?? this.accountId,
      isSynced: isSynced ?? this.isSynced,
      remoteId: remoteId ?? this.remoteId,
    );
  }
}

enum AccountType {
  cash,
  bank,
  card,
  upi,
  wallet,
  other;

  String toJson() => name;

  static AccountType fromJson(String value) {
    return AccountType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AccountType.other,
    );
  }

  String get displayName {
    switch (this) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.card:
        return 'Credit / Debit Card';
      case AccountType.upi:
        return 'UPI Wallet';
      case AccountType.wallet:
        return 'Wallet';
      case AccountType.other:
        return 'Other';
    }
  }
}

class Account {
  final String id;
  final String name;
  final AccountType type;
  final String color; // Hex string (e.g. '#2F6F5E')
  final double openingBalance;
  final bool archived;
  final int sortOrder;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    this.openingBalance = 0,
    this.archived = false,
    this.sortOrder = 0,
  });

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    String? color,
    double? openingBalance,
    bool? archived,
    int? sortOrder,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      openingBalance: openingBalance ?? this.openingBalance,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class Transfer {
  final String id;
  final String fromAccountId;
  final String toAccountId;
  final double amount;
  final DateTime date;
  final String? note;

  const Transfer({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.date,
    this.note,
  });

  Transfer copyWith({
    String? id,
    String? fromAccountId,
    String? toAccountId,
    double? amount,
    DateTime? date,
    String? note,
  }) {
    return Transfer(
      id: id ?? this.id,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
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

class HealthScoreFactor {
  final String key;
  final String label;
  final double score;
  final double weight;
  final String description;

  const HealthScoreFactor({
    required this.key,
    required this.label,
    required this.score,
    required this.weight,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'score': score,
    'weight': weight,
    'description': description,
  };

  factory HealthScoreFactor.fromJson(Map<String, dynamic> json) {
    return HealthScoreFactor(
      key: json['key'] as String,
      label: json['label'] as String,
      score: (json['score'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      description: json['description'] as String,
    );
  }

  HealthScoreFactor copyWith({double? score, double? weight, String? description}) {
    return HealthScoreFactor(
      key: key,
      label: label,
      score: score ?? this.score,
      weight: weight ?? this.weight,
      description: description ?? this.description,
    );
  }
}

class FinancialHealthScore {
  final double totalScore;
  final String label;
  final List<HealthScoreFactor> factors;
  final double? previousScore;
  final String? monthOverMonthExplanation;

  const FinancialHealthScore({
    required this.totalScore,
    required this.label,
    required this.factors,
    this.previousScore,
    this.monthOverMonthExplanation,
  });

  Map<String, dynamic> toJson() => {
    'totalScore': totalScore,
    'label': label,
    'factors': factors.map((f) => f.toJson()).toList(),
  };

  factory FinancialHealthScore.fromJson(Map<String, dynamic> json) {
    return FinancialHealthScore(
      totalScore: (json['totalScore'] as num).toDouble(),
      label: json['label'] as String,
      factors: (json['factors'] as List).map((f) => HealthScoreFactor.fromJson(f as Map<String, dynamic>)).toList(),
    );
  }

  static String ratingLabel(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Attention';
  }
}
