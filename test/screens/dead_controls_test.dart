/// No control in the app may look live and do nothing.
///
/// This is a whole-app rule, not one screen's, so it is tested as one: walk
/// every tab and assert that every button either has a handler or is visibly
/// disabled. Left to each screen's own file, a new dead control would arrive
/// with a screen that has no such test.
///
/// A guard INSIDE a handler does not satisfy this. `onPressed: () {}` and an
/// early `return` both leave the ripple and the pointer behaviour in place,
/// and a user cannot tell an inert button from a slow one — so they tap it
/// again and conclude the app is broken rather than unfinished.
library;

import 'dart:io';

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/app_shell.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:archlence_mobile/widgets/surfaces.dart';

import '../support/test_app.dart';

void main() {
  late ArchlenceDatabase db;
  late AppServices services;

  setUp(() {
    db = ArchlenceDatabase.memory();
    services = testServices(db);
  });

  tearDown(() => db.close());

  /// Buttons whose handler exists but does nothing would pass a null check,
  /// so the assertion is on the source shape instead: no `() {}` anywhere.
  test('the source carries no empty handler', () {
    // Cheap and blunt, and it holds the line the widget walk cannot: a
    // handler that is present and empty is indistinguishable from a real one
    // at runtime.
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final pattern in ['onTap: () {}', 'onPressed: () {}']) {
        if (source.contains(pattern)) offenders.add('${file.path}: $pattern');
      }
    }
    expect(offenders, isEmpty);
  });

  Future<void> walkTabs(WidgetTester tester) async {
    await tester.pumpWidget(testApp(services, const AppShell()));
    await tester.pumpAndSettle();
  }

  testWidgets('every tab builds, and what has no flow behind it is disabled', (
    tester,
  ) async {
    // NOT "every button is live or disabled" — that is a tautology.
    // `ButtonStyleButton.enabled` is DEFINED as `onPressed != null ||
    // onLongPress != null`, so asserting it would prove nothing. The rule is
    // held by the source check above; this pins the specific controls that
    // currently have no flow, so wiring one up without removing its disabled
    // state fails here, and so does making one look live without wiring it.
    await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 10000,
    );
    await services.accounts.createAccount(
      name: 'Kart',
      accountType: AccountType.creditCard,
      creditLimit: 20000,
    );
    // The savings card only renders when a goal exists, and its Save button
    // is one of the controls being pinned.
    await services.savings.createGoal(goalName: 'Tatil', targetAmount: 20000);

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await walkTabs(tester);

    Future<void> onTab(String tab) async {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }

    // `bySubtype`, not `byType`: `find.byType` matches the EXACT runtime
    // type, so `byType(ButtonStyleButton)` matches nothing at all —
    // OutlinedButton and TextButton are subclasses. An earlier version of
    // this test looped over `byType(ButtonStyleButton)` and passed because
    // the loop body never ran once.
    bool buttonDisabled(String label) =>
        tester
            .widget<ButtonStyleButton>(
              find.ancestor(
                of: find.text(label),
                matching: find.bySubtype<ButtonStyleButton>(),
              ),
            )
            .onPressed ==
        null;

    // GradientButton is built from an InkWell, not a ButtonStyleButton, so it
    // is checked on its own terms rather than left out.
    bool gradientDisabled(String label) =>
        tester
            .widget<GradientButton>(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(GradientButton),
              ),
            )
            .onPressed ==
        null;

    await onTab('Cards');
    // "+ ADD" is deliberately NOT here any more: it opens the add-account
    // sheet. This test caught that the moment the flow landed, which is what
    // it is for — a control must be pinned as one or the other, never left
    // unexamined.
    expect(
      gradientDisabled('+  ADD'),
      isFalse,
      reason: 'the add-account sheet is wired',
    );
    expect(buttonDisabled('Statement'), isTrue, reason: 'no statement screen');
    // Disabled here for a DIFFERENT reason than it used to be: the form
    // exists now, and this card has nothing owing. `pay_debt_test.dart`
    // covers the case where it does and the button is live.
    expect(
      buttonDisabled('Pay Debt'),
      isTrue,
      reason: 'this card owes nothing',
    );

    await onTab('Assets');
    // Save is live now too — the deposit sheet landed. Pinned as live rather
    // than removed, so making it inert again would fail here.
    expect(
      gradientDisabled('Save'),
      isFalse,
      reason: 'the deposit sheet is wired',
    );
  });
}
