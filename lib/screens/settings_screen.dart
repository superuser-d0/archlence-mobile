import 'package:flutter/material.dart';

import '../app_services.dart';
import '../crypto/key_provider.dart';
import '../theme/obsidian_prime.dart';
import '../widgets/not_yet.dart';
import '../widgets/surfaces.dart';

/// Settings, grouped into sections rather than one flat list.
///
/// One row here reports real state: where the encryption key is held. It used
/// to be a hard-coded sentence claiming an owner-only file, which on a device
/// with a working Keystore said the exact opposite of the truth — the worst
/// thing on this screen to be wrong about.
///
/// Everything else is marked unavailable. The two switches went with them:
/// they moved local state and nothing else, so a user could turn "Dark Mode"
/// off and watch nothing happen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int subtitleMaxLines;
  final bool danger;

  /// A row that reports real state but opens nothing — neither tappable nor
  /// unfinished, so it carries no chip and no chevron.
  ///
  /// NOTHING on this screen is tappable yet, which is why there is no `onTap`
  /// at all: a parameter nobody passes is a parameter nobody checks. It comes
  /// back with the first row that has a destination.
  final bool available;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = danger ? ObsidianPalette.error : ObsidianPalette.onSurface;

    return Padding(
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
          // No chevron anywhere: a chevron promises a destination, and none
          // of these rows has one.
          if (!available) const NotYetChip(),
        ],
      ),
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
