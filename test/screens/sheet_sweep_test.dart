/// Every sheet, under the same conditions every tab is held to.
///
/// **The layer under `tab_sweep_test.dart`.** That file found six defects by
/// opening the four tabs no test had ever built. Everything reached by
/// TAPPING one of those tabs — the forms, the buy and sell sheets, pay-debt,
/// subscriptions — was still in no accessibility or layout sweep at all. The
/// blind spot was the same one, a level down.
///
/// **Opened through `show...Sheet` rather than by tapping a path to it.**
/// The tab sweep drives the shell by its visible text, which makes it
/// language-dependent in a way the rest of the suite is not and which it has
/// to carry two label lists to keep honest. A sheet has a function that opens
/// it; calling that function is a seam the labels cannot rot out from under,
/// and it also means a sheet is covered here the day it is written rather
/// than the day something links to it.
///
/// What this still cannot see is the same thing no guideline can: reading
/// order, and whether a label that exists is any good.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/add_account_sheet.dart';
import 'package:archlence_mobile/screens/add_transaction_sheet.dart';
import 'package:archlence_mobile/screens/asset_sheets.dart';
import 'package:archlence_mobile/screens/budget_line_sheet.dart';
import 'package:archlence_mobile/screens/pay_debt_sheet.dart';
import 'package:archlence_mobile/screens/savings_sheets.dart';
import 'package:archlence_mobile/screens/subscription_sheet.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/asset_service.dart';
import 'package:archlence_mobile/services/recurring_service.dart';
import 'package:archlence_mobile/services/savings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  late ArchlenceDatabase db;
  late AppServices services;

  late Account cash;
  late Account card;
  late Asset holding;
  late SavingsGoal goal;
  late RecurringPayment subscription;

  setUp(() {
    db = ArchlenceDatabase.memory();
    services = testServices(db);
  });

  tearDown(() => db.close());

  /// Everything the sheets need to draw a filled form rather than an empty
  /// one, and the rows they hang off.
  ///
  /// A sheet opened over an empty profile shows a disabled button and three
  /// blank fields, which passes all of this for the wrong reason.
  Future<void> seed() async {
    final cashId = await services.accounts.createAccount(
      name: 'Maaş Hesabı',
      accountType: AccountType.checking,
      initialBalance: 50000,
    );
    await services.accounts.createAccount(
      name: 'Bonus Kart',
      accountType: AccountType.creditCard,
      initialBalance: 2400,
      creditLimit: 20000,
    );
    await services.assetPurchases.createPurchase(
      assetName: 'Gram Altın',
      assetCode: 'GC=F',
      assetType: 'Altın',
      purchasePrice: 2000,
      quantity: 3,
      accountId: cashId,
    );
    await services.savings.createGoal(
      goalName: 'Tatil Fonu',
      targetAmount: 20000,
    );
    await services.recurring.insertRecurringPayment(
      name: 'Netflix Standart',
      amount: 229.99,
      category: 'Dijital Abonelik',
      frequency: RecurrenceFrequency.monthly,
      nextDueDate: DateTime.now().add(const Duration(days: 5)),
      accountId: cashId,
    );

    final accounts = await services.accounts.getAccounts();
    cash = accounts.firstWhere((a) => a.name == 'Maaş Hesabı');
    card = accounts.firstWhere((a) => a.name == 'Bonus Kart');
    holding = (await services.assets.getAllAssets()).first;
    goal = (await services.savings.getGoals()).first;
    subscription = (await services.recurring.getActiveRecurringPayments())
        .first;
  }

  /// The nine ways into a form, by the function that opens each.
  ///
  /// Built after [seed] so the four that take a row have one to take.
  Map<String, void Function(BuildContext)> openers() {
    final now = DateTime.now();
    return {
      'add account': (c) => showAddAccountSheet(c),
      'add transaction': (c) => showAddTransactionSheet(c),
      'add transaction, account preselected': (c) =>
          showAddTransactionSheet(c, preselectedAccountId: cash.id),
      'buy asset': (c) => showBuyAssetSheet(c),
      'sell asset': (c) => showSellAssetSheet(c, holding),
      'budget line': (c) =>
          showBudgetLineSheet(c, month: now.month, year: now.year),
      'pay debt': (c) => showPayDebtSheet(c, card),
      'new savings goal': (c) => showNewGoalSheet(c),
      'move money': (c) => showMoveMoneySheet(c, goal),
      'subscription': (c) => showSubscriptionSheet(c, subscription),
    };
  }

  /// Pumps a host with one button, presses it, and leaves the sheet open.
  ///
  /// The host's own button carries a label, so it cannot be the thing that
  /// fails the label guideline.
  Future<void> openSheet(
    WidgetTester tester,
    void Function(BuildContext) open, {
    Size size = const Size(1080, 2400),
    double textScale = 1.0,
    Locale? locale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    if (textScale != 1.0) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    await tester.pumpWidget(
      testApp(
        services,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('open the sheet'),
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open the sheet'));
    await tester.pumpAndSettle();
  }

  /// Runs [body] against every sheet, as its own test.
  void forEverySheet(
    String description,
    Future<void> Function(WidgetTester, void Function(BuildContext)) body,
  ) {
    group(description, () {
      // The names are needed before `seed()` has run, so the map is built
      // once here for its keys and again inside each test for its values.
      for (final name in const [
        'add account',
        'add transaction',
        'add transaction, account preselected',
        'buy asset',
        'sell asset',
        'budget line',
        'pay debt',
        'new savings goal',
        'move money',
        'subscription',
      ]) {
        testWidgets(name, (tester) async {
          await seed();
          await body(tester, openers()[name]!);
        });
      }
    });
  }

  forEverySheet('says what its controls are', (tester, open) async {
    await openSheet(tester, open);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  forEverySheet('has targets big enough to hit', (tester, open) async {
    await openSheet(tester, open);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  forEverySheet('keeps its text readable', (tester, open) async {
    await openSheet(tester, open);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  // These assert nothing on purpose: a RenderFlex that overflows raises, and
  // a raise inside a testWidgets body fails the test. What is checked is that
  // the sheet can be laid out at all under a setting the user chooses.
  forEverySheet('lays out at a 1.5x font scale', (tester, open) async {
    await openSheet(tester, open, textScale: 1.5);
  });

  forEverySheet('lays out at a 2.0x font scale', (tester, open) async {
    await openSheet(tester, open, textScale: 2.0);
  });

  forEverySheet('lays out on a 320dp phone', (tester, open) async {
    await openSheet(tester, open, size: const Size(960, 2400));
  });

  forEverySheet('lays out in Turkish', (tester, open) async {
    await openSheet(tester, open, locale: const Locale('tr'));
  });

  forEverySheet('lays out in Turkish at a 2.0x font scale', (
    tester,
    open,
  ) async {
    await openSheet(tester, open, textScale: 2.0, locale: const Locale('tr'));
  });
}
