/// The order a screen reader reads the shell in.
///
/// **No guideline checks reading order.** `accessibility_test.dart` and the
/// three sweeps all read the semantics tree for labels, sizes and contrast —
/// none of them asks what order the tree is in, and a screen that announces
/// everything correctly in a senseless sequence passes every one of them.
///
/// This was found with TalkBack actually running on a device:
/// `extendBodyBehindAppBar: true` lays the body out FIRST, because it sits
/// behind the header, and semantics traversal follows layout order. So the
/// app read the entire screen — search box, balances, subscriptions — and
/// only then said "Archlence". On every tab.
///
/// `Semantics(sortKey: OrdinalSortKey(...))` puts it back: header, body,
/// action, tabs. This pins that, because the next person to change the
/// Scaffold will not be thinking about a screen reader.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/app_shell.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  late ArchlenceDatabase db;
  late AppServices services;

  setUp(() {
    db = ArchlenceDatabase.memory();
    services = testServices(db);
  });
  tearDown(() => db.close());

  /// Every labelled node, in the order a screen reader reaches it.
  ///
  /// `simulatedAccessibilityTraversal` and not a walk of `visitChildren`:
  /// sort keys are applied when the update is compiled for the platform, not
  /// when the tree is built, so a plain walk returns insertion order and
  /// reports the bug as still present after it is fixed. Found the hard way —
  /// the fix was verified working on a device while this file still failed.
  List<String> announced(WidgetTester tester) => [
    for (final node in tester.semantics.simulatedAccessibilityTraversal())
      if (node.label.isNotEmpty) node.label.replaceAll('\n', ' / '),
  ];

  testWidgets('the app says which app it is before it reads the screen', (
    tester,
  ) async {
    // No `ensureSemantics()` here: `simulatedAccessibilityTraversal` turns
    // semantics on itself and owns the handle, and holding a second one
    // fails the test at teardown rather than in the assertion.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(services, const AppShell()));
    await tester.pumpAndSettle();

    final order = announced(tester);
    final title = order.indexOf('Archlence');
    final firstTab = order.indexWhere((l) => l.startsWith('Home / Tab 1'));

    expect(title, isNonNegative, reason: 'the header is not announced at all');
    expect(
      title,
      lessThan(order.length - 1),
      reason: 'the header is the last thing announced',
    );
    // The header before ANY body content. Before the fix this was index 5,
    // after the search box, the balances and the subscriptions block.
    expect(
      title,
      0,
      reason:
          'The header should be the first thing a screen reader announces, '
          'and it is at $title. Reading order follows layout order, and '
          '`extendBodyBehindAppBar` lays the body out first — the sort keys '
          'in `AppShell` are what put the header back in front.\n'
          'Order was: ${order.take(8).toList()}',
    );
    expect(
      firstTab,
      greaterThan(title),
      reason: 'the tab bar should come after the header',
    );
  });
}
