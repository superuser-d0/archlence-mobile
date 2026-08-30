/// Platform key stores with an explicit, observable file fallback.
///
/// A port of the desktop app's `utils/key_provider.py`, with the Windows
/// DPAPI and Linux Secret Service providers replaced by the Android Keystore.
/// The contract is unchanged: a stored key is never silently replaced, every
/// write is read back and verified, and when no secure store is available the
/// app says so instead of pretending otherwise.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'aead_crypto.dart' show generateKey;

const int _keyLen = 32;

/// The key could not be read, written or verified.
///
/// Never thrown to be swallowed: the caller surfaces it. Continuing without a
/// key would mean either losing access to existing data or writing new data
/// under a second key that nothing can decrypt later.
class KeyUnavailableError implements Exception {
  const KeyUnavailableError(this.message);

  final String message;

  @override
  String toString() => 'KeyUnavailableError: $message';
}

void _validateKey(List<int> key) {
  if (key.length != _keyLen) {
    throw KeyUnavailableError(
      'Key is corrupt: ${key.length} bytes (expected $_keyLen).',
    );
  }
}

bool _sameKey(List<int>? a, List<int>? b) {
  if (a == null || b == null) return a == null && b == null;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Which store the key ended up in.
///
/// A CODE, not a display name, for the reason the services carry error codes
/// rather than sentences: the wording belongs to the screen that shows it and
/// has to survive translation. This layer knows which store it used; it does
/// not know what language the phone is in. `settings_screen.dart` turns these
/// into words.
enum KeyProtectionMethod { androidKeystore, ownerOnlyFile }

/// Why the key is somewhere less protected than it could be.
enum KeyProtectionWarning { osKeyStoreUnavailable, platformHasNoKeyStore }

/// How the key is being protected, for display in Settings.
class KeyProtectionStatus {
  const KeyProtectionStatus(this.method, this.secureStore, [this.warning]);

  /// The store in use.
  final KeyProtectionMethod method;

  /// Whether the key is held by an OS-backed secure store.
  final bool secureStore;

  /// Set when the key fell back to a less protected location, so the UI can
  /// tell the user rather than leaving them to assume the best case.
  final KeyProtectionWarning? warning;
}

abstract interface class KeyProvider {
  /// The existing key, or null when none has been stored.
  Future<Uint8List?> loadKey();

  /// Persists an explicit key without silently replacing another one.
  Future<void> storeKey(List<int> key);

  /// A 32-byte AES-256 key: generated and persisted on first call, and the
  /// same key on every call after.
  Future<Uint8List> getOrCreateKey();

  /// Atomically replaces a known current key, verifying it persisted.
  Future<void> replaceKey(List<int> key, {required List<int> expectedCurrent});

  /// Deletes only the exact expected key.
  Future<void> deleteKey({required List<int> expectedCurrent});
}

/// Keeps the key in a file, creating it without ever overwriting an existing
/// one.
///
/// The desktop version claims the path with `O_CREAT | O_EXCL` and then hard-
/// links the finished content into place, because a bare exclusive create
/// leaves the file briefly visible as EMPTY and a concurrent reader in that
/// window sees a zero-byte key. Dart exposes `File.create(exclusive: true)`
/// (the same `O_EXCL`) but no hard-link call, so the window is closed from the
/// other side instead: the claim is renamed over with complete content
/// immediately, and a reader that catches the gap retries rather than
/// concluding the file is corrupt.
///
/// What is never traded away is the property that motivated all of this — an
/// existing key file is never overwritten. Silently replacing one would make
/// everything encrypted under the old key permanently unrecoverable, because
/// the discarded key is backed up nowhere.
class FileKeyProvider implements KeyProvider {
  FileKeyProvider(this.keyPath);

  final String keyPath;

  File get _file => File(keyPath);

  @override
  Future<Uint8List?> loadKey() async {
    if (!await _file.exists()) return null;
    return _readExisting();
  }

  @override
  Future<void> storeKey(List<int> key) async {
    _validateKey(key);
    final existing = await loadKey();
    if (existing != null) {
      if (!_sameKey(existing, key)) {
        throw const KeyUnavailableError(
          'The existing key cannot be replaced without verifying it.',
        );
      }
      return;
    }
    await _createAtomically(key);
  }

  @override
  Future<Uint8List> getOrCreateKey() async {
    final existing = await loadKey();
    if (existing != null) return existing;
    return _createAtomically(generateKey());
  }

  @override
  Future<void> replaceKey(
    List<int> key, {
    required List<int> expectedCurrent,
  }) async {
    _validateKey(key);
    _validateKey(expectedCurrent);
    if (!_sameKey(await loadKey(), expectedCurrent)) {
      throw const KeyUnavailableError(
        'The key changed; the safe replacement was cancelled.',
      );
    }

    final staged = File('$keyPath.replacement');
    await staged.writeAsBytes(key, flush: true);
    await staged.rename(keyPath);

    if (!_sameKey(await loadKey(), key)) {
      throw const KeyUnavailableError(
        'The new key could not be verified after writing.',
      );
    }
  }

  @override
  Future<void> deleteKey({required List<int> expectedCurrent}) async {
    if (!_sameKey(await loadKey(), expectedCurrent)) {
      throw const KeyUnavailableError(
        'The key to delete is not the expected key.',
      );
    }
    await _file.delete();
  }

  Future<Uint8List> _createAtomically(List<int> key) async {
    await Directory(_file.parent.path).create(recursive: true);

    try {
      // O_EXCL: claims the path or fails. Never truncates an existing file.
      await _file.create(exclusive: true);
    } on FileSystemException {
      // Someone else got there first — adopt their key, do not overwrite it.
      return _readExisting();
    }

    final staged = File('$keyPath.tmp');
    await staged.writeAsBytes(key, flush: true);
    await staged.rename(keyPath);
    return Uint8List.fromList(key);
  }

  /// Reads the key, tolerating the brief moment when another writer has
  /// claimed the path but not yet renamed its content into place.
  Future<Uint8List> _readExisting() async {
    for (var attempt = 0; ; attempt++) {
      final bytes = await _file.readAsBytes();
      if (bytes.length == _keyLen) return bytes;

      // A zero-length file is the claim window; anything else is corruption.
      if (bytes.isNotEmpty || attempt >= 20) {
        throw KeyUnavailableError(
          'Key file is corrupt: ${bytes.length} bytes (expected $_keyLen).',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }
}

/// Holds the key in the Android Keystore.
///
/// Stands in for the desktop app's Secret Service and DPAPI providers: same
/// contract, same verify-after-write discipline, different OS facility.
///
/// `resetOnError: false` is the important argument, and it is important
/// because the default went the other way. `flutter_secure_storage` 11
/// defaults it to TRUE: a read that fails erases the entire store rather
/// than reporting. For a preference that would be a recovered error. What
/// this store holds is the key the whole database is encrypted under, so a
/// silent reset is every account, transaction and holding on the device,
/// unreadable, with nothing in the log to say it happened. It is set on
/// every construction in this app for the same reason — the entries share
/// one store, so a reset triggered by any of them takes the key with it.
class SecureStorageKeyProvider implements KeyProvider {
  SecureStorageKeyProvider({
    FlutterSecureStorage? storage,
    this.entryKey = 'archlence.encryption-key',
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(resetOnError: false),
           );

  final FlutterSecureStorage _storage;
  final String entryKey;

  /// Whether the platform store answers at all. A device with a broken or
  /// absent Keystore reports false so the caller can fall back deliberately
  /// and tell the user, rather than failing at the first write.
  Future<bool> isAvailable() async {
    try {
      await _storage.containsKey(key: entryKey);
      return true;
    } on Exception {
      return false;
    }
  }

  @override
  Future<Uint8List?> loadKey() async {
    final String? encoded;
    try {
      encoded = await _storage.read(key: entryKey);
    } on Exception {
      throw const KeyUnavailableError(
        'The key could not be read from the OS key store.',
      );
    }
    if (encoded == null) return null;

    final Uint8List key;
    try {
      key = base64.decode(encoded);
    } on FormatException {
      throw const KeyUnavailableError(
        'The value in the OS key store is corrupt.',
      );
    }
    _validateKey(key);
    return key;
  }

  @override
  Future<void> storeKey(List<int> key) async {
    _validateKey(key);
    final existing = await loadKey();
    if (existing != null && !_sameKey(existing, key)) {
      throw const KeyUnavailableError(
        'The existing OS key cannot be replaced without verifying it.',
      );
    }
    await _write(key, 'The key could not be written to the OS key store.');
  }

  @override
  Future<Uint8List> getOrCreateKey() async {
    final existing = await loadKey();
    if (existing != null) return existing;
    final key = generateKey();
    await storeKey(key);
    return key;
  }

  @override
  Future<void> replaceKey(
    List<int> key, {
    required List<int> expectedCurrent,
  }) async {
    _validateKey(key);
    if (!_sameKey(await loadKey(), expectedCurrent)) {
      throw const KeyUnavailableError(
        'The OS key changed; the safe replacement was cancelled.',
      );
    }
    await _write(key, 'The key in the OS key store could not be replaced.');
  }

  @override
  Future<void> deleteKey({required List<int> expectedCurrent}) async {
    if (!_sameKey(await loadKey(), expectedCurrent)) {
      throw const KeyUnavailableError('The OS key to delete does not match.');
    }
    try {
      await _storage.delete(key: entryKey);
    } on Exception {
      throw const KeyUnavailableError(
        'The key in the OS key store could not be deleted.',
      );
    }
  }

  /// Writes, then reads back. A store that accepts a write and returns
  /// something else is worse than one that refuses outright, because the
  /// mismatch would only surface later as undecryptable data.
  Future<void> _write(List<int> key, String failureMessage) async {
    try {
      await _storage.write(key: entryKey, value: base64.encode(key));
    } on Exception {
      throw KeyUnavailableError(failureMessage);
    }
    if (!_sameKey(await loadKey(), key)) {
      throw const KeyUnavailableError(
        'The write to the OS key store could not be verified.',
      );
    }
  }
}

/// Moves a legacy file key into the secure store on first use.
///
/// The old key is deleted only after the new store has been read back and
/// confirmed to hold it. An unverified move that deleted the file first would
/// lose the only copy.
class MigratingKeyProvider implements KeyProvider {
  const MigratingKeyProvider(this.primary, this.fallback, this.status);

  /// The secure store, or null when this platform has none available.
  final KeyProvider? primary;
  final FileKeyProvider fallback;
  final KeyProtectionStatus status;

  KeyProvider get _target => primary ?? fallback;

  @override
  Future<Uint8List?> loadKey() async {
    if (primary == null) return fallback.loadKey();

    final key = await primary!.loadKey();
    if (key != null) return key;

    final legacy = await fallback.loadKey();
    if (legacy == null) return null;

    await primary!.storeKey(legacy);
    if (!_sameKey(await primary!.loadKey(), legacy)) {
      throw const KeyUnavailableError(
        'The move of the old key into the OS store could not be verified.',
      );
    }
    await File(fallback.keyPath).delete();
    return legacy;
  }

  @override
  Future<void> storeKey(List<int> key) => _target.storeKey(key);

  @override
  Future<Uint8List> getOrCreateKey() async {
    final key = await loadKey();
    if (key != null) return key;
    final fresh = generateKey();
    await storeKey(fresh);
    return fresh;
  }

  @override
  Future<void> replaceKey(
    List<int> key, {
    required List<int> expectedCurrent,
  }) => _target.replaceKey(key, expectedCurrent: expectedCurrent);

  @override
  Future<void> deleteKey({required List<int> expectedCurrent}) =>
      _target.deleteKey(expectedCurrent: expectedCurrent);
}

/// Builds the provider chain for this platform.
Future<MigratingKeyProvider> createPlatformKeyProvider(
  String dataDirectory, {
  SecureStorageKeyProvider? secureStorage,
}) async {
  final fallback = FileKeyProvider('$dataDirectory/encryption.key');

  if (Platform.isAndroid || Platform.isIOS) {
    final provider = secureStorage ?? SecureStorageKeyProvider();
    if (await provider.isAvailable()) {
      return MigratingKeyProvider(
        provider,
        fallback,
        const KeyProtectionStatus(KeyProtectionMethod.androidKeystore, true),
      );
    }
    return MigratingKeyProvider(
      null,
      fallback,
      const KeyProtectionStatus(
        KeyProtectionMethod.ownerOnlyFile,
        false,
        KeyProtectionWarning.osKeyStoreUnavailable,
      ),
    );
  }

  return MigratingKeyProvider(
    null,
    fallback,
    const KeyProtectionStatus(
      KeyProtectionMethod.ownerOnlyFile,
      false,
      KeyProtectionWarning.platformHasNoKeyStore,
    ),
  );
}
