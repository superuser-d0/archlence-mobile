/// The single normalisation boundary for prices received outside the app.
library;

import 'package:decimal/decimal.dart';

import '../money/financial_decimal.dart';

/// Returns a finite, strictly positive [Decimal] price, or `null`.
///
/// A bad price must not abort the batch that contained it, so every failure
/// becomes `null`. Parsing deliberately remains in [decimalFrom]: duplicating
/// its conversion rules here would give external prices a second, drifting
/// definition of what a financial number is.
Decimal? finitePositivePrice(Object? value) {
  try {
    // Accept a String '1e400': it is a finite Decimal, unlike Python's
    // overflowing float; a JSON number at that magnitude is infinity and is
    // rejected by decimalFrom.
    // Do not copy Python's Unicode-aware string predicates here: Dart's
    // equivalents are not Unicode-aware, and Decimal.parse is the one parser.
    final price = decimalFrom(value);
    return price > Decimal.zero ? price : null;
  } catch (_) {
    return null;
  }
}
