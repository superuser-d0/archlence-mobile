/// Every `DropdownButtonFormField` in `lib/` sets `isExpanded: true`.
///
/// **A dropdown button sizes to its selected item.** Without `isExpanded` the
/// button's row takes the item's intrinsic width, so a label that is wider
/// than the sheet does not ellipsize — it overflows, and an
/// `overflow: TextOverflow.ellipsis` on the item's `Text` does nothing at all,
/// because there is no width constraint for it to ellipsize against. The
/// labels here are account rows: a name AND a balance, in a sheet on a phone.
///
/// **Seven of the app's nine were missing it**, and two had it. That is the
/// shape worth recording: the fix already existed in this codebase, applied
/// twice where somebody hit the problem, and never turned into a rule. One of
/// the seven overflowed by 152 pixels at the DEFAULT font scale — the pay-debt
/// sheet, which has a widget test file of its own that walks it end to end.
///
/// It walked past this because `pumpScreen` lays out on 800x2400 at a device
/// pixel ratio of 1 — an 800dp-wide surface, which no phone is. The sheet
/// sweep lays out at 360dp and 320dp, and that is what found it. A rule that
/// reads the source finds the rest, including the two that do not overflow
/// today because their labels happen to be short.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every DropdownButtonFormField is expanded', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();

      for (final match in RegExp(
        r'DropdownButtonFormField<',
      ).allMatches(source)) {
        // Walk from the argument list's opening paren to its match, so the
        // nested `items:` list and its builders stay inside the block.
        var open = source.indexOf('(', match.end);
        if (open < 0) continue;
        var depth = 0;
        var i = open;
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

        if (source.substring(match.start, end).contains('isExpanded')) continue;

        final line =
            '\n'.allMatches(source.substring(0, match.start)).length + 1;
        offenders.add('${entity.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These dropdowns have no isExpanded, so the button sizes to its '
          'selected item and a long label overflows the sheet rather than '
          'ellipsizing.\n${offenders.join('\n')}',
    );
  });
}
