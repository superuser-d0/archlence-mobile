import 'package:flutter/material.dart';

import '../app_services.dart';
import '../app_version.dart';
import '../crypto/key_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/backup_reminder.dart';
import '../services/shares_api_key.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../widgets/not_yet.dart';
import '../widgets/sheet_frame.dart';
import '../widgets/surfaces.dart';
import 'backup_screen.dart';
import 'category_settings_screen.dart';

/// Settings, grouped into sections rather than one flat list.
///
/// Three rows here do something real: the encryption key reports where it is
/// actually held, the resume lock switches the gate, and Backup & Restore
/// opens the screen that writes and reads packages. The key row used to be a
/// hard-coded sentence claiming an owner-only file, which on a device with a
/// working Keystore said the exact opposite of the truth — the worst thing on
/// this screen to be wrong about.
///
/// Everything else is marked unavailable. The two decorative switches went
/// with them: they moved local state and nothing else, so a user could turn
/// "Dark Mode" off and watch nothing happen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<(bool available, bool enabled)>? _lockState;

  final _reminder = BackupReminder();

  /// Days since the last backup, null when there has never been one.
  Future<int?>? _backupAge;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lockState ??= _readLock();
    _backupAge ??= _reminder.daysSinceBackup();
  }

  /// How long ago, in a sentence. Null days means it has never happened,
  /// which is the case worth saying plainly rather than as "0 days ago".
  String _backupAgeLine(AppLocalizations l10n, int? days) => switch (days) {
    null => l10n.backupAgeNever,
    0 => l10n.backupAgeToday,
    _ => l10n.backupAgeDays(days),
  };

  Future<(bool, bool)> _readLock() async {
    final lock = ServicesScope.of(context).screenLock;
    return (await lock.isAvailable(), await lock.isEnabled());
  }

  Future<void> _setLock(bool enabled) async {
    final lock = ServicesScope.of(context).screenLock;
    final reason = context.l10n.unlockPrompt;
    // Asked for BEFORE turning it on. A lock switched on by someone who
    // cannot then pass it is a lock on the owner's own data.
    if (enabled && !await lock.authenticate(reason: reason)) return;
    await lock.setEnabled(enabled);
    if (!mounted) return;
    // A block body, not an arrow. `setState(() => x = f())` returns the
    // assignment's value — here a Future — and Flutter asserts on a setState
    // callback that returns one, which leaves the state UNCHANGED. This is
    // the third time that trap has been walked into in this codebase; see
    // `test/no_async_set_state_test.dart`.
    setState(() {
      _lockState = _readLock();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final keyProtection = ServicesScope.of(context).keyProtection;
    final inset = MediaQuery.paddingOf(context);

    return ListView(
      key: const PageStorageKey('settings'),
      padding: EdgeInsets.fromLTRB(
        contentInset(context),
        inset.top + Spacing.stackLg,
        contentInset(context),
        inset.bottom + Spacing.stackLg,
      ),
      children: [
        SectionLabel(l10n.settingsSectionAccount),
        const SizedBox(height: Spacing.stackSm),
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.sell_outlined,
              title: l10n.settingsCategorySettings,
              subtitle: l10n.settingsCategorySubtitle,
              subtitleMaxLines: 2,
              available: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CategorySettingsScreen(),
                ),
              ),
            ),
            const _LanguageTile(),
            const _SharesKeyTile(),
            _SettingsTile(
              icon: Icons.vpn_key_outlined,
              title: l10n.settingsEncryptionKey,
              // Deliberately allowed to wrap. The reference truncates this
              // with an ellipsis, which hides WHERE the key is stored and how
              // well it is protected — the one line on this screen a user most
              // needs to read in full.
              subtitle: _keyProtectionSummary(l10n, keyProtection),
              subtitleMaxLines: 3,
              danger: keyProtection != null && !keyProtection.secureStore,
              available: true,
            ),
          ],
        ),
        const SizedBox(height: Spacing.stackMd),
        Center(
          child: Text(
            'Archlence v$appVersion',
            style: text.labelMedium?.copyWith(
              letterSpacing: 0,
              color: ObsidianPalette.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: Spacing.sectionGap),

        SectionLabel(l10n.settingsSectionSecurity),
        const SizedBox(height: Spacing.stackSm),
        FutureBuilder<(bool, bool)>(
          future: _lockState,
          builder: (context, snapshot) {
            final (available, enabled) = snapshot.data ?? (false, false);
            return _SettingsGroup(
              children: [
                _LockTile(
                  available: available,
                  enabled: enabled,
                  onChanged: _setLock,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: Spacing.sectionGap),

        SectionLabel(l10n.settingsSectionYourData),
        const SizedBox(height: Spacing.stackSm),
        FutureBuilder<int?>(
          future: _backupAge,
          builder: (context, snapshot) {
            final backup = ServicesScope.of(context).backup;
            // While the age is still being read the row says only what it
            // always said. A row that flashes "no backup yet" and then
            // corrects itself would frighten a user who backs up every week.
            final age = snapshot.connectionState == ConnectionState.done
                ? '${_backupAgeLine(l10n, snapshot.data)} '
                : '';
            return _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.backup_outlined,
                  title: l10n.settingsBackupRestore,
                  // The age goes FIRST, ahead of the explanation, because it
                  // is the only line here that changes and the only one that
                  // asks the user for anything. See `BackupReminder`.
                  subtitle: backup == null
                      ? l10n.settingsBackupUnavailable
                      : '$age${l10n.settingsBackupSubtitle}',
                  // Four, not three: the age line is prepended to an
                  // explanation that already filled three, and the pair was
                  // being cut mid-sentence. Found by looking at the row on a
                  // phone rather than at the string in the file.
                  subtitleMaxLines: 4,
                  available: backup != null,
                  onTap: backup == null
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const BackupScreen(),
                            ),
                          );
                          if (!context.mounted) return;
                          // Re-read on the way back: the user may have just
                          // written one, and a row still saying "never" would
                          // be the app forgetting what it had just done.
                          setState(() {
                            _backupAge = _reminder.daysSinceBackup();
                          });
                        },
                ),
              ],
            );
          },
        ),
        const SizedBox(height: Spacing.sectionGap),

        SectionLabel(l10n.settingsSectionAbout),
        const SizedBox(height: Spacing.stackSm),
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.description_outlined,
              title: l10n.settingsOpenSourceLicenses,
              subtitle: l10n.settingsOpenSourceLicensesSubtitle,
              available: true,
              // Flutter's own page. It collects the licence of every package
              // in the build INCLUDING this one — the root package's own
              // LICENSE file is picked up without being asked, which was
              // worth finding out by opening the page rather than assuming:
              // registering it by hand as well put the app in its own list
              // twice, under two names.
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Archlence',
                applicationVersion: appVersion,
                applicationLegalese: '© 2026 superuser-d0',
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sectionGap),

        // Three sections that are mockup and nothing else — see
        // `showUnbuiltFeatures`. `Sign Out` in particular: there is no
        // account to sign out of, and saying so in a row is worse than not
        // having the row.
        if (showUnbuiltFeatures) ...[
          SectionLabel(l10n.settingsSectionAppearance),
          const SizedBox(height: Spacing.stackSm),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: l10n.settingsPremiumTheme,
                subtitle: l10n.settingsPremiumThemeSubtitle,
              ),
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: l10n.settingsDataPrivacy,
              ),
            ],
          ),
          const SizedBox(height: Spacing.sectionGap),

          SectionLabel(l10n.settingsSectionSecurityHistory),
          const SizedBox(height: Spacing.stackSm),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.lock_outline,
                title: l10n.settingsChangePassword,
                subtitle: l10n.settingsChangePasswordSubtitle,
              ),
              _SettingsTile(
                icon: Icons.history,
                title: l10n.settingsBalanceHistory,
              ),
            ],
          ),
          const SizedBox(height: Spacing.sectionGap),

          SectionLabel(l10n.settingsSectionSystem),
          const SizedBox(height: Spacing.stackSm),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: l10n.settingsDarkMode,
                subtitle: l10n.settingsDarkModeSubtitle,
              ),
              _SettingsTile(
                icon: Icons.mail_outline,
                title: l10n.settingsContactUs,
              ),
              _SettingsTile(
                icon: Icons.logout,
                title: l10n.settingsSignOut,
                danger: true,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A card holding a run of tiles separated by hairlines.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 64),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleMaxLines = 2,
    this.danger = false,
    this.available = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int subtitleMaxLines;
  final bool danger;

  /// A row that reports real state, whether or not it opens anything.
  ///
  /// Three shapes, and they are distinguishable at a glance because the
  /// difference matters: available with an [onTap] gets a chevron because it
  /// has somewhere to go; available without one reports state and stays put;
  /// unavailable carries the chip that says so.
  final bool available;

  /// Where the row goes, or null when it goes nowhere.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = danger ? ObsidianPalette.error : ObsidianPalette.onSurface;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (danger ? ObsidianPalette.error : ObsidianPalette.primary)
                  .withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: danger ? ObsidianPalette.error : ObsidianPalette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodyMedium?.copyWith(
                    color: available ? tint : ObsidianPalette.onSurfaceVariant,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: subtitleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // A chevron promises a destination, so only a row that has one gets
          // it. The chip says the opposite.
          if (!available)
            const NotYetChip()
          else if (onTap != null)
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: ObsidianPalette.onSurfaceVariant,
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// What the Encryption Key row says, from what the key provider actually did.
///
/// Null means the caller has no platform provider behind it — the tests, which
/// inject a fixed key. It says so rather than assuming the best case: claiming
/// Keystore protection that is not there is the one thing on this screen it
/// would be worst to be wrong about.
String _keyProtectionSummary(AppLocalizations l10n, KeyProtectionStatus? status) {
  if (status == null) {
    return l10n.keyProtectionUnknown;
  }
  final method = switch (status.method) {
    KeyProtectionMethod.androidKeystore => l10n.keyMethodAndroidKeystore,
    KeyProtectionMethod.ownerOnlyFile => l10n.keyMethodOwnerOnlyFile,
  };
  final where = status.secureStore
      ? l10n.keyProtectionHeldByOs(method)
      : l10n.keyProtectionLocalFile(method);
  final warning = switch (status.warning) {
    null => null,
    KeyProtectionWarning.osKeyStoreUnavailable =>
      l10n.keyWarningOsStoreUnavailable,
    KeyProtectionWarning.platformHasNoKeyStore =>
      l10n.keyWarningNoPlatformStore,
  };
  return warning == null ? where : '$where $warning';
}

/// The BIST API key row: whether one is set, and the sheet that changes it.
///
/// A [StatefulWidget] because it reads the secure store, and the row has to
/// redraw the moment a key is saved or removed rather than on the next visit
/// to Settings.
///
/// The key ITSELF is never shown, not even masked. A row that displayed one
/// would put a credential on screen for a shoulder to read, and there is
/// nothing a user can do with seeing it that "a key is set" does not already
/// tell them — if it is wrong, the fix is to paste the right one, which the
/// sheet allows either way.
class _SharesKeyTile extends StatefulWidget {
  const _SharesKeyTile();

  @override
  State<_SharesKeyTile> createState() => _SharesKeyTileState();
}

class _SharesKeyTileState extends State<_SharesKeyTile> {
  Future<bool>? _isSet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isSet ??= _read();
  }

  Future<bool> _read() async =>
      await ServicesScope.of(context).sharesApiKey.read() != null;

  Future<void> _open() async {
    final store = ServicesScope.of(context).sharesApiKey;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ObsidianPalette.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      builder: (_) => _SharesKeySheet(store: store),
    );
    if (changed != true || !mounted) return;
    // A block body, not an arrow: `setState(() => x = f())` hands Flutter a
    // callback returning a Future, which it asserts on and swallows, leaving
    // the state unchanged. See `test/no_async_set_state_test.dart`.
    setState(() {
      _isSet = _read();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<bool>(
      future: _isSet,
      builder: (context, snapshot) {
        final isSet = snapshot.data ?? false;
        return _SettingsTile(
          icon: Icons.show_chart,
          title: l10n.settingsSharesKey,
          subtitle: isSet
              ? l10n.settingsSharesKeySet
              : l10n.settingsSharesKeyNotSet,
          subtitleMaxLines: 2,
          available: true,
          onTap: _open,
        );
      },
    );
  }
}

/// The sheet behind the row. Pops `true` when the stored key changed.
class _SharesKeySheet extends StatefulWidget {
  const _SharesKeySheet({required this.store});

  final SharesApiKey store;

  @override
  State<_SharesKeySheet> createState() => _SharesKeySheetState();
}

class _SharesKeySheetState extends State<_SharesKeySheet> {
  final _controller = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _write(String? key, String note) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _working = true);
    await widget.store.write(key);
    if (!mounted) return;
    navigator.pop(true);
    messenger.showSnackBar(SnackBar(content: Text(note)));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final typed = _controller.text.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.containerMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ObsidianPalette.cardStroke,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),
            ),
            const SizedBox(height: Spacing.stackLg),
            Text(l10n.sharesKeySheetTitle, style: text.headlineMedium),
            const SizedBox(height: Spacing.stackMd),
            Text(
              l10n.sharesKeyExplanation,
              style: text.bodySmall?.copyWith(
                color: ObsidianPalette.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.stackLg),
            SheetField(
              controller: _controller,
              label: l10n.sharesKeyField,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Spacing.stackLg),
            GradientButton(
              label: l10n.sharesKeySave,
              onPressed: _working || typed.isEmpty
                  ? null
                  : () => _write(typed, l10n.sharesKeySaved),
            ),
            const SizedBox(height: Spacing.stackSm),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: ObsidianPalette.error,
              ),
              onPressed: _working
                  ? null
                  : () => _write(null, l10n.sharesKeyRemoved),
              child: Text(l10n.sharesKeyRemove),
            ),
            const SizedBox(height: Spacing.stackMd),
          ],
        ),
      ),
    );
  }
}

/// The language row, and what it opens.
///
/// The names of the languages are NOT translated. A reader looking for their
/// own language finds it written the way they write it — "Türkçe" stays
/// "Türkçe" in the English interface — and someone stranded in a language
/// they cannot read can still find their way out.
class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  /// Null first: the option that follows the phone's own setting.
  static const _options = <Locale?>[null, ...supportedLocales];

  static String _name(AppLocalizations l10n, Locale? locale) =>
      switch (locale?.languageCode) {
        'tr' => 'Türkçe',
        'en' => 'English',
        _ => l10n.settingsLanguageSystem,
      };

  Future<void> _choose(BuildContext context, AppLocaleScope scope) async {
    final chosen = await showModalBottomSheet<_Chosen>(
      context: context,
      backgroundColor: ObsidianPalette.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      // The sheet returns the CHOICE, and a dismissed sheet returns nothing.
      // A plain `Locale?` result cannot tell "follow the device" from
      // "cancelled", so the options are wrapped on the way back out.
      builder: (sheetContext) => _LanguageSheet(selected: scope.selected),
    );
    if (chosen == null) return;
    await scope.select(chosen.locale);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scope = AppLocaleScope.maybeOf(context);
    return _SettingsTile(
      icon: Icons.language,
      title: l10n.settingsLanguage,
      subtitle: _name(l10n, scope?.selected),
      available: scope != null,
      onTap: scope == null ? null : () => _choose(context, scope),
    );
  }
}

/// A chosen locale, distinct from the sheet being dismissed.
class _Chosen {
  const _Chosen(this.locale);

  final Locale? locale;
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.selected});

  final Locale? selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              contentInset(context),
              Spacing.stackLg,
              contentInset(context),
              Spacing.stackSm,
            ),
            child: Text(context.l10n.settingsLanguage, style: text.titleLarge),
          ),
          for (final option in _LanguageTile._options)
            ListTile(
              title: Text(_LanguageTile._name(context.l10n, option)),
              trailing: option == selected
                  ? const Icon(Icons.check, color: ObsidianPalette.primary)
                  : null,
              onTap: () => Navigator.of(context).pop(_Chosen(option)),
            ),
          const SizedBox(height: Spacing.stackMd),
        ],
      ),
    );
  }
}

/// The resume gate's switch, with what it actually buys written under it.
///
/// The subtitle is not decoration. A lock the app draws stops a borrowed
/// phone; it does not stop anyone who can read the device's storage, because
/// the database key opens without it. Saying "your data is protected" here
/// would be the app claiming something it does not do.
class _LockTile extends StatelessWidget {
  const _LockTile({
    required this.available,
    required this.enabled,
    required this.onChanged,
  });

  final bool available;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ObsidianPalette.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fingerprint,
              size: 18,
              color: ObsidianPalette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.lockTileTitle,
                  style: text.bodyMedium?.copyWith(
                    color: available
                        ? ObsidianPalette.onSurface
                        : ObsidianPalette.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  available
                      ? l10n.lockTileExplanation
                      : l10n.lockTileUnavailable,
                  style: text.bodySmall?.copyWith(
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: enabled, onChanged: available ? onChanged : null),
        ],
      ),
    );
  }
}
