/// The category screen: what it shows, what it writes, and what it refuses.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/category_settings_screen.dart';
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

  Future<void> pump(WidgetTester tester) =>
      pumpScreen(tester, services, const CategorySettingsScreen());

  Future<bool> storedIsMain(String name) async {
    final categories = await services.categories.getCategories();
    return categories.firstWhere((c) => c.name == name).isMain;
  }

  /// The switch on the row carrying [name].
  ///
  /// Found through the row's own subtree rather than by index: the list is
  /// sixty rows long and an index would silently follow the seed order if it
  /// ever changed, flipping a different category than the test names.
  Finder switchFor(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
    matching: find.byType(Switch),
  );

  testWidgets('both sides are listed, under their own headings', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('INCOME'), findsOneWidget);
    expect(find.text('EXPENSE'), findsOneWidget);
    // A seeded category from each side, both near the top of their own list
    // so neither needs scrolling to.
    expect(find.text('Maaş'), findsOneWidget);
    expect(find.text('Ev Kirası'), findsOneWidget);
  });

  testWidgets('a switch reflects the row the table holds, not a default', (
    tester,
  ) async {
    // Two categories the seed disagrees about, so a screen that hard-coded
    // either value would fail on one of them.
    final categories = await services.categories.getCategories();
    final main = categories.firstWhere((c) => c.isMain);
    final extra = categories.firstWhere((c) => !c.isMain);

    await pump(tester);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text(main.name), 200);
    expect(tester.widget<Switch>(switchFor(main.name)).value, isTrue);

    await tester.scrollUntilVisible(find.text(extra.name), 200);
    expect(tester.widget<Switch>(switchFor(extra.name)).value, isFalse);
  });

  testWidgets('flipping one writes it through, with no Save to press', (
    tester,
  ) async {
    final target = (await services.categories.getCategories()).firstWhere(
      (c) => !c.isMain,
    );

    await pump(tester);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(target.name), 200);

    await tester.tap(switchFor(target.name));
    await tester.pumpAndSettle();

    expect(await storedIsMain(target.name), isTrue);
    expect(tester.widget<Switch>(switchFor(target.name)).value, isTrue);
  });

  testWidgets('flipping one leaves every other row where it was', (
    tester,
  ) async {
    final before = await services.categories.getCategories();
    final target = before.firstWhere((c) => !c.isMain);

    await pump(tester);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(target.name), 200);
    await tester.tap(switchFor(target.name));
    await tester.pumpAndSettle();

    final after = {
      for (final c in await services.categories.getCategories()) c.name: c.isMain,
    };
    for (final category in before) {
      expect(
        after[category.name],
        category.name == target.name ? true : category.isMain,
        reason: category.name,
      );
    }
  });

  testWidgets('the row says which word applies to its side', (tester) async {
    // 'Main income' and 'Essential' are the same column value. Showing the
    // income word under an expense would be the desktop's column leaking
    // through the screen.
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Main income'), findsWidgets);
    expect(find.text('Essential'), findsWidgets);
    // And the off state is spelled differently on each side too.
    expect(find.text('Extra income'), findsWidgets);
    expect(find.text('A choice'), findsWidgets);
  });

  testWidgets('the screen says what it cannot do, rather than hiding it', (
    tester,
  ) async {
    // No add, no rename, no delete — and a user who came looking for them
    // should find out why here rather than concluding the screen is broken.
    await pump(tester);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('cannot be added, renamed or removed'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('every switch on the screen is live', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches, isNotEmpty);
    for (final control in switches) {
      expect(control.onChanged, isNotNull);
    }
  });
}
