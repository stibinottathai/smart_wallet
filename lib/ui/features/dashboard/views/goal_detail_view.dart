import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;
import 'package:smart_wallet/ui/core/theme.dart';
import 'package:smart_wallet/ui/core/dialogs.dart';
import 'package:smart_wallet/ui/core/currency_utils.dart';
import 'package:smart_wallet/ui/providers.dart';
import 'goal_form_dialog.dart';

/// Read-only detail screen for a savings goal. Tapping a goal tile opens this;
/// Edit opens the [GoalFormDialog], Delete removes the goal after confirmation.
class GoalDetailView extends ConsumerWidget {
  final domain.SavingsGoal initialGoal;

  const GoalDetailView({super.key, required this.initialGoal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-read from the provider so edits reflect here; if the goal was deleted
    // (here or from the edit form) close this screen automatically.
    final goals = ref.watch(allSavingsGoalsProvider).value;
    final goal = goals == null
        ? initialGoal
        : goals.cast<domain.SavingsGoal?>().firstWhere(
              (g) => g?.id == initialGoal.id,
              orElse: () => null,
            );
    if (goal == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.shrink(),
      );
    }

    final symbol = currencySymbol(ref.watch(currencyCodeProvider));
    final color = Color(int.parse(goal.color.replaceAll('#', '0xFF')));
    final percent = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final remaining = goal.targetAmount - goal.currentAmount;

    void onEdit() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => GoalFormDialog(initialGoal: goal),
      );
    }

    Future<void> onDelete() async {
      final confirmed = await showDeleteConfirmationDialog(
        context: context,
        itemType: 'savings goal',
      );
      if (!confirmed) return;
      await ref.read(savingsGoalRepositoryProvider).deleteGoal(goal.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Savings goal deleted.')),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Goal Details',
          style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.secondary),
            onPressed: onDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card with progress.
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.track_changes_rounded, color: color, size: 32),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    goal.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$symbol${goal.currentAmount.toStringAsFixed(0)} of $symbol${goal.targetAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 6,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(percent * 100).toStringAsFixed(0)}% saved',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.savings_rounded,
                    label: 'Saved so far',
                    value: '$symbol${goal.currentAmount.toStringAsFixed(2)}',
                  ),
                  _divider(),
                  _DetailRow(
                    icon: Icons.flag_rounded,
                    label: 'Target',
                    value: '$symbol${goal.targetAmount.toStringAsFixed(2)}',
                  ),
                  _divider(),
                  _DetailRow(
                    icon: Icons.trending_up_rounded,
                    label: 'Remaining',
                    value: '$symbol${(remaining < 0 ? 0 : remaining).toStringAsFixed(2)}',
                    valueColor: remaining <= 0 ? AppColors.primary : null,
                  ),
                  _divider(),
                  _DetailRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Target date',
                    value: DateFormat('EEE, MMM d, yyyy').format(goal.targetDate),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete Goal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5));
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
