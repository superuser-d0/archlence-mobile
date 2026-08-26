/// The key on its own: exporting it, and putting one back.
///
/// Two things are being proven here and they are different. The PARITY tests
/// use a package the desktop's own `export_recovery_package` wrote, because a
/// port checked against a reading of the format tests the reading. The rest
/// are about a file that arrives from somewhere else and is not to be trusted
/// until it has earned it.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archlence_mobile/backup/backup_errors.dart';
import 'package:archlence_mobile/backup/key_recovery_service.dart';
import 'package:archlence_mobile/crypto/key_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/backup_profile.dart';

/// The pair `tool/emit_recovery_package.py` wrote the committed fixture with.
const String desktopPassphrase = 'desktop-written-recovery';
final Uint8List desktopKey = Uint8List.fromList(
  List<int>.generate(32, (index) => index),
);

void main() {
  late BackupProfile profile;
  late Directory workspace;

  setUp(() async {
    profile = await BackupProfile.create(key: desktopKey);
    workspace = await Directory.systemTemp.createTemp('archlence-recovery-');
  });

  tearDown(() async {
    await profile.dispose();
    if (workspace.existsSync()) await workspace.delete(recursive: true);
  });

  KeyRecoveryService recoveryFor(BackupProfile target) => KeyRecoveryService(
    databasePath: target.databasePath,
    keyProvider: target.keyProvider,
    backup: target.service(),
  );

  File fileIn(String name) => File(p.join(workspace.path, name));

  group('a package the desktop wrote', () {
    final fixture = File('test/desktop_key_recovery.json');

    test('opens here, and carries the exact key', () async {
      // Not "something 32 bytes long came back": the key is fixed on the
      // desktop side so the bytes themselves can be asserted.
      final key = await recoveryFor(profile).readRecoveryPackage(
        fixture,
        desktopPassphrase,
      );
      expect(key, desktopKey);
    });

    test('refuses the wrong passphrase as a passphrase problem', () async {
      // Distinct from a format error ON PURPOSE. "You mistyped" and "this
      // file is not what you think" send a user to different places.
      expect(
        () => recoveryFor(profile).readRecoveryPackage(
          fixture,
          'not-the-passphrase',
        ),
        throwsA(isA<WrongPassphraseError>()),
      );
    });
  });

  group('a package this app wrote', () {
    test('round-trips its own key back out', () async {
      await profile.createEmpty();
      final recovery = recoveryFor(profile);
      final package = fileIn('exported.json');

      await recovery.exportRecoveryPackage(package, 'a-long-enough-phrase');

      expect(await recovery.readRecoveryPackage(package, 'a-long-enough-phrase'),
          desktopKey);
    });

    test('is the shape the desktop reads', () async {
      // The field names and the format string are a contract with the other
      // app; `tool/emit_recovery_package.py --verify` proves the desktop
      // actually opens one, and this keeps the shape from drifting between
      // those runs.
      await profile.createEmpty();
      final package = fileIn('exported.json');
      await recoveryFor(profile)
          .exportRecoveryPackage(package, 'a-long-enough-phrase');

      final payload =
          jsonDecode(await package.readAsString()) as Map<String, Object?>;
      expect(payload['format'], 'archlence-key-recovery-v1');
      expect(payload['created_at'], isA<String>());
      expect(payload['key_fingerprint'], isA<String>());
      expect(
        (payload['recovery']! as Map<String, Object?>).keys.toSet(),
        {'kdf', 'iterations', 'salt', 'nonce', 'tag', 'ciphertext'},
      );
    });

    test('leaves nothing behind when it fails', () async {
      // The export stages and renames. A half-written package that looks
      // whole is exactly the file someone reaches for on the day they need
      // it, so a refusal must leave NO file at all — not a short one.
      final empty = FileKeyProvider(p.join(workspace.path, 'absent.key'));
      final recovery = KeyRecoveryService(
        databasePath: profile.databasePath,
        keyProvider: empty,
        backup: profile.service(),
      );
      final package = fileIn('never-written.json');

      await expectLater(
        () => recovery.exportRecoveryPackage(package, 'a-long-enough-phrase'),
        throwsA(isA<KeyUnavailableError>()),
      );
      expect(package.existsSync(), isFalse);
      expect(File('${package.path}.tmp').existsSync(), isFalse);
    });

    test('refuses a passphrase too short to be worth wrapping under',
        () async {
      await profile.createEmpty();
      expect(
        () => recoveryFor(profile)
            .exportRecoveryPackage(fileIn('short.json'), 'short'),
        throwsA(isA<BackupFormatError>()),
      );
    });
  });

  group('a file that is not one', () {
    Future<void> refuses(String name, String contents) async {
      final package = fileIn(name);
      await package.writeAsString(contents);
      await expectLater(
        () => recoveryFor(profile)
            .readRecoveryPackage(package, desktopPassphrase),
        throwsA(isA<BackupFormatError>()),
        reason: name,
      );
    }

    test('is refused as a backup error, whatever is wrong with it', () async {
      await refuses('not-json.json', 'this is not json at all');
      await refuses('an-array.json', '["not", "an", "object"]');
      await refuses('empty.json', '');
      await refuses(
        'wrong-format.json',
        jsonEncode({'format': 'something-else', 'recovery': {}}),
      );
      await refuses(
        'no-recovery.json',
        jsonEncode({'format': 'archlence-key-recovery-v1'}),
      );
      await refuses(
        'recovery-not-an-object.json',
        jsonEncode({
          'format': 'archlence-key-recovery-v1',
          'recovery': 'nope',
        }),
      );
    });

    test('is refused before it is parsed when it is absurdly large', () async {
      // The point is the SIZE check, not the parser: a huge file must be
      // turned away by its length rather than by the JSON decoder running
      // out of memory on a phone.
      final package = fileIn('enormous.json');
      await package.writeAsString('{${' ' * (4 * 1024 * 1024 + 1)}');
      await expectLater(
        () => recoveryFor(profile)
            .readRecoveryPackage(package, desktopPassphrase),
        throwsA(
          isA<BackupFormatError>().having(
            (error) => error.message,
            'message',
            contains('too large'),
          ),
        ),
      );
    });

    test('is refused when the fingerprint does not match the key', () async {
      // A package whose wrapped key was swapped for another valid one: the
      // AEAD verifies, and only the fingerprint catches it.
      final payload =
          jsonDecode(await File('test/desktop_key_recovery.json').readAsString())
              as Map<String, Object?>;
      payload['key_fingerprint'] = '0' * 64;
      final package = fileIn('wrong-fingerprint.json');
      await package.writeAsString(jsonEncode(payload));

      await expectLater(
        () => recoveryFor(profile)
            .readRecoveryPackage(package, desktopPassphrase),
        throwsA(
          isA<BackupFormatError>().having(
            (error) => error.message,
            'message',
            contains('fingerprint'),
          ),
        ),
      );
    });
  });

  group('importing', () {
    test('says when the key is the one already here', () async {
      // The reassuring answer, and a distinct one: the user asked "is this
      // the right key?" and deserves to be told yes rather than shown a
      // replacement that did nothing.
      await profile.seed();
      final outcome = await recoveryFor(profile).importRecoveryPackage(
        File('test/desktop_key_recovery.json'),
        desktopPassphrase,
      );

      expect(outcome.result, KeyImportResult.unchanged);
      expect(outcome.aeadRecordsVerified, greaterThan(0));
      expect(await profile.keyProvider.loadKey(), desktopKey);
    });

    test('stores it where there was none', () async {
      await profile.seed();
      final bare = FileKeyProvider(p.join(workspace.path, 'bare.key'));
      final recovery = KeyRecoveryService(
        databasePath: profile.databasePath,
        keyProvider: bare,
        backup: profile.service(),
      );

      final outcome = await recovery.importRecoveryPackage(
        File('test/desktop_key_recovery.json'),
        desktopPassphrase,
      );

      expect(outcome.result, KeyImportResult.stored);
      expect(await bare.loadKey(), desktopKey);
    });

    test('replaces a different one', () async {
      await profile.seed();
      // A store holding some other key, over a database the desktop key
      // opens: the case a user is actually in after a reinstall.
      final other = FileKeyProvider(p.join(workspace.path, 'other.key'));
      await other.storeKey(
        Uint8List.fromList(List<int>.generate(32, (index) => 255 - index)),
      );
      final recovery = KeyRecoveryService(
        databasePath: profile.databasePath,
        keyProvider: other,
        backup: profile.service(),
      );

      final outcome = await recovery.importRecoveryPackage(
        File('test/desktop_key_recovery.json'),
        desktopPassphrase,
      );

      expect(outcome.result, KeyImportResult.replaced);
      expect(await other.loadKey(), desktopKey);
      expect(outcome.fingerprint, hasLength(64));
    });

    test('reports zero when there was nothing to check the key against',
        () async {
      // THE NUMBER THAT MATTERS. An empty profile has no encrypted rows, so
      // the key was not really tested — any key would have passed. Saying so
      // is the difference between "verified" and "verified nothing", and the
      // desktop's return value cannot express it.
      await profile.createEmpty();
      final outcome = await recoveryFor(profile).importRecoveryPackage(
        File('test/desktop_key_recovery.json'),
        desktopPassphrase,
      );

      expect(outcome.aeadRecordsVerified, 0);
    });

    test('refuses a key that does not open the data, and touches nothing',
        () async {
      // THE ORDER IS THE WHOLE SAFETY PROPERTY. A key that does not open this
      // database would make every encrypted row unreadable the moment it
      // landed, and by then the old key is gone with nothing to roll back to.
      await profile.seed();

      // A package for a DIFFERENT key, written by this app so the file itself
      // is impeccable — the only thing wrong with it is that it does not
      // belong to this database.
      final stranger = FileKeyProvider(p.join(workspace.path, 'stranger.key'));
      final strangerKey = Uint8List.fromList(
        List<int>.generate(32, (index) => (index * 7 + 3) % 256),
      );
      await stranger.storeKey(strangerKey);
      final package = fileIn('stranger.json');
      await KeyRecoveryService(
        databasePath: profile.databasePath,
        keyProvider: stranger,
        backup: profile.service(),
      ).exportRecoveryPackage(package, 'a-long-enough-phrase');

      await expectLater(
        () => recoveryFor(profile)
            .importRecoveryPackage(package, 'a-long-enough-phrase'),
        throwsA(isA<BackupFormatError>()),
      );
      expect(
        await profile.keyProvider.loadKey(),
        desktopKey,
        reason: 'the key store must be exactly as it was',
      );
    });

    test('refuses when there is no database for the key to open', () async {
      // Nothing was created, so there is nothing to verify against. Storing
      // the key anyway would be accepting it on no evidence at all.
      await expectLater(
        () => recoveryFor(profile).importRecoveryPackage(
          File('test/desktop_key_recovery.json'),
          desktopPassphrase,
        ),
        throwsA(isA<BackupFormatError>()),
      );
    });
  });
}
