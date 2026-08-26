import 'package:flutter/material.dart';

import '../app_services.dart';
import '../crypto/key_provider.dart';
import '../theme/obsidian_prime.dart';
import '../widgets/not_yet.dart';
import '../widgets/surfaces.dart';
import 'backup_screen.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lockState ??= _readLock();
  }

  Future<(bool, bool)> _readLock() async {
    final lock = ServicesScope.of(context).screenLock;
    return (await lock.isAvailable(), await lock.isEnabled());
  }

  Future<void> _setLock(bool enabled) async {
    final lock = ServicesScope.of(context).screenLock;
    // Asked for BEFORE turning it on. A lock switched on by someone who
    // cannot then pass it is a lock on the owner's own data.
    if (enabled && !await lock.authenticate()) return;
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
    final keyProtection = ServicesScope.of(context).keyProtection;
    final inset = MediaQuery.paddingOf(context);

    return ListView(
      key: const PageStorageKey('settings'),
      padding: EdgeInsets.fromLTRB(
        Spacing.containerMargin,
        inset.top + Spacing.stackLg,
        Spacing.containerMargin,
        inset.bottom + Spacing.stackLg,
      ),
      children: [
        const SectionLabel('Account & Preferences'),
        const SizedBox(height: Spacing.stackSm),
        _SettingsGroup(
          children: [
            const _SettingsTile(
              icon: Icons.sell_outlined,
              title: 'Category Settings',
            ),
            const _SettingsTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: 'English',
            ),
            _SettingsTile(
              icon: Icons.vpn_key_outlined,
              title: 'Encryption Key',
              // Deliberately allowed to wrap. The reference truncates this
              // with an ellipsis, which hides WHERE the key is stored and how
              // well it is protected — the one line on this screen a user most
              // needs to read in full.
              subtitle: _keyProtectionSummary(keyProtection),
              subtitleMaxLines: 3,
              danger: keyProtection != null && !keyProtection.secureStore,
              available: true,
            ),
          ],
        ),
        const SizedBox(height: Spacing.stackMd),
        Center(
          child: Text(
            'Archlence v0.1.0',
            style: text.labelMedium?.copyWith(
              letterSpacing: 0,
              color: ObsidianPalette.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: Spacing.sectionGap),

        const SectionLabel('Security'),
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

        const SectionLabel('Your Data'),
        const SizedBox(height: Spacing.stackSm),
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.backup_outlined,
              title: 'Backup & Restore',
              subtitle: ServicesScope.of(context).backup == null
                  ? 'Not available in this build.'
                  : 'Write a backup you can keep, or restore one — including '
                        'a backup made by the desktop app.',
              subtitleMaxLines: 3,
              available: ServicesScope.of(context).backup != null,
              onTap: ServicesScope.of(context).backup == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BackupScreen(),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sectionGap),

        const SectionLabel('Appearance & Privacy'),
        const SizedBox(height: Spacing.stackSm),
        _SettingsGroup(
          children: [
            const _SettingsTile(
              icon: Icons.palette_outlined,
              title: 'Premium Blue Theme',
              subtitle: 'Uses the standard theme when disabled',
            ),
            _SettingsTile(icon: Icons.shield_outlined, title: 'Data & Privacy'),
          ],
        ),
        const SizedBox(height: Spacing.sectionGap),

        const SectionLabel('Security & History'),
        const SizedBox(height: Spacing.stackSm),
        _SettingsGroup(
          children: [
            const _SettingsTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'You can renew your password here.',
            ),
            _SettingsTile(icon: Icons.history, title: 'Balance History'),
          ],
        ),
        const SizedBox(height: Spacing.sectionGap),

        const SectionLabel('System'),
        const SizedBox(height: Spacing.stackSm),
        _SettingsGroup(
          children: [
            const _SettingsTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark Mode',
              subtitle: 'Obsidian Prime is dark-only for now',
            ),
            _SettingsTile(icon: Icons.mail_outline, title: 'Contact Us'),
            const _SettingsTile(
              icon: Icons.logout,
              title: 'Sign Out',
              danger: true,
            ),
          ],
        ),
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
String _keyProtectionSummary(KeyProtectionStatus? status) {
  if (status == null) {
    return 'Not known in this build.';
  }
  final where = status.secureStore
      ? '${status.method} — held by the operating system.'
      : '${status.method} — NOT in an OS key store; the key is a local file '
            'readable only by this app.';
  return status.warning == null ? where : '$where ${status.warning}';
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
                  'Lock when I come back',
                  style: text.bodyMedium?.copyWith(
                    color: available
                        ? ObsidianPalette.onSurface
                        : ObsidianPalette.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  available
                      ? 'Asks for your fingerprint or PIN after a minute away. '
                            'It hides the screen from someone holding your '
                            'phone — it does not add encryption.'
                      : 'This device has no fingerprint or screen lock set up.',
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
