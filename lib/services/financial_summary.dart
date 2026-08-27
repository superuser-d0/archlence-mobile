/// The main/extra split of a period's ledger.
///
/// A port of the desktop's `services/financial_summary_service.py`. What it
/// adds over the plain income and expense totals the Assets tab already showed
/// is the answer to a different question: not how much came in and went out,
/// but how much of it the household had a CHOICE about. That distinction lives
/// in `categories.importance`, which until now this app read and never used.
///
/// **The mapping is not symmetric, and that is the desktop's, not a slip.**
/// An importance of 'main' files income under [mainIncome] and an expense
/// under [essentialExpense] — a salary is a main income, rent is an essential
/// expense, and the two words are not interchangeable. Everything else is
/// 'extra' on both sides.
///
/// **What is missing counts as 'extra', and what is neither side counts as
/// nothing.** A category with no row in `categories` arrives with a null
/// importance and is extra rather than an error; a transaction that is neither
/// income nor expense — a transfer — is dropped entirely rather than counted
/// as zero somewhere. Both are checked against vectors generated from the
/// desktop's own function; see `test/summary_vectors.txt`.
///
/// **The decryption rule is upstream of this file.** The desktop's version
/// decrypts each amount itself and refuses to return a partial result if one
/// row will not read. Here that has already happened:
/// [TransactionService.getTransactionsByPeriod] raises rather than skipping,
/// for the same reason — a slice quietly missing from a percentage is a wrong
/// picture presented as a right one. So this file sees plain [Decimal]s and
/// cannot fail.
library;

import 'package:decimal/decimal.dart';

import '../money/financial_decimal.dart';
import 'category_service.dart';
import 'transaction_service.dart';

/// The four buckets, quantized to fiat precision.
class FinancialSummary {
  FinancialSummary({
    required this.mainIncome,
    required this.extraIncome,
    required this.essentialExpense,
    required this.extraExpense,
  });

  /// Everything at zero — what an empty period summarises to.
  FinancialSummary.zero()
    : mainIncome = Decimal.zero,
      extraIncome = Decimal.zero,
      essentialExpense = Decimal.zero,
      extraExpense = Decimal.zero;

  /// Income from a category marked 'main': the salary, the regular one.
  final Decimal mainIncome;

  /// Income from anything else: a bonus, a side project, a one-off sale.
  final Decimal extraIncome;

  /// Expense on a category marked 'main': what the household must pay.
  final Decimal essentialExpense;

  /// Expense on anything else: what it chose to.
  final Decimal extraExpense;

  Decimal get totalIncome => fiat(mainIncome + extraIncome);

  Decimal get totalExpense => fiat(essentialExpense + extraExpense);

  Decimal get net => fiat(totalIncome - totalExpense);

  /// True when nothing at all was recorded, so a caller can say so rather than
  /// drawing four zeroes and a chart of nothing.
  bool get isEmpty =>
      mainIncome == Decimal.zero &&
      extraIncome == Decimal.zero &&
      essentialExpense == Decimal.zero &&
      extraExpense == Decimal.zero;
}

/// Buckets [entries] by side and importance.
FinancialSummary summarizeTransactions(Iterable<PeriodEntry> entries) {
  var mainIncome = Decimal.zero;
  var extraIncome = Decimal.zero;
  var essentialExpense = Decimal.zero;
  var extraExpense = Decimal.zero;

  for (final entry in entries) {
    // [mainImportance], not the literal 'essential': the word in the BUCKET
    // name on the expense side is not the word in the column. The doc comment
    // on [PeriodEntry.importance] claimed it was until this port was written.
    final isMain = entry.importance == mainImportance;
    if (entry.isIncome) {
      if (isMain) {
        mainIncome += entry.amount;
      } else {
        extraIncome += entry.amount;
      }
    } else if (entry.isExpense) {
      if (isMain) {
        essentialExpense += entry.amount;
      } else {
        extraExpense += entry.amount;
      }
    }
    // Neither side: dropped. A transfer is not income to be split.
  }

  return FinancialSummary(
    mainIncome: fiat(mainIncome),
    extraIncome: fiat(extraIncome),
    essentialExpense: fiat(essentialExpense),
    extraExpense: fiat(extraExpense),
  );
}
