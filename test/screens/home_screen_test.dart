/// The Home screen against a real service graph.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/home_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/recurring_service.dart';
import 'package:archlence_mobile/widgets/surfaces.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  late ArchlenceDatabase db;
  late AppServices services;

  setUp(() {
    db = ArchlenceDatabase.memory();
    services = testServices(db);
  });

  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) =>
      pumpScreen(tester, services, const HomeScreen());

  testWidgets('the ring carries net worth and the stats its components', (
    tester,
  ) async {
    await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 17300,
    );
    await services.accounts.createAccount(
      name: 'Kart',
      accountType: AccountType.creditCard,
      initialBalance: 3500,
      creditLimit: 20000,
    );

    await pump(tester);

    expect(find.text('13.800,00 ₺'), findsOneWidget, reason: 'net worth');
    expect(find.text('17.300,00 ₺'), findsOneWidget, reason: 'cash');
    expect(find.text('3.500,00 ₺'), findsOneWidget, reason: 'card debt');
  });

  testWidgets('an empty database reads as zero, which is the truth', (
    tester,
  ) async {
    // Distinct from the unreadable case below: nothing recorded really does
    // mean nothing, and saying so is correct rather than evasive.
    await pump(tester);
    expect(find.text('0,00 ₺'), findsWidgets);
  });

  testWidgets('subscriptions come from the recurring service', (tester) async {
    final accountId = await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 10000,
    );
    await services.recurring.insertRecurringPayment(
      name: 'Netflix',
      amount: 229.99,
      category: 'Dijital Abonelik',
      frequency: RecurrenceFrequency.monthly,
      nextDueDate: DateTime(2026, 9, 15),
      accountId: accountId,
    );

    await pump(tester);

    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('229,99 ₺'), findsOneWidget);
    expect(find.text('Next on 15.09.2026'), findsOneWidget);
  });

  testWidgets('a subscription that will not decrypt says so', (tester) async {
    final accountId = await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 10000,
    );
    await services.recurring.insertRecurringPayment(
      name: 'Netflix',
      amount: 229.99,
      frequency: RecurrenceFrequency.monthly,
      nextDueDate: DateTime(2026, 9, 15),
      accountId: accountId,
    );
    await db.customUpdate(
      "UPDATE recurring_payments SET name = ?, amount = ?",
      variables: [
        Variable<String>('AEADv1:broken'),
        Variable<String>('AEADv1:broken'),
      ],
      updates: const {},
    );

    await pump(tester);

    expect(find.text('Unreadable subscription'), findsOneWidget);
    expect(find.text('unreadable'), findsOneWidget);
    expect(find.text('229,99 ₺'), findsNothing);
  });

  testWidgets('no subscriptions says so rather than showing an empty card', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('Nothing recurring yet'), findsOneWidget);
  });

  testWidgets('no change chip is drawn when there is no change to report', (
    tester,
  ) async {
    // Caught on the emulator, not in a test: an empty label still drew the
    // chip, so the ring showed a bare green pill with an upward arrow and no
    // number — which reads as a gain.
    await services.accounts.createAccount(
      name: 'Maaş',
      accountType: AccountType.checking,
      initialBalance: 100,
    );

    await pump(tester);

    expect(find.byType(TrendChip), findsNothing);
  });

  testWidgets('the insight cards draw no figure they cannot compute', (
    tester,
  ) async {
    // The mockup fills both with numbers. Those services are not ported, and
    // a health score with nothing behind it would be the most confidently
    // wrong thing on the screen.
    await pump(tester);

    expect(find.text('Algorithmic Forecast'), findsOneWidget);
    expect(find.text('Financial Health Score'), findsOneWidget);
    expect(find.text('NOT YET'), findsNWidgets(2));
    expect(find.text('72'), findsNothing);
  });
}
