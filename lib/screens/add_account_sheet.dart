/// The form for opening an account or a card.
///
/// A THIN COLLECTOR. It does not re-implement the rules — `createAccount`
/// owns them, and duplicating a rule in a form is how the desktop ended up
/// with `monthly_budget_plan.amount` validated only by its Kivy mixin, where
/// the next caller bypassed it without ever seeing it. What this does is
/// gather text, hand it over, and show what came back.
///
/// It DOES parse the amounts, because the service takes numbers and a person
/// types `1.234,56`. That is presentation, not a rule.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_services.dart';
import '../services/account_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/error_messages.dart';
import '../ui/money_format.dart';
import '../widgets/surfaces.dart';

/// Opens the sheet. Returns the new account's id, or null if it was dismissed.
Future<int?> showAddAccountSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ObsidianPalette.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
    ),
    builder: (context) => const _AddAccountSheet(),
  );
}

class _AddAccountSheet extends StatefulWidget {
  const _AddAccountSheet();

  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _limit = TextEditingController();
  final _statementDay = TextEditingController();
  final _cardNumber = TextEditingController();

  AccountType _type = AccountType.checking;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _amount,
      _limit,
      _statementDay,
      _cardNumber,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isCard => _type == AccountType.creditCard;

  Future<void> _save() async {
    // Read BEFORE the first await, so the `catch` does not reach for a
    // context that may no longer be mounted.
    final l10n = context.l10n;
    // A blank amount means zero, which is a real answer — an account opened
    // with nothing in it. Text that is not a number is NOT zero, and saying
    // so here is the difference between opening an empty account and telling
    // the user their typo was ignored.
    final amountText = _amount.text.trim();
    final amount = parseAmountInput(amountText);
    if (amountText.isNotEmpty && amount == null) {
      setState(() => _error = l10n.errNotAnAmount);
      return;
    }

    final limitText = _limit.text.trim();
    final limit = parseAmountInput(limitText);
    if (limitText.isNotEmpty && limit == null) {
      setState(() => _error = l10n.errNotAnAmount);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    try {
      final id = await ServicesScope.of(context).accounts.createAccount(
        name: _name.text,
        accountType: _type,
        initialBalance: amount ?? 0,
        // Belt-and-braces: `createAccount` already zeroes a limit on a
        // checking account, so this changes nothing today (measured). It
        // stays because a limit typed for a card, carried onto a cash
        // account by switching the toggle back, is not something to leave
        // depending on a rule in another file.
        creditLimit: _isCard ? (limit ?? 0) : 0,
        statementDate: _isCard ? _statementDay.text.trim() : null,
        cardNumberFull: _isCard && _cardNumber.text.trim().isNotEmpty
            ? _cardNumber.text.trim()
            : null,
      );
      navigator.pop(id);
    } on AccountError catch (error) {
      // The service's own rule, in the service's own words — translated once,
      // in error_messages.dart, rather than guessed at here.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = accountErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Padding(
      // The keyboard, or the sheet's fields sit under it.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.containerMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ObsidianPalette.cardStroke,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),
            ),
            const SizedBox(height: Spacing.stackLg),
            Text(l10n.addAccountTitle, style: text.headlineMedium),
            const SizedBox(height: Spacing.stackLg),

            SegmentedButton<AccountType>(
              segments: [
                ButtonSegment(
                  value: AccountType.checking,
                  label: Text(l10n.accountTypeCash),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                ),
                ButtonSegment(
                  value: AccountType.creditCard,
                  label: Text(l10n.accountTypeCreditCard),
                  icon: const Icon(Icons.credit_card),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: Spacing.stackLg),

            _Field(
              controller: _name,
              label: l10n.addAccountName,
              hint: _isCard
                  ? l10n.addAccountNameHintCard
                  : l10n.addAccountNameHintCash,
              autofocus: true,
            ),
            const SizedBox(height: Spacing.stackMd),

            _Field(
              controller: _amount,
              // The sign convention, said in words: for a card the user
              // enters what they OWE as a positive number, and the service
              // stores it negative. Labelling this "balance" on a card would
              // invite a minus sign that would double the debt.
              label: _isCard
                  ? l10n.addAccountCurrentDebt
                  : l10n.addAccountOpeningBalance,
              hint: '0,00',
              numeric: true,
            ),

            if (_isCard) ...[
              const SizedBox(height: Spacing.stackMd),
              _Field(
                controller: _limit,
                label: l10n.addAccountCardLimit,
                hint: '20.000,00',
                numeric: true,
              ),
              const SizedBox(height: Spacing.stackMd),
              _Field(
                controller: _statementDay,
                label: l10n.addAccountStatementDay,
                hint: '15',
                numeric: true,
              ),
              const SizedBox(height: Spacing.stackMd),
              _Field(
                controller: _cardNumber,
                label: l10n.addAccountCardNumber,
                hint: '#### #### #### 1234',
                numeric: true,
              ),
              const SizedBox(height: Spacing.stackSm),
              Text(
                l10n.addAccountCardNumberNote,
                style: text.labelMedium?.copyWith(
                  letterSpacing: 0,
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: Spacing.stackMd),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: ObsidianPalette.error,
                  ),
                  const SizedBox(width: Spacing.stackSm),
                  Expanded(
                    child: Text(
                      _error!,
                      style: text.bodySmall?.copyWith(
                        color: ObsidianPalette.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: Spacing.stackLg),
            GradientButton(
              label: _saving
                  ? l10n.savingInProgress
                  : l10n.addAccountAction,
              // Null while saving, so a second tap cannot open two accounts.
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: Spacing.stackMd),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.numeric = false,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool numeric;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numeric
          // Digits and the two separators only. NOT a stricter pattern: the
          // parser accepts both `1.234,56` and `1234.56`, and a formatter
          // that enforced one would reject what half the users type.
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: ObsidianPalette.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: ObsidianPalette.cardStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: ObsidianPalette.cardStroke),
        ),
      ),
    );
  }
}
