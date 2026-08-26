/// The passphrase-wrapped copy of the encryption key that travels inside a
/// backup, and the tag that authenticates the package's metadata.
///
/// A port of the corresponding halves of `services/backup_service.py`. THIS
/// IS A WIRE FORMAT, not an implementation detail: a package written by
/// either app must open in the other, so every constant here — the KDF, the
/// round count, the field lengths, the exact JSON the tag is computed over —
/// is fixed by the desktop and not ours to tidy.
///
/// The costs are real and deliberate. PBKDF2 at 600 000 rounds takes seconds
/// on a phone; that is the point of a KDF, and it must not run on the UI
/// isolate.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// The KDF name written into the package. Anything else is refused rather
/// than guessed at.
const String supportedRecoveryKdf = 'PBKDF2-HMAC-SHA256';

/// What this app writes.
const int recoveryIterations = 600000;

/// Bounds on a round count READ FROM A PACKAGE.
///
/// A package is untrusted input. Without a floor, a crafted backup could name
/// one round and have its passphrase brute-forced instantly; without a
/// ceiling, it could name a billion and hang the phone.
const int minRecoveryIterations = 100000;
const int maxRecoveryIterations = 4000000;

const int _saltLength = 16;
const int _nonceLength = 12;
const int _tagLength = 16;
const int _keyLength = 32;

/// Domain separation for the metadata tag, so a key derived for
/// authentication can never be the one that unwraps the encryption key.
final Uint8List authContext = Uint8List.fromList(
  utf8.encode('archlence-backup-auth-v2'),
);

/// The shortest passphrase this app will write or accept.
const int minPassphraseLength = 12;

class BackupFormatError implements Exception {
  const BackupFormatError(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatError: $message';
}

/// Raised when a passphrase does not open a package.
///
/// Distinct from [BackupFormatError] on purpose: "you typed the wrong
/// passphrase" and "this file is not a backup" need different reactions, and
/// collapsing them tells a user to go looking for a corrupt file when they
/// simply mistyped.
class WrongPassphraseError implements Exception {
  const WrongPassphraseError();

  @override
  String toString() => 'WrongPassphraseError';
}

/// The `key.recovery.json` payload.
class RecoveryMaterial {
  const RecoveryMaterial({
    required this.kdf,
    required this.iterations,
    required this.salt,
    required this.nonce,
    required this.tag,
    required this.ciphertext,
  });

  factory RecoveryMaterial.fromJson(Map<String, Object?> json) {
    if (json['kdf'] != supportedRecoveryKdf) {
      throw const BackupFormatError(
        'The backup uses a key-derivation function this app does not support.',
      );
    }
    return RecoveryMaterial(
      kdf: supportedRecoveryKdf,
      iterations: _requireIterations(json['iterations']),
      salt: _requireBytes(json['salt'], _saltLength, 'salt'),
      nonce: _requireBytes(json['nonce'], _nonceLength, 'nonce'),
      tag: _requireBytes(json['tag'], _tagLength, 'tag'),
      ciphertext: _requireBytes(json['ciphertext'], _keyLength, 'ciphertext'),
    );
  }

  final String kdf;
  final int iterations;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List tag;
  final Uint8List ciphertext;

  Map<String, Object?> toJson() => {
    'kdf': kdf,
    'iterations': iterations,
    'salt': base64.encode(salt),
    'nonce': base64.encode(nonce),
    'tag': base64.encode(tag),
    'ciphertext': base64.encode(ciphertext),
  };
}

/// Wraps [key] under [passphrase].
Future<RecoveryMaterial> encryptRecoveryMaterial(
  List<int> key,
  String passphrase, {
  Random? random,
}) async {
  requirePassphrase(passphrase);
  if (key.length != _keyLength) {
    throw const BackupFormatError('The encryption key is not 32 bytes.');
  }
  final source = random ?? Random.secure();
  final salt = Uint8List.fromList(
    List<int>.generate(_saltLength, (_) => source.nextInt(256)),
  );
  final nonce = Uint8List.fromList(
    List<int>.generate(_nonceLength, (_) => source.nextInt(256)),
  );

  final wrapping = await _deriveWrappingKey(
    passphrase,
    salt,
    recoveryIterations,
  );
  final box = await AesGcm.with256bits().encrypt(
    key,
    secretKey: SecretKey(wrapping),
    nonce: nonce,
  );
  return RecoveryMaterial(
    kdf: supportedRecoveryKdf,
    iterations: recoveryIterations,
    salt: salt,
    nonce: nonce,
    tag: Uint8List.fromList(box.mac.bytes),
    ciphertext: Uint8List.fromList(box.cipherText),
  );
}

/// Unwraps the key, or reports which of the two things went wrong.
Future<Uint8List> decryptRecoveryMaterial(
  RecoveryMaterial material,
  String passphrase,
) async {
  requirePassphrase(passphrase);
  final wrapping = await _deriveWrappingKey(
    passphrase,
    material.salt,
    material.iterations,
  );
  try {
    final key = await AesGcm.with256bits().decrypt(
      SecretBox(
        material.ciphertext,
        nonce: material.nonce,
        mac: Mac(material.tag),
      ),
      secretKey: SecretKey(wrapping),
    );
    if (key.length != _keyLength) {
      throw const BackupFormatError('The recovered key is not 32 bytes.');
    }
    return Uint8List.fromList(key);
  } on SecretBoxAuthenticationError {
    // The tag did not verify. Under a KDF-wrapped key that means the
    // passphrase, far more often than a corrupt file.
    throw const WrongPassphraseError();
  }
}

/// The HMAC over a package's metadata.
///
/// The metadata is serialised EXACTLY as Python's
/// `json.dumps(sort_keys=True, separators=(",", ":"))` does — sorted keys, no
/// spaces — because the tag is over those bytes. A different encoder produces
/// a different tag and every package fails to verify.
Future<String> backupAuthTag(
  Map<String, Object?> metadata,
  String passphrase,
) async {
  final material = Map<String, Object?>.from(metadata)
    ..remove('authentication_tag');
  final saltValue = material['authentication_salt'];
  if (saltValue is! String) {
    throw const BackupFormatError('The backup metadata has no salt.');
  }
  final Uint8List salt;
  try {
    salt = base64.decode(saltValue);
  } on FormatException {
    throw const BackupFormatError('The backup metadata salt is not base64.');
  }

  final key =
      await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: recoveryIterations,
        bits: 256,
      ).deriveKeyFromPassword(
        password: passphrase,
        nonce: Uint8List.fromList([...authContext, ...salt]),
      );

  final mac = await Hmac.sha256().calculateMac(
    utf8.encode(canonicalJson(material)),
    secretKey: key,
  );
  return mac.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Python's `json.dumps(sort_keys=True, separators=(",", ":"))`.
///
/// Written out rather than using `jsonEncode`, which does not sort keys. The
/// tag is computed over these exact bytes, so the ordering is part of the
/// wire format.
String canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k as String).toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:'
        '${canonicalJson(value[k])}').join(',')}}';
  }
  if (value is List) {
    return '[${value.map(canonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}

void requirePassphrase(String passphrase) {
  if (passphrase.length < minPassphraseLength) {
    throw const BackupFormatError(
      'A backup passphrase must be at least 12 characters.',
    );
  }
}

Future<Uint8List> _deriveWrappingKey(
  String passphrase,
  Uint8List salt,
  int iterations,
) async {
  final key = await Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: passphrase, nonce: salt);
  return Uint8List.fromList(await key.extractBytes());
}

int _requireIterations(Object? value) {
  // `bool` is not an `int` in Dart, unlike Python — where `True` would pass
  // an isinstance check and be accepted as a single-round KDF. The check is
  // kept anyway so the two implementations reject the same inputs.
  if (value is! int || value is bool) {
    throw const BackupFormatError('The backup round count is not a number.');
  }
  if (value < minRecoveryIterations || value > maxRecoveryIterations) {
    throw const BackupFormatError(
      'The backup round count is outside the supported range.',
    );
  }
  return value;
}

Uint8List _requireBytes(Object? value, int length, String field) {
  if (value is! String) {
    throw BackupFormatError('The backup $field is missing.');
  }
  final Uint8List bytes;
  try {
    bytes = base64.decode(value);
  } on FormatException {
    throw BackupFormatError('The backup $field is not base64.');
  }
  if (bytes.length != length) {
    throw BackupFormatError('The backup $field is the wrong length.');
  }
  return bytes;
}
