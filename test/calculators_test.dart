/// Differential tests against the desktop's own calculator methods.
///
/// Every expectation comes from `test/calculator_vectors.txt`, which
/// `tool/emit_calculator_vectors.py` produces by CALLING
/// `mixins/calculator_mixin.py` and `utils/calculator.py` — the mixin imported
/// with its Kivy widgets stubbed, so the arithmetic that answers is the
/// desktop's own.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:archlence_mobile/services/calculators.dart';
import 'package:archlence_mobile/services/expression_evaluator.dart';
import 'package:archlence_mobile/ui/money_format.dart';
import 'package:flutter_test/flutter_test.dart';

List<List<String>> _vectors(String kind) => [
  for (final line in File('test/calculator_vectors.txt').readAsLinesSync())
    if (line.startsWith('$kind|')) line.split('|').sublist(1),
];

void main() {
  group('deposit interest', () {
    final cases = _vectors('INTEREST');

    test('the fixture is there and covers more than one rate', () {
      expect(cases, isNotEmpty);
      expect(cases.map((c) => c[1]).toSet().length, greaterThan(1));
    });

    test('every case matches the desktop, down to the formatting', () {
      for (final row in cases) {
        final result = calculateDepositInterest(
          principal: double.parse(row[0]),
          ratePercent: double.parse(row[1]),
          days: int.parse(row[2]),
        );
        final where = '${row[0]} at ${row[1]}% for ${row[2]} days';
        expect(formatLira(result.netProfit), '${row[3]} ₺', reason: where);
        expect(formatLira(result.total), '${row[4]} ₺', reason: where);
      }
    });
  });

  group('compound growth', () {
    final cases = _vectors('COMPOUND');

    test('the fixture covers both with and without a contribution', () {
      expect(cases.any((c) => c[3] == '0'), isTrue);
      expect(cases.any((c) => c[3] != '0'), isTrue);
    });

    test('every case matches the desktop', () {
      for (final row in cases) {
        final result = calculateCompound(
          principal: double.parse(row[0]),
          ratePercent: double.parse(row[1]),
          years: int.parse(row[2]),
          monthlyDeposit: double.parse(row[3]),
        );
        final where = '${row[0]} at ${row[1]}% for ${row[2]}y +${row[3]}/mo';
        expect(formatLira(result.invested), '${row[4]} ₺', reason: where);
        expect(formatLira(result.profit), '${row[5]} ₺', reason: where);
        expect(formatLira(result.amount), '${row[6]} ₺', reason: where);
      }
    });
  });

  group('the loan', () {
    final cases = _vectors('LOAN');
    final rows = _vectors('LOANROW');

    test('the fixture carries schedules as well as instalments', () {
      expect(cases, isNotEmpty);
      expect(rows, isNotEmpty);
    });

    test('the instalment and the total match the desktop', () {
      for (final row in cases) {
        final result = calculateLoan(
          principal: double.parse(row[0]),
          monthlyRatePercent: double.parse(row[1]),
          months: int.parse(row[2]),
        );
        final where = '${row[0]} at ${row[1]}%/mo over ${row[2]}';
        expect(formatLira(result.instalment), '${row[3]} ₺', reason: where);
        expect(formatLira(result.totalRepayment), '${row[4]} ₺', reason: where);
      }
    });

    test('every scheduled row matches, including the last', () {
      // The last row is where floating drift accumulates: a schedule whose
      // final balance is 0,03 rather than 0,00 reads as a bug in the loan.
      for (final row in rows) {
        final result = calculateLoan(
          principal: double.parse(row[0]),
          monthlyRatePercent: double.parse(row[1]),
          months: int.parse(row[2]),
        );
        final month = int.parse(row[3]);
        final scheduled = result.schedule[month - 1];
        final where = '${row[0]}/${row[1]}/${row[2]} month $month';

        expect(scheduled.month, month, reason: where);
        expect(_plain(scheduled.instalment), row[4], reason: where);
        expect(_plain(scheduled.principalPart), row[5], reason: where);
        expect(_plain(scheduled.interestAndTax), row[6], reason: where);
        expect(_plain(scheduled.remaining), row[7], reason: where);
      }
    });

    test('the schedule pays the debt off exactly', () {
      final result = calculateLoan(
        principal: 100000,
        monthlyRatePercent: 3.29,
        months: 36,
      );
      expect(result.schedule, hasLength(36));
      expect(result.schedule.last.remaining.toDouble(), 0);
    });
  });

  group('what the desktop refuses, this refuses', () {
    final cases = _vectors('REFUSED');

    test('the fixture names all three calculators', () {
      expect(cases.map((c) => c[0]).toSet(), {'INTEREST', 'COMPOUND', 'LOAN'});
    });

    test('each refusal is a refusal here too', () {
      for (final row in cases) {
        final where = row.join('/');
        expect(
          () => switch (row[0]) {
            'INTEREST' => calculateDepositInterest(
              principal: double.parse(row[1]),
              ratePercent: double.parse(row[2]),
              days: int.parse(row[3]),
            ),
            'COMPOUND' => calculateCompound(
              principal: double.parse(row[1]),
              ratePercent: double.parse(row[2]),
              years: int.parse(row[3]),
            ),
            _ => calculateLoan(
              principal: double.parse(row[1]),
              monthlyRatePercent: double.parse(row[2]),
              months: int.parse(row[3]),
            ),
          },
          throwsA(isA<CalculatorError>()),
          reason: where,
        );
      }
    });

    test('a term over the cap is refused by its own code', () {
      // Distinguished from "not positive" so the screen can say WHICH rule
      // was broken rather than one message for both.
      expect(
        () => calculateLoan(
          principal: 100000,
          monthlyRatePercent: 3.29,
          months: loanMaxTermMonths + 1,
        ),
        throwsA(
          isA<CalculatorError>().having(
            (e) => e.code,
            'code',
            CalculatorErrorCode.termTooLong,
          ),
        ),
      );
    });
  });

  group('the plain calculator', () {
    final cases = _vectors('BASIC');

    test('the fixture covers the precedence traps', () {
      final expressions = cases.map((c) => c[0]).toSet();
      // Without these three the parser could be written wrong in the obvious
      // way and pass everything else.
      expect(expressions, contains('-2**2'));
      expect(expressions, contains('2**-2'));
      expect(expressions, contains('2**3**2'));
      expect(expressions, contains('10%-3'));
    });

    test('every expression gives the number Python gave, bit for bit', () {
      for (final row in cases) {
        if (_needsLog10(row[0])) continue;
        // Compared as doubles, not as text: the fixture carries Python's
        // `repr`, and Dart prints the same value differently in places
        // (`4.0` against `4`).
        expect(
          evaluateExpression(row[0]),
          double.parse(row[1]),
          reason: row[0],
        );
      }
    });

    test('the one function Dart lacks is out by at most one ULP', () {
      // Dart has no `log10`. `log(x) / ln10` is the substitute and it is a
      // DIFFERENT function in the last bit: Python's `math.log10(2)` is
      // 0.3010299956639812 and this gives 0.30102999566398114.
      //
      // The gap is stated as a bound rather than papered over with a loose
      // matcher — one ULP, asserted, so a real error still fails this. An
      // exact power of ten is not in here: those are snapped back and are
      // asserted bit-for-bit above, which is what protects the snap.
      final logCases = [for (final row in cases) if (_needsLog10(row[0])) row];
      expect(logCases, isNotEmpty);

      for (final row in logCases) {
        final expected = double.parse(row[1]);
        final actual = evaluateExpression(row[0]);
        // One ULP PER `log` CALL, not one per expression: `log(7)*log(13)`
        // multiplies two values that are each a bit off, so its error is two.
        // Stating the bound per call is what keeps it a bound rather than a
        // number chosen to make the test pass.
        final calls = 'log('.allMatches(row[0]).length;
        expect(
          (actual - expected).abs(),
          lessThanOrEqualTo(calls * _ulp(expected)),
          reason: '${row[0]}: $actual against $expected',
        );
      }
    });

    test('everything the desktop refuses is refused', () {
      final refused = [
        for (final line in File(
          'test/calculator_vectors.txt',
        ).readAsLinesSync())
          if (line.startsWith('BASICREFUSED|')) line.substring(13),
      ];
      expect(refused, isNotEmpty);
      // The two that matter for safety, spelled out so they cannot quietly
      // fall out of the fixture.
      expect(refused, contains("__import__('os')"));
      expect(refused, contains("open('x')"));

      for (final expression in refused) {
        expect(
          () => evaluateExpression(expression),
          throwsA(isA<CalculatorError>()),
          reason: expression,
        );
      }
    });

    test('an unclosed bracket and a stray operator are refused', () {
      for (final expression in ['(1+2', '1+2)', '*3', '2 3', 'sqrt', 'sqrt 4']) {
        expect(
          () => evaluateExpression(expression),
          throwsA(isA<CalculatorError>()),
          reason: expression,
        );
      }
    });
  });

  group('reading what the user typed', () {
    test('a Turkish decimal comma is accepted', () {
      // The desktop calls `float()` on the raw text, which refuses '1234,56'.
      // A phone keyboard in Turkish puts the comma under the thumb, and
      // copying that limitation would be copying an accident.
      expect(parseCalculatorNumber('1234,56'), 1234.56);
      expect(parseCalculatorNumber(' 1234.56 '), 1234.56);
    });

    test('a blank or non-numeric field is refused by its own code', () {
      for (final text in ['', '   ', 'abc', '1,2,3']) {
        expect(
          () => parseCalculatorNumber(text),
          throwsA(
            isA<CalculatorError>().having(
              (e) => e.code,
              'code',
              CalculatorErrorCode.notANumber,
            ),
          ),
          reason: text,
        );
      }
    });
  });
}

/// Whether an expression's answer goes through the base-10 logarithm.
///
/// `log(1000)` does NOT count: an exact power of ten is snapped back to its
/// integer, so it is required to match exactly.
bool _needsLog10(String expression) {
  if (!expression.contains('log(')) return false;
  return !const {'log(1000)'}.contains(expression);
}

/// The distance to the next representable double above [value].
double _ulp(double value) {
  final magnitude = value.abs();
  if (magnitude == 0) return 5e-324;
  final bits = ByteData(8)..setFloat64(0, magnitude);
  final next = ByteData(8)
    ..setUint64(0, bits.getUint64(0) + 1);
  return next.getFloat64(0) - magnitude;
}

/// A figure the way the desktop writes it inside its schedule table: grouped,
/// two decimals, and no currency symbol.
String _plain(Object amount) =>
    formatLira(amount as dynamic).replaceAll(' ₺', '');
