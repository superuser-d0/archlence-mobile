/// What can go wrong with a backup, kept apart because the three cases send a
/// user to three different places.
library;

/// The file is not a backup this app can read.
///
/// Covers everything structural: a package that broke one of the bounds, a
/// metadata field of the wrong shape, a database whose hash does not match,
/// a key that does not open the data it travels with. From the user's side
/// they are one thing — this file cannot be used — and the message says which.
class BackupFormatError implements Exception {
  const BackupFormatError(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatError: $message';
}

/// The passphrase does not open this package.
///
/// Distinct from [BackupFormatError] ON PURPOSE. "You mistyped" and "this file
/// is not a backup" send a user to different places, and collapsing them tells
/// someone to go hunting for a corrupt file when they simply typed the wrong
/// thing.
class WrongPassphraseError implements Exception {
  const WrongPassphraseError();

  @override
  String toString() => 'WrongPassphraseError';
}

/// A restore failed and the previous data was put back.
///
/// The message a user reads after this one has to say BOTH halves. "Restore
/// failed" alone leaves them believing their data is gone, which is the
/// opposite of what the rollback just guaranteed.
class RestoreFailedError implements Exception {
  const RestoreFailedError(this.message, [this.cause]);

  final String message;

  /// What actually went wrong, kept for the log rather than the screen.
  final Object? cause;

  @override
  String toString() =>
      'RestoreFailedError: $message${cause == null ? '' : ' ($cause)'}';
}

/// A half-finished restore was found and could not be undone.
///
/// FAIL-CLOSED, and deliberately not the same as [RestoreFailedError]: this
/// one means the profile may be mixed and nothing here can fix it. Starting
/// anyway, on the assumption that everything is fine, is worse than refusing.
class InterruptedRestoreError implements Exception {
  const InterruptedRestoreError(this.message);

  final String message;

  @override
  String toString() => 'InterruptedRestoreError: $message';
}
