/// The AEAD encryption core: versioned, authenticated AES-256-GCM.
///
/// A port of the desktop app's `utils/aead_crypto.py`, and wire-compatible
/// with it — a database or backup written by one must be readable by the
/// other, so the envelope layout below is a fixed format, not an
/// implementation detail.
///
/// There is NO fail-open. Every failure raises [DecryptionError]; a value
/// that cannot be authenticated is never quietly replaced with a blank or a
/// zero. The caller decides what to do about it.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Decryption failed: wrong key, corrupt or tampered data, or an
/// unrecognised version or algorithm.
class DecryptionError implements Exception {
  const DecryptionError(this.message);

  final String message;

  @override
  String toString() => 'DecryptionError: $message';
}

const int _version = 1;
const int _algoAes256Gcm = 1;
const int _headerLen = 2; // version + algo id
const int _nonceLen = 12;
const int _tagLen = 16;
const int _keyLen = 32; // AES-256

final AesGcm _aesGcm = AesGcm.with256bits();
final Random _random = Random.secure();

void _requireKeyLength(List<int> key) {
  if (key.length != _keyLen) {
    throw ArgumentError('Key must be $_keyLen bytes, got ${key.length}.');
  }
}

Uint8List _randomBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = _random.nextInt(256);
  }
  return bytes;
}

/// Encrypts [plaintext], returning
/// `base64(version | algo | nonce | tag | ciphertext)`.
///
/// The tag sits BEFORE the ciphertext, which is unusual — most layouts append
/// it — but it is what the desktop app writes, and changing it would strand
/// every record already in a user's database.
Future<String> encrypt(String plaintext, List<int> key) async {
  _requireKeyLength(key);

  final nonce = _randomBytes(_nonceLen);
  final secretBox = await _aesGcm.encrypt(
    utf8.encode(plaintext),
    secretKey: SecretKey(key),
    nonce: nonce,
  );

  final envelope = BytesBuilder()
    ..addByte(_version)
    ..addByte(_algoAes256Gcm)
    ..add(nonce)
    ..add(secretBox.mac.bytes)
    ..add(secretBox.cipherText);

  return base64.encode(envelope.takeBytes());
}

/// Unwraps an envelope produced by [encrypt].
///
/// Raises [DecryptionError] on any inconsistency — tampered envelope, wrong
/// key, unrecognised version or algorithm. There is no silent substitute.
Future<String> decrypt(String token, List<int> key) async {
  _requireKeyLength(key);

  final Uint8List envelope;
  try {
    envelope = base64.decode(token);
  } on FormatException catch (e) {
    throw DecryptionError('Invalid base64: ${e.message}');
  }

  if (envelope.length < _headerLen + _nonceLen + _tagLen) {
    throw const DecryptionError(
      'Envelope too short — corrupt or tampered data.',
    );
  }

  final version = envelope[0];
  final algoId = envelope[1];
  if (version != _version) {
    throw DecryptionError('Unknown envelope version: $version');
  }
  if (algoId != _algoAes256Gcm) {
    throw DecryptionError('Unknown algorithm id: $algoId');
  }

  final body = envelope.sublist(_headerLen);
  final nonce = body.sublist(0, _nonceLen);
  final tag = body.sublist(_nonceLen, _nonceLen + _tagLen);
  final ciphertext = body.sublist(_nonceLen + _tagLen);

  final List<int> plaintextBytes;
  try {
    plaintextBytes = await _aesGcm.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
      secretKey: SecretKey(key),
    );
  } on SecretBoxAuthenticationError {
    throw const DecryptionError(
      'Authentication failed — wrong key or tampered data.',
    );
  }

  try {
    return utf8.decode(plaintextBytes);
  } on FormatException catch (e) {
    throw DecryptionError('Decrypted data is not valid UTF-8: ${e.message}');
  }
}

/// A fresh AES-256 key from the platform's secure random source.
Uint8List generateKey() => _randomBytes(_keyLen);
