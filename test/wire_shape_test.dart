/// Exactly what this app puts on the wire, pinned byte for byte.
///
/// **This exists because of a declaration, not a feature.** Google Play's
/// Data safety form is answered "no data collected, no data shared", and that
/// answer rests on one fact: nothing in an outgoing request distinguishes one
/// user from another. Two people holding bitcoin produce byte-identical
/// requests. No amount, no quantity, no value, no cost, no description, no
/// account name, no device or user identifier — and, on the two keyless
/// hosts, **no request headers at all**.
///
/// A false Data safety declaration is a policy violation rather than a typo,
/// so the claim is checked against the wire rather than against a reading of
/// the code. If someone later adds a user agent, a client id, an install id,
/// a fourth query parameter or a fourth host, this fails before the
/// declaration becomes untrue.
///
/// The strings below are the whole point. Do not relax an assertion to make
/// it pass — if the request changed, the declaration and
/// `lib/legal/privacy_policy.dart` have to change with it.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/assets_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/shares_api_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_platform_auth.dart';
import 'support/test_app.dart';

void main() {
  late ArchlenceDatabase db;
  late List<({Uri uri, Map<String, String> headers})> wire;

  Future<String> recorder(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    wire.add((uri: uri, headers: headers));
    if (uri.host == 'api.coingecko.com') {
      return '{"bitcoin":{"usd":95000},"pax-gold":{"usd":2600}}';
    }
    if (uri.host == 'api.frankfurter.dev') {
      return '{"amount":1.0,"base":"TRY","date":"2026-08-30",'
          '"rates":{"USD":0.0242,"EUR":0.0221}}';
    }
    return '{"data":[{"code":"THYAO","price":300.0}]}';
  }

  setUp(() {
    db = ArchlenceDatabase.memory();
    wire = [];
  });
  tearDown(() => db.close());

  /// Opening the Assets screen is the ONLY thing in this app that can cause a
  /// request. There is no timer, no background worker, and the manifest
  /// declares no service, receiver or provider — so there is no other moment
  /// to test.
  Future<void> openAssets(WidgetTester tester, AppServices services) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(services, const AssetsScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> hold(
    AppServices services,
    List<(String, String, String)> holdings,
  ) async {
    for (final (name, code, type) in holdings) {
      await services.assets.insertAsset(
        assetName: name,
        assetCode: code,
        assetType: type,
        purchasePrice: '1000',
        quantity: '2',
      );
    }
  }

  List<String> sent() => [for (final r in wire) r.uri.toString()];

  testWidgets('a profile with no holdings is silent', (tester) async {
    final services = testServices(db, httpGet: recorder);
    await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 5000,
    );
    await openAssets(tester, services);

    // Not "few requests" — none. An app that phones somewhere on start has a
    // different privacy story from one that phones somewhere when you ask it
    // to price something you own, and this is the second kind.
    expect(sent(), isEmpty);
  });

  testWidgets('crypto, gold and currency: two requests, no headers', (
    tester,
  ) async {
    final services = testServices(db, httpGet: recorder);
    await hold(services, [
      ('Bitcoin', 'BTC', 'Kripto'),
      ('Gram Altın', 'GRAM', 'Altın'),
      ('Dolar', 'USD', 'Döviz'),
      ('Euro', 'EUR', 'Döviz'),
    ]);
    await openAssets(tester, services);

    expect(sent(), [
      // Gold rides on the same CoinGecko call as crypto, priced through PAX
      // Gold, rather than costing a request of its own.
      'https://api.coingecko.com/api/v3/simple/price'
          '?ids=bitcoin%2Cpax-gold&vs_currencies=usd',
      // USD is here because the crypto leg converts through it, not because
      // the user holds dollars — they happen to hold both.
      'https://api.frankfurter.dev/v1/latest?from=TRY&to=EUR%2CUSD',
    ]);

    // The assertion the declaration rests on: nothing rides along. No user
    // agent of ours, no client id, no install id, no cookie.
    for (final request in wire) {
      expect(
        request.headers,
        isEmpty,
        reason: 'A header was added to ${request.uri.host}. Anything sent '
            'alongside a symbol list is a candidate identifier, and the Data '
            'safety declaration says there is none.',
      );
    }
  });

  testWidgets('a share holding with no key sends nothing to its provider', (
    tester,
  ) async {
    final services = testServices(db, httpGet: recorder);
    await hold(services, [
      ('Türk Hava Yolları', 'THYAO', 'Hisse'),
      ('Garanti', 'GARAN', 'Hisse'),
    ]);
    await openAssets(tester, services);

    // Two share holdings, and the host is not contacted at all. The secure
    // store is not even read — see `LivePriceService.priceHoldings`.
    expect(sent(), isEmpty);
  });

  testWidgets('with a key, the shares call carries it and nothing else', (
    tester,
  ) async {
    final services = testServices(
      db,
      httpGet: recorder,
      sharesApiKey: SharesApiKey(
        storage: const FakeSecureStorage({
          'archlence.shares-api-key': 'THE-USERS-OWN-KEY',
        }),
      ),
    );
    await hold(services, [
      ('Türk Hava Yolları', 'THYAO', 'Hisse'),
      ('Garanti', 'GARAN', 'Hisse'),
    ]);
    await openAssets(tester, services);

    expect(sent(), [
      'https://www.nosyapi.com/apiv2/service/economy/bist/exchange-rate'
          '?code=GARAN%2CTHYAO',
    ]);
    // The key goes in a header rather than the query string, so it stays out
    // of proxy logs and browser history; and it is the ONLY header.
    expect(wire.single.headers, {'X-NSYP': 'THE-USERS-OWN-KEY'});
  });

  testWidgets('symbol lists are sorted, so they carry no ordering', (
    tester,
  ) async {
    final services = testServices(db, httpGet: recorder);
    // Inserted in an order chosen to be wrong alphabetically in both lists.
    await hold(services, [
      ('Euro', 'EUR', 'Döviz'),
      ('Dolar', 'USD', 'Döviz'),
    ]);
    await openAssets(tester, services);

    // EUR before USD despite EUR being inserted first only by luck — the
    // point is that the request cannot be used to reconstruct WHEN each
    // holding was added, which a raw insertion order would leak.
    expect(sent(), [
      'https://api.frankfurter.dev/v1/latest?from=TRY&to=EUR%2CUSD',
    ]);
  });

  testWidgets('two users holding the same things send the same bytes', (
    tester,
  ) async {
    // The declaration in one test. If these two ever differ, something in
    // the request identifies the profile rather than the question, and
    // "no data collected" stops being true.
    final first = testServices(db, httpGet: recorder);
    await hold(first, [('Bitcoin', 'BTC', 'Kripto')]);
    await openAssets(tester, first);
    final fromFirst = sent();

    final otherDb = ArchlenceDatabase.memory();
    addTearDown(otherDb.close);
    // Tear the first tree down before building the second. Pumping a widget
    // of the same type reuses the element, `initState` does not run again,
    // and the second profile would silently make no request at all — a green
    // test proving nothing, which is the failure mode this file exists to
    // avoid.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    wire = [];
    final second = testServices(otherDb, httpGet: recorder);
    // A different profile: different account, different amounts, different
    // name on the holding. Same asset.
    await second.accounts.createAccount(
      name: 'Başka Biri',
      accountType: AccountType.checking,
      initialBalance: 999999,
    );
    await second.assets.insertAsset(
      assetName: 'BTC uzun vade',
      assetCode: 'BTC',
      assetType: 'Kripto',
      purchasePrice: '4200000',
      quantity: '0.137',
    );
    await openAssets(tester, second);

    expect(sent(), fromFirst);
  });
}
