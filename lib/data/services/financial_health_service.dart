import 'dart:math';
import 'package:intl/intl.dart';
import '../../domain/models/models.dart' as domain;

class FinancialHealthService {
  final String currencySymbol;

  const FinancialHealthService({this.currencySymbol = '₹'});

  domain.FinancialHealthScore compute({
    required List<domain.Income> incomes,
    required List<domain.Expense> expenses,
    required List<domain.Category> categories,
    required List<domain.SavingsGoal> goals,
    required List<domain.Bill> bills,
    required double netBalance,
    domain.FinancialHealthScore? previousSnapshot,
  }) {
    final now = DateTime.now();
    final currentMonthExpenses = expenses.where((e) =>
      e.date.month == now.month && e.date.year == now.year).toList();
    final currentMonthIncomes = incomes.where((i) =>
      i.date.month == now.month && i.date.year == now.year).toList();

    final totalIncome = currentMonthIncomes.fold(0.0, (s, i) => s + i.amount);
    final totalExpense = currentMonthExpenses.fold(0.0, (s, e) => s + e.amount);

    final factors = <domain.HealthScoreFactor>[];
    double totalWeight = 0.0;

    // 1. Savings Rate (30%)
    if (totalIncome > 0) {
      final savingsRate = (totalIncome - totalExpense) / totalIncome;
      final score = (savingsRate / 0.30).clamp(0.0, 1.0) * 100;
      final desc = score >= 100
          ? "You're saving well above the 30% benchmark"
          : "Your savings rate is ${_pct(savingsRate)}";
      factors.add(domain.HealthScoreFactor(
        key: 'savings_rate', label: 'Savings Rate',
        score: score, weight: 0.30, description: desc,
      ));
      totalWeight += 0.30;
    }

    // 2. Budget Adherence (20%)
    final cappedCategories = categories
        .where((c) => c.budgetLimit != null && c.budgetLimit! > 0 && c.id != 'cat_income')
        .toList();
    if (cappedCategories.isNotEmpty) {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final elapsedFraction = now.day / daysInMonth;
      double sumScore = 0;
      int onTrack = 0;
      for (final cat in cappedCategories) {
        final spent = currentMonthExpenses
            .where((e) => e.categoryId == cat.id)
            .fold(0.0, (s, e) => s + e.amount);
        if (spent == 0) {
          sumScore += 100;
          onTrack++;
        } else {
          final pace = (spent / cat.budgetLimit!) / elapsedFraction;
          final catScore = (100 - (pace - 1) * 100).clamp(0.0, 100.0);
          if (catScore >= 80) onTrack++;
          sumScore += catScore;
        }
      }
      final score = sumScore / cappedCategories.length;
      factors.add(domain.HealthScoreFactor(
        key: 'budget_adherence', label: 'Budget Adherence',
        score: score, weight: 0.20,
        description: 'Staying within budget for $onTrack of ${cappedCategories.length} categories',
      ));
      totalWeight += 0.20;
    }

    // 3. Bill/EMI Burden (20%)
    if (totalIncome > 0) {
      double monthlyBillTotal = 0;
      for (final bill in bills.where((b) => !b.isPaid)) {
        switch (bill.frequency) {
          case domain.BillFrequency.monthly: monthlyBillTotal += bill.amount;
          case domain.BillFrequency.weekly: monthlyBillTotal += bill.amount * 4.33;
          case domain.BillFrequency.yearly: monthlyBillTotal += bill.amount / 12;
          case domain.BillFrequency.daily: monthlyBillTotal += bill.amount * 30;
          case domain.BillFrequency.oneOff:
        }
      }
      final emiRatio = monthlyBillTotal / totalIncome;
      final score = (100 - (emiRatio / 0.40) * 100).clamp(0.0, 100.0);
      final fmt = NumberFormat('#,##0');
      factors.add(domain.HealthScoreFactor(
        key: 'bill_burden', label: 'Bill Burden',
        score: score, weight: 0.20,
        description: 'Recurring bills are $currencySymbol${fmt.format(monthlyBillTotal.round())} of your $currencySymbol${fmt.format(totalIncome.round())} income',
      ));
      totalWeight += 0.20;
    }

    // 4. Emergency Fund Coverage (15%)
    {
      final monthlyTotals = <int, double>{};
      final threeMonthsAgo = DateTime(now.year, now.month - 2, 1);
      for (final exp in expenses) {
        if (exp.date.isBefore(threeMonthsAgo) || exp.date.isAfter(now)) continue;
        final key = exp.date.year * 12 + exp.date.month;
        monthlyTotals[key] = (monthlyTotals[key] ?? 0) + exp.amount;
      }
      if (monthlyTotals.isNotEmpty) {
        final avgMonthly = monthlyTotals.values.fold(0.0, (s, v) => s + v) / monthlyTotals.length;
        final monthsCovered = avgMonthly > 0 ? netBalance / avgMonthly : 6;
        final score = (monthsCovered / 6).clamp(0.0, 1.0) * 100;
        factors.add(domain.HealthScoreFactor(
          key: 'emergency_fund', label: 'Emergency Fund',
          score: score, weight: 0.15,
          description: 'You have ${monthsCovered.toStringAsFixed(1)} months of expenses covered',
        ));
        totalWeight += 0.15;
      }
    }

    // 5. Goal Progress (10%)
    if (goals.isNotEmpty) {
      double sumScore = 0;
      int onTrack = 0;
      for (final goal in goals) {
        if (goal.targetAmount <= 0) continue;
        final actualProgress = (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
        final remaining = goal.targetDate.difference(DateTime.now()).inDays;
        if (remaining <= 0 && actualProgress < 1.0) {
          sumScore += actualProgress * 50;
        } else if (remaining <= 30) {
          sumScore += actualProgress * 100;
        } else {
          sumScore += actualProgress * 100;
        }
        if (actualProgress >= 1.0 || (remaining > 0 && actualProgress >= 0.5)) onTrack++;
      }
      final score = sumScore / goals.length;
      factors.add(domain.HealthScoreFactor(
        key: 'goal_progress', label: 'Goal Progress',
        score: score, weight: 0.10,
        description: onTrack == goals.length
            ? 'On track with all ${goals.length} goals'
            : 'On track with $onTrack of ${goals.length} goals',
      ));
      totalWeight += 0.10;
    }

    // 6. Spending Consistency (5%)
    {
      final today = DateTime(now.year, now.month, now.day);
      final weeklyTotals = <double>[];
      for (int w = 7; w >= 0; w--) {
        final weekStart = today.subtract(Duration(days: (w + 1) * 7));
        final weekEnd = today.subtract(Duration(days: w * 7));
        double total = 0;
        for (final exp in expenses) {
          if (!exp.date.isBefore(weekStart) && exp.date.isBefore(weekEnd)) {
            total += exp.amount;
          }
        }
        weeklyTotals.add(total);
      }
      final mean = weeklyTotals.fold(0.0, (s, v) => s + v) / weeklyTotals.length;
      double score;
      if (mean == 0) {
        score = 100;
      } else {
        final variance = weeklyTotals.fold(0.0, (s, v) => s + (v - mean) * (v - mean)) / weeklyTotals.length;
        final cv = sqrt(variance) / mean;
        score = (100 - cv * 100).clamp(0.0, 100.0);
      }
      factors.add(domain.HealthScoreFactor(
        key: 'spending_consistency', label: 'Spending Consistency',
        score: score, weight: 0.05,
        description: score >= 80
            ? 'Your weekly spending is very consistent'
            : 'Your spending varies week-to-week',
      ));
      totalWeight += 0.05;
    }

    // Redistribute weights for excluded factors
    final adjustedWeight = totalWeight > 0 ? 1.0 / totalWeight : 1.0;
    final adjustedFactors = factors.map((f) => f.copyWith(weight: f.weight * adjustedWeight)).toList();

    // Final score
    final totalScore = adjustedFactors.fold(0.0, (s, f) => s + f.score * f.weight);

    // Month-over-month explanation
    String? explanation;
    if (previousSnapshot != null && previousSnapshot.factors.isNotEmpty) {
      final delta = totalScore - previousSnapshot.totalScore;
      if (delta.abs() >= 5) {
        // Find the factor with the largest weighted delta
        var biggestDelta = 0.0;
        String biggestLabel = '';
        String deltaDir = delta > 0 ? 'increased' : 'decreased';
        for (final current in adjustedFactors) {
          final prev = previousSnapshot.factors.where((f) => f.key == current.key).firstOrNull;
          if (prev != null) {
            final weightedDelta = (current.score - prev.score) * current.weight;
            if (weightedDelta.abs() > biggestDelta.abs()) {
              biggestDelta = weightedDelta;
              biggestLabel = _driverLabel(current.key, delta > 0);
            }
          }
        }
        if (biggestLabel.isNotEmpty) {
          explanation = 'Your score moved from ${previousSnapshot.totalScore.toStringAsFixed(0)} to ${totalScore.toStringAsFixed(0)}, mainly due to $biggestLabel ($deltaDir by ${biggestDelta.abs().toStringAsFixed(1)} points).';
        }
      }
    }

    return domain.FinancialHealthScore(
      totalScore: totalScore,
      label: domain.FinancialHealthScore.ratingLabel(totalScore),
      factors: adjustedFactors,
      previousScore: previousSnapshot?.totalScore,
      monthOverMonthExplanation: explanation,
    );
  }

  String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';

  String _driverLabel(String key, bool isImprovement) {
    switch (key) {
      case 'savings_rate': return isImprovement ? 'a higher savings rate' : 'a lower savings rate';
      case 'budget_adherence': return isImprovement ? 'better budget adherence' : 'worse budget adherence';
      case 'bill_burden': return isImprovement ? 'lower bill burden' : 'higher bill burden';
      case 'emergency_fund': return isImprovement ? 'better emergency fund coverage' : 'worse emergency fund coverage';
      case 'goal_progress': return isImprovement ? 'better goal progress' : 'worse goal progress';
      case 'spending_consistency': return isImprovement ? 'more consistent spending' : 'less consistent spending';
      default: return 'changes in ${key.replaceAll('_', ' ')}';
    }
  }
}
