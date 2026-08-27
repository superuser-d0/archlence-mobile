/// Search: the Turkish folding, the ranking, and what the box actually finds.
///
/// The folding half is differential — every expectation comes from
/// `test/search_folding_vectors.txt`, which `tool/emit_search_folding.py`
/// produced by calling the desktop's own `normalize()`.
library;

import 'dart:io';

import 'package:archlence_mobile/crypto/field_crypto.dart';
import 'package:archlence_mobile/crypto/key_provider.dart';
import 'package:archlence_mobile/data/database.dart';
import 'package:archlence_mobile/services/account_service.dart';
import 'package:archlence_mobile/services/search_service.dart';
import 'package:archlence_mobile/services/transaction_service.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'support/fixed_key_provider.dart';

/// Turns the fixture's escapes back into the string the desktop was given.
String _unescape(String field) {
  final out = StringBuffer();
  for (var i = 0; i < field.length; i++) {
    if (field[i] != r'\') {
      out.write(field[i]);
      continue;
    }
    i++;
    switch (field[i]) {
      case 'n':
        out.write('\n');
      case 't':
        out.write('\t');
      case r'\':
        out.write(r'\');
      case 'u':
        out.writeCharCode(int.parse(field.substring(i + 1, i + 5), radix: 16));
        i += 4;
      default:
        throw FormatException('Unknown escape in vector: $field');
    }
  }
  return out.toString();
}

void main() {
  late ArchlenceDatabase db;
  late FieldCrypto crypto;
  late AccountService accounts;
  late TransactionService transactions;
  late SearchService search;

  setUp(() {
    db = ArchlenceDatabase.memory();
    crypto = FieldCrypto(FixedKeyProvider.arbitrary());
    accounts = AccountService(db, crypto);
    transactions = TransactionService(db, crypto, accounts);
    search = SearchService(db, crypto);
  });

  tearDown(() => db.close());

  group('folding parity with the desktop', () {
    final vectors = [
      for (final line in File(
        'test/search_folding_vectors.txt',
      ).readAsLinesSync())
        if (line.isNotEmpty && !line.startsWith('#')) line,
    ];

    test('the fixture covers the cases that actually break', () {
      expect(vectors, isNotEmpty);
      // Without the dotted/dotless pairs the whole file proves nothing: a
      // port that just lower-cased would pass everything else.
      expect(vectors.any((v) => v.startsWith('CASE|ISI|')), isTrue);
      expect(vectors.any((v) => v.startsWith('CASE|ısı|')), isTrue);
      expect(vectors.any((v) => v.startsWith('CASE|İSİ|')), isTrue);
    });

    test('every vector normalizes the way the desktop did', () {
      final cases = [for (final v in vectors) if (v.startsWith('CASE|')) v];
      expect(cases, isNotEmpty);
      for (final vector in cases) {
        final parts = vector.split('|');
        expect(parts.length, 3, reason: vector);
        final input = _unescape(parts[1]);
        expect(
          searchNormalize(input),
          _unescape(parts[2]),
          reason: 'input ${input.runes.map((r) => r.toRadixString(16))}',
        );
      }
    });

    test('and the cases it CANNOT are the ones the fixture names', () {
      // The folding table stops at U+3000, so a character above it passes
      // through. That is a real gap and it is measured rather than described:
      // the generator writes a DIVERGES line for every case where the desktop
      // and this port disagree, and this asserts the port lands exactly where
      // the fixture says it does. Widening the table deletes these lines, and
      // this test then fails until the fixture is regenerated.
      for (final vector in vectors) {
        if (!vector.startsWith('DIVERGES|')) continue;
        final parts = vector.split('|');
        expect(parts.length, 4, reason: vector);
        final input = _unescape(parts[1]);
        expect(searchNormalize(input), _unescape(parts[3]), reason: vector);
        expect(searchNormalize(input), isNot(_unescape(parts[2])));
      }
    });

    test('the Turkish i, in every direction it is written', () {
      // Spelled out as well as covered by the vectors: this is the reason the
      // whole folding table exists, and it deserves to fail by name.
      expect(searchNormalize('ISI'), searchNormalize('ısı'));
      expect(searchNormalize('İSİ'), searchNormalize('isi'));
      expect(searchNormalize('İstanbul'), 'istanbul');
      expect(searchNormalize('IŞIK'), searchNormalize('ışık'));
    });
  });

  group('ranking', () {
    SearchHit named(String name) => SearchHit(
      kind: SearchKind.account,
      id: 1,
      name: name,
      detail: '',
    );

    test('exact beats prefix beats contained', () {
      final hits = matchNames('nakit', [
        named('Nakit Olmayan'),
        named('Vadesiz Nakit Hesap'),
        named('Nakit'),
      ]);
      expect([for (final hit in hits) hit.name], [
        'Nakit',
        'Nakit Olmayan',
        'Vadesiz Nakit Hesap',
      ]);
    });

    test('a tie keeps the order it was given', () {
      final hits = matchNames('a', [named('Aa'), named('Ab'), named('Ac')]);
      expect([for (final hit in hits) hit.name], ['Aa', 'Ab', 'Ac']);
    });

    test('an empty query matches nothing, not everything', () {
      expect(matchNames('', [named('Nakit')]), isEmpty);
      expect(matchNames('   ', [named('Nakit')]), isEmpty);
    });
  });

  group('what the box finds', () {
    Future<int> account(String name) => accounts.createAccount(
      name: name,
      accountType: AccountType.checking,
      initialBalance: 0,
    );

    test('an account by name, typed without its accents', () async {
      await account('Şirket Hesabı');
      final hits = await search.search('sirket');
      expect(hits, hasLength(1));
      expect(hits.single.kind, SearchKind.account);
      expect(hits.single.name, 'Şirket Hesabı');
    });

    test('a seeded category, in either case', () async {
      final hits = await search.search('MAAS');
      expect(hits.any((hit) => hit.name == 'Maaş'), isTrue);
      expect(
        hits.firstWhere((hit) => hit.name == 'Maaş').kind,
        SearchKind.category,
      );
    });

    test('a transaction description, which is encrypted at rest', () async {
      final id = await account('Nakit');
      await transactions.addTransaction(
        accountId: id,
        amount: 120,
        transactionType: 'expense',
        category: 'Market',
        description: 'Kırtasiye alışverişi',
      );

      // Proves the row really is encrypted, so the match cannot have come
      // from SQL doing the work.
      final stored = await db
          .customSelect('SELECT description FROM transactions')
          .getSingle();
      expect(stored.read<String>('description'), startsWith('AEADv1:'));

      final hits = await search.search('kirtasiye');
      final hit = hits.singleWhere((h) => h.kind == SearchKind.transaction);
      expect(hit.name, 'Kırtasiye alışverişi');
      expect(hit.detail, 'Market');
    });

    test('an empty query returns nothing rather than the whole profile', () async {
      await account('Nakit');
      expect(await search.search(''), isEmpty);
      expect(await search.search('   '), isEmpty);
    });

    test('accounts come before categories', () async {
      // 'Kira' matches the account by prefix and the seeded 'Ev Kirası' by
      // containment; the kinds must not interleave by rank.
      await account('Kira Hesabı');
      final hits = await search.search('kira');
      final firstCategory = hits.indexWhere(
        (hit) => hit.kind == SearchKind.category,
      );
      expect(hits.first.kind, SearchKind.account);
      expect(
        hits.skip(firstCategory).every((hit) => hit.kind != SearchKind.account),
        isTrue,
      );
    });

    test('a credit card sorts below the ordinary accounts', () async {
      await accounts.createAccount(
        name: 'Ortak Kart',
        accountType: AccountType.creditCard,
        initialBalance: 0,
        creditLimit: 10000,
      );
      await account('Ortak Hesap');

      final hits = await search.search('ortak');
      expect([for (final hit in hits) hit.name], [
        'Ortak Hesap',
        'Ortak Kart',
      ]);
    });

    test('the limit is honoured across all three kinds', () async {
      for (var i = 0; i < 6; i++) {
        await account('Test Hesap $i');
      }
      final hits = await search.search('test', limit: 4);
      expect(hits, hasLength(4));
    });

    test('a description that will not decrypt is skipped, not fatal', () async {
      final id = await account('Nakit');
      await transactions.addTransaction(
        accountId: id,
        amount: 10,
        transactionType: 'expense',
        category: 'Market',
        description: 'Kırtasiye alışverişi',
      );
      await transactions.addTransaction(
        accountId: id,
        amount: 20,
        transactionType: 'expense',
        category: 'Market',
        description: 'Kırtasiye defteri',
      );
      // Corrupt exactly one envelope.
      await db.customUpdate(
        'UPDATE transactions SET description = ? WHERE id = '
        '(SELECT MIN(id) FROM transactions)',
        variables: [Variable<String>('AEADv1:not-an-envelope')],
        updates: const {},
      );

      // Scoped to transactions: 'Kitap/Kırtasiye' is a seeded CATEGORY and
      // matches this query too, which is correct and not what is being
      // asserted here.
      final hits = [
        for (final hit in await search.search('kirtasiye'))
          if (hit.kind == SearchKind.transaction) hit,
      ];
      // The readable one still comes back. One broken row must not make the
      // box useless.
      expect(hits, hasLength(1));
      expect(hits.single.name, 'Kırtasiye defteri');
    });

    test('a missing key stops the search rather than reporting nothing', () async {
      final id = await account('Nakit');
      await transactions.addTransaction(
        accountId: id,
        amount: 10,
        transactionType: 'expense',
        category: 'Market',
        description: 'Kırtasiye alışverişi',
      );

      // A different service graph over the same database, whose key provider
      // has nothing to give. "No results" here would say the profile is empty
      // when it is only locked.
      final locked = SearchService(db, FieldCrypto(UnavailableKeyProvider()));
      expect(
        () => locked.search('kirtasiye'),
        throwsA(isA<KeyUnavailableError>()),
      );
    });

    test('only the recent window is opened', () async {
      final id = await account('Nakit');
      await transactions.addTransaction(
        accountId: id,
        amount: 10,
        transactionType: 'expense',
        category: 'Market',
        description: 'Eski kayıt',
        transactionDate: DateTime(2019, 1, 1),
      );
      await transactions.addTransaction(
        accountId: id,
        amount: 20,
        transactionType: 'expense',
        category: 'Market',
        description: 'Yeni kayıt',
      );

      // A window of one reaches only the newest row.
      final narrow = await search.searchTransactions('kayit', window: 1);
      expect(narrow, hasLength(1));
      expect(narrow.single.name, 'Yeni kayıt');

      final wide = await search.searchTransactions('kayit', window: 500);
      expect([for (final hit in wide) hit.name], ['Yeni kayıt', 'Eski kayıt']);
    });
  });
}
