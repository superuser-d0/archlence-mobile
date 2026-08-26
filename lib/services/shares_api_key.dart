/// Where the user's own share-price API key is kept.
///
/// THE ONE CREDENTIAL THIS APP HOLDS THAT IS NOT ITS OWN. Everything else in
/// the price layer is keyless by decision — see `docs/ROADMAP.md` ->
/// "Prices come from the phone, from keyless sources". Shares are the
/// exception the decision names: BIST data is commercial, no free source
/// exists to ship, and the only way to price a share without putting a shared
/// key in the APK (where anyone could read it) is for the person who wants it
/// to bring their own.
///
/// The platform secure store, beside the screen-lock and language
/// preferences, for the reason `screen_lock.dart` gives at length:
/// `finance.db`'s schema is a contract shared with the desktop app, and this
/// is neither financial data nor something a backup should carry to another
/// device. A restored backup does NOT bring someone's API key with it, which
/// is correct — the key belongs to a person and a plan, not to the data.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SharesApiKey {
  SharesApiKey({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _entryKey = 'archlence.shares-api-key';

  final FlutterSecureStorage _storage;

  /// The stored key, or null when there is none.
  ///
  /// Whitespace-only reads as null: a key pasted with a stray newline and
  /// then trimmed to nothing is the same as no key, and it must not produce
  /// a request carrying an empty credential.
  ///
  /// A storage failure reads as null rather than throwing, matching
  /// `ScreenLock.isEnabled`: the price layer treats "no key" as "shares stay
  /// at cost", which is a working app, where an exception here would take
  /// the whole Assets tab down over a preference.
  Future<String?> read() async {
    final String? value;
    try {
      value = await _storage.read(key: _entryKey);
    } on Exception {
      return null;
    }
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Stores [key], or removes it when [key] is null or blank.
  Future<void> write(String? key) {
    final trimmed = key?.trim();
    return _storage.write(
      key: _entryKey,
      value: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
  }
}
