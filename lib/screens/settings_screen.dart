import 'package:flutter/material.dart';

import '../theme/obsidian_prime.dart';
import '../widgets/surfaces.dart';

/// Settings, grouped into sections rather than one flat list.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _premiumTheme = true;
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
            _SettingsTile(
              icon: Icons.sell_outlined,
              title: 'Category Settings',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: 'English',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.vpn_key_outlined,
              title: 'Encryption Key',
              // Deliberately allowed to wrap. The reference truncates this
              // with an ellipsis, which hides WHERE the key is stored and how
              // well it is protected — the one line on this screen a user most
              // needs to read in full.
              subtitle:
                  'owner-only file — OS key store unavailable; key kept '
                  'in a local file with 0600 permissions.',
              subtitleMaxLines: 3,
              onTap: () {},
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
            _SettingsTile(
              icon: Icons.palette_outlined,
              title: 'Premium Blue Theme',
              subtitle: 'Uses the standard theme when disabled',
              trailing: Switch(
                value: _premiumTheme,
                onChanged: (v) => setState(() => _premiumTheme = v),
              ),
            ),
            _SettingsTile(
              icon: Icons.shield_outlined,
              title: 'Data & Privacy',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: Spacing.sectionGap),

        const SectionLabel('Security & History'),
        const SizedBox(height: Spacing.stackSm),
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'You can renew your password here.',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.history,
              title: 'Balance History',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: Spacing.sectionGap),

        const SectionLabel('System'),
        const SizedBox(height: Spacing.stackSm),
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark Mode',
              trailing: Switch(
                value: _darkMode,
                onChanged: (v) => setState(() => _darkMode = v),
              ),
            ),
            _SettingsTile(
              icon: Icons.mail_outline,
              title: 'Contact Us',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.logout,
              title: 'Sign Out',
              danger: true,
              onTap: () {},
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
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int subtitleMaxLines;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = danger ? ObsidianPalette.error : ObsidianPalette.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    (danger ? ObsidianPalette.error : ObsidianPalette.primary)
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
                  Text(title, style: text.bodyMedium?.copyWith(color: tint)),
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
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: danger
                    ? ObsidianPalette.error
                    : ObsidianPalette.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
