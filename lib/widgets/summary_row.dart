import 'package:flutter/material.dart';

import '../theme/obsidian_prime.dart';
import 'surfaces.dart';

/// One figure in a [SummaryRow].
class SummaryStat {
  const SummaryStat({
    required this.label,
    required this.value,
    this.tone = SummaryTone.neutral,
  });

  final String label;
  final String value;
  final SummaryTone tone;
}

enum SummaryTone { neutral, positive, negative }

/// The three-up figures at the top of the Cards and Assets screens.
///
/// The reference design lays these out as fixed 140px cards inside a
/// horizontal scroller, which pushes the third figure — Net Worth on Cards,
/// Net Balance on Assets — off-screen behind a swipe. In a finance app the
/// summary line is the first thing a user looks for, so all three are given
/// equal width here and always visible. The value shrinks to fit rather than
/// truncating: a half-rendered amount ("₺1.634.902,6") is worse than a small
/// one, because it reads as a different number.
class SummaryRow extends StatelessWidget {
  const SummaryRow({super.key, required this.stats});

  final List<SummaryStat> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      children: [
        for (final stat in stats) Expanded(child: _StatTile(stat: stat)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final SummaryStat stat;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (fill, valueColor) = switch (stat.tone) {
      SummaryTone.positive => (
        ObsidianPalette.tertiary.withValues(alpha: 0.10),
        ObsidianPalette.tertiary,
      ),
      SummaryTone.negative => (
        ObsidianPalette.error.withValues(alpha: 0.10),
        ObsidianPalette.error,
      ),
      SummaryTone.neutral => (
        ObsidianPalette.surfaceContainer,
        ObsidianPalette.onSurface,
      ),
    };

    return AppCard(
      color: fill,
      radius: Radii.md,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stat.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelMedium?.copyWith(
              letterSpacing: 0,
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              stat.value,
              maxLines: 1,
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
