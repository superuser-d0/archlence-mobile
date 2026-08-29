/// The chrome every bottom-sheet form in this app shares.
///
/// Four sheets grew their own copy of this before it was pulled out. The
/// desktop has already paid for that kind of duplication once — its savings
/// goal dictionary was built in two places and a field added to one made goal
/// cards lose their colour — so it lives here now, once.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import 'surfaces.dart';

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

/// The chrome every sheet in this app shares: a grab handle, a title, the
/// fields, an error line and one action.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    required this.title,
    required this.children,
    required this.actionLabel,
    required this.onSave,
    required this.saving,
    this.error,
    super.key,
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
        // Every write flow in the app is a sheet, so this one line keeps
        // all of them readable on a wide screen.
        padding: EdgeInsets.symmetric(
          horizontal: contentInset(context),
          vertical: Spacing.containerMargin,
        ),
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
              label: saving ? context.l10n.savingInProgress : actionLabel,
              onPressed: saving ? null : onSave,
            ),
            const SizedBox(height: Spacing.stackMd),
          ],
        ),
      ),
    );
  }
}

class SheetField extends StatefulWidget {
  const SheetField({
    required this.controller,
    required this.label,
    this.hint,
    this.numeric = false,
    this.secret = false,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool numeric;

  /// Obscures the text and offers a deliberate reveal.
  ///
  /// For the backup and key-recovery passphrases, which were typed in the
  /// clear until a run on a device showed them being. This app's own rule,
  /// written down for the shares key: "a displayed credential is one a
  /// shoulder can read".
  ///
  /// Obscured rather than obscured-with-no-way-back, because a passphrase
  /// here CANNOT BE RECOVERED — nothing stores it, and a package written
  /// under a typo is a package that never opens again. The confirm field
  /// catches a typo repeated differently; the eye catches one repeated the
  /// same way.
  final bool secret;

  final ValueChanged<String>? onChanged;

  @override
  State<SheetField> createState() => _SheetFieldState();
}

class _SheetFieldState extends State<SheetField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hidden = widget.secret && !_revealed;

    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      obscureText: hidden,
      // Off for a secret, and not as tidiness: an autocorrect dictionary and
      // a suggestion strip both LEARN what is typed into them, which would
      // put the passphrase somewhere this app does not control and cannot
      // clear.
      autocorrect: !widget.secret,
      enableSuggestions: !widget.secret,
      keyboardType: widget.numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: widget.numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]'))]
          : null,
      decoration: sheetDecoration(widget.label).copyWith(
        hintText: widget.hint,
        suffixIcon: widget.secret
            ? IconButton(
                icon: Icon(
                  hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                tooltip: hidden ? l10n.passphraseReveal : l10n.passphraseHide,
                onPressed: () => setState(() => _revealed = !_revealed),
              )
            : null,
      ),
    );
  }
}
