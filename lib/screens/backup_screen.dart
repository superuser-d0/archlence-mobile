/// Making a backup, and restoring from one.
///
/// The screen exists because onboarding tells the user their data is theirs to
/// look after, and until now the app gave them no way to do it.
///
/// Two things here are wording, not decoration:
///
///  * **The passphrase cannot be recovered.** It is not stored anywhere; it
///    is what the key inside the package is wrapped under. A user who expects
///    a reset link will find out at the worst possible moment.
///  * **Restoring replaces everything.** The app writes the current data to a
///    package of its own first, and says where, because "your data was
///    replaced" and "your data is gone" are different sentences and the
///    difference is that file.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_services.dart';
import '../backup/backup_errors.dart';
import '../backup/backup_service.dart';
import '../backup/key_recovery_service.dart';
import '../backup/recovery_material.dart';
import '../crypto/key_provider.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../widgets/sheet_frame.dart';
import '../widgets/surfaces.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _createPassphrase = TextEditingController();
  final _confirmPassphrase = TextEditingController();
  final _restorePassphrase = TextEditingController();
  final _exportKeyPassphrase = TextEditingController();
  final _confirmKeyPassphrase = TextEditingController();
  final _importKeyPassphrase = TextEditingController();

  /// What the app is doing, or null when it is doing nothing.
  ///
  /// The KDF takes seconds by design, and a button that simply stops
  /// responding for that long reads as a crash. The text says what is
  /// happening rather than spinning silently.
  String? _busy;

  /// The headline of what went wrong, in the user's language.
  String? _error;

  /// The technical detail under it, and the one thing on this screen that is
  /// NOT translated.
  ///
  /// The backup layer's sixty-odd messages are diagnostics about a malformed
  /// package — a hash that does not match, a field of the wrong shape, a key
  /// of the wrong length. Translating them would put sixty sentences nobody
  /// reads in front of a translator while the sentence that decides what the
  /// user DOES — [_error] — is the one above. The same split `DataUnavailable`
  /// and the start-up failure screen already use.
  String? _detail;

  String? _note;

  @override
  void dispose() {
    _createPassphrase.dispose();
    _confirmPassphrase.dispose();
    _restorePassphrase.dispose();
    _exportKeyPassphrase.dispose();
    _confirmKeyPassphrase.dispose();
    _importKeyPassphrase.dispose();
    super.dispose();
  }

  BackupService? get _service => ServicesScope.of(context).backup;

  KeyRecoveryService? get _recovery => ServicesScope.of(context).keyRecovery;

  /// Runs [work] with the screen locked and whatever it throws turned into a
  /// sentence.
  Future<void> _run(String busy, Future<String?> Function() work) async {
    final l10n = context.l10n;
    setState(() {
      _busy = busy;
      _error = null;
      _detail = null;
      _note = null;
    });
    String? note;
    String? error;
    String? detail;
    try {
      note = await work();
    } on _StatedError catch (failure) {
      error = failure.message;
    } on WrongPassphraseError {
      // No detail: there is nothing to add, and "you mistyped" and "this file
      // is not a backup" send a user to different places.
      error = l10n.backupWrongPassphrase;
    } on BackupFormatError catch (failure) {
      error = l10n.backupFileUnusable;
      detail = failure.message;
    } on RestoreFailedError catch (failure) {
      error = l10n.backupRestoreRolledBack;
      detail = failure.message;
    } on InterruptedRestoreError catch (failure) {
      error = l10n.backupInterrupted;
      detail = failure.message;
    } on KeyUnavailableError catch (failure) {
      error = l10n.backupKeyUnavailable;
      detail = failure.message;
    } on Object catch (failure) {
      error = l10n.backupUnexpected;
      detail = '$failure';
    }
    if (!mounted) return;
    setState(() {
      _busy = null;
      _note = note;
      _error = error;
      _detail = detail;
    });
  }

  Future<String?> _create() async {
    final l10n = context.l10n;
    final service = _service;
    if (service == null) return null;
    final passphrase = _createPassphrase.text;
    if (passphrase != _confirmPassphrase.text) {
      throw _StatedError(l10n.backupPassphrasesDiffer);
    }
    requirePassphrase(passphrase);

    final directory = await getApplicationDocumentsDirectory();
    final destination = File(
      p.join(directory.path, 'archlence-${_stamp(DateTime.now())}.archlence-backup'),
    );
    final outcome = await service.createBackup(destination, passphrase);

    _createPassphrase.clear();
    _confirmPassphrase.clear();

    // Shared, not saved to a folder. Since Android 11 an app cannot write
    // anywhere another app can read, so a backup left in this app's own
    // directory would go with the app if it were uninstalled — which is one
    // of the things a backup is for.
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(outcome.path)],
        fileNameOverrides: [p.basename(outcome.path)],
        subject: l10n.backupShareSubject,
      ),
    );
    return l10n.backupCreated(outcome.aeadRecordsVerified);
  }

  Future<String?> _restore() async {
    final l10n = context.l10n;
    final service = _service;
    final swap = AppRestartScope.maybeOf(context);
    if (service == null || swap == null) return null;

    // No type filter. On Android the chooser filters by MIME type, and
    // `.archlence-backup` maps to none — a filter would leave the user
    // looking at a picker that greys out the only file they came for. What
    // the file actually is gets decided by reading it, which is the only
    // thing that could be trusted anyway.
    final picked = await openFile(
      confirmButtonText: l10n.backupRestoreConfirmButton,
      acceptedTypeGroups: [XTypeGroup(label: l10n.backupFileTypeLabel)],
    );
    final path = picked?.path;
    if (path == null) return null;

    if (!mounted) return null;
    final confirmed = await _confirmRestore();
    if (confirmed != true) return null;

    final passphrase = _restorePassphrase.text;
    requirePassphrase(passphrase);

    String? safety;
    await swap(() async {
      final outcome = await service.restoreBackup(File(path), passphrase);
      safety = outcome.safetyBackupPath;
    });
    _restorePassphrase.clear();

    return safety == null
        ? l10n.backupRestoredNothingBefore
        : l10n.backupRestoredWithSafety(p.basename(safety!));
  }

  /// Writes the key on its own and hands it to the share sheet.
  ///
  /// Shared rather than saved into this app's own storage, for the same
  /// reason a backup is: a recovery package that lives beside the data it
  /// recovers goes with the phone.
  Future<String?> _exportKey() async {
    final l10n = context.l10n;
    final recovery = _recovery;
    if (recovery == null) return null;
    final passphrase = _exportKeyPassphrase.text;
    if (passphrase != _confirmKeyPassphrase.text) {
      throw _StatedError(l10n.backupPassphrasesDiffer);
    }
    requirePassphrase(passphrase);

    final directory = await getApplicationDocumentsDirectory();
    final destination = File(
      p.join(
        directory.path,
        'archlence-key-${_stamp(DateTime.now())}.archlence-key',
      ),
    );
    final written = await recovery.exportRecoveryPackage(
      destination,
      passphrase,
    );

    _exportKeyPassphrase.clear();
    _confirmKeyPassphrase.clear();

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(written)],
        fileNameOverrides: [p.basename(written)],
        subject: l10n.recoveryExportShareSubject,
      ),
    );
    return l10n.recoveryExported;
  }

  /// Puts a key from a file back into the key store.
  ///
  /// THROUGH `swapProfile`, like a restore, and not because the database is
  /// being replaced — it is not. `FieldCrypto` caches the key it first read,
  /// so a running app would go on decrypting with the OLD one and report
  /// every row as corrupt. Closing the graph and building it again over the
  /// new key is what makes the import take effect.
  Future<String?> _importKey() async {
    final l10n = context.l10n;
    final recovery = _recovery;
    final swap = AppRestartScope.maybeOf(context);
    if (recovery == null || swap == null) return null;

    final picked = await openFile(
      confirmButtonText: l10n.recoveryImportConfirmButton,
      acceptedTypeGroups: [XTypeGroup(label: l10n.recoveryFileTypeLabel)],
    );
    final path = picked?.path;
    if (path == null) return null;

    final passphrase = _importKeyPassphrase.text;
    requirePassphrase(passphrase);

    RecoveryImportOutcome? outcome;
    await swap(() async {
      outcome = await recovery.importRecoveryPackage(File(path), passphrase);
    });
    _importKeyPassphrase.clear();

    final result = outcome!;
    final said = switch (result.result) {
      KeyImportResult.stored =>
        l10n.recoveryImportedStored(result.aeadRecordsVerified),
      KeyImportResult.replaced =>
        l10n.recoveryImportedReplaced(result.aeadRecordsVerified),
      KeyImportResult.unchanged => l10n.recoveryImportedUnchanged,
    };
    // "Verified" and "verified nothing" are not the same reassurance: on a
    // profile with nothing encrypted in it, any key at all would have passed.
    return result.aeadRecordsVerified == 0 &&
            result.result != KeyImportResult.unchanged
        ? '$said ${l10n.recoveryVerifiedNothing}'
        : said;
  }

  Future<bool?> _confirmRestore() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: ObsidianPalette.surfaceContainer,
      title: Text(context.l10n.backupRestoreConfirmTitle),
      content: Text(context.l10n.backupRestoreConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            context.l10n.backupReplaceConfirm,
            style: const TextStyle(color: ObsidianPalette.error),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final available = _service != null;
    // A separate question from [available]: the recovery service and the
    // restart scope are what the key rows need, and a screen built without
    // either must show them dead rather than let a tap do nothing.
    final keyRecovery = _recovery != null && AppRestartScope.maybeOf(context) != null;
    final busy = _busy;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
      body: AbsorbPointer(
        absorbing: busy != null,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            contentInset(context),
            Spacing.stackLg,
            contentInset(context),
            Spacing.stackLg,
          ),
          children: [
            if (!available)
              AppCard(
                child: Text(
                  l10n.backupNoProfile,
                  style: text.bodySmall?.copyWith(
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
                ),
              ),
            if (busy != null) ...[
              AppCard(
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(busy, style: text.bodySmall)),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.stackMd),
            ],
            if (_error != null) ...[
              _Message(text: _error!, detail: _detail, danger: true),
              const SizedBox(height: Spacing.stackMd),
            ],
            if (_note != null) ...[
              _Message(text: _note!),
              const SizedBox(height: Spacing.stackMd),
            ],

            SectionLabel(l10n.backupSectionCreate),
            const SizedBox(height: Spacing.stackSm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.backupCreateExplanation,
                    style: text.bodySmall?.copyWith(
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.stackMd),
                  SheetField(
                    controller: _createPassphrase,
                    label: l10n.backupPassphrase,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Spacing.stackSm),
                  SheetField(
                    controller: _confirmPassphrase,
                    label: l10n.backupPassphraseAgain,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Spacing.stackMd),
                  GradientButton(
                    label: l10n.backupCreateAction,
                    onPressed: available && _createReady
                        ? () => _run(l10n.backupCreateBusy, _create)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sectionGap),

            SectionLabel(l10n.backupSectionRestore),
            const SizedBox(height: Spacing.stackSm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.backupRestoreExplanation,
                    style: text.bodySmall?.copyWith(
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.stackMd),
                  SheetField(
                    controller: _restorePassphrase,
                    label: l10n.backupRestorePassphrase,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Spacing.stackMd),
                  OutlinedButton(
                    onPressed:
                        available &&
                            _restorePassphrase.text.length >=
                                minPassphraseLength
                        ? () => _run(l10n.backupRestoreBusy, _restore)
                        : null,
                    child: Text(l10n.backupRestoreAction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sectionGap),

            SectionLabel(l10n.recoverySectionExport),
            const SizedBox(height: Spacing.stackSm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.recoveryExportExplanation,
                    style: text.bodySmall?.copyWith(
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.stackMd),
                  SheetField(
                    controller: _exportKeyPassphrase,
                    label: l10n.backupPassphrase,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Spacing.stackSm),
                  SheetField(
                    controller: _confirmKeyPassphrase,
                    label: l10n.backupPassphraseAgain,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Spacing.stackMd),
                  OutlinedButton(
                    onPressed: keyRecovery && _exportKeyReady
                        ? () => _run(l10n.backupCreateBusy, _exportKey)
                        : null,
                    child: Text(l10n.recoveryExportAction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sectionGap),

            SectionLabel(l10n.recoverySectionImport),
            const SizedBox(height: Spacing.stackSm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.recoveryImportExplanation,
                    style: text.bodySmall?.copyWith(
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.stackMd),
                  SheetField(
                    controller: _importKeyPassphrase,
                    label: l10n.recoveryImportPassphrase,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Spacing.stackMd),
                  OutlinedButton(
                    onPressed:
                        keyRecovery &&
                            _importKeyPassphrase.text.length >=
                                minPassphraseLength
                        ? () => _run(l10n.recoveryImportBusy, _importKey)
                        : null,
                    child: Text(l10n.recoveryImportAction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sectionGap),
          ],
        ),
      ),
    );
  }

  bool get _createReady =>
      _createPassphrase.text.length >= minPassphraseLength &&
      _confirmPassphrase.text.length >= minPassphraseLength;

  bool get _exportKeyReady =>
      _exportKeyPassphrase.text.length >= minPassphraseLength &&
      _confirmKeyPassphrase.text.length >= minPassphraseLength;
}

/// A problem this screen raises itself, already in the user's language.
///
/// Distinct from the backup layer's own exceptions, which carry an untranslated
/// diagnostic: this one IS the sentence, and gets no detail line under it.
class _StatedError implements Exception {
  const _StatedError(this.message);

  final String message;

  @override
  String toString() => 'StatedError: $message';
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.detail, this.danger = false});

  final String text;

  /// Untranslated technical detail, shown under [text] when there is any.
  final String? detail;

  final bool danger;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            danger ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: danger ? ObsidianPalette.error : ObsidianPalette.tertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: danger
                        ? ObsidianPalette.error
                        : ObsidianPalette.onSurface,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      letterSpacing: 0,
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `YYYYMMDD-HHMMSS`, so a folder of backups sorts by when they were made.
String _stamp(DateTime when) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${when.year}${two(when.month)}${two(when.day)}-'
      '${two(when.hour)}${two(when.minute)}${two(when.second)}';
}
