/// When a backup was last written, and whether it is time to say something.
///
/// **The gap this closes is the app's largest structural risk.** There is no
/// account and no server, by decision — so nobody else holds a copy of the
/// data, and a lost phone is a lost financial history. Onboarding says this,
/// in the third card, at the one moment the user has nothing to lose yet.
/// Nothing said it again afterwards.
///
/// That is the difference between a principle and a trap. "Your data is
/// yours" is only honest if the app helps the person act on it, and every
/// competitor's cloud sync is a safety net this one deliberately does not
/// have.
///
/// Kept in the platform secure store beside the screen-lock and language
/// preferences rather than in `finance.db`, for the reason `screen_lock.dart`
/// gives at length: the schema is a contract shared with the desktop app.
/// It also means a RESTORED backup does not bring a stale timestamp with it,
/// which is right — the reminder is about this phone.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BackupReminder {
  BackupReminder({FlutterSecureStorage? storage, DateTime Function()? now})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // `resetOnError: false`; see `SecureStorageKeyProvider`. These
            // entries share one store with the encryption key.
            aOptions: AndroidOptions(resetOnError: false),
          ),
      _now = now ?? DateTime.now;

  static const _entryKey = 'archlence.last-backup-at';

  /// How long a backup stays fresh before the app says anything.
  ///
  /// Thirty days rather than a week: a nudge that appears constantly is one
  /// a user learns to ignore, and this one has to still be read in a year.
  static const staleAfter = Duration(days: 30);

  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  /// When a backup was last written on this phone, or null if none ever was.
  ///
  /// A storage failure, or a value this cannot parse, both read as null —
  /// matching `ScreenLock.isEnabled` and `SharesApiKey.read`. The worst a
  /// wrong answer here can do is show a reminder that was not needed, and
  /// the alternative is an exception taking down a screen over a hint.
  Future<DateTime?> lastBackupAt() async {
    final String? value;
    try {
      value = await _storage.read(key: _entryKey);
    } on Object {
      return null;
    }
    if (value == null) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  /// Records that a backup was just written. Never throws for the same
  /// reason: failing to remember must not fail the backup that succeeded.
  Future<void> recordBackup() async {
    try {
      await _storage.write(
        key: _entryKey,
        value: _now().toUtc().toIso8601String(),
      );
    } on Object {
      // Ignored deliberately. The package is already on its way to the share
      // sheet; losing the timestamp costs an unnecessary reminder later.
    }
  }

  /// Full days since the last backup, or null when there has never been one.
  ///
  /// A timestamp in the FUTURE — a phone whose clock moved backwards — reads
  /// as zero rather than as a negative age, because "you backed up in -3
  /// days" is worse than saying it happened today.
  Future<int?> daysSinceBackup() async {
    final last = await lastBackupAt();
    if (last == null) return null;
    final days = _now().difference(last).inDays;
    return days < 0 ? 0 : days;
  }

  /// Whether the app should say something about backing up.
  ///
  /// True when there has never been one, or the last was longer ago than
  /// [staleAfter]. The caller decides whether there is anything worth backing
  /// up — a reminder on an empty install is a nag about nothing.
  Future<bool> isStale() async {
    final days = await daysSinceBackup();
    if (days == null) return true;
    return days >= staleAfter.inDays;
  }
}
