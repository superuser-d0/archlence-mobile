import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'screens/add_transaction_sheet.dart';
import 'screens/assets_screen.dart';
import 'screens/cards_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tools_screen.dart';
import 'theme/obsidian_prime.dart';
import 'ui/app_locale.dart';
import 'widgets/not_yet.dart';
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

/// Lets a screen inside the shell move the shell to another tab.
///
/// Search needs it and nothing else does yet: a result the user taps has to
/// take them where that thing LIVES, and an account lives on Cards. Passing a
/// callback down through Home's whole widget tree would put a parameter on
/// every widget between here and the field; an inherited scope puts it only
/// where it is read. [AppShell] is above the Navigator, so this survives a
/// pushed screen the way `ServicesScope` deliberately does not.
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    required this.selectTab,
    required super.child,
    super.key,
  });

  /// Moves the shell to [index]. Out-of-range values are ignored rather than
  /// throwing: the caller is a UI event, not a contract.
  final void Function(int index) selectTab;

  static AppShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellScope>();

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      selectTab != oldWidget.selectTab;
}

/// The tab indices the shell draws, named so a caller does not pass a bare
/// integer that silently means something else after a reorder.
abstract final class ShellTab {
  static const int home = 0;
  static const int assets = 1;
  static const int cards = 2;
  static const int tools = 3;
  static const int settings = 4;
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  /// Bumped after a write, so the visible tab reloads.
  ///
  /// The tabs keep their own futures and have no way to know a sheet opened
  /// over them changed something; rebuilding them under a new key is the
  /// smallest thing that makes a recorded transaction appear without each
  /// screen growing a subscription to the database.
  int _revision = 0;

  void _selectTab(int index) {
    if (index < 0 || index > 4 || index == _tab) return;
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return AppShellScope(
      selectTab: _selectTab,
      child: Scaffold(
        extendBody: true,
        // `extendBodyBehindAppBar` lays the body out FIRST, because it sits
        // behind the header — and semantics traversal follows that order, so
        // a screen reader read the whole screen before it said which app it
        // was in. Found with TalkBack actually running; no guideline checks
        // reading order. The sort keys put it back: header, body, action,
        // tabs.
        extendBodyBehindAppBar: true,
        appBar: const _GlassHeader(),
        // Recording a transaction is the app's most frequent action, so it gets
        // the one floating button. Cards deliberately has none — the reference
        // design put one there on top of its own "+ ADD" and it landed on the
        // Freeze Card switch.
        floatingActionButton: _tab == 3 || _tab == 4
            ? null
            : Semantics(
                sortKey: const OrdinalSortKey(2),
                child: FloatingActionButton(
                  // A tooltip, which is also the SEMANTIC LABEL: this button is
                  // an icon and nothing else, so without one a screen reader
                  // announces the app's most-used control as "button".
                  tooltip: context.l10n.a11yRecordTransaction,
                  onPressed: () async {
                    final recorded = await showAddTransactionSheet(context);
                    if (recorded != null) setState(() => _revision++);
                  },
                  child: const Icon(Icons.add),
                ),
              ),
        // Both bars are translucent and sit ON TOP of the body, so the body's
        // own inset must grow by their height — otherwise the first and last
        // items of every screen scroll underneath them and are unreachable.
        // Screens read this back through `MediaQuery.paddingOf`.
        body: Semantics(
          sortKey: const OrdinalSortKey(1),
          explicitChildNodes: true,
          child: MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(
                top: media.padding.top + kToolbarHeight,
                bottom: media.padding.bottom + _navBarHeight,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey('$_tab-$_revision'),
              child: switch (_tab) {
                0 => const HomeScreen(),
                1 => const AssetsScreen(),
                2 => const CardsScreen(),
                3 => const ToolsScreen(),
                _ => const SettingsScreen(),
              },
            ),
          ),
        ),
        bottomNavigationBar: Semantics(
          sortKey: const OrdinalSortKey(3),
          explicitChildNodes: true,
          child: GlassBar(
            border: const Border(
              top: BorderSide(color: ObsidianPalette.cardStroke),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              selectedIndex: _tab,
              onDestinationSelected: _selectTab,
              destinations: _destinations(context),
            ),
          ),
        ),
      ),
    );
  }
}

List<NavigationDestination> _destinations(BuildContext context) {
  final l10n = context.l10n;
  return [
    NavigationDestination(
      icon: const Icon(Icons.home_outlined),
      selectedIcon: const Icon(Icons.home),
      label: l10n.navHome,
    ),
    NavigationDestination(
      icon: const Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: const Icon(Icons.account_balance_wallet),
      label: l10n.navAssets,
    ),
    NavigationDestination(
      icon: const Icon(Icons.credit_card_outlined),
      selectedIcon: const Icon(Icons.credit_card),
      label: l10n.navCards,
    ),
    NavigationDestination(
      icon: const Icon(Icons.grid_view_outlined),
      selectedIcon: const Icon(Icons.grid_view),
      label: l10n.navTools,
    ),
    NavigationDestination(
      icon: const Icon(Icons.settings_outlined),
      selectedIcon: const Icon(Icons.settings),
      label: l10n.navSettings,
    ),
  ];
}

class _GlassHeader extends StatelessWidget implements PreferredSizeWidget {
  const _GlassHeader();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      sortKey: const OrdinalSortKey(0),
      explicitChildNodes: true,
      child: GlassBar(
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
                  // Nothing raises a notification yet, so this follows the
                  // same rule as every other unbuilt feature — see
                  // `showUnbuiltFeatures`. It stayed behind when the rest were
                  // removed, and a TalkBack round is where that showed: in the
                  // semantics tree it is a BUTTON with no label and no action,
                  // which a screen reader announces as an unnamed disabled
                  // control. The `SizedBox` keeps the title centred, since the
                  // avatar on the left is 32 wide inside a 48 tap target.
                  if (showUnbuiltFeatures)
                    const IconButton(
                      onPressed: null,
                      icon: Icon(Icons.notifications_outlined),
                    )
                  else
                    const SizedBox(width: 32, height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
