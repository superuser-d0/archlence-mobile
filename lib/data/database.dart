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

import 'schema.dart';

part 'database.g.dart';

/// Matches `PRAGMA user_version` on the desktop, which tracks its own
/// migrations. Kept at the value the current schema corresponds to so that a
/// database opened by either app agrees about how far it has been migrated.
const int schemaVersion = 1;

@DriftDatabase(tables: [])
class ArchlenceDatabase extends _$ArchlenceDatabase {
  ArchlenceDatabase(super.executor);

  /// Opens the app's own database file under the platform data directory.
  static Future<ArchlenceDatabase> open() async {
    final directory = await getApplicationDocumentsDirectory();
    return ArchlenceDatabase(
      NativeDatabase.createInBackground(
        File(p.join(directory.path, 'finance.db')),
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
