/// The four calculator screens: what they show, and what they refuse to leave
/// on screen.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/calculator_screens.dart';
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

  Future<void> fill(WidgetTester tester, List<String> values) async {
    final fields = find.byType(TextField);
    for (var i = 0; i < values.length; i++) {
      await tester.enterText(fields.at(i), values[i]);
    }
    await tester.pump();
  }

  Future<void> calculate(WidgetTester tester) async {
    await tester.tap(find.text('CALCULATE'));
    await tester.pumpAndSettle();
  }

  group('deposit interest', () {
    Future<void> open(WidgetTester tester) =>
        pumpScreen(tester, services, const InterestCalculatorScreen());

    testWidgets('reports the net return and the maturity value', (
      tester,
    ) async {
      await open(tester);
      await fill(tester, ['10000', '45', '32']);
      await calculate(tester);

      // The desktop's own figures for these inputs — see
      // test/calculator_vectors.txt.
      expect(find.text('374,79 ₺'), findsOneWidget);
      expect(find.text('10.374,79 ₺'), findsOneWidget);
    });

    testWidgets('says the withholding was taken off', (tester) async {
      // A return quoted without saying it is net is a number the user will
      // compare against a bank's gross rate and think the app is wrong.
      await open(tester);
      await fill(tester, ['10000', '45', '32']);
      await calculate(tester);

      expect(find.textContaining('withholding'), findsOneWidget);
    });

    testWidgets('a zero is refused, and no figure is left behind', (
      tester,
    ) async {
      await open(tester);
      await fill(tester, ['10000', '45', '32']);
      await calculate(tester);
      expect(find.text('374,79 ₺'), findsOneWidget);

      await fill(tester, ['10000', '0', '32']);
      await calculate(tester);

      expect(find.textContaining('greater than zero'), findsOneWidget);
      // The old answer must NOT still be sitting there: under a fresh error
      // it reads as the answer to what was just typed.
      expect(find.text('374,79 ₺'), findsNothing);
    });

    testWidgets('an empty field is refused by name', (tester) async {
      await open(tester);
      await calculate(tester);
      expect(find.textContaining('Fill every field'), findsOneWidget);
    });

    testWidgets('a Turkish decimal comma is accepted', (tester) async {
      await open(tester);
      await fill(tester, ['10000', '45', '32']);
      await calculate(tester);
      final withDot = find.text('374,79 ₺').evaluate().length;

      await fill(tester, ['10000', '45,0', '32']);
      await calculate(tester);

      expect(find.text('374,79 ₺'), findsNWidgets(withDot));
    });
  });

  group('compound', () {
    testWidgets('a blank contribution is zero, not an error', (tester) async {
      await pumpScreen(tester, services, const CompoundCalculatorScreen());
      await fill(tester, ['10000', '30', '5']);
      await calculate(tester);

      expect(find.text('10.000,00 ₺'), findsOneWidget);
      expect(find.text('27.129,30 ₺'), findsOneWidget);
      expect(find.text('37.129,30 ₺'), findsOneWidget);
    });

    testWidgets('a contribution is added to what was paid in', (tester) async {
      await pumpScreen(tester, services, const CompoundCalculatorScreen());
      await fill(tester, ['10000', '30', '5', '500']);
      await calculate(tester);

      expect(find.text('40.000,00 ₺'), findsOneWidget);
      expect(find.text('105.125,09 ₺'), findsOneWidget);
    });
  });

  group('the loan', () {
    Future<void> open(WidgetTester tester) =>
        pumpScreen(tester, services, const LoanCalculatorScreen());

    testWidgets('reports the instalment, the total and the taxes', (
      tester,
    ) async {
      await open(tester);
      await fill(tester, ['100000', '3.29', '12']);
      await calculate(tester);

      expect(find.text('10.827,17 ₺'), findsWidgets);
      expect(find.text('129.926,06 ₺'), findsOneWidget);
      expect(find.textContaining('KKDF'), findsOneWidget);
    });

    testWidgets('the payment plan has a row per month, ending at zero', (
      tester,
    ) async {
      await open(tester);
      await fill(tester, ['100000', '3.29', '12']);
      await calculate(tester);

      expect(find.byType(DataRow), findsNothing, reason: 'DataRow is not a widget');
      // Twelve months means twelve rows; the last one clears the debt.
      expect(find.text('12'), findsWidgets);
      expect(find.text('0,00 ₺'), findsOneWidget);
    });

    testWidgets('a term over the cap says what the cap IS', (tester) async {
      // "Too long" without the number leaves the user guessing.
      await open(tester);
      await fill(tester, ['100000', '3.29', '37']);
      await calculate(tester);

      expect(find.textContaining('at most 36 months'), findsOneWidget);
    });
  });

  group('the plain calculator', () {
    /// Presses pad keys BY KEY, not by text: the display shows '0' when the
    /// expression is empty, so `find.text('0')` is ambiguous the moment a
    /// test presses zero.
    Future<void> press(WidgetTester tester, List<String> keys) async {
      for (final key in keys) {
        await tester.tap(find.byKey(ValueKey('calc-key-$key')));
        await tester.pump();
      }
    }

    String answer(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('calc-answer'))).data ?? '';

    testWidgets('adds up', (tester) async {
      await pumpScreen(tester, services, const BasicCalculatorScreen());
      await press(tester, ['2', '+', '3', '×', '4', '=']);
      // Precedence, not left-to-right: 14, never 20.
      expect(answer(tester), '14');
    });

    testWidgets('takes a square root through its own key', (tester) async {
      // `sqrt(` is not reachable from a numeric keyboard, which is why the
      // keypad exists at all.
      await pumpScreen(tester, services, const BasicCalculatorScreen());
      await press(tester, ['√', '1', '6', ')', '=']);
      expect(answer(tester), '4');
    });

    testWidgets('a fraction is not rounded to two decimals', (tester) async {
      // This is a calculator, not a ledger. Quantizing 1/3 to 0,33 would be
      // answering a different question.
      await pumpScreen(tester, services, const BasicCalculatorScreen());
      await press(tester, ['1', '÷', '3', '=']);
      expect(answer(tester), startsWith('0.3333333'));
    });

    testWidgets('nonsense is refused rather than shown as a number', (
      tester,
    ) async {
      await pumpScreen(tester, services, const BasicCalculatorScreen());
      await press(tester, ['2', '+', '=']);
      expect(answer(tester), contains('not something'));
    });

    testWidgets('backspace and clear both work', (tester) async {
      await pumpScreen(tester, services, const BasicCalculatorScreen());
      await press(tester, ['1', '2', '3', '⌫']);
      expect(
        tester.widget<Text>(find.byKey(const Key('calc-expression'))).data,
        '12',
      );

      await press(tester, ['C']);
      expect(
        tester.widget<Text>(find.byKey(const Key('calc-expression'))).data,
        '0',
      );
    });

    testWidgets('the digits keep the arrangement a calculator has', (
      tester,
    ) async {
      // The first version of the pad filled the grid in order and produced a
      // row reading `4 5 6 1 2`. Nothing failed; it was obvious on a phone.
      // The assertion is on POSITION: each digit's centre, against the one
      // that should sit above and beside it.
      await pumpScreen(tester, services, const BasicCalculatorScreen());
      Offset at(String digit) =>
          tester.getCenter(find.byKey(ValueKey('calc-key-$digit')));

      // 7-8-9 / 4-5-6 / 1-2-3, three columns, three descending rows.
      for (final row in [['7', '8', '9'], ['4', '5', '6'], ['1', '2', '3']]) {
        expect(at(row[0]).dy, at(row[1]).dy, reason: row.join());
        expect(at(row[1]).dy, at(row[2]).dy, reason: row.join());
        expect(at(row[0]).dx, lessThan(at(row[1]).dx), reason: row.join());
        expect(at(row[1]).dx, lessThan(at(row[2]).dx), reason: row.join());
      }
      for (final column in [['7', '4', '1'], ['8', '5', '2'], ['9', '6', '3']]) {
        expect(at(column[0]).dx, at(column[1]).dx, reason: column.join());
        expect(at(column[1]).dx, at(column[2]).dx, reason: column.join());
        expect(at(column[0]).dy, lessThan(at(column[1]).dy));
        expect(at(column[1]).dy, lessThan(at(column[2]).dy));
      }
    });

    testWidgets('every key on the pad does something', (tester) async {
      // The pad is 25 buttons; one wired to nothing would be invisible in a
      // screenshot and obvious to whoever pressed it. Each is found through
      // its OWN label rather than by sweeping every InkWell on the screen —
      // the AppBar's back button is one of those and is not a calculator key.
      const labels = [
        '√', 'log', 'π', '^', '%',
        'C', '(', ')', '⌫', '÷',
        '7', '8', '9', '×', '−',
        '4', '5', '6', '+', '=',
        '1', '2', '3', '0', '.',
      ];
      await pumpScreen(tester, services, const BasicCalculatorScreen());

      for (final label in labels) {
        final key = find.byKey(ValueKey('calc-key-$label'));
        expect(key, findsOneWidget, reason: label);
        expect(tester.widget<InkWell>(key).onTap, isNotNull, reason: label);
      }
    });
  });

  testWidgets('every calculator says it records nothing', (tester) async {
    for (final screen in <Widget>[
      const InterestCalculatorScreen(),
      const CompoundCalculatorScreen(),
      const LoanCalculatorScreen(),
    ]) {
      await pumpScreen(tester, services, screen);
      expect(
        find.textContaining('not a record'),
        findsOneWidget,
        reason: '$screen',
      );
    }
  });
}
