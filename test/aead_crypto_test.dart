/// Wire-compatibility and fail-closed tests for the AEAD core.
///
/// `cpython_aead_vectors.txt` holds envelopes produced by the desktop app's
/// own `utils/aead_crypto.encrypt` (pycryptodome), one per line as
/// `base64(key) | envelope | base64(utf8 plaintext)`. If Dart cannot read
/// them, a database or backup written on the desktop is unreadable on the
/// phone — which is why this is checked against real output rather than
/// against a Dart round-trip alone.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archlence_mobile/crypto/aead_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('interoperability with the desktop app', () {
    test('decrypts every envelope CPython produced', () async {
      final lines = File('test/cpython_aead_vectors.txt')
          .readAsLinesSync()
          .where((line) => line.isNotEmpty)
          .toList();

      expect(lines, isNotEmpty);

      for (final line in lines) {
        final parts = line.split('|');
        final key = base64.decode(parts[0]);
        final token = parts[1];
        final expected = utf8.decode(base64.decode(parts[2]));

        expect(await decrypt(token, key), expected);
      }
    });

    test('produces envelopes in the same layout', () async {
      // version | algo | nonce(12) | tag(16) | ciphertext — the tag sits
      // before the ciphertext, not after it.
      final key = generateKey();
      final token = await encrypt('Nakit Cüzdanım', key);
      final envelope = base64.decode(token);

      expect(envelope[0], 1, reason: 'version');
      expect(envelope[1], 1, reason: 'AES-256-GCM');
      expect(
        envelope.length,
        2 + 12 + 16 + utf8.encode('Nakit Cüzdanım').length,
      );
    });
  });

  group('round trip', () {
    test('survives empty, unicode and long values', () async {
      final key = generateKey();
      for (final text in [
        '',
        '0.00',
        'Nakit Cüzdanım',
        '😀 çok baytlı',
        'a' * 5000,
      ]) {
        expect(await decrypt(await encrypt(text, key), key), text);
      }
    });

    test('a fresh nonce is used for every call', () async {
      final key = generateKey();
      final first = await encrypt('same plaintext', key);
      final second = await encrypt('same plaintext', key);
      expect(first, isNot(second));
    });
  });

  group('fails closed', () {
    late List<int> key;

    setUp(() => key = generateKey());

    test('rejects the wrong key rather than returning anything', () async {
      final token = await encrypt('334401.80', key);
      expect(
        () => decrypt(token, generateKey()),
        throwsA(isA<DecryptionError>()),
      );
    });

    test('rejects a tampered ciphertext', () async {
      final token = await encrypt('334401.80', key);
      final envelope = base64.decode(token);
      envelope[envelope.length - 1] ^= 0x01;
      expect(
        () => decrypt(base64.encode(envelope), key),
        throwsA(isA<DecryptionError>()),
      );
    });

    test('rejects a tampered authentication tag', () async {
      final token = await encrypt('334401.80', key);
      final envelope = base64.decode(token);
      envelope[2 + 12] ^= 0x01; // first byte of the tag
      expect(
        () => decrypt(base64.encode(envelope), key),
        throwsA(isA<DecryptionError>()),
      );
    });

    test('rejects an unknown version or algorithm', () async {
      final token = await encrypt('334401.80', key);

      final wrongVersion = base64.decode(token)..[0] = 2;
      expect(
        () => decrypt(base64.encode(wrongVersion), key),
        throwsA(isA<DecryptionError>()),
      );

      final wrongAlgo = base64.decode(token)..[1] = 9;
      expect(
        () => decrypt(base64.encode(wrongAlgo), key),
        throwsA(isA<DecryptionError>()),
      );
    });

    test('rejects a truncated envelope', () async {
      final token = await encrypt('334401.80', key);
      final short = base64.decode(token).sublist(0, 20);
      expect(
        () => decrypt(base64.encode(short), key),
        throwsA(isA<DecryptionError>()),
      );
    });

    test('rejects text that is not base64', () {
      expect(
        () => decrypt('not base64 !!', key),
        throwsA(isA<DecryptionError>()),
      );
    });

    test('rejects a key of the wrong length', () async {
      expect(
        () => encrypt('x', List.filled(16, 0)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
