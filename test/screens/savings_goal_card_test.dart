/// A savings goal whose target is zero, which only a restore can deliver.
///
/// **The card is the one place in the app that divides by `target_amount`,**
/// and until this file existed nothing had asked what it does when that
/// column is zero. `SavingsService.createGoal` refuses a non-positive
/// target, so no goal this app WROTE can be one — but the guarantee stops at
/// the writer. `savings_goals.target_amount` is `REAL NOT NULL` with no
/// positivity constraint, in `lib/data/schema.dart` and in the desktop
/// schema it is copied from verbatim, so the row is legal in the file and a
/// restored desktop backup can carry it.
///
/// And `Decimal / Decimal.zero` does not return infinity the way a double
/// division would. It throws `ArgumentError`, from inside `build()` — which
/// is not a wrong number on a card, it is the Assets tab and the savings
/// tool both replaced by an error box, on a profile the user cannot edit
/// their way out of because the row is in their own database.
///
/// The same argument the backup reader gets: this is data the app did not
/// write, and it must fail as a missing progress bar rather than as anything
/// else.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/savings_screen.dart';
import 'package:drift/drift.dart' show Variable;
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

  /// A goal created the normal way, then given the target only a foreign
  /// writer could give it.
  ///
  /// Written through the service first so the encrypted name stays valid and
  /// the row differs from a real one in exactly ONE column — the test is
  /// about that column and nothing else.
  Future<void> goalWithTarget(Object target, {Object current = 250}) async {
    final id = await services.savings.createGoal(
      goalName: 'Tatil',
      targetAmount: 1000,
      currentAmount: current,
    );
    await db.customUpdate(
      'UPDATE savings_goals SET target_amount = ? WHERE id = ?',
      variables: [Variable<double>((target as num).toDouble()), Variable<int>(id)],
    );
  }

  testWidgets('a goal with a zero target draws instead of throwing', (
    tester,
  ) async {
    await goalWithTarget(0);

    await pumpScreen(tester, services, const SavingsScreen());
    await tester.pumpAndSettle();

    // The card is on screen at all, which is the whole point: before the
    // guard this pump ended in an ArgumentError and `tester.takeException()`
    // returned it.
    expect(tester.takeException(), isNull);
    expect(find.text('Tatil'), findsOneWidget);

    // And it says what it can. The amounts are real figures out of the row;
    // only the ratio is unanswerable, so it reads as none of the way there
    // rather than as all of it.
    expect(find.textContaining('%0'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.0);
  });

  testWidgets('a negative target is treated the same way', (tester) async {
    // Not a case anybody expects to see, and exactly why it is here: the
    // guard is written as "is this target usable", not as "is it the one
    // value that throws". A `> 0` test that had been written as `!= 0` would
    // pass the case above and draw a backwards bar for this one.
    await goalWithTarget(-500);

    await pumpScreen(tester, services, const SavingsScreen());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.0);
  });

  testWidgets('an ordinary goal still shows its real progress', (tester) async {
    // The teeth on the guard itself. Without this, replacing the ratio with a
    // hardcoded 0.0 would pass both tests above.
    await goalWithTarget(1000, current: 250);

    await pumpScreen(tester, services, const SavingsScreen());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('%25'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.25, 1e-9));
  });
}
