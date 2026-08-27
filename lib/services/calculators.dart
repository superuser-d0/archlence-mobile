/// The four calculators: a plain one, deposit interest, compound growth and a
/// loan.
///
/// A port of the arithmetic in the desktop's `mixins/calculator_mixin.py` and
/// `utils/calculator.py`. The mixin's methods read Kivy fields and write Kivy
/// labels; only the sums come across, and every one of them is checked against
/// vectors produced by CALLING those methods — see
/// `tool/emit_calculator_vectors.py`, which imports the mixin with its UI
/// stubbed rather than re-deriving the formulas.
///
/// **These compute in `double`, and that is deliberate in an app whose money
/// layer refuses binary floats.** The rule the money layer holds is about
/// RECORDED money: a balance, a transaction, a total that has to agree with
/// another app down to the kurus. Nothing here is recorded. These are
/// projections of a hypothetical — what a deposit would return, what an
/// instalment would be — and the desktop computes them in `float`. Matching
/// its answer is worth more than a precision the inputs never had, and every
/// result is quantized to fiat before it leaves this file.
///
/// **What did NOT come across:** the loan calculator's advanced mode. On the
/// desktop that adds arbitrary user-entered charges, a file fee, insurance,
/// longer terms for car and mortgage loans, and a PDF export. Those are a
/// screen's worth of their own and the PDF is a desktop affordance; the basic
/// mode — the one the desktop opens on — is here, including its 36-month cap.
library;

import 'dart:math' as math;

import 'package:decimal/decimal.dart';

import '../money/financial_decimal.dart';

/// Why a calculation was refused.
enum CalculatorErrorCode {
  /// A field was blank, or not a number at all.
  notANumber,

  /// The desktop's own guard: principal, rate and term must all be > 0.
  notPositive,

  /// Over the term the loan type allows.
  termTooLong,

  /// The expression could not be evaluated — bad syntax, an unknown name, a
  /// division by zero, or an exponent large enough to hang the app.
  invalidExpression,
}

class CalculatorError implements Exception {
  const CalculatorError(this.code, this.message);

  final CalculatorErrorCode code;

  /// Developer-facing English. What the user sees is chosen in
  /// `ui/error_messages.dart`, so a code survives translation.
  final String message;

  @override
  String toString() => 'CalculatorError($code): $message';
}

/// The longest term the desktop allows in the basic mode, in months.
const int loanMaxTermMonths = 36;

/// Turkey's two taxes on consumer loan interest, each 15% OF THE INTEREST.
///
/// Not of the principal, and not of the instalment: the desktop builds its
/// effective rate as `r * (1 + kkdf + bsmv)`, so a 3.29% monthly rate is
/// charged as 4.277%. A port that applied these to the payment instead would
/// be out by a factor and still look plausible.
const double loanKkdf = 0.15;
const double loanBsmv = 0.15;

/// Withholding tax on deposit interest — 5%, taken off the gross return.
const double depositWithholding = 0.05;

/// What a term deposit returns.
class InterestResult {
  const InterestResult({required this.netProfit, required this.total});

  /// The return after withholding.
  final Decimal netProfit;

  /// Principal plus [netProfit].
  final Decimal total;
}

/// What a deposit grows to, and how much of that was put in.
class CompoundResult {
  const CompoundResult({
    required this.invested,
    required this.profit,
    required this.amount,
  });

  /// Everything paid in: the principal plus every monthly contribution.
  final Decimal invested;

  /// [amount] minus [invested].
  final Decimal profit;

  final Decimal amount;
}

/// One month of a loan's amortisation.
class LoanScheduleRow {
  const LoanScheduleRow({
    required this.month,
    required this.instalment,
    required this.principalPart,
    required this.interestAndTax,
    required this.remaining,
  });

  final int month;
  final Decimal instalment;

  /// How much of the instalment came off the debt.
  final Decimal principalPart;

  /// The rest: interest plus KKDF plus BSMV.
  final Decimal interestAndTax;

  /// What is still owed after this month. Zero on the last row.
  final Decimal remaining;
}

class LoanResult {
  const LoanResult({
    required this.instalment,
    required this.totalRepayment,
    required this.schedule,
  });

  final Decimal instalment;
  final Decimal totalRepayment;
  final List<LoanScheduleRow> schedule;
}

/// Parses a user-typed number, accepting the comma a Turkish keyboard offers.
///
/// The desktop calls `float()` on the raw text and shows a toast on failure.
/// This does the same, plus the comma: a phone keyboard in Turkish puts `,`
/// under the thumb, and refusing `1234,56` because the desktop's `float()`
/// would have refused it copies a limitation rather than a decision.
double parseCalculatorNumber(String text) {
  final cleaned = text.trim().replaceAll(',', '.');
  final value = double.tryParse(cleaned);
  if (value == null || !value.isFinite) {
    throw const CalculatorError(
      CalculatorErrorCode.notANumber,
      'The field is empty or not a number.',
    );
  }
  return value;
}

void _requirePositive(List<double> values) {
  for (final value in values) {
    if (value <= 0) {
      throw const CalculatorError(
        CalculatorErrorCode.notPositive,
        'Principal, rate and term must all be greater than zero.',
      );
    }
  }
}

/// Simple deposit interest: `P * r * days / 36500`, less 5% withholding.
///
/// 36500 rather than 36000: the desktop counts a 365-day year, which is what
/// a Turkish bank quotes. [ratePercent] is a yearly percentage — 45 means 45%.
InterestResult calculateDepositInterest({
  required double principal,
  required double ratePercent,
  required int days,
}) {
  _requirePositive([principal, ratePercent, days.toDouble()]);

  final gross = principal * ratePercent * days / 36500;
  final net = gross * (1 - depositWithholding);
  return InterestResult(netProfit: fiat(net), total: fiat(principal + net));
}

/// Compound growth, with an optional monthly contribution.
///
/// The principal compounds ANNUALLY — `P * (1 + r)^years` — while the monthly
/// contributions compound at `r / 12` over `years * 12` months. That is two
/// different compounding frequencies in one answer, and it is the desktop's,
/// not a slip in this port: the two halves of its formula were written for
/// different questions and this reproduces what its users have been seeing.
CompoundResult calculateCompound({
  required double principal,
  required double ratePercent,
  required int years,
  double monthlyDeposit = 0,
}) {
  _requirePositive([principal, ratePercent, years.toDouble()]);

  final rate = ratePercent / 100;
  var amount = principal * math.pow(1 + rate, years);

  if (monthlyDeposit > 0) {
    final months = years * 12;
    final monthlyRate = rate / 12;
    amount +=
        monthlyDeposit * (math.pow(1 + monthlyRate, months) - 1) / monthlyRate;
  }

  final invested = principal + monthlyDeposit * years * 12;
  return CompoundResult(
    invested: fiat(invested),
    profit: fiat(amount - invested),
    amount: fiat(amount),
  );
}

/// A consumer loan on the annuity formula, with KKDF and BSMV.
///
/// [monthlyRatePercent] is the monthly rate a Turkish bank advertises — 3.29
/// means 3.29% a month. The taxes are added to it before the instalment is
/// worked out, so the rate that actually applies is 4.277%.
LoanResult calculateLoan({
  required double principal,
  required double monthlyRatePercent,
  required int months,
  int maxTermMonths = loanMaxTermMonths,
}) {
  _requirePositive([principal, monthlyRatePercent, months.toDouble()]);
  if (months > maxTermMonths) {
    throw CalculatorError(
      CalculatorErrorCode.termTooLong,
      'The term cannot exceed $maxTermMonths months.',
    );
  }

  final rate = monthlyRatePercent / 100;
  final taxed = rate * (1 + loanKkdf + loanBsmv);
  final growth = math.pow(1 + taxed, months);
  final instalment = principal * (taxed * growth) / (growth - 1);

  final schedule = <LoanScheduleRow>[];
  var remaining = principal;
  for (var month = 1; month <= months; month++) {
    final interest = remaining * rate;
    final kkdf = interest * loanKkdf;
    final bsmv = interest * loanBsmv;
    final principalPart = instalment - (interest + kkdf + bsmv);
    remaining -= principalPart;
    // The desktop's clamp, kept: floating-point drift otherwise leaves a few
    // kurus owing after the last payment, and a schedule that does not end at
    // zero reads as a bug in the loan rather than in the arithmetic.
    if (remaining < 0.01) remaining = 0;

    schedule.add(
      LoanScheduleRow(
        month: month,
        instalment: fiat(instalment),
        principalPart: fiat(principalPart),
        interestAndTax: fiat(interest + kkdf + bsmv),
        remaining: fiat(remaining),
      ),
    );
  }

  return LoanResult(
    instalment: fiat(instalment),
    totalRepayment: fiat(instalment * months),
    schedule: schedule,
  );
}
