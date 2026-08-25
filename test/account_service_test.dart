/// The multi-account and credit-card rules, ported from the desktop's
/// `tests/test_account_service.py`.
///
/// The acceptance scenario the desktop encodes — a card spend lowering net
/// worth by exactly its amount — needs the transaction service, which is not
/// ported yet. What is provable without it is here: the sign convention at
/// the point an account is opened, the derived debt and limit fields, the
/// spending rule itself, and card payment.
///
/// Accounts that a service would refuse to create (a legacy row with no
/// account type, a card with no limit) are inserted with direct SQL, exactly
/// as the desktop's fixtures do: the point is to set up a state that exists
/// in real databases, not to exercise the validation that prevents new ones.
library;

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/balance_events.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:decimal/decimal.dart';
// Only the variable binder: drift also exports `isNull`/`isNotNull` as SQL
// expression builders, which would shadow the matchers of the same name.
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';

void main() {
  late ArchlenceDatabase db;
  late AccountService accounts;

  setUp(() {
    db = ArchlenceDatabase.memory();
    accounts = AccountService(db, FieldCrypto(FixedKeyProvider.arbitrary()));
  });

  tearDown(() => db.close());

  Future<List<Map<String, Object?>>> rawAccounts() async {
    final rows = await db
        .customSelect('SELECT * FROM accounts ORDER BY id')
        .get();
    return [for (final row in rows) row.data];
  }

  Future<Map<String, Object?>> rawAccount(int id) async {
    return (await rawAccounts()).firstWhere((row) => row['id'] == id);
  }

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  /// Inserts a row the service layer would reject, for states that exist in
  /// databases written by older versions.
  Future<int> insertLegacyAccount({
    required String name,
    required String type,
    required double balance,
    String? accountType,
    double creditLimit = 0,
    int isFrozen = 0,
  }) {
    return db.customInsert(
      'INSERT INTO accounts (name, type, balance, account_type, credit_limit, '
      'is_frozen) VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        Variable<String>(name),
        Variable<String>(type),
        Variable<double>(balance),
        // The column is NOT NULL with a default, so a genuinely old row still
        // carries a value; the empty string stands for "never classified".
        Variable<String>(accountType ?? ''),
        Variable<double>(creditLimit),
        Variable<int>(isFrozen),
      ],
    );
  }

  Decimal money(String value) => fiat(value);

  group('opening an account', () {
    test('a card stores its debt as a negative balance', () async {
      final id = await accounts.createAccount(
        name: 'Test Kart',
        accountType: AccountType.creditCard,
        initialBalance: 1500,
        creditLimit: 10000,
      );

      expect((await rawAccount(id))['balance'], -1500.0);
      expect((await rawAccount(id))['credit_limit'], 10000.0);

      final account = (await accounts.getAccount(id))!;
      expect(account.debt, money('1500'));
      expect(account.availableLimit, money('8500'));
      expect(account.balance, money('-1500'));
    });

    test('a checking account ignores the card-only fields', () async {
      final id = await accounts.createAccount(
        name: 'Vadesiz',
        accountType: AccountType.checking,
        initialBalance: 2000,
        creditLimit: 5000,
        statementDate: 10,
      );

      final account = (await accounts.getAccount(id))!;
      expect(account.balance, money('2000'));
      expect(account.creditLimit, Decimal.zero);
      expect(account.statementDate, isNull);
      expect((await rawAccount(id))['credit_limit'], 0.0);
      expect((await rawAccount(id))['statement_date'], isNull);
    });

    test('an opening balance is recorded in the ledger', () async {
      final id = await accounts.createAccount(
        name: 'Maaş',
        accountType: AccountType.checking,
        initialBalance: '1234.56',
      );

      final event = await db
          .customSelect('SELECT * FROM balance_events')
          .getSingle();
      expect(event.read<String>('entity_type'), accountEntity);
      expect(event.read<int>('entity_id'), id);
      expect(event.read<double>('delta'), 1234.56);
      expect(event.read<double>('resulting_value'), 1234.56);
      expect(event.read<String>('source'), 'account_opened');
    });

    test('rejects a nameless account', () {
      expect(
        () => accounts.createAccount(
          name: '   ',
          accountType: AccountType.checking,
        ),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.emptyName,
          ),
        ),
      );
    });

    test('rejects a card with no limit', () {
      expect(
        () => accounts.createAccount(
          name: 'Kart',
          accountType: AccountType.creditCard,
          creditLimit: 0,
        ),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.creditLimitRequired,
          ),
        ),
      );
    });

    test('rejects an opening debt larger than the limit', () {
      expect(
        () => accounts.createAccount(
          name: 'Kart',
          accountType: AccountType.creditCard,
          initialBalance: 200,
          creditLimit: 100,
        ),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.openingDebtExceedsLimit,
          ),
        ),
      );
    });

    test('rejects a statement day outside 1-31', () {
      expect(
        () => accounts.createAccount(
          name: 'Kart',
          accountType: AccountType.creditCard,
          creditLimit: 1000,
          statementDate: 45,
        ),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.invalidStatementDay,
          ),
        ),
      );
    });

    test('reads an empty statement day as "not set"', () async {
      final id = await accounts.createAccount(
        name: 'Kart',
        accountType: AccountType.creditCard,
        creditLimit: 1000,
        statementDate: '',
      );
      expect((await accounts.getAccount(id))!.statementDate, isNull);
    });

    test('rejects a non-finite opening amount', () {
      expect(
        () => accounts.createAccount(
          name: 'Kart',
          accountType: AccountType.checking,
          initialBalance: double.nan,
        ),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.invalidAmount,
          ),
        ),
      );
    });

    test('nothing is written when validation fails', () async {
      await expectLater(
        () => accounts.createAccount(
          name: 'Kart',
          accountType: AccountType.creditCard,
          initialBalance: 200,
          creditLimit: 100,
        ),
        throwsA(isA<AccountError>()),
      );
      expect(await count('accounts'), 0);
      expect(await count('balance_events'), 0);
    });
  });

  group('card numbers', () {
    test('only the last four digits and the network are stored', () async {
      final id = await accounts.createAccount(
        name: 'Test Kart',
        accountType: AccountType.creditCard,
        initialBalance: 500,
        creditLimit: 5000,
        cardNumberFull: '4532 1234 5678 9012',
      );

      final row = await rawAccount(id);
      expect(row['card_number_full'], isNull);
      expect(row['expiry_date'], isNull);
      expect(row['cvc_code'], isNull);
      expect(row['masked_number'], '**** **** **** 9012');
      expect(row['network_logo'], 'assets/visa.png');

      final account = (await accounts.getAccount(id))!;
      expect(account.maskedNumber, '**** **** **** 9012');
      expect(account.hasCardNumber, isTrue);
    });

    test('a card opened without a number reads as unknown', () async {
      final id = await accounts.createAccount(
        name: 'Kart',
        accountType: AccountType.creditCard,
        creditLimit: 5000,
      );
      final account = (await accounts.getAccount(id))!;
      expect(account.maskedNumber, unknownMaskedNumber);
      expect(account.hasCardNumber, isFalse);
      expect(account.networkLogo, '');
    });

    test('Troy is matched before Mastercard', () {
      // 9792 also starts with 9, but a Troy card's second rule-matching digit
      // is the trap: checking Mastercard's single '5' or Visa's '4' first
      // would be harmless here, while checking a one-digit rule before
      // Troy's four-digit one leaves 9792 unmatched.
      expect(
        AccountService.cardNetworkLogo('9792 1234 5678 9012'),
        'assets/troy.png',
      );
      expect(
        AccountService.cardNetworkLogo('5555 4444 3333 2222'),
        'assets/mastercard.png',
      );
      expect(
        AccountService.cardNetworkLogo('2221 0000 0000 0009'),
        'assets/mastercard.png',
      );
      expect(
        AccountService.cardNetworkLogo('4532 1234 5678 9012'),
        'assets/visa.png',
      );
      expect(AccountService.cardNetworkLogo('6011000000000004'), '');
      expect(AccountService.cardNetworkLogo('no digits here'), '');
      expect(AccountService.cardNetworkLogo(null), '');
    });
  });

  group('derived fields on rows from older versions', () {
    test('a null preference column reads as its schema default', () async {
      // The two preference columns were added by later ALTER TABLEs. Rows
      // that predate them, and rows a restored backup wrote without them,
      // hold NULL rather than the column default — so the fallback here is
      // what a real database exercises, not a defensive nicety.
      final id = await db.customInsert(
        'INSERT INTO accounts (name, type, balance, account_type, '
        'credit_limit, is_frozen, online_payments_enabled) '
        'VALUES (?, ?, ?, ?, ?, NULL, NULL)',
        variables: [
          Variable<String>('Eski Kart'),
          Variable<String>('credit'),
          Variable<double>(-100),
          Variable<String>('credit_card'),
          Variable<double>(1000),
        ],
      );

      final account = (await accounts.getAccount(id))!;
      expect(account.isFrozen, isFalse);
      // Absent means enabled: the column arrived with DEFAULT 1, so a row
      // written before it existed was one where payments were allowed.
      expect(account.onlinePaymentsEnabled, isTrue);
    });

    test('an unclassified row is typed from its legacy type column', () async {
      await insertLegacyAccount(
        name: 'Eski Nakit',
        type: 'cash',
        balance: 1000,
      );
      await insertLegacyAccount(
        name: 'Eski Kart',
        type: 'credit',
        balance: -750,
      );

      final byName = {
        for (final account in await accounts.getAccounts())
          account.name: account,
      };
      expect(byName['Eski Nakit']!.accountType, AccountType.checking);
      expect(byName['Eski Nakit']!.balance, money('1000'));
      expect(byName['Eski Kart']!.accountType, AccountType.creditCard);
      expect(byName['Eski Kart']!.debt, money('750'));
    });

    test('an overpaid card shows no debt and a raised limit', () async {
      // A positive balance on a card means it is in credit. Reporting that as
      // negative debt would put a minus sign in front of a figure the screen
      // labels "debt".
      final id = await insertLegacyAccount(
        name: 'Fazla Ödenmiş',
        type: 'credit',
        balance: 250,
        accountType: 'credit_card',
        creditLimit: 1000,
      );
      final account = (await accounts.getAccount(id))!;
      expect(account.debt, Decimal.zero);
      expect(account.availableLimit, money('1250'));
    });

    test('debt beyond the limit never reports a negative limit', () async {
      final id = await insertLegacyAccount(
        name: 'Limit Aşımı',
        type: 'credit',
        balance: -1500,
        accountType: 'credit_card',
        creditLimit: 1000,
      );
      final account = (await accounts.getAccount(id))!;
      expect(account.debt, money('1500'));
      expect(account.availableLimit, Decimal.zero);
    });
  });

  group('net worth', () {
    test('equals the plain sum of the balance column', () async {
      // The invariant behind the sign convention. If it breaks, something
      // that writes accounts.balance has broken the rule.
      await accounts.createAccount(
        name: 'Vadesiz',
        accountType: AccountType.checking,
        initialBalance: 4000,
      );
      await accounts.createAccount(
        name: 'Kart',
        accountType: AccountType.creditCard,
        initialBalance: 1200,
        creditLimit: 10000,
      );

      final row = await db
          .customSelect('SELECT SUM(balance) AS total FROM accounts')
          .getSingle();

      final netWorth = await accounts.getNetWorth();
      expect(netWorth.cash, money('4000'));
      expect(netWorth.cardDebt, money('1200'));
      expect(netWorth.net, fiat(row.read<double>('total')));
    });

    test('is zero on an empty database', () async {
      final netWorth = await accounts.getNetWorth();
      expect(netWorth.net, Decimal.zero);
      expect(await accounts.hasAnyAccount(), isFalse);
    });
  });

  group('the spending rule', () {
    test('a frozen account rejects income as well as expense', () async {
      final id = await insertLegacyAccount(
        name: 'Dondurulmuş',
        type: 'credit',
        balance: -100,
        accountType: 'credit_card',
        creditLimit: 5000,
        isFrozen: 1,
      );

      for (final type in ['expense', 'income']) {
        await expectLater(
          () => accounts.assertSpendingAllowed(id, 10, transactionType: type),
          throwsA(
            isA<AccountError>().having(
              (e) => e.code,
              'code',
              AccountErrorCode.cardFrozen,
            ),
          ),
        );
      }
    });

    test('a card spend beyond the limit is rejected', () async {
      final id = await accounts.createAccount(
        name: 'Dar Kart',
        accountType: AccountType.creditCard,
        initialBalance: 900,
        creditLimit: 1000,
      );

      final decision = await accounts.checkSpendingAllowed(id, 250);
      expect(decision.isAllowed, isFalse);
      expect(decision.error!.code, AccountErrorCode.insufficientLimit);

      // Exactly the remaining limit is allowed; a cent more is not.
      expect((await accounts.checkSpendingAllowed(id, 100)).isAllowed, isTrue);
      expect(
        (await accounts.checkSpendingAllowed(id, '100.01')).isAllowed,
        isFalse,
      );
    });

    test('an import may exceed the limit', () async {
      // Historical rows are facts, not requests: the limit they were charged
      // against is not the limit today.
      final id = await accounts.createAccount(
        name: 'Dar Kart',
        accountType: AccountType.creditCard,
        initialBalance: 900,
        creditLimit: 1000,
      );
      final decision = await accounts.checkSpendingAllowed(
        id,
        250,
        enforceLimits: false,
      );
      expect(decision.isAllowed, isTrue);
    });

    test('a card with no recorded limit is not blocked', () async {
      // Cards arriving from the desktop's migration have credit_limit = 0,
      // which means "no limit set" — not "no room to spend".
      final id = await insertLegacyAccount(
        name: 'Limitsiz',
        type: 'credit',
        balance: -3500,
        accountType: 'credit_card',
      );
      expect((await accounts.checkSpendingAllowed(id, 750)).isAllowed, isTrue);
    });

    test('a checking account may go negative', () async {
      final id = await accounts.createAccount(
        name: 'Vadesiz',
        accountType: AccountType.checking,
        initialBalance: 100,
      );
      expect((await accounts.checkSpendingAllowed(id, 5000)).isAllowed, isTrue);
    });

    test('an account that does not exist is rejected', () async {
      final decision = await accounts.checkSpendingAllowed(404, 10);
      expect(decision.error!.code, AccountErrorCode.accountNotFound);
    });

    test('income on a card is not limit-checked', () async {
      final id = await accounts.createAccount(
        name: 'Kart',
        accountType: AccountType.creditCard,
        initialBalance: 900,
        creditLimit: 1000,
      );
      expect(
        (await accounts.checkSpendingAllowed(
          id,
          5000,
          transactionType: 'income',
        )).isAllowed,
        isTrue,
      );
    });
  });

  group('paying card debt', () {
    late int sourceId;
    late int cardId;

    setUp(() async {
      sourceId = await accounts.createAccount(
        name: 'Maaş',
        accountType: AccountType.checking,
        initialBalance: 5000,
      );
      cardId = await accounts.createAccount(
        name: 'Kart',
        accountType: AccountType.creditCard,
        initialBalance: 2400,
        creditLimit: 3000,
      );
    });

    test('moves cash and card together and files both sides', () async {
      await accounts.payCreditCardDebt(
        creditCardId: cardId,
        sourceAccountId: sourceId,
        amount: 900,
      );

      expect((await accounts.getAccount(sourceId))!.balance, money('4100'));
      final card = (await accounts.getAccount(cardId))!;
      expect(card.debt, money('1500'));
      expect(card.availableLimit, money('1500'));

      final rows = await db
          .customSelect('SELECT * FROM transactions ORDER BY id')
          .get();
      expect(rows.map((row) => row.read<String>('type')), [
        'expense',
        'payment',
      ]);
      expect(rows.map((row) => row.read<int>('account_id')), [
        sourceId,
        cardId,
      ]);
      for (final row in rows) {
        expect(row.read<String>('category'), debtPaymentCategory);
        // Both encrypted columns must leave as envelopes; a plaintext amount
        // here would be readable in a stolen database file.
        expect(FieldCrypto.isEncrypted(row.read<String>('amount')), isTrue);
        expect(
          FieldCrypto.isEncrypted(row.read<String>('description')),
          isTrue,
        );
      }

      final crypto = FieldCrypto(FixedKeyProvider.arbitrary());
      expect(
        await crypto.decryptField(rows.first.read<String>('amount')),
        '900.0',
      );
      expect(
        await crypto.decryptField(rows.first.read<String>('description')),
        'Kart $debtPaymentDescriptionSuffix',
      );
    });

    test('records both ledger entries with their resulting balances', () async {
      await accounts.payCreditCardDebt(
        creditCardId: cardId,
        sourceAccountId: sourceId,
        amount: 900,
      );

      final events = await db
          .customSelect(
            "SELECT * FROM balance_events WHERE source = 'card_payment' "
            'ORDER BY id',
          )
          .get();
      expect(events, hasLength(2));
      expect(events[0].read<double>('delta'), -900.0);
      expect(events[0].read<double>('resulting_value'), 4100.0);
      expect(events[1].read<double>('delta'), 900.0);
      expect(events[1].read<double>('resulting_value'), -1500.0);
    });

    test('cannot pay more than the debt', () async {
      await expectLater(
        () => accounts.payCreditCardDebt(
          creditCardId: cardId,
          sourceAccountId: sourceId,
          amount: 2401,
        ),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.paymentExceedsDebt,
          ),
        ),
      );
      expect((await accounts.getAccount(sourceId))!.balance, money('5000'));
      expect((await accounts.getAccount(cardId))!.debt, money('2400'));
      expect(await count('transactions'), 0);
    });

    test('paying the debt off exactly is allowed', () async {
      await accounts.payCreditCardDebt(
        creditCardId: cardId,
        sourceAccountId: sourceId,
        amount: 2400,
      );
      final card = (await accounts.getAccount(cardId))!;
      expect(card.debt, Decimal.zero);
      expect(card.availableLimit, money('3000'));
    });

    test('rejects a card with nothing owing', () async {
      final clearId = await accounts.createAccount(
        name: 'Temiz Kart',
        accountType: AccountType.creditCard,
        creditLimit: 3000,
      );
      await expectLater(
        () => accounts.payCreditCardDebt(
          creditCardId: clearId,
          sourceAccountId: sourceId,
          amount: 100,
        ),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.noDebtToPay,
          ),
        ),
      );
      expect((await accounts.getAccount(sourceId))!.balance, money('5000'));
    });

    test('the source must be a checking account', () async {
      final otherCardId = await accounts.createAccount(
        name: 'Diğer Kart',
        accountType: AccountType.creditCard,
        creditLimit: 3000,
      );
      await expectLater(
        () => accounts.payCreditCardDebt(
          creditCardId: cardId,
          sourceAccountId: otherCardId,
          amount: 100,
        ),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.sourceMustBeChecking,
          ),
        ),
      );
      expect((await accounts.getAccount(cardId))!.debt, money('2400'));
    });

    test('a non-finite amount changes nothing at all', () async {
      // The boundary itself is what is measured here. Every comparison
      // against NaN is false, so it passes "greater than zero?" and "more
      // than the debt?" and reaches the first UPDATE, which sets a real
      // balance to NULL inside the transaction. Nothing is left corrupted
      // afterwards, but the decision has to be made at the boundary, not two
      // statements past it — so the balances, their storage types and both
      // row counts must be untouched.
      Future<Object> snapshot() async {
        final rows = await db
            .customSelect(
              'SELECT id, balance, typeof(balance) AS kind FROM accounts '
              'ORDER BY id',
            )
            .get();
        return [
          for (final row in rows) row.data,
          await count('transactions'),
          await count('balance_events'),
        ].toString();
      }

      // Proof that the amount is judged BEFORE any row is read: paired with a
      // card id that does not exist, the answer is still about the amount. If
      // parsing had moved below the lookups the code would be
      // `notACreditCard`, and the snapshot below would pass anyway, because a
      // rollback hides the write either way.
      await expectLater(
        () => accounts.payCreditCardDebt(
          creditCardId: 404,
          sourceAccountId: 404,
          amount: double.nan,
        ),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.invalidPaymentAmount,
          ),
        ),
      );

      final before = await snapshot();
      for (final amount in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
        'nan',
        'not a number',
      ]) {
        await expectLater(
          () => accounts.payCreditCardDebt(
            creditCardId: cardId,
            sourceAccountId: sourceId,
            amount: amount,
          ),
          throwsA(
            isA<AccountError>().having(
              (e) => e.code,
              'code',
              AccountErrorCode.invalidPaymentAmount,
            ),
          ),
          reason: '$amount reached the database',
        );
        expect(await snapshot(), before, reason: '$amount changed state');
      }
    });

    test('rejects a payment of zero or less', () async {
      for (final amount in [0, -1]) {
        await expectLater(
          () => accounts.payCreditCardDebt(
            creditCardId: cardId,
            sourceAccountId: sourceId,
            amount: amount,
          ),
          throwsA(
            isA<AccountError>().having(
              (e) => e.code,
              'code',
              AccountErrorCode.paymentNotPositive,
            ),
          ),
        );
      }
      expect(await count('transactions'), 0);
    });

    test('works on a frozen card', () async {
      // Freezing stops new debt. Trapping the user with debt they cannot pay
      // off would be the opposite of what the switch is for.
      await accounts.setCardFrozen(cardId, true);
      await accounts.payCreditCardDebt(
        creditCardId: cardId,
        sourceAccountId: sourceId,
        amount: 400,
      );
      expect((await accounts.getAccount(cardId))!.debt, money('2000'));
    });
  });

  group('card preferences', () {
    test('freezing and online payments round-trip', () async {
      final id = await accounts.createAccount(
        name: 'Kart',
        accountType: AccountType.creditCard,
        creditLimit: 1000,
      );
      var account = (await accounts.getAccount(id))!;
      expect(account.isFrozen, isFalse);
      expect(account.onlinePaymentsEnabled, isTrue);

      await accounts.setCardFrozen(id, true);
      await accounts.setOnlinePayments(id, false);

      account = (await accounts.getAccount(id))!;
      expect(account.isFrozen, isTrue);
      expect(account.onlinePaymentsEnabled, isFalse);
    });

    test('an unknown account is reported, not silently ignored', () {
      expect(
        () => accounts.setCardFrozen(404, true),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.accountNotFound,
          ),
        ),
      );
    });
  });

  group('deleting a card', () {
    test('removes its dependants and leaves other cards alone', () async {
      final deletedId = await accounts.createAccount(
        name: 'Silinecek',
        accountType: AccountType.creditCard,
        initialBalance: 200,
        creditLimit: 3000,
      );
      final keptId = await accounts.createAccount(
        name: 'Kalacak',
        accountType: AccountType.creditCard,
        initialBalance: 100,
        creditLimit: 3000,
      );

      for (final id in [deletedId, keptId]) {
        await db.customInsert(
          'INSERT INTO transactions (account_id, amount, type, category, '
          'description, transaction_date) VALUES (?, ?, ?, ?, ?, ?)',
          variables: [
            Variable<int>(id),
            Variable<String>('AEADv1:placeholder'),
            Variable<String>('expense'),
            Variable<String>('Test'),
            Variable<String>('AEADv1:placeholder'),
            Variable<String>('2026-08-01 12:00:00'),
          ],
        );
        await db.customInsert(
          'INSERT INTO recurring_payments (name, amount, category, frequency, '
          'next_due_date, auto_deduct, is_active, account_id) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable<String>('AEADv1:placeholder'),
            Variable<String>('AEADv1:placeholder'),
            Variable<String>('Test'),
            Variable<String>('monthly'),
            Variable<String>('2026-09-01'),
            Variable<int>(1),
            Variable<int>(1),
            Variable<int>(id),
          ],
        );
      }

      await accounts.deleteCreditCard(deletedId);

      expect(await accounts.getAccount(deletedId), isNull);
      expect(await accounts.getAccount(keptId), isNotNull);
      expect(await count('transactions'), 1);
      expect(await count('recurring_payments'), 1);

      final events = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM balance_events '
            'WHERE entity_type = ? AND entity_id = ?',
            variables: [
              Variable<String>(accountEntity),
              Variable<int>(deletedId),
            ],
          )
          .getSingle();
      expect(events.read<int>('n'), 0);
    });

    test('refuses a checking account', () async {
      final id = await accounts.createAccount(
        name: 'Vadesiz',
        accountType: AccountType.checking,
        initialBalance: 100,
      );
      await expectLater(
        () => accounts.deleteCreditCard(id),
        throwsA(
          isA<AccountError>().having(
            (e) => e.code,
            'code',
            AccountErrorCode.notACreditCard,
          ),
        ),
      );
      expect(await accounts.getAccount(id), isNotNull);
    });

    test(
      'counts no instalment plans when the table was never created',
      () async {
        // The desktop creates installment_plans lazily, so a fresh database
        // does not have it. Querying it regardless would throw where the
        // honest answer is zero.
        final tables = await db.tableNames();
        expect(tables, isNot(contains('installment_plans')));
        expect(await accounts.getActiveInstallmentPlanCount(1), 0);
      },
    );
  });
}
