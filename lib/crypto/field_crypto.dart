/// Field-level encryption for values on their way to and from the database.
///
/// A port of the desktop app's `utils/crypto.py`. Three behaviours here are
/// storage format, not implementation detail, and all three must match or the
/// two apps cannot read each other's rows:
///
///  * every ciphertext carries the `AEADv1:` prefix;
///  * null and blank values pass through untouched, unencrypted;
///  * anything that fails to decrypt raises — it is never replaced.
///
/// The prefix exists to tell AEAD records apart from the legacy AES-CBC ones
/// the desktop wrote before its migration. A colon never appears in the
/// base64 alphabet, so the test cannot produce a false positive.
library;

import 'aead_crypto.dart' as aead;
import 'key_provider.dart';

/// Marks a value as carrying an AES-256-GCM envelope.
const String aeadPrefix = 'AEADv1:';

/// The encrypted value could not be authenticated.
///
/// Distinct from [KeyUnavailableError]: this one means the key was readable
/// but the data did not verify under it — corruption or tampering, not a
/// configuration problem. The two need different messages in the UI.
class IntegrityVerificationError implements Exception {
  const IntegrityVerificationError(this.message);

  final String message;

  @override
  String toString() => 'IntegrityVerificationError: $message';
}

/// Which columns hold encrypted values.
///
/// Mirrors `ENCRYPTED_FIELDS` in `services/backup_service.py`, which is the
/// single source the desktop uses for backup, migration and key verification.
/// A column missing from this map is silently left in the clear, so it is
/// asserted against the real schema in the tests rather than trusted.
const Map<String, List<String>> encryptedFields = {
  'transactions': ['amount', 'description'],
  'active_debts': ['debt_name', 'total_amount', 'monthly_payment'],
  'active_assets': ['purchase_price', 'quantity'],
  'recurring_payments': ['name', 'amount'],
  'savings_goals': ['goal_name'],
  'installment_plans': ['description', 'total_amount', 'monthly_amount'],
  'savings_migration_quarantine': ['goal_name', 'payload'],
};

/// Encrypts values for storage, holding the key for the process lifetime.
class FieldCrypto {
  FieldCrypto(this._keyProvider);

  final KeyProvider _keyProvider;
  List<int>? _cachedKey;

  Future<List<int>> _key() async {
    return _cachedKey ??= await _keyProvider.getOrCreateKey();
  }

  /// True when [value] is already an AEAD envelope.
  static bool isEncrypted(Object? value) =>
      value is String && value.startsWith(aeadPrefix);

  /// Whether a value is one the desktop leaves unencrypted.
  ///
  /// Null and blank are stored as-is. Encrypting them would make an empty
  /// description indistinguishable from a present one, and would break every
  /// `WHERE column IS NULL` the desktop relies on.
  static bool _passesThrough(Object? value) =>
      value == null || value.toString().trim().isEmpty;

  /// Encrypts [value] for storage, returning `AEADv1:<base64 envelope>`.
  ///
  /// Blank input is returned unchanged. Failure raises: no plaintext is ever
  /// written as a fallback.
  Future<String?> encryptField(Object? value) async {
    if (_passesThrough(value)) return value?.toString();

    final List<int> key;
    try {
      key = await _key();
    } on KeyUnavailableError {
      rethrow;
    } on Exception catch (e) {
      throw KeyUnavailableError(
        'The encryption key was unreachable; nothing was saved. ($e)',
      );
    }

    return aeadPrefix + await aead.encrypt(value.toString(), key);
  }

  /// Decrypts a value read from storage.
  ///
  /// Blank input is returned unchanged. A value without the prefix predates
  /// the desktop's AEAD migration and is reported rather than guessed at —
  /// the legacy AES-CBC reader is deliberately not ported, since the desktop
  /// migrates those rows in place before any backup is written.
  Future<String?> decryptField(Object? value) async {
    if (_passesThrough(value)) return value?.toString();

    final text = value.toString();
    if (!text.startsWith(aeadPrefix)) {
      throw const IntegrityVerificationError(
        'The value is not in the AEADv1 format; it predates the encryption '
        'migration and must be migrated on the desktop first.',
      );
    }

    final List<int> key;
    try {
      key = await _key();
    } on KeyUnavailableError {
      rethrow;
    } on Exception catch (e) {
      throw KeyUnavailableError(
        'The encryption key was unreachable; the value was not opened. ($e)',
      );
    }

    try {
      return await aead.decrypt(text.substring(aeadPrefix.length), key);
    } on aead.DecryptionError {
      throw const IntegrityVerificationError(
        'The integrity of the encrypted value could not be verified.',
      );
    }
  }
}
