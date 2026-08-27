/// The `categories` table: reading the list, and the one thing that writes it.
///
/// **There is no create, rename or delete here, and that is deliberate.** The
/// desktop has none either — `database/init_db.py` seeds the list and the only
/// write anywhere in that codebase is `main.py`'s
/// `UPDATE categories SET importance = ? WHERE name = ?`. Adding more on this
/// side would fork a schema that is a contract shared with the desktop, and it
/// would do it in the worst place: `transactions.category` stores the category
/// NAME as text, so a rename here would split a household's history in two —
/// the rows written before it under the old name, the rows after under the
/// new, and neither app able to tell they were ever the same thing.
///
/// So this file is a list and a switch. What the switch means is in
/// `financial_summary.dart`.
library;

import 'package:drift/drift.dart';

import '../data/database.dart';

/// One row of `categories`, as the settings screen reads it.
class Category {
  const Category({
    required this.name,
    required this.type,
    required this.importance,
  });

  final String name;

  /// 'income' or 'expense' — which side of the ledger this category files
  /// under. Not a transaction type: the table stores the side, while a
  /// TRANSACTION may spell its type in either language (see
  /// `incomeTransactionTypes` in `transaction_service.dart`).
  final String type;

  /// 'main' or 'extra'. See [Category.isMain] before comparing this by hand.
  final String importance;

  bool get isIncome => type == 'income';

  /// True when the household treats this as one it must have.
  ///
  /// Read through here rather than comparing the string at the call site: the
  /// bucket a 'main' expense lands in is named 'essential', and code that
  /// tested for that word would compile and be wrong.
  bool get isMain => importance == mainImportance;
}

/// The value of `importance` that means "the household must".
///
/// Declared here, beside the table it belongs to, and imported by
/// `financial_summary.dart` rather than spelled twice. Two copies of a magic
/// string are two chances to change one of them.
const String mainImportance = 'main';

/// The other value. A category with neither — a null, from a row the seed did
/// not write — reads as this one.
const String extraImportance = 'extra';

class CategoryService {
  CategoryService(this._db);

  final ArchlenceDatabase _db;

  /// Every category, income first, then in the order the seed wrote them.
  ///
  /// `ORDER BY id` inside each side, not by name: the seed's order is the
  /// desktop's order, which puts the ones a household actually uses near the
  /// top. Sorting alphabetically would bury 'Maaş' in the middle of the list.
  Future<List<Category>> getCategories() async {
    final rows = await _db
        .customSelect(
          'SELECT name, type, importance FROM categories '
          "ORDER BY CASE type WHEN 'income' THEN 0 ELSE 1 END, id",
        )
        .get();
    return [
      for (final row in rows)
        Category(
          name: row.read<String>('name'),
          type: row.data['type'] as String? ?? 'expense',
          importance: row.data['importance'] as String? ?? extraImportance,
        ),
    ];
  }

  /// Marks [name] as one the household must have, or one it chooses.
  ///
  /// Matched by NAME, not by id, because that is what the desktop does and
  /// because the name is what `transactions.category` holds. A name with no
  /// row updates nothing and reports so rather than throwing: the list this is
  /// driven from comes from the table, so a miss means the row went away
  /// underneath — a restore, most likely — and the screen reloading is the
  /// right answer, not a crash.
  Future<bool> setImportance(String name, {required bool isMain}) async {
    final updated = await _db.customUpdate(
      'UPDATE categories SET importance = ? WHERE name = ?',
      variables: [
        Variable<String>(isMain ? mainImportance : extraImportance),
        Variable<String>(name),
      ],
      updates: const {},
    );
    return updated > 0;
  }
}
