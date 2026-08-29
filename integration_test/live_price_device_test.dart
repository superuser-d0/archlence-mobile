/// Whether the two keyless price providers answer THIS PHONE, over a real
/// connection, in the shape the parser reads.
///
/// Until this file existed, no socket had ever opened from this app. Every
/// other test drives the providers through the `HttpGet` seam and hands back
/// a recorded body — which is the right seam, and this is its blind spot: a
/// recording proves the parser and never that the response is still that
/// shape. It is also the blind spot that hid the missing INTERNET permission
/// for as long as it hid; see `docs/ROADMAP.md` -> "The permission a release
/// build did not have".
///
/// **A failure here is a question before it is a defect.** It asserts against
/// two servers this project does not own, from a device that may have no
/// connection. So every test below proves reachability FIRST and on its own,
/// because `fetchCoinGeckoUsdPrices` and `fetchFrankfurterTryRates` never
/// throw — by design, every failure becomes an absent key — and asking one of
/// them alone cannot tell a provider that changed shape from a phone that is
/// offline. Split in two, a red test says which.
///
/// Outside `flutter test` deliberately, like the rest of `integration_test/`.
///
/// Run: `flutter test integration_test/live_price_device_test.dart -d DEVICE`
library;

import 'dart:convert';

import 'package:archlence_mobile/services/price_providers.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Fetches [uri] and fails with a message that says "connection", not
  /// "defect" — the distinction the rest of each test depends on.
  Future<String> reach(Uri uri, String provider) async {
    try {
      return await httpGetDefault(uri);
    } on Object catch (error) {
      fail(
        '$provider was not reachable from this device: $error\n'
        'Nothing below this line has been tested. That is a connection or an '
        'outage rather than something wrong in this app — check the device '
        'has internet, then read the rest of this file again.',
      );
    }
  }

  testWidgets('CoinGecko answers, in the shape the parser reads', (
    tester,
  ) async {
    final uri = Uri.https('api.coingecko.com', '/api/v3/simple/price', {
      'ids': 'bitcoin',
      'vs_currencies': 'usd',
    });
    final body = await reach(uri, 'CoinGecko');
    expect(body, isNotEmpty);

    final prices = await fetchCoinGeckoUsdPrices(
      {'bitcoin'},
      get: httpGetDefault,
    );

    expect(
      prices.keys,
      contains('bitcoin'),
      reason:
          'CoinGecko was reachable and answered with $body, and '
          'fetchCoinGeckoUsdPrices read no price out of it. The response '
          'shape has moved away from what the parser expects.',
    );
    // A price, not merely a number: `finitePositivePrice` has already
    // rejected zero, infinity and NaN, so what is left to say is that
    // something real came back rather than a placeholder.
    expect(prices['bitcoin']! > Decimal.zero, isTrue);
  });

  testWidgets('Frankfurter answers, and the rate arrives inverted', (
    tester,
  ) async {
    final uri = Uri.https('api.frankfurter.dev', '/v1/latest', {
      'from': 'TRY',
      'to': 'USD',
    });
    final body = await reach(uri, 'Frankfurter');
    expect(body, isNotEmpty);

    final rates = await fetchFrankfurterTryRates({'USD'}, get: httpGetDefault);

    expect(
      rates.keys,
      contains('USD'),
      reason:
          'Frankfurter was reachable and answered with $body, and '
          'fetchFrankfurterTryRates read no rate out of it. The response '
          'shape has moved away from what the parser expects.',
    );

    // The direction, which is the part of this provider that is easy to get
    // backwards and impossible to notice: the endpoint answers TRY -> USD
    // (how much USD one lira buys, a number well under 1) and the app deals
    // in "how many lira is one unit" (a number well over 1). Asserting only
    // "positive" would pass just as happily on the un-inverted rate.
    final tryPerUsd = rates['USD']!;
    expect(
      tryPerUsd > Decimal.one,
      isTrue,
      reason:
          'One US dollar came back as $tryPerUsd lira. Under 1 means the '
          'rate was returned the way Frankfurter states it rather than the '
          'way the rest of the app reads it.',
    );

    // And that the inversion is of THIS response rather than of anything:
    // the raw rate multiplied back out has to land on 1 again.
    final raw = Decimal.parse(
      ((jsonDecode(body) as Map)['rates'] as Map)['USD'].toString(),
    );
    final roundTrip = (tryPerUsd * raw).toDouble();
    expect(roundTrip, closeTo(1.0, 0.0001));
  });
}
