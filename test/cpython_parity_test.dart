/// Differential test against the real desktop implementation.
///
/// `cpython_quantize_vectors.txt` was produced by running 12 000 values
/// through the Python app's own `quantize_financial`, deliberately dense in
/// amounts that land exactly on a half step — the only place where banker's
/// rounding differs from half-up, and so the only place a plausible-looking
/// port silently disagrees. Regenerate it by re-running that module if the
/// Python side ever changes.
library;

import 'dart:io';

import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quantizeFinancial matches CPython on every recorded vector', () {
    final lines = File('test/cpython_quantize_vectors.txt')
        .readAsLinesSync()
        .where((line) => line.isNotEmpty);

    final precisions = {
      for (final precision in FinancialPrecision.values)
        precision.name: precision,
    };

    var checked = 0;
    final mismatches = <String>[];

    for (final line in lines) {
      final parts = line.split('|');
      final input = parts[0];
      final precision = precisions[parts[1]]!;
      final expected = parts[2];

      final actual = quantizeFinancial(
        input,
        precision,
      ).toStringAsFixed(precision.scale);
      if (actual != expected) {
        mismatches.add('$input @ ${parts[1]}: py=$expected dart=$actual');
      }
      checked++;
    }

    expect(checked, 12000);
    expect(mismatches.take(10), isEmpty, reason: '${mismatches.length} total');
  });
}
