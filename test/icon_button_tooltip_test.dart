/// Every enabled `IconButton` in `lib/` carries a tooltip.
///
/// **A tooltip IS the semantic label on an `IconButton`.** Without one the
/// button is not merely unlabelled — it is absent from the semantics tree
/// altogether, which a screen reader cannot reach at all. That is not a
/// reading of the framework: the `+` beside "My Active Assets" was missing
/// from `uiautomator`'s dump of a RELEASE build on a device while every other
/// control on that screen was in it. Adding `tooltip:` put it there.
///
/// **Why a grep rather than a widget test.** `labeledTapTargetGuideline` is
/// the right check and this app already runs it, on every screen in
/// `accessibility_test.dart` and on every tab in `tab_sweep_test.dart` — and
/// it did NOT catch this one. A guideline reads the semantics tree, the
/// semantics tree holds what was laid out, and that button sits below where
/// either test lays the Assets tab out. The same blind spot that hid six
/// defects hides this class of them too, and a rule that reads the source
/// does not have it.
///
/// **Disabled buttons are exempt, and the exemption is the framework's.** An
/// `IconButton` with `onPressed: null` is not a tap target, the guideline
/// skips it, and a tooltip on something nobody can press describes an action
/// that cannot happen. `app_shell.dart`'s notifications bell is the one this
/// applies to.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every enabled IconButton has a tooltip', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();

      for (final match in RegExp(r'IconButton\(').allMatches(source)) {
        // Walk to the matching close paren so nested calls in the argument
        // list — an `onPressed` closure, an `Icon(...)` — stay inside the
        // block being examined rather than ending it early.
        var depth = 0;
        var i = match.end - 1;
        var end = -1;
        while (i < source.length) {
          if (source[i] == '(') depth++;
          if (source[i] == ')') {
            depth--;
            if (depth == 0) {
              end = i;
              break;
            }
          }
          i++;
        }
        if (end < 0) continue;

        final block = source.substring(match.start, end);
        if (block.contains('tooltip:')) continue;
        if (RegExp(r'onPressed:\s*null').hasMatch(block)) continue;

        final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
        offenders.add('${entity.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These IconButtons have no tooltip, which on an IconButton is the '
          'semantic label — a screen reader cannot reach them at all. Give '
          'each one a localised tooltip, or make it onPressed: null if it is '
          'not meant to be pressed yet.\n${offenders.join('\n')}',
    );
  });
}
