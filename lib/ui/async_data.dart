/// One place that decides what a screen shows while its data is loading, and
/// what it shows when the load fails.
///
/// THE RULE THIS ENFORCES: a failure is never drawn as a zero. Every service
/// in this app refuses to substitute a plausible-looking number for one it
/// could not read; a screen that caught the exception and rendered `0,00 ₺`
/// would undo all of it at the last step.
library;

import 'package:flutter/material.dart';

import '../theme/obsidian_prime.dart';
import '../widgets/surfaces.dart';

class AsyncData<T> extends StatelessWidget {
  const AsyncData({
    required this.future,
    required this.builder,
    this.placeholderHeight = 96,
    super.key,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;

  /// How much room to hold while loading, so the page does not jump when the
  /// real content arrives.
  final double placeholderHeight;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return DataUnavailable(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return _Loading(height: placeholderHeight);
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}

/// Shown in place of a figure that could not be read.
///
/// It names what went wrong rather than saying "something went wrong": the
/// errors this catches are specific ([AccountError], a corrupt row, a
/// missing key) and the user's next step differs for each.
class DataUnavailable extends StatelessWidget {
  const DataUnavailable({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: ObsidianPalette.error.withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Spacing.stackSm,
        children: [
          const Icon(
            Icons.error_outline,
            size: 18,
            color: ObsidianPalette.error,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This could not be read',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$error',
                  style: text.bodySmall?.copyWith(
                    color: ObsidianPalette.onSurfaceVariant,
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

/// Shown where there is genuinely nothing yet — no accounts, no holdings.
///
/// Deliberately distinct from [DataUnavailable]: "you have not added anything"
/// and "we could not read what you added" call for different reactions, and
/// collapsing them is how an unreadable database comes to look like an empty
/// one.
class NothingYet extends StatelessWidget {
  const NothingYet({required this.message, this.action, super.key});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: text.bodySmall?.copyWith(
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: Spacing.stackMd),
            action!,
          ],
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
