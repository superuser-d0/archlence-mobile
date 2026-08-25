/// One savings goal, drawn the same way wherever it appears.
///
/// Shared between the Assets tab and the savings tool: two copies would drift,
/// and the desktop has already paid for that once — its goal dictionary was
/// built in two places, and a field added to one and not the other made goal
/// cards lose their colour after an operation.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../money/financial_decimal.dart';
import '../services/savings_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/money_format.dart';
import 'surfaces.dart';

class SavingsGoalCard extends StatelessWidget {
  const SavingsGoalCard({
    required this.goal,
    required this.onMoveMoney,
    super.key,
  });

  final SavingsGoal goal;

  /// Opens the deposit/withdraw sheet.
  ///
  /// Required and non-null: both hosts offer it, and an optional callback
  /// would leave a branch nothing reaches — room for the button to become
  /// live-and-inert without any test able to notice.
  final VoidCallback onMoveMoney;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // The service already guarantees a positive target, so this divides
    // safely; the clamp is for a goal deliberately overfunded past it.
    final ratio = (goal.currentAmount / goal.targetAmount).toDouble().clamp(
      0.0,
      1.0,
    );
    final tone = goal.isCompleted
        ? ObsidianPalette.tertiary
        : ObsidianPalette.primary;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined, size: 20, color: tone),
              const SizedBox(width: Spacing.stackSm),
              Expanded(
                child: Text(
                  // A name that will not decrypt says so rather than being
                  // replaced with something that reads like a real goal.
                  goal.goalName ?? 'Unreadable goal',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleLarge?.copyWith(
                    fontStyle: goal.goalName == null ? FontStyle.italic : null,
                    color: goal.goalName == null ? ObsidianPalette.error : null,
                  ),
                ),
              ),
              Text(
                formatPercent(
                  percentage(
                    (goal.currentAmount / goal.targetAmount).toDecimal(
                          scaleOnInfinitePrecision: 20,
                        ) *
                        Decimal.fromInt(100),
                  ),
                ),
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.stackMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: ObsidianPalette.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(tone),
            ),
          ),
          const SizedBox(height: Spacing.stackMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Amount(
                  label: 'Saved',
                  value: formatLira(goal.currentAmount),
                ),
              ),
              Expanded(
                child: Amount(
                  label: 'Target',
                  value: formatLira(goal.targetAmount),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.stackMd),
          GradientButton(
            label: goal.isCompleted ? 'Take back' : 'Save',
            onPressed: onMoveMoney,
          ),
        ],
      ),
    );
  }
}

class Amount extends StatelessWidget {
  const Amount({
    required this.label,
    required this.value,
    this.alignEnd = false,
    super.key,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelMedium?.copyWith(
            letterSpacing: 0,
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
