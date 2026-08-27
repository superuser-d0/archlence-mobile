package com.archlence.archlence_mobile

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * `FlutterFragmentActivity`, NOT the template's `FlutterActivity`.
 *
 * `local_auth` shows Android's BiometricPrompt, which is a fragment and needs
 * a `FragmentActivity` to attach to. Under the plain `FlutterActivity` its
 * `authenticate()` throws `no_fragment_activity` — and the failure is quiet in
 * the worst way: `isDeviceSupported()` does NOT need the fragment, so the
 * Settings row correctly reported that the phone has a PIN while the switch
 * beside it did nothing at all when tapped.
 *
 * No Dart test can see this: the widget tests drive a fake authenticator, and
 * the emulator had no screen lock configured until the verification round put
 * one there. `test/main_activity_test.dart` holds the line by reading this
 * file, which is the only place the rule is expressible.
 */
class MainActivity : FlutterFragmentActivity()
