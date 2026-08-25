/// Marks a control that has nothing behind it yet.
///
/// The rule this exists to keep: a control is either live or visibly
/// unavailable — never live-looking and inert. A user cannot tell an inert
/// button from a slow one, so they tap it again, and again, and conclude the
/// app is broken rather than unfinished.
///
/// The guard belongs on the AFFORDANCE, not inside the handler. `onTap: null`
/// (or `onPressed: null`) removes the ripple and the pointer behaviour; an
/// early `return` inside a handler leaves both in place and still invites the
/// tap.
library;

import 'package:flutter/material.dart';

import '../theme/obsidian_prime.dart';

class NotYetChip extends StatelessWidget {
  const NotYetChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ObsidianPalette.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Text(
        'NOT YET',
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(fontSize: 9, color: ObsidianPalette.onSurfaceVariant),
      ),
    );
  }
}
