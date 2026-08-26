/// Changing a subscription: its price, one skipped period, or stopping it.
///
/// Three actions with three different meanings, and the difference between
/// the last two is the one a user is most likely to get wrong:
///
///  * SKIP moves the due date on one period and leaves the subscription
///    running. It is "not this month", not "no more".
///  * STOP deactivates it for good. The row is NOT deleted — past
///    transactions and the radar's "already tracked" check both rely on it
///    existing, and a physical delete would turn settled history back into a
///    fresh candidate to rediscover.
library;

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../services/recurring_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/error_messages.dart';
import '../ui/money_format.dart';
import '../widgets/sheet_frame.dart';

/// Opens the sheet. Returns true if anything changed.
Future<bool?> showSubscriptionSheet(
  BuildContext context,
  RecurringPayment payment,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ObsidianPalette.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
    ),
    builder: (context) => _SubscriptionSheet(payment: payment),
  );
}

class _SubscriptionSheet extends StatefulWidget {
  const _SubscriptionSheet({required this.payment});

  final RecurringPayment payment;

  @override
  State<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<_SubscriptionSheet> {
  late final _amount = TextEditingController(
    text: widget.payment.amount?.toString() ?? '',
  );
  String? _error;
  bool _working = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// Runs [action], closing the sheet only if it reported a change.
  Future<void> _run(Future<bool> Function(RecurringService) action) async {
    // Read BEFORE the first await, so the `catch` does not reach for a
    // context that may no longer be mounted.
    final l10n = context.l10n;
    setState(() {
      _working = true;
      _error = null;
    });

    final services = ServicesScope.of(context);
    final navigator = Navigator.of(context);
    try {
      final changed = await action(services.recurring);
      if (!changed) {
        if (!mounted) return;
        setState(() {
          _working = false;
          _error = l10n.subscriptionNoLongerActive;
        });
        return;
      }
      navigator.pop(true);
    } on RecurringError catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = recurringErrorMessage(l10n, error);
      });
    }
  }

  Future<void> _savePrice() async {
    final amount = parseAmountInput(_amount.text);
    if (amount == null) {
      setState(() => _error = context.l10n.errEnterNewPrice);
      return;
    }
    await _run(
      (recurring) =>
          recurring.updateSubscriptionAmount(widget.payment.id, amount),
    );
  }

  Future<void> _skip() => _run(
    (recurring) async =>
        await recurring.skipNextOccurrence(widget.payment.id) != null,
  );

  Future<void> _stop() =>
      _run((recurring) => recurring.cancelSubscription(widget.payment.id));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final payment = widget.payment;

    return SheetFrame(
      title: payment.name ?? l10n.subscriptionFallbackName,
      error: _error,
      saving: _working,
      actionLabel: l10n.subscriptionSavePrice,
      onSave: _savePrice,
      children: [
        Text(
          l10n.subscriptionNextOn(formatStoredDate(payment.nextDueDate)),
          style: text.bodySmall?.copyWith(
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.stackMd),
        SheetField(
          controller: _amount,
          label: l10n.subscriptionPrice,
          hint: '0,00',
          numeric: true,
        ),
        const SizedBox(height: Spacing.stackSm),
        Text(
          // Why changing the price is not "delete and re-add": that would
          // reset the due history and the alignment of the next charge.
          l10n.subscriptionPriceNote,
          style: text.labelMedium?.copyWith(
            letterSpacing: 0,
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: Spacing.stackLg),
        const Divider(),
        const SizedBox(height: Spacing.stackMd),

        OutlinedButton.icon(
          onPressed: _working ? null : _skip,
          icon: const Icon(Icons.skip_next, size: 18),
          label: Text(l10n.subscriptionSkip),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.subscriptionSkipNote,
          style: text.labelMedium?.copyWith(
            letterSpacing: 0,
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: Spacing.stackMd),
        OutlinedButton.icon(
          onPressed: _working ? null : _confirmStop,
          style: OutlinedButton.styleFrom(
            foregroundColor: ObsidianPalette.error,
          ),
          icon: const Icon(Icons.stop_circle_outlined, size: 18),
          label: Text(l10n.subscriptionStop),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.subscriptionStopNote,
          style: text.labelMedium?.copyWith(
            letterSpacing: 0,
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Stopping is the only irreversible thing on this sheet, so it asks.
  Future<void> _confirmStop() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.subscriptionStopTitle),
        content: Text(
          l10n.subscriptionStopBody(
            widget.payment.name ?? l10n.subscriptionStopFallbackName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.subscriptionKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: ObsidianPalette.error),
            child: Text(l10n.subscriptionStopConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await _stop();
  }
}
