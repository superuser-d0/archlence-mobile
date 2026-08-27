/// Which categories the household must pay, and which it chooses to.
///
/// The desktop's category settings screen, and exactly as much of it: a list
/// with one switch per row writing `categories.importance`. There is no add,
/// no rename and no delete here because there is none there either — see
/// `CategoryService` for why inventing them would be worse than leaving them
/// out.
///
/// **The switch is written straight through, with no Save button.** Every
/// other write in this app goes through a form because it moves money or
/// creates a row that has to balance; this one flips a flag on a row that
/// already exists, and a screen of sixty switches behind a single Save is a
/// screen where a user changes three, leaves, and loses all three. The row
/// reverts and says so if the write does not land.
library;

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../services/category_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/async_data.dart';
import '../widgets/surfaces.dart';

class CategorySettingsScreen extends StatefulWidget {
  const CategorySettingsScreen({super.key});

  @override
  State<CategorySettingsScreen> createState() => _CategorySettingsScreenState();
}

class _CategorySettingsScreenState extends State<CategorySettingsScreen> {
  Future<List<Category>>? _categories;

  /// The switches the user has moved since the load, by category name.
  ///
  /// Held here rather than by mutating the loaded list: the future is the
  /// source of truth for what is IN the table, and a failed write has to be
  /// able to fall back to it.
  final Map<String, bool> _pending = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _categories ??= ServicesScope.of(context).categories.getCategories();
  }

  Future<void> _setImportance(Category category, bool isMain) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pending[category.name] = isMain);

    final wrote = await ServicesScope.of(context).categories
        .setImportance(category.name, isMain: isMain);
    if (!mounted) return;
    if (wrote) return;

    // The row went away underneath — a restore, most likely. Put the switch
    // back where the table says it is rather than leaving it showing a change
    // that did not happen.
    setState(() => _pending.remove(category.name));
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.categorySettingsWriteFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categorySettingsTitle)),
      body: ListView(
        key: const PageStorageKey('category-settings'),
        padding: EdgeInsets.fromLTRB(
          contentInset(context),
          Spacing.stackMd,
          contentInset(context),
          MediaQuery.paddingOf(context).bottom + Spacing.stackLg,
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(Spacing.gutter),
            child: Text(
              l10n.categorySettingsExplainer,
              style: text.bodyMedium?.copyWith(
                color: ObsidianPalette.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: Spacing.stackLg),
          AsyncData<List<Category>>(
            future: _categories!,
            placeholderHeight: 400,
            builder: (context, categories) => _CategoryList(
              categories: categories,
              isMain: (category) => _pending[category.name] ?? category.isMain,
              onChanged: _setImportance,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.isMain,
    required this.onChanged,
  });

  final List<Category> categories;
  final bool Function(Category) isMain;
  final void Function(Category, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final income = [
      for (final c in categories)
        if (c.isIncome) c,
    ];
    final expense = [
      for (final c in categories)
        if (!c.isIncome) c,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.categorySettingsIncome),
        const SizedBox(height: Spacing.stackSm),
        _Group(categories: income, isMain: isMain, onChanged: onChanged),
        const SizedBox(height: Spacing.sectionGap),
        SectionLabel(l10n.categorySettingsExpense),
        const SizedBox(height: Spacing.stackSm),
        _Group(categories: expense, isMain: isMain, onChanged: onChanged),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.categories,
    required this.isMain,
    required this.onChanged,
  });

  final List<Category> categories;
  final bool Function(Category) isMain;
  final void Function(Category, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final category in categories)
            _CategoryRow(
              category: category,
              isMain: isMain(category),
              onChanged: (value) => onChanged(category, value),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.isMain,
    required this.onChanged,
  });

  final Category category;
  final bool isMain;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.gutter,
        vertical: 6,
      ),
      // MERGED, so the row is one thing to a screen reader.
      //
      // Without this the switch is a node of its own: sixty identical
      // controls announced as "on, switch", with the category's name in a
      // separate node beside them and nothing joining the two.
      //
      // The first attempt wrote a label by hand onto a `Semantics` wrapper
      // and put `ExcludeSemantics` around the switch, so a reader would not
      // hear the state twice. It read beautifully and it removed the switch's
      // TAP ACTION — leaving the row unreachable to exactly the assistive tech
      // it was meant to serve, and PASSING the guideline, because a node that
      // is not tappable cannot be an unlabelled tappable node.
      //
      // The mutation check is what caught it: deleting the label left the
      // suite green. Merging instead keeps the action and reads the name, the
      // side word and the state as one thing.
      child: MergeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.name, style: text.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    // The word changes with the side: a salary is a main income
                    // and rent is an essential expense, and calling rent "main"
                    // would be the desktop's column leaking into the screen.
                    isMain
                        ? (category.isIncome
                              ? l10n.categoryMainIncome
                              : l10n.categoryEssentialExpense)
                        : (category.isIncome
                              ? l10n.categoryExtraIncome
                              : l10n.categoryExtraExpense),
                    style: text.bodySmall?.copyWith(
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: isMain, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
