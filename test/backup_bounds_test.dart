/// What a backup file is not allowed to make this app do.
///
/// **A BACKUP FILE IS UNTRUSTED INPUT.** It comes from the user's storage, a
/// cloud folder or a chat app, and by the time the code in `stagePackage`
/// looks at it nothing about it has been proven. Every test here is a
/// hostile file, built here rather than described, and the assertion is that
/// it is refused before it costs anything.
///
/// The tests were checked for teeth by removing each bound in turn and
/// requiring the matching test to fail; see the notes at the two that needed
/// changing as a result.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:archlence_mobile/backup/backup_errors.dart';
import 'package:archlence_mobile/backup/backup_package.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory workspace;
  late Directory staging;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('bounds-');
    staging = Directory(p.join(workspace.path, 'staged'));
  });

  tearDown(() => workspace.delete(recursive: true));

  /// Writes [archive] as a ZIP in the workspace and returns it.
  File pack(Archive archive, {String name = 'hostile.zip'}) {
    final bytes = ZipEncoder().encode(archive);
    final file = File(p.join(workspace.path, name));
    file.writeAsBytesSync(bytes);
    return file;
  }

  /// The three members a package must have, with plausible contents.
  Archive wellFormed() => Archive()
    ..add(ArchiveFile.bytes(databaseMember, utf8.encode('SQLite format 3\u0000')))
    ..add(ArchiveFile.string(metadataMember, '{"format_version":2}'))
    ..add(ArchiveFile.string(recoveryMember, '{"kdf":"PBKDF2-HMAC-SHA256"}'));

  Matcher throwsBackupFormatError([String? containing]) => throwsA(
    containing == null
        ? isA<BackupFormatError>()
        : isA<BackupFormatError>().having(
            (e) => e.message,
            'message',
            contains(containing),
          ),
  );

  test('a well-formed package stages, so the rejections mean something', () async {
    // The control. Without it every test below would pass on a staging
    // function that refused everything.
    final members = await stagePackage(pack(wellFormed()), staging);

    expect(members.toSet(), requiredMembers.toSet());
    expect(
      staging.listSync().map((e) => p.basename(e.path)).toSet(),
      requiredMembers.toSet(),
    );
  });

  group('the shape of the package', () {
    test('more members than a backup has', () async {
      final archive = wellFormed()
        ..add(ArchiveFile.string(configMember, '{}'))
        ..add(ArchiveFile.string('readme.txt', 'hello'));

      await expectLater(
        stagePackage(pack(archive), staging),
        throwsBackupFormatError('more files'),
      );
    });

    test('a member the format does not have', () async {
      final archive = wellFormed()..add(ArchiveFile.string('notes.txt', 'x'));

      await expectLater(
        stagePackage(pack(archive), staging),
        throwsBackupFormatError('unexpected file'),
      );
    });

    test('a member the format requires, missing', () async {
      final archive = Archive()
        ..add(ArchiveFile.string(metadataMember, '{}'))
        ..add(ArchiveFile.string(recoveryMember, '{}'));

      await expectLater(
        stagePackage(pack(archive), staging),
        throwsBackupFormatError('missing a file'),
      );
    });

    test('a member of an allowed name, MARKED as a directory', () async {
      // An entry named `config.json/` would be refused by the allowed-names
      // check long before anything looked at what kind of entry it is. The
      // reachable shape is the one with a legal name and S_IFDIR in its
      // attributes, and it is the shape that matters: a reader that honoured
      // it would create a DIRECTORY where the settings file goes.
      final archive = wellFormed()
        ..add(ArchiveFile.string(configMember, '{}'));
      archive.files.firstWhere((file) => file.name == configMember).mode =
          0x41FF;

      await expectLater(
        stagePackage(pack(archive), staging),
        throwsBackupFormatError('directory entry'),
      );
    });

    test('a symbolic link', () async {
      // S_IFLNK in the high half of the external attributes. Extracting it
      // would write a link, and the next member written through that name
      // would land wherever the link pointed.
      final archive = wellFormed();
      archive.files
              .firstWhere((file) => file.name == metadataMember)
              .mode =
          0xA1FF;

      await expectLater(
        stagePackage(pack(archive), staging),
        throwsBackupFormatError('symbolic link'),
      );
    });

    test('a member marked encrypted', () async {
      final file = pack(wellFormed());
      // Bit 0 of the general-purpose flag, set in the central directory.
      // Nothing this app writes is encrypted at the ZIP level, and the format
      // has no second password to ask for.
      _patchCentralDirectory(file, (bytes, offset) {
        bytes.buffer.asByteData().setUint16(offset + 8, 0x1, Endian.little);
      });

      await expectLater(
        stagePackage(file, staging),
        throwsBackupFormatError('encrypted'),
      );
    });
  });

  group('the size of the package', () {
    test('a member larger than its limit is refused end to end', () async {
      // Incompressible, so the ratio check is not what refuses it.
      final archive = wellFormed()
        ..add(
          ArchiveFile.bytes(
            configMember,
            _incompressible(maxSmallMemberBytes + 1024),
          ),
        );

      await expectLater(
        stagePackage(pack(archive), staging),
        throwsBackupFormatError('too large'),
      );
    });

    test('...and refused from the HEADER, before anything is decompressed', () {
      // The test above passes with the header check removed, because the
      // counter in the staging loop catches the same file a moment later.
      // That is two layers doing their job and one test that cannot tell them
      // apart — so the pre-extraction gate is exercised on its own here.
      //
      // Which layer refuses it is not a detail. This one decides from the
      // central directory alone, so a member claiming 250 MB is never
      // decompressed at all; the other one finds out by decompressing it.
      final headers = [
        for (final name in requiredMembers)
          ZipFileHeader()
            ..filename = name
            ..compressedSize = 100
            ..uncompressedSize = 1000,
      ];
      expect(() => rejectUnsafeMembers(headers), returnsNormally);

      headers.add(
        ZipFileHeader()
          ..filename = configMember
          ..compressedSize = maxSmallMemberBytes
          ..uncompressedSize = maxSmallMemberBytes + 1,
      );
      expect(() => rejectUnsafeMembers(headers), throwsBackupFormatError('too large'));
    });

    test('a member that expands further than a backup does', () async {
      final archive = Archive()
        ..add(ArchiveFile.bytes(databaseMember, utf8.encode('SQLite format 3')))
        ..add(ArchiveFile.bytes(metadataMember, Uint8List(3 * 1024 * 1024)))
        ..add(ArchiveFile.string(recoveryMember, '{}'));

      await expectLater(
        stagePackage(pack(archive), staging),
        throwsBackupFormatError('expands further'),
      );
    });

    test('a header that LIES about how large its member is', () async {
      // The bound above reads the size a member DECLARES, and the declaration
      // is written by whoever built the file. So the decompressed bytes are
      // counted as they arrive, and this is the test that the second counter
      // exists: five megabytes of member, declared as five kilobytes.
      final archive = Archive()
        ..add(ArchiveFile.bytes(databaseMember, utf8.encode('SQLite format 3')))
        ..add(ArchiveFile.bytes(metadataMember, Uint8List(5 * 1024 * 1024)))
        ..add(ArchiveFile.string(recoveryMember, '{}'));
      final file = pack(archive);

      _patchCentralDirectory(file, (bytes, offset) {
        final view = bytes.buffer.asByteData();
        final nameLength = view.getUint16(offset + 28, Endian.little);
        final name = utf8.decode(
          bytes.sublist(offset + 46, offset + 46 + nameLength),
        );
        if (name != metadataMember) return;
        // Only the DECLARED uncompressed size is changed. The compressed
        // stream is left whole, so the ratio it declares — five kilobytes out
        // of the five kilobytes it really occupies — is about one. Under the
        // limit, under the ratio ceiling: nothing a header can say gives it
        // away, and only counting what comes out does.
        view.setUint32(offset + 24, 5000, Endian.little);
      });

      await expectLater(
        stagePackage(file, staging),
        throwsBackupFormatError('too large'),
      );
    });
  });

  group('the file itself', () {
    test('something that is not a ZIP at all', () async {
      final file = File(p.join(workspace.path, 'not-a-zip'))
        ..writeAsStringSync('this is a text file');

      await expectLater(
        stagePackage(file, staging),
        throwsBackupFormatError('could not be opened'),
      );
    });

    test('a truncated package', () async {
      final file = pack(wellFormed());
      final bytes = file.readAsBytesSync();
      file.writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 2));

      // Cutting the tail off takes the central directory with it, so the
      // reader finds no members rather than throwing. That is its own case:
      // a package with nothing in it is not a package.
      await expectLater(
        stagePackage(file, staging),
        throwsBackupFormatError('could not be opened'),
      );
    });

    test('a member whose compressed data is damaged', () async {
      // The case the test above does NOT cover: the reader gets far enough
      // to inflate, and the damage does not stop it. Deflate is not
      // self-checking — decoding arbitrary bits mostly yields arbitrary
      // bytes rather than an error — so what refuses this file is the CRC the
      // package declares for the member, checked against what came out.
      //
      // Measured while writing the test: with no CRC check the package
      // staged CLEANLY, and `config.json` landed as 64 KB of garbage.
      final archive = wellFormed()
        ..add(ArchiveFile.bytes(configMember, _semiCompressible(64 * 1024)));
      final file = pack(archive);
      _damageCompressedData(file, configMember);

      await expectLater(
        stagePackage(file, staging),
        throwsBackupFormatError('damaged'),
      );
    });

    test('an empty file', () async {
      final file = File(p.join(workspace.path, 'empty'))..writeAsBytesSync([]);

      await expectLater(
        stagePackage(file, staging),
        throwsBackupFormatError('could not be opened'),
      );
    });
  });

  test('no corruption of a package escapes as anything but a backup error', () async {
    // The reason `stagePackage` catches everything rather than a named list
    // of exceptions. A ZIP reader handed a mangled file can throw a range
    // error off the end of a truncated structure, a format error out of
    // zlib, or an OS error — and a caller that catches only
    // BackupFormatError would see any of those as a crash.
    //
    // Rather than engineering one input per exception type, this corrupts a
    // valid package in 400 different ways and requires the same answer every
    // time. The seed is fixed, so a failure is reproducible; the assertion is
    // deliberately weak — SUCCEEDING is allowed, since flipping a byte in a
    // member's payload need not make the package invalid — and what is not
    // allowed is any other exception reaching the caller.
    final valid = pack(
      wellFormed()..add(ArchiveFile.bytes(configMember, _semiCompressible(2048))),
    ).readAsBytesSync();

    var random = 0x1234567;
    int next(int bound) {
      random ^= (random << 13) & 0xFFFFFFFF;
      random ^= random >> 17;
      random ^= (random << 5) & 0xFFFFFFFF;
      return random % bound;
    }

    for (var attempt = 0; attempt < 400; attempt++) {
      final mangled = Uint8List.fromList(valid);
      for (var flip = 0; flip < 1 + next(4); flip++) {
        mangled[next(mangled.length)] ^= 1 << next(8);
      }
      final file = File(p.join(workspace.path, 'fuzz.zip'))
        ..writeAsBytesSync(mangled);
      final target = Directory(p.join(workspace.path, 'fuzz-$attempt'));

      try {
        await stagePackage(file, target);
      } on BackupFormatError {
        // The only failure a package is allowed to produce.
      } on Object catch (error, stack) {
        fail('attempt $attempt escaped as ${error.runtimeType}: $error\n$stack');
      }
    }
  });

  group('member names that would write outside the staging directory', () {
    // These cannot be reached through `stagePackage`: the allowed-names check
    // runs first and rejects `../finance.db` as an unexpected file long
    // before any path is built from it. That is the point — the name check is
    // the SECOND line, kept because the first one is a list that could grow.
    // So it is tested where it can be reached.
    test('a POSIX traversal', () {
      expect(() => requirePlainMemberName('../finance.db'), throwsBackupFormatError());
      expect(() => requirePlainMemberName('a/finance.db'), throwsBackupFormatError());
      expect(() => requirePlainMemberName('/etc/passwd'), throwsBackupFormatError());
    });

    test('a Windows traversal, on a platform with no backslash separator', () {
      // `..\finance.db` is a plain file name to every POSIX path API, so a
      // check that asked the path library would take it for one and write a
      // file with a backslash in its name — which is a traversal on the phone
      // the package is later moved to.
      expect(p.basename(r'..\finance.db'), r'..\finance.db');
      expect(() => requirePlainMemberName(r'..\finance.db'), throwsBackupFormatError());
      expect(() => requirePlainMemberName(r'C:\finance.db'), throwsBackupFormatError());
    });

    test('the names a backup really has are accepted', () {
      for (final name in allowedMembers) {
        expect(() => requirePlainMemberName(name), returnsNormally);
      }
    });
  });

  group('metadata the format does not allow', () {
    test('a root that is not an object', () {
      final file = File(p.join(workspace.path, 'array.json'))
        ..writeAsStringSync('[]');

      // Measured on the desktop: this used to reach a field access and fail
      // with a type error rather than as a bad backup. The root type has to
      // be the first thing tested.
      expect(() => readJsonObject(file, 'metadata'), throwsBackupFormatError());
    });

    test('a digest that is not one', () {
      expect(() => requireHexDigest(null, 'x'), throwsBackupFormatError());
      expect(() => requireHexDigest('abc', 'x'), throwsBackupFormatError());
      expect(() => requireHexDigest('A' * 64, 'x'), throwsBackupFormatError());
      expect(() => requireHexDigest('g' * 64, 'x'), throwsBackupFormatError());
      expect(requireHexDigest('a' * 64, 'x'), 'a' * 64);
    });

    test('a record count that is not a count', () {
      expect(() => requireRecordCount('7'), throwsBackupFormatError());
      expect(() => requireRecordCount(-1), throwsBackupFormatError());
      expect(() => requireRecordCount(null), throwsBackupFormatError());
      expect(requireRecordCount(0), 0);
    });
  });
}

/// Bytes deflate really does compress, but only about twofold — so the member
/// is genuinely DEFLATED (incompressible input gets stored instead, and a
/// stored member has no stream to damage) while staying under the ratio
/// ceiling.
Uint8List _semiCompressible(int length) {
  final bytes = _incompressible(length);
  for (var i = 0; i < length; i++) {
    bytes[i] &= 0x0F;
  }
  return bytes;
}

/// Bytes that deflate cannot shrink, so a size test is not a ratio test.
Uint8List _incompressible(int length) {
  final bytes = Uint8List(length);
  var state = 0x2545F491;
  for (var i = 0; i < length; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    bytes[i] = state & 0xFF;
  }
  return bytes;
}

/// Flips bytes inside one member's DEFLATE stream, leaving every header the
/// reader looks at intact.
void _damageCompressedData(File file, String member) {
  final bytes = file.readAsBytesSync();
  final view = bytes.buffer.asByteData();
  var localHeaderOffset = -1;
  var compressedSize = 0;
  for (var offset = 0; offset + 4 <= bytes.length; offset++) {
    if (view.getUint32(offset, Endian.little) != 0x02014b50) continue;
    final nameLength = view.getUint16(offset + 28, Endian.little);
    final name = utf8.decode(bytes.sublist(offset + 46, offset + 46 + nameLength));
    if (name != member) continue;
    compressedSize = view.getUint32(offset + 20, Endian.little);
    localHeaderOffset = view.getUint32(offset + 42, Endian.little);
  }
  expect(localHeaderOffset, isNonNegative, reason: 'member not found');

  final dataStart =
      localHeaderOffset +
      30 +
      view.getUint16(localHeaderOffset + 26, Endian.little) +
      view.getUint16(localHeaderOffset + 28, Endian.little);
  // Well inside the stream: the first bytes carry the block header, and
  // damaging those could look like a different failure.
  for (var i = compressedSize ~/ 3; i < compressedSize ~/ 3 + 32; i++) {
    bytes[dataStart + i] ^= 0xFF;
  }
  file.writeAsBytesSync(bytes);
}

/// Calls [patch] at the offset of every central-directory header in [file].
///
/// The central directory is what `stagePackage` reads to decide whether to
/// extract anything, so it is where a hostile file would put its lies.
void _patchCentralDirectory(File file, void Function(Uint8List, int) patch) {
  final bytes = file.readAsBytesSync();
  final view = bytes.buffer.asByteData();
  for (var offset = 0; offset + 4 <= bytes.length; offset++) {
    if (view.getUint32(offset, Endian.little) == 0x02014b50) {
      patch(bytes, offset);
    }
  }
  file.writeAsBytesSync(bytes);
}
