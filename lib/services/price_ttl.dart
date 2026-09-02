/// How long a cached price stays usable before it is worth fetching again.
///
/// A port of the desktop's `get_ttl_minutes` in `services/price_service.py`,
/// whose module docstring calls that service "cache-first, dinamik TTL'li".
/// This app had no lifetime at all: `priceHoldings` went to the providers on
/// every call, and the Assets screen is rebuilt from scratch on every tab
/// switch, every recorded transaction and every period chip — so tapping
/// through the five period chips cost five CoinGecko round trips for figures
/// the period does not affect.
///
/// THE RULES ARE NOT INVENTED HERE. They are the desktop's, generated into
/// `test/price_ttl_vectors.txt` by `tool/emit_price_ttl_vectors.py` calling
/// the real function, and pinned by `test/price_ttl_test.dart`. Testing a
/// port against expectations typed out by hand tests the typing.
///
/// The shape worth knowing: a CLOSED MARKET has no lifetime at all. A share
/// price at midnight cannot change before the market opens, so refetching it
/// is pure waste — the desktop returns infinity and so does this, as `null`.
library;

import 'ticker_mapper.dart' show normalizeAssetType;

/// Istanbul is UTC+3 all year. Turkey has kept no daylight saving since 2016,
/// which is why neither side of this port needs a timezone database — the
/// same assumption `_istanbulTimestamp` in `live_price_service.dart` already
/// writes cache rows under.
const Duration _istanbulOffset = Duration(hours: 3);

/// `MARKET_OPEN` and `MARKET_CLOSE` in the desktop module. Both bounds are
/// INCLUSIVE there (`MARKET_OPEN <= t <= MARKET_CLOSE`) and the vectors probe
/// each edge to the minute, because that is exactly where a `<=` silently
/// becoming a `<` would hide.
const int _marketOpenMinutes = 9 * 60 + 55;
const int _marketCloseMinutes = 18 * 60 + 10;

/// How long a price of [assetType] stays fresh, or `null` for "indefinitely".
///
/// `null` is the desktop's `INFINITE_TTL`, and it means the market that sets
/// this price is shut: there is nothing to refresh towards. Callers must not
/// read it as "unknown" — it is the strongest possible statement that the
/// cached row is still the current price.
Duration? priceCacheLifetime(String? assetType, DateTime now) {
  final kind = normalizeAssetType(assetType);
  final istanbul = now.toUtc().add(_istanbulOffset);
  // `DateTime.weekday` is 1=Monday..7=Sunday; Python's is 0=Monday..6=Sunday.
  // `weekday < 5` there is Monday-Friday, which is `weekday <= 5` here — the
  // kind of off-by-one that a fixture generated from the real function
  // catches and a transcribed table does not.
  final isWeekday = istanbul.weekday <= DateTime.friday;
  final minuteOfDay = istanbul.hour * 60 + istanbul.minute;

  switch (kind) {
    case 'CRYPTO':
      // Trades continuously; the desktop refreshes fastest here.
      return const Duration(minutes: 3);
    case 'STOCK':
      final open =
          isWeekday &&
          minuteOfDay >= _marketOpenMinutes &&
          minuteOfDay <= _marketCloseMinutes;
      return open ? const Duration(minutes: 5) : null;
    case 'FX_GOLD':
      return isWeekday ? const Duration(minutes: 10) : null;
    default:
      return const Duration(minutes: 10);
  }
}

/// Whether a row written at [updatedAt] still answers for [assetType].
///
/// Separated from [priceCacheLifetime] so the "closed market" case is stated
/// once: a null lifetime is fresh forever, and writing `age < ttl` with a
/// nullable ttl at each call site is how one of them ends up refetching all
/// night.
bool priceStillFresh({
  required String? assetType,
  required DateTime updatedAt,
  required DateTime now,
}) {
  final lifetime = priceCacheLifetime(assetType, now);
  if (lifetime == null) return true;
  final age = now.difference(updatedAt);
  // A negative age is a clock that moved, not a fresh price. Treating it as
  // fresh would let a bad device clock pin a stale figure indefinitely, so it
  // falls through to a refetch — the opposite of the choice `priceAge` makes
  // in `lib/ui/price_freshness.dart`, and deliberately: that one is deciding
  // what to SAY, this one is deciding whether to ASK.
  if (age.isNegative) return false;
  return age < lifetime;
}
