/// A [KeyProvider] that serves one fixed key, standing in for the platform
/// store.
///
/// The real providers need Android's Keystore or a file on disk; neither is
/// what a service test is trying to prove. Tests that care about the key
/// store itself use the device test instead.
library;

import 'dart:typed_data';

import 'package:archlence_mobile/crypto/key_provider.dart';

class FixedKeyProvider implements KeyProvider {
  FixedKeyProvider(this.key);

  /// A key of the right length whose bytes are arbitrary. Anything that
  /// depends on the VALUE of the key belongs in a vector test, which reads
  /// the key the desktop used.
  FixedKeyProvider.arbitrary()
    : key = Uint8List.fromList(List<int>.generate(32, (index) => index));

  final Uint8List key;

  @override
  Future<Uint8List?> loadKey() async => key;

  @override
  Future<Uint8List> getOrCreateKey() async => key;

  @override
  Future<void> storeKey(List<int> key) async {}

  @override
  Future<void> replaceKey(
    List<int> key, {
    required List<int> expectedCurrent,
  }) async {}

  @override
  Future<void> deleteKey({required List<int> expectedCurrent}) async {}
}
