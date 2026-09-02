/// Maps stored holding data to provider-neutral price requests.
library;

import 'package:decimal/decimal.dart';

/// A lookup the price providers can understand without exposing provider IDs
/// to the rest of the app.
sealed class PriceRequest {
  const PriceRequest({required this.normalizedAssetType, required this.code});

  /// The desktop-compatible classification of the stored asset type.
  ///
  /// Keeping it on the request makes the data boundary auditable without
  /// turning a provider's identifier into part of the stored-holding model.
  final String normalizedAssetType;

  /// The holding's own stored `asset_code`, trimmed and upper-cased.
  ///
  /// On the base class, not just the subtypes that look one up in a provider
  /// table: `asset_price_cache.symbol` is keyed on this EXACT value for every
  /// kind of holding, gold included, because that is what the desktop's own
  /// `_store_cache` keys it on too — a cache is only compatible with the
  /// other app's if a mobile-written row can sit beside a desktop-written one
  /// under the same symbol.
  final String code;
}

/// A crypto lookup by the holding's canonical code.
final class CryptoPriceRequest extends PriceRequest {
  const CryptoPriceRequest({
    required super.normalizedAssetType,
    required super.code,
  });
}

/// A fiat-currency lookup by ISO-style code.
final class CurrencyPriceRequest extends PriceRequest {
  const CurrencyPriceRequest({
    required super.normalizedAssetType,
    required super.code,
  });
}

/// A gold lookup, optionally scaled to a physical holding's gram weight.
final class GoldPriceRequest extends PriceRequest {
  const GoldPriceRequest({
    required super.normalizedAssetType,
    required super.code,
    required this.multiplier,
  });

  final Decimal? multiplier;
}

/// A BIST share.
///
/// NOT "unsupported", which is what this was called when nothing could price
/// one. Whether a share CAN be priced depends on whether the user has given
/// the app an API key — a runtime fact that belongs to `LivePriceService`,
/// not to a classification that only ever asked what kind of holding this is.
final class SharesPriceRequest extends PriceRequest {
  const SharesPriceRequest({
    required super.normalizedAssetType,
    required super.code,
  });
}

/// A holding for which no live price should be requested.
final class UnknownPriceRequest extends PriceRequest {
  const UnknownPriceRequest({
    required super.normalizedAssetType,
    required super.code,
  });
}

const _cryptoAssetTypes = <String>{
  'CRYPTO',
  'KRIPTO',
  'KRİPTO',
  'KRIPTO PARA',
  'KRİPTO PARA',
};

const _stockAssetTypes = <String>{
  'STOCK',
  'HISSE',
  'HİSSE',
  'HİSSE SENEDİ',
  'HISSE SENEDI',
};

const _fxGoldAssetTypes = <String>{
  'FX_GOLD',
  'DÖVIZ',
  'DÖVİZ',
  'FOREX',
  'ALTIN',
  'GOLD',
};

const _goldInternalCodes = <String>{
  'ALTIN',
  'GOLD',
  'GRAM',
  'XAU',
  'GOLD-ONS',
  'GOLD-CEYREK',
  'GOLD-YARIM',
  'GOLD-TAM',
};

final _goldMultipliers = <String, Decimal>{
  'GOLD-ONS': Decimal.parse('31.1034768'),
  'GOLD-CEYREK': Decimal.parse('1.75'),
  'GOLD-YARIM': Decimal.parse('3.5'),
  'GOLD-TAM': Decimal.parse('7.0'),
};

final _unicodeLetters = RegExp(r'^\p{L}+$', unicode: true);

/// Classifies the stored [assetCode] and [assetType] into a live-price lookup.
///
/// The result intentionally carries no provider identifier. Providers decide
/// their own query shapes; this boundary only preserves the desktop's stored
/// data classification.
PriceRequest priceRequestForHolding(String? assetCode, String? assetType) {
  // Stored values are protocol data. Do not use localizedUpperCase here:
  // Python's str.upper(), like Dart's toUpperCase(), is locale-independent.
  final code = (assetCode ?? '').trim().toUpperCase();
  final kind = normalizeAssetType(assetType);

  if (code.isEmpty) {
    return UnknownPriceRequest(normalizedAssetType: kind, code: code);
  }
  if (kind == 'STOCK') {
    return SharesPriceRequest(normalizedAssetType: kind, code: code);
  }
  if (kind == 'CRYPTO') {
    return CryptoPriceRequest(normalizedAssetType: kind, code: code);
  }
  if (_goldInternalCodes.contains(code)) {
    return GoldPriceRequest(
      normalizedAssetType: kind,
      code: code,
      multiplier: _goldMultipliers[code],
    );
  }
  if (_isCurrencyCode(code)) {
    return CurrencyPriceRequest(normalizedAssetType: kind, code: code);
  }
  return UnknownPriceRequest(normalizedAssetType: kind, code: code);
}

/// The desktop's `normalize_asset_type`, and public for the same reason it is
/// there: the cache lifetime in `price_ttl.dart` is decided by asset KIND, and
/// a second spelling table for it would be a second place to drift.
String normalizeAssetType(String? assetType) {
  // `toUpperCase` is deliberately locale-independent; these are database
  // literals, and using the Turkish display helper would change the protocol.
  final value = (assetType ?? '').trim().toUpperCase();
  if (_cryptoAssetTypes.contains(value)) return 'CRYPTO';
  if (_stockAssetTypes.contains(value)) return 'STOCK';
  if (_fxGoldAssetTypes.contains(value)) return 'FX_GOLD';
  return value.isEmpty ? 'FX_GOLD' : value;
}

bool _isCurrencyCode(String code) =>
    code.runes.length == 3 && _unicodeLetters.hasMatch(code) && code != 'TRY';
