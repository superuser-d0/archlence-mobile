/// Puts a screen under a real service graph over an in-memory database.
///
/// The services are the REAL ones, not stubs: what these tests are for is the
/// join between a screen and the data layer, and a stub would let that join
/// drift without anything noticing.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/services/live_price_service.dart';
import 'package:archlence_mobile/services/price_providers.dart';
import 'package:archlence_mobile/theme/obsidian_prime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixed_key_provider.dart';

/// What every widget test's [LivePriceService] calls instead of a socket.
///
/// Every screen that shows a holding now asks `LivePriceService` for a
/// price, so leaving this unset would mean every such widget test opens a
/// REAL connection the moment it pumps. `LivePriceService` already treats a
/// thrown provider error as "nothing to price this fetch" and falls back to
/// whatever the cache holds (nothing, for a fresh in-memory database) — the
/// same path a genuinely offline phone takes — so refusing here is not a
/// special case for tests, it exercises a real one.
Future<String> _refusingHttpGet(Uri uri) async =>
    throw StateError('no network in tests: $uri');

/// A service graph over a fresh in-memory database.
///
/// [httpGet] lets a test that specifically wants to drive live pricing hand
/// in its own fake; every other test gets one that refuses to be called.
AppServices testServices(ArchlenceDatabase db, {HttpGet? httpGet}) =>
    AppServices.forDatabase(
      db,
      FieldCrypto(FixedKeyProvider.arbitrary()),
      livePrices: LivePriceService(db: db, httpGet: httpGet ?? _refusingHttpGet),
    );

/// Records what a screen asked the language to be changed to.
///
/// Settings' language row is live only where something can actually change
/// the language, so a test that left the scope out would be exercising the
/// unavailable branch — a row with a NOT YET chip on it, which is not what
/// the app draws.
class LocaleChoice {
  Locale? chosen;
  bool asked = false;

  Future<void> select(Locale? locale) async {
    asked = true;
    chosen = locale;
  }
}

/// Wraps [child] in the app's theme and a [ServicesScope].
///
/// The media query mirrors what `AppShell` hands its screens — they read the
/// inset back through `MediaQuery.paddingOf` and would otherwise lay out
/// against a zero inset that never occurs in the app.
///
/// No `locale` is passed, which is what puts these tests in ENGLISH: the test
/// binding reports an en-US device and an unset choice means the device
/// decides. The Turkish labels are covered by `test/l10n_test.dart`.
Widget testApp(
  AppServices services,
  Widget child, {
  LocaleChoice? language,
  Locale? locale,
  ProfileSwap? swapProfile,
}) {
  // The real root, so the scope's placement above the Navigator is the one
  // production uses rather than a copy of it that could drift.
  return ArchlenceRoot(
    services: services,
    theme: obsidianPrimeTheme(),
    selectLocale: (language ?? LocaleChoice()).select,
    locale: locale,
    // Runs the work and nothing else. In the app this closes the service
    // graph and builds another one over what the work left behind; a widget
    // test has no graph to close, and a screen gated on the scope being
    // PRESENT — Backup & Restore's key rows are — would otherwise be tested
    // in its unavailable state.
    swapProfile: swapProfile ?? (work) => work(),
    home: Scaffold(body: child),
  );
}

/// Pumps [child] on a surface tall enough to lay the whole page out.
///
/// The default 800x600 test surface builds only what a `ListView` can show,
/// so anything below the fold is simply absent from the tree and a finder
/// reports "0 widgets" whether the wiring works or not. These tests are about
/// the JOIN between screen and services, not about scroll physics, so the
/// surface is made tall rather than each test taught to scroll.
Future<void> pumpScreen(
  WidgetTester tester,
  AppServices services,
  Widget child, {
  Size size = const Size(800, 2400),
  LocaleChoice? language,
  Locale? locale,
  ProfileSwap? swapProfile,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    testApp(
      services,
      child,
      language: language,
      locale: locale,
      swapProfile: swapProfile,
    ),
  );
  await tester.pumpAndSettle();
}
