/// When the app is allowed to say "you have not backed up".
///
/// The rules here are small and every one of them is a wrong answer waiting
/// to happen: a phone whose clock moved backwards, a store that throws, a
/// value written by a version that stored something else.
library;

import 'package:archlence_mobile/services/backup_reminder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// An in-memory stand-in, and one that can be told to fail.
class _FakeStore implements FlutterSecureStorage {
  _FakeStore({this.throws = false});

  final Map<String, String> values = {};
  bool throws;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throws) throw const FormatException('store unavailable');
    return values[key];
  }

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
    if (throws) throw const FormatException('store unavailable');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

void main() {
  late _FakeStore store;
  var now = DateTime(2026, 8, 29, 12);

  BackupReminder reminder() =>
      BackupReminder(storage: store, now: () => now);

  setUp(() {
    store = _FakeStore();
    now = DateTime(2026, 8, 29, 12);
  });

  test('a phone that has never backed up is stale, and says so', () async {
    expect(await reminder().lastBackupAt(), isNull);
    expect(await reminder().daysSinceBackup(), isNull);
    expect(await reminder().isStale(), isTrue);
  });

  test('a backup just written is neither stale nor a day old', () async {
    await reminder().recordBackup();

    expect(await reminder().daysSinceBackup(), 0);
    expect(await reminder().isStale(), isFalse);
  });

  test('it goes stale on the thirtieth day, not the twenty-ninth', () async {
    await reminder().recordBackup();

    now = now.add(const Duration(days: 29));
    expect(await reminder().daysSinceBackup(), 29);
    expect(await reminder().isStale(), isFalse);

    now = now.add(const Duration(days: 1));
    expect(await reminder().daysSinceBackup(), 30);
    expect(await reminder().isStale(), isTrue);
  });

  test('a clock that moved backwards reads as today, never as negative', () async {
    await reminder().recordBackup();
    now = now.subtract(const Duration(days: 3));

    // "Last backup -3 days ago" is worse than being a little wrong about
    // which day it was, and a negative age would also read as not stale by
    // accident rather than by decision.
    expect(await reminder().daysSinceBackup(), 0);
    expect(await reminder().isStale(), isFalse);
  });

  test('a value that is not a date reads as never', () async {
    store.values['archlence.last-backup-at'] = 'the day before yesterday';

    expect(await reminder().lastBackupAt(), isNull);
    expect(await reminder().isStale(), isTrue);
  });

  test('a store that throws reads as never rather than taking a screen down', () async {
    store.throws = true;

    expect(await reminder().lastBackupAt(), isNull);
    expect(await reminder().isStale(), isTrue);
  });

  test('a store that throws does not fail the backup that succeeded', () async {
    store.throws = true;

    // The package is already written and on its way to the share sheet by the
    // time this is called. Losing the timestamp costs one unnecessary
    // reminder; throwing here would report a successful backup as a failure.
    await expectLater(reminder().recordBackup(), completes);
  });

  test('the timestamp is stored in UTC and read back in local time', () async {
    await reminder().recordBackup();

    final stored = store.values['archlence.last-backup-at']!;
    expect(stored.endsWith('Z'), isTrue, reason: 'stored as UTC: $stored');
    // A phone that changes time zone must not gain or lose a day because of
    // it, which is what storing a local timestamp would do.
    expect((await reminder().lastBackupAt())!.isUtc, isFalse);
    expect(await reminder().daysSinceBackup(), 0);
  });
}
