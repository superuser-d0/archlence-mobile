/// What covers the app while it is locked.
///
/// It says what the lock IS. Calling this "your data is protected" would be a
/// claim the lock does not back: the database key opens without it, and this
/// stops a borrowed phone rather than an attacker.
library;

import 'package:flutter/material.dart';

import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../widgets/surfaces.dart';

class LockedScreen extends StatefulWidget {
  const LockedScreen({
    required this.onAuthenticate,
    required this.onUnlocked,
    super.key,
  });

  final Future<bool> Function() onAuthenticate;
  final VoidCallback onUnlocked;

  @override
  State<LockedScreen> createState() => _LockedScreenState();
}

class _LockedScreenState extends State<LockedScreen> {
  bool _asking = false;
  bool _refused = false;

  @override
  void initState() {
    super.initState();
    // Asked immediately: the common case is the owner coming back, and a
    // screen that waits for a tap adds a step to every single return.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  Future<void> _ask() async {
    if (_asking) return;
    setState(() {
      _asking = true;
      _refused = false;
    });
    final passed = await widget.onAuthenticate();
    if (!mounted) return;
    setState(() {
      _asking = false;
      _refused = !passed;
    });
    if (passed) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    // Opaque, not translucent: the point is that the figures behind it cannot
    // be read.
    return ColoredBox(
      color: ObsidianPalette.surface,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: contentInset(context),
            vertical: Spacing.containerMargin,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 48,
                color: ObsidianPalette.primary,
              ),
              const SizedBox(height: Spacing.stackLg),
              Text(l10n.lockedTitle, style: text.headlineMedium),
              const SizedBox(height: Spacing.stackSm),
              Text(
                l10n.lockedExplanation,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
              if (_refused) ...[
                const SizedBox(height: Spacing.stackMd),
                Text(
                  l10n.lockedRefused,
                  style: text.bodySmall?.copyWith(color: ObsidianPalette.error),
                ),
              ],
              const SizedBox(height: Spacing.stackLg),
              GradientButton(
                label: _asking ? l10n.lockedWaiting : l10n.lockedUnlock,
                expand: false,
                onPressed: _asking ? null : _ask,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
