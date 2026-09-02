import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../services/account_service.dart';
import '../services/transaction_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/app_locale.dart';
import '../ui/async_data.dart';
import '../ui/money_format.dart';
import 'add_account_sheet.dart';
import 'pay_debt_sheet.dart';
import '../widgets/summary_row.dart';
import '../widgets/surfaces.dart';

part 'cards_screen_face.dart';
part 'cards_screen_detail.dart';
part 'cards_screen_transactions.dart';

/// Cards and accounts.
class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

/// Everything this screen draws, read in one pass.
///
/// One load rather than a future per card: the summary row, the carousel and
/// the account list all describe the SAME set of accounts, and loading them
/// separately would let the header disagree with the list below it while the
/// second query was still running.
class _CardsData {
  const _CardsData({
    required this.cards,
    required this.checkingAccounts,
    required this.netWorth,
    required this.holdingsCost,
    required this.holdingsCount,
  });

  final List<Account> cards;
  final List<Account> checkingAccounts;
  final NetWorth netWorth;

  /// What the holdings COST, not what they are worth. There is no price
  /// source yet (roadmap open question 3), and labelling a cost basis as a
  /// market value would be a lie the user cannot see through.
  final Decimal holdingsCost;
  final int holdingsCount;
}

class _CardsScreenState extends State<CardsScreen> {
  final _controller = PageController(viewportFraction: 0.88);
  int _index = 0;
  Future<_CardsData>? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  Future<_CardsData> _load() async {
    final services = ServicesScope.of(context);
    final accounts = await services.accounts.getAccounts();
    final holdings = await services.assets.getAllAssets();

    var cost = Decimal.zero;
    for (final holding in holdings) {
      cost += holding.purchasePrice * holding.quantity;
    }

    return _CardsData(
      cards: [
        for (final account in accounts)
          if (account.accountType == AccountType.creditCard) account,
      ],
      checkingAccounts: [
        for (final account in accounts)
          if (account.accountType == AccountType.checking) account,
      ],
      netWorth: await services.accounts.getNetWorth(),
      holdingsCost: cost,
      holdingsCount: holdings.length,
    );
  }

  void _reload() {
    // A block body, not an arrow: `setState(() => _data = _load())` returns
    // the assignment's value — a Future — and Flutter asserts on a setState
    // callback that returns one.
    setState(() {
      _data = _load();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);

    // No floating action button here. The reference design carries one on top
    // of the "+ ADD" header button — two affordances for the same action —
    // and, floating, it lands squarely on the Freeze Card switch, making that
    // control untappable mid-scroll. "+ ADD" stays: it is discoverable, it
    // never covers anything, and it does not need scrolling to reach.
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        key: const PageStorageKey('cards'),
        padding: EdgeInsets.only(
          top: inset.top + Spacing.stackMd,
          bottom: inset.bottom + Spacing.stackLg,
        ),
        children: [
          AsyncData<_CardsData>(
            future: _data!,
            placeholderHeight: 360,
            builder: (context, data) => _CardsBody(
              data: data,
              controller: _controller,
              index: _index.clamp(
                0,
                data.cards.isEmpty ? 0 : data.cards.length - 1,
              ),
              onIndexChanged: (i) => setState(() => _index = i),
              onChanged: _reload,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardsBody extends StatelessWidget {
  const _CardsBody({
    required this.data,
    required this.controller,
    required this.index,
    required this.onIndexChanged,
    required this.onChanged,
  });

  final _CardsData data;
  final PageController controller;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final horizontal = EdgeInsets.symmetric(horizontal: contentInset(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: horizontal,
          child: SummaryRow(
            stats: [
              SummaryStat(
                label: l10n.homeCash,
                value: formatLira(data.netWorth.cash),
                tone: SummaryTone.positive,
              ),
              SummaryStat(
                label: l10n.homeCardDebt,
                value: formatLira(data.netWorth.cardDebt),
                tone: SummaryTone.negative,
              ),
              SummaryStat(
                label: l10n.homeNetWorth,
                value: formatLira(data.netWorth.net),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.stackLg),

        Padding(
          padding: horizontal,
          child: Row(
            children: [
              // Its own announcement. Loose text in a scroll body merges
              // into the body's own node, which is then read out BEFORE
              // everything it contains — here that put "My Cards, ADD, My
              // Accounts" ahead of the cards and accounts themselves. Same
              // shape as the Assets headings; see the roadmap's label-quality
              // entry.
              Expanded(
                child: Semantics(
                  container: true,
                  child: Text(l10n.cardsMyCards, style: text.titleLarge),
                ),
              ),
              GradientButton(
                label: l10n.cardsAdd,
                expand: false,
                onPressed: () async {
                  final created = await showAddAccountSheet(context);
                  // Only reload when something was actually added; a
                  // dismissed sheet should leave the page as it was rather
                  // than flashing a spinner over unchanged figures.
                  if (created != null) onChanged();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.stackMd),

        if (data.cards.isEmpty)
          Padding(
            padding: horizontal,
            child: NothingYet(message: l10n.cardsNoCards),
          )
        else ...[
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: controller,
              itemCount: data.cards.length,
              onPageChanged: onIndexChanged,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _CardFace(card: data.cards[i]),
              ),
            ),
          ),
          const SizedBox(height: Spacing.stackMd),
          _PageDots(count: data.cards.length, active: index),
          const SizedBox(height: Spacing.stackMd),
          Padding(
            padding: horizontal,
            child: _CardDetail(
              // Keyed on the account so switching cards rebuilds the detail
              // against the new one instead of keeping the old card's state.
              key: ValueKey(data.cards[index].id),
              card: data.cards[index],
              onChanged: onChanged,
            ),
          ),
        ],
        const SizedBox(height: Spacing.sectionGap),

        Padding(
          padding: horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                child: Text(l10n.cardsMyAccounts, style: text.titleLarge),
              ),
              const SizedBox(height: Spacing.stackMd),
              if (data.holdingsCount > 0) ...[
                _AccountTile(
                  name: l10n.cardsActiveAssets,
                  // Cost, not value: see _CardsData.holdingsCost.
                  meta: l10n.cardsHoldingsMeta(data.holdingsCount),
                  balance: formatLira(data.holdingsCost),
                  highlighted: true,
                ),
                const SizedBox(height: Spacing.stackMd),
              ],
              if (data.checkingAccounts.isEmpty)
                NothingYet(message: l10n.cardsNoCashAccounts)
              else
                for (final account in data.checkingAccounts) ...[
                  _AccountTile(
                    name: account.name,
                    meta: l10n.cardsCashChecking,
                    balance: formatLira(account.balance),
                  ),
                  const SizedBox(height: Spacing.stackMd),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The network's own name for a card, from the logo path stored on the row.
///
/// `Account.networkLogo` holds the desktop's asset path (`assets/visa.png`)
/// because that string is a STORAGE contract the desktop reads back. Turning
/// it into something to show is the screen's job, which is what this is.
String cardNetworkLabel(String networkLogo) => switch (networkLogo) {
  'assets/visa.png' => 'VISA',
  'assets/mastercard.png' => 'MC',
  'assets/troy.png' => 'TROY',
  _ => '',
};
