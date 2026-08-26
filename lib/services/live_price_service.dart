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
  Future<Map<int, CachedPrice>> priceHoldings(List<Asset> holdings) async {
    final requests = {
      for (final holding in holdings)
        holding.id: priceRequestForHolding(holding.assetCode, holding.assetType),
    };

    // Every CoinGecko id this batch needs: one per resolvable crypto code,
    // plus PAXG the moment any gold holding is present at all.
    final cryptoIds = <String>{};
    for (final request in requests.values) {
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
      for (final request in requests.values)
        if (request is CurrencyPriceRequest) request.code,
      // Crypto and gold both convert their USD leg through USDTRY, so the
      // rate is fetched the moment either is present — even for a portfolio
      // with no currency holding of its own.
      if (cryptoIds.isNotEmpty) 'USD',
    };

    final shareCodes = <String>{
      for (final request in requests.values)
        if (request is SharesPriceRequest) request.code,
    };
    // Read ONLY when there is a share to price. A portfolio of crypto and
    // gold must not touch the secure store at all, and a key the user has
    // not given is not an error — it is the documented default, and it means
    // shares stay at cost exactly as they did before this existed.
    final apiKey = shareCodes.isEmpty ? null : await _sharesApiKey.read();

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

    final result = <int, CachedPrice>{};
    final toCache = <String, (Decimal price, String assetType, String source)>{};
    final unresolvedCodes = <String>{};

    for (final entry in requests.entries) {
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
      } else if (request is CurrencyPriceRequest ||
          request is CryptoPriceRequest ||
          request is GoldPriceRequest ||
          (request is SharesPriceRequest && apiKey != null)) {
        // Priceable IN PRINCIPLE, just not by this fetch — a provider gap.
        // A share counts only when a key exists: without one, nothing has
        // ever priced it, so there is no cache row to find and no reason to
        // look. WITH one, a share falls back like anything else, which is
        // what keeps a portfolio readable when a monthly credit runs out.
        unresolvedCodes.add(request.code);
      }
    }

    if (toCache.isNotEmpty) await _writeCache(toCache);
    if (unresolvedCodes.isNotEmpty) {
      final cached = await _readCache(unresolvedCodes);
      for (final entry in requests.entries) {
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
