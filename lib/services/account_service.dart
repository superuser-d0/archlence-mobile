/// Multi-account and credit-card service.
///
/// A port of the desktop's `services/account_service.py`, and the only place
/// that reads or writes the `accounts` table. Its real work is turning the
/// SIGNED value in the raw `balance` column into what a screen wants to show:
/// a positive [Account.debt] and [Account.availableLimit] for a credit card,
/// a plain [Account.balance] for a checking account.
///
/// THE SIGN CONVENTION, which everything here rests on: `accounts.balance` is
/// always that account's contribution to net worth. Checking balances are
/// positive and an expense lowers them; card debt is held as a NEGATIVE
/// balance, so spending on the card pushes it further negative and paying it
/// moves it toward zero. The benefit is that net worth stays correct from a
/// plain `SUM(balance)` — card debts subtract themselves — so no other caller
/// that touches the column has to know account types apart. Storing debt as a
/// positive number would make one forgotten call site silently add debt to
/// net worth.
///
/// The account name is NOT encrypted, unlike the names in `active_debts` and
/// `recurring_payments`. The desktop seeds it in the clear and joins on it as
/// text; encrypting it here would make those rows unreadable to the desktop.
///
/// Two deliberate departures from the Python:
///
///  * Errors are [AccountError]s carrying an [AccountErrorCode], not
///    pre-formatted Turkish sentences. The desktop raises `ValueError` with
///    the user-facing text baked in; this app still has to grow an i18n layer
///    (the desktop's `ui/i18n.py` has both languages), and a code survives
///    translation where a matched string does not.
///  * The `type_label` field is dropped. It was a Turkish UI string on a data
///    model; the label belongs to whatever renders the account.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../crypto/field_crypto.dart';
import '../data/balance_events.dart';
import '../data/database.dart';
import '../money/financial_decimal.dart';

/// Card network logo paths, verbatim from `database/db.py::NETWORK_LOGOS`.
///
/// These strings are written into `accounts.network_logo` and the desktop
/// resolves them against its own asset directory, so they are a storage
/// contract and not this app's asset paths. Mapping one to a Flutter asset is
/// the UI's job.
const Map<String, String> networkLogos = {
  'Visa': 'assets/visa.png',
  'Mastercard': 'assets/mastercard.png',
  'Troy': 'assets/troy.png',
};

/// Shown for a card whose number was never entered.
const String unknownMaskedNumber = '**** **** **** 0000';

/// The category a card payment is filed under, and the suffix on its
/// description.
///
/// Both are Turkish because both are DATA, not interface text: the desktop
/// groups and reports on the literal category string, and these rows have to
/// land in the same group there. Translating them would split one category in
/// two.
const String debtPaymentCategory = 'Borç Ödeme';
const String debtPaymentDescriptionSuffix = 'Borç Ödemesi';

/// What a screen or a caller can do about a rejected operation.
enum AccountErrorCode {
  emptyName,
  unknownAccountType,
  invalidAmount,
  invalidStatementDay,
  creditLimitRequired,
  negativeOpeningDebt,
  openingDebtExceedsLimit,
  accountNotFound,
  cardFrozen,
  insufficientLimit,
  invalidPaymentAmount,
  paymentNotPositive,
  notACreditCard,
  noDebtToPay,
  paymentExceedsDebt,
  sourceMustBeChecking,
  balanceUpdateFailed,
  unknownCardPreference,
}

/// A rejected account operation.
///
/// [message] is developer-facing English; user-facing text is produced from
/// [code] by the presentation layer.
class AccountError implements Exception {
  const AccountError(this.code, this.message);

  final AccountErrorCode code;
  final String message;

  @override
  String toString() => 'AccountError(${code.name}): $message';
}

/// The two kinds of account, as stored in `accounts.account_type`.
enum AccountType {
  checking('checking'),
  creditCard('credit_card');

  const AccountType(this.wireValue);

  /// The exact string in the column. Never derive this from [name]: the enum
  /// spells it `creditCard` and the database spells it `credit_card`.
  final String wireValue;

  static AccountType? fromWire(String? value) => switch (value) {
    'checking' => AccountType.checking,
    'credit_card' => AccountType.creditCard,
    _ => null,
  };
}

/// One account, with the fields a screen needs derived from the raw row.
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.accountType,
    required this.balance,
    required this.creditLimit,
    required this.statementDate,
    required this.debt,
    required this.availableLimit,
    required this.maskedNumber,
    required this.networkLogo,
    required this.isFrozen,
    required this.onlinePaymentsEnabled,
    required this.hasCardNumber,
  });

  /// Derives an account from a raw `accounts` row.
  ///
  /// Every column read here is defensive about nulls on purpose: rows written
  /// before the desktop's later `ALTER TABLE` migrations carry nulls where
  /// the current schema has defaults, and a restored backup can contain them.
  factory Account.fromRow(Map<String, Object?> row) {
    // A row from before `account_type` existed is classified by the legacy
    // `type` column, which held 'cash'/'bank'/'credit'.
    final legacyType = row['type'] as String?;
    final accountType =
        AccountType.fromWire(row['account_type'] as String?) ??
        (legacyType == 'credit'
            ? AccountType.creditCard
            : AccountType.checking);

    final balance = fiat(row['balance'] ?? 0);
    final rawLimit = fiat(row['credit_limit'] ?? 0);

    final storedMask = row['masked_number'] as String?;
    final hasCardNumber = storedMask != null && storedMask.isNotEmpty;

    final Decimal debt;
    final Decimal availableLimit;
    if (accountType == AccountType.creditCard) {
      if (balance > Decimal.zero) {
        // Overpaid: the surplus sits on top of the limit rather than
        // showing as negative debt.
        debt = Decimal.zero;
        availableLimit = rawLimit + balance;
      } else {
        debt = -balance;
        availableLimit = _atLeastZero(rawLimit - debt);
      }
    } else {
      debt = Decimal.zero;
      availableLimit = Decimal.zero;
    }

    return Account(
      id: row['id']! as int,
      name: row['name']! as String,
      accountType: accountType,
      balance: balance,
      creditLimit: accountType == AccountType.creditCard
          ? rawLimit
          : Decimal.zero,
      statementDate: row['statement_date'] as int?,
      debt: debt,
      availableLimit: availableLimit,
      maskedNumber: hasCardNumber ? storedMask : unknownMaskedNumber,
      networkLogo: (row['network_logo'] as String?) ?? '',
      isFrozen: (row['is_frozen'] as int? ?? 0) != 0,
      // Absent means enabled: the column was added with DEFAULT 1, so a row
      // that predates it was one where payments were allowed.
      onlinePaymentsEnabled: (row['online_payments_enabled'] as int? ?? 1) != 0,
      hasCardNumber: hasCardNumber,
    );
  }

  final int id;
  final String name;
  final AccountType accountType;

  /// The signed contribution to net worth. Negative on a card in debt.
  final Decimal balance;
  final Decimal creditLimit;
  final int? statementDate;

  /// Debt as a positive number; always zero on a checking account.
  final Decimal debt;

  /// Limit still available to spend; always zero on a checking account.
  final Decimal availableLimit;

  final String maskedNumber;
  final String networkLogo;
  final bool isFrozen;
  final bool onlinePaymentsEnabled;

  /// False when [maskedNumber] is the [unknownMaskedNumber] placeholder
  /// rather than digits the user entered.
  final bool hasCardNumber;
}

/// Net worth, with the parts it is made of.
///
/// [net] is arithmetically identical to `SUM(balance)` under the sign
/// convention; the components exist so a screen can show the breakdown.
class NetWorth {
  const NetWorth({
    required this.cash,
    required this.cardDebt,
    required this.net,
  });

  final Decimal cash;
  final Decimal cardDebt;
  final Decimal net;
}

/// The outcome of an advisory spending check.
class SpendingDecision {
  const SpendingDecision.allowed() : error = null;
  const SpendingDecision.rejected(AccountError this.error);

  final AccountError? error;

  bool get isAllowed => error == null;
}

Decimal _atLeastZero(Decimal value) =>
    value < Decimal.zero ? Decimal.zero : value;

class AccountService {
  AccountService(this._db, this._crypto);

  final ArchlenceDatabase _db;

  /// Card payments write two ledger rows, whose amount and description are
  /// encrypted columns.
  final FieldCrypto _crypto;

  /// Creates an account or card and returns the new row's id.
  ///
  /// For a credit card, [initialBalance] is the CURRENT DEBT as a positive
  /// number: the user says "I owe 5000" and this writes -5000. The caller
  /// does not flip the sign.
  ///
  /// [cardNumberFull] exists only for the duration of this call. The last
  /// four digits and the network are derived from it and stored; the number
  /// itself is never written, encrypted or otherwise. The desktop used to
  /// keep the full number, expiry and CVC in encrypted columns and dropped
  /// them — the interface only ever showed the last four and the network, so
  /// holding the rest bought nothing and risked everything.
  Future<int> createAccount({
    required String name,
    required AccountType accountType,
    Object? initialBalance,
    Object? creditLimit,
    Object? statementDate,
    String? cardNumberFull,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const AccountError(
        AccountErrorCode.emptyName,
        'An account needs a name.',
      );
    }

    final Decimal openingAmount;
    final Decimal limit;
    try {
      openingAmount = fiat(initialBalance ?? 0);
      limit = fiat(creditLimit ?? 0);
    } on FinancialValueError catch (error) {
      throw AccountError(
        AccountErrorCode.invalidAmount,
        'Amount and limit must be finite numbers: ${error.message}',
      );
    }

    final statementDay = _parseStatementDate(statementDate);

    final Decimal balance;
    final String legacyType;
    if (accountType == AccountType.creditCard) {
      if (limit <= Decimal.zero) {
        throw const AccountError(
          AccountErrorCode.creditLimitRequired,
          'A credit card needs a limit greater than zero.',
        );
      }
      if (openingAmount < Decimal.zero) {
        throw const AccountError(
          AccountErrorCode.negativeOpeningDebt,
          'Opening debt cannot be negative.',
        );
      }
      if (openingAmount > limit) {
        throw const AccountError(
          AccountErrorCode.openingDebtExceedsLimit,
          'Opening debt cannot exceed the card limit.',
        );
      }
      balance = -openingAmount;
      legacyType = 'credit';
    } else {
      balance = openingAmount;
      legacyType = 'bank';
    }

    // A checking account has no limit and no statement day, whatever the
    // caller passed. The dialog shares one form for both kinds, so these
    // arrive populated from fields the user never saw.
    final storedLimit = accountType == AccountType.creditCard
        ? limit
        : Decimal.zero;
    final storedStatementDay = accountType == AccountType.creditCard
        ? statementDay
        : null;

    String? maskedNumber;
    String? networkLogo;
    if (cardNumberFull != null && cardNumberFull.isNotEmpty) {
      networkLogo = cardNetworkLogo(cardNumberFull);
      final last4 = cardNumberFull.length >= 4
          ? cardNumberFull.substring(cardNumberFull.length - 4)
          : cardNumberFull;
      maskedNumber = '**** **** **** $last4';
    }

    final signedBalance = balance.toDouble();

    return _db.transaction(() async {
      final accountId = await _db.customInsert(
        'INSERT INTO accounts '
        '(name, type, balance, account_type, credit_limit, statement_date, '
        'masked_number, network_logo) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable<String>(trimmedName),
          Variable<String>(legacyType),
          Variable<double>(signedBalance),
          Variable<String>(accountType.wireValue),
          Variable<double>(storedLimit.toDouble()),
          Variable<int>(storedStatementDay),
          Variable<String>(maskedNumber),
          Variable<String>(networkLogo),
        ],
      );
      await recordBalanceEvent(
        _db,
        entityType: accountEntity,
        entityId: accountId,
        delta: signedBalance,
        resultingValue: signedBalance,
        source: 'account_opened',
      );
      return accountId;
    });
  }

  /// Reads a statement day, accepting the empty string the desktop's form
  /// sends for "not set".
  static int? _parseStatementDate(Object? value) {
    if (value == null || value == '') {
      return null;
    }
    final day = value is int ? value : int.tryParse(value.toString());
    if (day == null || day < 1 || day > 31) {
      throw const AccountError(
        AccountErrorCode.invalidStatementDay,
        'The statement day must be a number from 1 to 31.',
      );
    }
    return day;
  }

  /// Returns the network logo path for a card number, or '' if unrecognised.
  ///
  /// ORDER MATTERS. Troy numbers begin 9792 and Mastercard begins 5, so the
  /// most specific prefix has to be tested first; checking Mastercard's
  /// single digit before Troy's four would leave every Troy card unmatched.
  static String cardNetworkLogo(String? cardNumber) {
    if (cardNumber == null) {
      return '';
    }
    final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return '';
    }
    if (digits.startsWith('9792')) {
      return networkLogos['Troy']!;
    }
    if (digits.startsWith('4')) {
      return networkLogos['Visa']!;
    }
    if (digits.startsWith('5') || digits.startsWith('2')) {
      return networkLogos['Mastercard']!;
    }
    return '';
  }

  /// Every account, checking accounts first, then by id.
  Future<List<Account>> getAccounts() async {
    final rows = await _db
        .customSelect(
          "SELECT * FROM accounts ORDER BY "
          "CASE WHEN account_type = 'credit_card' THEN 1 ELSE 0 END, id",
        )
        .get();
    return [for (final row in rows) Account.fromRow(row.data)];
  }

  /// One account, or null when no row has that id.
  Future<Account?> getAccount(int accountId) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM accounts WHERE id = ?',
          variables: [Variable<int>(accountId)],
        )
        .getSingleOrNull();
    return row == null ? null : Account.fromRow(row.data);
  }

  /// Does the account exist? A precondition for anything that writes a row
  /// referencing an account.
  ///
  /// The desktop needs this because it no longer seeds a default account, so
  /// its `DEFAULT_ACCOUNT_ID` matches nothing on a fresh install and flows
  /// that assumed otherwise were creating ownerless records.
  Future<bool> accountExists(int accountId) async {
    final row = await _db
        .customSelect(
          'SELECT 1 FROM accounts WHERE id = ?',
          variables: [Variable<int>(accountId)],
        )
        .getSingleOrNull();
    return row != null;
  }

  /// Has the user created any account at all? The onboarding gate's condition.
  Future<bool> hasAnyAccount() async {
    final row = await _db
        .customSelect('SELECT 1 FROM accounts LIMIT 1')
        .getSingleOrNull();
    return row != null;
  }

  /// Net worth and its components.
  Future<NetWorth> getNetWorth() async {
    var cash = Decimal.zero;
    var cardDebt = Decimal.zero;
    for (final account in await getAccounts()) {
      if (account.accountType == AccountType.creditCard) {
        cardDebt += account.debt;
      } else {
        cash += account.balance;
      }
    }
    return NetWorth(cash: cash, cardDebt: cardDebt, net: cash - cardDebt);
  }

  /// Closes the card to new income and expense transactions.
  Future<void> setCardFrozen(int accountId, bool frozen) =>
      _setCardPreference(accountId, 'is_frozen', frozen);

  /// Records the online-shopping preference.
  ///
  /// It does not block anything today: a transaction carries no
  /// online/offline attribute, so there is nothing to test it against. The
  /// screen presents it as a stored preference rather than a control.
  Future<void> setOnlinePayments(int accountId, bool enabled) =>
      _setCardPreference(accountId, 'online_payments_enabled', enabled);

  Future<void> _setCardPreference(
    int accountId,
    String column,
    bool enabled,
  ) async {
    // The column name is interpolated into SQL, so it is checked against a
    // fixed set rather than trusted — both call sites are internal today, but
    // the guard is what keeps that true.
    if (column != 'is_frozen' && column != 'online_payments_enabled') {
      throw const AccountError(
        AccountErrorCode.unknownCardPreference,
        'Unknown card preference column.',
      );
    }
    final updated = await _db.customUpdate(
      'UPDATE accounts SET $column = ? WHERE id = ?',
      variables: [Variable<int>(enabled ? 1 : 0), Variable<int>(accountId)],
      updates: const {},
    );
    if (updated != 1) {
      throw const AccountError(
        AccountErrorCode.accountNotFound,
        'No account with that id.',
      );
    }
  }

  /// Throws unless [accountId] may take this transaction.
  ///
  /// CALL THIS INSIDE THE TRANSACTION THAT DOES THE WRITE. The decision and
  /// the write have to share one commit: a check that reads on its own cannot
  /// see a commit landing between the two, so two concurrent spends could
  /// consume the same limit snapshot and push a 100-lira card to 120. Drift's
  /// sqlite3 executor opens transactions with `BEGIN IMMEDIATE`, so a caller
  /// already inside [ArchlenceDatabase.transaction] holds the write lock and
  /// this reads the state that lock protects. This function serialises
  /// nothing by itself.
  ///
  /// The desktop keeps this rule in one place after learning why it matters:
  /// `transaction_service` had solved the race by copying the rule into
  /// itself, and `asset_purchase_service`, which did not copy it, was left
  /// checking outside the transaction.
  ///
  /// A frozen account rejects everything, income included. A checking account
  /// is NOT limited by its balance — going deliberately negative is allowed;
  /// only a card's limit is enforced. Paying down card debt does not come
  /// through here and works on a frozen card.
  Future<void> assertSpendingAllowed(
    int accountId,
    Object? amount, {
    String transactionType = 'expense',
    bool enforceLimits = true,
  }) async {
    final row = await _db
        .customSelect(
          'SELECT account_type, type, balance, credit_limit, is_frozen '
          'FROM accounts WHERE id = ?',
          variables: [Variable<int>(accountId)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw AccountError(
        AccountErrorCode.accountNotFound,
        'No account with id $accountId.',
      );
    }
    if ((row.data['is_frozen'] as int? ?? 0) != 0) {
      throw const AccountError(
        AccountErrorCode.cardFrozen,
        'The card is frozen; unfreeze it before making transactions.',
      );
    }

    // 'Gider' is the Turkish spelling the desktop's older rows carry.
    final isExpense =
        transactionType == 'expense' || transactionType == 'Gider';
    if (!isExpense || !enforceLimits) {
      return;
    }

    final Decimal spend;
    try {
      spend = fiat(amount);
    } on FinancialValueError catch (error) {
      throw AccountError(
        AccountErrorCode.invalidAmount,
        'Invalid amount: ${error.message}',
      );
    }

    final accountType =
        AccountType.fromWire(row.data['account_type'] as String?) ??
        ((row.data['type'] as String?) == 'credit'
            ? AccountType.creditCard
            : AccountType.checking);
    if (accountType != AccountType.creditCard) {
      return;
    }

    final limit = fiat(row.data['credit_limit'] ?? 0);
    // Zero means "no limit recorded", not "no room". Cards arriving from the
    // desktop's migration have it, and blocking them would be wrong.
    if (limit <= Decimal.zero) {
      return;
    }

    final debt = _atLeastZero(-fiat(row.data['balance'] ?? 0));
    if (debt + spend > limit) {
      throw AccountError(
        AccountErrorCode.insufficientLimit,
        'Available limit ${limit - debt}, requested $spend.',
      );
    }
  }

  /// The asking form of [assertSpendingAllowed], for telling the user before
  /// they commit to something.
  ///
  /// CAREFUL: the answer can go stale the moment it is returned. Do not use
  /// it as the guard in front of a write — that is what
  /// [assertSpendingAllowed] inside the write's own transaction is for.
  Future<SpendingDecision> checkSpendingAllowed(
    int accountId,
    Object? amount, {
    String transactionType = 'expense',
    bool enforceLimits = true,
  }) async {
    try {
      await assertSpendingAllowed(
        accountId,
        amount,
        transactionType: transactionType,
        enforceLimits: enforceLimits,
      );
    } on AccountError catch (error) {
      return SpendingDecision.rejected(error);
    }
    return const SpendingDecision.allowed();
  }

  /// Pays card debt from a checking account, moving the money and writing
  /// both sides of the ledger in one commit.
  ///
  /// The two rows written to `transactions` are what makes the payment show
  /// up on each account's statement: an `expense` on the source account and a
  /// `payment` on the card. The card side is deliberately not an `income` —
  /// the desktop's reports count income, and a debt payment is not earnings.
  ///
  /// Unlike spending, this works on a frozen card. Freezing is meant to stop
  /// new debt, not to trap the user with debt they cannot clear.
  Future<void> payCreditCardDebt({
    required int creditCardId,
    required int sourceAccountId,
    required Object? amount,
  }) async {
    final Decimal payment;
    try {
      payment = fiat(amount);
    } on FinancialValueError catch (error) {
      // NaN and infinity have to be stopped HERE, before any SQL. Every
      // comparison against NaN is false, so it slips past both the
      // "positive?" and the "over the debt?" tests below and reaches the
      // first UPDATE, where it sets a real balance to NULL inside the
      // transaction. The desktop measured exactly this: the write rolled back
      // and left no corruption, but the decision was being made past the
      // boundary instead of at it.
      throw AccountError(
        AccountErrorCode.invalidPaymentAmount,
        'The payment amount must be a finite number: ${error.message}',
      );
    }
    if (payment <= Decimal.zero) {
      throw const AccountError(
        AccountErrorCode.paymentNotPositive,
        'The payment amount must be greater than zero.',
      );
    }

    final paymentAsDouble = payment.toDouble();

    await _db.transaction(() async {
      final card = await getAccount(creditCardId);
      if (card == null || card.accountType != AccountType.creditCard) {
        throw const AccountError(
          AccountErrorCode.notACreditCard,
          'No credit card with that id.',
        );
      }
      if (card.debt <= Decimal.zero) {
        throw const AccountError(
          AccountErrorCode.noDebtToPay,
          'This card has no outstanding debt.',
        );
      }
      if (payment > card.debt) {
        throw AccountError(
          AccountErrorCode.paymentExceedsDebt,
          'The payment cannot exceed the debt of ${card.debt}.',
        );
      }

      final source = await getAccount(sourceAccountId);
      if (source == null || source.accountType != AccountType.checking) {
        throw const AccountError(
          AccountErrorCode.sourceMustBeChecking,
          'A card payment must come from a checking account.',
        );
      }

      final debited = await _db.customUpdate(
        'UPDATE accounts SET balance = balance - ? '
        'WHERE id = ? AND account_type = ?',
        variables: [
          Variable<double>(paymentAsDouble),
          Variable<int>(sourceAccountId),
          Variable<String>(AccountType.checking.wireValue),
        ],
        updates: const {},
      );
      if (debited != 1) {
        throw const AccountError(
          AccountErrorCode.balanceUpdateFailed,
          'The source balance could not be updated.',
        );
      }

      // `balance <= -payment` re-tests the debt against the row as the write
      // itself sees it, so a payment cannot overshoot on a card whose debt
      // moved after the check above.
      //
      // NOT COVERED BY A TEST, deliberately. Within this app the case cannot
      // be staged: drift's sqlite3 executor opens transactions with
      // `BEGIN IMMEDIATE`, so the check above already reads under the write
      // lock and no second writer can interleave. What this defends against
      // is a writer outside the app — the desktop, holding the same file —
      // which a unit test has no way to produce. Removing it therefore
      // breaks nothing visible, which is exactly why the reason is recorded
      // here.
      final credited = await _db.customUpdate(
        'UPDATE accounts SET balance = balance + ? '
        'WHERE id = ? AND account_type = ? AND balance <= ?',
        variables: [
          Variable<double>(paymentAsDouble),
          Variable<int>(creditCardId),
          Variable<String>(AccountType.creditCard.wireValue),
          Variable<double>(-paymentAsDouble),
        ],
        updates: const {},
      );
      if (credited != 1) {
        throw const AccountError(
          AccountErrorCode.paymentExceedsDebt,
          'The payment cannot exceed the current card debt.',
        );
      }

      await recordBalanceEvent(
        _db,
        entityType: accountEntity,
        entityId: sourceAccountId,
        delta: -paymentAsDouble,
        resultingValue: await _rawBalance(sourceAccountId),
        source: 'card_payment',
      );
      await recordBalanceEvent(
        _db,
        entityType: accountEntity,
        entityId: creditCardId,
        delta: paymentAsDouble,
        resultingValue: await _rawBalance(creditCardId),
        source: 'card_payment',
      );

      // Written as the desktop writes it: the amount through `str(float)`, so
      // a value stored by either app parses back the same way.
      final encryptedAmount = await _crypto.encryptField(
        paymentAsDouble.toString(),
      );
      final encryptedDescription = await _crypto.encryptField(
        '${card.name} $debtPaymentDescriptionSuffix',
      );
      final now = sqliteTimestamp(DateTime.now());

      for (final (accountId, type) in [
        (sourceAccountId, 'expense'),
        (creditCardId, 'payment'),
      ]) {
        await _db.customInsert(
          'INSERT INTO transactions '
          '(account_id, amount, type, category, description, transaction_date) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          variables: [
            Variable<int>(accountId),
            Variable<String>(encryptedAmount),
            Variable<String>(type),
            Variable<String>(debtPaymentCategory),
            Variable<String>(encryptedDescription),
            Variable<String>(now),
          ],
        );
      }
    });
  }

  /// The signed `balance` column as stored, for the ledger's
  /// `resulting_value`.
  Future<double> _rawBalance(int accountId) async {
    final row = await _db
        .customSelect(
          'SELECT balance FROM accounts WHERE id = ?',
          variables: [Variable<int>(accountId)],
        )
        .getSingle();
    return row.read<double>('balance');
  }

  /// Deletes a card together with every record that depends on it.
  Future<void> deleteCreditCard(int creditCardId) async {
    await _db.transaction(() async {
      final card = await _db
          .customSelect(
            'SELECT id FROM accounts WHERE id = ? AND account_type = ?',
            variables: [
              Variable<int>(creditCardId),
              Variable<String>(AccountType.creditCard.wireValue),
            ],
          )
          .getSingleOrNull();
      if (card == null) {
        throw const AccountError(
          AccountErrorCode.notACreditCard,
          'No credit card with that id.',
        );
      }

      // The desktop creates installment_plans lazily on the first plan, so a
      // database that has never had one legitimately lacks the table.
      if (await _tableExists('installment_plans')) {
        await _db.customUpdate(
          'DELETE FROM installment_plans WHERE account_id = ?',
          variables: [Variable<int>(creditCardId)],
          updates: const {},
        );
      }
      for (final statement in const [
        'DELETE FROM recurring_payments WHERE account_id = ?',
        'DELETE FROM transactions WHERE account_id = ?',
      ]) {
        await _db.customUpdate(
          statement,
          variables: [Variable<int>(creditCardId)],
          updates: const {},
        );
      }
      await _db.customUpdate(
        'DELETE FROM balance_events WHERE entity_type = ? AND entity_id = ?',
        variables: [
          Variable<String>(accountEntity),
          Variable<int>(creditCardId),
        ],
        updates: const {},
      );
      final deleted = await _db.customUpdate(
        'DELETE FROM accounts WHERE id = ? AND account_type = ?',
        variables: [
          Variable<int>(creditCardId),
          Variable<String>(AccountType.creditCard.wireValue),
        ],
        updates: const {},
      );
      if (deleted != 1) {
        throw const AccountError(
          AccountErrorCode.notACreditCard,
          'No credit card with that id.',
        );
      }
    });
  }

  /// How many instalment plans on the card are still running.
  Future<int> getActiveInstallmentPlanCount(int creditCardId) async {
    if (!await _tableExists('installment_plans')) {
      return 0;
    }
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS plan_count FROM installment_plans '
          'WHERE account_id = ? AND paid_installments < total_installments',
          variables: [Variable<int>(creditCardId)],
        )
        .getSingleOrNull();
    return row == null ? 0 : row.read<int>('plan_count');
  }

  Future<bool> _tableExists(String name) async {
    final row = await _db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [Variable<String>(name)],
        )
        .getSingleOrNull();
    return row != null;
  }
}
