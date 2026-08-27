/// Runs on a real device or emulator, against the real Android Keystore.
///
/// The unit tests use an in-memory stand-in for the platform store, which
/// proves the logic around it but says nothing about whether the Keystore
/// itself works, survives a reopen, or is reachable at all on this device.
/// Only a test on the device answers that — and it is the one part of the
/// key layer that, if broken, makes every encrypted record unreadable.
///
/// Run: `flutter test integration_test/key_provider_device_test.dart -d DEVICE`
library;

import 'package:archlence_mobile/crypto/aead_crypto.dart' as aead;
import 'package:archlence_mobile/crypto/key_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  const entryKey = 'archlence.test.encryption-key';

  Future<void> clear() => storage.delete(key: entryKey);

  setUp(clear);
  tearDown(clear);

  testWidgets('the platform key store is available on this device', (
    tester,
  ) async {
    final provider = SecureStorageKeyProvider(
      storage: storage,
      entryKey: entryKey,
    );
    expect(await provider.isAvailable(), isTrue);
  });

  testWidgets('a key survives being written and read back through Keystore', (
    tester,
  ) async {
    final provider = SecureStorageKeyProvider(
      storage: storage,
      entryKey: entryKey,
    );

    final created = await provider.getOrCreateKey();
    expect(created, hasLength(32));

    // A separate instance, as a fresh app launch would build.
    final reopened = await SecureStorageKeyProvider(
      storage: storage,
      entryKey: entryKey,
    ).loadKey();
    expect(reopened, created);
  });

  testWidgets('the Keystore key actually decrypts what it encrypted', (
    tester,
  ) async {
    final provider = SecureStorageKeyProvider(
      storage: storage,
      entryKey: entryKey,
    );
    final key = await provider.getOrCreateKey();

    final token = await aead.encrypt('334.401,80 ₺', key);
    final roundTripKey = await SecureStorageKeyProvider(
      storage: storage,
      entryKey: entryKey,
    ).loadKey();

    expect(await aead.decrypt(token, roundTripKey!), '334.401,80 ₺');
  });

  testWidgets('the platform provider chain reports a secure store', (
    tester,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final provider = await createPlatformKeyProvider(directory.path);

    expect(provider.status.secureStore, isTrue);
    // A `KeyProtectionMethod`, not the words 'Android Keystore'. This
    // asserted the string until i18n moved the wording into
    // `settings_screen.dart` — see "Services raise error codes, not
    // sentences" — and it has been failing ever since, unnoticed, because
    // device tests need `-d` and are not part of `flutter test`.
    expect(provider.status.method, KeyProtectionMethod.androidKeystore);
    expect(provider.status.warning, isNull);
  });
}
