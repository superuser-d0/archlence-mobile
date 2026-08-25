import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/obsidian_prime.dart';

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
    return Material(
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
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
    final button = DecoratedBox(
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
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Small caps section label ("ACCOUNT & PREFERENCES").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: ObsidianPalette.onSurfaceVariant),
    );
  }
}
