/// Ported from the desktop app's `tests/test_financial_decimal.py`.
///
/// Every expectation below is the value CPython's `decimal` module produces
/// for the same input. They are the contract between the two apps: if one of
/// these changes, the phone and the desktop disagree about someone's money.
library;

import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal d(String value) => Decimal.parse(value);

void main() {
  group('decimalFrom', () {
    test('a binary float is converted through its text form', () {
      // Decimal(str(0.1)) — not the double's actual bits.
      expect(decimalFrom(0.1), d('0.1'));
    });

    test('non-finite values are rejected', () {
      for (final value in ['NaN', 'Infinity', '-Infinity']) {
        expect(
          () => decimalFrom(value),
          throwsA(isA<FinancialValueError>()),
          reason: value,
        );
      }
      expect(
        () => decimalFrom(double.nan),
        throwsA(isA<FinancialValueError>()),
      );
      expect(
        () => decimalFrom(double.infinity),
        throwsA(isA<FinancialValueError>()),
      );
      expect(
        () => decimalFrom(double.negativeInfinity),
        throwsA(isA<FinancialValueError>()),
      );
    });

    test('a boolean is not a financial number', () {
      expect(() => decimalFrom(true), throwsA(isA<FinancialValueError>()));
      expect(() => decimalFrom(false), throwsA(isA<FinancialValueError>()));
    });

    test('nonsense text is rejected rather than defaulting to zero', () {
      expect(
        () => decimalFrom('not-a-number'),
        throwsA(isA<FinancialValueError>()),
      );
      expect(() => decimalFrom(null), throwsA(isA<FinancialValueError>()));
    });
  });

  group('fiat', () {
    test('uses bankers rounding', () {
      // The case that half-up would get wrong: 1.005 -> 1.01.
      expect(fiat('1.005'), d('1.00'));
      expect(fiat('1.015'), d('1.02'));
    });

    test('bankers rounding is symmetric about zero', () {
      expect(fiat('-1.005'), d('-1.00'));
      expect(fiat('-1.015'), d('-1.02'));
    });

    test('values away from a half step round normally', () {
      expect(fiat('1.004'), d('1.00'));
      expect(fiat('1.006'), d('1.01'));
      expect(fiat('-1.006'), d('-1.01'));
    });

    test('a value already at precision is unchanged', () {
      expect(fiat('10.10'), d('10.10'));
      expect(fiat('0'), d('0.00'));
    });

    test('large amounts keep every digit', () {
      // Well past the 2^53 mark where a double silently loses precision.
      expect(fiat('9007199254740993.005'), d('9007199254740993.00'));
    });
  });

  group('quantity', () {
    test('asset quantity rules are explicit', () {
      expect(quantity('1.23456', 'Altın'), d('1.2346'));
      expect(quantity('1.2345678', 'Hisse'), d('1.234568'));
      expect(quantity('1.234567895', 'Kripto'), d('1.23456790'));
    });

    test('english asset names resolve to the same precision', () {
      expect(quantity('1.23456', 'gold'), quantity('1.23456', 'Altın'));
      expect(quantity('1.2345678', 'equity'), quantity('1.2345678', 'Hisse'));
      expect(
        quantity('1.234567895', 'crypto'),
        quantity('1.234567895', 'Kripto'),
      );
    });

    test('an unknown asset type falls back to unit-price precision', () {
      expect(quantity('1.234567895', 'something-else'), d('1.23456790'));
      expect(quantity('1.234567895', null), d('1.23456790'));
      expect(quantity('1.234567895', '  '), d('1.23456790'));
    });

    test('the asset type is matched case-insensitively', () {
      expect(quantity('1.23456', 'ALTIN'), d('1.2346'));
      expect(quantity('1.23456', '  Gold  '), d('1.2346'));
    });
  });

  group('percentage', () {
    test('has one shared precision', () {
      expect(percentage('12.345'), d('12.34'));
      expect(FinancialPrecision.percent.scale, FinancialPrecision.fiat.scale);
    });
  });
}
