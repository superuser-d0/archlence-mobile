/// `priceCacheLifetime` against the desktop's own `get_ttl_minutes`.
///
/// The vectors in `price_ttl_vectors.txt` are OUTPUT of
/// `services/price_service.get_ttl_minutes`, written by
/// `tool/emit_price_ttl_vectors.py`. Nothing here states what the answer
/// should be: every expectation was produced by the function this one is a
/// port of, which is the rule the rest of the parity fixtures follow.
///
/// The cases cover every asset spelling the mobile side can be handed, both
/// sides of each market edge to the minute, and both weekend days.
library;

import 'dart:io';

import 'package:archlence_mobile/services/price_ttl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final vectors = File('test/price_ttl_vectors.txt')
      .readAsLinesSync()
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList();

  test('the fixture is actually there', () {
    // A parity test whose file went missing passes vacuously; this is the
    // same guard `cpython_parity_test.dart` keeps for the same reason.
    expect(vectors, hasLength(greaterThan(100)));
  });

  test('every desktop TTL vector reproduces', () {
    for (final line in vectors) {
      final parts = line.split('|');
      expect(parts, hasLength(3), reason: 'malformed vector: $line');
      final assetType = parts[0];
      final moment = DateTime.parse(parts[1]);
      final expected = parts[2];

      final lifetime = priceCacheLifetime(assetType, moment);

      if (expected == 'inf') {
        expect(
          lifetime,
          isNull,
          reason: 'closed market should have no lifetime: $line',
        );
      } else {
        // The desktop writes minutes as a float ('3' or '3.0'); compare on
        // the number rather than on how it was rendered.
        final minutes = double.parse(expected);
        expect(lifetime, isNotNull, reason: 'expected $minutes minutes: $line');
        expect(
          lifetime!.inMinutes,
          minutes.round(),
          reason: 'wrong lifetime: $line',
        );
      }
    }
  });

  group('priceStillFresh', () {
    final now = DateTime.parse('2026-09-02T13:00:00+03:00');

    test('a crypto row inside three minutes is not refetched', () {
      expect(
        priceStillFresh(
          assetType: 'Kripto',
          updatedAt: now.subtract(const Duration(minutes: 2, seconds: 59)),
          now: now,
        ),
        isTrue,
      );
    });

    test('and one past it is', () {
      expect(
        priceStillFresh(
          assetType: 'Kripto',
          updatedAt: now.subtract(const Duration(minutes: 3, seconds: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a share out of hours stays fresh however old it is', () {
      // The point of the infinite branch: the market is shut, so a row from
      // last night is still the current price and asking again is waste.
      final saturday = DateTime.parse('2026-09-05T13:00:00+03:00');
      expect(
        priceStillFresh(
          assetType: 'Hisse',
          updatedAt: saturday.subtract(const Duration(days: 3)),
          now: saturday,
        ),
        isTrue,
      );
    });

    test('the same share inside market hours does expire', () {
      expect(
        priceStillFresh(
          assetType: 'Hisse',
          updatedAt: now.subtract(const Duration(minutes: 6)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a row from the future is refetched rather than trusted', () {
      // A device clock that moved must not pin a figure indefinitely. This
      // is the opposite of what `priceAge` does with a negative duration,
      // and the difference is deliberate: that one decides what to SAY, this
      // one decides whether to ASK.
      expect(
        priceStillFresh(
          assetType: 'Kripto',
          updatedAt: now.add(const Duration(hours: 1)),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
