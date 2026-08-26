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
import '../backup/recovery_material.dart';
import '../crypto/key_provider.dart';
import '../theme/obsidian_prime.dart';
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

  /// What the app is doing, or null when it is doing nothing.
  ///
  /// The KDF takes seconds by design, and a button that simply stops
  /// responding for that long reads as a crash. The text says what is
  /// happening rather than spinning silently.
  String? _busy;

  String? _error;
  String? _note;

  @override
  void dispose() {
    _createPassphrase.dispose();
    _confirmPassphrase.dispose();
    _restorePassphrase.dispose();
    super.dispose();
  }

  BackupService? get _service => ServicesScope.of(context).backup;

  /// Runs [work] with the screen locked and whatever it throws turned into a
  /// sentence.
  Future<void> _run(String busy, Future<String?> Function() work) async {
    setState(() {
      _busy = busy;
      _error = null;
      _note = null;
    });
    String? note;
    String? error;
    try {
      note = await work();
    } on WrongPassphraseError {
      error = 'That passphrase does not open this backup.';
    } on BackupFormatError catch (failure) {
      error = failure.message;
    } on RestoreFailedError catch (failure) {
      error = failure.message;
    } on InterruptedRestoreError catch (failure) {
      error = failure.message;
    } on KeyUnavailableError catch (failure) {
      error = failure.message;
    } on Object catch (failure) {
      error = 'Something went wrong: $failure';
    }
    if (!mounted) return;
    setState(() {
      _busy = null;
      _note = note;
      _error = error;
    });
  }

  Future<String?> _create() async {
    final service = _service;
    if (service == null) return null;
    final passphrase = _createPassphrase.text;
    if (passphrase != _confirmPassphrase.text) {
      throw const BackupFormatError('The two passphrases are not the same.');
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
        subject: 'Archlence backup',
      ),
    );
    return 'Backup written and checked: '
        '${outcome.aeadRecordsVerified} encrypted records opened with the key '
        'inside it before it was published.';
  }

  Future<String?> _restore() async {
    final service = _service;
    final swap = AppRestartScope.maybeOf(context);
    if (service == null || swap == null) return null;

    // No type filter. On Android the chooser filters by MIME type, and
    // `.archlence-backup` maps to none — a filter would leave the user
    // looking at a picker that greys out the only file they came for. What
    // the file actually is gets decided by reading it, which is the only
    // thing that could be trusted anyway.
    final picked = await openFile(
      confirmButtonText: 'Restore',
      acceptedTypeGroups: const [XTypeGroup(label: 'Archlence backup')],
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
        ? 'Restored. There was nothing here before, so nothing was set aside.'
        : 'Restored. What was here before was written to '
              '${p.basename(safety!)} in this app\'s own storage first.';
  }

  Future<bool?> _confirmRestore() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: ObsidianPalette.surfaceContainer,
      title: const Text('Replace everything in this app?'),
      content: const Text(
        'Every account, transaction, holding, budget and goal on this phone '
        'is replaced by what is in the backup.\n\n'
        'What is here now is written to a backup of its own first, using the '
        'same passphrase, and the app will tell you its name.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Replace',
            style: TextStyle(color: ObsidianPalette.error),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final available = _service != null;
    final busy = _busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: AbsorbPointer(
        absorbing: busy != null,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.containerMargin,
            Spacing.stackLg,
            Spacing.containerMargin,
            Spacing.stackLg,
          ),
          children: [
            if (!available)
              AppCard(
                child: Text(
                  'This build has no profile on disk, so there is nothing to '
                  'back up.',
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
              _Message(text: _error!, danger: true),
              const SizedBox(height: Spacing.stackMd),
            ],
            if (_note != null) ...[
              _Message(text: _note!),
              const SizedBox(height: Spacing.stackMd),
            ],

            const SectionLabel('Make a backup'),
            const SizedBox(height: Spacing.stackSm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A backup holds your whole database and the key that opens '
                    'it, wrapped under a passphrase you choose. Twelve '
                    'characters at least.\n\n'
                    'THE PASSPHRASE IS NOT STORED ANYWHERE. Without it the '
                    'backup cannot be opened — not by this app, not by anyone.',
                    style: text.bodySmall?.copyWith(
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.stackMd),
                  SheetField(
                    controller: _createPassphrase,
                    label: 'Passphrase',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Spacing.stackSm),
                  SheetField(
                    controller: _confirmPassphrase,
                    label: 'Passphrase again',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Spacing.stackMd),
                  GradientButton(
                    label: 'Create and share a backup',
                    onPressed: available && _createReady
                        ? () => _run(
                            'Wrapping the key. This takes a few seconds — the '
                            'passphrase is deliberately slow to try.',
                            _create,
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sectionGap),

            const SectionLabel('Restore from a backup'),
            const SizedBox(height: Spacing.stackSm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replaces everything in this app with what is in the file, '
                    'including the encryption key. A backup written by the '
                    'desktop app works here.\n\n'
                    'What is here now is written to a backup of its own first, '
                    'under the same passphrase.',
                    style: text.bodySmall?.copyWith(
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.stackMd),
                  SheetField(
                    controller: _restorePassphrase,
                    label: 'The backup\'s passphrase',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Spacing.stackMd),
                  OutlinedButton(
                    onPressed:
                        available &&
                            _restorePassphrase.text.length >=
                                minPassphraseLength
                        ? () => _run(
                            'Checking the backup and replacing your data. Do '
                            'not close the app.',
                            _restore,
                          )
                        : null,
                    child: const Text('Choose a file and restore'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _createReady =>
      _createPassphrase.text.length >= minPassphraseLength &&
      _confirmPassphrase.text.length >= minPassphraseLength;
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.danger = false});

  final String text;
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
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: danger
                    ? ObsidianPalette.error
                    : ObsidianPalette.onSurface,
              ),
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
