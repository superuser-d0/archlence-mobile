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

class SheetField extends StatelessWidget {
  const SheetField({
    required this.controller,
    required this.label,
    this.hint,
    this.numeric = false,
    this.onChanged,
    super.key,
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
