/// The first run.
library;

import 'package:archlence_mobile/app_services.dart';
import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/crypto/key_provider.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/screens/onboarding_screen.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/widgets/surfaces.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixed_key_provider.dart';
import '../support/test_app.dart';

void main() {
  late ArchlenceDatabase db;

  setUp(() => db = ArchlenceDatabase.memory());
  tearDown(() => db.close());

  AppServices servicesWith(KeyProtectionStatus? status) =>
      AppServices.forDatabase(
        db,
        FieldCrypto(FixedKeyProvider.arbitrary()),
        keyProtection: status,
      );

  Future<AppServices> pump(
    WidgetTester tester, {
    KeyProtectionStatus? status = const KeyProtectionStatus(
      KeyProtectionMethod.androidKeystore,
      true,
    ),
    VoidCallback? onFinished,
    Size size = const Size(800, 2400),
  }) async {
    final services = servicesWith(status);
    await pumpScreen(
      tester,
      services,
      OnboardingScreen(onFinished: onFinished ?? () {}),
      size: size,
    );
    return services;
  }

  Future<void> next(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Next').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next').last);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String value) async {
    final field = find.ancestor(
      of: find.text(label),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field.first);
    await tester.pumpAndSettle();
    await tester.enterText(field.first, value);
    await tester.pumpAndSettle();
  }

  group('the gate', () {
    test('asks the data, not a preference flag', () async {
      // "Has the user seen a welcome screen" is the wrong question: a flag
      // would survive a wiped or restored-empty database and strand a fresh
      // install on a dashboard of zeroes with nothing to add.
      final services = servicesWith(null);
      expect(await services.isSetUp, isFalse);

      await services.accounts.createAccount(
        name: 'Nakit',
        accountType: AccountType.checking,
        initialBalance: 0,
      );
      expect(await services.isSetUp, isTrue);
    });

    test('an account with nothing in it still counts as set up', () async {
      // The gate is about having somewhere for money to go, not having money.
      final services = servicesWith(null);
      await services.accounts.createAccount(
        name: 'Boş',
        accountType: AccountType.checking,
        initialBalance: 0,
      );
      expect(await services.isSetUp, isTrue);
    });
  });

  group('what it says', () {
    testWidgets('names the trade the user is making', (tester) async {
      // Local-first cuts both ways, and the second half is the part a welcome
      // screen is tempted to leave out.
      await pump(tester);

      // Title AND body for each: asserting one leaves the other free to be
      // emptied without a test noticing, which is exactly how the two halves
      // of this trade could drift apart.
      expect(find.text('No account, no server'), findsOneWidget);
      expect(find.textContaining('nothing to sign in to'), findsOneWidget);
      expect(find.text('Which means backups are on you'), findsOneWidget);
      expect(find.textContaining('the data goes with it'), findsOneWidget);
    });

    testWidgets('reports a hardware key store as one', (tester) async {
      await pump(tester);
      await next(tester);

      expect(find.text('Android Keystore'), findsOneWidget);
      expect(
        find.textContaining('Held by the operating system'),
        findsOneWidget,
      );
    });

    testWidgets('does not flatter a file fallback', (tester) async {
      // A welcome screen that implied Keystore protection where there is none
      // would be the app's first lie.
      await pump(
        tester,
        status: const KeyProtectionStatus(
          KeyProtectionMethod.ownerOnlyFile,
          false,
          KeyProtectionWarning.osKeyStoreUnavailable,
        ),
      );
      await next(tester);

      expect(find.textContaining('weaker than the key store'), findsOneWidget);
      expect(
        find.textContaining('The OS key store is unavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('Held by the operating system'), findsNothing);
    });

    testWidgets('says it does not know rather than assuming the best', (
      tester,
    ) async {
      await pump(tester, status: null);
      await next(tester);

      expect(find.text('Key location unknown'), findsOneWidget);
      expect(
        find.textContaining('could not tell where the key ended up'),
        findsOneWidget,
      );
      expect(find.text('Android Keystore'), findsNothing);
      expect(find.textContaining('Held by the operating system'), findsNothing);
    });
  });

  group('the first account', () {
    Future<AppServices> toLastPage(
      WidgetTester tester, {
      VoidCallback? onFinished,
    }) async {
      final services = await pump(tester, onFinished: onFinished);
      await next(tester);
      await next(tester);
      return services;
    }

    testWidgets('is created, not merely offered', (tester) async {
      // Nothing in the app works without one, so an onboarding that ends
      // without an account has not finished its job.
      var finished = false;
      final services = await toLastPage(
        tester,
        onFinished: () => finished = true,
      );
      await type(tester, 'Name', 'Maaş Hesabı');
      await type(tester, 'What is in it now', '17.300,50');
      await tester.tap(find.text('Start using Archlence'));
      await tester.pumpAndSettle();

      final account = (await services.accounts.getAccounts()).single;
      expect(account.name, 'Maaş Hesabı');
      expect(account.balance, Decimal.parse('17300.50'));
      expect(finished, isTrue);
      expect(await services.isSetUp, isTrue);
    });

    testWidgets('an empty balance is allowed and means zero', (tester) async {
      final services = await toLastPage(tester);
      await tester.tap(find.text('Start using Archlence'));
      await tester.pumpAndSettle();

      expect(
        (await services.accounts.getAccounts()).single.balance,
        Decimal.zero,
      );
    });

    testWidgets('a blank name is refused and the gate stays shut', (
      tester,
    ) async {
      var finished = false;
      final services = await toLastPage(
        tester,
        onFinished: () => finished = true,
      );
      await type(tester, 'Name', '   ');
      await tester.tap(find.text('Start using Archlence'));
      await tester.pumpAndSettle();

      expect(find.text('Give the account a name.'), findsOneWidget);
      expect(await services.accounts.getAccounts(), isEmpty);
      expect(finished, isFalse, reason: 'the app must not open empty');
    });

    testWidgets('text that is not a number is refused, never read as zero', (
      tester,
    ) async {
      var finished = false;
      final services = await toLastPage(
        tester,
        onFinished: () => finished = true,
      );
      await type(tester, 'What is in it now', ',,,');
      await tester.tap(find.text('Start using Archlence'));
      await tester.pumpAndSettle();

      expect(find.text('That is not an amount.'), findsOneWidget);
      expect(await services.accounts.getAccounts(), isEmpty);
      expect(finished, isFalse);
    });
  });

  group('the keyboard', () {
    // A PHONE-SHAPED surface, unlike every other test in this file. The tall
    // 2400px one exists so a finder can reach anything without scrolling, and
    // that is exactly what hides this: with room for the whole page there is
    // nothing for a keyboard to push off the bottom.
    const phone = Size(360, 800);
    const keyboard = 320.0;

    testWidgets('does not slice the primary action in half', (tester) async {
      // WHAT THIS CAUGHT. `Scaffold` shrinks the body by the keyboard's
      // height and the page scrolls, so the button ended up straddling the
      // keyboard's top edge: about ten pixels of gradient with the page dots
      // sitting on top of it. Not hidden, which the user would scroll for —
      // SLICED, which reads as a rendering fault, on the first screen anyone
      // ever fills in. Found by driving an emulator by hand.
      await pump(tester, size: phone);
      await next(tester);
      await next(tester);

      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      await tester.pumpAndSettle();

      final button = find.widgetWithText(
        GradientButton,
        'Start using Archlence',
      );
      expect(button, findsOneWidget);
      final rect = tester.getRect(button);

      // Fully above the keyboard, and at its real height rather than a
      // sliver. Both halves matter: asserting only the height would pass on
      // a button drawn entirely underneath the keyboard.
      expect(
        rect.bottom,
        lessThanOrEqualTo(phone.height - keyboard),
        reason: 'the button is under the keyboard',
      );
      expect(
        rect.height,
        greaterThan(32),
        reason: 'the button is clipped to a sliver',
      );
    });

    testWidgets('and the field being typed into stays on screen', (
      tester,
    ) async {
      // The reason the fix scrolls the LEAST that reveals the button rather
      // than jumping to the end of the page: a taller keyboard or a larger
      // font must not push the field out of sight to make room.
      await pump(tester, size: phone);
      await next(tester);
      await next(tester);

      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      await tester.pumpAndSettle();

      final field = tester.getRect(find.byType(TextField).last);
      expect(field.bottom, lessThanOrEqualTo(phone.height - keyboard));
      expect(field.top, greaterThanOrEqualTo(0));
    });
  });
}
