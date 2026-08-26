library;

import 'package:archlence_mobile/services/price_guard.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('finitePositivePrice', () {
    test('rejects double.infinity', () {
      expect(finitePositivePrice(double.infinity), isNull);
    });

    test('rejects double.negativeInfinity', () {
      expect(finitePositivePrice(double.negativeInfinity), isNull);
    });

    test('rejects double.nan', () {
      expect(finitePositivePrice(double.nan), isNull);
    });

    test('rejects the string "Infinity"', () {
      expect(finitePositivePrice('Infinity'), isNull);
    });

    test('rejects the string "NaN"', () {
      expect(finitePositivePrice('NaN'), isNull);
    });

    test('accepts the finite Decimal string "1e400"', () {
      expect(finitePositivePrice('1e400'), Decimal.parse('1e400'));
    });

    test('rejects the string "abc"', () {
      expect(finitePositivePrice('abc'), isNull);
    });

    test('rejects the empty string', () {
      expect(finitePositivePrice(''), isNull);
    });

    test('rejects true', () {
      expect(finitePositivePrice(true), isNull);
    });

    test('rejects false', () {
      expect(finitePositivePrice(false), isNull);
    });

    test('rejects null', () {
      expect(finitePositivePrice(null), isNull);
    });

    test('rejects 0', () {
      expect(finitePositivePrice(0), isNull);
    });

    test('rejects -1', () {
      expect(finitePositivePrice(-1), isNull);
    });

    test('rejects -0.0', () {
      expect(finitePositivePrice(-0.0), isNull);
    });

    test('returns a Decimal for a normal price', () {
      final price = finitePositivePrice(4612.05);

      expect(price, isA<Decimal>());
      expect(price, Decimal.parse('4612.05'));
    });
  });
}
