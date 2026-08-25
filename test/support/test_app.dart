/// Puts a screen under a real service graph over an in-memory database.
///
/// The services are the REAL ones, not stubs: what these tests are for is the
/// join between a screen and the data layer, and a stub would let that join
/// drift without anything noticing.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/theme/obsidian_prime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixed_key_provider.dart';

/// A service graph over a fresh in-memory database.
AppServices testServices(ArchlenceDatabase db) =>
    AppServices.forDatabase(db, FieldCrypto(FixedKeyProvider.arbitrary()));

/// Wraps [child] in the app's theme and a [ServicesScope].
///
/// The media query mirrors what `AppShell` hands its screens — they read the
/// inset back through `MediaQuery.paddingOf` and would otherwise lay out
/// against a zero inset that never occurs in the app.
Widget testApp(AppServices services, Widget child) {
  // The real root, so the scope's placement above the Navigator is the one
  // production uses rather than a copy of it that could drift.
  return ArchlenceRoot(
    services: services,
    theme: obsidianPrimeTheme(),
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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(testApp(services, child));
  await tester.pumpAndSettle();
}
