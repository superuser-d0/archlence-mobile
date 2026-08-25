/// Proves a database created by this app is identical to one created by the
/// desktop app.
///
/// `desktop_schema.sql` is a dump of `sqlite_master` from a database built by
/// the desktop's own `initialize_database()`. If the two ever diverge —
/// a missing column appended by an old ALTER TABLE, a dropped default, a
/// forgotten index — a backup moved between the two apps would fail in ways
/// that look like data loss rather than a schema bug.
library;

import 'dart:io';

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

/// Collapses whitespace so that indentation and line breaks — which SQLite
/// preserves verbatim from the original CREATE — do not count as differences.
String _normalise(String sql) =>
    sql.replaceAll(RegExp(r'\s+'), ' ').replaceAll('( ', '(').trim();

/// `name -> normalised SQL` for every object in a schema dump.
Map<String, String> _objects(Iterable<String> statements) {
  final byName = <String, String>{};
  final pattern = RegExp(
    r'CREATE\s+(?:UNIQUE\s+)?(?:TABLE|INDEX)\s+(?:IF NOT EXISTS\s+)?"?(\w+)"?',
    caseSensitive: false,
  );

  for (final statement in statements) {
    final trimmed = statement.trim();
    if (trimmed.isEmpty) continue;
    final match = pattern.firstMatch(trimmed);
    if (match == null) continue;
    final name = match.group(1)!;
    // Created by SQLite itself for AUTOINCREMENT tables.
    if (name == 'sqlite_sequence') continue;
    byName[name] = _normalise(trimmed);
  }
  return byName;
}

void main() {
  late ArchlenceDatabase db;

  setUp(() async {
    db = ArchlenceDatabase.memory();
    // Force onCreate to run.
    await db.tableNames();
  });

  tearDown(() async => db.close());

  Map<String, String> desktopObjects() {
    final source = File('test/desktop_schema.sql').readAsStringSync();
    return _objects(source.split(';\n'));
  }

  Future<Map<String, String>> dartObjects() async {
    final rows = await db
        .customSelect('SELECT sql FROM sqlite_master WHERE sql IS NOT NULL')
        .get();
    return _objects([for (final row in rows) row.read<String>('sql')]);
  }

  test('creates exactly the desktop app\'s tables and indexes', () async {
    final desktop = desktopObjects();
    final dart = await dartObjects();

    expect(desktop, isNotEmpty, reason: 'the ground-truth dump must parse');
    expect(
      dart.keys.toList()..sort(),
      desktop.keys.toList()..sort(),
      reason: 'the set of objects must match',
    );
  });

  test('every table and index is defined identically', () async {
    final desktop = desktopObjects();
    final dart = await dartObjects();

    for (final name in desktop.keys) {
      expect(dart[name], desktop[name], reason: 'definition of $name');
    }
  });

  test('every encrypted table exists in the schema', () async {
    final tables = await db.tableNames();

    for (final table in encryptedFields.keys) {
      // installment_plans is created lazily by the desktop when the first
      // instalment plan is written, so it is legitimately absent here.
      if (table == 'installment_plans') continue;
      expect(tables, contains(table), reason: '$table carries encrypted data');
    }
  });

  test('every encrypted column exists on its table', () async {
    for (final entry in encryptedFields.entries) {
      if (entry.key == 'installment_plans') continue;

      final rows = await db
          .customSelect('PRAGMA table_info(${entry.key})')
          .get();
      final columns = [for (final row in rows) row.read<String>('name')];

      for (final column in entry.value) {
        expect(
          columns,
          contains(column),
          reason: '${entry.key}.$column is listed as encrypted',
        );
      }
    }
  });

  test('foreign keys are enforced on the connection', () async {
    // SQLite ignores a declared foreign key unless this is switched on, and
    // it is per-connection rather than stored in the file.
    final rows = await db.customSelect('PRAGMA foreign_keys').get();
    expect(rows.single.read<int>('foreign_keys'), 1);
  });

  test(
    'a row inserted here is readable with the desktop column names',
    () async {
      await db.customStatement(
        "INSERT INTO accounts (name, type, account_type, balance) "
        "VALUES ('Nakit Cüzdanım', 'cash', 'checking', 0)",
      );

      final rows = await db
          .customSelect('SELECT name, account_type, balance FROM accounts')
          .get();

      expect(rows.single.read<String>('name'), 'Nakit Cüzdanım');
      expect(rows.single.read<String>('account_type'), 'checking');
    },
  );
}
