/// `setState` must never be handed a callback that returns a Future.
///
/// `setState(() => _data = _load())` reads as an assignment and is not one:
/// the arrow body RETURNS the assignment's value, so when the right-hand side
/// is async the callback returns a `Future`. Flutter asserts on that, the
/// assertion is swallowed by whatever is running, and — the part that makes
/// it expensive — THE STATE IS NEVER UPDATED. The screen simply does not
/// change, with nothing in the log to say why.
///
/// It has been walked into three times here: two screens when the data layer
/// was first wired, and the settings screen's lock switch, which saved the
/// preference correctly and sprang straight back. Twice it was found by a
/// widget test failing for a reason that looked unrelated.
///
/// A grep is not elegant, but the analyzer has no rule for it and the
/// alternative is finding it a fourth time.
///
/// The rule has NO exception for a call that happens to be synchronous. Text
/// cannot tell `_load()` from `value.round()`, and a rule with a judgement
/// call in it is a rule that gets argued with. A block body costs two lines
/// and removes the question.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no setState callback assigns the result of a call', () {
    final offenders = <String>[];
    // An arrow-bodied setState whose assignment ends in a call: the shape
    // that can return a Future. A plain `setState(() => _tab = index)` is
    // fine and stays.
    final pattern = RegExp(r'setState\(\(\)\s*=>\s*\w+\s*=\s*[\w.]+\(');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        // A comment describing the trap is not the trap.
        if (line.startsWith('//') || line.startsWith('///')) continue;
        if (pattern.hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}: $line');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Use a block body: setState(() { x = f(); }).',
    );
  });
}
