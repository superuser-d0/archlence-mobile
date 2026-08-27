/// The category list and the one write it allows.
library;

import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/data/default_categories.dart';
import 'package:archlence_mobile/services/category_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ArchlenceDatabase db;
  late CategoryService categories;

  setUp(() {
    db = ArchlenceDatabase.memory();
    categories = CategoryService(db);
  });

  tearDown(() => db.close());

  Future<String?> storedImportance(String name) async {
    final rows = await db
        .customSelect(
          'SELECT importance FROM categories WHERE name = ?',
          variables: [Variable<String>(name)],
        )
        .get();
    return rows.isEmpty ? null : rows.single.data['importance'] as String?;
  }

  group('the list', () {
    test('carries every seeded category, and nothing invented', () async {
      final listed = await categories.getCategories();
      expect(listed.length, defaultCategories.length);
      expect(
        listed.map((category) => category.name).toSet(),
        defaultCategories.map((seed) => seed.$1).toSet(),
      );
    });

    test('reports the importance the seed wrote, not a default', () async {
      final listed = await categories.getCategories();
      final byName = {for (final c in listed) c.name: c};
      // The seed is not all one value — if it were, this test would pass with
      // `isMain` hard-coded either way.
      expect(listed.any((c) => c.isMain), isTrue);
      expect(listed.any((c) => !c.isMain), isTrue);
      for (final (name, _, importance) in defaultCategories) {
        expect(
          byName[name]!.isMain,
          importance == mainImportance,
          reason: name,
        );
      }
    });

    test('income comes before expense, and the seed order survives', () async {
      final listed = await categories.getCategories();
      final firstExpense = listed.indexWhere((c) => !c.isIncome);
      expect(firstExpense, greaterThan(0));
      expect(
        listed.take(firstExpense).every((c) => c.isIncome),
        isTrue,
        reason: 'an expense appeared among the income categories',
      );
      expect(
        listed.skip(firstExpense).any((c) => c.isIncome),
        isFalse,
        reason: 'an income category appeared after the expenses started',
      );
      // Seed order, not alphabetical: the desktop puts the ones a household
      // uses at the top, and sorting by name would bury them.
      final seededIncome = [
        for (final (name, type, _) in defaultCategories)
          if (type == 'income') name,
      ];
      expect(listed.take(firstExpense).map((c) => c.name), seededIncome);
    });
  });

  group('the switch', () {
    test('writes the column the summary reads', () async {
      final name = defaultCategories
          .firstWhere((seed) => seed.$3 != mainImportance)
          .$1;
      expect(await categories.setImportance(name, isMain: true), isTrue);
      expect(await storedImportance(name), mainImportance);

      expect(await categories.setImportance(name, isMain: false), isTrue);
      expect(await storedImportance(name), extraImportance);
    });

    test('touches only the category named', () async {
      final before = await categories.getCategories();
      final target = before.firstWhere((c) => !c.isMain);
      await categories.setImportance(target.name, isMain: true);

      final after = {
        for (final c in await categories.getCategories()) c.name: c.isMain,
      };
      for (final category in before) {
        expect(
          after[category.name],
          category.name == target.name ? true : category.isMain,
          reason: category.name,
        );
      }
    });

    test('a name with no row reports the miss instead of throwing', () async {
      expect(
        await categories.setImportance('no such category', isMain: true),
        isFalse,
      );
    });
  });
}
