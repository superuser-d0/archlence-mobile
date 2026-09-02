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
import 'package:archlence_mobile/services/shares_api_key.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_platform_auth.dart';

/// A canned response keyed by which host it answers for, and a call counter
/// so a test can assert how many round trips actually happened — the
/// dedup behind fetching one CoinGecko id or one Frankfurter code once no
/// matter how many holdings share it.
class FakeProviders {
  FakeProviders({this.coinGeckoBody, this.frankfurterBody, this.sharesBody});

  String? coinGeckoBody;
  String? frankfurterBody;
  int coinGeckoCalls = 0;
  int frankfurterCalls = 0;
  final List<Uri> requested = [];

  /// What the shares endpoint answered with, and null to make it fail.
  String? sharesBody;
  int sharesCalls = 0;

  /// Every header the shares request carried, so a test can prove the key
  /// travelled in one rather than in the URL.
  Map<String, String> sharesHeaders = const {};

  Future<String> get(Uri uri, {Map<String, String> headers = const {}}) async {
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
    if (uri.host == 'www.nosyapi.com') {
      sharesCalls++;
      sharesHeaders = headers;
      if (sharesBody == null) throw const _NetworkFailure();
      return sharesBody!;
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

  /// [apiKey] null means the user has given the app no BIST key, which is
  /// the default state and the one most of these tests want.
  LivePriceService serviceWith(
    FakeProviders fake, {
    DateTime? now,
    String? apiKey,
  }) => LivePriceService(
    db: db,
    httpGet: fake.get,
    now: () => now ?? fixedNow,
    // Injected rather than left to the real one: a plain `test()` has no
    // Flutter binding, so the platform channel behind the secure store
    // throws an Error the service is right not to catch.
    sharesApiKey: SharesApiKey(
      storage: FakeSecureStorage(
        apiKey == null ? {} : {'archlence.shares-api-key': apiKey},
      ),
    ),
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

  group('shares, which need the user\'s own key', () {
    const sharesBody =
        '{"status":"success","rowCount":1,"data":['
        '{"code":"ASELS","ShortName":"ASELSAN","latest":214.5,'
        '"buying":214.4,"selling":214.6}]}';

    test('with no key, a share is not priced and nothing is asked', () async {
      // The default state, and the one the roadmap decision describes: the
      // app is keyless out of the box and shares stay at cost.
      final fake = FakeProviders(sharesBody: sharesBody);
      final result = await serviceWith(fake).priceHoldings([
        _asset(id: 1, code: 'ASELS', type: 'Hisse'),
      ]);

      expect(result.containsKey(1), isFalse);
      expect(fake.sharesCalls, 0);
    });

    test('with a key, a share is priced in lira with no conversion', () async {
      // BIST trades in lira, so this is the one provider whose number needs
      // no USDTRY leg at all.
      final fake = FakeProviders(sharesBody: sharesBody);
      final result = await serviceWith(
        fake,
        apiKey: 'a-user-key',
      ).priceHoldings([_asset(id: 1, code: 'ASELS', type: 'Hisse')]);

      expect(result[1]!.pricePerUnit, Decimal.parse('214.5'));
      expect(result[1]!.source, 'NosyAPI');
      expect(fake.sharesCalls, 1);
    });

    test('the key travels in a header, never in the query string', () async {
      // A credential in a URL reaches server logs, proxy logs and Referer.
      final fake = FakeProviders(sharesBody: sharesBody);
      await serviceWith(fake, apiKey: 'a-user-key').priceHoldings([
        _asset(id: 1, code: 'ASELS', type: 'Hisse'),
      ]);

      expect(fake.sharesHeaders['X-NSYP'], 'a-user-key');
      final shareUri = fake.requested.singleWhere(
        (uri) => uri.host == 'www.nosyapi.com',
      );
      expect(shareUri.query, isNot(contains('a-user-key')));
      expect(shareUri.toString(), isNot(contains('a-user-key')));
    });

    test('one request carries every share in the portfolio', () async {
      // The endpoint takes a comma-separated list and the free plan bills
      // per REQUEST, so batching is both the right shape and the cheap one.
      final fake = FakeProviders(
        sharesBody:
            '{"data":[{"code":"ASELS","latest":214.5},'
            '{"code":"THYAO","latest":312.25}]}',
      );
      final result = await serviceWith(fake, apiKey: 'k').priceHoldings([
        _asset(id: 1, code: 'ASELS', type: 'Hisse'),
        _asset(id: 2, code: 'THYAO', type: 'Hisse'),
      ]);

      expect(fake.sharesCalls, 1);
      final shareUri = fake.requested.singleWhere(
        (uri) => uri.host == 'www.nosyapi.com',
      );
      expect(shareUri.queryParameters['code'], 'ASELS,THYAO');
      expect(result[1]!.pricePerUnit, Decimal.parse('214.5'));
      expect(result[2]!.pricePerUnit, Decimal.parse('312.25'));
    });

    test('a rejected key leaves the share at cost, not an error', () async {
      // A 401, an expired key, or a spent monthly credit all arrive here the
      // same way, and all mean the same thing to a screen.
      final fake = FakeProviders(sharesBody: null);
      final result = await serviceWith(fake, apiKey: 'wrong').priceHoldings([
        _asset(id: 1, code: 'ASELS', type: 'Hisse'),
      ]);

      expect(result.containsKey(1), isFalse);
    });

    test('with a key, a share falls back to the cache like anything else',
        () async {
      // The case a spent monthly credit actually produces: yesterday's price
      // beats no price, as long as it says how old it is.
      final earlier = fixedNow.subtract(const Duration(hours: 5));
      await serviceWith(
        FakeProviders(sharesBody: sharesBody),
        now: earlier,
        apiKey: 'k',
      ).priceHoldings([_asset(id: 1, code: 'ASELS', type: 'Hisse')]);

      final result = await serviceWith(
        FakeProviders(sharesBody: null),
        apiKey: 'k',
      ).priceHoldings([_asset(id: 1, code: 'ASELS', type: 'Hisse')]);

      expect(result[1]!.pricePerUnit, Decimal.parse('214.5'));
      expect(result[1]!.asOf, earlier);
    });

    test('without a key, no cache lookup happens for a share at all', () async {
      // Nothing has ever priced it, so there is nothing to find — and asking
      // would be a database read on every refresh for no possible answer.
      await serviceWith(
        FakeProviders(sharesBody: sharesBody),
        apiKey: 'k',
      ).priceHoldings([_asset(id: 1, code: 'ASELS', type: 'Hisse')]);

      final result = await serviceWith(
        FakeProviders(sharesBody: sharesBody),
      ).priceHoldings([_asset(id: 1, code: 'ASELS', type: 'Hisse')]);

      expect(
        result.containsKey(1),
        isFalse,
        reason: 'a cached row must not resurrect a share the user cannot price',
      );
    });

    test('a portfolio with no shares never reads the key store', () async {
      // Proven by giving it a key store that throws: if it were consulted,
      // this would fail rather than pass.
      final service = LivePriceService(
        db: db,
        httpGet: FakeProviders(
          coinGeckoBody: _coinGeckoBody,
          frankfurterBody: _frankfurterBody,
        ).get,
        now: () => fixedNow,
        sharesApiKey: SharesApiKey(storage: const ThrowingSecureStorage()),
      );

      final result = await service.priceHoldings([
        _asset(id: 1, code: 'BTC', type: 'Kripto'),
      ]);

      expect(result.containsKey(1), isTrue);
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

    test('a price inside its lifetime is served with NO request at all', () async {
      // The reason `price_ttl.dart` exists. The Assets screen is torn down
      // and rebuilt on every tab switch, every recorded transaction and every
      // period chip; before this, each of those was a live round trip for a
      // figure that had not moved.
      final first = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      final holdings = [_asset(id: 1, code: 'BTC', type: 'Kripto')];
      await serviceWith(first, now: fixedNow).priceHoldings(holdings);
      expect(first.coinGeckoCalls, 1);

      // Two minutes later — inside crypto's three-minute lifetime.
      final second = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      final result = await serviceWith(
        second,
        now: fixedNow.add(const Duration(minutes: 2)),
      ).priceHoldings(holdings);

      expect(second.requested, isEmpty, reason: 'nothing may leave the phone');
      expect(result[1], isNotNull);
      // And it reports the age it actually has, not the moment it was asked.
      expect(result[1]!.asOf, fixedNow);
    });

    test('and past its lifetime it is fetched again', () async {
      final first = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      final holdings = [_asset(id: 1, code: 'BTC', type: 'Kripto')];
      await serviceWith(first, now: fixedNow).priceHoldings(holdings);

      final second = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      await serviceWith(
        second,
        now: fixedNow.add(const Duration(minutes: 4)),
      ).priceHoldings(holdings);

      expect(second.coinGeckoCalls, 1);
    });

    test('force ignores the lifetime, which is pull-to-refresh', () async {
      final first = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      final holdings = [_asset(id: 1, code: 'BTC', type: 'Kripto')];
      await serviceWith(first, now: fixedNow).priceHoldings(holdings);

      final second = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      await serviceWith(
        second,
        now: fixedNow.add(const Duration(seconds: 5)),
      ).priceHoldings(holdings, force: true);

      expect(second.coinGeckoCalls, 1);
    });

    test('a fresh crypto row does not drag USDTRY along with it', () async {
      // The USD leg is fetched "the moment either is present". That has to
      // key off what is being REFETCHED, or a portfolio held entirely in
      // cache would still call Frankfurter every time.
      final first = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      final holdings = [_asset(id: 1, code: 'BTC', type: 'Kripto')];
      await serviceWith(first, now: fixedNow).priceHoldings(holdings);

      final second = FakeProviders(
        coinGeckoBody: _coinGeckoBody,
        frankfurterBody: _frankfurterBody,
      );
      await serviceWith(
        second,
        now: fixedNow.add(const Duration(minutes: 1)),
      ).priceHoldings(holdings);

      expect(second.frankfurterCalls, 0);
    });

    test('a share with no key still touches nothing, cached or not', () async {
      // The rule that predates this change and must survive it: without a
      // key the app has never priced a share, so it must not read the store
      // for one either.
      final fake = FakeProviders(sharesBody: '{"data":[]}');
      final result = await serviceWith(fake).priceHoldings([
        _asset(id: 1, code: 'ASELS', type: 'Hisse'),
      ]);
      expect(fake.requested, isEmpty);
      expect(result.containsKey(1), isFalse);
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
