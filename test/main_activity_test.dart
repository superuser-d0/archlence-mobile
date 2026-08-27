/// The one rule that lives in Kotlin.
///
/// `local_auth` needs a `FragmentActivity` to attach BiometricPrompt to, and
/// nothing in Dart can observe whether it has one — the widget tests drive a
/// fake authenticator, and the failure only appears on a device that HAS a
/// screen lock. So the rule is asserted against the source, the same way
/// `dead_controls_test.dart` holds a rule the widget tree cannot express.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MainActivity extends FlutterFragmentActivity', () {
    // Reverting this to the Flutter template's `FlutterActivity` compiles,
    // installs, runs, and leaves the screen lock switch silently inert.
    final source = File(
      'android/app/src/main/kotlin/com/archlence/archlence_mobile/'
      'MainActivity.kt',
    ).readAsStringSync();

    expect(
      source,
      contains('class MainActivity : FlutterFragmentActivity()'),
      reason: 'local_auth cannot show its prompt without a FragmentActivity',
    );
    expect(
      source,
      contains(
        'import io.flutter.embedding.android.FlutterFragmentActivity',
      ),
    );
  });
}
