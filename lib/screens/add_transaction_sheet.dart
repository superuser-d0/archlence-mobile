/// The form for recording a transaction.
///
/// The same thin-collector rule as `add_account_sheet.dart`: the form gathers
/// text and shows what `addTransaction` said. It parses amounts, because a
/// person types `1.234,56`, and it offers a date, because a future date means
/// something specific here — the row is recorded as `pending` and reaches the
/// balance only when the day arrives.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_services.dart';
import '../services/account_service.dart';
import '../services/transaction_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/error_messages.dart';
import '../ui/money_format.dart';
import '../widgets/surfaces.dart';

/// Opens the sheet. Returns the new transaction's id, or null if dismissed.
Future<int?> showAddTransactionSheet(
  BuildContext context, {
  int? preselectedAccountId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ObsidianPalette.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
    ),
    builder: (context) =>
        _AddTransactionSheet(preselectedAccountId: preselectedAccountId),
  );
}

class _AddTransactionSheet extends StatefulWidget {
  const _AddTransactionSheet({this.preselectedAccountId});

  final int? preselectedAccountId;

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _amount = TextEditingController();
  final _description = TextEditingController();

  String _type = 'expense';
  int? _accountId;
  String? _category;
  DateTime _date = DateTime.now();
  int? _installments;

  Future<(List<Account>, List<String>)>? _options;
  String? _error;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _options ??= _loadOptions();
  }

  Future<(List<Account>, List<String>)> _loadOptions() async {
    final services = ServicesScope.of(context);
    final accounts = await services.accounts.getAccounts();
    final categories = await services.transactions.getCategories(_type);
    _accountId ??= widget.preselectedAccountId ?? accounts.firstOrNull?.id;
    return (accounts, categories);
  }

  void _reloadOptions() {
    setState(() {
      // The category list depends on the type, and a category picked for one
      // does not belong to the other — clearing it is the honest reset.
      _category = null;
      _options = _loadOptions();
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  bool _isCard(List<Account> accounts) =>
      accounts
          .where((account) => account.id == _accountId)
          .firstOrNull
          ?.accountType ==
      AccountType.creditCard;

  /// A date later than today makes the row `pending`; nothing reaches the
  /// balance until start-up settles it.
  bool get _isFuture {
    final today = DateTime.now();
    return DateTime(
      _date.year,
      _date.month,
      _date.day,
    ).isAfter(DateTime(today.year, today.month, today.day));
  }

  Future<void> _save(List<Account> accounts) async {
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
      setState(() => _error = l10n.addTransactionNoAccount);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final services = ServicesScope.of(context);
    final navigator = Navigator.of(context);
    try {
      final id = await services.transactions.addTransaction(
        accountId: accountId,
        amount: amount,
        transactionType: _type,
        category: _category ?? '',
        description: _description.text.trim(),
        transactionDate: _date,
        installments: _installments,
      );

      // The subscription radar. A card expense that looks like a subscription
      // becomes a tracked one, and this is the hook `add_transaction` calls on
      // the desktop — the last piece of that module to be connected. It is
      // idempotent by name, so entering the same subscription monthly by hand
      // still keeps a single record.
      if (_type == 'expense') {
        await services.recurring.registerSubscriptionFromTransaction(
          accountId: accountId,
          amount: amount,
          category: _category,
          description: _description.text.trim(),
          transactionDate: _date,
          isCreditCard: _isCard(accounts),
        );
      }

      navigator.pop(id);
    } on TransactionError catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = transactionErrorMessage(l10n, error);
      });
    } on AccountError catch (error) {
      // The spending rule — a frozen card, or a limit that will not stretch.
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
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FutureBuilder<(List<Account>, List<String>)>(
        future: _options,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final (accounts, categories) = snapshot.data!;

          return SingleChildScrollView(
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
                Text(l10n.addTransactionTitle, style: text.headlineMedium),
                const SizedBox(height: Spacing.stackLg),

                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'expense',
                      label: Text(l10n.transactionTypeExpense),
                      icon: const Icon(Icons.arrow_outward),
                    ),
                    ButtonSegment(
                      value: 'income',
                      label: Text(l10n.transactionTypeIncome),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) {
                    _type = selection.first;
                    _reloadOptions();
                  },
                ),
                const SizedBox(height: Spacing.stackLg),

                if (accounts.isEmpty)
                  Text(
                    l10n.addTransactionNoAccount,
                    style: text.bodySmall?.copyWith(
                      color: ObsidianPalette.error,
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    // Keyed so a test can reach the field itself: tapping its
                    // label text hits the decoration, not the button.
                    key: const Key('field-account'),
                    initialValue: _accountId,
                    decoration: _decoration(l10n.fieldAccount),
                    items: [
                      for (final account in accounts)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(account.name),
                        ),
                    ],
                    onChanged: (id) => setState(() {
                      _accountId = id;
                      // Instalments belong to a card; carrying a count onto a
                      // cash account would send one the service rejects.
                      _installments = null;
                    }),
                  ),
                const SizedBox(height: Spacing.stackMd),

                _AmountField(controller: _amount),
                const SizedBox(height: Spacing.stackMd),

                DropdownButtonFormField<String>(
                  key: const Key('field-category'),
                  initialValue: _category,
                  isExpanded: true,
                  decoration: _decoration(l10n.fieldCategory),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category,
                        child: Text(category, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => _category = value),
                ),
                const SizedBox(height: Spacing.stackMd),

                TextField(
                  controller: _description,
                  decoration: _decoration(l10n.fieldDescriptionOptional),
                ),
                const SizedBox(height: Spacing.stackMd),

                _DateRow(
                  date: _date,
                  isFuture: _isFuture,
                  onPick: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(DateTime.now().year + 5),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),

                if (_isCard(accounts) && _type == 'expense') ...[
                  const SizedBox(height: Spacing.stackMd),
                  DropdownButtonFormField<int?>(
                    key: const Key('field-installments'),
                    initialValue: _installments,
                    decoration: _decoration(l10n.fieldInstallments),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.installmentsNone),
                      ),
                      for (var count = 2; count <= 12; count++)
                        DropdownMenuItem(
                          value: count,
                          child: Text(l10n.installmentMonths(count)),
                        ),
                    ],
                    onChanged: (value) => setState(() => _installments = value),
                  ),
                  const SizedBox(height: Spacing.stackSm),
                  Text(
                    l10n.installmentNote,
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
                      : l10n.addTransactionAction,
                  onPressed: _saving || accounts.isEmpty
                      ? null
                      : () => _save(accounts),
                ),
                const SizedBox(height: Spacing.stackMd),
              ],
            ),
          );
        },
      ),
    );
  }
}

InputDecoration _decoration(String label) => InputDecoration(
  labelText: label,
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
);

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
      ],
      decoration: _decoration(
        context.l10n.fieldAmount,
      ).copyWith(hintText: '0,00'),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.date,
    required this.isFuture,
    required this.onPick,
  });

  final DateTime date;
  final bool isFuture;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.event, size: 18),
          label: Text(formatStoredDate(_iso(date))),
        ),
        if (isFuture) ...[
          const SizedBox(height: Spacing.stackSm),
          // Saying what a future date MEANS, not just that it is one: the
          // money does not move yet, and the user would otherwise wonder why
          // their balance did not change.
          Text(
            context.l10n.transactionScheduledNote,
            style: text.labelMedium?.copyWith(
              letterSpacing: 0,
              color: ObsidianPalette.secondary,
            ),
          ),
        ],
      ],
    );
  }

  static String _iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
