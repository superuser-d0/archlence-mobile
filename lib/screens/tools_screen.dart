import 'package:flutter/material.dart';

import '../theme/obsidian_prime.dart';
import '../widgets/surfaces.dart';

/// The financial tools launcher. Mirrors the desktop app's Tools tab.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  static const _tools = <_Tool>[
    _Tool('Monthly\nBudget', Icons.calendar_month_outlined,
        ObsidianPalette.primary),
    _Tool('Calendar', Icons.event_note_outlined, ObsidianPalette.tertiary),
    _Tool('Calculator', Icons.calculate_outlined, ObsidianPalette.primary),
    _Tool('Interest\nReturn', Icons.percent, ObsidianPalette.secondary),
    _Tool('Compound\nInterest', Icons.trending_up, ObsidianPalette.tertiary),
    _Tool('Loan\nCalculator', Icons.account_balance_outlined,
        ObsidianPalette.error),
    _Tool('Savings\nGoal', Icons.savings_outlined, ObsidianPalette.secondary),
    _Tool('What-If\nSandbox', Icons.explore_outlined, ObsidianPalette.primary),
    _Tool('Reset\nData', Icons.delete_outline, ObsidianPalette.error,
        destructive: true),
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
          style: text.bodyMedium
              ?.copyWith(color: ObsidianPalette.onSurfaceVariant),
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

class _Tool {
  const _Tool(this.label, this.icon, this.accent, {this.destructive = false});

  final String label;
  final IconData icon;
  final Color accent;
  final bool destructive;
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});

  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Spacing.gutter),
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tool.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(tool.icon, size: 22, color: tool.accent),
          ),
          const Spacer(),
          Text(
            tool.label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: tool.destructive
                      ? ObsidianPalette.error
                      : ObsidianPalette.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}
