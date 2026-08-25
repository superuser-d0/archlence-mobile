/// Monthly budget planning and tracking, ported from the desktop's
/// `test_budget_service.py`.
library;

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/money/financial_decimal.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/budget_service.dart';
import 'package:archlence_mobile/services/recurring_service.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';

void main() {
  late ArchlenceDatabase db;
  late FieldCrypto crypto;
  late AccountService accounts;
  late RecurringService recurring;
  late BudgetService budget;

  setUp(() {
    db = ArchlenceDatabase.memory();
    crypto = FieldCrypto(FixedKeyProvider.arbitrary());
    accounts = AccountService(db, crypto);
    recurring = RecurringService(db, crypto, accounts);
    budget = BudgetService(db, crypto, recurring);
  });

  tearDown(() => db.close());

  Decimal money(String value) => fiat(value);

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  Future<List<Map<String, Object?>>> planRows() async {
    final rows = await db
        .customSelect('SELECT * FROM monthly_budget_plan ORDER BY id')
        .get();
    return [for (final row in rows) row.data];
  }

  /// Writes a plan row directly, the way the desktop's own fixture does —
  /// the point is a known starting state, not exercising the write rules.
  Future<int> plan({
    required int year,
    required int month,
    required Object amount,
    String? category,
    String name = 'Kalem',
    String type = 'expense',
    int rollover = 0,
    int template = 0,
    int threshold = 80,
  }) {
    return db.customInsert(
      'INSERT INTO monthly_budget_plan (type, name, amount, target_month, '
      'target_year, category_name, rollover_enabled, is_template, '
      'alert_threshold_pct) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable<String>(type),
        Variable<String>(name),
        Variable<double>(double.parse(amount.toString())),
        Variable<int>(month),
        Variable<int>(year),
        Variable<String>(category),
        Variable<int>(rollover),
        Variable<int>(template),
        Variable<int>(threshold),
      ],
    );
  }

  /// A completed expense, with its amount encrypted as the ledger stores it.
  Future<void> expense(String category, Object amount, String date) async {
    await db.customInsert(
      'INSERT INTO transactions (account_id, amount, type, category, '
      "description, transaction_date, status) "
      "VALUES (NULL, ?, 'expense', ?, ?, ?, 'completed')",
      variables: [
        Variable<String>((await crypto.encryptField(amount.toString()))!),
        Variable<String>(category),
        Variable<String>((await crypto.encryptField('Test'))!),
        Variable<String>('$date 12:00:00'),
      ],
    );
  }

  group('the effective plan', () {
    test('keeps the same month in different years apart', () async {
      await plan(year: 2026, month: 1, amount: 100, category: 'Süpermarket');
      await plan(year: 2027, month: 1, amount: 700, category: 'Süpermarket');

      expect(
        (await budget.calculateMonthlyBudget(1, 2026)).plannedExpense,
        money('100'),
      );
      expect(
        (await budget.calculateMonthlyBudget(1, 2027)).plannedExpense,
        money('700'),
      );
    });

    test('a template applies to every month until one overrides it', () async {
      await plan(
        year: 2026,
        month: 7,
        amount: 400,
        category: 'Süpermarket',
        template: 1,
      );
      expect(
        (await budget.calculateMonthlyBudget(8, 2026)).plannedExpense,
        money('400'),
      );

      // A concrete item for August replaces the template THERE and nowhere
      // else — that is the whole point of editing one month of a repeating
      // line.
      await plan(year: 2026, month: 8, amount: 550, category: 'Süpermarket');
      expect(
        (await budget.calculateMonthlyBudget(8, 2026)).plannedExpense,
        money('550'),
      );
      expect(
        (await budget.calculateMonthlyBudget(9, 2026)).plannedExpense,
        money('400'),
      );
    });

    test(
      'a later template of the same identity replaces the earlier one',
      () async {
        await plan(
          year: 2026,
          month: 1,
          amount: 400,
          category: 'Süpermarket',
          template: 1,
        );
        await plan(
          year: 2026,
          month: 1,
          amount: 650,
          category: 'Süpermarket',
          template: 1,
        );
        expect(
          (await budget.calculateMonthlyBudget(8, 2026)).plannedExpense,
          money('650'),
          reason: 'two templates for one category must not both count',
        );
      },
    );

    test('identity matching ignores letter case', () async {
      await plan(
        year: 2026,
        month: 1,
        amount: 400,
        category: 'Market',
        template: 1,
      );
      await plan(year: 2026, month: 8, amount: 550, category: 'market');
      expect(
        (await budget.calculateMonthlyBudget(8, 2026)).plannedExpense,
        money('550'),
        reason: '"Market" and "market" are one line, not two',
      );
    });

    test('an item without a category is identified by its name', () async {
      await plan(
        year: 2026,
        month: 1,
        amount: 1000,
        name: 'Maaş Planı',
        type: 'income',
        template: 1,
      );
      await plan(
        year: 2026,
        month: 8,
        amount: 1400,
        name: ' maaş planı ',
        type: 'income',
      );
      expect(
        (await budget.calculateMonthlyBudget(8, 2026)).plannedIncome,
        money('1400'),
      );
    });

    test('rejects a month outside 1-12', () async {
      for (final month in [0, 13]) {
        await expectLater(
          () => budget.calculateMonthlyBudget(month, 2026),
          throwsA(
            isA<BudgetError>().having(
              (e) => e.code,
              'code',
              BudgetErrorCode.invalidMonth,
            ),
          ),
        );
      }
    });
  });

  group('category progress', () {
    test('reports actual, percentage and what is left', () async {
      await plan(
        year: 2026,
        month: 5,
        amount: 500,
        category: 'Süpermarket',
        threshold: 75,
      );
      await expense('Süpermarket', 125, '2026-05-10');

      final progress = (await budget.getCategoryBudgetProgress(5, 2026)).single;
      expect(progress.planned, money('500'));
      expect(progress.actual, money('125'));
      expect(progress.pct, money('25'));
      expect(progress.remaining, money('375'));
      expect(progress.alertThresholdPct, 75);
    });

    test('overspending shows as a negative remainder', () async {
      await plan(year: 2026, month: 5, amount: 300, category: 'Kıyafet');
      await expense('Kıyafet', 450, '2026-05-20');

      final progress = (await budget.getCategoryBudgetProgress(5, 2026)).single;
      expect(progress.remaining, money('-150'));
      expect(progress.pct, money('150'));
    });

    test('a pending transaction is not spending yet', () async {
      // The money has not left the account; counting it would report a
      // category as spent while the cash is still there.
      await plan(year: 2026, month: 5, amount: 500, category: 'Süpermarket');
      await db.customInsert(
        'INSERT INTO transactions (account_id, amount, type, category, '
        "description, transaction_date, status) "
        "VALUES (NULL, ?, 'expense', 'Süpermarket', ?, ?, 'pending')",
        variables: [
          Variable<String>((await crypto.encryptField('125'))!),
          Variable<String>((await crypto.encryptField('Test'))!),
          Variable<String>('2026-05-10 12:00:00'),
        ],
      );

      expect(
        (await budget.getCategoryBudgetProgress(5, 2026)).single.actual,
        Decimal.zero,
      );
    });

    test(
      'a row written before the status column existed still counts',
      () async {
        await plan(year: 2026, month: 5, amount: 500, category: 'Süpermarket');
        await db.customInsert(
          'INSERT INTO transactions (account_id, amount, type, category, '
          "description, transaction_date, status) "
          "VALUES (NULL, ?, 'expense', 'Süpermarket', ?, ?, NULL)",
          variables: [
            Variable<String>((await crypto.encryptField('125'))!),
            Variable<String>((await crypto.encryptField('Test'))!),
            Variable<String>('2026-05-10 12:00:00'),
          ],
        );
        expect(
          (await budget.getCategoryBudgetProgress(5, 2026)).single.actual,
          money('125'),
        );
      },
    );

    test(
      'an unreadable amount fails the whole result, not just its row',
      () async {
        // A budget silently short by one category is worse than one that
        // refuses to draw.
        await plan(year: 2026, month: 5, amount: 500, category: 'Süpermarket');
        await db.customInsert(
          'INSERT INTO transactions (account_id, amount, type, category, '
          "description, transaction_date, status) "
          "VALUES (NULL, 'AEADv1:broken', 'expense', 'Süpermarket', ?, ?, "
          "'completed')",
          variables: [
            Variable<String>((await crypto.encryptField('Test'))!),
            Variable<String>('2026-05-10 12:00:00'),
          ],
        );

        await expectLater(
          budget.getCategoryBudgetProgress(5, 2026),
          throwsA(isA<BudgetDataIntegrityError>()),
        );
      },
    );

    test('an income plan line is not category progress', () async {
      await plan(
        year: 2026,
        month: 5,
        amount: 9000,
        category: 'Maaş',
        type: 'income',
      );
      expect(await budget.getCategoryBudgetProgress(5, 2026), isEmpty);
    });
  });

  group('rollover', () {
    test('carries last month\'s surplus when enabled', () async {
      // 1000 planned, 700 spent -> +300 into a new 500.
      await plan(year: 2025, month: 12, amount: 1000, category: 'Süpermarket');
      await expense('Süpermarket', 700, '2025-12-15');
      await plan(
        year: 2026,
        month: 1,
        amount: 500,
        category: 'Süpermarket',
        rollover: 1,
      );

      expect(
        await budget.getEffectiveLimit('Süpermarket', 1, 2026),
        money('800'),
      );
    });

    test('carries last month\'s overspend too', () async {
      // 300 planned, 450 spent -> -150 into a new 500.
      await plan(year: 2025, month: 12, amount: 300, category: 'Kıyafet');
      await expense('Kıyafet', 450, '2025-12-20');
      await plan(
        year: 2026,
        month: 1,
        amount: 500,
        category: 'Kıyafet',
        rollover: 1,
      );

      expect(await budget.getEffectiveLimit('Kıyafet', 1, 2026), money('350'));
    });

    test('is ignored when the flag is off', () async {
      await plan(year: 2025, month: 12, amount: 400, category: 'Ulaşım');
      await plan(year: 2026, month: 1, amount: 250, category: 'Ulaşım');

      expect(await budget.getEffectiveLimit('Ulaşım', 1, 2026), money('250'));
    });

    test('does not chain past the previous month', () async {
      // November's surplus must not reach January through December: what is
      // carried is December's OWN planned-minus-actual, not what December
      // inherited. Chaining would let one frugal month inflate every month
      // after it.
      await plan(year: 2025, month: 11, amount: 1000, category: 'Süpermarket');
      await plan(
        year: 2025,
        month: 12,
        amount: 400,
        category: 'Süpermarket',
        rollover: 1,
      );
      await plan(
        year: 2026,
        month: 1,
        amount: 500,
        category: 'Süpermarket',
        rollover: 1,
      );

      expect(
        await budget.getEffectiveLimit('Süpermarket', 1, 2026),
        money('900'),
        reason: '500 + December\'s own 400, not November\'s 1000 as well',
      );
    });

    test('a category with no plan this month has no limit', () async {
      expect(await budget.getEffectiveLimit('Yok', 1, 2026), Decimal.zero);
    });
  });

  group('subscription reservations', () {
    test('a subscription due this month is held back from the plan', () async {
      final accountId = await accounts.createAccount(
        name: 'Vadesiz',
        accountType: AccountType.checking,
        initialBalance: 10000,
      );
      await plan(
        year: 2026,
        month: 8,
        amount: 1000,
        name: 'Maaş Planı',
        type: 'income',
      );
      await recurring.insertRecurringPayment(
        name: 'Netflix',
        amount: 229.99,
        category: 'Dijital Abonelik',
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: DateTime(2026, 8, 31),
        accountId: accountId,
        recurrenceDay: 31,
      );

      final result = await budget.calculateMonthlyBudget(8, 2026);
      expect(result.reservedRecurring, money('229.99'));
      expect(result.remainingBudget, money('770.01'));

      expect(
        (await budget.calculateMonthlyBudget(7, 2026)).reservedRecurring,
        Decimal.zero,
        reason: 'it is not due in July',
      );
    });

    test(
      'a weekly subscription reserves every occurrence in the month',
      () async {
        // One month's fee would understate a weekly charge four- or five-fold.
        final accountId = await accounts.createAccount(
          name: 'Vadesiz',
          accountType: AccountType.checking,
          initialBalance: 10000,
        );
        await recurring.insertRecurringPayment(
          name: 'Haftalık',
          amount: 100,
          frequency: RecurrenceFrequency.weekly,
          nextDueDate: DateTime(2026, 8, 3),
          accountId: accountId,
          recurrenceDay: 3,
        );

        final items = await budget.getReservedRecurringItems(8, 2026);
        expect(items.single.occurrences, greaterThanOrEqualTo(4));
        expect(
          items.single.reservedAmount,
          money('100') * Decimal.fromInt(items.single.occurrences),
        );
      },
    );

    test(
      'a subscription with an unusable amount fails the reservation',
      () async {
        // Leaving it out would UNDER-reserve and overstate what is spendable —
        // the exact error a reservation exists to prevent.
        final accountId = await accounts.createAccount(
          name: 'Vadesiz',
          accountType: AccountType.checking,
          initialBalance: 10000,
        );
        await recurring.insertRecurringPayment(
          name: 'Bozuk',
          amount: 100,
          frequency: RecurrenceFrequency.monthly,
          nextDueDate: DateTime(2026, 8, 15),
          accountId: accountId,
        );
        await db.customUpdate(
          'UPDATE recurring_payments SET amount = ?',
          variables: [Variable<String>((await crypto.encryptField('-10'))!)],
          updates: const {},
        );

        await expectLater(
          budget.getReservedRecurringItems(8, 2026),
          throwsA(isA<BudgetDataIntegrityError>()),
        );
        await expectLater(
          budget.calculateMonthlyBudget(8, 2026),
          throwsA(isA<BudgetDataIntegrityError>()),
        );
      },
    );

    test('a cancelled subscription reserves nothing', () async {
      final accountId = await accounts.createAccount(
        name: 'Vadesiz',
        accountType: AccountType.checking,
        initialBalance: 10000,
      );
      final id = await recurring.insertRecurringPayment(
        name: 'Netflix',
        amount: 229.99,
        frequency: RecurrenceFrequency.monthly,
        nextDueDate: DateTime(2026, 8, 15),
        accountId: accountId,
      );
      await recurring.cancelSubscription(id);

      expect(
        (await budget.calculateMonthlyBudget(8, 2026)).reservedRecurring,
        Decimal.zero,
      );
    });
  });

  group('suggesting a limit', () {
    test('averages the last three completed months', () async {
      final today = DateTime.now();
      for (final (offset, amount) in [(-1, 300), (-2, 200), (-3, 100)]) {
        final (year, month) = shiftMonth(today.year, today.month, offset);
        await expense(
          'Süpermarket',
          amount,
          '$year-${month.toString().padLeft(2, '0')}-10',
        );
      }
      expect(await budget.suggestCategoryBudget('Süpermarket'), money('200'));
    });

    test('excludes the current month', () async {
      // A month only a third over would drag the suggestion to a third of
      // the truth.
      final today = DateTime.now();
      await expense(
        'Süpermarket',
        9000,
        '${today.year}-${today.month.toString().padLeft(2, '0')}-01',
      );
      expect(await budget.suggestCategoryBudget('Süpermarket'), isNull);
    });

    test('a category with no history suggests nothing', () async {
      expect(await budget.suggestCategoryBudget('Olmayan Kategori'), isNull);
    });
  });

  group('carrying a plan to the year end', () {
    test('copies concrete items into the remaining months', () async {
      await plan(year: 2026, month: 10, amount: 5000, category: 'Kira');
      await plan(year: 2026, month: 10, amount: 1200, category: 'Market');

      expect(await budget.applyPlanToYearEnd(10, 2026), 4);
      for (final month in [11, 12]) {
        final categories = {
          for (final item in await budget.getEffectivePlanItems(month, 2026))
            item.categoryName,
        };
        expect(categories, containsAll(['Kira', 'Market']));
      }
    });

    test('confirming twice adds nothing', () async {
      await plan(year: 2026, month: 11, amount: 5000, category: 'Kira');
      expect(await budget.applyPlanToYearEnd(11, 2026), 1);
      expect(await budget.applyPlanToYearEnd(11, 2026), 0);
    });

    test('skips a target month that already has the same identity', () async {
      await plan(year: 2026, month: 11, amount: 5000, category: 'Kira');
      await plan(year: 2026, month: 12, amount: 9999, category: 'Kira');

      expect(await budget.applyPlanToYearEnd(11, 2026), 0);
      expect(
        (await budget.calculateMonthlyBudget(12, 2026)).plannedExpense,
        money('9999'),
        reason: 'the existing item is kept, not overwritten',
      );
    });

    test('does not copy templates', () async {
      // They already apply to every month; copying would double them.
      await plan(
        year: 2026,
        month: 10,
        amount: 400,
        category: 'Market',
        template: 1,
      );
      expect(await budget.applyPlanToYearEnd(10, 2026), 0);
    });

    test('an empty source month copies nothing', () async {
      expect(await budget.applyPlanToYearEnd(10, 2026), 0);
    });
  });

  group('saving a plan item', () {
    Future<void> save({
      String itemType = 'expense',
      String name = 'Market',
      Object? amount = 1500.0,
      int month = 8,
      int year = 2026,
      String? category = 'Market',
      int alertThresholdPct = 80,
      bool isTemplate = false,
      int? itemId,
      bool editingATemplate = false,
      Iterable<int> propagateToMonths = const [],
    }) {
      return budget.savePlanItem(
        itemType: itemType,
        name: name,
        amount: amount,
        month: month,
        year: year,
        category: category,
        alertThresholdPct: alertThresholdPct,
        isTemplate: isTemplate,
        itemId: itemId,
        editingATemplate: editingATemplate,
        propagateToMonths: propagateToMonths,
      );
    }

    test(
      'rejects a non-finite or non-positive amount without writing',
      () async {
        for (final amount in [
          double.nan,
          double.infinity,
          double.negativeInfinity,
          0,
          -1.0,
          'abc',
          null,
        ]) {
          await expectLater(
            () => save(amount: amount),
            throwsA(isA<BudgetError>()),
            reason: '$amount',
          );
          expect(await planRows(), isEmpty, reason: '$amount');
        }
      },
    );

    test('rejects invalid metadata without writing', () async {
      final cases = <String, Future<void> Function()>{
        'blank name': () => save(name: '   '),
        'unknown type': () => save(itemType: 'gider'),
        'month 0': () => save(month: 0),
        'month 13': () => save(month: 13),
        'threshold 0': () => save(alertThresholdPct: 0),
        'threshold 101': () => save(alertThresholdPct: 101),
        'invalid copy month': () => save(propagateToMonths: const [13]),
      };
      for (final entry in cases.entries) {
        await expectLater(
          entry.value,
          throwsA(isA<BudgetError>()),
          reason: entry.key,
        );
        expect(await planRows(), isEmpty, reason: entry.key);
      }
    });

    test('stores the amount quantized to the kurus', () async {
      await save(amount: 1500.555);
      expect((await planRows()).single['amount'], 1500.56);
    });

    test('creates, then updates in place', () async {
      await save();
      final itemId = (await planRows()).single['id']! as int;

      await save(itemId: itemId, amount: 2000.0, name: 'Market (zam)');

      final rows = await planRows();
      expect(rows, hasLength(1), reason: 'the update wrote a new row');
      expect(rows.single['id'], itemId);
      expect(rows.single['amount'], 2000.0);
      expect(rows.single['name'], 'Market (zam)');
    });

    test(
      'editing a template leaves it alone and creates a monthly item',
      () async {
        await save(isTemplate: true);
        final templateId = (await planRows()).single['id']! as int;

        await save(itemId: templateId, editingATemplate: true, amount: 900.0);

        final rows = await planRows();
        expect(rows, hasLength(2));
        final template = rows.firstWhere((row) => row['id'] == templateId);
        final created = rows.firstWhere((row) => row['id'] != templateId);
        expect(template['is_template'], 1, reason: 'the template was changed');
        expect(created['is_template'], 0, reason: 'the derived item is a copy');
        expect(created['amount'], 900.0);
      },
    );

    test(
      'a derived item is never a template, even with the switch on',
      () async {
        // Editing one month of a repeating line while the "is template" switch
        // is still on must not mint a SECOND template — the derived item is a
        // one-month override, and two templates for one identity would leave
        // the later one silently winning in every other month.
        await save(isTemplate: true);
        final templateId = (await planRows()).single['id']! as int;

        await save(
          itemId: templateId,
          editingATemplate: true,
          isTemplate: true,
          amount: 900.0,
        );

        final rows = await planRows();
        expect(rows, hasLength(2));
        expect(
          rows.where((row) => row['is_template'] == 1),
          hasLength(1),
          reason: 'the derived item became a second template',
        );
        expect(
          rows.firstWhere((row) => row['id'] != templateId)['is_template'],
          0,
        );
      },
    );

    test('propagated copies are written and are never templates', () async {
      await save(propagateToMonths: const [9, 10, 8]);

      final rows = await planRows();
      expect(rows.map((row) => row['target_month']).toList()..sort(), [
        8,
        9,
        10,
      ], reason: 'the source month must not be copied twice');
      expect(rows.every((row) => row['is_template'] == 0), isTrue);
      expect(rows.every((row) => row['amount'] == 1500.0), isTrue);
      expect(rows.every((row) => row['target_year'] == 2026), isTrue);
    });

    test('a rejected copy list leaves no half-written plan', () async {
      // The copying shares the original write's commit precisely so this
      // cannot happen.
      await expectLater(
        () => save(propagateToMonths: const [9, 99]),
        throwsA(isA<BudgetError>()),
      );
      expect(await planRows(), isEmpty);
    });

    test('a saved item is visible to the budget calculation', () async {
      await save(amount: 1500.0);
      expect(
        (await budget.calculateMonthlyBudget(8, 2026)).plannedExpense,
        money('1500'),
      );
    });

    test('accepts the Turkish type spellings older rows carry', () async {
      await save(itemType: 'Gider', amount: 100);
      await save(itemType: 'Gelir', name: 'Maaş', category: null, amount: 900);

      final result = await budget.calculateMonthlyBudget(8, 2026);
      expect(result.plannedExpense, money('100'));
      expect(result.plannedIncome, money('900'));
    });
  });

  group('the trend series', () {
    test('runs backwards with the end month last', () async {
      await plan(year: 2026, month: 7, amount: 500, category: 'Market');
      await expense('Market', 200, '2026-07-10');
      await plan(year: 2026, month: 8, amount: 600, category: 'Market');
      await expense('Market', 650, '2026-08-10');

      final series = await budget.getBudgetTrend(
        months: 3,
        endDate: DateTime(2026, 8, 20),
      );

      expect(series.map((point) => point.label), [
        '06/2026',
        '07/2026',
        '08/2026',
      ]);
      expect(series[0].planned, Decimal.zero);
      expect(series[1].planned, money('500'));
      expect(series[1].actual, money('200'));
      expect(series[2].planned, money('600'));
      expect(series[2].actual, money('650'));
    });

    test('crosses a year boundary', () async {
      final series = await budget.getBudgetTrend(
        months: 3,
        endDate: DateTime(2026, 1, 15),
      );
      expect(series.map((point) => point.label), [
        '11/2025',
        '12/2025',
        '01/2026',
      ]);
    });
  });

  group('the planner month range', () {
    test('offers this month through December', () {
      expect(plannerMonthRange(DateTime(2026, 1, 15)), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
      ]);
      expect(plannerMonthRange(DateTime(2026, 7, 25)), [7, 8, 9, 10, 11, 12]);
      expect(plannerMonthRange(DateTime(2026, 12, 1)), [12]);
    });
  });

  test('no plan and no subscriptions is an empty budget', () async {
    final result = await budget.calculateMonthlyBudget(8, 2026);
    expect(result.plannedIncome, Decimal.zero);
    expect(result.plannedExpense, Decimal.zero);
    expect(result.remainingBudget, Decimal.zero);
    expect(await count('monthly_budget_plan'), 0);
  });
}
