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
          _error = 'This subscription is no longer active.';
        });
        return;
      }
      navigator.pop(true);
    } on RecurringError catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = recurringErrorMessage(error);
      });
    }
  }

  Future<void> _savePrice() async {
    final amount = parseAmountInput(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Enter the new price.');
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
    final payment = widget.payment;

    return SheetFrame(
      title: payment.name ?? 'Subscription',
      error: _error,
      saving: _working,
      actionLabel: 'Save new price',
      onSave: _savePrice,
      children: [
        Text(
          'Next on ${formatStoredDate(payment.nextDueDate)}',
          style: text.bodySmall?.copyWith(
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.stackMd),
        SheetField(
          controller: _amount,
          label: 'Price',
          hint: '0,00',
          numeric: true,
        ),
        const SizedBox(height: Spacing.stackSm),
        Text(
          // Why changing the price is not "delete and re-add": that would
          // reset the due history and the alignment of the next charge.
          'Changing the price leaves the schedule where it is.',
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
          label: const Text('Skip the next one'),
        ),
        const SizedBox(height: 4),
        Text(
          'Moves it on one period. The subscription keeps running.',
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
          label: const Text('Stop tracking it'),
        ),
        const SizedBox(height: 4),
        Text(
          'Stops it for good. Past charges stay in your history.',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop tracking this?'),
        content: Text(
          '${widget.payment.name ?? 'This subscription'} will stop being '
          'tracked. Charges already recorded stay where they are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: ObsidianPalette.error),
            child: const Text('Stop it'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await _stop();
  }
}
