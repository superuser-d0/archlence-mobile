/// Three screens driven into a real state, on a phone.
///
/// **The gap the three sweeps have, and cannot close.**
/// `tab_sweep_test.dart`, `sheet_sweep_test.dart` and `route_sweep_test.dart`
/// lay every screen out at 360dp and 320dp, at 1.5x and 2.0x, in both
/// languages — but each of them renders a screen in the state it OPENS in. A
/// calculator with no result. A calendar with no day selected. A holding with
/// no price yet.
///
/// The per-screen test files do drive those states, and they do it on
/// `pumpScreen`'s 800dp surface, which no phone has. So the intersection —
/// **a real state at a real width** — was covered by nothing at all, and held
/// three overflows:
///
/// | Site | Overflow at 360dp |
/// | --- | --- |
/// | `calculator_screens.dart` result row | 9 of the 12 assertions |
/// | `calendar_screen.dart` entry row | the unreadable-amount case |
/// | `assets_screen.dart` holding row | once a live price arrives |
///
/// They were found by moving `pumpScreen` to 360dp as an experiment, which is
/// written up in the roadmap under "What the 800dp surface was hiding". This
/// file is the cheap half of that experiment kept permanently: the three
/// states that broke, at the widths that broke them, without rewriting the
/// twenty-two tests that would need to learn to scroll.
///
/// **It is three states, not a policy.** If a fourth state turns out to
/// matter, it belongs here rather than in a wider surface change.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/assets_screen.dart';
import 'package:archlence_mobile/screens/calculator_screens.dart';
import 'package:archlence_mobile/screens/calendar_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// A CoinGecko/Frankfurter pair that prices one bitcoin well above its cost,
/// so the holding tile draws its Current column and its gain line — the state
/// the sweeps never reach.
Future<String> _fakeLiveGet(
  Uri uri, {
  Map<String, String> headers = const {},
}) async {
  if (uri.host == 'api.coingecko.com') return '{"bitcoin":{"usd":95000}}';
  if (uri.host == 'api.frankfurter.dev') {
    return '{"amount":1.0,"base":"TRY","date":"2026-08-30","rates":{"USD":0.0242}}';
  }
  throw StateError('unexpected host: ${uri.host}');
}

void main() {
  late ArchlenceDatabase db;
  late AppServices services;

  setUp(() {
    db = ArchlenceDatabase.memory();
    services = testServices(db);
  });

  tearDown(() => db.close());

  /// The widths and scales a phone actually is.
  ///
  /// Named rather than a bare list so a failure says which one it was under.
  const conditions = <String, ({Size size, double scale})>{
    '360dp': (size: Size(1080, 2400), scale: 1.0),
    '320dp': (size: Size(960, 2400), scale: 1.0),
    '360dp at 1.5x': (size: Size(1080, 2400), scale: 1.5),
    '360dp at 2.0x': (size: Size(1080, 2400), scale: 2.0),
  };

  Future<void> pumpAt(
    WidgetTester tester,
    AppServices graph,
    Widget screen,
    ({Size size, double scale}) at, {
    Locale? locale,
  }) async {
    tester.view.physicalSize = at.size;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    if (at.scale != 1.0) {
      tester.platformDispatcher.textScaleFactorTestValue = at.scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    await tester.pumpWidget(testApp(graph, screen, locale: locale));
    await tester.pumpAndSettle();
  }

  group('a calculator showing its result', () {
    for (final entry in conditions.entries) {
      testWidgets(entry.key, (tester) async {
        await pumpAt(
          tester,
          services,
          const InterestCalculatorScreen(),
          entry.value,
        );

        final fields = find.byType(TextField);
        for (final (i, value) in ['10000', '45', '32'].indexed) {
          await tester.enterText(fields.at(i), value);
        }
        await tester.pump();
        await tester.tap(find.text('CALCULATE'));
        await tester.pumpAndSettle();

        // The result rows are the thing being laid out. If they are not
        // there, this test is measuring an empty screen and proving nothing.
        expect(find.text('10.374,79 ₺'), findsOneWidget);
      });
    }
  });

  group('a calendar day whose amount cannot be read', () {
    for (final entry in conditions.entries) {
      testWidgets(entry.key, (tester) async {
        final accountId = await services.accounts.createAccount(
          name: 'Maaş Hesabı',
          accountType: AccountType.checking,
          initialBalance: 5000,
        );
        final now = DateTime.now();
        await services.transactions.addTransaction(
          accountId: accountId,
          amount: 500,
          transactionType: 'expense',
          category: 'Market',
          description: 'haftalık alışveriş',
          transactionDate: DateTime(now.year, now.month, 7),
        );
        // The same corruption `calendar_screen_test.dart` uses: an envelope
        // the field decryptor cannot open, so the row is drawn and the figure
        // is refused rather than invented.
        await db.customUpdate(
          'UPDATE transactions SET amount = ?',
          variables: [Variable<String>('AEADv1:not-an-envelope')],
          updates: const {},
        );

        await pumpAt(tester, services, const CalendarScreen(), entry.value);
        await tester.tap(find.text('7'));
        await tester.pumpAndSettle();

        expect(find.text('This amount cannot be read'), findsOneWidget);
      });
    }
  });

  group('a holding with a live price', () {
    for (final entry in conditions.entries) {
      testWidgets(entry.key, (tester) async {
        final live = testServices(db, httpGet: _fakeLiveGet);
        await live.assets.insertAsset(
          assetName: 'Bitcoin',
          assetCode: 'BTC',
          assetType: 'Kripto',
          purchasePrice: '1000000',
          quantity: '1',
        );

        await pumpAt(tester, live, const AssetsScreen(), entry.value);

        // Current rather than Cost: the tile is in the state that overflowed.
        expect(find.text('Current'), findsOneWidget);
      });
    }
  });
}
