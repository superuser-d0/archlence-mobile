/// Writing a backup, proving one, and restoring from one without ever
/// leaving the profile half-replaced.
///
/// A port of `services/backup_service.py`. Three properties carry over
/// unchanged, and each is here because losing it loses data:
///
///  * **A package is verified before it is published.** The copy is hashed,
///    integrity-checked and opened with the key that travels in it BEFORE the
///    file appears where the user can see it. A backup that cannot be
///    restored is worse than no backup, because it is believed.
///  * **A package is untrusted input.** See `backup_package.dart` for the
///    bounds; nothing here is reached until they pass.
///  * **A restore is journalled and can be rolled back.** A half-restored
///    database is worse than no restore at all, so every step writes down
///    where it got to and every failure walks back out.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../crypto/aead_crypto.dart' as aead;
import '../crypto/field_crypto.dart' show aeadPrefix, encryptedFields;
import '../crypto/key_provider.dart';
import 'backup_errors.dart';
import 'backup_package.dart';
import 'recovery_material.dart';

/// What a finished backup reports about itself.
class BackupOutcome {
  const BackupOutcome({
    required this.path,
    required this.aeadRecordsVerified,
    required this.databaseSha256,
  });

  final String path;

  /// How many encrypted fields were opened with the key before the package
  /// was published. Zero is legitimate on an empty profile and is reported
  /// rather than hidden, because "verified nothing" and "verified 900 rows"
  /// are not the same reassurance.
  final int aeadRecordsVerified;

  final String databaseSha256;
}

/// A package that has been staged and proven.
class VerifiedBackup {
  const VerifiedBackup({
    required this.key,
    required this.metadata,
    required this.config,
  });

  /// The encryption key the package carries, already checked against the
  /// data it travels with.
  final Uint8List key;

  final Map<String, Object?> metadata;

  /// `config.json`, when the package carried one.
  final Uint8List? config;
}

/// What a restore did.
class RestoreOutcome {
  const RestoreOutcome({required this.safetyBackupPath});

  /// Where the pre-restore backup of the previous data was written, or null
  /// when there was nothing to save.
  final String? safetyBackupPath;
}

/// What was found, and undone, at startup.
enum RecoveryAction {
  /// No interrupted restore: the normal case.
  none,

  /// The restore had committed; only its bookkeeping was left behind.
  cleanedUp,

  /// The restore was interrupted partway and the previous data was put back.
  rolledBack,
}

const String _journalDirName = '.archlence-restore';
const String _journalName = 'journal.json';

/// The states a restore passes through, in this order:
///
///     STAGED -> ROLLBACK_GENERATION_READY -> DB_REPLACED -> CONFIG_REPLACED
///     -> VERIFIED -> KEY_REPLACING -> KEY_REPLACED -> COMMITTED
///
/// **The key is swapped LAST, and that is the whole design.** The desktop
/// swaps it in the middle, and its recovery has no way to put the old one
/// back — the journal never records it. So a desktop restore killed after the
/// key step and rolled back at the next start brings the OLD database back
/// under the NEW key, which opens nothing. On a phone, where the OS kills
/// apps as a matter of routine, that is not a corner case.
///
/// Moving the swap to the end makes every earlier state unambiguous: the old
/// key is still in the store, so rolling the database back restores a
/// generation that still opens. Writing the old key to disk for the duration
/// would have worked too, and was rejected: on a device with a Keystore the
/// key's whole value is that it is NOT a file.
const List<String> _rollbackStates = [
  'STAGED',
  'ROLLBACK_GENERATION_READY',
  'DB_REPLACED',
  'CONFIG_REPLACED',
  'VERIFIED',
];

/// The one state that cannot be decided from its name.
///
/// The process died somewhere inside the key store's own write, so the store
/// holds either the previous key or the incoming one and the journal cannot
/// know which. It is resolved by EVIDENCE rather than assumption: the journal
/// records the fingerprint of both keys, and whichever one the store actually
/// holds says which side of the swap the process died on.
const String _keyReplacingState = 'KEY_REPLACING';

/// Past the point of no return: the new database has been verified and the
/// key that opens it is in the store.
const List<String> _committedStates = ['KEY_REPLACED', 'COMMITTED'];

/// The files SQLite keeps beside a database.
///
/// They belong to the GENERATION, not to the file name. A rollback journal
/// left over from a process that was killed describes the OLD database; if it
/// is still lying there when a restored database takes that name, SQLite will
/// open the new file and replay the old file's journal into it. So they move
/// with the database they belong to and come back with it.
///
/// The desktop does not do this, and does not need to as sharply: a phone
/// kills its apps as a matter of routine.
const List<String> _sqliteSidecars = ['-journal', '-wal', '-shm'];

class BackupService {
  BackupService({
    required this.databasePath,
    required this.keyProvider,
    this.configPath,
    Random? random,
  }) : _random = random ?? Random.secure();

  /// The live database this app reads and writes.
  final String databasePath;

  final KeyProvider keyProvider;

  /// An optional settings file that travels with the data. Null when the app
  /// keeps none.
  final String? configPath;

  final Random _random;

  File get _database => File(databasePath);

  Directory get _dataDirectory => _database.parent;

  Directory get _journalDirectory =>
      Directory(p.join(_dataDirectory.path, _journalDirName));

  // ---------------------------------------------------------------- create

  /// Writes a verified package to [destination].
  ///
  /// The package is proven by reading it back before this returns. The order
  /// matters: the file is renamed into place first so the verification runs
  /// against the bytes that actually landed, not against the temporary copy
  /// they were built from.
  Future<BackupOutcome> createBackup(File destination, String passphrase) async {
    requirePassphrase(passphrase);
    if (!await _database.exists()) {
      throw const BackupFormatError('There is no database to back up.');
    }
    final key = await keyProvider.loadKey();
    if (key == null) {
      throw const KeyUnavailableError(
        'There is no encryption key to back up; nothing was written.',
      );
    }
    final recovery = await encryptRecoveryMaterial(key, passphrase);

    await destination.parent.create(recursive: true);
    final temp = await destination.parent.createTemp('archlence-backup-');
    final String digest;
    final int aeadChecked;
    try {
      final copy = File(p.join(temp.path, databaseMember));
      await _sqliteCopy(_database, copy);
      _integrityCheck(copy);
      aeadChecked = await verifyDatabaseKey(copy, key);
      digest = await sha256File(copy);

      final metadata = <String, Object?>{
        'format_version': backupFormatVersion,
        'created_at': _utcNow(),
        'database_sha256': digest,
        'key_fingerprint': await sha256Hex(key),
        'aead_records_verified': aeadChecked,
        'authentication_salt': base64.encode(_randomBytes(16)),
      };
      metadata['authentication_tag'] = await backupAuthTag(
        metadata,
        passphrase,
      );

      const encoder = JsonEncoder.withIndent('  ');
      File(
        p.join(temp.path, metadataMember),
      ).writeAsStringSync(encoder.convert(metadata));
      File(
        p.join(temp.path, recoveryMember),
      ).writeAsStringSync(encoder.convert(recovery.toJson()));

      final members = [...requiredMembers];
      final config = configPath == null ? null : File(configPath!);
      if (config != null && config.existsSync()) {
        config.copySync(p.join(temp.path, configMember));
        members.add(configMember);
      }

      final staged = File(p.join(temp.path, 'backup.zip'));
      await writePackage(temp, members, staged);
      await staged.rename(destination.path);
    } finally {
      await temp.delete(recursive: true);
    }

    await verifyBackup(destination, passphrase);
    return BackupOutcome(
      path: destination.path,
      aeadRecordsVerified: aeadChecked,
      databaseSha256: digest,
    );
  }

  // ---------------------------------------------------------------- verify

  /// Stages a package under the bounds and proves it opens.
  Future<VerifiedBackup> verifyBackup(File package, String passphrase) async {
    requirePassphrase(passphrase);
    final temp = await Directory.systemTemp.createTemp('archlence-verify-');
    try {
      await stagePackage(package, temp);
      return await _verifyStaged(temp, passphrase);
    } finally {
      await temp.delete(recursive: true);
    }
  }

  /// Everything a staged package has to prove before any of it is believed.
  Future<VerifiedBackup> _verifyStaged(
    Directory temp,
    String passphrase,
  ) async {
    final metadata = readJsonObject(
      File(p.join(temp.path, metadataMember)),
      'metadata',
    );
    final recoveryJson = readJsonObject(
      File(p.join(temp.path, recoveryMember)),
      'recovery material',
    );

    if (metadata['format_version'] != backupFormatVersion) {
      throw const BackupFormatError(
        'The backup was written in a format this app does not read.',
      );
    }
    if (metadata['authentication_salt'] is! String) {
      throw const BackupFormatError('The backup metadata is corrupt.');
    }
    final expectedDigest = requireHexDigest(
      metadata['database_sha256'],
      'database hash',
    );
    final expectedFingerprint = requireHexDigest(
      metadata['key_fingerprint'],
      'key fingerprint',
    );
    final expectedRecords = requireRecordCount(
      metadata['aead_records_verified'],
    );

    // The metadata is authenticated BEFORE any field of it is used for
    // anything, because everything below reads it.
    final supplied = metadata['authentication_tag'];
    if (supplied is! String ||
        !_constantTimeEquals(supplied, await backupAuthTag(metadata, passphrase))) {
      // Two very different things fail here, and the user needs to be told
      // which. The tag is derived from the passphrase, so a mismatch is most
      // often a mistyped passphrase — but it is also exactly what a tampered
      // metadata file looks like. Rather than guess, ask the OTHER thing the
      // passphrase opens: the recovery material carries its own AES-GCM tag
      // and its round count is already bounded. If the passphrase opens that,
      // the passphrase is right and the metadata was altered.
      //
      // The extra derivation costs seconds, and only on a path that has
      // already failed.
      await _unwrapOrReportWrongPassphrase(recoveryJson, passphrase);
      throw const BackupFormatError(
        'The backup metadata does not match its signature; the file has been '
        'altered since it was written.',
      );
    }

    final database = File(p.join(temp.path, databaseMember));
    if (await sha256File(database) != expectedDigest) {
      throw const BackupFormatError(
        'The database in the backup does not match the hash recorded for it.',
      );
    }

    final key = await _unwrapOrReportWrongPassphrase(recoveryJson, passphrase);
    if (await sha256Hex(key) != expectedFingerprint) {
      throw const BackupFormatError(
        'The key in the backup is not the key its metadata names.',
      );
    }

    _integrityCheck(database);
    final checked = await verifyDatabaseKey(database, key);
    if (checked != expectedRecords) {
      throw const BackupFormatError(
        'The backup holds a different number of encrypted records than its '
        'metadata claims.',
      );
    }

    final config = File(p.join(temp.path, configMember));
    return VerifiedBackup(
      key: key,
      metadata: metadata,
      config: config.existsSync() ? config.readAsBytesSync() : null,
    );
  }

  Future<Uint8List> _unwrapOrReportWrongPassphrase(
    Map<String, Object?> recoveryJson,
    String passphrase,
  ) async {
    return decryptRecoveryMaterial(
      RecoveryMaterial.fromJson(recoveryJson),
      passphrase,
    );
  }

  // --------------------------------------------------------------- restore

  /// Replaces this app's database and key with the ones in [package].
  ///
  /// **The database must be closed before this is called.** It replaces the
  /// file, and a connection still holding the old one would go on writing to
  /// a file that is no longer the app's data.
  ///
  /// On any failure the previous database, key and settings are put back and
  /// [RestoreFailedError] is thrown. The state is written down at every step,
  /// so a restore killed by the OS partway through is undone at the next
  /// start rather than left mixed.
  Future<RestoreOutcome> restoreBackup(
    File package,
    String passphrase, {
    File? safetyBackup,
    void Function(String point)? failurePoint,
  }) async {
    requirePassphrase(passphrase);
    await _dataDirectory.create(recursive: true);
    final config = configPath == null ? null : File(configPath!);
    final currentKey = await keyProvider.loadKey();

    final stamp = _fileStamp(DateTime.now());
    final safety =
        safetyBackup ??
        File(p.join(_dataDirectory.path, 'pre-restore-$stamp.archlence-backup'));

    final temp = await _dataDirectory.createTemp('archlence-restore-');
    try {
      await stagePackage(package, temp);
      final verification = await _verifyStaged(temp, passphrase);

      // The insurance, taken before anything is touched. Without a key or a
      // database there is nothing to insure, and nothing to lose.
      final databaseExisted = await _database.exists();
      final tookSafetyBackup = databaseExisted && currentKey != null;
      if (tookSafetyBackup) {
        await createBackup(safety, passphrase);
      }

      final journal = _journalDirectory;
      final oldDatabase = File(p.join(journal.path, 'old-finance.db'));
      final oldConfig = File(p.join(journal.path, 'old-config.json'));
      final stagedDatabase = File(p.join(temp.path, databaseMember));

      final hadConfig = config != null && config.existsSync();
      final ledger = _Ledger(
        hadConfig: hadConfig,
        previousKeyFingerprint:
            currentKey == null ? null : await sha256Hex(currentKey),
        incomingKeyFingerprint: await sha256Hex(verification.key),
      );
      try {
        await journal.create(recursive: true);
        if (hadConfig) config.copySync(oldConfig.path);
        _writeJournal(journal, 'STAGED', ledger);

        if (databaseExisted) {
          await _database.rename(oldDatabase.path);
        }
        _moveSidecars(_database, journal, aside: true);
        _writeJournal(journal, 'ROLLBACK_GENERATION_READY', ledger);
        failurePoint?.call('after_old_files_staged');

        await stagedDatabase.rename(databasePath);
        _writeJournal(journal, 'DB_REPLACED', ledger);
        failurePoint?.call('after_database_replaced');

        if (config != null && verification.config != null) {
          await config.parent.create(recursive: true);
          config.writeAsBytesSync(verification.config!);
        }
        _writeJournal(journal, 'CONFIG_REPLACED', ledger);
        failurePoint?.call('after_config_replaced');

        // Verified with the key HELD IN MEMORY, before it is anywhere near
        // the key store. Everything the restore can get wrong is caught here,
        // while the store still holds the old key and a rollback still has a
        // generation that opens.
        _integrityCheck(_database);
        await verifyDatabaseKey(_database, verification.key);
        _writeJournal(journal, 'VERIFIED', ledger);
        failurePoint?.call('after_post_verification');

        // The last mutation, and the only one that is not reversible from
        // the journal alone. It is announced before it happens.
        _writeJournal(journal, _keyReplacingState, ledger);
        failurePoint?.call('before_key_replaced');
        if (currentKey == null) {
          await keyProvider.storeKey(verification.key);
        } else {
          await keyProvider.replaceKey(
            verification.key,
            expectedCurrent: currentKey,
          );
        }
        _writeJournal(journal, 'KEY_REPLACED', ledger);
        failurePoint?.call('after_key_replaced');
      } on Object catch (error) {
        await _rollBack(
          oldDatabase: oldDatabase,
          oldConfig: oldConfig,
          config: config,
          hadConfig: hadConfig,
          currentKey: currentKey,
        );
        throw RestoreFailedError(
          'The restore failed and your previous data was put back.',
          error,
        );
      }

      _writeJournal(journal, 'COMMITTED', ledger);
      failurePoint?.call('after_committed_marker');
      _discardJournal(journal);

      return RestoreOutcome(
        safetyBackupPath: tookSafetyBackup ? safety.path : null,
      );
    } finally {
      if (temp.existsSync()) await temp.delete(recursive: true);
    }
  }

  /// Puts the previous generation back, in the reverse order it was taken.
  Future<void> _rollBack({
    required File oldDatabase,
    required File oldConfig,
    required File? config,
    required bool hadConfig,
    required List<int>? currentKey,
  }) async {
    final journal = _journalDirectory;
    if (_database.existsSync()) _database.deleteSync();
    _moveSidecars(_database, journal, aside: false);
    if (oldDatabase.existsSync()) {
      await oldDatabase.rename(databasePath);
    }

    // The key first: whatever is in the store now may be the incoming one.
    final installed = await keyProvider.loadKey();
    if (currentKey != null &&
        installed != null &&
        !_sameBytes(installed, currentKey)) {
      await keyProvider.replaceKey(currentKey, expectedCurrent: installed);
    } else if (currentKey == null && installed != null) {
      await keyProvider.deleteKey(expectedCurrent: installed);
    }

    // If there was NO config before the restore, the one the restore wrote
    // has to be DELETED. Putting an old copy back would be inventing a file.
    if (config != null) {
      if (hadConfig && oldConfig.existsSync()) {
        await oldConfig.rename(config.path);
      } else if (!hadConfig && config.existsSync()) {
        config.deleteSync();
      }
    }
    _discardJournal(journal);
  }

  /// Undoes a restore that the OS killed partway through.
  ///
  /// Called at startup, BEFORE the database is opened. Does nothing when
  /// there is no journal, which is every ordinary start.
  ///
  /// FAIL-CLOSED: a journal that cannot be read, or that names a state this
  /// build does not know, is not shrugged off. Opening a profile that may be
  /// half of one generation and half of another, on the assumption that
  /// everything is fine, is worse than refusing to start.
  Future<RecoveryAction> recoverInterruptedRestore() async {
    final journal = _journalDirectory;
    final file = File(p.join(journal.path, _journalName));
    if (!file.existsSync()) return RecoveryAction.none;

    final Map<String, Object?> payload;
    final String state;
    try {
      final parsed = jsonDecode(file.readAsStringSync());
      payload = parsed as Map<String, Object?>;
      state = payload['state']! as String;
    } on Object catch (error) {
      throw InterruptedRestoreError(
        'An interrupted restore was found and its record could not be read. '
        'The data has been left exactly as it is. ($error)',
      );
    }

    final resolved = state == _keyReplacingState
        ? await _resolveKeyReplacing(payload)
        : state;
    if (!_rollbackStates.contains(resolved) &&
        !_committedStates.contains(resolved)) {
      throw InterruptedRestoreError(
        'An interrupted restore was found in a state this version does not '
        'know how to undo ($state). The data has been left exactly as it is.',
      );
    }

    final config = configPath == null ? null : File(configPath!);
    final hadConfig = payload['had_config'] == true;
    final oldDatabase = File(p.join(journal.path, 'old-finance.db'));
    final oldConfig = File(p.join(journal.path, 'old-config.json'));

    if (_committedStates.contains(resolved)) {
      // The restore got far enough that the new database was verified and the
      // key that opens it is in the store; only the bookkeeping was left
      // behind. The one thing worth checking is that the database is there.
      if (!_database.existsSync()) {
        throw const InterruptedRestoreError(
          'A restore recorded itself as finished, but the database it wrote '
          'is missing. The data has been left exactly as it is.',
        );
      }
      _discardJournal(journal);
      return RecoveryAction.cleanedUp;
    }

    if (_database.existsSync()) _database.deleteSync();
    _moveSidecars(_database, journal, aside: false);
    if (oldDatabase.existsSync()) {
      await oldDatabase.rename(databasePath);
    }
    if (config != null) {
      if (hadConfig && oldConfig.existsSync()) {
        await oldConfig.rename(config.path);
      } else if (!hadConfig && config.existsSync()) {
        config.deleteSync();
      }
    }
    _discardJournal(journal);
    return RecoveryAction.rolledBack;
  }

  /// Decides which side of the key swap the process died on.
  ///
  /// The only evidence is the key store itself, and the journal wrote down
  /// what both possible answers look like before the swap began. Whichever
  /// fingerprint the store matches says whether the swap happened.
  ///
  /// A store that matches NEITHER is not guessed at. It means the key changed
  /// underneath the restore — another process, a wiped Keystore, a restored
  /// device backup — and either choice here could destroy the wrong
  /// generation.
  Future<String> _resolveKeyReplacing(Map<String, Object?> payload) async {
    final previous = payload['previous_key_fingerprint'];
    final incoming = payload['incoming_key_fingerprint'];
    if (incoming is! String || (previous != null && previous is! String)) {
      throw const InterruptedRestoreError(
        'An interrupted restore was found without the fingerprints needed to '
        'undo it safely. The data has been left exactly as it is.',
      );
    }

    final Uint8List? stored;
    try {
      stored = await keyProvider.loadKey();
    } on KeyUnavailableError catch (error) {
      throw InterruptedRestoreError(
        'An interrupted restore was found and the key store could not be '
        'read to finish undoing it. The data has been left exactly as it is. '
        '(${error.message})',
      );
    }

    final fingerprint = stored == null ? null : await sha256Hex(stored);
    if (fingerprint == incoming) return 'KEY_REPLACED';
    if (fingerprint == previous) return 'VERIFIED';
    throw const InterruptedRestoreError(
      'An interrupted restore was found, and the encryption key is now '
      'neither the one it started with nor the one it was installing. The '
      'data has been left exactly as it is.',
    );
  }

  // ------------------------------------------------------------ the ledger

  /// Writes the journal ATOMICALLY: a temporary file, then a rename.
  ///
  /// Writing in place would leave a half-written journal if the process died
  /// on this exact line, and recovery would have nothing it could trust.
  void _writeJournal(Directory journal, String state, _Ledger ledger) {
    final payload = <String, Object?>{
      'state': state,
      'db_path': databasePath,
      'config_path': configPath,
      'had_config': ledger.hadConfig,
      // Fingerprints, not keys. They are what lets recovery decide which side
      // of the key swap the process died on without either app ever writing a
      // key to disk. A SHA-256 of a 32-byte random key tells an attacker
      // nothing they could not already compute.
      'previous_key_fingerprint': ledger.previousKeyFingerprint,
      'incoming_key_fingerprint': ledger.incomingKeyFingerprint,
    };
    final target = File(p.join(journal.path, _journalName));
    final staged = File('${target.path}.writing');
    final handle = staged.openSync(mode: FileMode.writeOnly);
    try {
      handle.writeStringSync(jsonEncode(payload));
      handle.flushSync();
    } finally {
      handle.closeSync();
    }
    staged.renameSync(target.path);
  }

  void _discardJournal(Directory journal) {
    if (journal.existsSync()) journal.deleteSync(recursive: true);
  }

  /// Moves SQLite's sidecar files out of the way, or brings them back.
  void _moveSidecars(File database, Directory journal, {required bool aside}) {
    for (final suffix in _sqliteSidecars) {
      final live = File('${database.path}$suffix');
      final parked = File(p.join(journal.path, 'old-finance.db$suffix'));
      if (aside) {
        if (live.existsSync()) live.renameSync(parked.path);
      } else {
        if (live.existsSync()) live.deleteSync();
        if (parked.existsSync()) parked.renameSync(live.path);
      }
    }
  }

  // -------------------------------------------------------------- the data

  /// Opens every AEAD field in [database] with [key], and counts them.
  ///
  /// This is what makes a package trustworthy: the key that travels in it is
  /// proven against the data it travels with, rather than assumed to match
  /// because it came out of the same file.
  ///
  /// Values without the `AEADv1:` prefix are skipped, exactly as the desktop
  /// skips them: those are the legacy AES-CBC rows its own migration handles,
  /// and failing on them here would refuse to back up a profile the desktop
  /// can still read.
  Future<int> verifyDatabaseKey(File database, List<int> key) async {
    final connection = _open(database, readOnly: true);
    final work = <(String table, int id, String field, String token)>[];
    try {
      final tables = {
        for (final row in connection.select(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        ))
          row['name'] as String,
      };
      for (final entry in encryptedFields.entries) {
        if (!tables.contains(entry.key)) continue;
        final columns = {
          for (final row in connection.select(
            'PRAGMA table_info(${entry.key})',
          ))
            row['name'] as String,
        };
        final usable = entry.value.where(columns.contains).toList();
        if (usable.isEmpty) continue;
        final selected = ['id', ...usable].join(', ');
        for (final row in connection.select(
          'SELECT $selected FROM ${entry.key}',
        )) {
          for (final field in usable) {
            final value = row[field];
            if (value == null || value.toString().trim().isEmpty) continue;
            final text = value.toString();
            if (!text.startsWith(aeadPrefix)) continue;
            work.add((entry.key, row['id'] as int, field, text));
          }
        }
      }
    } finally {
      connection.close();
    }

    for (final (table, id, field, token) in work) {
      try {
        await aead.decrypt(token.substring(aeadPrefix.length), key);
      } on Object {
        throw BackupFormatError(
          'The key in the backup does not open $table id=$id ($field).',
        );
      }
    }
    return work.length;
  }

  /// A SQLite-level copy, not a file copy.
  ///
  /// The online backup API takes a consistent snapshot under SQLite's own
  /// locking. Copying the file's bytes would catch a write in progress and
  /// produce a database that passes as a file and fails as a database.
  Future<void> _sqliteCopy(File source, File destination) async {
    final from = _open(source, readOnly: true);
    Database? to;
    try {
      to = sqlite3.open(destination.path);
      // A single step copies every page at once. The default of five pages a
      // step sleeps 250 ms between steps, which turns a few megabytes into
      // minutes.
      await from.backup(to, nPage: -1).drain<void>();
    } on SqliteException catch (error) {
      throw BackupFormatError('The database could not be copied. ($error)');
    } finally {
      to?.close();
      from.close();
    }
  }

  /// SQLite's own opinion of the file, plus its foreign keys.
  void _integrityCheck(File database) {
    final connection = _open(database, readOnly: true);
    try {
      final result = connection.select('PRAGMA integrity_check');
      final verdict = result.isEmpty
          ? 'empty'
          : result.first.values.first.toString();
      if (verdict != 'ok') {
        throw const BackupFormatError(
          'The database in the backup did not pass SQLite\'s integrity check.',
        );
      }
      final violations = connection.select('PRAGMA foreign_key_check');
      if (violations.isNotEmpty) {
        final first = violations.first;
        throw BackupFormatError(
          'The database in the backup breaks a foreign key '
          '(first: ${first.values.take(3).join(' -> ')}).',
        );
      }
    } finally {
      connection.close();
    }
  }

  Database _open(File database, {required bool readOnly}) {
    try {
      return sqlite3.open(
        database.path,
        mode: readOnly ? OpenMode.readOnly : OpenMode.readWrite,
      );
    } on SqliteException catch (error) {
      throw BackupFormatError('The database could not be opened. ($error)');
    }
  }

  Uint8List _randomBytes(int length) => Uint8List.fromList(
    List<int>.generate(length, (_) => _random.nextInt(256)),
  );
}

/// What every journal entry of one restore carries, so the fields cannot be
/// passed inconsistently from one call to the next.
class _Ledger {
  const _Ledger({
    required this.hadConfig,
    required this.previousKeyFingerprint,
    required this.incomingKeyFingerprint,
  });

  /// Whether a settings file existed BEFORE the restore. The distinction is
  /// load-bearing: if there was none, the one the restore wrote has to be
  /// deleted on the way back, not replaced with an older copy.
  final bool hadConfig;

  /// Null when there was no key at all — a fresh install.
  final String? previousKeyFingerprint;

  final String incomingKeyFingerprint;
}

/// `datetime.now(timezone.utc).isoformat()`, which writes the offset out in
/// full rather than as `Z`.
String _utcNow() {
  final iso = DateTime.now().toUtc().toIso8601String();
  return iso.endsWith('Z')
      ? '${iso.substring(0, iso.length - 1)}+00:00'
      : iso;
}

/// `YYYYMMDD-HHMMSS`, for a file name that sorts.
String _fileStamp(DateTime when) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${when.year}${two(when.month)}${two(when.day)}-'
      '${two(when.hour)}${two(when.minute)}${two(when.second)}';
}

/// Compares two hex strings without letting the time taken say how much of
/// them matched.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return difference == 0;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
