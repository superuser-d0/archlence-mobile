/// Ported from the desktop app's `tests/test_key_provider.py`.
///
/// The properties under test are the ones that make a lost key
/// unrecoverable, so each is checked directly rather than through the app.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archlence_mobile/crypto/key_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// An in-memory stand-in for the platform store.
class _FakeSecureStorage implements FlutterSecureStorage {
  _FakeSecureStorage({this.available = true});

  final bool available;
  final Map<String, String> entries = {};

  void _guard() {
    if (!available) throw Exception('secure store unavailable');
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _guard();
    return entries[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _guard();
    if (value == null) {
      entries.remove(key);
    } else {
      entries[key] = value;
    }
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _guard();
    return entries.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _guard();
    entries.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used in tests');
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('archlence_key_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  String keyPath() => '${tempDir.path}/encryption.key';

  group('FileKeyProvider', () {
    test(
      'creates a 32-byte key on first use and returns it thereafter',
      () async {
        final provider = FileKeyProvider(keyPath());
        final first = await provider.getOrCreateKey();
        expect(first, hasLength(32));

        final second = await FileKeyProvider(keyPath()).getOrCreateKey();
        expect(second, first, reason: 'the key must survive a restart');
      },
    );

    test('loadKey is null before anything is stored', () async {
      expect(await FileKeyProvider(keyPath()).loadKey(), isNull);
    });

    test('refuses to overwrite a different existing key', () async {
      final provider = FileKeyProvider(keyPath());
      await provider.getOrCreateKey();

      expect(
        () => provider.storeKey(Uint8List(32)),
        throwsA(isA<KeyUnavailableError>()),
      );
    });

    test('storing the identical key again is a no-op', () async {
      final provider = FileKeyProvider(keyPath());
      final key = await provider.getOrCreateKey();
      await provider.storeKey(key);
      expect(await provider.loadKey(), key);
    });

    test('a corrupt key file is reported, never treated as absent', () async {
      // Treating it as absent would generate a second key and silently
      // strand every record encrypted under the first.
      await File(keyPath()).writeAsBytes(List.filled(16, 7), flush: true);

      expect(
        () => FileKeyProvider(keyPath()).loadKey(),
        throwsA(isA<KeyUnavailableError>()),
      );
    });

    test(
      'replaceKey requires the current key and verifies the new one',
      () async {
        final provider = FileKeyProvider(keyPath());
        final current = await provider.getOrCreateKey();
        final replacement = Uint8List.fromList(List.filled(32, 9));

        expect(
          () =>
              provider.replaceKey(replacement, expectedCurrent: Uint8List(32)),
          throwsA(isA<KeyUnavailableError>()),
        );
        expect(
          await provider.loadKey(),
          current,
          reason: 'unchanged on refusal',
        );

        await provider.replaceKey(replacement, expectedCurrent: current);
        expect(await provider.loadKey(), replacement);
      },
    );

    test('deleteKey removes only the exact expected key', () async {
      final provider = FileKeyProvider(keyPath());
      final key = await provider.getOrCreateKey();

      expect(
        () => provider.deleteKey(expectedCurrent: Uint8List(32)),
        throwsA(isA<KeyUnavailableError>()),
      );
      expect(await provider.loadKey(), key);

      await provider.deleteKey(expectedCurrent: key);
      expect(await provider.loadKey(), isNull);
    });

    test('concurrent creators all end up with one key', () async {
      // The desktop app hit this for real: two processes racing between the
      // existence check and the write each generated a key, and the loser's
      // data became unreadable.
      final results = await Future.wait([
        for (var i = 0; i < 16; i++)
          FileKeyProvider(keyPath()).getOrCreateKey(),
      ]);

      for (final key in results) {
        expect(key, results.first, reason: 'every caller must see one key');
      }
    });
  });

  group('SecureStorageKeyProvider', () {
    test('round-trips through the platform store', () async {
      final storage = _FakeSecureStorage();
      final key = await SecureStorageKeyProvider(storage: storage)
          .getOrCreateKey();

      final reopened = await SecureStorageKeyProvider(storage: storage)
          .loadKey();
      expect(reopened, key);
    });

    test('reports an unavailable store instead of failing at write', () async {
      final provider = SecureStorageKeyProvider(
        storage: _FakeSecureStorage(available: false),
      );
      expect(await provider.isAvailable(), isFalse);
    });

    test('a corrupt stored value is reported', () async {
      final storage = _FakeSecureStorage();
      final provider = SecureStorageKeyProvider(storage: storage);
      storage.entries[provider.entryKey] = 'not base64 !!';

      expect(provider.loadKey(), throwsA(isA<KeyUnavailableError>()));
    });

    test('a stored value of the wrong length is reported', () async {
      final storage = _FakeSecureStorage();
      final provider = SecureStorageKeyProvider(storage: storage);
      storage.entries[provider.entryKey] = base64.encode(List.filled(16, 1));

      expect(provider.loadKey(), throwsA(isA<KeyUnavailableError>()));
    });

    test('refuses to overwrite a different existing key', () async {
      final storage = _FakeSecureStorage();
      final provider = SecureStorageKeyProvider(storage: storage);
      await provider.getOrCreateKey();

      expect(
        () => provider.storeKey(Uint8List(32)),
        throwsA(isA<KeyUnavailableError>()),
      );
    });
  });

  group('MigratingKeyProvider', () {
    test(
      'moves a legacy file key into the secure store, then removes it',
      () async {
        final fallback = FileKeyProvider(keyPath());
        final legacy = await fallback.getOrCreateKey();

        final storage = _FakeSecureStorage();
        final migrating = MigratingKeyProvider(
          SecureStorageKeyProvider(storage: storage),
          fallback,
          const KeyProtectionStatus('Android Keystore', true),
        );

        expect(await migrating.loadKey(), legacy);
        expect(
          await File(keyPath()).exists(),
          isFalse,
          reason: 'the legacy file is removed only after the move is verified',
        );
        expect(
          await SecureStorageKeyProvider(storage: storage).loadKey(),
          legacy,
        );
      },
    );

    test(
      'keeps the legacy file when the secure store cannot confirm the move',
      () async {
        final fallback = FileKeyProvider(keyPath());
        await fallback.getOrCreateKey();

        final migrating = MigratingKeyProvider(
          SecureStorageKeyProvider(
            storage: _FakeSecureStorage(available: false),
          ),
          fallback,
          const KeyProtectionStatus('Android Keystore', true),
        );

        expect(migrating.loadKey(), throwsA(isA<KeyUnavailableError>()));
        expect(
          await File(keyPath()).exists(),
          isTrue,
          reason: 'the only copy of the key must survive a failed move',
        );
      },
    );

    test(
      'falls back to the file provider when there is no secure store',
      () async {
        final fallback = FileKeyProvider(keyPath());
        final migrating = MigratingKeyProvider(
          null,
          fallback,
          const KeyProtectionStatus('owner-only file', false, 'no store'),
        );

        final key = await migrating.getOrCreateKey();
        expect(await fallback.loadKey(), key);
        expect(migrating.status.secureStore, isFalse);
        expect(migrating.status.warning, isNotNull);
      },
    );
  });
}
