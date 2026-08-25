/// Savings goals, ported from the desktop's `test_savings_service.py`,
/// `test_savings_status_rounding.py` and the identity half of
/// `test_savings_identity_reuse_regression.py`.
library;

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/balance_events.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/savings_service.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';

void main() {
  late ArchlenceDatabase db;
  late FieldCrypto crypto;
  late AccountService accounts;
  late SavingsService savings;

  setUp(() {
    db = ArchlenceDatabase.memory();
    crypto = FieldCrypto(FixedKeyProvider.arbitrary());
    accounts = AccountService(db, crypto);
    savings = SavingsService(db, crypto);
  });

  tearDown(() => db.close());

  Decimal money(String value) => fiat(value);

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  Future<int> newAccount({Object? balance = 10000}) => accounts.createAccount(
    name: 'Vadesiz',
    accountType: AccountType.checking,
    initialBalance: balance,
  );

  Future<Decimal> balanceOf(int id) async =>
      (await accounts.getAccount(id))!.balance;

  /// The raw stored values, past the quantizing the model applies on read.
  Future<(double current, double target, String status)> rawGoal(
    int goalId,
  ) async {
    final row = await db
        .customSelect(
          'SELECT current_amount, target_amount, status FROM savings_goals '
          'WHERE id = ?',
          variables: [Variable<int>(goalId)],
        )
        .getSingle();
    return (
      row.read<double>('current_amount'),
      row.read<double>('target_amount'),
      row.read<String>('status'),
    );
  }

  group('opening a goal', () {
    test('stores every field and a durable identity', () async {
      final id = await savings.createGoal(
        goalName: 'Araba Fonu',
        targetAmount: 20000,
        targetDate: '2027-01-01',
        color: 'blue',
        autoDeposit: true,
        createdAt: '2026-01-05',
      );

      final goal = (await savings.getGoal(id))!;
      expect(goal.goalName, 'Araba Fonu');
      expect(goal.targetAmount, money('20000'));
      expect(goal.currentAmount, Decimal.zero);
      expect(goal.targetDate, '2027-01-01');
      expect(goal.color, 'blue');
      expect(goal.autoDeposit, isTrue);
      expect(goal.createdAt, '2026-01-05');
      expect(goal.status, SavingsStatus.active);
      expect(
        goal.goalUid,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('the name is encrypted at rest', () async {
      final id = await savings.createGoal(
        goalName: 'Araba Fonu',
        targetAmount: 20000,
      );
      final row = await db
          .customSelect('SELECT goal_name FROM savings_goals')
          .getSingle();
      expect(row.read<String>('goal_name'), isNot(contains('Araba')));
      expect(FieldCrypto.isEncrypted(row.read<String>('goal_name')), isTrue);
      expect((await savings.getGoal(id))!.goalName, 'Araba Fonu');
    });

    test('every goal gets its own identity', () async {
      final first = await savings.createGoal(goalName: 'A', targetAmount: 100);
      final second = await savings.createGoal(goalName: 'B', targetAmount: 100);
      expect(
        (await savings.getGoal(first))!.goalUid,
        isNot((await savings.getGoal(second))!.goalUid),
      );
    });

    test('opening at the target starts complete', () async {
      final id = await savings.createGoal(
        goalName: 'Bitti',
        targetAmount: 500,
        currentAmount: 500,
      );
      expect((await savings.getGoal(id))!.status, SavingsStatus.completed);
    });

    test('records an opening ledger line even at zero', () async {
      // It moves no total, but leaving it out would make the ledger's record
      // of the goal's existence incomplete.
      final id = await savings.createGoal(goalName: 'A', targetAmount: 100);
      final event = await db
          .customSelect(
            "SELECT * FROM balance_events WHERE source = 'savings_goal_created'",
          )
          .getSingle();
      expect(event.read<String>('entity_type'), savingsGoalEntity);
      expect(event.read<int>('entity_id'), id);
      expect(event.read<double>('delta'), 0.0);
    });

    test(
      'rejects a non-positive target or a negative opening amount',
      () async {
        await expectLater(
          () => savings.createGoal(goalName: 'A', targetAmount: 0),
          throwsA(
            isA<SavingsError>().having(
              (e) => e.code,
              'code',
              SavingsErrorCode.amountNotPositive,
            ),
          ),
        );
        await expectLater(
          () => savings.createGoal(
            goalName: 'A',
            targetAmount: 100,
            currentAmount: -1,
          ),
          throwsA(
            isA<SavingsError>().having(
              (e) => e.code,
              'code',
              SavingsErrorCode.negativeOpeningAmount,
            ),
          ),
        );
        expect(await count('savings_goals'), 0);
      },
    );

    test('refuses a blank name, where the desktop does not', () async {
      // A deliberate divergence. The desktop's create_goal validates the
      // amounts and not the name, which reads as an oversight beside
      // create_account, and an unnamed goal is indistinguishable from its
      // neighbours in a list.
      for (final name in ['', '   ']) {
        await expectLater(
          () => savings.createGoal(goalName: name, targetAmount: 1000),
          throwsA(
            isA<SavingsError>().having(
              (e) => e.code,
              'code',
              SavingsErrorCode.emptyName,
            ),
          ),
          reason: '"$name"',
        );
      }
      expect(await count('savings_goals'), 0);
    });

    test('stores the name trimmed', () async {
      final id = await savings.createGoal(
        goalName: '  Tatil  ',
        targetAmount: 1000,
      );
      expect((await savings.getGoal(id))!.goalName, 'Tatil');
    });

    test('rejects a non-finite amount', () async {
      await expectLater(
        () => savings.createGoal(goalName: 'A', targetAmount: double.nan),
        throwsA(
          isA<SavingsError>().having(
            (e) => e.code,
            'code',
            SavingsErrorCode.invalidAmount,
          ),
        ),
      );
      expect(await count('savings_goals'), 0);
    });

    test('a goal whose name will not decrypt reads as null', () async {
      final id = await savings.createGoal(goalName: 'A', targetAmount: 100);
      await db.customUpdate(
        "UPDATE savings_goals SET goal_name = 'AEADv1:broken'",
        updates: const {},
      );
      expect((await savings.getGoal(id))!.goalName, isNull);
    });
  });

  group('depositing', () {
    test('isolates money from the checking balance', () async {
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );

      final goal = await savings.depositToGoal(
        goalId: goalId,
        amount: 1500,
        accountId: accountId,
      );

      expect(await balanceOf(accountId), money('8500'));
      expect(goal!.currentAmount, money('1500'));
    });

    test(
      'is not spending, so nothing reaches the ledger of transactions',
      () async {
        // Setting money aside must not appear in any expense chart.
        final accountId = await newAccount();
        final goalId = await savings.createGoal(
          goalName: 'Tatil',
          targetAmount: 5000,
        );
        await savings.depositToGoal(
          goalId: goalId,
          amount: 1500,
          accountId: accountId,
        );
        expect(await count('transactions'), 0);
      },
    );

    test(
      'writes both sides of the ledger, each pointing at the other',
      () async {
        // The account and the goal must get DIFFERENT ids, or a ref_id
        // pointing at the wrong counterpart would read as correct: both
        // tables start their own AUTOINCREMENT at 1.
        await newAccount();
        final accountId = await newAccount();
        final goalId = await savings.createGoal(
          goalName: 'Tatil',
          targetAmount: 5000,
        );
        expect(accountId, isNot(goalId), reason: 'the ids must differ here');
        await savings.depositToGoal(
          goalId: goalId,
          amount: 1500,
          accountId: accountId,
        );

        final events = await db
            .customSelect(
              "SELECT * FROM balance_events WHERE source = 'savings_deposit' "
              'ORDER BY id',
            )
            .get();
        expect(events, hasLength(2));
        expect(events[0].read<String>('entity_type'), accountEntity);
        expect(events[0].read<double>('delta'), -1500.0);
        expect(events[0].read<int>('ref_id'), goalId);
        expect(events[1].read<String>('entity_type'), savingsGoalEntity);
        expect(events[1].read<double>('delta'), 1500.0);
        expect(events[1].read<int>('ref_id'), accountId);
      },
    );

    test('may drive the account negative', () async {
      // Deliberate: there is no insufficient-balance guard, the same decision
      // the ledger makes for an ordinary expense.
      final accountId = await newAccount(balance: 100);
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );
      await savings.depositToGoal(
        goalId: goalId,
        amount: 500,
        accountId: accountId,
      );
      expect(await balanceOf(accountId), money('-400'));
    });

    test('completes the goal on reaching the target', () async {
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 1000,
      );
      await savings.depositToGoal(
        goalId: goalId,
        amount: 1000,
        accountId: accountId,
      );
      expect((await savings.getGoal(goalId))!.status, SavingsStatus.completed);
    });

    test('refuses a completed goal, moving no money', () async {
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 1000,
        currentAmount: 1000,
      );

      await expectLater(
        () => savings.depositToGoal(
          goalId: goalId,
          amount: 100,
          accountId: accountId,
        ),
        throwsA(
          isA<SavingsError>().having(
            (e) => e.code,
            'code',
            SavingsErrorCode.goalNotFoundOrCompleted,
          ),
        ),
      );
      expect(await balanceOf(accountId), money('10000'));
    });

    test('refuses an account that does not exist, moving no money', () async {
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );
      await expectLater(
        () =>
            savings.depositToGoal(goalId: goalId, amount: 100, accountId: 404),
        throwsA(
          isA<SavingsError>().having(
            (e) => e.code,
            'code',
            SavingsErrorCode.accountNotFound,
          ),
        ),
      );
      expect((await savings.getGoal(goalId))!.currentAmount, Decimal.zero);
      expect(await count('balance_events'), 1, reason: 'only the opening one');
    });

    test('rejects a non-positive amount', () async {
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );
      for (final amount in [0, -1, double.nan]) {
        await expectLater(
          () => savings.depositToGoal(
            goalId: goalId,
            amount: amount,
            accountId: accountId,
          ),
          throwsA(isA<SavingsError>()),
        );
      }
      expect(await balanceOf(accountId), money('10000'));
    });
  });

  group('withdrawing', () {
    test('returns money to the checking balance', () async {
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );
      await savings.depositToGoal(
        goalId: goalId,
        amount: 1500,
        accountId: accountId,
      );

      final goal = await savings.withdrawFromGoal(
        goalId: goalId,
        amount: 500,
        accountId: accountId,
      );

      expect(await balanceOf(accountId), money('9000'));
      expect(goal!.currentAmount, money('1000'));
    });

    test('refuses to overdraw the goal', () async {
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );
      await savings.depositToGoal(
        goalId: goalId,
        amount: 100,
        accountId: accountId,
      );

      await expectLater(
        () => savings.withdrawFromGoal(
          goalId: goalId,
          amount: 500,
          accountId: accountId,
        ),
        throwsA(
          isA<SavingsError>().having(
            (e) => e.code,
            'code',
            SavingsErrorCode.insufficientGoalBalance,
          ),
        ),
      );
      expect((await savings.getGoal(goalId))!.currentAmount, money('100'));
      expect(await balanceOf(accountId), money('9900'));
    });

    test('writes both ledger sides in the opposite direction', () async {
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );
      await savings.depositToGoal(
        goalId: goalId,
        amount: 1500,
        accountId: accountId,
      );
      await savings.withdrawFromGoal(
        goalId: goalId,
        amount: 500,
        accountId: accountId,
      );

      final events = await db
          .customSelect(
            "SELECT * FROM balance_events WHERE source = 'savings_withdraw' "
            'ORDER BY id',
          )
          .get();
      expect(events, hasLength(2));
      expect(events[0].read<String>('entity_type'), savingsGoalEntity);
      expect(events[0].read<double>('delta'), -500.0);
      expect(events[1].read<String>('entity_type'), accountEntity);
      expect(events[1].read<double>('delta'), 500.0);
    });
  });

  group('the REAL column\'s drift in a goal', () {
    /// Nine deposits of 0.60 plus 10.00, less 5.00, against a 10.40 target.
    /// The sequence is the desktop's: it leaves `current_amount` a hair below
    /// the target in the raw column while the screen shows 10.40/10.40.
    Future<(int accountId, int goalId)> driftedCompletedGoal() async {
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Bozuk para',
        targetAmount: 10.40,
      );
      for (var i = 0; i < 9; i++) {
        await savings.depositToGoal(
          goalId: goalId,
          amount: 0.60,
          accountId: accountId,
        );
      }
      await savings.depositToGoal(
        goalId: goalId,
        amount: 10.00,
        accountId: accountId,
      );
      await savings.withdrawFromGoal(
        goalId: goalId,
        amount: 5.00,
        accountId: accountId,
      );
      return (accountId, goalId);
    }

    test('reaching the target completes the goal even under drift', () async {
      // The COMPLETION rule's own rounding, which the sequence below does not
      // reach: there the raw value is comfortably above the target at the
      // moment completion is decided, so a raw comparison would pass too.
      // Here nine deposits of 0.60 against a 5.40 target land the raw column
      // at 5.3999999999999994 — the card reads 5.40/5.40 and the goal must
      // say so.
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Bozuk para',
        targetAmount: 5.40,
      );
      for (var i = 0; i < 9; i++) {
        await savings.depositToGoal(
          goalId: goalId,
          amount: 0.60,
          accountId: accountId,
        );
      }

      final (current, target, status) = await rawGoal(goalId);
      expect(
        current,
        lessThan(target),
        reason: 'no drift was produced; this test no longer measures anything',
      );
      expect(fiat(current), fiat(target));
      expect(
        status,
        SavingsStatus.completed,
        reason: 'the card reads 5.40/5.40 while the row says $status',
      );
    });

    test('a goal still holding its target stays complete', () async {
      final (_, goalId) = await driftedCompletedGoal();
      final (current, target, status) = await rawGoal(goalId);

      expect(
        current,
        lessThan(target),
        reason: 'no drift was produced; this sequence no longer measures it',
      );
      expect(
        fiat(current),
        fiat(target),
        reason:
            'the scenario must sit exactly on the target at kurus precision',
      );
      expect(
        status,
        SavingsStatus.completed,
        reason: 'the screen reads 10.40/10.40 while the row says $status',
      );
    });

    test('but really dropping below reopens it', () async {
      // The complement. Without this, rounding the comparison could have
      // turned into "once complete, complete for ever".
      final (accountId, goalId) = await driftedCompletedGoal();
      await savings.withdrawFromGoal(
        goalId: goalId,
        amount: 0.01,
        accountId: accountId,
      );

      final (current, target, status) = await rawGoal(goalId);
      expect(fiat(current), lessThan(fiat(target)));
      expect(status, SavingsStatus.active);
    });

    test('the whole displayed balance is withdrawable', () async {
      // If the card says 10.40, 10.40 must come back out — comparing raw
      // REALs would refuse the user their own money by a fraction of a kurus.
      final (accountId, goalId) = await driftedCompletedGoal();
      final displayed = (await savings.getGoal(goalId))!.currentAmount;

      final goal = await savings.withdrawFromGoal(
        goalId: goalId,
        amount: displayed,
        accountId: accountId,
      );
      expect(goal!.currentAmount, Decimal.zero);
    });
  });

  group('the durable identity', () {
    test('a matching uid is accepted', () async {
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );
      final uid = (await savings.getGoal(goalId))!.goalUid;

      final goal = await savings.depositToGoal(
        goalId: goalId,
        amount: 100,
        accountId: accountId,
        goalUid: uid,
      );
      expect(goal!.currentAmount, money('100'));
    });

    test('a foreign uid is refused before any money moves', () async {
      // The case this exists for: a numeric id freed by a restore and taken
      // by a different goal, while a screen still holds the old card.
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );

      await expectLater(
        () => savings.depositToGoal(
          goalId: goalId,
          amount: 100,
          accountId: accountId,
          goalUid: generateGoalUid(),
        ),
        throwsA(
          isA<SavingsError>().having(
            (e) => e.code,
            'code',
            SavingsErrorCode.identityMismatch,
          ),
        ),
      );
      expect(await balanceOf(accountId), money('10000'));
      expect((await savings.getGoal(goalId))!.currentAmount, Decimal.zero);
    });

    test('withdraw and delete share the same fail-closed contract', () async {
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );
      await savings.depositToGoal(
        goalId: goalId,
        amount: 1000,
        accountId: accountId,
      );
      final foreign = generateGoalUid();

      await expectLater(
        () => savings.withdrawFromGoal(
          goalId: goalId,
          amount: 100,
          accountId: accountId,
          goalUid: foreign,
        ),
        throwsA(isA<SavingsError>()),
      );
      await expectLater(
        () => savings.deleteGoal(
          goalId: goalId,
          accountId: accountId,
          goalUid: foreign,
        ),
        throwsA(isA<SavingsError>()),
      );

      expect((await savings.getGoal(goalId))!.currentAmount, money('1000'));
      expect(await balanceOf(accountId), money('9000'));
    });

    test('an id reused after a restore does not fund the wrong goal', () async {
      // Staged the way a restore leaves it: the row behind the id is gone and
      // a different goal now holds it.
      final accountId = await newAccount();
      final firstId = await savings.createGoal(
        goalName: 'Araba Fonu',
        targetAmount: 20000,
      );
      final staleUid = (await savings.getGoal(firstId))!.goalUid;

      await savings.deleteGoal(goalId: firstId, refund: false);
      await db.customUpdate(
        'UPDATE sqlite_sequence SET seq = 0 WHERE name = ?',
        variables: [Variable<String>('savings_goals')],
        updates: const {},
      );
      final reusedId = await savings.createGoal(
        goalName: 'Tatil Fonu',
        targetAmount: 10000,
      );
      expect(reusedId, firstId, reason: 'the id really was reused');

      await expectLater(
        () => savings.depositToGoal(
          goalId: reusedId,
          amount: 500,
          accountId: accountId,
          goalUid: staleUid,
        ),
        throwsA(
          isA<SavingsError>().having(
            (e) => e.code,
            'code',
            SavingsErrorCode.identityMismatch,
          ),
        ),
      );
      expect((await savings.getGoal(reusedId))!.currentAmount, Decimal.zero);
    });
  });

  group('deleting a goal', () {
    test('refunds the balance to a checking account', () async {
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );
      await savings.depositToGoal(
        goalId: goalId,
        amount: 1500,
        accountId: accountId,
      );

      expect(
        await savings.deleteGoal(goalId: goalId, accountId: accountId),
        isTrue,
      );
      expect(await balanceOf(accountId), money('10000'));
      expect(await savings.getGoal(goalId), isNull);
    });

    test('discarding keeps the money out of the account', () async {
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );
      await savings.depositToGoal(
        goalId: goalId,
        amount: 1500,
        accountId: accountId,
      );

      await savings.deleteGoal(
        goalId: goalId,
        accountId: accountId,
        refund: false,
      );

      expect(await balanceOf(accountId), money('8500'));
      // The closing line's source is the only trace left once the row is gone.
      final event = await db
          .customSelect(
            "SELECT * FROM balance_events "
            "WHERE source = 'savings_goal_discarded'",
          )
          .getSingle();
      expect(event.read<double>('delta'), -1500.0);
      expect(event.read<double>('resulting_value'), 0.0);
    });

    test('refuses a credit card as the refund destination', () async {
      final cardId = await accounts.createAccount(
        name: 'Kart',
        accountType: AccountType.creditCard,
        creditLimit: 5000,
      );
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );
      await savings.depositToGoal(
        goalId: goalId,
        amount: 1500,
        accountId: accountId,
      );

      await expectLater(
        () => savings.deleteGoal(goalId: goalId, accountId: cardId),
        throwsA(
          isA<SavingsError>().having(
            (e) => e.code,
            'code',
            SavingsErrorCode.accountNotFound,
          ),
        ),
      );
      expect(await savings.getGoal(goalId), isNotNull);
    });

    test('a refund with no account chosen is refused', () async {
      final accountId = await newAccount();
      final goalId = await savings.createGoal(
        goalName: 'Tatil',
        targetAmount: 5000,
      );
      await savings.depositToGoal(
        goalId: goalId,
        amount: 1500,
        accountId: accountId,
      );

      await expectLater(
        () => savings.deleteGoal(goalId: goalId),
        throwsA(
          isA<SavingsError>().having(
            (e) => e.code,
            'code',
            SavingsErrorCode.refundAccountRequired,
          ),
        ),
      );
      expect(await savings.getGoal(goalId), isNotNull);
    });

    test('an empty goal needs no refund account', () async {
      final goalId = await savings.createGoal(
        goalName: 'Boş',
        targetAmount: 5000,
      );
      expect(await savings.deleteGoal(goalId: goalId), isTrue);
    });

    test('deleting a goal that is not there reports so', () async {
      expect(await savings.deleteGoal(goalId: 404), isFalse);
    });
  });

  group('listing goals', () {
    test('can be narrowed to the active ones', () async {
      final accountId = await newAccount();
      await savings.createGoal(goalName: 'Aktif', targetAmount: 5000);
      final doneId = await savings.createGoal(
        goalName: 'Biten',
        targetAmount: 100,
      );
      await savings.depositToGoal(
        goalId: doneId,
        amount: 100,
        accountId: accountId,
      );

      expect((await savings.getGoals()).map((g) => g.goalName), [
        'Aktif',
        'Biten',
      ]);
      expect(
        (await savings.getGoals(onlyActive: true)).map((g) => g.goalName),
        ['Aktif'],
      );
    });
  });
}
