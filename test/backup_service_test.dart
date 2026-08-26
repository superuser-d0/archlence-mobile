/// Backup and restore, end to end.
///
/// Two things are proven here that no unit test of the pieces could:
///
///  * **The port reads what the desktop actually writes.**
///    `test/desktop_backup.archlence-backup` was produced by running
///    `services/backup_service.py`'s own `create_backup`, and the key it
///    carries is a known one — so the assertion is that this app recovers
///    THAT key, not merely that something 32 bytes long came out.
///  * **A restore that fails leaves the profile exactly as it was.** Every
///    step of the restore is driven into failure in turn, and the previous
///    database, key and settings are required back each time.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archlence_mobile/backup/backup_errors.dart';
import 'package:archlence_mobile/backup/backup_package.dart';
import 'package:archlence_mobile/backup/backup_service.dart';
import 'package:archlence_mobile/backup/recovery_material.dart';
import 'package:archlence_mobile/crypto/key_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/backup_profile.dart';

/// The fixture the desktop wrote, and what it was written with.
///
/// Both are fixed by `tool/emit_backup_package.py`; changing either there
/// means regenerating the file.
const String desktopPackagePath = 'test/desktop_backup.archlence-backup';
const String desktopPassphrase = 'desktop-written-backup';
final Uint8List desktopKey = Uint8List.fromList(
  List<int>.generate(32, (index) => index),
);

/// PBKDF2 at 600 000 rounds costs a second or two per derivation, and a
/// restore performs several. The default 30 seconds is not a real budget.
const Timeout _slow = Timeout(Duration(minutes: 5));

void main() {
  late BackupProfile profile;

  setUp(() async {
    profile = await BackupProfile.create();
  });

  tearDown(() => profile.dispose());

  File packageIn(BackupProfile profile) =>
      File(p.join(profile.directory.path, 'out.archlence-backup'));

  group('a package the desktop wrote', () {
    test('opens, and carries the key the desktop put in it', () async {
      final verified = await profile.service().verifyBackup(
        File(desktopPackagePath),
        desktopPassphrase,
      );

      expect(verified.key, desktopKey);
      expect(verified.metadata['format_version'], backupFormatVersion);
      // The desktop counted eleven encrypted fields across five tables. The
      // blank description it also wrote is not among them: blank values are
      // stored unencrypted, and a reader that counted one would have a
      // different total from the app that wrote the file.
      expect(verified.metadata['aead_records_verified'], 11);
      expect(verified.config, isNull);
    }, timeout: _slow);

    test('a wrong passphrase is reported as wrong, not as corruption', () async {
      await expectLater(
        profile.service().verifyBackup(
          File(desktopPackagePath),
          'not-the-passphrase',
        ),
        throwsA(isA<WrongPassphraseError>()),
      );
    }, timeout: _slow);

    test('restores onto a profile that has nothing in it', () async {
      // No database and no key: the first thing a new phone would do with a
      // backup carried over from the desktop.
      await profile.keyProvider.deleteKey(
        expectedCurrent: (await profile.keyProvider.loadKey())!,
      );

      final service = profile.service();
      final outcome = await service.restoreBackup(
        File(desktopPackagePath),
        desktopPassphrase,
      );

      // Nothing was there to insure, so nothing was written aside.
      expect(outcome.safetyBackupPath, isNull);
      expect(await profile.keyProvider.loadKey(), desktopKey);
      expect(profile.database.existsSync(), isTrue);
      expect(await service.verifyDatabaseKey(profile.database, desktopKey), 11);

      // And the restored database is the desktop's, readable through this
      // app's own connection.
      await profile.withDatabase((db, crypto) async {
        final rows = await db
            .customSelect('SELECT description FROM transactions ORDER BY id')
            .get();
        expect(rows, hasLength(2));
        expect(
          await crypto.decryptField(rows.first.read<String?>('description')),
          'haftalık alışveriş',
        );
      });
    }, timeout: _slow);
  });

  group('a package this app wrote', () {
    test('reads back, with the key and the count it recorded', () async {
      await profile.seed();
      final service = profile.service();
      final destination = packageIn(profile);

      final outcome = await service.createBackup(destination, 'a passphrase!');

      // Three encrypted fields: two amounts and one description. The blank
      // description of the second transaction is not one.
      expect(outcome.aeadRecordsVerified, 3);
      expect(outcome.path, destination.path);

      final verified = await service.verifyBackup(destination, 'a passphrase!');
      expect(verified.key, await profile.keyProvider.loadKey());
      expect(verified.metadata['database_sha256'], outcome.databaseSha256);
    }, timeout: _slow);

    test('holds exactly the members the format allows', () async {
      await profile.seed();
      File(profile.configPath).writeAsStringSync('{"theme":"obsidian"}');

      final destination = packageIn(profile);
      await profile
          .service(withConfig: true)
          .createBackup(destination, 'a passphrase!');

      final staged = await Directory.systemTemp.createTemp('members-');
      addTearDown(() => staged.delete(recursive: true));
      final members = await stagePackage(destination, staged);

      expect(members.toSet(), {...requiredMembers, configMember});

      final verified = await profile
          .service(withConfig: true)
          .verifyBackup(destination, 'a passphrase!');
      expect(utf8.decode(verified.config!), '{"theme":"obsidian"}');
    }, timeout: _slow);

    test('refuses to write one without a key to put in it', () async {
      await profile.seed();
      await profile.keyProvider.deleteKey(
        expectedCurrent: (await profile.keyProvider.loadKey())!,
      );

      await expectLater(
        profile.service().createBackup(packageIn(profile), 'a passphrase!'),
        throwsA(isA<KeyUnavailableError>()),
      );
    }, timeout: _slow);

    test('refuses a passphrase shorter than the format allows', () async {
      await profile.seed();
      await expectLater(
        profile.service().createBackup(packageIn(profile), 'short'),
        throwsA(isA<BackupFormatError>()),
      );
      // And nothing was left behind by the attempt.
      expect(packageIn(profile).existsSync(), isFalse);
    }, timeout: _slow);
  });

  group('restoring over data that is already there', () {
    test('replaces the data, and writes the old data aside first', () async {
      // The package to restore FROM: a second profile with its own key.
      final source = await BackupProfile.create(
        key: Uint8List.fromList(List<int>.generate(32, (i) => i * 7 % 256)),
      );
      addTearDown(source.dispose);
      await source.seed();
      final package = packageIn(source);
      await source.service().createBackup(package, 'a passphrase!');

      // The profile to restore INTO, with different data and a different key.
      await profile.seed();
      final keyBefore = (await profile.keyProvider.loadKey())!;
      final service = profile.service();

      final outcome = await service.restoreBackup(package, 'a passphrase!');

      expect(await profile.keyProvider.loadKey(), await source.keyProvider.loadKey());
      expect(await profile.keyProvider.loadKey(), isNot(keyBefore));
      expect(outcome.safetyBackupPath, isNotNull);

      // The insurance really is a working backup of what was there before,
      // and not merely a file that exists.
      final safety = await service.verifyBackup(
        File(outcome.safetyBackupPath!),
        'a passphrase!',
      );
      expect(safety.key, keyBefore);

      expect(Directory(p.join(profile.directory.path, '.archlence-restore')).existsSync(), isFalse);
    }, timeout: _slow);

    test('a failure at any step puts everything back', () async {
      const points = [
        'after_old_files_staged',
        'after_database_replaced',
        'after_config_replaced',
        'after_post_verification',
        'before_key_replaced',
        'after_key_replaced',
      ];

      for (final point in points) {
        final target = await BackupProfile.create();
        final source = await BackupProfile.create(
          key: Uint8List.fromList(List<int>.generate(32, (i) => i + 100)),
        );
        try {
          await source.seed();
          final package = packageIn(source);
          await source.service().createBackup(package, 'a passphrase!');

          await target.seed();
          File(target.configPath).writeAsStringSync('{"before":true}');
          final keyBefore = (await target.keyProvider.loadKey())!;
          final digestBefore = await sha256File(target.database);
          final service = target.service(withConfig: true);

          await expectLater(
            service.restoreBackup(
              package,
              'a passphrase!',
              failurePoint: (reached) {
                if (reached == point) throw StateError('killed at $point');
              },
            ),
            throwsA(isA<RestoreFailedError>()),
            reason: 'failing at $point should not succeed',
          );

          expect(
            await sha256File(target.database),
            digestBefore,
            reason: 'the database should be the one that was there, at $point',
          );
          expect(
            await target.keyProvider.loadKey(),
            keyBefore,
            reason: 'the key should be the one that was there, at $point',
          );
          expect(
            File(target.configPath).readAsStringSync(),
            '{"before":true}',
            reason: 'the settings should be the ones that were there, at $point',
          );
          expect(
            Directory(p.join(target.directory.path, '.archlence-restore')).existsSync(),
            isFalse,
            reason: 'a completed rollback leaves no journal, at $point',
          );
        } finally {
          await target.dispose();
          await source.dispose();
        }
      }
    }, timeout: const Timeout(Duration(minutes: 20)));

    test('a config that did not exist before is not invented by a rollback', () async {
      final source = await BackupProfile.create();
      addTearDown(source.dispose);
      await source.seed();
      File(source.configPath).writeAsStringSync('{"from":"the package"}');
      final package = packageIn(source);
      await source.service(withConfig: true).createBackup(package, 'a passphrase!');

      await profile.seed();
      // No config file here at all.
      expect(File(profile.configPath).existsSync(), isFalse);

      await expectLater(
        profile.service(withConfig: true).restoreBackup(
          package,
          'a passphrase!',
          failurePoint: (reached) {
            if (reached == 'after_post_verification') {
              throw StateError('killed after the config was written');
            }
          },
        ),
        throwsA(isA<RestoreFailedError>()),
      );

      // Putting an OLD copy back would be inventing a file that never
      // existed; the one the restore wrote has to be removed instead.
      expect(File(profile.configPath).existsSync(), isFalse);
    }, timeout: _slow);
  });

  group('a restore the operating system killed partway', () {
    /// Runs a restore, snapshots the whole profile at [point] AS IT STANDS,
    /// and then lets the restore fail.
    ///
    /// The snapshot is what a killed process leaves behind: the journal, the
    /// half-moved files and the key store all exactly as they were at that
    /// instant, with no rollback having run. Restoring the snapshot over the
    /// profile reproduces the next start of the app.
    Future<void> killAt(
      BackupProfile target,
      File package,
      String point,
    ) async {
      final snapshot = Directory(
        p.join(target.directory.parent.path, '${p.basename(target.directory.path)}-snapshot'),
      );
      await expectLater(
        target.service().restoreBackup(
          package,
          'a passphrase!',
          failurePoint: (reached) {
            if (reached != point) return;
            _copyTree(target.directory, snapshot);
            throw StateError('killed at $point');
          },
        ),
        // Whatever the failure point threw. Past the commit the restore no
        // longer converts it, and this helper is only here to freeze the
        // profile mid-flight — the assertions are on what recovery does with
        // the snapshot, not on how the aborted call reported itself.
        throwsA(anything),
      );
      addTearDown(() => snapshot.delete(recursive: true));

      await target.directory.delete(recursive: true);
      _copyTree(snapshot, target.directory);
    }

    test('is rolled back at the next start', () async {
      final source = await BackupProfile.create(
        key: Uint8List.fromList(List<int>.generate(32, (i) => i ~/ 2)),
      );
      addTearDown(source.dispose);
      await source.seed();
      final package = packageIn(source);
      await source.service().createBackup(package, 'a passphrase!');

      await profile.seed();
      final keyBefore = (await profile.keyProvider.loadKey())!;
      final digestBefore = await sha256File(profile.database);

      await killAt(profile, package, 'after_post_verification');

      // The killed process left the new database in place. The key was not
      // touched: it is swapped last, precisely so that this state can be
      // undone into something that still opens.
      expect(await sha256File(profile.database), isNot(digestBefore));
      expect(await profile.keyProvider.loadKey(), keyBefore);

      final action = await profile.service().recoverInterruptedRestore();

      expect(action, RecoveryAction.rolledBack);
      expect(await sha256File(profile.database), digestBefore);
      expect(await profile.keyProvider.loadKey(), keyBefore);
      expect(
        Directory(p.join(profile.directory.path, '.archlence-restore')).existsSync(),
        isFalse,
      );
    }, timeout: _slow);

    test('one that had already committed is only tidied up', () async {
      final source = await BackupProfile.create();
      addTearDown(source.dispose);
      await source.seed();
      final package = packageIn(source);
      await source.service().createBackup(package, 'a passphrase!');

      await profile.seed();
      await killAt(profile, package, 'after_key_replaced');

      final restoredDigest = await sha256File(profile.database);
      final action = await profile.service().recoverInterruptedRestore();

      // Past the commit the new data is correct and stays. Rolling it back
      // would be undoing a restore that succeeded.
      expect(action, RecoveryAction.cleanedUp);
      expect(await sha256File(profile.database), restoredDigest);
      expect(
        Directory(p.join(profile.directory.path, '.archlence-restore')).existsSync(),
        isFalse,
      );
    }, timeout: _slow);

    /// Rewrites the journal's state in place.
    ///
    /// The key store's own write is not interruptible from here — it either
    /// happened or it did not — so the ambiguous state is reproduced by
    /// putting the journal back to it after a real run reached each side.
    void setJournalState(BackupProfile target, String state) {
      final file = File(
        p.join(target.directory.path, '.archlence-restore', 'journal.json'),
      );
      final payload = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      payload['state'] = state;
      file.writeAsStringSync(jsonEncode(payload));
    }

    test('killed inside the key swap, before the store took it', () async {
      final source = await BackupProfile.create(
        key: Uint8List.fromList(List<int>.generate(32, (i) => (i + 9) % 256)),
      );
      addTearDown(source.dispose);
      await source.seed();
      final package = packageIn(source);
      await source.service().createBackup(package, 'a passphrase!');

      await profile.seed();
      final keyBefore = (await profile.keyProvider.loadKey())!;
      final digestBefore = await sha256File(profile.database);

      await killAt(profile, package, 'before_key_replaced');
      expect(await profile.keyProvider.loadKey(), keyBefore);

      // The journal cannot say whether the store took the key; the store
      // itself does, and it still holds the previous one.
      final action = await profile.service().recoverInterruptedRestore();

      expect(action, RecoveryAction.rolledBack);
      expect(await sha256File(profile.database), digestBefore);
      expect(await profile.keyProvider.loadKey(), keyBefore);
    }, timeout: _slow);

    test('killed inside the key swap, after the store took it', () async {
      final source = await BackupProfile.create(
        key: Uint8List.fromList(List<int>.generate(32, (i) => (i + 40) % 256)),
      );
      addTearDown(source.dispose);
      await source.seed();
      final package = packageIn(source);
      await source.service().createBackup(package, 'a passphrase!');

      await profile.seed();
      await killAt(profile, package, 'after_key_replaced');
      // The same journal state as the test above, and the opposite answer:
      // the store now holds the incoming key.
      setJournalState(profile, 'KEY_REPLACING');
      final restoredDigest = await sha256File(profile.database);

      final action = await profile.service().recoverInterruptedRestore();

      expect(action, RecoveryAction.cleanedUp);
      expect(await sha256File(profile.database), restoredDigest);
      expect(
        await profile.keyProvider.loadKey(),
        await source.keyProvider.loadKey(),
      );
    }, timeout: _slow);

    test('a key that is neither one stops the app rather than guessing', () async {
      final source = await BackupProfile.create(
        key: Uint8List.fromList(List<int>.generate(32, (i) => (i + 77) % 256)),
      );
      addTearDown(source.dispose);
      await source.seed();
      final package = packageIn(source);
      await source.service().createBackup(package, 'a passphrase!');

      await profile.seed();
      await killAt(profile, package, 'before_key_replaced');
      setJournalState(profile, 'KEY_REPLACING');

      // A third key: the store changed underneath the restore. Rolling back
      // and committing would each destroy a generation, and there is no
      // evidence for either.
      await profile.keyProvider.replaceKey(
        Uint8List.fromList(List<int>.generate(32, (i) => (i * 11) % 256)),
        expectedCurrent: (await profile.keyProvider.loadKey())!,
      );

      await expectLater(
        profile.service().recoverInterruptedRestore(),
        throwsA(isA<InterruptedRestoreError>()),
      );
      expect(
        Directory(p.join(profile.directory.path, '.archlence-restore')).existsSync(),
        isTrue,
      );
    }, timeout: _slow);

    test('an ordinary start finds nothing to do', () async {
      await profile.seed();
      expect(
        await profile.service().recoverInterruptedRestore(),
        RecoveryAction.none,
      );
    }, timeout: _slow);

    test('a journal that cannot be read stops the app rather than guessing', () async {
      await profile.seed();
      final journal = Directory(p.join(profile.directory.path, '.archlence-restore'));
      journal.createSync();
      File(p.join(journal.path, 'journal.json')).writeAsStringSync('{not json');

      await expectLater(
        profile.service().recoverInterruptedRestore(),
        throwsA(isA<InterruptedRestoreError>()),
      );
      // FAIL-CLOSED: it did not quietly delete the journal on its way out.
      expect(journal.existsSync(), isTrue);
    }, timeout: _slow);

    test('a state this version does not know stops it too', () async {
      await profile.seed();
      final journal = Directory(p.join(profile.directory.path, '.archlence-restore'));
      journal.createSync();
      File(p.join(journal.path, 'journal.json')).writeAsStringSync(
        jsonEncode({'state': 'FROM_A_LATER_VERSION', 'had_config': false}),
      );

      await expectLater(
        profile.service().recoverInterruptedRestore(),
        throwsA(isA<InterruptedRestoreError>()),
      );
    }, timeout: _slow);
  });

  group('what a package is not allowed to get away with', () {
    test('metadata altered after it was signed', () async {
      await profile.seed();
      final destination = packageIn(profile);
      await profile.service().createBackup(destination, 'a passphrase!');

      final rebuilt = await _rewriteMember(destination, metadataMember, (bytes) {
        final metadata =
            jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
        // The timestamp, deliberately: nothing else in the file validates it,
        // so the signature is the ONLY thing that can notice. Changing the
        // record count instead would have been caught a few lines later by
        // the count check, and the test would have passed with the signature
        // check deleted — which is what it did, before this comment.
        metadata['created_at'] = '1999-12-31T23:59:59+00:00';
        return utf8.encode(jsonEncode(metadata));
      });
      addTearDown(() => rebuilt.delete());

      // Not WrongPassphraseError: the passphrase is right, and saying
      // otherwise would send the user to retype something that is correct.
      await expectLater(
        profile.service().verifyBackup(rebuilt, 'a passphrase!'),
        throwsA(isA<BackupFormatError>()),
      );
    }, timeout: _slow);

    test('a record count that no longer matches the database', () async {
      await profile.seed();
      final destination = packageIn(profile);
      await profile.service().createBackup(destination, 'a passphrase!');

      // Re-signed around the changed count, so the signature holds and the
      // count check is the only thing left that can refuse it. This is what
      // a package whose rows were removed after it was written looks like.
      final rebuilt = await _resign(destination, 'a passphrase!', (metadata) {
        metadata['aead_records_verified'] =
            (metadata['aead_records_verified']! as int) - 1;
      });
      addTearDown(() => rebuilt.delete());

      await expectLater(
        profile.service().verifyBackup(rebuilt, 'a passphrase!'),
        throwsA(
          isA<BackupFormatError>().having(
            (e) => e.message,
            'message',
            contains('different number of encrypted records'),
          ),
        ),
      );
    }, timeout: _slow);

    test('a database swapped for another one', () async {
      await profile.seed();
      final destination = packageIn(profile);
      await profile.service().createBackup(destination, 'a passphrase!');

      final other = await BackupProfile.create();
      addTearDown(other.dispose);
      await other.seed();

      final rebuilt = await _rewriteMember(
        destination,
        databaseMember,
        (_) => other.database.readAsBytesSync(),
      );
      addTearDown(() => rebuilt.delete());

      await expectLater(
        profile.service().verifyBackup(rebuilt, 'a passphrase!'),
        throwsA(isA<BackupFormatError>()),
      );
    }, timeout: _slow);

    test('a recovery key swapped, on a profile with nothing encrypted', () async {
      // The case that isolates the key FINGERPRINT. On a profile with rows
      // in it, a substituted key is caught a moment later when it fails to
      // open one — but a profile with nothing encrypted has no rows to fail
      // on, and every other check still passes: the metadata is untouched so
      // its signature holds, the database is untouched so its hash holds, and
      // the count of zero matches a count of zero for any key at all.
      //
      // Without the fingerprint, this package would restore and silently
      // install a key that opens nothing the user later writes with it.
      await profile.createEmpty();
      final service = profile.service();
      final destination = packageIn(profile);
      final outcome = await service.createBackup(destination, 'a passphrase!');
      expect(outcome.aeadRecordsVerified, 0);

      final stranger = Uint8List.fromList(
        List<int>.generate(32, (i) => (i * 13 + 5) % 256),
      );
      final rebuilt = await _rewriteMember(destination, recoveryMember, (_) {
        return utf8.encode('placeholder');
      });
      addTearDown(() => rebuilt.delete());
      // Written through the real wrapper, so the substituted material is a
      // VALID one under the same passphrase — just for the wrong key.
      final material = await encryptRecoveryMaterial(stranger, 'a passphrase!');
      final swapped = await _rewriteMember(
        rebuilt,
        recoveryMember,
        (_) => utf8.encode(jsonEncode(material.toJson())),
      );
      addTearDown(() => swapped.delete());

      await expectLater(
        service.verifyBackup(swapped, 'a passphrase!'),
        throwsA(
          isA<BackupFormatError>().having(
            (e) => e.message,
            'message',
            contains('not the key its metadata names'),
          ),
        ),
      );
    }, timeout: _slow);

    test('a database the key in the package does not open', () async {
      // The last line of defence, and the one that is easiest to leave out:
      // the hash matches, the metadata is correctly signed, the key
      // fingerprint agrees — and the key still does not open the rows.
      await profile.seed();
      final destination = packageIn(profile);
      await profile.service().createBackup(destination, 'a passphrase!');

      // A database with the same shape, encrypted under a DIFFERENT key.
      final stranger = await BackupProfile.create(
        key: Uint8List.fromList(List<int>.generate(32, (i) => (i * 3) % 256)),
      );
      addTearDown(stranger.dispose);
      await stranger.seed();

      final rebuilt = await _rewriteMembers(destination, {
        databaseMember: (_) => stranger.database.readAsBytesSync(),
        metadataMember: (bytes) => bytes,
      });
      addTearDown(() => rebuilt.delete());

      // Re-sign the metadata around the substituted database, so the only
      // thing left wrong is the one thing under test.
      final staged = await Directory.systemTemp.createTemp('resign-');
      addTearDown(() => staged.delete(recursive: true));
      await stagePackage(rebuilt, staged);
      final metadata =
          readJsonObject(File(p.join(staged.path, metadataMember)), 'metadata');
      metadata['database_sha256'] =
          await sha256File(File(p.join(staged.path, databaseMember)));
      metadata.remove('authentication_tag');
      metadata['authentication_tag'] =
          await backupAuthTag(metadata, 'a passphrase!');
      File(
        p.join(staged.path, metadataMember),
      ).writeAsStringSync(jsonEncode(metadata));
      final resigned = File(p.join(staged.path, 'resigned.archlence-backup'));
      await writePackage(staged, requiredMembers, resigned);

      await expectLater(
        profile.service().verifyBackup(resigned, 'a passphrase!'),
        throwsA(
          isA<BackupFormatError>().having(
            (e) => e.message,
            'message',
            contains('does not open'),
          ),
        ),
      );
    }, timeout: _slow);
  });
}

/// Rebuilds [package] with its metadata edited and SIGNED AGAIN.
///
/// So that a test can put exactly one thing wrong: without re-signing, every
/// edit would be refused by the signature and no test below it would ever run.
Future<File> _resign(
  File package,
  String passphrase,
  void Function(Map<String, Object?> metadata) edit,
) async {
  final staged = await Directory.systemTemp.createTemp('resign-');
  final members = await stagePackage(package, staged);
  final file = File(p.join(staged.path, metadataMember));
  final metadata = readJsonObject(file, 'metadata');
  edit(metadata);
  metadata.remove('authentication_tag');
  metadata['authentication_tag'] = await backupAuthTag(metadata, passphrase);
  file.writeAsStringSync(jsonEncode(metadata));
  final rebuilt = File('${package.path}.resigned');
  await writePackage(staged, members, rebuilt);
  await staged.delete(recursive: true);
  return rebuilt;
}

/// Rebuilds [package] with one member's bytes passed through [rewrite].
Future<File> _rewriteMember(
  File package,
  String member,
  List<int> Function(Uint8List bytes) rewrite,
) => _rewriteMembers(package, {member: rewrite});

Future<File> _rewriteMembers(
  File package,
  Map<String, List<int> Function(Uint8List bytes)> rewrites,
) async {
  final staged = await Directory.systemTemp.createTemp('rewrite-');
  final members = await stagePackage(package, staged);
  for (final entry in rewrites.entries) {
    final file = File(p.join(staged.path, entry.key));
    file.writeAsBytesSync(entry.value(file.readAsBytesSync()));
  }
  final rebuilt = File('${package.path}.rewritten');
  await writePackage(staged, members, rebuilt);
  await staged.delete(recursive: true);
  return rebuilt;
}

void _copyTree(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final entity in from.listSync(recursive: true)) {
    final relative = p.relative(entity.path, from: from.path);
    final target = p.join(to.path, relative);
    if (entity is Directory) {
      Directory(target).createSync(recursive: true);
    } else if (entity is File) {
      Directory(p.dirname(target)).createSync(recursive: true);
      entity.copySync(target);
    }
  }
}
