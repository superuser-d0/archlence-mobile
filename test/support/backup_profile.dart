/// A real profile on disk — a database file and a key file beside it — for
/// the tests that back one up and restore over it.
///
/// The in-memory database the service tests use has no path, and a backup is
/// a SQLite-level copy of a FILE. So these tests get the real thing: drift
/// over a real file, the real [FileKeyProvider], and rows written through the
/// real services so the encrypted columns hold what the app would put there.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:archlence_mobile/backup/backup_service.dart';
import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/crypto/key_provider.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/transaction_service.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

/// A profile directory, its database, and the key that opens it.
class BackupProfile {
  BackupProfile._(this.directory, this.keyProvider);

  /// Creates the directory and its key, but not yet the database.
  static Future<BackupProfile> create({Uint8List? key}) async {
    final directory = await Directory.systemTemp.createTemp('archlence-test-');
    final provider = FileKeyProvider(p.join(directory.path, 'encryption.key'));
    await provider.storeKey(key ?? _arbitraryKey);
    return BackupProfile._(directory, provider);
  }

  static final Uint8List _arbitraryKey = Uint8List.fromList(
    List<int>.generate(32, (index) => 255 - index),
  );

  final Directory directory;
  final FileKeyProvider keyProvider;

  String get databasePath => p.join(directory.path, 'finance.db');

  File get database => File(databasePath);

  String get configPath => p.join(directory.path, 'config.json');

  BackupService service({bool withConfig = false}) => BackupService(
    databasePath: databasePath,
    keyProvider: keyProvider,
    configPath: withConfig ? configPath : null,
  );

  /// Opens the database, runs [work] against real services, and closes it.
  ///
  /// Closing matters: a restore replaces the file, and a connection still
  /// holding the old one would be writing into a file that is no longer the
  /// app's data.
  Future<void> withDatabase(
    Future<void> Function(ArchlenceDatabase db, FieldCrypto crypto) work,
  ) async {
    final db = ArchlenceDatabase(NativeDatabase(database));
    final crypto = FieldCrypto(keyProvider);
    try {
      await work(db, crypto);
    } finally {
      await db.close();
    }
  }

  /// Creates the database and its schema, and stops there.
  ///
  /// A real profile with nothing encrypted in it — the state a fresh install
  /// is in before its first account.
  Future<void> createEmpty() =>
      withDatabase((db, _) async => db.tableNames());

  /// Fills the profile with rows across several encrypted columns.
  ///
  /// Returns how many encrypted fields it produced, so a test can assert the
  /// count a backup records rather than repeat the arithmetic.
  Future<void> seed() async {
    await withDatabase((db, crypto) async {
      final accounts = AccountService(db, crypto);
      final ledger = TransactionService(db, crypto, accounts);
      final id = await accounts.createAccount(
        name: 'Vadesiz',
        accountType: AccountType.checking,
        initialBalance: 1500,
      );
      await ledger.addTransaction(
        accountId: id,
        amount: '1234.56',
        transactionType: 'expense',
        category: 'Market',
        description: 'haftalık alışveriş',
      );
      // A blank description passes through UNENCRYPTED, so a count that
      // included it would disagree with the desktop's.
      await ledger.addTransaction(
        accountId: id,
        amount: '89.90',
        transactionType: 'expense',
        category: 'Ulaşım',
      );
    });
  }

  Future<void> dispose() async {
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }
}
