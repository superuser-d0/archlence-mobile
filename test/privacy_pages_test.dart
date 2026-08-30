/// The published privacy pages match the app's own copy of the text.
///
/// **Google Play treats a policy that says something untrue as a policy
/// violation, not a typo.** The requirement is that the policy be reachable
/// from the store listing AND from inside the app, which means two copies of
/// a legal document that must not contradict each other — the exact
/// arrangement this project refuses for parity fixtures, for the same reason.
///
/// So `lib/legal/privacy_policy.dart` is the only copy anyone edits, the app
/// renders it, `tool/emit_privacy_pages.dart` writes `docs/privacy.html` and
/// `docs/gizlilik.html`, and this fails if the committed pages have drifted.
/// Editing the text without regenerating is a red suite rather than a store
/// listing that disagrees with the app it describes.
library;

import 'dart:io';

import 'package:archlence_mobile/legal/privacy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/emit_privacy_pages.dart';

void main() {
  for (final (policy, filename) in [
    (privacyPolicyEn, 'docs/privacy.html'),
    (privacyPolicyTr, 'docs/gizlilik.html'),
  ]) {
    test('$filename is what the generator produces', () {
      final onDisk = File(filename).readAsStringSync();
      expect(
        onDisk,
        renderPolicyPage(policy),
        reason:
            'The published policy has drifted from lib/legal/'
            'privacy_policy.dart. Run:\n'
            '    dart run tool/emit_privacy_pages.dart\n'
            'and commit the result. Do not edit $filename by hand — it is '
            'generated, and the copy inside the app comes from the same '
            'source.',
      );
    });
  }

  test('both languages carry the same sections', () {
    // Not a translation check — a structure one. A section present in one
    // language and missing in the other is a policy that says different
    // things to different readers, which is the failure mode that gets an
    // app pulled rather than a wording one.
    expect(
      privacyPolicyTr.sections.length,
      privacyPolicyEn.sections.length,
      reason: 'One language has a section the other does not.',
    );
    for (var i = 0; i < privacyPolicyEn.sections.length; i++) {
      final en = privacyPolicyEn.sections[i];
      final tr = privacyPolicyTr.sections[i];
      expect(
        tr.blocks.length,
        en.blocks.length,
        reason:
            'Section ${i + 1} ("${en.title}" / "${tr.title}") has '
            '${en.blocks.length} blocks in English and ${tr.blocks.length} in '
            'Turkish.',
      );
      for (var j = 0; j < en.blocks.length; j++) {
        expect(
          tr.blocks[j].runtimeType,
          en.blocks[j].runtimeType,
          reason:
              'Section ${i + 1}, block ${j + 1} is a '
              '${en.blocks[j].runtimeType} in English and a '
              '${tr.blocks[j].runtimeType} in Turkish.',
        );
      }
    }
  });

  test('the three hosts in the policy are the three hosts in the code', () {
    // The policy's central claim, checked against the source it describes
    // rather than against a memory of it. If a fourth host is ever added,
    // this fails before the policy can become false.
    final urls = <String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match in RegExp(
        r"""Uri\.https\(\s*'([^']+)'""",
      ).allMatches(entity.readAsStringSync())) {
        urls.add(match.group(1)!);
      }
    }

    expect(
      urls,
      {'api.coingecko.com', 'api.frankfurter.dev', 'www.nosyapi.com'},
      reason:
          'The set of hosts the app can reach has changed. The privacy '
          'policy names three by hand, in both languages, and it is now '
          'wrong. Update lib/legal/privacy_policy.dart and regenerate.',
    );

    for (final host in urls) {
      for (final policy in [privacyPolicyEn, privacyPolicyTr]) {
        final text = policy.sections
            .expand((s) => s.blocks)
            .map(
              (b) => switch (b) {
                PolicyParagraph(:final text) => text,
                PolicyBullets(:final items) => items.join(' '),
                PolicyTable(:final rows) => rows.expand((r) => r).join(' '),
              },
            )
            .join(' ');
        expect(
          text,
          contains(host),
          reason: '$host is reachable from the app but is not named in the '
              '${policy.languageCode} policy.',
        );
      }
    }
  });
}
