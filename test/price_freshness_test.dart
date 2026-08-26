/// A pure function over an [AppLocalizations] instance, loaded directly —
/// no widget needed to prove what it says.
library;

import 'package:archlence_mobile/l10n/app_localizations.dart';
import 'package:archlence_mobile/ui/price_freshness.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations tr;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    tr = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  test('under a minute reads as just now', () {
    expect(priceAge(en, const Duration(seconds: 30)), 'just now');
    expect(priceAge(tr, const Duration(seconds: 30)), 'az önce');
  });

  test('minutes, below the hour boundary', () {
    expect(priceAge(en, const Duration(minutes: 3)), '3m ago');
    expect(priceAge(en, const Duration(minutes: 59)), '59m ago');
  });

  test('hours, below the day boundary', () {
    expect(priceAge(en, const Duration(hours: 1)), '1h ago');
    expect(priceAge(en, const Duration(hours: 23, minutes: 59)), '23h ago');
  });

  test('days, at and beyond the boundary', () {
    expect(priceAge(en, const Duration(days: 1)), '1d ago');
    expect(priceAge(en, const Duration(days: 9)), '9d ago');
    expect(priceAge(tr, const Duration(days: 2)), '2 gün önce');
  });

  test('a negative elapsed time — clock skew — reads as just now, not "-1m ago"', () {
    expect(priceAge(en, const Duration(minutes: -5)), 'just now');
  });
}
