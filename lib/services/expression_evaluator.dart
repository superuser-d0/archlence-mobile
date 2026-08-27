/// The plain calculator's expression evaluator.
///
/// A port of the desktop's `utils/calculator.py`, which parses with Python's
/// own `ast` module and walks a restricted set of nodes — so it executes no
/// code while still getting Python's precedence for free. Dart has no such
/// parser to borrow, so this is a small recursive-descent one, and the
/// borrowed grammar is where the care goes.
///
/// **Three places a hand-written parser gets Python wrong,** each with a
/// vector generated from `utils/calculator.py` itself:
///
///  * `**` binds TIGHTER than a unary minus on its left, so `-2**2` is -4 and
///    not 4. Its right operand may itself be unary, so `2**-2` is 0.25. And it
///    associates to the RIGHT, so `2**3**2` is 512 and not 64.
///  * `%` takes the sign of the DIVISOR in Python. Dart's `%` is always
///    non-negative and its `remainder` takes the sign of the dividend, so
///    neither operator can be used directly: `10 % -3` is -2 in Python, 1 with
///    Dart's `%`.
///  * Python's tokenizer accepts `.5`, `1.` and `1_000`.
///
/// **The refusals are the security-relevant half.** `__import__('os')` and
/// `open('x')` are refused because the only callables are the five named here
/// — not because of a blocklist, which is the wrong shape for this and the
/// reason the desktop walks an allowlist of AST nodes.
library;

import 'dart:math' as math;

import 'calculators.dart';

/// The longest expression accepted, matching the desktop.
const int _maxExpressionLength = 200;

/// The largest exponent, matching the desktop's own guard. Without it, a
/// pasted `2**100000000` hangs the app rather than answering.
const int _maxExponent = 100;

const Map<String, double Function(double)> _functions = {
  'sin': math.sin,
  'cos': math.cos,
  'tan': math.tan,
  'sqrt': math.sqrt,
  // `log` is base 10 here, as it is in the desktop, which maps it to
  // `math.log10`. Dart's `math.log` is natural, so this is NOT a rename.
  'log': _log10,
};

/// Base-10 logarithm, which Dart's `dart:math` does not provide.
///
/// `log(x) / ln10` is the obvious substitute and it is not the same function:
/// for an exact power of ten it lands an ULP low, so `log(1000)` comes out as
/// 2.9999999999999996 where the desktop's `math.log10` gives 3. A calculator
/// that answers 2,9999999999999996 to log(1000) is one nobody trusts again.
///
/// So the exact powers of ten are snapped back. The check is not "is it close
/// to an integer" — that would round `log(999.9999)` to 3 as well — it is
/// whether ten to that integer IS the input, which only an exact power of ten
/// satisfies.
double _log10(double value) {
  final approximate = math.log(value) / math.ln10;
  final rounded = approximate.roundToDouble();
  if (rounded.abs() <= 308 && math.pow(10, rounded) == value) return rounded;
  return approximate;
}

const Map<String, double> _constants = {'pi': math.pi, 'e': math.e};

/// Evaluates [expression], or throws [CalculatorError].
double evaluateExpression(String expression) {
  final text = expression.trim();
  if (text.isEmpty || text.length > _maxExpressionLength) {
    throw const CalculatorError(
      CalculatorErrorCode.invalidExpression,
      'The expression is empty or too long.',
    );
  }

  final parser = _Parser(text);
  final value = parser.parseExpression();
  parser.expectEnd();

  if (!value.isFinite) {
    // Covers a division by zero, which Python raises on and Dart quietly
    // turns into infinity.
    throw const CalculatorError(
      CalculatorErrorCode.invalidExpression,
      'The result is not finite.',
    );
  }
  return value;
}

CalculatorError _invalid(String detail) =>
    CalculatorError(CalculatorErrorCode.invalidExpression, detail);

class _Parser {
  _Parser(this._text);

  final String _text;
  int _at = 0;

  void _skipSpace() {
    while (_at < _text.length && _isSpace(_text.codeUnitAt(_at))) {
      _at++;
    }
  }

  static bool _isSpace(int unit) =>
      unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D;

  static bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

  static bool _isNameStart(int unit) =>
      (unit >= 0x61 && unit <= 0x7A) || (unit >= 0x41 && unit <= 0x5A);

  bool _take(String token) {
    _skipSpace();
    if (_text.startsWith(token, _at)) {
      _at += token.length;
      return true;
    }
    return false;
  }

  /// True when the next token is [token] and it is not the start of a longer
  /// operator — `*` must not match the `*` of `**`.
  bool _takeOperator(String token) {
    _skipSpace();
    if (!_text.startsWith(token, _at)) return false;
    if (token == '*' && _text.startsWith('**', _at)) return false;
    _at += token.length;
    return true;
  }

  void expectEnd() {
    _skipSpace();
    if (_at != _text.length) {
      throw _invalid('Unexpected input at $_at.');
    }
  }

  double parseExpression() {
    var value = _parseTerm();
    while (true) {
      if (_takeOperator('+')) {
        value += _parseTerm();
      } else if (_takeOperator('-')) {
        value -= _parseTerm();
      } else {
        return value;
      }
    }
  }

  double _parseTerm() {
    var value = _parseUnary();
    while (true) {
      if (_takeOperator('*')) {
        value *= _parseUnary();
      } else if (_takeOperator('/')) {
        value /= _parseUnary();
      } else if (_takeOperator('%')) {
        value = _pythonModulo(value, _parseUnary());
      } else {
        return value;
      }
    }
  }

  /// Python's `%`: the result takes the sign of the DIVISOR.
  static double _pythonModulo(double left, double right) {
    if (right == 0) return double.nan;
    return left - right * (left / right).floorToDouble();
  }

  double _parseUnary() {
    if (_takeOperator('-')) return -_parseUnary();
    if (_takeOperator('+')) return _parseUnary();
    return _parsePower();
  }

  double _parsePower() {
    final base = _parseAtom();
    if (!_take('**')) return base;
    // The right operand goes through `_parseUnary`, which makes `**`
    // right-associative and lets its exponent be negative.
    final exponent = _parseUnary();
    if (exponent.abs() > _maxExponent) {
      throw _invalid('The exponent is too large.');
    }
    return math.pow(base, exponent).toDouble();
  }

  double _parseAtom() {
    _skipSpace();
    if (_at >= _text.length) throw _invalid('The expression ends early.');

    if (_take('(')) {
      final value = parseExpression();
      if (!_take(')')) throw _invalid('A bracket was left open.');
      return value;
    }

    final unit = _text.codeUnitAt(_at);
    if (_isDigit(unit) || unit == 0x2E) return _parseNumber();
    if (_isNameStart(unit)) return _parseName();
    throw _invalid('Unexpected character at $_at.');
  }

  double _parseNumber() {
    final start = _at;
    final digits = StringBuffer();
    var seenDot = false;
    while (_at < _text.length) {
      final unit = _text.codeUnitAt(_at);
      if (_isDigit(unit)) {
        digits.writeCharCode(unit);
      } else if (unit == 0x2E && !seenDot) {
        seenDot = true;
        digits.writeCharCode(unit);
      } else if (unit == 0x5F) {
        // An underscore separator, which Python's tokenizer allows in a
        // numeric literal and simply ignores.
      } else {
        break;
      }
      _at++;
    }
    // `1.` and `.5` are both valid to Python and neither parses in Dart, so
    // the buffer is padded rather than handed over as written.
    var literal = digits.toString();
    if (literal.startsWith('.')) literal = '0$literal';
    if (literal.endsWith('.')) literal = '${literal}0';
    final value = double.tryParse(literal);
    if (value == null) throw _invalid('Bad number at $start.');
    return value;
  }

  double _parseName() {
    final start = _at;
    while (_at < _text.length && _isNameStart(_text.codeUnitAt(_at))) {
      _at++;
    }
    final name = _text.substring(start, _at);

    final constant = _constants[name];
    if (constant != null) return constant;

    final function = _functions[name];
    if (function == null) throw _invalid('Unknown name "$name".');
    if (!_take('(')) throw _invalid('"$name" needs an argument.');
    final argument = parseExpression();
    if (!_take(')')) throw _invalid('A bracket was left open.');
    return function(argument);
  }
}
