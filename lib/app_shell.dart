import 'package:flutter/material.dart';

import 'screens/assets_screen.dart';
import 'screens/cards_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tools_screen.dart';
import 'theme/obsidian_prime.dart';
import 'widgets/surfaces.dart';

/// The five-tab shell: a glass header and bottom bar with content scrolling
/// underneath both.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

/// Height of the [NavigationBar], mirroring `navigationBarTheme.height`.
const _navBarHeight = 68.0;

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: const _GlassHeader(),
      // Both bars are translucent and sit ON TOP of the body, so the body's
      // own inset must grow by their height — otherwise the first and last
      // items of every screen scroll underneath them and are unreachable.
      // Screens read this back through `MediaQuery.paddingOf`.
      body: MediaQuery(
        data: media.copyWith(
          padding: media.padding.copyWith(
            top: media.padding.top + kToolbarHeight,
            bottom: media.padding.bottom + _navBarHeight,
          ),
        ),
        child: switch (_tab) {
          0 => const HomeScreen(),
          1 => const AssetsScreen(),
          2 => const CardsScreen(),
          3 => const ToolsScreen(),
          _ => const SettingsScreen(),
        },
      ),
      bottomNavigationBar: GlassBar(
        border: const Border(
          top: BorderSide(color: ObsidianPalette.cardStroke),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: _destinations,
        ),
      ),
    );
  }
}

const _destinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  NavigationDestination(
    icon: Icon(Icons.account_balance_wallet_outlined),
    selectedIcon: Icon(Icons.account_balance_wallet),
    label: 'Assets',
  ),
  NavigationDestination(
    icon: Icon(Icons.credit_card_outlined),
    selectedIcon: Icon(Icons.credit_card),
    label: 'Cards',
  ),
  NavigationDestination(
    icon: Icon(Icons.grid_view_outlined),
    selectedIcon: Icon(Icons.grid_view),
    label: 'Tools',
  ),
  NavigationDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: 'Settings',
  ),
];

class _GlassHeader extends StatelessWidget implements PreferredSizeWidget {
  const _GlassHeader();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return GlassBar(
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.containerMargin,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: ObsidianPalette.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 18,
                    color: ObsidianPalette.onPrimary,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Archlence',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_outlined),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
