/// Fills `asset_price_cache` from the live providers, one holding at a time,
/// and reads it back when a live fetch could not reach a symbol.
///
/// The composition point the roadmap's price-fetching item 5 describes: no
/// price arithmetic or fetching happens anywhere else, so a screen only ever
/// asks THIS what a holding is worth and never touches `ticker_mapper.dart`
/// or `price_providers.dart` directly.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../data/database.dart';
import 'asset_service.dart' show Asset;
import 'price_providers.dart';
import 'price_ttl.dart';
import 'shares_api_key.dart';
import 'ticker_mapper.dart';

/// One holding's current price, live or read back from the cache.
class CachedPrice {
  const CachedPrice({
    required this.pricePerUnit,
    required this.source,
    required this.asOf,
  });

  /// TRY per unit, at FULL precision.
  ///
  /// Not pre-rounded to any [FinancialPrecision]: `AssetService.calculatePnl`
  /// is explicit that the arithmetic stays Decimal throughout and only the
  /// RESULT is quantized. Rounding the input here would be the same mistake
  /// one level up.
  final Decimal pricePerUnit;

  /// Which provider(s) this came from — `'CoinGecko'`,
  /// `'Frankfurter (ECB)'`, or both joined with `' + '` where a price is the
  /// product of two legs (crypto and gold both convert through USDTRY).
  /// Verbatim desktop data; not translated, for the same reason
  /// `network_logo` values are not.
  final String source;

  /// When this price was fetched or, for a cache read, when the row it came
  /// from was last written. Never omitted: a figure with no age attached is
  /// indistinguishable from a live one, and this app does not present a
  /// stale price as fresh.
  final DateTime asOf;
}

/// The grams in one troy ounce — `GRAMS_PER_TROY_OUNCE` in the desktop's
/// `utils/ticker_mapper.py`. A physical constant, not application logic, so
/// it is repeated here rather than exported from `ticker_mapper.dart` — that
/// file's job is classification, not unit conversion.
final Decimal _gramsPerTroyOunce = Decimal.parse('31.1034768');

/// Fills [Asset] holdings with live prices, and the cache row behind each
/// one.
class LivePriceService {
  LivePriceService({
    required this.db,
    HttpGet? httpGet,
    DateTime Function()? now,
    SharesApiKey? sharesApiKey,
  }) : _httpGet = httpGet ?? httpGetDefault,
       _now = now ?? DateTime.now,
       _sharesApiKey = sharesApiKey ?? SharesApiKey();

  final ArchlenceDatabase db;
  final HttpGet _httpGet;
  final DateTime Function() _now;

  /// Where the user's own BIST key lives. Read fresh on every batch rather
  /// than cached in a field: a key entered in Settings has to take effect on
  /// the next pull-to-refresh, not on the next app start.
  final SharesApiKey _sharesApiKey;

  /// Prices every holding it can. A holding this service has no way to price
  /// — shares, an unrecognised symbol, or a symbol neither the live fetch
  /// nor the cache has ever seen — is simply absent from the result; the
  /// caller (the Assets screen) draws those at cost, same as before this.
  ///
  /// CACHE FIRST. A row still inside its lifetime is returned without the
  /// network being touched at all — see `price_ttl.dart`, which ports the
  /// desktop's own dynamic TTL. This used to fetch unconditionally, and the
  /// Assets screen is torn down and rebuilt on every tab switch, every
  /// recorded transaction and every period chip, so tapping through the five
  /// period chips cost five CoinGecko round trips for figures no period
  /// affects. The providers are somebody else's servers and are rate limited;
  /// this app already refuses to fetch a logo per holding for decoration, and
  /// the same restraint belongs here.
  ///
  /// [force] is the pull-to-refresh path: the one gesture that means "I want
  /// a new number now" ignores the lifetime.
  Future<Map<int, CachedPrice>> priceHoldings(
    List<Asset> holdings, {
    bool force = false,
  }) async {
    final requests = {
      for (final holding in holdings)
        holding.id: priceRequestForHolding(holding.assetCode, holding.assetType),
    };

    // The key is read under exactly the condition it was before — a portfolio
    // of crypto and gold must not touch the secure store — but it is read up
    // here now, because it decides which holdings are allowed a cached price
    // as well as which can be fetched. Moving it must not widen that: a share
    // with no key behaves exactly as it did, at cost.
    final allShareCodes = <String>{
      for (final request in requests.values)
        if (request is SharesPriceRequest) request.code,
    };
    final apiKey = allShareCodes.isEmpty ? null : await _sharesApiKey.read();

    // Whether this app would ever put a price against a request — from the
    // cache or from the wire. Unknown codes never can; a share can only once
    // the user has supplied a key. The normalized type it reads is fed back
    // through `normalizeAssetType` inside the TTL, which is idempotent and
    // pinned by the vectors: 'CRYPTO', 'STOCK' and 'FX_GOLD' are inputs there
    // as well as outputs.
    bool priceable(PriceRequest request) => switch (request) {
      UnknownPriceRequest() => false,
      SharesPriceRequest() => apiKey != null,
      _ => true,
    };

    final now = _now();
    final cached = await _readCache({
      for (final request in requests.values)
        if (priceable(request)) request.code,
    });

    // Split into what the cache still answers for and what has to be asked.
    final result = <int, CachedPrice>{};
    final pending = <int, PriceRequest>{};
    for (final entry in requests.entries) {
      final request = entry.value;
      if (!priceable(request)) continue;
      final row = cached[request.code];
      final fresh =
          !force &&
          row != null &&
          priceStillFresh(
            assetType: request.normalizedAssetType,
            updatedAt: row.asOf,
            now: now,
          );
      if (fresh) {
        result[entry.key] = row;
      } else {
        pending[entry.key] = request;
      }
    }

    // The whole point: a portfolio whose prices are all inside their lifetime
    // opens the Assets tab with no request leaving the phone.
    if (pending.isEmpty) return result;

    // Every CoinGecko id this batch needs: one per resolvable crypto code,
    // plus PAXG the moment any gold holding is present at all.
    final cryptoIds = <String>{};
    for (final request in pending.values) {
      switch (request) {
        case CryptoPriceRequest(:final code):
          final id = coinGeckoIdFor(code);
          if (id != null) cryptoIds.add(id);
        case GoldPriceRequest():
          cryptoIds.add(goldCoinGeckoId);
        case CurrencyPriceRequest():
        case SharesPriceRequest():
        case UnknownPriceRequest():
          break;
      }
    }

    final currencyCodes = <String>{
      for (final request in pending.values)
        if (request is CurrencyPriceRequest) request.code,
      // Crypto and gold both convert their USD leg through USDTRY, so the
      // rate is fetched the moment either is present — even for a portfolio
      // with no currency holding of its own.
      if (cryptoIds.isNotEmpty) 'USD',
    };

    // Only the shares actually being refetched. `apiKey` was read above, once,
    // under the same "is there a share at all" condition it always had.
    final shareCodes = <String>{
      for (final request in pending.values)
        if (request is SharesPriceRequest) request.code,
    };

    final usdPrices = await fetchCoinGeckoUsdPrices(cryptoIds, get: _httpGet);
    final tryRates = await fetchFrankfurterTryRates(currencyCodes, get: _httpGet);
    final sharePrices = apiKey == null
        ? const <String, Decimal>{}
        : await fetchSharePricesTry(
            shareCodes,
            apiKey: apiKey,
            get: _httpGet,
          );
    final usdtry = tryRates['USD'];
    final fetchedAt = _now();

    final toCache = <String, (Decimal price, String assetType, String source)>{};
    final unresolvedCodes = <String>{};

    for (final entry in pending.entries) {
      final holdingId = entry.key;
      final request = entry.value;
      final live = _liveResult(
        request: request,
        usdPrices: usdPrices,
        tryRates: tryRates,
        sharePrices: sharePrices,
        usdtry: usdtry,
      );
      if (live != null) {
        result[holdingId] = CachedPrice(
          pricePerUnit: live.price,
          source: live.source,
          asOf: fetchedAt,
        );
        toCache[request.code] = (
          live.price,
          request.normalizedAssetType,
          live.source,
        );
      } else {
        // Priceable IN PRINCIPLE, just not by this fetch — a provider gap.
        // Everything in `pending` passed `priceable` already, so the
        // eligibility test that used to live here has moved upstream where
        // it also governs the cache read.
        unresolvedCodes.add(request.code);
      }
    }

    if (toCache.isNotEmpty) await _writeCache(toCache);
    if (unresolvedCodes.isNotEmpty) {
      // A STALE row is better than no figure at all, and it carries its own
      // `asOf` so the screen says how old it is. These rows were already read
      // at the top of this method; querying again would only re-read what a
      // failed fetch did not change.
      for (final entry in pending.entries) {
        if (result.containsKey(entry.key)) continue;
        final row = cached[entry.value.code];
        if (row != null) result[entry.key] = row;
      }
    }

    return result;
  }

  /// The price this fetch's own results can compute for [request], or null
  /// when a leg it needs (a CoinGecko id, USDTRY, a Frankfurter rate) did not
  /// come back. Pure: touches neither the network nor the database.
  ({Decimal price, String source})? _liveResult({
    required PriceRequest request,
    required Map<String, Decimal> usdPrices,
    required Map<String, Decimal> tryRates,
    required Map<String, Decimal> sharePrices,
    required Decimal? usdtry,
  }) {
    switch (request) {
      case CryptoPriceRequest(:final code):
        final id = coinGeckoIdFor(code);
        final usd = id == null ? null : usdPrices[id];
        if (usd == null || usdtry == null) return null;
        return (
          price: usd * usdtry,
          source: '$sourceCoinGecko + $sourceFrankfurter',
        );

      case GoldPriceRequest(:final multiplier):
        final usd = usdPrices[goldCoinGeckoId];
        if (usd == null || usdtry == null) return null;
        final gram = (usd * usdtry / _gramsPerTroyOunce).toDecimal(
          scaleOnInfinitePrecision: 20,
        );
        return (
          price: multiplier == null ? gram : gram * multiplier,
          source: '$sourceCoinGecko + $sourceFrankfurter',
        );

      case CurrencyPriceRequest(:final code):
        final rate = tryRates[code];
        if (rate == null) return null;
        return (price: rate, source: sourceFrankfurter);

      case SharesPriceRequest(:final code):
        // Already in lira — the only provider here that needs no conversion,
        // because BIST trades in lira.
        final price = sharePrices[code];
        if (price == null) return null;
        return (price: price, source: sourceNosyApi);

      case UnknownPriceRequest():
        return null;
    }
  }

  Future<void> _writeCache(
    Map<String, (Decimal price, String assetType, String source)> rows,
  ) async {
    final stamp = _istanbulTimestamp(_now());
    await db.transaction(() async {
      for (final entry in rows.entries) {
        final (price, assetType, source) = entry.value;
        await db.customInsert(
          'INSERT INTO asset_price_cache '
          '(symbol, price, asset_type, updated_at, source) '
          'VALUES (?, ?, ?, ?, ?) '
          'ON CONFLICT(symbol) DO UPDATE SET '
          'price=excluded.price, asset_type=excluded.asset_type, '
          'updated_at=excluded.updated_at, source=excluded.source',
          variables: [
            Variable<String>(entry.key),
            Variable<double>(price.toDouble()),
            Variable<String>(assetType),
            Variable<String>(stamp),
            Variable<String>(source),
          ],
        );
      }
    });
  }

  Future<Map<String, CachedPrice>> _readCache(Set<String> symbols) async {
    if (symbols.isEmpty) return const {};
    final placeholders = List.filled(symbols.length, '?').join(',');
    final rows = await db
        .customSelect(
          'SELECT symbol, price, updated_at, source FROM asset_price_cache '
          'WHERE symbol IN ($placeholders)',
          variables: [for (final symbol in symbols) Variable<String>(symbol)],
        )
        .get();

    final out = <String, CachedPrice>{};
    for (final row in rows) {
      final data = row.data;
      final price = data['price'];
      final updatedAt = data['updated_at'];
      if (price is! num || updatedAt is! String) continue;
      final asOf = DateTime.tryParse(updatedAt);
      if (asOf == null) continue;
      out[data['symbol']! as String] = CachedPrice(
        pricePerUnit: Decimal.parse(price.toString()),
        source: (data['source'] as String?) ?? sourceLegacyYahoo,
        asOf: asOf,
      );
    }
    return out;
  }
}

/// `updated_at`, in the ONE format this specific table needs to stay
/// sortable by SQLite's `MAX(updated_at)` however a row was written.
///
/// The desktop stores `datetime.astimezone(ISTANBUL).isoformat()` — a FIXED
/// `+03:00` offset, because Turkey has observed no daylight saving since
/// September 2016. That fixed offset is exactly why this needs no timezone
/// database: `+03:00` never changes, so three hours is the whole rule.
///
/// Every OTHER timestamp column in this app uses `sqliteTimestamp` instead
/// (`YYYY-MM-DD HH:MM:SS`, no offset). This table is the one exception,
/// because it is the one where a mobile-written row and a desktop-written row
/// can end up side by side after a restore, and `MAX()` is a plain TEXT
/// comparison — mixing formats could make an older desktop row read as newer
/// than a fresher mobile one, or the reverse.
String _istanbulTimestamp(DateTime when) {
  final istanbul = when.toUtc().add(const Duration(hours: 3));
  String two(int value) => value.toString().padLeft(2, '0');
  return '${istanbul.year.toString().padLeft(4, '0')}-${two(istanbul.month)}-'
      '${two(istanbul.day)}T${two(istanbul.hour)}:${two(istanbul.minute)}:'
      '${two(istanbul.second)}+03:00';
}
