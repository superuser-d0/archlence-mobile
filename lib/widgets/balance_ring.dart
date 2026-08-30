import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import 'surfaces.dart';

/// The dashboard's headline: total balance inside a progress ring.
///
/// [changeLabel] may be empty, and then no change chip is drawn at all.
///
/// The amount is wrapped in a [FittedBox]. The reference design sets it at a
/// fixed 40px, which already overflows the ring at "334.401,80 ₺" and breaks
/// outright once a balance reaches seven or eight digits — a real prospect in
/// a lira-denominated app. Shrinking to fit keeps a large balance inside the
/// ring instead of letting it collide with the border.
class BalanceRing extends StatelessWidget {
  const BalanceRing({
    super.key,
    required this.amount,
    required this.changeLabel,
    required this.changeIsPositive,
    required this.periodLabel,
    required this.progress,
    this.diameter = 256,
  });

  final String amount;
  final String changeLabel;
  final bool changeIsPositive;
  final String periodLabel;

  /// 0..1 — how much of the ring is drawn.
  final double progress;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // One announcement, in an order that survives being read aloud.
    //
    // Left alone this came out as "Total Balance, 19.769,25 lira, Net Worth,
    // Cash, 23.250,00 lira" — the caption for the big figure sits BELOW it on
    // screen, so it landed after the number and immediately before an
    // unrelated one, and a listener heard "Net Worth, Cash" as a pair. The
    // layout is right; only the reading of it was wrong. Found with TalkBack
    // running, which is the only thing that finds this class of defect.
    return Semantics(
      container: true,
      label: context.l10n.a11yNetWorthIs(amount),
      excludeSemantics: true,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _RingPainter(progress: progress)),
            ),
            Padding(
              // Keep the label block clear of the stroke on both sides.
              padding: EdgeInsets.symmetric(horizontal: diameter * 0.14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.totalBalance,
                    style: text.bodySmall?.copyWith(
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(amount, maxLines: 1, style: text.displayLarge),
                  ),
                  // An empty label means there is no change to report — the
                  // period figures come from services this port has not
                  // reached. The chip is dropped entirely rather than drawn
                  // empty: on the emulator a bare green pill with an upward
                  // arrow and no number reads as a gain, which is worse than
                  // saying nothing.
                  if (changeLabel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TrendChip(label: changeLabel, positive: changeIsPositive),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    periodLabel,
                    style: text.labelMedium?.copyWith(
                      fontSize: 10,
                      letterSpacing: 0,
                      color: ObsidianPalette.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 5.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withValues(alpha: 0.05);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = ObsidianPalette.tertiary
      // DESIGN.md's `drop-shadow(0 0 8px)` glow, kept subtle enough that the
      // stroke still reads as a line rather than a smear.
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.5);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
