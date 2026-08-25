/// Buying and selling a holding.
///
/// Both are thin collectors, like the account and transaction sheets: the
/// services own the rules and these show what came back.
///
/// One thing the BUYING form has to get across in words, because no amount of
/// layout says it: "I already owned this" writes the holding WITHOUT taking
/// the money from any account. Getting that wrong either invents a purchase
/// that never happened or loses one that did.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_services.dart';
import '../money/financial_decimal.dart';
import '../services/account_service.dart';
import '../services/asset_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/error_messages.dart';
import '../ui/money_format.dart';
import '../widgets/surfaces.dart';

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

/// Opens the buy form. Returns the new holding's id, or null if dismissed.
Future<int?> showBuyAssetSheet(BuildContext context) =>
    _showSheet<int>(context, const _BuyAssetSheet());

/// Opens the sell form for [holding]. Returns the proceeds, or null if
/// dismissed.
Future<Decimal?> showSellAssetSheet(BuildContext context, Asset holding) =>
    _showSheet<Decimal>(context, _SellAssetSheet(holding: holding));

// ─── Buying ────────────────────────────────────────────────────────────────

class _BuyAssetSheet extends StatefulWidget {
  const _BuyAssetSheet();

  @override
  State<_BuyAssetSheet> createState() => _BuyAssetSheetState();
}

class _BuyAssetSheetState extends State<_BuyAssetSheet> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _price = TextEditingController();
  final _quantity = TextEditingController();

  String _type = 'Altın';
  int? _accountId;
  bool _alreadyOwned = false;
  Future<List<Account>>? _accounts;
  String? _error;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accounts ??= ServicesScope.of(context).accounts.getAccounts();
  }

  @override
  void dispose() {
    for (final controller in [_name, _code, _price, _quantity]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final price = parseAmountInput(_price.text);
    final quantity = parseAmountInput(_quantity.text);
    if (price == null || quantity == null) {
      setState(() => _error = 'Enter a price and a quantity.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    try {
      final result = await ServicesScope.of(context).assetPurchases
          .createPurchase(
            assetName: _name.text.trim(),
            assetCode: _code.text.trim(),
            assetType: _type,
            purchasePrice: price,
            quantity: quantity,
            // Belt-and-braces: `createPurchase` ignores the account when
            // it is not deducting, so this changes nothing today (measured).
            // It stays because an account picked before the toggle was
            // flipped should not be sent as though it were being charged.
            accountId: _alreadyOwned ? null : _accountId,
            deductFromBalance: !_alreadyOwned,
          );
      navigator.pop(result.assetId);
    } on AssetError catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = assetErrorMessage(error);
      });
    } on AccountError catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = accountErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final price = parseAmountInput(_price.text);
    final quantity = parseAmountInput(_quantity.text);

    return _SheetFrame(
      title: 'New holding',
      error: _error,
      saving: _saving,
      actionLabel: 'Add holding',
      onSave: _save,
      children: [
        _Field(controller: _name, label: 'Name', hint: 'Gram Altın'),
        const SizedBox(height: Spacing.stackMd),
        _Field(controller: _code, label: 'Code', hint: 'GC=F'),
        const SizedBox(height: Spacing.stackMd),
        DropdownButtonFormField<String>(
          key: const Key('field-type'),
          initialValue: _type,
          decoration: sheetDecoration('Kind'),
          items: [
            for (final type in assetTypes)
              DropdownMenuItem(value: type, child: Text(type)),
          ],
          onChanged: (value) => setState(() => _type = value ?? _type),
        ),
        const SizedBox(height: Spacing.stackMd),
        _Field(
          controller: _price,
          label: 'Unit price',
          hint: '0,00',
          numeric: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Spacing.stackMd),
        _Field(
          controller: _quantity,
          label: 'Quantity',
          hint: '1',
          numeric: true,
          onChanged: (_) => setState(() {}),
        ),

        if (price != null && quantity != null) ...[
          const SizedBox(height: Spacing.stackSm),
          // Shown before anything is written, because `1.234` meaning a
          // thousand rather than a lira and a bit is a judgement the parser
          // makes on the user's behalf.
          Text(
            'That is ${formatLira(fiat(price * quantity))} in total.',
            style: text.labelMedium?.copyWith(
              letterSpacing: 0,
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
        ],

        const SizedBox(height: Spacing.stackMd),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _alreadyOwned,
          onChanged: (value) => setState(() => _alreadyOwned = value),
          title: Text('I already owned this', style: text.bodyMedium),
          subtitle: Text(
            'Records the holding without taking the money from an account.',
            style: text.labelMedium?.copyWith(
              letterSpacing: 0,
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
        ),

        if (!_alreadyOwned) ...[
          const SizedBox(height: Spacing.stackSm),
          FutureBuilder<List<Account>>(
            future: _accounts,
            builder: (context, snapshot) {
              final accounts = [
                for (final account in snapshot.data ?? const <Account>[])
                  if (account.accountType == AccountType.checking) account,
              ];
              if (accounts.isEmpty) {
                return Text(
                  'No cash account to pay from. Add one, or record this as '
                  'something you already owned.',
                  style: text.bodySmall?.copyWith(color: ObsidianPalette.error),
                );
              }
              return DropdownButtonFormField<int?>(
                key: const Key('field-account'),
                initialValue: _accountId,
                decoration: sheetDecoration('Pay from'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    // The service picks the first account that can cover it,
                    // and the richest one if none can. Saying so beats a
                    // silent default.
                    child: Text('Choose for me'),
                  ),
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
        ],
      ],
    );
  }
}

// ─── Selling ───────────────────────────────────────────────────────────────

class _SellAssetSheet extends StatefulWidget {
  const _SellAssetSheet({required this.holding});

  final Asset holding;

  @override
  State<_SellAssetSheet> createState() => _SellAssetSheetState();
}

class _SellAssetSheetState extends State<_SellAssetSheet> {
  late final _price = TextEditingController();
  late final _quantity = TextEditingController(
    text: widget.holding.quantity.toString(),
  );

  int? _accountId;
  Future<List<Account>>? _accounts;
  String? _error;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accounts ??= ServicesScope.of(context).accounts.getAccounts();
  }

  @override
  void dispose() {
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = parseAmountInput(_price.text);
    final quantity = parseAmountInput(_quantity.text);
    if (price == null || quantity == null) {
      setState(() => _error = 'Enter a price and a quantity.');
      return;
    }
    final accountId = _accountId;
    if (accountId == null) {
      setState(() => _error = 'Choose where the money goes.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    try {
      final proceeds = await ServicesScope.of(context).assetSales.sell(
        assetId: widget.holding.id,
        sellPricePerUnit: price,
        accountId: accountId,
        quantity: quantity,
      );
      navigator.pop(proceeds);
    } on AssetError catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = assetErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final holding = widget.holding;
    final price = parseAmountInput(_price.text);
    final quantity = parseAmountInput(_quantity.text);

    return _SheetFrame(
      title: 'Sell ${holding.assetName}',
      error: _error,
      saving: _saving,
      actionLabel: 'Sell',
      onSave: _save,
      children: [
        Text(
          'You hold ${holding.quantity}, bought at '
          '${formatLira(holding.purchasePrice)} each.',
          style: text.bodySmall?.copyWith(
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.stackMd),
        _Field(
          controller: _price,
          label: 'Sale price, per unit',
          hint: '0,00',
          numeric: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Spacing.stackMd),
        _Field(
          controller: _quantity,
          label: 'Quantity to sell',
          numeric: true,
          onChanged: (_) => setState(() {}),
        ),

        if (price != null && quantity != null) ...[
          const SizedBox(height: Spacing.stackSm),
          Builder(
            builder: (context) {
              final proceeds = fiat(price * quantity);
              final cost = fiat(holding.purchasePrice * quantity);
              final gain = proceeds - cost;
              return Text(
                '${formatLira(proceeds)} in, against '
                '${formatLira(cost)} paid — '
                '${formatSignedLira(gain)}.',
                style: text.labelMedium?.copyWith(
                  letterSpacing: 0,
                  color: gain < Decimal.zero
                      ? ObsidianPalette.error
                      : ObsidianPalette.tertiary,
                ),
              );
            },
          ),
        ],

        const SizedBox(height: Spacing.stackMd),
        FutureBuilder<List<Account>>(
          future: _accounts,
          builder: (context, snapshot) {
            final accounts = snapshot.data ?? const <Account>[];
            if (accounts.isEmpty) {
              return Text(
                'No account to pay into.',
                style: text.bodySmall?.copyWith(color: ObsidianPalette.error),
              );
            }
            _accountId ??= accounts.first.id;
            return DropdownButtonFormField<int>(
              key: const Key('field-account'),
              initialValue: _accountId,
              decoration: sheetDecoration('Pay into'),
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
      ],
    );
  }
}

// ─── Shared chrome ─────────────────────────────────────────────────────────

InputDecoration sheetDecoration(String label) => InputDecoration(
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

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.children,
    required this.actionLabel,
    required this.onSave,
    required this.saving,
    this.error,
  });

  final String title;
  final List<Widget> children;
  final String actionLabel;
  final VoidCallback onSave;
  final bool saving;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
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
            Text(title, style: text.headlineMedium),
            const SizedBox(height: Spacing.stackLg),
            ...children,
            if (error != null) ...[
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
                      error!,
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
              label: saving ? 'Saving…' : actionLabel,
              onPressed: saving ? null : onSave,
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
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool numeric;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]'))]
          : null,
      decoration: sheetDecoration(label).copyWith(hintText: hint),
    );
  }
}
