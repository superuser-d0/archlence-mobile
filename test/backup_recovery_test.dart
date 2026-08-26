/// The backup's cryptographic core, against the desktop's OWN output.
///
/// `backup_vectors.txt` was produced by running
/// `services/backup_service.py`'s own functions — not by re-deriving what
/// they ought to produce. This is a wire format: a package written by either
/// app must open in the other, so testing the port against expectations
/// written by hand would test the derivation and not the port.
///
/// These are slow on purpose. PBKDF2 at 600 000 rounds is the whole point of
/// a KDF, and a test that shortcut it would not be testing what ships.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archlence_mobile/backup/recovery_material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A deterministic stand-in for `Random.secure()`, so a written package can
/// be compared byte for byte.
class _FixedRandom implements Random {
  _FixedRandom(this._bytes);

  final List<int> _bytes;
  int _at = 0;

  @override
  int nextInt(int max) => _bytes[_at++ % _bytes.length] % max;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  late List<String> lines;

  setUpAll(() {
    lines = File('test/backup_vectors.txt')
        .readAsLinesSync()
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
  });

  List<List<String>> rowsOf(String type) => [
    for (final line in lines)
      if (line.startsWith('$type|')) line.split('|').sublist(1),
  ];

  test('the round count matches the desktop constant', () {
    expect(rowsOf('ITER').single.single, recoveryIterations.toString());
  });

  test('the authentication context matches the desktop constant', () {
    expect(base64.encode(authContext), rowsOf('AUTHCONTEXT').single.single);
  });

  test('unwraps every key the desktop wrapped', () async {
    var checked = 0;
    for (final row in rowsOf('RECOVERY')) {
      final [key, passphrase, salt, nonce, tag, ciphertext, iterations] = row;
      final material = RecoveryMaterial.fromJson({
        'kdf': supportedRecoveryKdf,
        'iterations': int.parse(iterations),
        'salt': salt,
        'nonce': nonce,
        'tag': tag,
        'ciphertext': ciphertext,
      });

      expect(
        base64.encode(await decryptRecoveryMaterial(material, passphrase)),
        key,
        reason: passphrase,
      );
      checked++;
    }
    expect(checked, greaterThanOrEqualTo(4), reason: 'vectors were not read');
    expect(
      rowsOf('RECOVERY').any((row) => row[6] != recoveryIterations.toString()),
      isTrue,
      // Without one, a port that ignored the count a package declares and
      // always used its own would pass every vector.
      reason: 'a vector at a non-default round count is required',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('a wrong passphrase is reported as wrong, not as corruption', () async {
    // "You mistyped" and "this file is not a backup" need different
    // reactions; collapsing them sends a user hunting for a corrupt file.
    final row = rowsOf('RECOVERY').first;
    final material = RecoveryMaterial.fromJson({
      'kdf': supportedRecoveryKdf,
      'iterations': int.parse(row[6]),
      'salt': row[2],
      'nonce': row[3],
      'tag': row[4],
      'ciphertext': row[5],
    });

    await expectLater(
      decryptRecoveryMaterial(material, 'not the passphrase'),
      throwsA(isA<WrongPassphraseError>()),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('what this app wraps, this app unwraps', () async {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => i * 7 % 256));
    final material = await encryptRecoveryMaterial(
      key,
      'a good long passphrase',
      random: _FixedRandom(const [1, 2, 3, 4, 5]),
    );
    expect(
      await decryptRecoveryMaterial(material, 'a good long passphrase'),
      key,
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('reproduces every authentication tag the desktop computed', () async {
    var checked = 0;
    for (final row in rowsOf('AUTHTAG')) {
      final passphrase = row[0];
      // The vector carries the exact bytes Python serialised, so a
      // disagreement about encoding shows up here rather than as a package
      // that mysteriously fails to verify.
      final metadata = jsonDecode(row[1]) as Map<String, Object?>;
      expect(canonicalJson(metadata), row[1], reason: 'canonical form');
      expect(await backupAuthTag(metadata, passphrase), row[2]);
      checked++;
    }
    expect(checked, greaterThanOrEqualTo(4));
  }, timeout: const Timeout(Duration(minutes: 10)));

  group('what a package is not allowed to say', () {
    RecoveryMaterial parse(Map<String, Object?> overrides) =>
        RecoveryMaterial.fromJson({
          'kdf': supportedRecoveryKdf,
          'iterations': recoveryIterations,
          'salt': base64.encode(List.filled(16, 0)),
          'nonce': base64.encode(List.filled(12, 0)),
          'tag': base64.encode(List.filled(16, 0)),
          'ciphertext': base64.encode(List.filled(32, 0)),
          ...overrides,
        });

    test('an unsupported KDF', () {
      expect(() => parse({'kdf': 'scrypt'}), throwsA(isA<BackupFormatError>()));
    });

    test('a round count low enough to brute-force instantly', () {
      // A package is untrusted input. Without a floor, a crafted backup names
      // one round and its passphrase falls in seconds.
      for (final iterations in [1, 0, -1, minRecoveryIterations - 1]) {
        expect(
          () => parse({'iterations': iterations}),
          throwsA(isA<BackupFormatError>()),
          reason: '$iterations',
        );
      }
    });

    test('a round count high enough to hang the phone', () {
      expect(
        () => parse({'iterations': maxRecoveryIterations + 1}),
        throwsA(isA<BackupFormatError>()),
      );
    });

    test('a round count that is not a number', () {
      for (final value in ['600000', true, null, 1.5]) {
        expect(
          () => parse({'iterations': value}),
          throwsA(isA<BackupFormatError>()),
          reason: '$value',
        );
      }
    });

    test('a field of the wrong length', () {
      for (final field in ['salt', 'nonce', 'tag', 'ciphertext']) {
        expect(
          () => parse({field: base64.encode(List.filled(3, 0))}),
          throwsA(isA<BackupFormatError>()),
          reason: field,
        );
      }
    });

    test('a field that is not base64 at all', () {
      expect(
        () => parse({'salt': 'not base64!!'}),
        throwsA(isA<BackupFormatError>()),
      );
    });
  });

  group('the passphrase floor', () {
    test('is twelve characters, on the way in and the way out', () async {
      await expectLater(
        encryptRecoveryMaterial(Uint8List(32), 'short'),
        throwsA(isA<BackupFormatError>()),
      );
      final material = RecoveryMaterial.fromJson({
        'kdf': supportedRecoveryKdf,
        'iterations': recoveryIterations,
        'salt': base64.encode(List.filled(16, 0)),
        'nonce': base64.encode(List.filled(12, 0)),
        'tag': base64.encode(List.filled(16, 0)),
        'ciphertext': base64.encode(List.filled(32, 0)),
      });
      await expectLater(
        decryptRecoveryMaterial(material, 'short'),
        throwsA(isA<BackupFormatError>()),
      );
    });
  });

  test('the canonical form sorts keys and omits spaces', () {
    // Python's json.dumps(sort_keys=True, separators=(",", ":")). The tag is
    // over these exact bytes, so the ordering is wire format, not style.
    expect(
      canonicalJson({'b': 1, 'a': 'x', 'c': null}),
      '{"a":"x","b":1,"c":null}',
    );
  });
}
