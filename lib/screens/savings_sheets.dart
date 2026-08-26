/// Opening a savings goal, and moving money in and out of one.
///
/// Every one of these passes `goalUid`. That is the point of the field: a
/// numeric id can be reused after a restore, so a screen still holding an old
/// card would otherwise fund a goal the user never meant. The service checks
/// it before any money moves and refuses on a mismatch.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../services/account_service.dart';
import '../services/savings_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/error_messages.dart';
import '../ui/money_format.dart';
import '../widgets/sheet_frame.dart';

Future<T?> _showSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ObsidianPalette.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
    ),
    builder: (context) => child,
  );
}

/// Opens the new-goal form. Returns the goal's id, or null if dismissed.
Future<int?> showNewGoalSheet(BuildContext context) =>
    _showSheet<int>(context, const _NewGoalSheet());

/// Opens the deposit/withdraw form for [goal]. Returns true if money moved.
Future<bool?> showMoveMoneySheet(BuildContext context, SavingsGoal goal) =>
    _showSheet<bool>(context, _MoveMoneySheet(goal: goal));

// ─── Opening a goal ────────────────────────────────────────────────────────

class _NewGoalSheet extends StatefulWidget {
  const _NewGoalSheet();

  @override
  State<_NewGoalSheet> createState() => _NewGoalSheetState();
}

class _NewGoalSheetState extends State<_NewGoalSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Read BEFORE the first await, so the `catch` does not reach for a
    // context that may no longer be mounted.
    final l10n = context.l10n;
    final target = parseAmountInput(_target.text);
    if (target == null) {
      setState(() => _error = l10n.errEnterTargetAmount);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    try {
      final id = await ServicesScope.of(context).savings
          // Not trimmed here: `createGoal` trims and rejects a blank name,
          // and a form that pre-cleans input is a form quietly holding half a
          // rule.
          .createGoal(goalName: _name.text, targetAmount: target);
      navigator.pop(id);
    } on SavingsError catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = savingsErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return SheetFrame(
      title: l10n.newGoalTitle,
      error: _error,
      saving: _saving,
      actionLabel: l10n.newGoalAction,
      onSave: _save,
      children: [
        Text(
          l10n.newGoalExplanation,
          style: text.bodySmall?.copyWith(
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.stackMd),
        SheetField(
          controller: _name,
          label: l10n.newGoalName,
          hint: l10n.newGoalNameHint,
        ),
        const SizedBox(height: Spacing.stackMd),
        SheetField(
          controller: _target,
          label: l10n.newGoalTarget,
          hint: '0,00',
          numeric: true,
        ),
      ],
    );
  }
}

// ─── Moving money ──────────────────────────────────────────────────────────

class _MoveMoneySheet extends StatefulWidget {
  const _MoveMoneySheet({required this.goal});

  final SavingsGoal goal;

  @override
  State<_MoveMoneySheet> createState() => _MoveMoneySheetState();
}

class _MoveMoneySheetState extends State<_MoveMoneySheet> {
  final _amount = TextEditingController();
  bool _depositing = true;
  int? _accountId;
  Future<List<Account>>? _accounts;
  String? _error;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accounts ??= _loadAccounts();
  }

  Future<List<Account>> _loadAccounts() async {
    // Cash only: a goal holds money aside from a balance, and a card has no
    // balance to hold it aside from — only a limit.
    final accounts = await ServicesScope.of(context).accounts.getAccounts();
    return [
      for (final account in accounts)
        if (account.accountType == AccountType.checking) account,
    ];
  }

  @override
  void dispose() {
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
    final accountId = _accountId;
    if (accountId == null) {
      setState(() => _error = l10n.errChooseCashAccount);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final savings = ServicesScope.of(context).savings;
    final navigator = Navigator.of(context);
    try {
      if (_depositing) {
        await savings.depositToGoal(
          goalId: widget.goal.id,
          amount: amount,
          accountId: accountId,
          goalUid: widget.goal.goalUid,
        );
      } else {
        await savings.withdrawFromGoal(
          goalId: widget.goal.id,
          amount: amount,
          accountId: accountId,
          goalUid: widget.goal.goalUid,
        );
      }
      navigator.pop(true);
    } on SavingsError catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = savingsErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final goal = widget.goal;
    final remaining = goal.targetAmount - goal.currentAmount;

    return SheetFrame(
      title: goal.goalName ?? l10n.goalFallbackName,
      error: _error,
      saving: _saving,
      actionLabel: _depositing ? l10n.goalSetAside : l10n.goalTakeBack,
      onSave: _save,
      children: [
        Text(
          remaining > Decimal.zero
              ? l10n.goalProgressWithRemaining(
                  formatLira(goal.currentAmount),
                  formatLira(goal.targetAmount),
                  formatLira(remaining),
                )
              : l10n.goalProgress(
                  formatLira(goal.currentAmount),
                  formatLira(goal.targetAmount),
                ),
          style: text.bodySmall?.copyWith(
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.stackMd),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: true,
              label: Text(l10n.goalSetAside),
              icon: const Icon(Icons.savings_outlined),
            ),
            ButtonSegment(
              value: false,
              label: Text(l10n.goalTakeBack),
              icon: const Icon(Icons.undo),
            ),
          ],
          selected: {_depositing},
          onSelectionChanged: (selection) =>
              setState(() => _depositing = selection.first),
        ),
        const SizedBox(height: Spacing.stackMd),
        SheetField(
          controller: _amount,
          label: l10n.fieldAmount,
          hint: '0,00',
          numeric: true,
        ),
        const SizedBox(height: Spacing.stackMd),
        FutureBuilder<List<Account>>(
          future: _accounts,
          builder: (context, snapshot) {
            final accounts = snapshot.data ?? const <Account>[];
            if (accounts.isEmpty) {
              return Text(
                l10n.goalMoveNoAccount,
                style: text.bodySmall?.copyWith(color: ObsidianPalette.error),
              );
            }
            _accountId ??= accounts.first.id;
            return DropdownButtonFormField<int>(
              key: const Key('field-account'),
              initialValue: _accountId,
              decoration: sheetDecoration(
                _depositing ? l10n.goalMoveFrom : l10n.goalMoveInto,
              ),
              items: [
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: (id) => setState(() => _accountId = id),
            );
          },
        ),
        if (_depositing) ...[
          const SizedBox(height: Spacing.stackSm),
          // The deliberate absence of a guard, said out loud: the service has
          // no insufficient-balance check here, because going negative to
          // fund a goal is the user's call.
          Text(
            l10n.goalMayGoNegative,
            style: text.labelMedium?.copyWith(
              letterSpacing: 0,
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
