/// Paying down a credit card from a cash account.
///
/// The service moves both sides and writes both statement lines in one
/// commit, so this only has to gather three things and show what came back.
///
/// One rule is worth saying on screen because its absence is invisible: a
/// FROZEN card can still be paid. Freezing stops new debt, and trapping the
/// user with a balance they cannot clear would be the opposite of what the
/// switch is for.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../services/account_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/error_messages.dart';
import '../ui/money_format.dart';
import '../widgets/sheet_frame.dart';

/// Opens the form for [card]. Returns true if a payment was made.
Future<bool?> showPayDebtSheet(BuildContext context, Account card) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ObsidianPalette.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
    ),
    builder: (context) => _PayDebtSheet(card: card),
  );
}

class _PayDebtSheet extends StatefulWidget {
  const _PayDebtSheet({required this.card});

  final Account card;

  @override
  State<_PayDebtSheet> createState() => _PayDebtSheetState();
}

class _PayDebtSheetState extends State<_PayDebtSheet> {
  final _amount = TextEditingController();
  int? _sourceId;
  Future<List<Account>>? _sources;
  String? _error;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sources ??= _loadSources();
  }

  Future<List<Account>> _loadSources() async {
    // Cash only. The service refuses a card as the source, and offering one
    // here would be inviting an error rather than preventing it.
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
    final sourceId = _sourceId;
    if (sourceId == null) {
      setState(() => _error = l10n.errChooseSource);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    try {
      await ServicesScope.of(context).accounts.payCreditCardDebt(
        creditCardId: widget.card.id,
        sourceAccountId: sourceId,
        amount: amount,
      );
      navigator.pop(true);
    } on AccountError catch (error) {
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
    final card = widget.card;

    return SheetFrame(
      title: l10n.payDebtTitle(card.name),
      error: _error,
      saving: _saving,
      actionLabel: l10n.payDebtAction,
      onSave: _save,
      children: [
        Text(
          l10n.payDebtOwing(formatLira(card.debt)),
          style: text.bodyMedium?.copyWith(color: ObsidianPalette.error),
        ),
        const SizedBox(height: Spacing.stackMd),
        SheetField(
          controller: _amount,
          label: l10n.payDebtAmount,
          hint: '0,00',
          numeric: true,
        ),
        const SizedBox(height: Spacing.stackSm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: card.debt > Decimal.zero
                ? () => setState(() {
                    // The whole debt, in the form the parser reads back —
                    // typing it out is the step most likely to go wrong by a
                    // kurus, and paying more than is owed is refused.
                    _amount.text = formatLira(card.debt).replaceAll(' ₺', '');
                  })
                : null,
            child: Text(l10n.payDebtAll(formatLira(card.debt))),
          ),
        ),
        const SizedBox(height: Spacing.stackSm),
        FutureBuilder<List<Account>>(
          future: _sources,
          builder: (context, snapshot) {
            final sources = snapshot.data ?? const <Account>[];
            if (sources.isEmpty) {
              return Text(
                l10n.payDebtNoSource,
                style: text.bodySmall?.copyWith(color: ObsidianPalette.error),
              );
            }
            _sourceId ??= sources.first.id;
            return DropdownButtonFormField<int>(
              key: const Key('field-source'),
              initialValue: _sourceId,
              decoration: sheetDecoration(l10n.payDebtFrom),
              items: [
                for (final source in sources)
                  DropdownMenuItem(
                    value: source.id,
                    child: Text(
                      l10n.accountWithBalance(
                        source.name,
                        formatLira(source.balance),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) => setState(() => _sourceId = id),
            );
          },
        ),
        if (card.isFrozen) ...[
          const SizedBox(height: Spacing.stackSm),
          Text(
            l10n.payDebtFrozenNote,
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
