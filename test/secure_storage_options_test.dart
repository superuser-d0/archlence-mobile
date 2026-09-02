/// Every `FlutterSecureStorage` in `lib/` must pass
/// `AndroidOptions(resetOnError: false)`.
///
/// WHY THIS IS THE MOST EXPENSIVE RULE IN THE APP. `flutter_secure_storage`
/// 11 changed `resetOnError` to default TRUE. On that default, a read the
/// platform cannot satisfy does not surface as an error — it ERASES THE WHOLE
/// STORE. And this store holds the key the entire database is encrypted
/// under, so the reset is not a recovered error: it is every account, every
/// transaction and every holding on the device, permanently unreadable, with
/// no backup unless the user happened to have made one.
///
/// `pubspec.yaml` has said so since the key store moved to 11, and until this
/// test existed that sentence was the only thing holding the line. All five
/// constructions were correct; a sixth added without the argument would
/// compile, analyze clean, pass 1118 tests, and destroy a user's data the
/// first time a read failed.
///
/// A grep is not elegant. It is the same trade the `setState` rule makes in
/// `no_async_set_state_test.dart`: the analyzer has no rule for it, and the
/// alternative is finding out from a one-star review that cannot be answered.
///
/// The rule has NO exception. A default that is safe today is a default that
/// changed once already — which is exactly how this became a rule.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The constructor call, from `FlutterSecureStorage(` to its matching `)`.
///
/// Read by counting parentheses rather than by matching a line, because the
/// argument sits two lines below the constructor in every current use and a
/// line-at-a-time check would see neither half.
String? _construction(String source, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < source.length; i++) {
    final char = source[i];
    if (char == '(') depth++;
    if (char == ')') {
      depth--;
      if (depth == 0) return source.substring(openIndex, i + 1);
    }
  }
  // Unbalanced: the file would not compile, so let the analyzer report it
  // rather than failing here with a worse message.
  return null;
}

void main() {
  test('every FlutterSecureStorage sets resetOnError: false', () {
    final offenders = <String>[];
    final constructor = RegExp(r'\bFlutterSecureStorage\s*\(');
    final required = RegExp(r'AndroidOptions\s*\([^)]*resetOnError:\s*false');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();

      for (final match in constructor.allMatches(source)) {
        // The `(` of the call, which is the last character matched.
        final call = _construction(source, match.end - 1);
        if (call == null) continue;
        if (required.hasMatch(call)) continue;

        final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
        offenders.add('${entity.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These constructions would take flutter_secure_storage 11\'s default '
          'of resetOnError: TRUE, which wipes the store — and with it the '
          'database encryption key — when a read fails. Pass '
          'const AndroidOptions(resetOnError: false).',
    );
  });

  test('the rule is actually holding something', () {
    // The teeth check. A rule whose subject has vanished passes forever and
    // says nothing, so require that there is still something to constrain.
    var constructions = 0;
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      constructions += RegExp(
        r'\bFlutterSecureStorage\s*\(',
      ).allMatches(entity.readAsStringSync()).length;
    }

    expect(
      constructions,
      greaterThanOrEqualTo(5),
      reason:
          'lib/ had five secure-storage constructions when this was written — '
          'the key provider, the backup reminder, the screen lock, the shares '
          'API key and the locale store. Fewer means one was removed and this '
          'count should come down deliberately, not that the rule is moot.',
    );
  });
}
