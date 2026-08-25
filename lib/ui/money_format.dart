/// Turkish presentation formatting for money, percentages and dates.
///
/// PRESENTATION ONLY. `formatWithThousands` in `asset_service.dart` looks
/// similar and is NOT the same thing: that one produces the Western
/// `1,234.56` that goes INTO a stored `transactions.description`, where it has
/// to match what the desktop writes byte for byte. These functions produce
/// what a screen shows. Unifying the two would silently change stored data.
///
/// Numbers are Turkish (`1.234,56 ₺`, `%12,5`) while the labels around them
/// are still English — the app has no i18n layer yet, and the number format is
/// not a translation but the one the design specifies and the desktop stores.
library;

import 'package:decimal/decimal.dart';

import '../money/financial_decimal.dart';

/// `1.234.567,89 ₺`, or `-1.234,56 ₺` when negative.
String formatLira(Decimal value) => '${_groupedTurkish(fiat(value))} ₺';

/// The same, with an explicit `+` in front of a gain.
///
/// For deltas, where "1.250,00" and "+1.250,00" mean different things to a
/// reader scanning a column of changes.
String formatSignedLira(Decimal value) {
  final quantized = fiat(value);
  final sign = quantized > Decimal.zero ? '+' : '';
  return '$sign${_groupedTurkish(quantized)} ₺';
}

/// `%12,5` — Turkish writes the symbol before the number, so a minus sign
/// goes before both: `-%6,2`.
String formatPercent(Decimal value, {bool signed = false}) {
  final quantized = percentage(value);
  final digits = _decimalDigits(
    quantized.abs(),
    FinancialPrecision.percent.scale,
    trimTrailingZeros: true,
  ).replaceFirst('.', ',');

  final String sign;
  if (quantized < Decimal.zero) {
    sign = '-';
  } else if (signed && quantized > Decimal.zero) {
    sign = '+';
  } else {
    sign = '';
  }
  return '$sign%$digits';
}

/// A stored `YYYY-MM-DD...` stamp as `DD.MM.YYYY`, or '' if unreadable.
String formatStoredDate(String? stamp) {
  if (stamp == null || stamp.length < 10) return '';
  return '${stamp.substring(8, 10)}.${stamp.substring(5, 7)}.'
      '${stamp.substring(0, 4)}';
}

/// A stored stamp as `DD.MM` — for a dense statement column where the year is
/// the same on every row.
String formatStoredDayMonth(String? stamp) {
  if (stamp == null || stamp.length < 10) return '';
  return '${stamp.substring(8, 10)}.${stamp.substring(5, 7)}';
}

String _groupedTurkish(Decimal value) {
  final negative = value.sign < 0;
  final text = _decimalDigits(value.abs(), FinancialPrecision.fiat.scale);
  final parts = text.split('.');
  final whole = parts[0];
  final fraction = parts.length > 1 ? parts[1] : '';

  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write('.');
    grouped.write(whole[i]);
  }
  return '${negative ? '-' : ''}$grouped,$fraction';
}

/// [value] as plain digits with exactly [scale] fractional places.
///
/// `Decimal.toString()` drops trailing zeros — 100 prints as "100", not
/// "100.00" — so the fraction is rebuilt from the shifted integer rather than
/// read off the text.
String _decimalDigits(
  Decimal value,
  int scale, {
  bool trimTrailingZeros = false,
}) {
  final shifted = value.shift(scale).toBigInt();
  final divisor = BigInt.from(10).pow(scale);
  final whole = (shifted ~/ divisor).toString();
  var fraction = (shifted % divisor).toString().padLeft(scale, '0');
  if (trimTrailingZeros) {
    fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    if (fraction.isEmpty) return whole;
  }
  return '$whole.$fraction';
}
