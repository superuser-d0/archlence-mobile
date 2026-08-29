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
import '../ui/app_locale.dart';

/// Whether a control with nothing behind it is DRAWN at all.
///
/// `false` for 1.0, and the distinction it rests on is worth stating because
/// this reverses a decision this project made deliberately once.
///
/// The rule above — live, or visibly unavailable — is about a control that
/// EXISTS and is inert in some state: a Pay Debt button on a card that owes
/// nothing, an export that needs a passphrase first. Drawing those as
/// unavailable is honest, because the user could reach them by changing
/// something.
///
/// A row for a feature that has never been built is a different thing. It is
/// not a control in a state; it is an advertisement for an absence, and
/// "Change Password — NOT YET" tells a user nothing they can act on. Running
/// the app on a device made the difference obvious: Settings showed four of
/// them in a single screenful, and two of them — Sign Out, and Dark Mode —
/// contradicted the app outright. There is no account to sign out of, which
/// is the product's whole premise, and no light theme to leave.
///
/// So they are not drawn. The code stays behind this constant rather than
/// being deleted, because each one is a real intention and the argument for
/// building it has not changed. Flip this to `true` to see them all again.
const bool showUnbuiltFeatures = false;

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
        context.l10n.notYetChip,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(fontSize: 9, color: ObsidianPalette.onSurfaceVariant),
      ),
    );
  }
}
