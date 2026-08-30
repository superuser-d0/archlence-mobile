import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';

/// A standard content card: opaque fill plus the 1px hairline stroke.
///
/// DESIGN.md specifies glassmorphism (translucent fill + 20px backdrop blur)
/// for every card. That is deliberately NOT done here, for two reasons.
/// First, these cards sit on a flat [ObsidianPalette.surface] backdrop — there
/// is nothing behind them to blur, so the blur is invisible. Second, every
/// [BackdropFilter] forces a `saveLayer`, and a scrolling list of a dozen of
/// them is a real jank source on mid-range Android. The glass effect is kept
/// where it actually reads: [GlassBar], which overlays moving content.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.gutter),
    this.color,
    this.radius = Radii.lg,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    // `container: true` makes every card its own announcement.
    //
    // Without it a screen reader read whole TABS as a single utterance: the
    // Assets screen came out as one ~60-word sentence carrying twelve figures
    // and a three-sentence explainer, with no way to step inside it or hear
    // one part again. A card is the unit a sighted reader takes in at a
    // glance, so it is the right unit to say out loud. Found by running
    // TalkBack; no guideline reads the shape of an announcement.
    return Semantics(
      container: true,
      child: Material(
        color: color ?? ObsidianPalette.surfaceContainer,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: ObsidianPalette.cardStroke),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// A translucent, blurred bar for surfaces that content scrolls underneath —
/// the app header and the bottom navigation. This is the one place the blur
/// earns its cost, because there is genuinely something moving behind it.
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.child, this.border});

  final Widget child;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ObsidianPalette.surface.withValues(alpha: 0.80),
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Pill-shaped semantic badge: emerald for gains, rose for losses.
class TrendChip extends StatelessWidget {
  const TrendChip({super.key, required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? ObsidianPalette.tertiary : ObsidianPalette.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      // `Flexible` + `FittedBox`, for the same reason the balance above it
      // shrinks: the chip lives inside a 256px ring and a label carrying both
      // a lira figure and a percentage overflows it. Overflow here is not a
      // stripe in a debug build and a clean release — it is a chip clipped
      // mid-number, which reads as a different amount.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: color),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            positive ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: color,
          ),
        ],
      ),
    );
  }
}

/// Primary action: the indigo-to-violet gradient, no border.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    // A null callback has to LOOK like a null callback.
    //
    // It did not: the gradient was painted at full strength whatever
    // `onPressed` held, so a button waiting on a field the user had not
    // filled in was indistinguishable from one that would work, and tapping
    // it did nothing at all. Found by opening the backup screen on the
    // emulator and looking at it — every finder in the widget test was
    // checking `onPressed`, which was correctly null the whole time.
    final enabled = onPressed != null;
    // Its own node, announced as a button.
    //
    // `InkWell` adds a tap ACTION to the nearest semantics node rather than
    // making one, so this button had no node of its own: on the Cards tab it
    // merged upward and the whole scroll body — 1080x1129 of it — became one
    // tappable region labelled "+ ADD", announced before everything it
    // contained. `container` gives it a boundary and `button` makes a screen
    // reader say what kind of thing it is. Found with TalkBack running.
    final button = Opacity(
      opacity: enabled ? 1 : 0.38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ObsidianPalette.primaryGradient,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(Radii.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ObsidianPalette.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final labelled = Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: button,
    );
    return expand
        ? SizedBox(width: double.infinity, child: labelled)
        : labelled;
  }
}

/// Small caps section label ("ACCOUNT & PREFERENCES").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      // Not `toUpperCase()`: see `localizedUpperCase`. Every heading on the
      // Settings screen goes through here, and half of them have an `i` in
      // them in Turkish.
      localizedUpperCase(text, Localizations.localeOf(context)),
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: ObsidianPalette.onSurfaceVariant),
    );
  }
}
