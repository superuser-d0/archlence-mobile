/// The composition layer: classify each holding, fetch what live prices it
/// needs, write what it learned to `asset_price_cache`, and fall back to
/// that same cache for whatever the live fetch could not reach.
///
/// No socket opens anywhere in this file — every network call goes through
/// a fake [HttpGet] that answers from a fixed map of canned responses, the
/// same seam `price_providers_test.dart` drives directly.
library;

import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/services/asset_service.dart';
import 'package:archlence_mobile/services/live_price_service.dart';
import 'package:archlence_mobile/services/price_providers.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

/// A canned response keyed by which host it answers for, and a call counter
/// so a test can assert how many round trips actually happened — the
/// dedup behind fetching one CoinGecko id or one Frankfurter code once no
/// matter how many holdings share it.
class FakeProviders {
  FakeProviders({this.coinGeckoBody, this.frankfurterBody});

  String? coinGeckoBody;
  String? frankfurterBody;
  int coinGeckoCalls = 0;
  int frankfurterCalls = 0;
  final List<Uri> requested = [];

  Future<String> get(Uri uri) async {
    requested.add(uri);
    if (uri.host == 'api.coingecko.com') {
      coinGeckoCalls++;
      if (coinGeckoBody == null) throw const _NetworkFailure();
      return coinGeckoBody!;
    }
    if (uri.host == 'api.frankfurter.dev') {
      frankfurterCalls++;
      if (frankfurterBody == null) throw const _NetworkFailure();
      return frankfurterBody!;
    }
    throw StateError('unexpected host: ${uri.host}');
  }
}

class _NetworkFailure implements Exception {
  const _NetworkFailure();
}

/// Reasonable canned bodies, reused across tests. PAXG/USDT figures are the
/// ones measured live for the roadmap decision.
const _coinGeckoBody =
    '{"bitcoin":{"usd":78402},"pax-gold":{"usd":4612.05}}';
const _frankfurterBody =
    '{"amount":1.0,"base":"TRY","date":"2026-08-25",'
    '"rates":{"USD":0.02079}}';

Asset _asset({
  required int id,
  required String code,
  required String type,
  Decimal? price,
  Decimal? quantity,
}) => Asset(
  id: id,
  assetName: code,
  assetCode: code,
  assetType: type,
  purchasePrice: price ?? Decimal.one,
  quantity: quantity ?? Decimal.one,
  purchaseDate: '2026-01-01',
);

void main() {
  late ArchlenceDatabase db;

  setUp(() => db = ArchlenceDatabase.memory());
  tearDown(() => db.close());

  final fixedNow = DateTime.utc(2026, 8, 26, 12);

  LivePriceService serviceWith(FakeProviders fake, {DateTime? now}) =>
      LivePriceService(
        db: db,
        httpGet: fake.get,
        now: () => now ?? fixedNow,
      );

  group('live pricing', () {
    test('prices a crypto holding as usd price times usdtry', () async {
      final fake = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      final result = await serviceWith(fake).priceHoldings([
        _asset(id: 1, code: 'BTC', type: 'Kripto'),
      ]);

      final usdtry = (Decimal.one / Decimal.parse('0.02079')).toDecimal(
        scaleOnInfinitePrecision: 20,
      );
      expect(result[1]!.pricePerUnit, Decimal.parse('78402') * usdtry);
      expect(result[1]!.pricePerUnit, isA<Decimal>());
      expect(result[1]!.source, 'CoinGecko + Frankfurter (ECB)');
      expect(result[1]!.asOf, fixedNow);
    });

    test('prices a currency holding as the inverted Frankfurter rate', () async {
      final fake = FakeProviders(frankfurterBody: _frankfurterBody);
      final result = await serviceWith(fake).priceHoldings([
        _asset(id: 1, code: 'USD', type: 'Döviz'),
      ]);

      final expected = (Decimal.one / Decimal.parse('0.02079')).toDecimal(
        scaleOnInfinitePrecision: 20,
      );
      expect(result[1]!.pricePerUnit, expected);
      expect(result[1]!.source, 'Frankfurter (ECB)');
      // A currency holding needs no crypto leg, so CoinGecko is never asked.
      expect(fake.coinGeckoCalls, 0);
    });

    test('prices bare gram gold with no multiplier', () async {
      final fake = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      final result = await serviceWith(fake).priceHoldings([
        _asset(id: 1, code: 'GOLD', type: 'Altın'),
      ]);

      final usdtry = (Decimal.one / Decimal.parse('0.02079')).toDecimal(
        scaleOnInfinitePrecision: 20,
      );
      final expectedGram =
          (Decimal.parse('4612.05') * usdtry / Decimal.parse('31.1034768'))
              .toDecimal(scaleOnInfinitePrecision: 20);
      expect(result[1]!.pricePerUnit, expectedGram);
    });

    test('scales a quarter coin by its weight multiplier', () async {
      final fake = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      final result = await serviceWith(fake).priceHoldings([
        _asset(id: 1, code: 'GOLD-CEYREK', type: 'Altın'),
      ]);

      final usdtry = (Decimal.one / Decimal.parse('0.02079')).toDecimal(
        scaleOnInfinitePrecision: 20,
      );
      final gram =
          (Decimal.parse('4612.05') * usdtry / Decimal.parse('31.1034768'))
              .toDecimal(scaleOnInfinitePrecision: 20);
      expect(result[1]!.pricePerUnit, gram * Decimal.parse('1.75'));
    });

    test('fetches each provider once for a whole portfolio, not per holding', () async {
      final fake = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      await serviceWith(fake).priceHoldings([
        _asset(id: 1, code: 'BTC', type: 'Kripto'),
        _asset(id: 2, code: 'BTC', type: 'Kripto'),
        _asset(id: 3, code: 'GOLD', type: 'Altın'),
        _asset(id: 4, code: 'USD', type: 'Döviz'),
      ]);

      expect(fake.coinGeckoCalls, 1);
      expect(fake.frankfurterCalls, 1);
    });

    test('shares are never priced and never touch a provider', () async {
      final fake = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      final result = await serviceWith(fake).priceHoldings([
        _asset(id: 1, code: 'ASELS', type: 'Hisse'),
      ]);

      expect(result.containsKey(1), isFalse);
      expect(fake.coinGeckoCalls, 0);
      expect(fake.frankfurterCalls, 0);
    });

    test('an unknown symbol is priced by neither provider', () async {
      final fake = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      final result = await serviceWith(fake).priceHoldings([
        _asset(id: 1, code: 'TRY', type: 'Döviz'),
      ]);

      expect(result.containsKey(1), isFalse);
    });
  });

  group('the cache', () {
    test('a successful live fetch is written under the holding\'s symbol', () async {
      final fake = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      await serviceWith(fake).priceHoldings([
        _asset(id: 1, code: 'BTC', type: 'Kripto'),
      ]);

      final rows = await db
          .customSelect(
            "SELECT price, asset_type, source FROM asset_price_cache "
            "WHERE symbol = 'BTC'",
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.data['asset_type'], 'CRYPTO');
      expect(rows.single.data['source'], 'CoinGecko + Frankfurter (ECB)');
    });

    test('a provider gap falls back to what the cache already holds', () async {
      // First call: live, and it writes the cache.
      final firstFake = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      final earlier = fixedNow.subtract(const Duration(hours: 2));
      await serviceWith(firstFake, now: earlier).priceHoldings([
        _asset(id: 1, code: 'BTC', type: 'Kripto'),
      ]);

      // Second call: the network is down. The earlier row must still answer.
      final secondFake = FakeProviders();
      final result = await serviceWith(secondFake).priceHoldings([
        _asset(id: 1, code: 'BTC', type: 'Kripto'),
      ]);

      expect(result.containsKey(1), isTrue);
      expect(result[1]!.source, 'CoinGecko + Frankfurter (ECB)');
      // The STALE timestamp, not "now" — a cached answer must say when it
      // was actually true, or a screen reading it would present two hours
      // of silence as a live quote.
      expect(result[1]!.asOf, earlier);
    });

    test('with nothing cached and no network, the holding is simply absent', () async {
      final fake = FakeProviders();
      final result = await serviceWith(fake).priceHoldings([
        _asset(id: 1, code: 'BTC', type: 'Kripto'),
      ]);

      expect(result.containsKey(1), isFalse);
    });

    test('a cache row with no source — written before that column existed — '
        'reads back as Yahoo Finance, matching the desktop\'s own default',
        () async {
      // Not a value this app ever WRITES; it is what a pre-`source`-column
      // desktop row means, and only the desktop's own convention — Yahoo was
      // the only provider back then — says so correctly.
      await db.customInsert(
        "INSERT INTO asset_price_cache (symbol, price, asset_type, "
        "updated_at) VALUES ('BTC', 100.0, 'CRYPTO', '2020-01-01T00:00:00+03:00')",
      );

      final fake = FakeProviders();
      final result = await serviceWith(fake).priceHoldings([
        _asset(id: 1, code: 'BTC', type: 'Kripto'),
      ]);

      expect(result[1]!.source, 'Yahoo Finance');
    });

    test('a second live fetch overwrites the row rather than duplicating it', () async {
      final fake = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      final holding = _asset(id: 1, code: 'BTC', type: 'Kripto');
      await serviceWith(fake).priceHoldings([holding]);
      await serviceWith(fake).priceHoldings([holding]);

      final rows = await db
          .customSelect(
            "SELECT COUNT(*) AS n FROM asset_price_cache WHERE symbol = 'BTC'",
          )
          .get();
      expect(rows.single.data['n'], 1);
    });
  });
}
