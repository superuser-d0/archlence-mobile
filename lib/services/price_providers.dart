/// The two keyless price providers the phone calls directly, and the
/// symbol/id maps between what the app stores and what each API answers to.
///
/// A port of `services/price_providers.py`'s CoinGecko and Frankfurter halves
/// — but not of its role there. On the desktop those two are a FALLBACK
/// behind `yfinance`; here they are the ONLY source, by decision — see
/// `docs/ROADMAP.md` -> "Prices come from the phone, from keyless sources".
/// Nothing in this file talks to Yahoo, and nothing in this app does.
library;

import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';

import 'price_guard.dart';

/// Fetches the body of a GET request, or throws.
///
/// The seam a test drives instead of the network: everything in this file
/// takes one of these rather than reaching for `HttpClient` itself, so a
/// test can hand back a recorded response — or a malformed one — without a
/// socket ever opening. See `lib/backup/backup_service.dart` for the same
/// idea applied to the file system instead of the network.
typedef HttpGet = Future<String> Function(Uri uri);

/// The default [HttpGet]: `dart:io`'s own client, with a bound on how long a
/// price screen can be made to wait for a provider that never answers.
///
/// Verified rather than assumed: `HttpClient.getUrl` follows the 3xx Location
/// header on its own (`followRedirects` defaults to `true`), so the
/// Frankfurter host's redirect to `.dev` needs no handling here.
Future<String> httpGetDefault(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw HttpException(
        'GET $uri returned ${response.statusCode}',
        uri: uri,
      );
    }
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

/// Named the way the cached row's `source` column names them — desktop data,
/// not translated, because a restored backup and a mobile-written cache row
/// have to read as the same source under either app.
const String sourceCoinGecko = 'CoinGecko';
const String sourceFrankfurter = 'Frankfurter (ECB)';

/// What a `NULL` `asset_price_cache.source` means — a row written before that
/// column existed. `PRICE_SOURCE` in the desktop's `price_service.py`: back
/// then Yahoo was the only provider there was, so a row with no source on it
/// really did come from Yahoo, and reading it as anything else would be
/// inventing where a figure came from. This app never WRITES this value —
/// it never calls Yahoo — only reads it, for a row the desktop wrote first.
const String sourceLegacyYahoo = 'Yahoo Finance';

/// The desktop's own crypto-code-to-CoinGecko-id table
/// (`services/asset_service.py::COINGECKO_IDS`), verbatim. A code missing
/// here is a crypto this app cannot price yet, not a bug to work around —
/// the desktop has exactly the same gap.
const Map<String, String> coinGeckoIds = {
  'BTC': 'bitcoin',
  'ETH': 'ethereum',
  'ETC': 'ethereum-classic',
  'USDT': 'tether',
  'USDC': 'usd-coin',
  'BNB': 'binancecoin',
  'XRP': 'ripple',
  'ADA': 'cardano',
  'SOL': 'solana',
  'DOGE': 'dogecoin',
  'DOT': 'polkadot',
  'TRX': 'tron',
  'AVAX': 'avalanche-2',
  'SHIB': 'shiba-inu',
  'LTC': 'litecoin',
  'LINK': 'chainlink',
  'MATIC': 'matic-network',
  'XLM': 'stellar',
  'ATOM': 'cosmos',
  'UNI': 'uniswap',
  'XMR': 'monero',
  'BCH': 'bitcoin-cash',
  'FIL': 'filecoin',
  'APT': 'aptos',
  'ARB': 'arbitrum',
  'OP': 'optimism',
};

/// PAXG: tokenised gold, one troy ounce of allocated metal per token. The
/// answer to gold once `GC=F` is off the table — see the roadmap decision,
/// which also records the cross-check against XAUT that justified it.
const String goldCoinGeckoId = 'pax-gold';

/// The quote suffixes the desktop strips before looking a code up
/// (`_coingecko_id_for`). Kept even though this app never WRITES a suffixed
/// code itself: `active_assets` is schema-compatible, so a holding restored
/// from a desktop backup can carry one.
const List<String> _cryptoQuoteSuffixes = [
  '-USDTRY',
  '-USDT',
  '-USDC',
  '-BUSD',
  '-USD',
  '-TRY',
  '-EUR',
];

/// `'BTC-USD'` -> `'bitcoin'`; bare `'BTC'` matches directly. Null for a code
/// this app has no CoinGecko id for.
String? coinGeckoIdFor(String code) {
  var base = code.trim().toUpperCase();
  for (final suffix in _cryptoQuoteSuffixes) {
    if (base.endsWith(suffix)) {
      base = base.substring(0, base.length - suffix.length);
      break;
    }
  }
  return coinGeckoIds[base];
}

/// Fetches USD prices for [ids] (CoinGecko ids, e.g. `{'bitcoin', 'pax-gold'}`)
/// from `/simple/price`.
///
/// NEVER THROWS. A network failure, a timeout, a malformed body or a missing
/// id all come back as an ABSENT key rather than an exception — the caller's
/// job is to say what it could not price, not to catch what this already
/// swallowed. Every value that does come back has passed [finitePositivePrice]
/// first, so a hostile or broken response cannot smuggle an `Infinity` into
/// the batch the way it once did on the desktop.
Future<Map<String, Decimal>> fetchCoinGeckoUsdPrices(
  Set<String> ids, {
  required HttpGet get,
}) async {
  if (ids.isEmpty) return const {};
  final uri = Uri.https('api.coingecko.com', '/api/v3/simple/price', {
    'ids': (ids.toList()..sort()).join(','),
    'vs_currencies': 'usd',
  });

  final Object? payload;
  try {
    payload = jsonDecode(await get(uri));
  } on Object {
    return const {};
  }
  if (payload is! Map<String, Object?>) return const {};

  final prices = <String, Decimal>{};
  for (final id in ids) {
    final entry = payload[id];
    if (entry is! Map<String, Object?>) continue;
    final price = finitePositivePrice(entry['usd']);
    if (price != null) prices[id] = price;
  }
  return prices;
}

/// Fetches the lira value of ONE UNIT of each of [currencyCodes] from
/// Frankfurter (the ECB's daily reference rates).
///
/// The endpoint answers `TRY -> {code}` — how much of `code` one lira buys —
/// so this INVERTS every rate before returning it: the rest of the app deals
/// in "how many lira is one unit", the same direction `formatLira` and every
/// stored price already use. A rate of zero (which would divide by zero) is
/// impossible here: [finitePositivePrice] has already rejected it.
///
/// NEVER THROWS, for the same reason [fetchCoinGeckoUsdPrices] does not: a
/// missing code is a hole in the result, not a reason to fail every other
/// code in the same request.
Future<Map<String, Decimal>> fetchFrankfurterTryRates(
  Set<String> currencyCodes, {
  required HttpGet get,
}) async {
  if (currencyCodes.isEmpty) return const {};
  final uri = Uri.https('api.frankfurter.dev', '/v1/latest', {
    'from': 'TRY',
    'to': (currencyCodes.toList()..sort()).join(','),
  });

  final Object? payload;
  try {
    payload = jsonDecode(await get(uri));
  } on Object {
    return const {};
  }
  if (payload is! Map<String, Object?>) return const {};
  final rates = payload['rates'];
  if (rates is! Map<String, Object?>) return const {};

  final tryPerUnit = <String, Decimal>{};
  for (final code in currencyCodes) {
    final tryPerCode = finitePositivePrice(rates[code]);
    if (tryPerCode == null) continue;
    final inverted = (Decimal.one / tryPerCode).toDecimal(
      scaleOnInfinitePrecision: 20,
    );
    tryPerUnit[code] = inverted;
  }
  return tryPerUnit;
}
