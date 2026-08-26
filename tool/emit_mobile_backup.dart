/// Writes a backup package with THIS APP's own code, for the desktop to read.
///
/// The other direction of the same proof as `test/desktop_backup.archlence-backup`:
/// that fixture shows this app reads what the desktop writes, and this shows
/// the desktop reads what this app writes. A format only one side can produce
/// is not a shared format.
///
/// Run it through `flutter test`, which is the only runner that has the
/// package's Flutter dependencies:
///
///     ARCHLENCE_BACKUP_OUT=/tmp/mobile.archlence-backup \
///         flutter test tool/emit_mobile_backup.dart
///
/// then read it back with the desktop's own module, from the desktop checkout:
///
///     ./aeadvenv/bin/python -c "
///     from services.backup_service import verify_backup
///     result = verify_backup('/tmp/mobile.archlence-backup', 'mobile-written-backup')
///     print(result['metadata'])
///     print(result['key'].hex())"
///
/// The key is fixed so the desktop's answer can be checked rather than merely
/// observed not to raise.
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
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String passphrase = 'mobile-written-backup';
final Uint8List key = Uint8List.fromList(
  List<int>.generate(32, (index) => (index * 5 + 1) % 256),
);

void main() {
  test('emit', () async {
    final out = Platform.environment['ARCHLENCE_BACKUP_OUT'];
    if (out == null) {
      fail('Set ARCHLENCE_BACKUP_OUT to where the package should be written.');
    }

    final home = await Directory.systemTemp.createTemp('archlence-emit-');
    final provider = FileKeyProvider(p.join(home.path, 'encryption.key'));
    await provider.storeKey(key);

    final database = File(p.join(home.path, 'finance.db'));
    final db = ArchlenceDatabase(NativeDatabase(database));
    final crypto = FieldCrypto(provider);
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
    await db.close();

    final outcome = await BackupService(
      databasePath: database.path,
      keyProvider: provider,
    ).createBackup(File(out), passphrase);

    // ignore: avoid_print
    print('wrote      ${outcome.path}');
    // ignore: avoid_print
    print('passphrase $passphrase');
    // ignore: avoid_print
    print('key        ${key.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
    // ignore: avoid_print
    print('aead rows  ${outcome.aeadRecordsVerified}');

    await home.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
