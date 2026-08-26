/// Writes a key recovery package with THIS APP's own code, for the desktop
/// to read.
///
/// The other direction of the same proof as `test/desktop_key_recovery.json`:
/// that fixture shows this app reads what the desktop writes, and this shows
/// the desktop reads what this app writes. A format only one side can produce
/// is not a shared format — and for a recovery package that is the whole
/// point, since it exists for the day one of the two is unavailable.
///
/// Run it through `flutter test`, which is the only runner that has the
/// package's Flutter dependencies:
///
///     ARCHLENCE_RECOVERY_OUT=/tmp/mobile-recovery.json \
///         flutter test tool/emit_mobile_recovery.dart
///
/// then read it back with the desktop's own module, from the desktop checkout:
///
///     ./aeadvenv/bin/python tool/emit_recovery_package.py \
///         test/desktop_key_recovery.json --verify /tmp/mobile-recovery.json
///
/// The key and the passphrase match that script's fixed pair, so the desktop
/// checks the exact bytes rather than merely observing that nothing raised.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:archlence_mobile/backup/backup_service.dart';
import 'package:archlence_mobile/backup/key_recovery_service.dart';
import 'package:archlence_mobile/crypto/key_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String passphrase = 'desktop-written-recovery';

/// `bytes(range(32))` — the same key `tool/emit_recovery_package.py` uses.
final Uint8List key = Uint8List.fromList(List<int>.generate(32, (i) => i));

void main() {
  test('emit', () async {
    final out = Platform.environment['ARCHLENCE_RECOVERY_OUT'];
    expect(out, isNotNull, reason: 'set ARCHLENCE_RECOVERY_OUT');

    final directory = await Directory.systemTemp.createTemp('archlence-emit-');
    addTearDown(() => directory.delete(recursive: true));

    final provider = FileKeyProvider(p.join(directory.path, 'encryption.key'));
    await provider.storeKey(key);

    final recovery = KeyRecoveryService(
      databasePath: p.join(directory.path, 'finance.db'),
      keyProvider: provider,
      backup: BackupService(
        databasePath: p.join(directory.path, 'finance.db'),
        keyProvider: provider,
      ),
    );

    final written = await recovery.exportRecoveryPackage(
      File(out!),
      passphrase,
    );
    stdout.writeln('wrote $written');
  });
}
