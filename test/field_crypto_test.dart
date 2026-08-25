/// Storage-format compatibility for encrypted columns.
///
/// `cpython_field_vectors.txt` was produced by the desktop app's own
/// `utils/crypto.encrypt`, under a fixed key injected through its
/// key-provider seam. The first line carries that key; the rest are
/// `AEADv1:` tokens and their plaintexts, plus the blank values the desktop
/// deliberately leaves unencrypted.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';

void main() {
  late Uint8List key;
  late List<String> lines;

  setUpAll(() {
    lines = File('test/cpython_field_vectors.txt')
        .readAsLinesSync()
        .where((line) => line.isNotEmpty)
        .toList();
    key = base64.decode(lines.first.split('|')[1]);
  });

  FieldCrypto crypto() => FieldCrypto(FixedKeyProvider(key));

  group('storage format', () {
    test('decrypts every value the desktop wrote', () async {
      final subject = crypto();
      var checked = 0;

      for (final line in lines.skip(1)) {
        if (!line.startsWith('AEADv1:')) continue;
        final parts = line.split('|');
        final expected = utf8.decode(base64.decode(parts[1]));

        expect(await subject.decryptField(parts[0]), expected);
        checked++;
      }

      expect(checked, greaterThan(0));
    });

    test('writes values the desktop can recognise', () async {
      final token = await crypto().encryptField('334401.80');
      expect(token, startsWith(aeadPrefix));
      expect(FieldCrypto.isEncrypted(token), isTrue);
    });

    test('a colon cannot appear in base64, so the prefix is unambiguous', () {
      // Text that merely mentions the prefix is not mistaken for a token.
      expect(
        FieldCrypto.isEncrypted('Metin içinde AEADv1 kelimesi geçiyor'),
        isFalse,
      );
    });
  });

  group('blank values pass through unencrypted', () {
    test('matches the desktop for empty and whitespace-only input', () async {
      final subject = crypto();

      for (final line in lines.where((l) => l.startsWith('PASSTHROUGH|'))) {
        final parts = line.split('|');
        final input = utf8.decode(base64.decode(parts[1]));
        final desktopOutput = utf8.decode(base64.decode(parts[2]));

        expect(await subject.encryptField(input), desktopOutput);
      }
    });

    test('null stays null', () async {
      expect(await crypto().encryptField(null), isNull);
      expect(await crypto().decryptField(null), isNull);
    });

    test('a blank value is not turned into a token', () async {
      // Encrypting these would make an absent description indistinguishable
      // from a present one and break every IS NULL query the desktop uses.
      expect(await crypto().encryptField(''), '');
      expect(await crypto().encryptField('   '), '   ');
    });
  });

  group('round trip', () {
    test('survives amounts, unicode and long text', () async {
      final subject = crypto();
      for (final value in [
        '334401.80',
        '-22131.50',
        'Nakit Cüzdanım',
        '😀 abonelik',
        'a' * 2000,
      ]) {
        expect(
          await subject.decryptField(await subject.encryptField(value)),
          value,
        );
      }
    });
  });

  group('fails closed', () {
    test('a tampered token raises rather than returning anything', () async {
      final subject = crypto();
      final token = (await subject.encryptField('334401.80'))!;
      final tampered =
          '$aeadPrefix${token.substring(aeadPrefix.length, token.length - 4)}AAAA';

      expect(
        () => subject.decryptField(tampered),
        throwsA(isA<IntegrityVerificationError>()),
      );
    });

    test('a wrong key raises rather than returning anything', () async {
      final token = (await crypto().encryptField('334401.80'))!;
      final other = FieldCrypto(FixedKeyProvider(Uint8List(32)));

      expect(
        () => other.decryptField(token),
        throwsA(isA<IntegrityVerificationError>()),
      );
    });

    test('an unprefixed value is reported, not guessed at', () async {
      // Legacy AES-CBC rows are migrated on the desktop; reading them here
      // would mean reimplementing a format that is being retired.
      expect(
        () => crypto().decryptField('bm90IGFuIGFlYWQgdG9rZW4='),
        throwsA(isA<IntegrityVerificationError>()),
      );
    });
  });

  group('encryptedFields map', () {
    test('covers every table the desktop encrypts', () {
      // Mirrors ENCRYPTED_FIELDS in services/backup_service.py. A column
      // missing here is silently stored in the clear.
      expect(
        encryptedFields.keys,
        containsAll(<String>[
          'transactions',
          'active_debts',
          'active_assets',
          'recurring_payments',
          'savings_goals',
          'installment_plans',
          'savings_migration_quarantine',
        ]),
      );
      expect(encryptedFields['transactions'], ['amount', 'description']);
      expect(encryptedFields['active_assets'], ['purchase_price', 'quantity']);
    });
  });
}
