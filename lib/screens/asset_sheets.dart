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

import '../app_services.dart';
import '../money/financial_decimal.dart';
import '../services/account_service.dart';
import '../services/asset_service.dart';
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
    // Read BEFORE the first await, so the `catch` does not reach for a
    // context that may no longer be mounted.
    final l10n = context.l10n;
    final price = parseAmountInput(_price.text);
    final quantity = parseAmountInput(_quantity.text);
    if (price == null || quantity == null) {
      setState(() => _error = l10n.errEnterPriceAndQuantity);
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
        _error = assetErrorMessage(l10n, error);
      });
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
    final price = parseAmountInput(_price.text);
    final quantity = parseAmountInput(_quantity.text);

    return SheetFrame(
      title: l10n.buyAssetTitle,
      error: _error,
      saving: _saving,
      actionLabel: l10n.buyAssetAction,
      onSave: _save,
      children: [
        SheetField(
          controller: _name,
          label: l10n.assetName,
          hint: l10n.assetNameHint,
        ),
        const SizedBox(height: Spacing.stackMd),
        SheetField(controller: _code, label: l10n.assetCode, hint: 'GC=F'),
        const SizedBox(height: Spacing.stackMd),
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: const Key('field-type'),
          initialValue: _type,
          decoration: sheetDecoration(l10n.assetKind),
          items: [
            for (final type in assetTypes)
              DropdownMenuItem(value: type, child: Text(type)),
          ],
          onChanged: (value) => setState(() => _type = value ?? _type),
        ),
        const SizedBox(height: Spacing.stackMd),
        SheetField(
          controller: _price,
          label: l10n.assetUnitPrice,
          hint: '0,00',
          numeric: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Spacing.stackMd),
        SheetField(
          controller: _quantity,
          label: l10n.assetQuantity,
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
            l10n.assetTotalIs(formatLira(fiat(price * quantity))),
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
          title: Text(l10n.assetAlreadyOwned, style: text.bodyMedium),
          subtitle: Text(
            l10n.assetAlreadyOwnedNote,
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
                  l10n.assetNoCashAccount,
                  style: text.bodySmall?.copyWith(color: ObsidianPalette.error),
                );
              }
              return DropdownButtonFormField<int?>(
                isExpanded: true,
                key: const Key('field-account'),
                initialValue: _accountId,
                decoration: sheetDecoration(l10n.assetPayFrom),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.assetChooseForMe),
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
    // Read BEFORE the first await, so the `catch` does not reach for a
    // context that may no longer be mounted.
    final l10n = context.l10n;
    final price = parseAmountInput(_price.text);
    final quantity = parseAmountInput(_quantity.text);
    if (price == null || quantity == null) {
      setState(() => _error = l10n.errEnterPriceAndQuantity);
      return;
    }
    final accountId = _accountId;
    if (accountId == null) {
      setState(() => _error = l10n.errChooseDestination);
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
        _error = assetErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final holding = widget.holding;
    final price = parseAmountInput(_price.text);
    final quantity = parseAmountInput(_quantity.text);

    return SheetFrame(
      title: l10n.sellAssetTitle(holding.assetName),
      error: _error,
      saving: _saving,
      actionLabel: l10n.sellAssetAction,
      onSave: _save,
      children: [
        Text(
          l10n.sellAssetHoldingLine(
            '${holding.quantity}',
            formatLira(holding.purchasePrice),
          ),
          style: text.bodySmall?.copyWith(
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.stackMd),
        SheetField(
          controller: _price,
          label: l10n.sellAssetPrice,
          hint: '0,00',
          numeric: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Spacing.stackMd),
        SheetField(
          controller: _quantity,
          label: l10n.sellAssetQuantity,
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
                l10n.sellAssetOutcome(
                  formatLira(proceeds),
                  formatLira(cost),
                  formatSignedLira(gain),
                ),
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
                l10n.sellAssetNoAccount,
                style: text.bodySmall?.copyWith(color: ObsidianPalette.error),
              );
            }
            _accountId ??= accounts.first.id;
            return DropdownButtonFormField<int>(
              isExpanded: true,
              key: const Key('field-account'),
              initialValue: _accountId,
              decoration: sheetDecoration(l10n.sellAssetPayInto),
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
