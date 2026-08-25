import 'package:flutter/material.dart';

import '../theme/obsidian_prime.dart';
import '../widgets/not_yet.dart';
import '../widgets/surfaces.dart';
import 'budget_screen.dart';
import 'savings_screen.dart';

/// The financial tools launcher. Mirrors the desktop app's Tools tab.
///
/// A tool with nothing behind it is drawn as UNAVAILABLE rather than left
/// tappable. A card that looks live and does nothing on tap is a defect the
/// user has no way to tell from a slow one, and seven of these nine have no
/// port yet.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  static const _tools = <_Tool>[
    _Tool(
      'Monthly\nBudget',
      Icons.calendar_month_outlined,
      ObsidianPalette.primary,
      destination: _Destination.budget,
    ),
    _Tool('Calendar', Icons.event_note_outlined, ObsidianPalette.tertiary),
    _Tool('Calculator', Icons.calculate_outlined, ObsidianPalette.primary),
    _Tool('Interest\nReturn', Icons.percent, ObsidianPalette.secondary),
    _Tool('Compound\nInterest', Icons.trending_up, ObsidianPalette.tertiary),
    _Tool(
      'Loan\nCalculator',
      Icons.account_balance_outlined,
      ObsidianPalette.error,
    ),
    _Tool(
      'Savings\nGoal',
      Icons.savings_outlined,
      ObsidianPalette.secondary,
      destination: _Destination.savings,
    ),
    _Tool('What-If\nSandbox', Icons.explore_outlined, ObsidianPalette.primary),
    _Tool(
      'Reset\nData',
      Icons.delete_outline,
      ObsidianPalette.error,
      destructive: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final inset = MediaQuery.paddingOf(context);

    return ListView(
      key: const PageStorageKey('tools'),
      padding: EdgeInsets.fromLTRB(
        Spacing.containerMargin,
        inset.top + Spacing.stackLg,
        Spacing.containerMargin,
        inset.bottom + Spacing.stackLg,
      ),
      children: [
        Text('Financial Tools', style: text.headlineMedium),
        const SizedBox(height: Spacing.stackSm),
        Text(
          'Explore calculators and planners to optimize your finances.',
          style: text.bodyMedium?.copyWith(
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.stackLg),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _tools.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: Spacing.gutter,
            crossAxisSpacing: Spacing.gutter,
            // Tall enough for a two-line label without clipping.
            mainAxisExtent: 168,
          ),
          itemBuilder: (context, index) => _ToolCard(tool: _tools[index]),
        ),
      ],
    );
  }
}

/// Which screen a tool opens. Absent means it has no port yet.
enum _Destination { budget, savings }

class _Tool {
  const _Tool(
    this.label,
    this.icon,
    this.accent, {
    this.destructive = false,
    this.destination,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool destructive;
  final _Destination? destination;

  bool get isAvailable => destination != null;
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});

  final _Tool tool;

  void _open(BuildContext context) {
    final builder = switch (tool.destination) {
      _Destination.budget => (BuildContext _) => const BudgetScreen(),
      _Destination.savings => (BuildContext _) => const SavingsScreen(),
      null => null,
    };
    if (builder == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final available = tool.isAvailable;
    // Dimmed rather than hidden: the grid is the desktop's tool set, and
    // dropping the unported ones would misrepresent what the app is for.
    final accent = available
        ? tool.accent
        : tool.accent.withValues(alpha: 0.35);

    return AppCard(
      padding: const EdgeInsets.all(Spacing.gutter),
      onTap: available ? () => _open(context) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(tool.icon, size: 22, color: accent),
              ),
              const Spacer(),
              if (!available) const NotYetChip(),
            ],
          ),
          const Spacer(),
          Text(
            tool.label,
            style: text.titleLarge?.copyWith(
              color: !available
                  ? ObsidianPalette.onSurfaceVariant
                  : tool.destructive
                  ? ObsidianPalette.error
                  : ObsidianPalette.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
