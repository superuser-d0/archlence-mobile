/// Pins that the drift accumulating in the `REAL` balance column never
/// reaches a business decision.
///
/// Ported from the desktop's `tests/test_real_balance_invariants.py`.
///
/// WHY IT EXISTS: `adjustAccountBalance` moves the balance with
/// `UPDATE accounts SET balance = balance + ?`. The addition happens inside
/// SQLite's `REAL` column, not in Dart, so moving the whole Dart side to
/// `Decimal` does not stop the accumulation from being binary floating point.
/// Adding 0.01 ten thousand times leaves the raw value at 100.00000000001425.
///
/// These tests do NOT claim the raw column equals the decimal. Under this
/// schema that would be a wrong expectation and a permanently red gate. What
/// the app actually guarantees is narrower and more useful: **the figure shown
/// to the user is correct, and the decision taken agrees with the figure
/// shown.** The mechanism is that every comparison runs on the quantized
/// value — `fiat()` on the way out of the column, and `Decimal` arithmetic
/// from there on.
///
/// So this is a guard against that mechanism being removed. Take `fiat()` out
/// of the derivation or the comparison and the user sees ₺100.00 on screen and
/// cannot spend ₺100.00 — a far worse class of defect than a display slip.
library;

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/transaction_service.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';

void main() {
  late ArchlenceDatabase db;
  late AccountService accounts;
  late TransactionService ledger;

  setUp(() {
    db = ArchlenceDatabase.memory();
    final crypto = FieldCrypto(FixedKeyProvider.arbitrary());
    accounts = AccountService(db, crypto);
    ledger = TransactionService(db, crypto, accounts);
  });

  tearDown(() => db.close());

  /// Produces the drift with the application's own SQL pattern, in one
  /// transaction so ten thousand statements stay fast.
  Future<void> drift(
    int accountId, {
    required bool add,
    int times = 10000,
    double step = 0.01,
  }) {
    final sql =
        'UPDATE accounts SET balance = balance ${add ? '+' : '-'} ? '
        'WHERE id = ?';
    return db.transaction(() async {
      for (var i = 0; i < times; i++) {
        await db.customUpdate(
          sql,
          variables: [Variable<double>(step), Variable<int>(accountId)],
          updates: const {},
        );
      }
    });
  }

  Future<double> rawBalance(int accountId) async {
    final row = await db
        .customSelect(
          'SELECT balance FROM accounts WHERE id = ?',
          variables: [Variable<int>(accountId)],
        )
        .getSingle();
    return row.read<double>('balance');
  }

  test('the displayed balance is the exact amount', () async {
    final id = await accounts.createAccount(
      name: 'Drift',
      accountType: AccountType.checking,
      initialBalance: 0,
    );
    await drift(id, add: true);

    // If this stops holding, the test has stopped measuring what it is for:
    // no drift means no guard is being exercised.
    expect(
      Decimal.parse((await rawBalance(id)).toString()),
      isNot(Decimal.parse('100.00')),
      reason: 'no drift was produced; this test no longer measures anything',
    );
    expect((await accounts.getAccount(id))!.balance, fiat('100.00'));
  });

  test('the whole displayed balance is spendable', () async {
    final id = await accounts.createAccount(
      name: 'Drift',
      accountType: AccountType.checking,
      initialBalance: 0,
    );
    await drift(id, add: true);

    final decision = await accounts.checkSpendingAllowed(id, fiat('100.00'));
    expect(
      decision.isAllowed,
      isTrue,
      reason: 'the whole displayed amount was refused: ${decision.error}',
    );
  });

  test('the card limit decision agrees with what is on screen', () async {
    final id = await accounts.createAccount(
      name: 'Drift card',
      accountType: AccountType.creditCard,
      creditLimit: 100,
    );
    await drift(id, add: false, times: 5000);

    final card = (await accounts.getAccount(id))!;
    expect(card.debt, fiat('50.00'));
    expect(card.availableLimit, fiat('50.00'));

    expect(
      (await accounts.checkSpendingAllowed(id, fiat('50.00'))).isAllowed,
      isTrue,
      reason: 'the whole remaining limit was refused',
    );
    expect(
      (await accounts.checkSpendingAllowed(id, fiat('50.01'))).isAllowed,
      isFalse,
      reason: 'a kurus over the limit was accepted',
    );

    await ledger.addTransaction(
      accountId: id,
      amount: fiat('50.00'),
      transactionType: 'expense',
      category: 'Audit',
      description: 'sınır',
    );
    expect((await accounts.getAccount(id))!.debt, fiat('100.00'));
  });

  test('the whole displayed available limit is spendable', () async {
    // The dangerous direction. In the test above the raw debt settles a shade
    // BELOW the exact value, where the decisions come out right by accident
    // even with the guard removed. The danger is the other way: a raw debt a
    // shade ABOVE means the screen says "available 100.00" and the spend is
    // refused.
    //
    // The desktop notes that removing only one of its two guard layers left
    // this test green, the other swallowing the drift. That is NOT true of
    // this port, and it was measured: dropping the quantize where the balance
    // is derived, or the one where the debt is, fails this file on its own.
    // The difference is that once a value is a Decimal the arithmetic after
    // it is exact, so there is no second place for the drift to be absorbed.
    final id = await accounts.createAccount(
      name: 'Drift card',
      accountType: AccountType.creditCard,
      creditLimit: 200,
    );
    await drift(id, add: false);

    final card = (await accounts.getAccount(id))!;
    expect(card.debt, fiat('100.00'));
    expect(card.availableLimit, fiat('100.00'));

    final decision = await accounts.checkSpendingAllowed(id, fiat('100.00'));
    expect(
      decision.isAllowed,
      isTrue,
      reason: 'the displayed available limit was refused: ${decision.error}',
    );
  });
}
