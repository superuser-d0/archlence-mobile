/// Differential tests against the desktop holding classification.
library;

import 'dart:io';

import 'package:archlence_mobile/services/asset_service.dart' show assetTypes;
import 'package:archlence_mobile/services/ticker_mapper.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

class _ClassificationVector {
  const _ClassificationVector({
    required this.symbol,
    required this.assetType,
    required this.kind,
    required this.isGold,
    required this.multiplier,
  });

  final String symbol;
  final String assetType;
  final String kind;
  final bool isGold;
  final Decimal? multiplier;
}

List<_ClassificationVector> _readVectors() {
  return [
    for (final line in File(
      'test/ticker_classification_vectors.txt',
    ).readAsLinesSync())
      if (line.isNotEmpty && !line.startsWith('#')) _parseVector(line),
  ];
}

_ClassificationVector _parseVector(String line) {
  final parts = line.split('|');
  if (parts.length != 5) {
    throw FormatException('Malformed ticker classification vector: $line');
  }
  return _ClassificationVector(
    symbol: parts[0],
    assetType: parts[1],
    kind: parts[2],
    isGold: parts[3] == 'true',
    multiplier: parts[4].isEmpty ? null : Decimal.parse(parts[4]),
  );
}

PriceRequest _requestFor(_ClassificationVector vector) =>
    priceRequestForHolding(vector.symbol, vector.assetType);

void main() {
  final vectors = _readVectors();

  group('ticker classification parity', () {
    test('every vector carries the desktop normalized asset type', () {
      for (final vector in vectors) {
        expect(
          _requestFor(vector).normalizedAssetType,
          vector.kind,
          reason: '${vector.symbol} / ${vector.assetType}',
        );
      }
    });

    test('every assetTypes entry is represented by desktop-produced data', () {
      for (final assetType in assetTypes) {
        expect(
          vectors.any((vector) => vector.assetType == assetType),
          isTrue,
          reason: assetType,
        );
      }
    });

    test(
      'the desktop crypto classifications produce typed crypto requests',
      () {
        for (final vector in vectors.where(
          (vector) => vector.kind == 'CRYPTO',
        )) {
          final request = _requestFor(vector);
          expect(request, isA<CryptoPriceRequest>(), reason: vector.assetType);
          expect(
            (request as CryptoPriceRequest).code,
            vector.symbol.toUpperCase(),
          );
        }
      },
    );

    test('the desktop stock classifications produce typed share requests', () {
      for (final vector in vectors.where((vector) => vector.kind == 'STOCK')) {
        expect(
          _requestFor(vector),
          isA<SharesPriceRequest>(),
          reason: vector.assetType,
        );
      }
    });

    test('each desktop internal-gold code keeps its multiplier', () {
      final goldVectors = vectors.where((vector) => vector.isGold);

      expect(goldVectors.length, 8);
      for (final vector in goldVectors) {
        final request = _requestFor(vector);
        expect(request, isA<GoldPriceRequest>(), reason: vector.symbol);
        expect(
          (request as GoldPriceRequest).multiplier,
          vector.multiplier,
          reason: vector.symbol,
        );
        // The cache key a live price gets written under. Without this on
        // every request type, a gold holding's price would have nowhere of
        // its own to be cached — see lib/services/live_price_service.dart.
        expect(request.code, vector.symbol.toUpperCase(), reason: vector.symbol);
      }
    });

    test('a three-letter alphabetic code becomes a currency request', () {
      final vector = vectors.singleWhere(
        (vector) => vector.symbol == 'USD' && vector.assetType == 'Döviz',
      );

      final request = _requestFor(vector);
      expect(request, isA<CurrencyPriceRequest>());
      expect((request as CurrencyPriceRequest).code, 'USD');
    });

    test('TRY does not become a currency request', () {
      final vector = vectors.singleWhere((vector) => vector.symbol == 'TRY');

      expect(_requestFor(vector), isA<UnknownPriceRequest>());
    });

    test('an empty symbol is unknown', () {
      final vector = vectors.singleWhere((vector) => vector.symbol.isEmpty);

      expect(_requestFor(vector), isA<UnknownPriceRequest>());
    });

    test('an unknown asset type falls through as the desktop says', () {
      final vector = vectors.singleWhere(
        (vector) => vector.assetType == 'Bilinmeyen',
      );

      expect(_requestFor(vector), isA<UnknownPriceRequest>());
      expect(_requestFor(vector).normalizedAssetType, vector.kind);
    });

    test('Unicode alphabetic currency codes follow Python isalpha', () {
      final vector = vectors.singleWhere((vector) => vector.symbol == 'ÄBC');

      expect(_requestFor(vector), isA<CurrencyPriceRequest>());
    });
  });
}
