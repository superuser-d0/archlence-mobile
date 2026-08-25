/// Shared Decimal boundaries and explicit financial rounding rules.
///
/// A direct port of the desktop app's `utils/financial_decimal.py`. The two
/// must agree digit for digit: the same account opened on desktop and on the
/// phone has to show the same balance, so any divergence here is a defect
/// even when both answers look plausible.
library;

import 'package:decimal/decimal.dart';

/// Raised instead of returning a fallback. A financial value that cannot be
/// read is never quietly treated as zero — showing no total is safer than
/// showing a false one.
class FinancialValueError implements Exception {
  const FinancialValueError(this.message);

  final String message;

  @override
  String toString() => 'FinancialValueError: $message';
}

/// How many fractional digits each kind of financial figure keeps.
///
/// Values mirror `FinancialPrecision` in the Python module. They are held as
/// digit counts rather than as step sizes ("0.01") because Dart's rounding
/// works on a scale, but they denote exactly the same steps.
enum FinancialPrecision {
  fiat(2),
  preciousMetalQuantity(4),
  equityQuantity(6),
  cryptoQuantity(8),
  percent(2),
  unitPrice(8);

  const FinancialPrecision(this.scale);

  /// Fractional digit count.
  final int scale;
}

final Decimal _one = Decimal.one;
final Decimal _half = Decimal.parse('0.5');
final BigInt _two = BigInt.two;

/// Returns a finite [Decimal] without importing binary-float artefacts.
///
/// Everything is routed through its text form, exactly as the Python side
/// does with `Decimal(str(value))`: parsing the shortest representation of
/// `0.1` yields one tenth, while reading the double's actual bits would give
/// 0.1000000000000000055511151231257827.
Decimal decimalFrom(Object? value) {
  if (value == null) {
    throw const FinancialValueError('Financial value is not numeric.');
  }
  if (value is bool) {
    throw const FinancialValueError('Boolean is not a financial number.');
  }
  if (value is Decimal) return value;

  if (value is double && (value.isNaN || value.isInfinite)) {
    throw const FinancialValueError('Financial value must be finite.');
  }

  try {
    return Decimal.parse(value.toString());
  } on FormatException {
    // Covers 'NaN', 'Infinity', '-Infinity' and any other non-numeric text.
    throw const FinancialValueError('Financial value is not numeric.');
  }
}

/// Rounds [value] to [precision] using banker's rounding.
///
/// The `decimal` package offers only truncate/floor/ceil/half-up, so half-even
/// is implemented here. Half-up would disagree with the desktop app on every
/// amount that lands exactly on a half step — 1.005 would become 1.01 instead
/// of 1.00 — and those disagreements accumulate across a ledger.
Decimal quantizeFinancial(
  Object? value, [
  FinancialPrecision precision = FinancialPrecision.fiat,
]) {
  final decimal = decimalFrom(value);
  final scale = precision.scale;

  final truncated = decimal.truncate(scale: scale);
  final remainder = (decimal - truncated).abs();
  final step = _one.shift(-scale);
  final halfStep = _half.shift(-scale);

  if (remainder < halfStep) return truncated;

  final awayFromZero = decimal.sign >= 0 ? truncated + step : truncated - step;
  if (remainder > halfStep) return awayFromZero;

  // Exactly halfway: keep whichever neighbour ends in an even digit.
  final significand = truncated.shift(scale).toBigInt();
  return significand % _two == BigInt.zero ? truncated : awayFromZero;
}

/// A currency amount: two fractional digits.
Decimal fiat(Object? value) =>
    quantizeFinancial(value, FinancialPrecision.fiat);

/// A percentage. Shares [FinancialPrecision.fiat]'s precision by design, so
/// that a rate and the amount it produces round the same way.
Decimal percentage(Object? value) =>
    quantizeFinancial(value, FinancialPrecision.percent);

/// A holding size, at the precision its asset class trades in.
///
/// The accepted spellings include the Turkish ones the desktop database
/// already stores, so a restored backup keeps its precision.
Decimal quantity(Object? value, String? assetType) {
  final kind = (assetType ?? '').trim().toLowerCase();
  final precision = switch (kind) {
    'altın' ||
    'altin' ||
    'gold' ||
    'precious_metal' ||
    'precious metal' => FinancialPrecision.preciousMetalQuantity,
    'hisse' || 'stock' || 'equity' => FinancialPrecision.equityQuantity,
    'kripto' ||
    'crypto' ||
    'cryptocurrency' => FinancialPrecision.cryptoQuantity,
    _ => FinancialPrecision.unitPrice,
  };
  return quantizeFinancial(value, precision);
}
