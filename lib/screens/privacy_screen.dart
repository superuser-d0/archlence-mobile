/// The privacy policy, inside the app.
///
/// **Google Play requires the policy to be reachable from the app itself**,
/// not only from the store listing, and it accepts a link OR the text. This
/// is the text. A link would mean adding `url_launcher` and a fourth URL to a
/// codebase whose README invites the reader to run
/// `grep -rn "Uri.https" lib/` and count three — so the requirement would
/// have been met by making the app's central claim harder to check.
///
/// It also works with no network, which for a policy that opens by saying the
/// app does not need one is the difference between a claim and a
/// demonstration.
///
/// The text comes from `lib/legal/privacy_policy.dart`, which is also what
/// `docs/privacy.html` and `docs/gizlilik.html` are generated from.
library;

import 'package:flutter/material.dart';

import '../legal/privacy_policy.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../widgets/surfaces.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The policy follows the app's language rather than the device's, so a
    // reader who chose Turkish in Settings gets the Turkish text.
    final policy = Localizations.localeOf(context).languageCode == 'tr'
        ? privacyPolicyTr
        : privacyPolicyEn;
    final text = Theme.of(context).textTheme;
    final inset = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: ObsidianPalette.surface,
      appBar: AppBar(
        title: Text(context.l10n.settingsPrivacyPolicy),
        backgroundColor: ObsidianPalette.surface,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          contentInset(context),
          Spacing.stackLg,
          contentInset(context),
          inset.bottom + Spacing.stackLg,
        ),
        children: [
          Text(policy.title, style: text.headlineSmall),
          const SizedBox(height: Spacing.stackSm),
          Text(
            policy.subtitle,
            style: text.bodySmall?.copyWith(
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.stackLg),
          AppCard(
            padding: const EdgeInsets.all(Spacing.gutter),
            child: _Marked(policy.summary, style: text.bodyMedium),
          ),
          for (final section in policy.sections) ...[
            const SizedBox(height: Spacing.sectionGap),
            Text(section.title, style: text.titleMedium),
            const SizedBox(height: Spacing.stackSm),
            for (final block in section.blocks) ...[
              _Block(block),
              const SizedBox(height: Spacing.stackMd),
            ],
          ],
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block(this.block);

  final PolicyBlock block;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final body = text.bodyMedium?.copyWith(
      color: ObsidianPalette.onSurfaceVariant,
    );

    switch (block) {
      case PolicyParagraph(:final text_):
        return _Marked(text_, style: body);
      case PolicyBullets(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.stackSm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: body),
                    // Expanded, or a bullet whose text is wider than the
                    // phone overflows instead of wrapping. See the roadmap's
                    // "What the 800dp surface was hiding".
                    Expanded(child: _Marked(item, style: body)),
                  ],
                ),
              ),
          ],
        );
      case PolicyTable(:final headers, :final rows):
        // Stacked rather than a real table: three columns of prose on a
        // 360dp phone is a horizontal scroll nobody performs. Each row
        // becomes a card, each cell keeps its column's heading.
        return Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.stackMd),
                child: AppCard(
                  padding: const EdgeInsets.all(Spacing.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < row.length; i++) ...[
                        if (i > 0) const SizedBox(height: Spacing.stackSm),
                        Text(
                          headers[i].toUpperCase(),
                          style: text.labelMedium?.copyWith(
                            letterSpacing: 0.6,
                            color: ObsidianPalette.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _Marked(row[i], style: body),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
    }
  }
}

/// Renders the one markup rule the policy uses: `**bold**`.
///
/// The same rule `tool/emit_privacy_pages.dart` turns into `<strong>`. One
/// rule, because two renderers have to agree on it and every rule added is a
/// rule they can disagree about.
class _Marked extends StatelessWidget {
  const _Marked(this.source, {this.style});

  final String source;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyMedium;
    final bold = base?.copyWith(
      fontWeight: FontWeight.w700,
      color: ObsidianPalette.onSurface,
    );

    final spans = <TextSpan>[];
    var index = 0;
    for (final match in RegExp(
      r'\*\*(.+?)\*\*',
      dotAll: true,
    ).allMatches(source)) {
      if (match.start > index) {
        spans.add(TextSpan(text: source.substring(index, match.start)));
      }
      spans.add(TextSpan(text: match.group(1), style: bold));
      index = match.end;
    }
    if (index < source.length) {
      spans.add(TextSpan(text: source.substring(index)));
    }

    return Text.rich(TextSpan(style: base, children: spans));
  }
}

/// `PolicyParagraph`'s field is `text`, which collides with the local
/// `text` in `_Block.build`; this extension names it apart rather than
/// renaming the field, which the generator and the tests also read.
extension on PolicyParagraph {
  String get text_ => text;
}
