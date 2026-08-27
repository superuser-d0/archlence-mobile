/// Every screen, at every width the app can actually be opened at.
///
/// **A whole-app rule tested as one**, like `dead_controls_test.dart` and
/// `accessibility_test.dart`. A new screen that only works on a 360dp portrait
/// phone should fail here rather than on somebody's tablet.
///
/// **What a widget test can prove about layout, and what it cannot.** It can
/// prove that nothing OVERFLOWS: a `RenderFlex` that runs past its constraints
/// throws in a test, which is the same defect that paints a yellow-and-black
/// stripe in a debug build and silently clips in a release one. It cannot say
/// whether the result looks good. So this file holds the line on breakage and
/// on one measurable rule — how wide a column of text is allowed to get — and
/// leaves taste to a person with a tablet.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/app_shell.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/backup_screen.dart';
import 'package:archlence_mobile/screens/budget_screen.dart';
import 'package:archlence_mobile/screens/calculator_screens.dart';
import 'package:archlence_mobile/screens/calendar_screen.dart';
import 'package:archlence_mobile/screens/category_settings_screen.dart';
import 'package:archlence_mobile/screens/locked_screen.dart';
import 'package:archlence_mobile/screens/onboarding_screen.dart';
import 'package:archlence_mobile/screens/savings_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/recurring_service.dart';
import 'package:archlence_mobile/theme/obsidian_prime.dart';
import 'package:archlence_mobile/widgets/surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// The sizes, in logical pixels, an Android build really gets opened at.
///
/// Material's breakpoints: compact below 600, medium to 839, expanded above.
/// The landscape phone is here because it is the one a user reaches by
/// turning the device they already have, and it is SHORT rather than wide —
/// a different failure from a tablet's.
const Map<String, Size> _surfaces = {
  'phone portrait': Size(360, 800),
  'phone landscape': Size(800, 360),
  'small tablet': Size(600, 960),
  'tablet': Size(840, 1120),
  'large tablet': Size(1280, 800),
};

void main() {
  late ArchlenceDatabase db;
  late AppServices services;

  setUp(() {
    db = ArchlenceDatabase.memory();
    services = testServices(db);
  });

  tearDown(() => db.close());

  Future<void> seed() async {
    final id = await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 25000,
    );
    await services.accounts.createAccount(
      name: 'Kart',
      accountType: AccountType.creditCard,
      initialBalance: 3500,
      creditLimit: 20000,
    );
    await services.transactions.addTransaction(
      accountId: id,
      amount: 1250,
      transactionType: 'expense',
      category: 'Market',
      description: 'haftalık alışveriş',
    );
    await services.savings.createGoal(goalName: 'Tatil', targetAmount: 20000);
    await services.recurring.insertRecurringPayment(
      name: 'Netflix',
      amount: 229.99,
      category: 'Dijital Abonelik',
      frequency: RecurrenceFrequency.monthly,
      nextDueDate: DateTime.now().add(const Duration(days: 5)),
      accountId: id,
    );
  }

  final screens = <String, Widget Function()>{
    'shell': () => const AppShell(),
    // Onboarding and the lock screen are in this list because they were NOT
    // in its first version, and the tablet run found them stretched edge to
    // edge — onboarding being the first thing a new user reads. A list of
    // screens a test walks is only as good as its completeness.
    'onboarding': () => OnboardingScreen(onFinished: () {}),
    'locked': () => LockedScreen(
      onAuthenticate: () async => true,
      onUnlocked: () {},
    ),
    'category settings': () => const CategorySettingsScreen(),
    'calendar': () => const CalendarScreen(),
    'budget': () => const BudgetScreen(),
    'savings': () => const SavingsScreen(),
    'backup': () => const BackupScreen(),
    'basic calculator': () => const BasicCalculatorScreen(),
    'loan calculator': () => const LoanCalculatorScreen(),
  };

  Future<void> openAt(
    WidgetTester tester,
    Widget screen,
    Size size,
  ) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(services, screen));
    await tester.pumpAndSettle();
  }

  group('a line of text never gets wider than it can be read at', () {
    /// The widest card on the screen, which is the widest a line inside it
    /// can be.
    ///
    /// Measured on the CARD rather than on a `Text`, because a short label
    /// takes only the width it needs and would pass this at any screen size —
    /// the container is what actually decides how long a line is allowed to
    /// get.
    double widestCard(WidgetTester tester) {
      var widest = 0.0;
      for (final element in find.byType(AppCard).evaluate()) {
        final width = tester.getSize(find.byWidget(element.widget)).width;
        if (width > widest) widest = width;
      }
      return widest;
    }

    for (final screen in {
      'category settings': () => const CategorySettingsScreen(),
      'budget': () => const BudgetScreen(),
      'backup': () => const BackupScreen(),
      'loan calculator': () => const LoanCalculatorScreen(),
    }.entries) {
      testWidgets('${screen.key} is capped on a large tablet', (tester) async {
        await seed();
        await openAt(tester, screen.value(), const Size(1280, 800));
        // Before this cap the explainer on Category Settings ran 1198dp — one
        // line of about 150 characters, where Material asks for 40 to 75.
        expect(
          widestCard(tester),
          lessThanOrEqualTo(readableContentWidth),
          reason: screen.key,
        );
      });

      testWidgets('${screen.key} still fills a phone', (tester) async {
        // The other half of the rule, and the one a max-width alone would
        // get wrong: a 360dp phone must NOT gain margins it did not have.
        await seed();
        await openAt(tester, screen.value(), const Size(360, 800));
        expect(
          widestCard(tester),
          360 - 2 * Spacing.containerMargin,
          reason: screen.key,
        );
      });
    }
  });

  for (final surface in _surfaces.entries) {
    group('at ${surface.key}', () {
      for (final screen in screens.entries) {
        testWidgets('${screen.key} lays out without overflowing', (
          tester,
        ) async {
          await seed();
          await openAt(tester, screen.value(), surface.value);
          // `pumpAndSettle` above rethrows a layout exception, so reaching
          // here is the assertion. Named explicitly so a reader knows this
          // test is not empty.
          expect(tester.takeException(), isNull);
        });
      }
    });
  }
}
