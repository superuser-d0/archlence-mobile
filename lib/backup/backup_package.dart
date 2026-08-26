/// The ZIP package a backup travels in, and the bounds it is read under.
///
/// A port of the packaging half of `services/backup_service.py`. The bounds
/// are the security-critical part and they exist for one reason:
///
/// **A BACKUP FILE IS UNTRUSTED INPUT.** It arrives from the user's storage,
/// a cloud folder or a messaging app, and nothing about it has been proven
/// when this code first looks at it. Every limit below is a limit on what a
/// hostile file can make the phone do before it is rejected.
///
/// The member names, the limits and the format version are fixed by the
/// desktop: a package written by either app has to open in the other.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import 'backup_errors.dart';

/// The `format_version` this app writes and the only one it reads.
const int backupFormatVersion = 2;

const String databaseMember = 'finance.db';
const String metadataMember = 'metadata.json';
const String recoveryMember = 'key.recovery.json';
const String configMember = 'config.json';

const List<String> requiredMembers = [
  databaseMember,
  metadataMember,
  recoveryMember,
];
const List<String> optionalMembers = [configMember];
const Set<String> allowedMembers = {...requiredMembers, ...optionalMembers};

/// At most four files, and only the four named above.
const int maxPackageMembers = 4;

/// The database may be large; nothing else in the package has any business
/// being.
const int maxDatabaseMemberBytes = 256 * 1024 * 1024;
const int maxSmallMemberBytes = 4 * 1024 * 1024;
const int maxTotalBytes = maxDatabaseMemberBytes + 3 * maxSmallMemberBytes;

/// The zip-bomb ceiling: a member may not claim to expand more than this.
const int maxCompressionRatio = 200;

/// How much is decompressed before it is handed to the file.
const int _stageChunk = 64 * 1024;

/// How much is read at a time when hashing.
const int _hashChunk = 1024 * 1024;

/// The per-member byte limit.
int memberByteLimit(String name) =>
    name == databaseMember ? maxDatabaseMemberBytes : maxSmallMemberBytes;

/// A member name has to be a plain file name INSIDE the staging directory.
///
/// Both separators are tested. The ZIP standard says `/`, but `\` is also
/// seen in archives produced on Windows, and no POSIX path API treats it as a
/// separator — so a check that only asked the path library would take
/// `..\finance.db` for a plain name on Android and write outside the staging
/// directory.
void requirePlainMemberName(String name) {
  if (name.isEmpty || name == '.' || name == '..') {
    throw const BackupFormatError('The backup contains an unsafe file path.');
  }
  if (name.contains('/') || name.contains('\\')) {
    throw const BackupFormatError('The backup contains an unsafe file path.');
  }
  // A leading separator is caught above; this catches `C:\...`, whose drive
  // letter makes it absolute without either separator appearing first.
  if (name.length >= 2 && name[1] == ':') {
    throw const BackupFormatError('The backup contains an unsafe file path.');
  }
}

/// Everything that can be decided from the central directory alone, decided
/// BEFORE a single byte is decompressed.
///
/// Reading the directory is cheap and reads nothing but headers; decompressing
/// is where a hostile file gets to spend the phone's memory. So every question
/// that a header can answer is answered here.
void rejectUnsafeMembers(List<ZipFileHeader> headers) {
  if (headers.length > maxPackageMembers) {
    throw const BackupFormatError('The backup contains more files than a '
        'backup has.');
  }
  final names = [for (final header in headers) header.filename];
  if (names.toSet().length != names.length) {
    throw const BackupFormatError('The backup contains a duplicate file.');
  }
  final present = names.toSet();
  if (!present.containsAll(requiredMembers)) {
    throw const BackupFormatError('The backup is missing a file it needs.');
  }
  if (present.difference(allowedMembers).isNotEmpty) {
    throw const BackupFormatError('The backup contains an unexpected file.');
  }

  var declaredTotal = 0;
  for (final header in headers) {
    final name = header.filename;
    requirePlainMemberName(name);

    // Three ways an entry says it is a directory, and all three are tested
    // because only the last two are reachable: a name ending in `/` is not
    // one of the allowed names, so the allowed-names check above rejects it
    // first. An entry named exactly `config.json` and MARKED as a directory
    // is what actually gets here.
    if (name.endsWith('/') ||
        (header.externalFileAttributes >> 16) & 0xF000 == 0x4000 ||
        header.externalFileAttributes & 0x10 != 0) {
      throw const BackupFormatError('The backup contains a directory entry.');
    }
    // Bit 0 of the general-purpose flag: the member is encrypted. Nothing
    // this app writes is, and a prompt for a second password would be a
    // prompt for something the format does not have.
    if (header.generalPurposeBitFlag & 0x1 != 0) {
      throw const BackupFormatError('The backup contains an encrypted file.');
    }
    // The UNIX mode lives in the high half of the external attributes.
    // S_IFLNK there means extracting the member would write a symbolic link,
    // and the next step would follow it out of the staging directory.
    if ((header.externalFileAttributes >> 16) & 0xF000 == 0xA000) {
      throw const BackupFormatError('The backup contains a symbolic link.');
    }
    // Deflate is what the desktop writes; stored is what an unsqueezable
    // member ends up as. bzip2 is refused rather than decompressed: the
    // desktop never writes it, and its decoder here has no bounded mode.
    if (header.compressionMethod != 0 && header.compressionMethod != 8) {
      throw const BackupFormatError(
        'The backup uses a compression method this app does not read.',
      );
    }

    final limit = memberByteLimit(name);
    if (header.uncompressedSize > limit) {
      throw const BackupFormatError('A file in the backup is too large.');
    }
    declaredTotal += header.uncompressedSize;
    if (header.compressedSize > 0 &&
        header.uncompressedSize / header.compressedSize > maxCompressionRatio) {
      throw const BackupFormatError(
        'The backup expands further than a real backup does.',
      );
    }
  }
  if (declaredTotal > maxTotalBytes) {
    throw const BackupFormatError('The backup is larger in total than a '
        'backup is.');
  }
}

/// Extracts [package] into [destination] ONCE, under every bound above.
///
/// Returns the staged member names.
///
/// The single entry point for both verification and restore. The desktop
/// learned this the hard way: restore used to extract the package and then
/// call verify, which extracted the SAME hostile input a second time.
Future<List<String>> stagePackage(File package, Directory destination) async {
  await destination.create(recursive: true);

  InputFileStream? input;
  try {
    input = InputFileStream(package.path);
    final directory = ZipDirectory();
    directory.read(input);
    if (directory.fileHeaders.isEmpty) {
      throw const BackupFormatError('The backup could not be opened.');
    }
    rejectUnsafeMembers(directory.fileHeaders);

    final staged = <String>[];
    var total = 0;
    for (final header in directory.fileHeaders) {
      total += _stageMember(header, destination, total);
      staged.add(header.filename);
    }
    return staged;
  } on BackupFormatError {
    rethrow;
  } on Object catch (error) {
    // Anything the ZIP reader can throw on a malformed file — a range error
    // off the end of a truncated archive, an ArchiveException, an OS error —
    // means the same thing to the caller and must not escape as itself.
    throw BackupFormatError('The backup could not be opened. ($error)');
  } finally {
    await input?.close();
  }
}

/// Copies one member out with a SECOND counter: the bytes actually produced.
///
/// The header's `uncompressedSize` is checked before this runs, but a header
/// can lie — it is written by whoever made the file. So the decompressed
/// bytes are counted as they arrive and the copy is abandoned the moment it
/// passes the limit, however small the member claimed to be.
int _stageMember(ZipFileHeader info, Directory destination, int runningTotal) {
  final limit = memberByteLimit(info.filename);
  final target = File(p.join(destination.path, info.filename));
  final sink = target.openSync(mode: FileMode.writeOnly);

  var written = 0;
  var crc = 0;
  final pending = BytesBuilder(copy: false);

  void flush() {
    if (pending.isEmpty) return;
    sink.writeFromSync(pending.takeBytes());
  }

  void take(List<int> chunk) {
    written += chunk.length;
    if (written > limit) {
      throw const BackupFormatError('A file in the backup is too large.');
    }
    if (runningTotal + written > maxTotalBytes) {
      throw const BackupFormatError('The backup is larger in total than a '
          'backup is.');
    }
    crc = getCrc32(chunk, crc);
    pending.add(chunk);
    if (pending.length >= _stageChunk) flush();
  }

  try {
    final raw = info.file!.getStream(decompress: false);
    if (info.compressionMethod == 0) {
      while (!raw.isEOS) {
        take(raw.readBytes(_stageChunk).toUint8List());
      }
    } else {
      // dart:io's zlib, driven a chunk at a time. `ChunkedConversionSink` is
      // pushed synchronously, so `take` runs as the bytes are produced and
      // can abandon the member mid-stream — which is the whole point. The
      // convenience wrapper in `package:archive` cannot: it collects every
      // chunk and hands them over only at close, by which time a zip bomb has
      // already been paid for in memory.
      final inflate = ZLibCodec(raw: true).decoder.startChunkedConversion(
        ByteConversionSink.withCallback((bytes) => take(bytes)),
      );
      while (!raw.isEOS) {
        inflate.add(raw.readBytes(_stageChunk).toUint8List());
      }
      inflate.close();
    }
    flush();
    // What came out has to be what the package said would come out.
    //
    // Not redundant with the bounds above: those ask whether the member is
    // ALLOWED to be this big, and this asks whether it is the member at all.
    // A damaged DEFLATE stream does not reliably raise — Huffman decoding
    // arbitrary bits mostly produces arbitrary bytes — so without this, a
    // corrupted `config.json` would be staged as garbage and only noticed
    // later, as a settings file that would not parse.
    //
    // The other three members are separately authenticated: `finance.db` by
    // the SHA-256 in the metadata, the metadata by its HMAC, the recovery
    // material by its own AES-GCM tag. `config.json` is covered by nothing
    // else, which is exactly why the check belongs here rather than there.
    if (written != info.uncompressedSize || crc != info.crc32) {
      throw BackupFormatError(
        'A file in the backup (${info.filename}) is damaged.',
      );
    }
    return written;
  } finally {
    sink.closeSync();
  }
}

/// Writes [members] from [staged] into [destination] as a deflated ZIP.
Future<void> writePackage(
  Directory staged,
  List<String> members,
  File destination,
) async {
  final encoder = ZipFileEncoder();
  encoder.create(destination.path);
  try {
    for (final member in members) {
      await encoder.addFile(File(p.join(staged.path, member)), member);
    }
  } finally {
    await encoder.close();
  }
}

/// The file's SHA-256, read in bounded chunks.
///
/// Not `sha256.convert(await file.readAsBytes())`: that pulls the whole file
/// into memory as a second copy, and the package limit is 256 MB. The digest
/// is byte for byte the same either way; only the peak allocation differs.
Future<String> sha256File(File file) async {
  final sink = Sha256().newHashSink();
  final handle = await file.open();
  try {
    while (true) {
      final chunk = await handle.read(_hashChunk);
      if (chunk.isEmpty) break;
      sink.add(chunk);
    }
  } finally {
    await handle.close();
  }
  sink.close();
  return hex((await sink.hash()).bytes);
}

/// The lowercase hex the metadata's digests and fingerprints are written as.
String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// SHA-256 of a value small enough to hold in memory — a key, in practice.
Future<String> sha256Hex(List<int> bytes) async =>
    hex((await Sha256().hash(bytes)).bytes);

/// Reads a JSON object, insisting that the root really is an object.
///
/// A package whose `metadata.json` held `[]` would otherwise fail on the
/// first field access with a type error rather than as a bad backup. The root
/// type has to be the first thing tested.
Map<String, Object?> readJsonObject(File file, String label) {
  final Object? parsed;
  try {
    parsed = jsonDecode(file.readAsStringSync());
  } on Object {
    throw BackupFormatError('The backup $label is corrupt.');
  }
  if (parsed is! Map<String, Object?>) {
    throw BackupFormatError('The backup $label is corrupt.');
  }
  return parsed;
}

const Set<String> _hexDigits = {
  '0', '1', '2', '3', '4', '5', '6', '7', //
  '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
};

/// A 64-character lowercase hex string — the only shape a SHA-256 takes here.
String requireHexDigest(Object? value, String label) {
  if (value is! String ||
      value.length != 64 ||
      !value.split('').every(_hexDigits.contains)) {
    throw BackupFormatError('The backup $label is not a valid digest.');
  }
  return value;
}

/// `aead_records_verified` has to be a real, non-negative count.
int requireRecordCount(Object? value) {
  if (value is! int || value < 0) {
    throw const BackupFormatError(
      'The backup AEAD verification count is invalid.',
    );
  }
  return value;
}
