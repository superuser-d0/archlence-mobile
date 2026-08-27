/// Differential tests against the desktop's own main/extra bucketing.
///
/// Every expectation here is read out of `test/summary_vectors.txt`, which
/// `tool/emit_summary_vectors.py` produces by CALLING
/// `services/financial_summary_service.py`. Nothing in this file encodes
/// somebody's reading of that module.
library;

import 'dart:io';

import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:archlence_mobile/services/financial_summary.dart';
import 'package:archlence_mobile/services/transaction_service.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

class _SummaryVector {
  const _SummaryVector({
    required this.type,
    required this.importance,
    required this.amount,
    required this.mainIncome,
    required this.extraIncome,
    required this.essentialExpense,
    required this.extraExpense,
  });

  /// 'ALL' on the final line, which sums every case above it.
  final String type;
  final String importance;
  final String amount;
  final Decimal mainIncome;
  final Decimal extraIncome;
  final Decimal essentialExpense;
  final Decimal extraExpense;

  bool get isTotal => type == 'ALL';

  PeriodEntry get entry => PeriodEntry(
    amount: fiat(amount),
    type: type,
    category: 'irrelevant',
    transactionDate: '2026-08-27 10:00:00',
    importance: importance,
  );

  void expectMatches(FinancialSummary summary) {
    final where = isTotal ? 'ALL' : '$type / "$importance" / $amount';
    expect(summary.mainIncome, mainIncome, reason: 'main income, $where');
    expect(summary.extraIncome, extraIncome, reason: 'extra income, $where');
    expect(
      summary.essentialExpense,
      essentialExpense,
      reason: 'essential expense, $where',
    );
    expect(summary.extraExpense, extraExpense, reason: 'extra expense, $where');
  }
}

List<_SummaryVector> _readVectors() {
  return [
    for (final line in File('test/summary_vectors.txt').readAsLinesSync())
      if (line.isNotEmpty && !line.startsWith('#')) _parseVector(line),
  ];
}

_SummaryVector _parseVector(String line) {
  final parts = line.split('|');
  if (parts.length != 7) {
    throw FormatException('Malformed summary vector: $line');
  }
  return _SummaryVector(
    type: parts[0],
    importance: parts[1],
    amount: parts[2],
    // `fiat`, not `Decimal.parse`: the desktop prints an untouched bucket as
    // '0' and a filled one as '1000.00', and those must compare equal to what
    // the port quantizes. Parsing raw would make 0 != 0.00 in `expect`.
    mainIncome: fiat(parts[3]),
    extraIncome: fiat(parts[4]),
    essentialExpense: fiat(parts[5]),
    extraExpense: fiat(parts[6]),
  );
}

void main() {
  final vectors = _readVectors();
  final cases = [for (final v in vectors) if (!v.isTotal) v];
  final total = vectors.singleWhere((v) => v.isTotal);

  group('main/extra parity with the desktop', () {
    test('the fixture is present and covers both sides', () {
      expect(cases, isNotEmpty);
      expect(cases.any((v) => incomeTransactionTypes.contains(v.type)), isTrue);
      expect(
        cases.any((v) => expenseTransactionTypes.contains(v.type)),
        isTrue,
      );
      // A type that is neither, so the drop is actually exercised.
      expect(
        cases.any(
          (v) =>
              !incomeTransactionTypes.contains(v.type) &&
              !expenseTransactionTypes.contains(v.type),
        ),
        isTrue,
      );
    });

    test('each case alone lands where the desktop puts it', () {
      for (final vector in cases) {
        vector.expectMatches(summarizeTransactions([vector.entry]));
      }
    });

    test('all of them together sum as the desktop sums them', () {
      total.expectMatches(
        summarizeTransactions([for (final v in cases) v.entry]),
      );
    });
  });

  group('what the buckets derive', () {
    test('an empty period is empty rather than four zeroes with a chart', () {
      final summary = summarizeTransactions(const <PeriodEntry>[]);
      expect(summary.isEmpty, isTrue);
      expect(summary.net, Decimal.zero);
    });

    test('totals and net follow the four buckets', () {
      final summary = summarizeTransactions([
        for (final v in cases) v.entry,
      ]);
      expect(summary.totalIncome, fiat(total.mainIncome + total.extraIncome));
      expect(
        summary.totalExpense,
        fiat(total.essentialExpense + total.extraExpense),
      );
      expect(summary.net, fiat(summary.totalIncome - summary.totalExpense));
      expect(summary.isEmpty, isFalse);
    });

    test('net agrees with the income and expense the Assets tab already showed', () {
      // The tab summed `isIncome` and `isExpense` inline before this port. The
      // split must not change the two numbers that were already on screen.
      final entries = [for (final v in cases) v.entry];
      var income = Decimal.zero;
      var expense = Decimal.zero;
      for (final entry in entries) {
        if (entry.isIncome) income += entry.amount;
        if (entry.isExpense) expense += entry.amount;
      }
      final summary = summarizeTransactions(entries);
      expect(summary.totalIncome, fiat(income));
      expect(summary.totalExpense, fiat(expense));
    });
  });
}
