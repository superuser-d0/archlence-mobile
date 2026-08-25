/// Savings goals: isolating money from the checking account, and giving it
/// back.
///
/// A port of `services/savings_service.py`.
///
/// A deposit is NOT an expense. Money moves out of `accounts.balance` and into
/// the goal's `current_amount` inside one commit — the two are atomic, and an
/// interruption rolls back both. Nothing is written to `transactions`, on
/// purpose: setting money aside must not appear as spending in any chart.
/// Withdrawal is the exact inverse.
///
/// `goal_name` is stored encrypted; the amounts are plain REALs, which is why
/// the status comparisons below round in SQL — see [SavingsService.depositToGoal].
///
/// Departures from the Python:
///
///  * `accountId` is REQUIRED rather than defaulting to `DEFAULT_ACCOUNT_ID`.
///    The desktop removed its seeded default account, so that constant now
///    matches no row on a fresh install and the default only ever produced
///    ownerless writes.
///  * An unreadable goal name reads back as `null`, not `"Bilinmeyen Hedef"`.
///    Same reasoning as elsewhere: a placeholder that looks like data is worse
///    than an absence that says so.
library;

import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../crypto/field_crypto.dart';
import '../crypto/key_provider.dart';
import '../data/balance_events.dart';
import '../data/database.dart';
import '../money/financial_decimal.dart';

/// The literal `status` strings the column holds.
class SavingsStatus {
  const SavingsStatus._();

  static const String active = 'aktif';
  static const String completed = 'tamamlandi';
}

enum SavingsErrorCode {
  invalidAmount,
  amountNotPositive,
  negativeOpeningAmount,
  identityMismatch,
  accountNotFound,
  goalNotFoundOrCompleted,
  insufficientGoalBalance,
  refundAccountRequired,
}

class SavingsError implements Exception {
  const SavingsError(this.code, this.message);

  final SavingsErrorCode code;
  final String message;

  @override
  String toString() => 'SavingsError(${code.name}): $message';
}

/// One savings goal.
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.goalUid,
    required this.goalName,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.status,
    required this.color,
    required this.autoDeposit,
    required this.createdAt,
  });

  /// The ONE place a row becomes a goal.
  ///
  /// The desktop built this shape in two places and they drifted: a field
  /// added to one and not the other made goal cards lose their colour after
  /// an operation. A single factory makes that impossible rather than
  /// unlikely.
  factory SavingsGoal.fromRow(Map<String, Object?> row, String? name) {
    return SavingsGoal(
      id: row['id']! as int,
      goalUid: row['goal_uid']! as String,
      goalName: name,
      targetAmount: fiat(row['target_amount'] ?? 0),
      currentAmount: fiat(row['current_amount'] ?? 0),
      targetDate: row['target_date'] as String?,
      status: row['status'] as String? ?? SavingsStatus.active,
      color: row['color'] as String?,
      autoDeposit: (row['auto_deposit'] as int? ?? 0) != 0,
      createdAt: row['created_at'] as String?,
    );
  }

  final int id;

  /// The DURABLE identity. The numeric [id] can be reused after a restore, so
  /// it cannot say on its own which goal a user action meant.
  final String goalUid;

  /// Null when the stored name could not be decrypted.
  final String? goalName;

  final Decimal targetAmount;
  final Decimal currentAmount;
  final String? targetDate;
  final String status;
  final String? color;
  final bool autoDeposit;
  final String? createdAt;

  bool get isCompleted => status == SavingsStatus.completed;
}

/// A random UUID v4, for [SavingsGoal.goalUid].
///
/// Written out rather than pulled from a package: one function is cheaper
/// than a dependency, and the only thing that matters is that it is random
/// and shaped like what the desktop's `str(uuid4())` writes.
String generateGoalUid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
  final hex = [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')]
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class SavingsService {
  SavingsService(this._db, this._crypto);

  final ArchlenceDatabase _db;
  final FieldCrypto _crypto;

  /// Opens a goal and returns its id.
  ///
  /// [goalUid] is generated here unless a caller supplies one; only a
  /// migration does, and it supplies a fresh UUID too.
  Future<int> createGoal({
    required String goalName,
    required Object? targetAmount,
    Object? currentAmount = 0,
    String? targetDate,
    String? color,
    bool autoDeposit = false,
    String? createdAt,
    String? goalUid,
  }) async {
    final target = _requireFinite(targetAmount);
    final current = _requireFinite(currentAmount);
    if (target <= Decimal.zero) {
      throw const SavingsError(
        SavingsErrorCode.amountNotPositive,
        'The target amount must be greater than zero.',
      );
    }
    if (current < Decimal.zero) {
      throw const SavingsError(
        SavingsErrorCode.negativeOpeningAmount,
        'The opening amount cannot be negative.',
      );
    }

    final openingAmount = current.toDouble();
    return _db.transaction(() async {
      final goalId = await _db.customInsert(
        'INSERT INTO savings_goals (goal_name, target_amount, current_amount, '
        'target_date, status, goal_uid, color, auto_deposit, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable<String>((await _crypto.encryptField(goalName))!),
          Variable<double>(target.toDouble()),
          Variable<double>(openingAmount),
          Variable<String>(targetDate),
          Variable<String>(
            current >= target ? SavingsStatus.completed : SavingsStatus.active,
          ),
          Variable<String>(goalUid ?? generateGoalUid()),
          Variable<String>(color),
          Variable<int>(autoDeposit ? 1 : 0),
          Variable<String>(createdAt ?? sqliteDate(DateTime.now())),
        ],
      );

      // Written even at zero: it does not move a total, but it keeps the
      // ledger's record of the goal's existence complete.
      await recordBalanceEvent(
        _db,
        entityType: savingsGoalEntity,
        entityId: goalId,
        delta: openingAmount,
        resultingValue: openingAmount,
        source: 'savings_goal_created',
      );
      return goalId;
    });
  }

  /// Every goal, oldest first.
  Future<List<SavingsGoal>> getGoals({bool onlyActive = false}) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM savings_goals'
          '${onlyActive ? ' WHERE status = ?' : ''}'
          ' ORDER BY id',
          variables: [if (onlyActive) Variable<String>(SavingsStatus.active)],
        )
        .get();
    return [
      for (final row in rows)
        SavingsGoal.fromRow(row.data, await _readName(row.data['goal_name'])),
    ];
  }

  /// One goal, or null if it does not exist.
  Future<SavingsGoal?> getGoal(int goalId) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM savings_goals WHERE id = ?',
          variables: [Variable<int>(goalId)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return SavingsGoal.fromRow(
      row.data,
      await _readName(row.data['goal_name']),
    );
  }

  /// Moves money from a checking account into a goal, and returns the goal.
  ///
  /// There is deliberately NO insufficient-balance guard: the user may take
  /// the account negative to fund a goal, the same decision the ledger makes
  /// for an ordinary expense.
  ///
  /// THE STATUS COMPARISONS ROUND IN SQL. `current_amount` is a REAL column
  /// updated with `current_amount + ?`, so it drifts: nine deposits of 0.60
  /// leave a goal a hair BELOW a 10.40 target while the screen shows
  /// 10.40/10.40. Comparing the raw values would flip a goal the user can see
  /// is finished back to "active".
  Future<SavingsGoal?> depositToGoal({
    required int goalId,
    required Object? amount,
    required int accountId,
    String? goalUid,
  }) async {
    final quantized = _requirePositive(amount, 'The deposit');
    final amountAsDouble = quantized.toDouble();

    return _db.transaction(() async {
      await _assertIdentity(goalId, goalUid);

      final debited = await _db.customUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        variables: [Variable<double>(amountAsDouble), Variable<int>(accountId)],
        updates: const {},
      );
      if (debited == 0) {
        throw SavingsError(
          SavingsErrorCode.accountNotFound,
          'No account with id $accountId.',
        );
      }

      final credited = await _db.customUpdate(
        'UPDATE savings_goals SET current_amount = current_amount + ? '
        'WHERE id = ? AND status != ?',
        variables: [
          Variable<double>(amountAsDouble),
          Variable<int>(goalId),
          Variable<String>(SavingsStatus.completed),
        ],
        updates: const {},
      );
      if (credited == 0) {
        throw const SavingsError(
          SavingsErrorCode.goalNotFoundOrCompleted,
          'No such goal, or it is already complete.',
        );
      }

      await _db.customUpdate(
        'UPDATE savings_goals SET status = ? WHERE id = ? '
        'AND ROUND(current_amount, 2) >= ROUND(target_amount, 2)',
        variables: [
          Variable<String>(SavingsStatus.completed),
          Variable<int>(goalId),
        ],
        updates: const {},
      );

      await recordBalanceEvent(
        _db,
        entityType: accountEntity,
        entityId: accountId,
        delta: -amountAsDouble,
        resultingValue: await _accountBalance(accountId),
        source: 'savings_deposit',
        refId: goalId,
      );
      await recordBalanceEvent(
        _db,
        entityType: savingsGoalEntity,
        entityId: goalId,
        delta: amountAsDouble,
        resultingValue: await _goalAmount(goalId),
        source: 'savings_deposit',
        refId: accountId,
      );

      return getGoal(goalId);
    });
  }

  /// Returns money from a goal to a checking account — the inverse of
  /// [depositToGoal], under the same atomic pattern.
  ///
  /// The guard `ROUND(current_amount, 2) >= ROUND(amount, 2)` is what makes a
  /// goal showing 10.40 fully withdrawable: comparing raw REALs would refuse
  /// the user their own money by a fraction of a kurus.
  Future<SavingsGoal?> withdrawFromGoal({
    required int goalId,
    required Object? amount,
    required int accountId,
    String? goalUid,
  }) async {
    final quantized = _requirePositive(amount, 'The withdrawal');
    final amountAsDouble = quantized.toDouble();

    return _db.transaction(() async {
      await _assertIdentity(goalId, goalUid);

      final debited = await _db.customUpdate(
        'UPDATE savings_goals SET current_amount = current_amount - ? '
        'WHERE id = ? AND ROUND(current_amount, 2) >= ROUND(?, 2)',
        variables: [
          Variable<double>(amountAsDouble),
          Variable<int>(goalId),
          Variable<double>(amountAsDouble),
        ],
        updates: const {},
      );
      if (debited == 0) {
        throw const SavingsError(
          SavingsErrorCode.insufficientGoalBalance,
          'The goal does not hold that much.',
        );
      }

      await _db.customUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        variables: [Variable<double>(amountAsDouble), Variable<int>(accountId)],
        updates: const {},
      );

      // The complement of the completion rule: a withdrawal that really does
      // drop below the target reopens the goal. Without this, "completed"
      // would be sticky — a bug the rounding fix could easily have created.
      await _db.customUpdate(
        'UPDATE savings_goals SET status = ? WHERE id = ? '
        'AND ROUND(current_amount, 2) < ROUND(target_amount, 2)',
        variables: [
          Variable<String>(SavingsStatus.active),
          Variable<int>(goalId),
        ],
        updates: const {},
      );

      await recordBalanceEvent(
        _db,
        entityType: savingsGoalEntity,
        entityId: goalId,
        delta: -amountAsDouble,
        resultingValue: await _goalAmount(goalId),
        source: 'savings_withdraw',
        refId: accountId,
      );
      await recordBalanceEvent(
        _db,
        entityType: accountEntity,
        entityId: accountId,
        delta: amountAsDouble,
        resultingValue: await _accountBalance(accountId),
        source: 'savings_withdraw',
        refId: goalId,
      );

      return getGoal(goalId);
    });
  }

  /// Deletes a goal, returning its balance to [accountId] when [refund] is
  /// set. Returns whether a goal was there to delete.
  ///
  /// Identity is checked here too: deleting is the most expensive thing to do
  /// to the wrong goal.
  Future<bool> deleteGoal({
    required int goalId,
    int? accountId,
    bool refund = true,
    String? goalUid,
  }) async {
    return _db.transaction(() async {
      await _assertIdentity(goalId, goalUid);

      final row = await _db
          .customSelect(
            'SELECT current_amount FROM savings_goals WHERE id = ?',
            variables: [Variable<int>(goalId)],
          )
          .getSingleOrNull();
      if (row == null) return false;

      final refundAmount = fiat(row.data['current_amount'] ?? 0).toDouble();
      if (refund && refundAmount > 0) {
        if (accountId == null) {
          throw const SavingsError(
            SavingsErrorCode.refundAccountRequired,
            'An account to refund the balance into must be chosen.',
          );
        }
        final credited = await _db.customUpdate(
          'UPDATE accounts SET balance = balance + ? '
          "WHERE id = ? AND account_type = 'checking'",
          variables: [Variable<double>(refundAmount), Variable<int>(accountId)],
          updates: const {},
        );
        if (credited != 1) {
          throw SavingsError(
            SavingsErrorCode.accountNotFound,
            'No checking account with id $accountId.',
          );
        }
        await recordBalanceEvent(
          _db,
          entityType: accountEntity,
          entityId: accountId,
          delta: refundAmount,
          resultingValue: await _accountBalance(accountId),
          source: 'savings_goal_deleted',
          refId: goalId,
        );
      }

      // The goal's own closing line. The source distinguishes money given
      // back from money written off, which is the only trace left once the
      // row is gone.
      await recordBalanceEvent(
        _db,
        entityType: savingsGoalEntity,
        entityId: goalId,
        delta: -refundAmount,
        resultingValue: 0,
        source: refund ? 'savings_goal_deleted' : 'savings_goal_discarded',
        refId: accountId,
      );

      await _db.customUpdate(
        'DELETE FROM savings_goals WHERE id = ?',
        variables: [Variable<int>(goalId)],
        updates: const {},
      );
      return true;
    });
  }

  /// Proves the numeric id and the durable identity name the same row.
  ///
  /// FAIL-CLOSED, and it runs BEFORE any money moves. A numeric `id` can be
  /// reused after a restore: create two goals, restore a backup taken between
  /// them, and goal 2's id is free for the next goal to take. A screen still
  /// holding the old card would then fund a goal the user never meant.
  ///
  /// A null [goalUid] skips the check — a deliberate door for callers that do
  /// not know the identity (tests, maintenance). Any screen must pass one.
  Future<void> _assertIdentity(int goalId, String? goalUid) async {
    if (goalUid == null) return;
    final row = await _db
        .customSelect(
          'SELECT 1 FROM savings_goals WHERE id = ? AND goal_uid = ?',
          variables: [Variable<int>(goalId), Variable<String>(goalUid)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw const SavingsError(
        SavingsErrorCode.identityMismatch,
        'This goal no longer exists or has changed; the operation was stopped '
        'and no money moved.',
      );
    }
  }

  Future<double> _accountBalance(int accountId) async {
    final row = await _db
        .customSelect(
          'SELECT balance FROM accounts WHERE id = ?',
          variables: [Variable<int>(accountId)],
        )
        .getSingleOrNull();
    return row == null ? 0 : (row.data['balance'] as double? ?? 0);
  }

  Future<double> _goalAmount(int goalId) async {
    final row = await _db
        .customSelect(
          'SELECT current_amount FROM savings_goals WHERE id = ?',
          variables: [Variable<int>(goalId)],
        )
        .getSingleOrNull();
    return row == null ? 0 : (row.data['current_amount'] as double? ?? 0);
  }

  Future<String?> _readName(Object? stored) async {
    try {
      return (await _crypto.decryptField(stored)) ?? '';
    } on KeyUnavailableError {
      rethrow;
    } on Exception {
      return null;
    }
  }

  Decimal _requireFinite(Object? value) {
    try {
      return fiat(value);
    } on FinancialValueError catch (error) {
      throw SavingsError(
        SavingsErrorCode.invalidAmount,
        'The amount must be a finite number: ${error.message}',
      );
    }
  }

  Decimal _requirePositive(Object? value, String label) {
    final quantized = _requireFinite(value);
    if (quantized <= Decimal.zero) {
      throw SavingsError(
        SavingsErrorCode.amountNotPositive,
        '$label amount must be greater than zero.',
      );
    }
    return quantized;
  }
}
