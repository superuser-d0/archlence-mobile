/// Search over account names, category names and transaction descriptions.
///
/// A port of the desktop's `services/search_service.py`.
///
/// **Ported from its CODE, not its header.** That file opens by saying
/// transaction descriptions are out of scope and that searching them is a cost
/// this round does not take — and then defines `search_transactions` and calls
/// it from `search`. The docstring is older than the function underneath it.
/// Following the prose would have shipped a search that silently found less
/// than the desktop's; following the code costs a decrypt of a bounded window,
/// which is what the desktop actually pays. This is the same shape of mistake
/// as the R8 entry in the roadmap: a claim in a file is not the file's
/// behaviour.
///
/// **Turkish folding is the real work here,** and it is why this file exists
/// rather than a `contains` at each call site. `"I".toLowerCase()` is `"i"`
/// but `"ı".toLowerCase()` stays `"ı"`, so a user typing "ISI" would never
/// find "ısı"; `"İ"` lowercases to an `i` followed by a combining dot, which
/// is not equal to an `i`. [searchNormalize] brings all of them to one place,
/// through a table generated from the desktop's own function — see
/// `search_folding.dart`.
///
/// **A row that will not decrypt is skipped, but a missing KEY is not.** One
/// unreadable description must not make the search box useless; a key that is
/// gone is not a row problem, and it propagates. The desktop draws the line in
/// the same place.
library;

import 'package:drift/drift.dart';

import '../crypto/field_crypto.dart';
import '../crypto/key_provider.dart';
import '../data/database.dart';
import 'search_folding.dart';

/// What a hit points at.
enum SearchKind { account, category, transaction }

/// One result, in the order the search decided.
class SearchHit {
  const SearchHit({
    required this.kind,
    required this.id,
    required this.name,
    required this.detail,
    this.date,
  });

  final SearchKind kind;

  /// The row's id, or null for a category — the desktop returns categories
  /// without one because nothing navigates to a category by id.
  final int? id;

  /// What matched: the account's name, the category's name, or the
  /// transaction's description.
  final String name;

  /// The account's type, the category's side, or the transaction's category.
  final String detail;

  /// The transaction's stored date. Null for the other two kinds.
  final String? date;
}

/// How many results a search returns at most.
const int searchDefaultLimit = 20;

/// How many recent transactions have their description decrypted and checked.
///
/// The window is the whole reason descriptions can be searched at all: they
/// are AES-encrypted, so the filter cannot be pushed into SQL, and a profile
/// with 50,000 transactions would take about a second to open all of them (the
/// desktop measured it). Ordering and windowing happen in SQL over the plain
/// `transaction_date`; only these rows are decrypted.
const int searchDescriptionWindow = 500;

/// Reduces [text] to one comparable form.
///
/// The steps are the desktop's, in its order: fold case, decompose accents and
/// drop them, map dotless `ı` onto `i`, then collapse runs of whitespace. The
/// first three are a table lookup per character — see `search_folding.dart`,
/// which is generated and carries the proof that folding character by
/// character gives the same answer as the whole-string function it came from.
String searchNormalize(String? text) {
  if (text == null || text.isEmpty) return '';

  final folded = StringBuffer();
  for (final rune in text.runes) {
    if (rune < searchFoldingCoveredBelow) {
      folded.write(searchFolding[rune] ?? String.fromCharCode(rune));
    } else {
      folded.write(String.fromCharCode(rune));
    }
  }

  // Collapse on the whitespace set the desktop's `str.split()` uses, not on
  // Dart's ASCII-only `\s`: a non-breaking space left in the middle of a name
  // would make it unfindable by anyone typing an ordinary one.
  final out = StringBuffer();
  var pendingSpace = false;
  var wroteAnything = false;
  for (final rune in folded.toString().runes) {
    if (searchWhitespace.contains(rune)) {
      pendingSpace = wroteAnything;
      continue;
    }
    if (pendingSpace) {
      out.write(' ');
      pendingSpace = false;
    }
    out.writeCharCode(rune);
    wroteAnything = true;
  }
  return out.toString();
}

/// How good a match is: 0 exact, 1 prefix, 2 contained, null for none.
///
/// The ranking exists so that typing "Nakit" puts "Nakit" above "Nakit
/// Olmayan". A plain containment check does not give that order, and the first
/// result is the one a user reaches for.
int? searchRank(String needle, String haystack) {
  if (needle.isEmpty) return null;
  if (haystack == needle) return 0;
  if (haystack.startsWith(needle)) return 1;
  if (haystack.contains(needle)) return 2;
  return null;
}

/// Ranks [items] by name against [query], best first.
///
/// Pure, so it is testable without a database — the desktop split it out for
/// the same reason. An EMPTY query matches nothing rather than everything:
/// focusing the search box must not dump the whole profile onto the screen.
///
/// Ties keep their input order, which is why the caller's `ORDER BY` matters.
List<SearchHit> matchNames(String query, List<SearchHit> items) {
  final needle = searchNormalize(query);
  if (needle.isEmpty) return const [];

  final scored = <(int, int, SearchHit)>[];
  for (var position = 0; position < items.length; position++) {
    final rank = searchRank(needle, searchNormalize(items[position].name));
    if (rank == null) continue;
    scored.add((rank, position, items[position]));
  }
  scored.sort((a, b) {
    final byRank = a.$1.compareTo(b.$1);
    return byRank != 0 ? byRank : a.$2.compareTo(b.$2);
  });
  return [for (final (_, _, hit) in scored) hit];
}

class SearchService {
  SearchService(this._db, this._crypto);

  final ArchlenceDatabase _db;
  final FieldCrypto _crypto;

  /// Accounts and categories by name, then descriptions to fill the rest.
  ///
  /// An empty or whitespace-only query returns nothing at all.
  Future<List<SearchHit>> search(
    String query, {
    int limit = searchDefaultLimit,
  }) async {
    final needle = searchNormalize(query);
    if (needle.isEmpty) return const [];

    final accountRows = await _db
        .customSelect(
          'SELECT id, name, account_type FROM accounts ORDER BY '
          "CASE WHEN account_type = 'credit_card' THEN 1 ELSE 0 END, id",
        )
        .get();
    final accounts = [
      for (final row in accountRows)
        SearchHit(
          kind: SearchKind.account,
          id: row.read<int>('id'),
          name: row.read<String>('name'),
          detail: row.data['account_type'] as String? ?? '',
        ),
    ];

    final categoryRows = await _db
        .customSelect('SELECT name, type FROM categories ORDER BY name')
        .get();
    final categories = [
      for (final row in categoryRows)
        SearchHit(
          kind: SearchKind.category,
          id: null,
          name: row.read<String>('name'),
          detail: row.data['type'] as String? ?? '',
        ),
    ];

    final results = [
      ...matchNames(query, accounts),
      ...matchNames(query, categories),
    ];
    if (results.length < limit) {
      results.addAll(
        await searchTransactions(query, limit: limit - results.length),
      );
    }
    return results.length <= limit ? results : results.sublist(0, limit);
  }

  /// The descriptions of the most recent [window] transactions.
  Future<List<SearchHit>> searchTransactions(
    String query, {
    int limit = searchDefaultLimit,
    int window = searchDescriptionWindow,
  }) async {
    final needle = searchNormalize(query);
    if (needle.isEmpty) return const [];

    final rows = await _db
        .customSelect(
          'SELECT id, account_id, description, category, transaction_date '
          'FROM transactions WHERE description IS NOT NULL '
          'ORDER BY date(transaction_date) DESC, id DESC LIMIT ?',
          variables: [Variable<int>(window)],
        )
        .get();

    final results = <SearchHit>[];
    for (final row in rows) {
      final String? description;
      try {
        description = await _crypto.decryptField(row.data['description']);
      } on KeyUnavailableError {
        // Not a row problem. Every description is unreadable, and reporting
        // "no results" would say the profile is empty when it is locked.
        rethrow;
      } on Exception {
        // One broken or pre-migration row must not make the box unusable.
        continue;
      }
      if (searchRank(needle, searchNormalize(description)) == null) continue;

      results.add(
        SearchHit(
          kind: SearchKind.transaction,
          id: row.read<int>('id'),
          name: description ?? '',
          detail: row.data['category'] as String? ?? '',
          date: row.data['transaction_date'] as String?,
        ),
      );
      if (results.length >= limit) break;
    }
    return results;
  }
}
