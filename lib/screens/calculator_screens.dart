/// The four calculator screens behind the Tools grid.
///
/// One file, because three of them are the same screen with different fields:
/// a form, a Calculate button, and a result card that appears once there is
/// something to show. Splitting that into three files would triple the
/// scaffolding and leave one copy to drift.
///
/// **Every one of them says it changes nothing.** These are the only screens
/// in the app that show money figures which are NOT the user's money — a
/// projection of a deposit that does not exist, an instalment on a loan nobody
/// has taken. Everywhere else a figure on screen is a record. The note at the
/// bottom of each screen is what keeps that distinction visible.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/calculators.dart';
import '../services/expression_evaluator.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/error_messages.dart';
import '../ui/money_format.dart';
import '../widgets/surfaces.dart';

/// One labelled figure in a result card.
typedef _Line = (String label, String value);

/// The shape all three financial calculators share.
class _CalculatorScaffold extends StatelessWidget {
  const _CalculatorScaffold({
    required this.title,
    required this.fields,
    required this.onCalculate,
    required this.result,
    required this.error,
    this.footnote,
    this.extra,
  });

  final String title;
  final List<Widget> fields;
  final VoidCallback onCalculate;

  /// The figures, or null before the first calculation.
  final List<_Line>? result;

  /// What went wrong, or null.
  final String? error;

  /// A sentence under the result explaining a tax or a deduction.
  final String? footnote;

  /// Anything after the result card — the loan's schedule.
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Spacing.containerMargin,
          Spacing.stackMd,
          Spacing.containerMargin,
          MediaQuery.paddingOf(context).bottom + Spacing.stackLg,
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(Spacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in fields) ...[
                  field,
                  const SizedBox(height: Spacing.stackSm),
                ],
                const SizedBox(height: 4),
                GradientButton(
                  label: l10n.calcCalculate,
                  onPressed: onCalculate,
                ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: Spacing.stackMd),
            AppCard(
              padding: const EdgeInsets.all(Spacing.gutter),
              child: Text(
                error!,
                style: text.bodyMedium?.copyWith(color: ObsidianPalette.error),
              ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: Spacing.stackMd),
            AppCard(
              padding: const EdgeInsets.all(Spacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (label, value) in result!) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: text.bodySmall?.copyWith(
                            color: ObsidianPalette.onSurfaceVariant,
                          ),
                        ),
                        Text(value, style: text.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (footnote != null)
                    Text(
                      footnote!,
                      style: text.bodySmall?.copyWith(
                        color: ObsidianPalette.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (extra != null) ...[
            const SizedBox(height: Spacing.stackMd),
            extra!,
          ],
          const SizedBox(height: Spacing.stackMd),
          Text(
            l10n.calcProjectionNote,
            style: text.bodySmall?.copyWith(
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A number field, keyboard set for money.
class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      // `decimal: true` so the comma key is there: the parser accepts it, and
      // a Turkish keyboard offers a comma where the desktop's `float()` wanted
      // a dot.
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}

// ---------------------------------------------------------------------------

class InterestCalculatorScreen extends StatefulWidget {
  const InterestCalculatorScreen({super.key});

  @override
  State<InterestCalculatorScreen> createState() =>
      _InterestCalculatorScreenState();
}

class _InterestCalculatorScreenState extends State<InterestCalculatorScreen> {
  final _principal = TextEditingController();
  final _rate = TextEditingController();
  final _days = TextEditingController();

  InterestResult? _result;
  String? _error;

  @override
  void dispose() {
    _principal.dispose();
    _rate.dispose();
    _days.dispose();
    super.dispose();
  }

  void _calculate() {
    final l10n = context.l10n;
    try {
      final result = calculateDepositInterest(
        principal: parseCalculatorNumber(_principal.text),
        ratePercent: parseCalculatorNumber(_rate.text),
        days: parseCalculatorNumber(_days.text).round(),
      );
      setState(() {
        _result = result;
        _error = null;
      });
    } on CalculatorError catch (error) {
      // The result is CLEARED, not left standing. A figure from the previous
      // inputs sitting under a fresh error reads as the answer to what was
      // just typed.
      setState(() {
        _result = null;
        _error = calculatorErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = _result;

    return _CalculatorScaffold(
      title: l10n.calcInterestTitle,
      fields: [
        _NumberField(controller: _principal, label: l10n.calcPrincipal),
        _NumberField(controller: _rate, label: l10n.calcAnnualRate),
        _NumberField(controller: _days, label: l10n.calcDays),
      ],
      onCalculate: _calculate,
      error: _error,
      footnote: result == null ? null : l10n.calcWithholdingNote,
      result: result == null
          ? null
          : [
              (l10n.calcNetReturn, formatLira(result.netProfit)),
              (l10n.calcAtMaturity, formatLira(result.total)),
            ],
    );
  }
}

// ---------------------------------------------------------------------------

class CompoundCalculatorScreen extends StatefulWidget {
  const CompoundCalculatorScreen({super.key});

  @override
  State<CompoundCalculatorScreen> createState() =>
      _CompoundCalculatorScreenState();
}

class _CompoundCalculatorScreenState extends State<CompoundCalculatorScreen> {
  final _principal = TextEditingController();
  final _rate = TextEditingController();
  final _years = TextEditingController();
  final _deposit = TextEditingController();

  CompoundResult? _result;
  String? _error;

  @override
  void dispose() {
    _principal.dispose();
    _rate.dispose();
    _years.dispose();
    _deposit.dispose();
    super.dispose();
  }

  void _calculate() {
    final l10n = context.l10n;
    try {
      final result = calculateCompound(
        principal: parseCalculatorNumber(_principal.text),
        ratePercent: parseCalculatorNumber(_rate.text),
        years: parseCalculatorNumber(_years.text).round(),
        // Blank is zero, not an error: the desktop treats the contribution as
        // optional and so does the label on the field.
        monthlyDeposit: _deposit.text.trim().isEmpty
            ? 0
            : parseCalculatorNumber(_deposit.text),
      );
      setState(() {
        _result = result;
        _error = null;
      });
    } on CalculatorError catch (error) {
      setState(() {
        _result = null;
        _error = calculatorErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = _result;

    return _CalculatorScaffold(
      title: l10n.calcCompoundTitle,
      fields: [
        _NumberField(controller: _principal, label: l10n.calcPrincipal),
        _NumberField(controller: _rate, label: l10n.calcAnnualRate),
        _NumberField(controller: _years, label: l10n.calcYears),
        _NumberField(controller: _deposit, label: l10n.calcMonthlyDeposit),
      ],
      onCalculate: _calculate,
      error: _error,
      result: result == null
          ? null
          : [
              (l10n.calcInvested, formatLira(result.invested)),
              (l10n.calcGain, formatLira(result.profit)),
              (l10n.calcTotal, formatLira(result.amount)),
            ],
    );
  }
}

// ---------------------------------------------------------------------------

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _amount = TextEditingController();
  final _rate = TextEditingController();
  final _term = TextEditingController();

  LoanResult? _result;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    _term.dispose();
    super.dispose();
  }

  void _calculate() {
    final l10n = context.l10n;
    try {
      final result = calculateLoan(
        principal: parseCalculatorNumber(_amount.text),
        monthlyRatePercent: parseCalculatorNumber(_rate.text),
        months: parseCalculatorNumber(_term.text).round(),
      );
      setState(() {
        _result = result;
        _error = null;
      });
    } on CalculatorError catch (error) {
      setState(() {
        _result = null;
        _error = calculatorErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = _result;

    return _CalculatorScaffold(
      title: l10n.calcLoanTitle,
      fields: [
        _NumberField(controller: _amount, label: l10n.calcLoanAmount),
        _NumberField(controller: _rate, label: l10n.calcMonthlyRate),
        _NumberField(controller: _term, label: l10n.calcTermMonths),
      ],
      onCalculate: _calculate,
      error: _error,
      footnote: result == null ? null : l10n.calcTaxNote,
      result: result == null
          ? null
          : [
              (l10n.calcInstalment, formatLira(result.instalment)),
              (l10n.calcTotalRepayment, formatLira(result.totalRepayment)),
            ],
      extra: result == null ? null : _Schedule(rows: result.schedule),
    );
  }
}

/// The amortisation table.
///
/// Scrolls horizontally rather than shrinking the type: four money columns do
/// not fit a phone at a readable size, and a table nobody can read is worse
/// than one they have to push sideways.
class _Schedule extends StatelessWidget {
  const _Schedule({required this.rows});

  final List<LoanScheduleRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(Spacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.calcSchedule, style: text.titleMedium),
          const SizedBox(height: Spacing.stackSm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowHeight: 34,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 38,
              columns: [
                DataColumn(label: Text(l10n.calcScheduleMonth)),
                DataColumn(label: Text(l10n.calcInstalment)),
                DataColumn(label: Text(l10n.calcSchedulePrincipal)),
                DataColumn(label: Text(l10n.calcScheduleInterest)),
                DataColumn(label: Text(l10n.calcScheduleRemaining)),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      DataCell(Text('${row.month}')),
                      DataCell(Text(formatLira(row.instalment))),
                      DataCell(Text(formatLira(row.principalPart))),
                      DataCell(Text(formatLira(row.interestAndTax))),
                      DataCell(Text(formatLira(row.remaining))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The plain calculator: a display and a keypad.
///
/// **The keypad, not the phone keyboard.** `sqrt(` and `**` are not reachable
/// from a numeric keyboard, and a calculator that needs the user to switch to
/// letters to take a square root is one they close.
class BasicCalculatorScreen extends StatefulWidget {
  const BasicCalculatorScreen({super.key});

  @override
  State<BasicCalculatorScreen> createState() => _BasicCalculatorScreenState();
}

class _BasicCalculatorScreenState extends State<BasicCalculatorScreen> {
  String _expression = '';
  String? _answer;
  String? _error;

  void _append(String token) {
    setState(() {
      _expression += token;
      _answer = null;
      _error = null;
    });
  }

  void _clear() {
    setState(() {
      _expression = '';
      _answer = null;
      _error = null;
    });
  }

  void _backspace() {
    if (_expression.isEmpty) return;
    setState(() {
      _expression = _expression.substring(0, _expression.length - 1);
      _answer = null;
      _error = null;
    });
  }

  void _evaluate() {
    final l10n = context.l10n;
    try {
      final value = evaluateExpression(_expression);
      setState(() {
        // Printed the way Dart prints a double, not through the money
        // formatter: this is a calculator, and rounding 1/3 to two decimals
        // would be answering a different question.
        _answer = value == value.roundToDouble() && value.abs() < 1e15
            ? value.toInt().toString()
            : value.toString();
        _error = null;
      });
    } on CalculatorError catch (error) {
      setState(() {
        _answer = null;
        _error = calculatorErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calcBasicTitle)),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          Spacing.containerMargin,
          Spacing.stackMd,
          Spacing.containerMargin,
          MediaQuery.paddingOf(context).bottom + Spacing.stackMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(Spacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _expression.isEmpty ? '0' : _expression,
                    key: const Key('calc-expression'),
                    textAlign: TextAlign.end,
                    style: text.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _error ?? _answer ?? '',
                    key: const Key('calc-answer'),
                    textAlign: TextAlign.end,
                    style: text.headlineMedium?.copyWith(
                      color: _error != null
                          ? ObsidianPalette.error
                          : ObsidianPalette.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.stackMd),
            Expanded(
              child: _Keypad(onKey: _handleKey, l10n: l10n),
            ),
          ],
        ),
      ),
    );
  }

  void _handleKey(String key) => switch (key) {
    'C' => _clear(),
    '<' => _backspace(),
    '=' => _evaluate(),
    _ => _append(key),
  };
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey, required this.l10n});

  final void Function(String) onKey;
  final AppLocalizations l10n;

  /// What each button inserts. The label and the token differ where the token
  /// is not typeable — `√` inserts `sqrt(`.
  ///
  /// **The digits keep their calculator arrangement**: 7-8-9 over 4-5-6 over
  /// 1-2-3, in the first three columns, with the operators to their right. The
  /// first version of this pad simply filled a 5x5 grid in order and produced
  /// a row reading `4 5 6 1 2` — every test passed, and it was obvious the
  /// second it was opened on a phone.
  static const List<List<(String, String)>> _rows = [
    [('√', 'sqrt('), ('log', 'log('), ('π', 'pi'), ('^', '**'), ('%', '%')],
    [('C', 'C'), ('(', '('), (')', ')'), ('⌫', '<'), ('÷', '/')],
    [('7', '7'), ('8', '8'), ('9', '9'), ('×', '*'), ('−', '-')],
    [('4', '4'), ('5', '5'), ('6', '6'), ('+', '+'), ('=', '=')],
    [('1', '1'), ('2', '2'), ('3', '3'), ('0', '0'), ('.', '.')],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _rows)
          Expanded(
            child: Row(
              children: [
                for (final (label, token) in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _Key(label: label, onTap: () => onKey(token)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final emphasised = label == '=' || label == 'C';
    return Material(
      color: emphasised
          ? ObsidianPalette.primary.withValues(alpha: 0.16)
          : ObsidianPalette.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        // Keyed so a test can reach THIS key rather than any InkWell that
        // happens to sit above a matching label — the display shows '0' when
        // the expression is empty, which collides with the zero key.
        key: ValueKey('calc-key-$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: emphasised
                  ? ObsidianPalette.primary
                  : ObsidianPalette.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
