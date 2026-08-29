/// The version the app SHOWS has to be the version it IS.
///
/// Found by running it: `pubspec.yaml` had been moved to `1.0.0` and the
/// Settings screen went on drawing `Archlence v0.1.0`, because the string was
/// a literal in the widget. The APK would have carried `versionName 1.0.0`
/// into the store listing while the app's own About line disagreed with it.
///
/// No test could have caught that, which is why this one reads `pubspec.yaml`
/// rather than asserting a string: a test written the obvious way would have
/// asserted the same stale literal and passed. Same shape as
/// `main_activity_test.dart`, which reads Kotlin source for the same reason.
library;

import 'dart:io';

import 'package:archlence_mobile/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `version:` line of `pubspec.yaml`, without the `+build` suffix.
String _pubspecVersion() {
  final line = File('pubspec.yaml')
      .readAsLinesSync()
      .firstWhere(
        (line) => line.startsWith('version:'),
        orElse: () => throw StateError('pubspec.yaml has no version: line'),
      );
  return line.substring('version:'.length).trim().split('+').first;
}

void main() {
  test('appVersion is the version in pubspec.yaml', () {
    expect(
      appVersion,
      _pubspecVersion(),
      reason:
          'Bump both together. pubspec.yaml becomes the APK versionName that '
          'Play shows; appVersion is what Settings shows the person holding '
          'the phone. They are the same claim and have to be the same string.',
    );
  });

  test('nothing draws a version string of its own', () {
    // The teeth of the test above. Re-hardcoding `v1.0.0` into a screen would
    // agree with pubspec today and drift again at the next bump, and the
    // check above would go on passing — it can only see the constant.
    final offenders = <String>[];
    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      // The constant's own file is where the literal belongs.
      if (entry.path.endsWith('app_version.dart')) continue;
      // Two shapes, because the first draft caught neither of the ones that
      // matter. It anchored the quote to the digits — `'v1.0.0'` — and the
      // string it was written to catch is `'Archlence v1.0.0'`, where the
      // quote is nowhere near them. It passed the mutation it existed for.
      //
      //   * `v1.0.0` anywhere at all, quoted or not, which is how a version
      //     is written when it is meant to be read.
      //   * a quoted bare triple, for `'1.0.0'` handed to something else.
      //
      // Checked against `lib/` before being trusted: together they match
      // nothing outside `app_version.dart`.
      final source = entry.readAsStringSync();
      final displayed = RegExp(r'v\d+\.\d+\.\d+');
      final bare = RegExp(r"""['"]\d+\.\d+\.\d+['"]""");
      if (displayed.hasMatch(source) || bare.hasMatch(source)) {
        offenders.add(entry.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These files carry a version literal. Use `appVersion` from '
          'lib/app_version.dart, which pubspec.yaml is checked against.',
    );
  });
}
