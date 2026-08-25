/// Connection and schema management for the Archlence database.
///
/// The schema is applied verbatim from [desktopSchemaStatements] rather than
/// declared as drift tables, so that a file created here is
/// indistinguishable from one the desktop created. Data access is written as
/// SQL for the same reason: the tables are an existing external contract, not
/// something this app gets to define.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'default_categories.dart';
import 'schema.dart';

part 'database.g.dart';

/// Where this app keeps everything it owns: the database and the key file
/// alongside it.
///
/// One function rather than a `getApplicationDocumentsDirectory()` call at
/// each site — the two must not be able to drift apart, since a key beside
/// the wrong database opens nothing.
Future<String> applicationDataDirectory() async =>
    (await getApplicationDocumentsDirectory()).path;

/// Formats [when] the way every date and timestamp column in this database is
/// written: `YYYY-MM-DD HH:MM:SS` in local time.
///
/// The desktop produces these with
/// `datetime.now().strftime("%Y-%m-%d %H:%M:%S")`, and its queries compare
/// and sort the column as text. An ISO-8601 string from `DateTime.toString()`
/// would carry sub-second digits and sort differently against the rows
/// already there, so the format is fixed here rather than left to each caller.
String sqliteTimestamp(DateTime when) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${when.year.toString().padLeft(4, '0')}-${two(when.month)}-'
      '${two(when.day)} ${two(when.hour)}:${two(when.minute)}:'
      '${two(when.second)}';
}

/// Formats [when] as the bare `YYYY-MM-DD` that date-only columns hold —
/// `recurring_payments.next_due_date` and the like, which the desktop
/// compares with SQLite's `date()`.
String sqliteDate(DateTime when) => sqliteTimestamp(when).substring(0, 10);

/// Matches `PRAGMA user_version` on the desktop, which tracks its own
/// migrations. Kept at the value the current schema corresponds to so that a
/// database opened by either app agrees about how far it has been migrated.
const int schemaVersion = 1;

@DriftDatabase(tables: [])
class ArchlenceDatabase extends _$ArchlenceDatabase {
  ArchlenceDatabase(super.executor);

  /// Opens the app's own database file under the platform data directory.
  static Future<ArchlenceDatabase> open() async {
    return ArchlenceDatabase(
      NativeDatabase.createInBackground(
        File(p.join(await applicationDataDirectory(), 'finance.db')),
      ),
    );
  }

  /// An in-memory database, for tests.
  static ArchlenceDatabase memory() =>
      ArchlenceDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final statement in desktopSchemaStatements) {
        await customStatement(statement);
      }
      // The schema dump carries no rows, but the desktop SEEDS its category
      // list on first run, and those names are matched as literals by the
      // budget, the distribution chart and the subscription radar. A database
      // created here without them would agree on shape and disagree on
      // content.
      for (final (name, type, importance) in defaultCategories) {
        await customInsert(
          'INSERT INTO categories (name, type, importance) VALUES (?, ?, ?)',
          variables: [
            Variable<String>(name),
            Variable<String>(type),
            Variable<String>(importance),
          ],
        );
      }
    },
    beforeOpen: (details) async {
      // The desktop declares transactions.account_id as a foreign key;
      // SQLite ignores it unless enforcement is switched on per
      // connection, so a delete could otherwise orphan rows here that
      // the desktop would have refused.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Every table name currently present, excluding SQLite's own bookkeeping.
  Future<List<String>> tableNames() async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    ).get();
    return [for (final row in rows) row.read<String>('name')];
  }
}
