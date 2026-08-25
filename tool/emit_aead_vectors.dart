// Emits envelopes for the desktop app to verify it can read what the phone
// writes. Run: dart run tool/emit_aead_vectors.dart
import 'dart:convert';

import 'package:archlence_mobile/crypto/aead_crypto.dart';

Future<void> main() async {
  const samples = <String>[
    '',
    '0.00',
    '-22131.50',
    'Nakit Cüzdanım',
    'İĞÜŞÖÇ ığüşöç',
    '😀 emoji ve çok baytlı karakterler',
    '{"json":"payload","amount":"334401.80"}',
    'line1\nline2\ttab',
  ];
  for (final text in samples) {
    final key = generateKey();
    final token = await encrypt(text, key);
    print(
      [base64.encode(key), token, base64.encode(utf8.encode(text))].join('|'),
    );
  }
  // A deliberately long one, kept out of the literal list for readability.
  final key = generateKey();
  final long = 'a' * 5000;
  print(
    [
      base64.encode(key),
      await encrypt(long, key),
      base64.encode(utf8.encode(long)),
    ].join('|'),
  );
}
