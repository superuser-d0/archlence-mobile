/// The savings goals, on their own screen.
///
/// Read-only for now: `SavingsService` can open, fund, withdraw from and
/// delete a goal, and none of those has a form yet.
library;

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../services/savings_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/async_data.dart';
import '../widgets/savings_goal_card.dart';
import 'savings_sheets.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  Future<List<SavingsGoal>>? _goals;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _goals ??= ServicesScope.of(context).savings.getGoals();
  }

  void _reload() {
    setState(() {
      _goals = ServicesScope.of(context).savings.getGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        actions: [
          IconButton(
            onPressed: () async {
              final created = await showNewGoalSheet(context);
              if (created != null) _reload();
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          key: const PageStorageKey('savings'),
          padding: const EdgeInsets.fromLTRB(
            Spacing.containerMargin,
            Spacing.stackMd,
            Spacing.containerMargin,
            Spacing.stackLg,
          ),
          children: [
            Text(
              'Money in a goal is held aside from your balance. It is not '
              'spending, so it never appears in any expense chart.',
              style: text.bodySmall?.copyWith(
                color: ObsidianPalette.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.stackLg),
            AsyncData<List<SavingsGoal>>(
              future: _goals!,
              placeholderHeight: 200,
              builder: (context, goals) {
                if (goals.isEmpty) {
                  return const NothingYet(
                    message: 'No savings goals yet. Add one with the + above.',
                  );
                }
                return Column(
                  children: [
                    for (final goal in goals) ...[
                      SavingsGoalCard(
                        goal: goal,
                        onMoveMoney: () async {
                          final moved = await showMoveMoneySheet(context, goal);
                          if (moved ?? false) _reload();
                        },
                      ),
                      const SizedBox(height: Spacing.stackMd),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
