/// Turkish presentation formatting.
///
/// Separate from `formatWithThousands` in `asset_service.dart` on purpose:
/// that one produces the Western form that goes INTO stored descriptions and
/// must match what the desktop writes. These two must never converge, so both
/// are pinned.
library;

import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:archlence_mobile/services/asset_service.dart';
import 'package:archlence_mobile/ui/money_format.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Decimal money(String value) => fiat(value);

  group('formatLira', () {
    test('groups by three with Turkish separators', () {
      expect(formatLira(money('1234567.89')), '1.234.567,89 ₺');
      expect(formatLira(money('334401.8')), '334.401,80 ₺');
      expect(formatLira(money('999.99')), '999,99 ₺');
    });

    test('always shows two fractional digits', () {
      // Decimal.toString() drops trailing zeros — 100 prints as "100" — so
      // the fraction is rebuilt rather than read off the text.
      expect(formatLira(money('100')), '100,00 ₺');
      expect(formatLira(money('100.5')), '100,50 ₺');
      expect(formatLira(Decimal.zero), '0,00 ₺');
    });

    test('keeps the minus in front of the digits', () {
      expect(formatLira(money('-1234.56')), '-1.234,56 ₺');
      expect(formatLira(money('-0.5')), '-0,50 ₺');
    });

    test('rounds to the kurus by policy', () {
      // Half-even, as everywhere else: 1.005 goes to 1.00, not 1.01.
      expect(formatLira(Decimal.parse('1.005')), '1,00 ₺');
      expect(formatLira(Decimal.parse('1.015')), '1,02 ₺');
    });
  });

  group('formatSignedLira', () {
    test('marks a gain explicitly', () {
      expect(formatSignedLira(money('1250')), '+1.250,00 ₺');
      expect(formatSignedLira(money('-1250')), '-1.250,00 ₺');
      expect(formatSignedLira(Decimal.zero), '0,00 ₺');
    });
  });

  group('formatPercent', () {
    test('puts the symbol before the number, Turkish style', () {
      expect(formatPercent(money('12.5')), '%12,5');
      expect(formatPercent(money('25')), '%25');
    });

    test('a minus goes before the symbol', () {
      expect(formatPercent(money('-6.2')), '-%6,2');
    });

    test('a plus appears only when asked for', () {
      expect(formatPercent(money('6.2')), '%6,2');
      expect(formatPercent(money('6.2'), signed: true), '+%6,2');
    });
  });

  group('dates', () {
    test('a stored stamp reads day-first', () {
      expect(formatStoredDate('2026-09-15'), '15.09.2026');
      expect(formatStoredDate('2026-09-15 14:05:09'), '15.09.2026');
      expect(formatStoredDayMonth('2026-08-06 12:00:00'), '06.08');
    });

    test('an unusable stamp reads empty, not as a wrong date', () {
      expect(formatStoredDate(null), '');
      expect(formatStoredDate('2026'), '');
    });
  });

  group('parseAmountInput', () {
    test('reads the Turkish form the app itself prints', () {
      expect(parseAmountInput('1.234,56'), Decimal.parse('1234.56'));
      expect(parseAmountInput('334.401,80'), Decimal.parse('334401.80'));
      expect(parseAmountInput('1.234.567,89'), Decimal.parse('1234567.89'));
    });

    test('reads the Western form the same user may also type', () {
      expect(parseAmountInput('1,234.56'), Decimal.parse('1234.56'));
      expect(parseAmountInput('1234.56'), Decimal.parse('1234.56'));
    });

    test('a lone comma is a decimal point', () {
      expect(parseAmountInput('1234,56'), Decimal.parse('1234.56'));
      expect(parseAmountInput('0,5'), Decimal.parse('0.5'));
    });

    test('lone dots in groups of three are grouping, not decimals', () {
      // The judgement call. `1.234` is far likelier to be a thousand-lira
      // figure than a lira and a bit, and the form shows what it understood
      // before anything is written.
      expect(parseAmountInput('1.234'), Decimal.parse('1234'));
      expect(parseAmountInput('1.234.567'), Decimal.parse('1234567'));
    });

    test('a lone dot with any other group length is a decimal point', () {
      expect(parseAmountInput('1234.5'), Decimal.parse('1234.5'));
      expect(parseAmountInput('12.3456'), Decimal.parse('12.3456'));
      expect(parseAmountInput('0.05'), Decimal.parse('0.05'));
    });

    test('tolerates spaces and a lira sign', () {
      expect(parseAmountInput('  1.234,56 ₺ '), Decimal.parse('1234.56'));
    });

    test('keeps a minus sign', () {
      expect(parseAmountInput('-1.234,56'), Decimal.parse('-1234.56'));
    });

    test('returns null rather than guessing zero', () {
      // A form that read "abc" as 0 would silently open an account with no
      // money in it and tell the user nothing.
      for (final input in ['', '   ', 'abc', '12abc', '1,2,3', '1.2.3,4,5']) {
        expect(parseAmountInput(input), isNull, reason: input);
      }
    });

    test('what the app prints, the app can read back', () {
      // The round trip that matters: a figure shown on screen, retyped by the
      // user, must come back as the same number.
      for (final value in ['0', '0.05', '1234.56', '1234567.89', '-500.5']) {
        final decimal = fiat(value);
        expect(
          parseAmountInput(formatLira(decimal)),
          decimal,
          reason: formatLira(decimal),
        );
      }
    });
  });

  test('the stored form and the shown form stay different', () {
    // If these ever agree, one of them has been changed to match the other —
    // and whichever way round that happened, it is a defect: the stored form
    // is a wire contract with the desktop and the shown form is not.
    final value = money('2456.78');
    expect(formatWithThousands(value), '2,456.78');
    expect(formatLira(value), '2.456,78 ₺');
  });
}
