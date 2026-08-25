/// Stand-ins for the platform secure store and the biometric prompt.
///
/// A widget test has no platform behind `flutter_secure_storage` or
/// `local_auth`, so without these the lock's explanatory text — the part that
/// says what it does NOT buy — would only ever render on a real device and
/// go untested on the path users read.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/types/auth_messages.dart';

/// An in-memory stand-in for the platform secure store and the biometric
/// prompt, so a widget test can drive both.
class FakeSecureStorage extends FlutterSecureStorage {
  const FakeSecureStorage(this._values);

  final Map<String, String> _values;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

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
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }
}

class FakePlatformAuth implements LocalAuthentication {
  FakePlatformAuth();

  bool supported = true;
  bool passes = true;
  int prompts = 0;

  /// What the last prompt asked for. Recorded because `biometricOnly: true`
  /// would lock out anyone with no fingerprint enrolled, and that is
  /// invisible unless the call itself is inspected.
  bool? lastBiometricOnly;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    prompts++;
    lastBiometricOnly = biometricOnly;
    return passes;
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => const [];

  @override
  Future<bool> get canCheckBiometrics async => supported;

  @override
  Future<bool> stopAuthentication() async => true;
}

class ThrowingSecureStorage extends FlutterSecureStorage {
  const ThrowingSecureStorage();

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw const FormatException('unreadable');
}
