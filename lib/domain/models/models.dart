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
  final String? originalCurrency;
  final double? originalAmount;
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
    this.originalCurrency,
    this.originalAmount,
    this.isSynced = false,
    this.remoteId,
  });

  /// True when this entry was recorded in a currency other than the base.
  bool get isForeign => originalCurrency != null && originalAmount != null;

  Income copyWith({
    String? id,
    double? amount,
    String? source,
    DateTime? date,
    bool? isRecurring,
    IncomeFrequency? frequency,
    String? accountId,
    String? originalCurrency,
    double? originalAmount,
    bool clearOriginalCurrency = false,
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
      originalCurrency: clearOriginalCurrency ? null : (originalCurrency ?? this.originalCurrency),
      originalAmount: clearOriginalCurrency ? null : (originalAmount ?? this.originalAmount),
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
  final String? originalCurrency;
  final double? originalAmount;
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
    this.originalCurrency,
    this.originalAmount,
    this.isSynced = false,
    this.remoteId,
  });

  /// True when this entry was recorded in a currency other than the base.
  bool get isForeign => originalCurrency != null && originalAmount != null;

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
    String? originalCurrency,
    double? originalAmount,
    bool clearOriginalCurrency = false,
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
      originalCurrency: clearOriginalCurrency ? null : (originalCurrency ?? this.originalCurrency),
      originalAmount: clearOriginalCurrency ? null : (originalAmount ?? this.originalAmount),
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
  final bool isDefault;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    this.openingBalance = 0,
    this.archived = false,
    this.sortOrder = 0,
    this.isDefault = false,
  });

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    String? color,
    double? openingBalance,
    bool? archived,
    int? sortOrder,
    bool? isDefault,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      openingBalance: openingBalance ?? this.openingBalance,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

enum DebtType {
  borrowed, // you owe someone (loan, EMI)
  lent; // someone owes you

  String toJson() => name;

  static DebtType fromJson(String value) {
    return DebtType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DebtType.borrowed,
    );
  }

  String get displayName => this == DebtType.borrowed ? 'I owe' : 'Owed to me';
}

/// Money borrowed or lent. [paidAmount] tracks repayment progress toward
/// [principalAmount], mirroring how [SavingsGoal] tracks saved-vs-target.
class Debt {
  final String id;
  final String name;
  final DebtType type;
  final String? counterparty;
  final double principalAmount;
  final double paidAmount;
  final double? interestRate;
  final double? emiAmount;
  final DateTime startDate;
  final DateTime? dueDate;
  final String color;
  final bool isClosed;
  final String? note;

  const Debt({
    required this.id,
    required this.name,
    required this.type,
    this.counterparty,
    required this.principalAmount,
    this.paidAmount = 0,
    this.interestRate,
    this.emiAmount,
    required this.startDate,
    this.dueDate,
    required this.color,
    this.isClosed = false,
    this.note,
  });

  /// Outstanding amount still owed / to be collected (never negative).
  double get remaining {
    final r = principalAmount - paidAmount;
    return r < 0 ? 0 : r;
  }

  /// Repayment progress 0..1.
  double get progress =>
      principalAmount > 0 ? (paidAmount / principalAmount).clamp(0.0, 1.0) : 0.0;

  bool get isSettled => isClosed || paidAmount >= principalAmount;

  Debt copyWith({
    String? id,
    String? name,
    DebtType? type,
    String? counterparty,
    bool clearCounterparty = false,
    double? principalAmount,
    double? paidAmount,
    double? interestRate,
    bool clearInterestRate = false,
    double? emiAmount,
    bool clearEmiAmount = false,
    DateTime? startDate,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? color,
    bool? isClosed,
    String? note,
    bool clearNote = false,
  }) {
    return Debt(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      counterparty: clearCounterparty ? null : (counterparty ?? this.counterparty),
      principalAmount: principalAmount ?? this.principalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      interestRate: clearInterestRate ? null : (interestRate ?? this.interestRate),
      emiAmount: clearEmiAmount ? null : (emiAmount ?? this.emiAmount),
      startDate: startDate ?? this.startDate,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      color: color ?? this.color,
      isClosed: isClosed ?? this.isClosed,
      note: clearNote ? null : (note ?? this.note),
    );
  }
}

enum RecurringType {
  expense,
  income;

  String toJson() => name;

  static RecurringType fromJson(String value) {
    return RecurringType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RecurringType.expense,
    );
  }
}

enum RecurrenceFrequency {
  daily,
  weekly,
  monthly,
  yearly;

  String toJson() => name;

  static RecurrenceFrequency fromJson(String value) {
    return RecurrenceFrequency.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RecurrenceFrequency.monthly,
    );
  }

  String get displayName {
    switch (this) {
      case RecurrenceFrequency.daily:
        return 'Daily';
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
      case RecurrenceFrequency.yearly:
        return 'Yearly';
    }
  }

  /// Short adverb used in summaries, e.g. "Repeats monthly".
  String get adverb => displayName.toLowerCase();
}

/// A template that auto-creates an [Expense] or [Income] on a schedule.
class RecurringRule {
  final String id;
  final RecurringType type;
  final String title;
  final double amount;
  final String? categoryId; // expenses
  final String? source; // incomes
  final String? accountId;
  final String? note;
  final RecurrenceFrequency frequency;
  final int intervalCount;
  final DateTime nextDueDate;
  final DateTime? endDate;
  final DateTime? lastPostedDate;
  final bool isActive;

  const RecurringRule({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    this.categoryId,
    this.source,
    this.accountId,
    this.note,
    required this.frequency,
    this.intervalCount = 1,
    required this.nextDueDate,
    this.endDate,
    this.lastPostedDate,
    this.isActive = true,
  });

  RecurringRule copyWith({
    String? id,
    RecurringType? type,
    String? title,
    double? amount,
    String? categoryId,
    String? source,
    String? accountId,
    String? note,
    RecurrenceFrequency? frequency,
    int? intervalCount,
    DateTime? nextDueDate,
    DateTime? endDate,
    DateTime? lastPostedDate,
    bool? isActive,
  }) {
    return RecurringRule(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      source: source ?? this.source,
      accountId: accountId ?? this.accountId,
      note: note ?? this.note,
      frequency: frequency ?? this.frequency,
      intervalCount: intervalCount ?? this.intervalCount,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      endDate: endDate ?? this.endDate,
      lastPostedDate: lastPostedDate ?? this.lastPostedDate,
      isActive: isActive ?? this.isActive,
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
