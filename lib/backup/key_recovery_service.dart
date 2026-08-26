/// Exporting the encryption key on its own, and putting one back.
///
/// A port of the export/import half of `services/key_recovery_service.py`.
/// `rotate_encryption_key` is deliberately still not here — see
/// "What the backup work did NOT port" in the roadmap.
///
/// WHAT THIS IS FOR, and why a whole backup does not cover it: a backup holds
/// the database AND the key, so restoring one replaces both. This answers the
/// other case — the data is fine and the KEY is gone. A phone reset, a
/// reinstall, a Keystore invalidated by changing the screen lock: the rows are
/// still there and unreadable, and a backup from last month would throw away
/// everything written since.
///
/// A recovery package is a few hundred bytes of JSON: the key wrapped under a
/// passphrase, exactly as it travels inside a backup, plus a fingerprint to
/// check it against. It is wire-compatible with the desktop's — same format
/// string, same fields — so a key exported on one opens the other's database.
///
/// **THE FILE IS UNTRUSTED INPUT**, like a backup package and for the same
/// reasons: it arrives from storage, a cloud folder or a messaging app, and
/// nothing about it is proven when this code first looks at it.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../crypto/key_provider.dart';
import 'backup_package.dart' show maxSmallMemberBytes, sha256Hex;
import 'backup_service.dart';
import 'recovery_material.dart';

/// The `format` this app writes and the only one it reads. The desktop's
/// string, verbatim.
const String recoveryPackageFormat = 'archlence-key-recovery-v1';

/// What importing a key actually did.
enum KeyImportResult {
  /// There was no key here; the imported one was stored.
  stored,

  /// A different key was here; it was replaced.
  replaced,

  /// The imported key was already the key here. Nothing was touched.
  ///
  /// Reported rather than folded into [replaced] because it is the reassuring
  /// answer and the user asked a question: "is this the right key?" — and it
  /// is worth being told yes rather than being shown a replacement that did
  /// nothing.
  unchanged,
}

/// What an import did, and how much it was able to prove.
class RecoveryImportOutcome {
  const RecoveryImportOutcome({
    required this.result,
    required this.fingerprint,
    required this.aeadRecordsVerified,
  });

  final KeyImportResult result;

  /// SHA-256 of the imported key, hex. The same value the package carries,
  /// recomputed from what actually came out of it.
  final String fingerprint;

  /// How many encrypted fields the key was checked against BEFORE it went
  /// anywhere near the key store.
  ///
  /// **Zero is the number to pay attention to.** It means the database had
  /// nothing encrypted in it, so the key was not really tested — any key at
  /// all would have passed. The desktop returns nothing here and cannot say
  /// so; the caller is expected to.
  final int aeadRecordsVerified;
}

class KeyRecoveryService {
  const KeyRecoveryService({
    required this.databasePath,
    required this.keyProvider,
    required this.backup,
  });

  final String databasePath;
  final KeyProvider keyProvider;

  /// Borrowed for `verifyDatabaseKey`, which is the same walk a backup does
  /// over the same tables. A second copy of it would be a second thing to
  /// keep in step with `encryptedFields`.
  final BackupService backup;

  /// Writes the current key, wrapped under [passphrase], to [destination].
  ///
  /// Staged and renamed rather than written in place: a half-written recovery
  /// package that looks like a whole one is exactly the file someone reaches
  /// for on the day they need it.
  Future<String> exportRecoveryPackage(
    File destination,
    String passphrase,
  ) async {
    requirePassphrase(passphrase);
    final key = await keyProvider.loadKey();
    if (key == null) {
      throw const KeyUnavailableError(
        'There is no encryption key to export; nothing was written.',
      );
    }

    final payload = <String, Object?>{
      'format': recoveryPackageFormat,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'key_fingerprint': await sha256Hex(key),
      'recovery': (await encryptRecoveryMaterial(key, passphrase)).toJson(),
    };

    await destination.parent.create(recursive: true);
    final staged = File('${destination.path}.tmp');
    await staged.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    await staged.rename(destination.path);
    return destination.path;
  }

  /// Opens [package] and returns the key inside it, proving nothing else.
  ///
  /// Split out from [importRecoveryPackage] so the checks that happen before
  /// anything is written can be read in one place — and so a caller that only
  /// wants to know whether a passphrase opens a file does not have to risk
  /// writing a key to find out.
  Future<Uint8List> readRecoveryPackage(
    File package,
    String passphrase,
  ) async {
    final Object? decoded;
    try {
      // Bounded before it is parsed. The same ceiling the recovery member
      // inside a backup gets, and this file is three orders of magnitude
      // under it — the point is that a 2GB "recovery package" is refused by
      // its size rather than by the JSON parser running out of memory.
      final length = await package.length();
      if (length > maxSmallMemberBytes) {
        throw const BackupFormatError(
          'That file is far too large to be a key recovery package.',
        );
      }
      decoded = jsonDecode(await package.readAsString());
    } on BackupFormatError {
      rethrow;
    } on Object {
      // FileSystemException, FormatException, and anything a malformed byte
      // sequence raises on the way to UTF-8. One answer for all of them: the
      // file is not a recovery package.
      throw const BackupFormatError('That file is not a key recovery package.');
    }

    if (decoded is! Map<String, Object?>) {
      throw const BackupFormatError('That file is not a key recovery package.');
    }
    if (decoded['format'] != recoveryPackageFormat) {
      throw const BackupFormatError(
        'That key recovery package is in a format this app does not read.',
      );
    }
    final material = decoded['recovery'];
    if (material is! Map<String, Object?>) {
      throw const BackupFormatError('That key recovery package is damaged.');
    }

    // Throws WrongPassphraseError when the tag does not verify, which the
    // screen has to be able to tell apart from a damaged file: "you mistyped"
    // and "this file is not what you think" send a user to different places.
    final key = await decryptRecoveryMaterial(
      RecoveryMaterial.fromJson(material),
      passphrase,
    );

    // Checked AFTER decryption, and it is a CHECK rather than a secret: a
    // SHA-256 of 32 random bytes gives nothing away, and it catches a package
    // whose wrapped key was swapped for another valid one.
    if (await sha256Hex(key) != decoded['key_fingerprint']) {
      throw const BackupFormatError(
        'The key in that package does not match its own fingerprint.',
      );
    }
    return key;
  }

  /// Puts the key from [package] into the key store.
  ///
  /// **THE ORDER IS THE SAFETY PROPERTY.** The key is proven against the
  /// database that is here NOW, before the key store is touched at all. A key
  /// that does not open this data would make every encrypted row unreadable
  /// the moment it landed, and there is nothing to roll back to — the old key
  /// is gone by then. So the verification comes first and a failure leaves the
  /// store exactly as it was.
  Future<RecoveryImportOutcome> importRecoveryPackage(
    File package,
    String passphrase,
  ) async {
    final incoming = await readRecoveryPackage(package, passphrase);

    final database = File(databasePath);
    if (!await database.exists()) {
      throw const BackupFormatError(
        'There is no database here for that key to open.',
      );
    }
    final verified = await backup.verifyDatabaseKey(database, incoming);

    final current = await keyProvider.loadKey();
    final KeyImportResult result;
    if (current == null) {
      await keyProvider.storeKey(incoming);
      result = KeyImportResult.stored;
    } else if (_sameBytes(current, incoming)) {
      result = KeyImportResult.unchanged;
    } else {
      // `expectedCurrent` rather than a blind write: the provider refuses if
      // the store moved under us between the read above and this call.
      await keyProvider.replaceKey(incoming, expectedCurrent: current);
      result = KeyImportResult.replaced;
    }

    return RecoveryImportOutcome(
      result: result,
      fingerprint: await sha256Hex(incoming),
      aeadRecordsVerified: verified,
    );
  }
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
