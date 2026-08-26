/// The monthly budget: what was planned, what is reserved, and what is left.
///
/// Read-only for now. `BudgetService.savePlanItem` is ready and has no form
/// to call it from — see the roadmap's note that no screen writes yet.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../services/budget_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/async_data.dart';
import '../ui/month_names.dart';
import '../ui/money_format.dart';
import '../widgets/savings_goal_card.dart';
import '../widgets/summary_row.dart';
import '../widgets/surfaces.dart';
import 'budget_line_sheet.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

/// The month's totals and the categories underneath them, read together.
class _BudgetData {
  const _BudgetData({
    required this.budget,
    required this.progress,
    required this.reserved,
  });

  final MonthlyBudget budget;
  final List<CategoryBudgetProgress> progress;
  final List<ReservedRecurringItem> reserved;
}

class _BudgetScreenState extends State<BudgetScreen> {
  late int _month = DateTime.now().month;
  late final int _year = DateTime.now().year;
  Future<_BudgetData>? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<_BudgetData> _load() async {
    final budget = ServicesScope.of(context).budget;
    return _BudgetData(
      budget: await budget.calculateMonthlyBudget(_month, _year),
      progress: await budget.getCategoryBudgetProgress(_month, _year),
      reserved: await budget.getReservedRecurringItems(_month, _year),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.budgetTitle),
        actions: [
          IconButton(
            onPressed: () async {
              final saved = await showBudgetLineSheet(
                context,
                month: _month,
                year: _year,
              );
              if (saved ?? false) _reload();
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          key: const PageStorageKey('budget'),
          padding: const EdgeInsets.fromLTRB(
            Spacing.containerMargin,
            Spacing.stackMd,
            Spacing.containerMargin,
            Spacing.stackLg,
          ),
          children: [
            // Only the months the planner can act on: a plan for a month that
            // has gone is not something the user can change.
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: plannerMonthRange(DateTime.now()).length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final month = plannerMonthRange(DateTime.now())[index];
                  return _MonthChip(
                    month: month,
                    selected: month == _month,
                    onTap: () {
                      setState(() {
                        _month = month;
                        _data = _load();
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: Spacing.stackLg),
            AsyncData<_BudgetData>(
              future: _data!,
              placeholderHeight: 320,
              builder: (context, data) => _BudgetBody(data: data),
            ),
            const SizedBox(height: Spacing.sectionGap),
            Text(context.l10n.budgetCategories, style: text.titleLarge),
            const SizedBox(height: Spacing.stackMd),
            AsyncData<_BudgetData>(
              future: _data!,
              placeholderHeight: 120,
              builder: (context, data) => _Categories(data.progress),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetBody extends StatelessWidget {
  const _BudgetBody({required this.data});

  final _BudgetData data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final budget = data.budget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryRow(
          stats: [
            SummaryStat(
              label: l10n.budgetPlannedIncome,
              value: formatLira(budget.plannedIncome),
              tone: SummaryTone.positive,
            ),
            SummaryStat(
              label: l10n.budgetPlannedExpense,
              value: formatLira(budget.plannedExpense),
              tone: SummaryTone.negative,
            ),
            SummaryStat(
              label: l10n.budgetReserved,
              value: formatLira(budget.reservedRecurring),
            ),
          ],
        ),
        const SizedBox(height: Spacing.stackMd),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                l10n.budgetLeftToSpend,
                style: text.bodySmall?.copyWith(
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatLira(budget.remainingBudget),
                  maxLines: 1,
                  style: text.headlineLarge?.copyWith(
                    // Negative is the case worth seeing at a glance: the
                    // month is already over-committed before any of it has
                    // been spent.
                    color: budget.remainingBudget < Decimal.zero
                        ? ObsidianPalette.error
                        : ObsidianPalette.tertiary,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.stackSm),
              Text(
                l10n.budgetLeftToSpendNote,
                textAlign: TextAlign.center,
                style: text.labelMedium?.copyWith(
                  letterSpacing: 0,
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (data.reserved.isNotEmpty) ...[
          const SizedBox(height: Spacing.stackMd),
          _ReservedList(data.reserved),
        ],
      ],
    );
  }
}

/// What the month's subscriptions will take before anything is spendable.
class _ReservedList extends StatelessWidget {
  const _ReservedList(this.items);

  final List<ReservedRecurringItem> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(context.l10n.budgetReservedForSubscriptions),
          const SizedBox(height: Spacing.stackSm),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.payment.name ??
                          context.l10n.subscriptionUnreadableName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        fontStyle: item.payment.name == null
                            ? FontStyle.italic
                            : null,
                      ),
                    ),
                  ),
                  // A weekly subscription falls due four or five times in a
                  // month; showing one fee would understate it that many-fold.
                  if (item.occurrences > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        context.l10n.budgetOccurrences(item.occurrences),
                        style: text.labelMedium?.copyWith(
                          letterSpacing: 0,
                          color: ObsidianPalette.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Text(
                    formatLira(item.reservedAmount),
                    style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories(this.progress);

  final List<CategoryBudgetProgress> progress;

  @override
  Widget build(BuildContext context) {
    if (progress.isEmpty) {
      return NothingYet(message: context.l10n.budgetNoCategoryPlans);
    }
    return Column(
      children: [
        for (final item in progress) ...[
          _CategoryRow(item: item),
          const SizedBox(height: Spacing.stackMd),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.item});

  final CategoryBudgetProgress item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pct = item.pct;
    final overspent = item.remaining < Decimal.zero;
    // Past the user's own alert threshold but not yet over: the point of
    // setting a threshold is to hear about it before the limit is gone.
    final nearLimit =
        !overspent &&
        pct != null &&
        pct >= Decimal.fromInt(item.alertThresholdPct);

    final tone = overspent
        ? ObsidianPalette.error
        : nearLimit
        ? ObsidianPalette.secondary
        : ObsidianPalette.tertiary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (item.rolloverEnabled)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.history,
                    size: 14,
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
                ),
              Text(
                pct == null ? '—' : formatPercent(pct),
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.stackSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: LinearProgressIndicator(
              // Clamped so an overspent category fills the bar rather than
              // overflowing it; the colour and the figures say the rest.
              value: pct == null ? 0 : (pct.toDouble() / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: ObsidianPalette.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(tone),
            ),
          ),
          const SizedBox(height: Spacing.stackSm),
          Row(
            children: [
              Expanded(
                child: Amount(
                  label: context.l10n.budgetSpent,
                  value: formatLira(item.actual),
                ),
              ),
              Expanded(
                child: Amount(
                  label: overspent
                      ? context.l10n.budgetOverBy
                      : context.l10n.budgetLeft,
                  value: formatLira(item.remaining.abs()),
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.month,
    required this.selected,
    required this.onTap,
  });

  final int month;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? ObsidianPalette.surfaceContainerHigh
              : ObsidianPalette.surfaceContainer,
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(color: ObsidianPalette.cardStroke),
        ),
        child: Text(
          shortMonthName(context.l10n, month),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 0,
            color: selected
                ? ObsidianPalette.onSurface
                : ObsidianPalette.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
