/// The provider layer, driven entirely through the [HttpGet] seam — no
/// socket in this file opens. `fetchCoinGeckoUsdPrices` and
/// `fetchFrankfurterTryRates` are the boundary a hostile or merely broken
/// response has to cross, so most of what is tested here is what happens
/// when the network answers something other than a clean price.
library;

import 'dart:convert';

import 'package:archlence_mobile/services/price_providers.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands back [body] for any URI, or throws [error] if one was given —
/// standing in for a timeout, a DNS failure, or any other network exception.
HttpGet fixedResponse(String body, {Object? error}) {
  return (uri) async {
    if (error != null) throw error;
    return body;
  };
}

void main() {
  group('coinGeckoIdFor', () {
    test('matches a bare code', () {
      expect(coinGeckoIdFor('BTC'), 'bitcoin');
    });

    test('strips a quote suffix a restored desktop holding might carry', () {
      expect(coinGeckoIdFor('BTC-USD'), 'bitcoin');
      expect(coinGeckoIdFor('eth-usdt'), 'ethereum');
    });

    test('is null for a code this app has no id for', () {
      expect(coinGeckoIdFor('NOTACOIN'), isNull);
    });
  });

  group('fetchCoinGeckoUsdPrices', () {
    test('returns a Decimal for a clean response', () async {
      final prices = await fetchCoinGeckoUsdPrices(
        {'bitcoin', 'pax-gold'},
        get: fixedResponse(
          jsonEncode({
            'bitcoin': {'usd': 78402},
            'pax-gold': {'usd': 4612.05},
          }),
        ),
      );

      expect(prices['bitcoin'], Decimal.parse('78402'));
      expect(prices['pax-gold'], Decimal.parse('4612.05'));
    });

    test('never throws on a network failure — empty result instead', () async {
      final prices = await fetchCoinGeckoUsdPrices(
        {'bitcoin'},
        get: fixedResponse('', error: const SocketExceptionStub()),
      );
      expect(prices, isEmpty);
    });

    test('drops one bad id rather than the whole batch', () async {
      // 'bitcoin' is `1e400` — a syntactically valid JSON numeric literal
      // that overflows to `double.infinity` on the way in, exactly the
      // desktop's own historical defect — and 'pax-gold' is missing
      // outright. Both must be dropped without taking 'ethereum' with them.
      // `jsonEncode` cannot produce this body itself: `double.infinity` has
      // no JSON representation and encoding it throws, so the body is a
      // literal string instead — this is what a HOSTILE response looks like,
      // not what this app's own code would ever write.
      final prices = await fetchCoinGeckoUsdPrices(
        {'bitcoin', 'ethereum', 'pax-gold'},
        get: fixedResponse(
          '{"bitcoin": {"usd": 1e400}, "ethereum": {"usd": 3200}}',
        ),
      );

      expect(prices.containsKey('bitcoin'), isFalse);
      expect(prices.containsKey('pax-gold'), isFalse);
      expect(prices['ethereum'], Decimal.parse('3200'));
    });

    test('an empty request makes no call and returns empty', () async {
      var called = false;
      final prices = await fetchCoinGeckoUsdPrices(
        const {},
        get: (uri) async {
          called = true;
          return '{}';
        },
      );
      expect(called, isFalse);
      expect(prices, isEmpty);
    });

    for (final malformed in [
      'not json at all',
      '[]',
      '{"bitcoin": "not an object"}',
      '{"bitcoin": {"usd": "abc"}}',
      '{"bitcoin": {"usd": null}}',
      '{"bitcoin": {"usd": true}}',
      '',
    ]) {
      test('a malformed body (${jsonEncode(malformed)}) yields no prices, '
          'never an exception', () async {
        final prices = await fetchCoinGeckoUsdPrices(
          {'bitcoin'},
          get: fixedResponse(malformed),
        );
        expect(prices, isEmpty);
      });
    }
  });

  group('fetchFrankfurterTryRates', () {
    test('inverts TRY->X into TRY-per-unit', () async {
      // 1 TRY = 0.02079 USD, so 1 USD = 1/0.02079 TRY.
      final rates = await fetchFrankfurterTryRates(
        {'USD'},
        get: fixedResponse(
          jsonEncode({
            'amount': 1.0,
            'base': 'TRY',
            'date': '2026-08-25',
            'rates': {'USD': 0.02079},
          }),
        ),
      );

      final expected = (Decimal.one / Decimal.parse('0.02079')).toDecimal(
        scaleOnInfinitePrecision: 20,
      );
      expect(rates['USD'], expected);
      expect(rates['USD']!.toDouble(), closeTo(48.10, 0.01));
    });

    test('never throws on a network failure', () async {
      final rates = await fetchFrankfurterTryRates(
        {'USD'},
        get: fixedResponse('', error: const SocketExceptionStub()),
      );
      expect(rates, isEmpty);
    });

    test('a zero rate cannot divide by zero — it is dropped', () async {
      // finitePositivePrice already refuses zero, so the inversion never
      // runs on it; this pins that the whole path stays exception-free.
      final rates = await fetchFrankfurterTryRates(
        {'USD'},
        get: fixedResponse(
          jsonEncode({
            'rates': {'USD': 0},
          }),
        ),
      );
      expect(rates, isEmpty);
    });

    test('a missing "rates" object yields nothing, not a crash', () async {
      final rates = await fetchFrankfurterTryRates(
        {'USD'},
        get: fixedResponse(jsonEncode({'amount': 1.0})),
      );
      expect(rates, isEmpty);
    });

    test('an empty request makes no call and returns empty', () async {
      var called = false;
      final rates = await fetchFrankfurterTryRates(
        const {},
        get: (uri) async {
          called = true;
          return '{}';
        },
      );
      expect(called, isFalse);
      expect(rates, isEmpty);
    });
  });
}

/// Stands in for the kind of error a real socket failure raises, without
/// depending on `dart:io`'s concrete exception types.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'SocketExceptionStub';
}
