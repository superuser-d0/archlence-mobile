/// The form for a monthly budget line.
///
/// The service owns every rule; this gathers text. Two of its fields need
/// explaining rather than labelling, because neither says what it does:
///
///  * "Every month" makes the line a TEMPLATE — it applies to every month
///    until a concrete line of the same identity overrides it in one.
///  * "Carry the balance over" takes LAST MONTH's leftover into this month's
///    limit, and does not chain past it.
library;

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../services/budget_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/error_messages.dart';
import '../ui/money_format.dart';
import '../widgets/sheet_frame.dart';

/// Opens the form. Returns true if a line was saved.
Future<bool?> showBudgetLineSheet(
  BuildContext context, {
  required int month,
  required int year,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ObsidianPalette.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
    ),
    builder: (context) => _BudgetLineSheet(month: month, year: year),
  );
}

class _BudgetLineSheet extends StatefulWidget {
  const _BudgetLineSheet({required this.month, required this.year});

  final int month;
  final int year;

  @override
  State<_BudgetLineSheet> createState() => _BudgetLineSheetState();
}

class _BudgetLineSheetState extends State<_BudgetLineSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();

  String _type = 'expense';
  String? _category;
  bool _everyMonth = false;
  bool _rollover = false;
  int _threshold = 80;

  Future<List<String>>? _categories;
  String? _error;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _categories ??= _loadCategories();
  }

  Future<List<String>> _loadCategories() =>
      ServicesScope.of(context).transactions.getCategories(_type);

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Read BEFORE the first await, so the `catch` does not reach for a
    // context that may no longer be mounted.
    final l10n = context.l10n;
    final amount = parseAmountInput(_amount.text);
    if (amount == null) {
      setState(() => _error = l10n.errEnterAnAmount);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    try {
      await ServicesScope.of(context).budget.savePlanItem(
        itemType: _type,
        name: _name.text,
        amount: amount,
        month: widget.month,
        year: widget.year,
        category: _category,
        rolloverEnabled: _rollover,
        isTemplate: _everyMonth,
        alertThresholdPct: _threshold,
      );
      navigator.pop(true);
    } on BudgetError catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = budgetErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return SheetFrame(
      title: l10n.budgetLineTitle,
      error: _error,
      saving: _saving,
      actionLabel: l10n.budgetLineAction,
      onSave: _save,
      children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'expense',
              label: Text(l10n.transactionTypeExpense),
            ),
            ButtonSegment(
              value: 'income',
              label: Text(l10n.transactionTypeIncome),
            ),
          ],
          selected: {_type},
          onSelectionChanged: (selection) => setState(() {
            _type = selection.first;
            // A category chosen for one type does not exist under the other.
            _category = null;
            _categories = _loadCategories();
          }),
        ),
        const SizedBox(height: Spacing.stackMd),

        SheetField(
          controller: _name,
          label: l10n.budgetLineName,
          hint: l10n.budgetLineNameHint,
        ),
        const SizedBox(height: Spacing.stackMd),
        SheetField(
          controller: _amount,
          label: l10n.budgetLineAmount,
          hint: '0,00',
          numeric: true,
        ),
        const SizedBox(height: Spacing.stackMd),

        FutureBuilder<List<String>>(
          future: _categories,
          builder: (context, snapshot) {
            final categories = snapshot.data ?? const <String>[];
            return DropdownButtonFormField<String?>(
              key: const Key('field-category'),
              initialValue: _category,
              isExpanded: true,
              decoration: sheetDecoration(l10n.fieldCategoryOptional),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.categoryNone),
                ),
                for (final category in categories)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _category = value),
            );
          },
        ),
        const SizedBox(height: Spacing.stackSm),
        Text(
          // Why the optional field matters: without a category the line
          // counts towards the month's total and nothing tracks it.
          l10n.budgetLineCategoryNote,
          style: text.labelMedium?.copyWith(
            letterSpacing: 0,
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: Spacing.stackMd),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _everyMonth,
          onChanged: (value) => setState(() => _everyMonth = value),
          title: Text(l10n.budgetLineEveryMonth, style: text.bodyMedium),
          subtitle: Text(
            l10n.budgetLineEveryMonthNote,
            style: text.labelMedium?.copyWith(
              letterSpacing: 0,
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _rollover,
          onChanged: (value) => setState(() => _rollover = value),
          title: Text(l10n.budgetLineRollover, style: text.bodyMedium),
          subtitle: Text(
            l10n.budgetLineRolloverNote,
            style: text.labelMedium?.copyWith(
              letterSpacing: 0,
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
        ),

        const SizedBox(height: Spacing.stackMd),
        Text(l10n.budgetLineWarnAt('%$_threshold'), style: text.bodyMedium),
        Slider(
          value: _threshold.toDouble(),
          min: 10,
          max: 100,
          divisions: 18,
          label: '%$_threshold',
          onChanged: (value) => setState(() {
            _threshold = value.round();
          }),
        ),
      ],
    );
  }
}
