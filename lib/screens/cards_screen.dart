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
    const horizontal = EdgeInsets.symmetric(
      horizontal: Spacing.containerMargin,
    );

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
              Expanded(child: Text(l10n.cardsMyCards, style: text.titleLarge)),
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
              Text(l10n.cardsMyAccounts, style: text.titleLarge),
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

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card});

  final Account card;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: ObsidianPalette.cardStroke),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1B1B), Color(0xFF2A2A2A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Archlence', style: text.titleLarge)),
              const Icon(Icons.contactless_outlined, size: 22),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              // maskedNumber already carries the placeholder form for a card
              // whose digits were never entered.
              card.maskedNumber.replaceAll('*', '•'),
              maxLines: 1,
              style: text.bodyLarge?.copyWith(letterSpacing: 2),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                cardNetworkLabel(card.networkLogo),
                style: text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active
                  ? ObsidianPalette.primary
                  : ObsidianPalette.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Radii.full),
            ),
          ),
      ],
    );
  }
}

class _CardDetail extends StatefulWidget {
  const _CardDetail({required this.card, required this.onChanged, super.key});

  final Account card;

  /// Called after a control writes, so the summary row and the carousel are
  /// re-read from the same source the switch just changed.
  final VoidCallback onChanged;

  @override
  State<_CardDetail> createState() => _CardDetailState();
}

class _CardDetailState extends State<_CardDetail> {
  /// Set while a switch is being written, so a second tap cannot race the
  /// first — the switch shows the value it is moving to meanwhile.
  bool? _pendingFrozen;
  bool? _pendingOnline;

  Future<void> _setFrozen(bool value) async {
    setState(() => _pendingFrozen = value);
    await ServicesScope.of(context).accounts
        .setCardFrozen(widget.card.id, value);
    if (!mounted) return;
    setState(() => _pendingFrozen = null);
    widget.onChanged();
  }

  Future<void> _setOnlinePayments(bool value) async {
    setState(() => _pendingOnline = value);
    await ServicesScope.of(context).accounts
        .setOnlinePayments(widget.card.id, value);
    if (!mounted) return;
    setState(() => _pendingOnline = null);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final card = widget.card;
    // A limit of zero means "none recorded", not "none left" — the same rule
    // the spending check applies — so there is no usage bar to draw.
    final usage = card.creditLimit > Decimal.zero
        ? (card.debt / card.creditLimit).toDouble().clamp(0.0, 1.0)
        : 0.0;

    return AppCard(
      padding: const EdgeInsets.all(Spacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Expanded, not Flexible-plus-Spacer: two flex children with
              // the same factor split the free space evenly, which squeezed
              // the card's name down to "World Pl…" while blank space sat
              // beside it.
              Expanded(
                child: Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleLarge,
                ),
              ),
              const SizedBox(width: Spacing.stackSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ObsidianPalette.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Text(
                  context.l10n.cardsCreditCardBadge,
                  style: text.labelMedium?.copyWith(
                    fontSize: 10,
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.more_horiz, size: 20),
            ],
          ),
          const SizedBox(height: Spacing.stackMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Figure(
                  label: context.l10n.cardsAvailableLimit,
                  value: formatLira(card.availableLimit),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: context.l10n.cardsCurrentDebt,
                  value: formatLira(card.debt),
                  color: ObsidianPalette.error,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.stackSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: LinearProgressIndicator(
              value: usage,
              minHeight: 5,
              backgroundColor: ObsidianPalette.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation(ObsidianPalette.primary),
            ),
          ),
          const SizedBox(height: Spacing.stackLg),

          SectionLabel(context.l10n.cardsControls),
          const SizedBox(height: Spacing.stackSm),
          _ControlRow(
            icon: Icons.public,
            title: context.l10n.cardsOnlineShopping,
            subtitle: context.l10n.cardsOnlineShoppingNote,
            value: _pendingOnline ?? card.onlinePaymentsEnabled,
            onChanged: _setOnlinePayments,
          ),
          _ControlRow(
            icon: Icons.ac_unit,
            title: context.l10n.cardsFreeze,
            subtitle: context.l10n.cardsFreezeNote,
            value: _pendingFrozen ?? card.isFrozen,
            onChanged: _setFrozen,
          ),
          const SizedBox(height: Spacing.stackMd),

          SectionLabel(context.l10n.cardsRecentTransactions),
          const SizedBox(height: Spacing.stackSm),
          _RecentTransactions(accountId: card.id),
          const SizedBox(height: Spacing.stackMd),

          Row(
            spacing: Spacing.stackMd,
            children: [
              // Statement has no screen yet; Pay Debt has
              // AccountService.payCreditCardDebt behind it and no form.
              Expanded(
                child: OutlinedButton(
                  onPressed: null,
                  child: Text(context.l10n.cardsStatement),
                ),
              ),
              Expanded(
                child: OutlinedButton(
                  // Only when there is something to pay: a payment against a
                  // clear card is refused by the service, and offering it
                  // would be inviting the error rather than preventing it.
                  onPressed: card.debt > Decimal.zero
                      ? () async {
                          final paid = await showPayDebtSheet(context, card);
                          if (paid ?? false) widget.onChanged();
                        }
                      : null,
                  child: Text(context.l10n.cardsPayDebt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelMedium?.copyWith(
            letterSpacing: 0,
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.bodySmall),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: text.labelMedium?.copyWith(
                      letterSpacing: 0,
                      color: ObsidianPalette.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// The last few completed rows on one account.
///
/// Its own loader rather than part of the screen's single read: the statement
/// changes only when the account it belongs to changes, and folding it into
/// the page load would re-decrypt every row each time a switch is flipped.
class _RecentTransactions extends StatefulWidget {
  const _RecentTransactions({required this.accountId});

  final int accountId;

  @override
  State<_RecentTransactions> createState() => _RecentTransactionsState();
}

class _RecentTransactionsState extends State<_RecentTransactions> {
  Future<List<LedgerEntry>>? _entries;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _entries ??= ServicesScope.of(context).transactions
        .getRecentForAccount(widget.accountId);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncData<List<LedgerEntry>>(
      future: _entries!,
      placeholderHeight: 72,
      builder: (context, entries) {
        if (entries.isEmpty) {
          return NothingYet(message: context.l10n.cardsNothingOnCard);
        }
        return Column(
          children: [for (final entry in entries) _TxRow(entry: entry)],
        );
      },
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Income on a card is a payment against the debt, so it reads as a
    // credit; everything else grows what is owed.
    final isCredit = entry.type == 'income' || entry.type == 'payment';
    final amount = entry.amount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            formatStoredDayMonth(entry.date),
            style: text.bodySmall?.copyWith(
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              // The service returns what was stored and invents no fallback,
              // so the category stands in for a description left blank.
              entry.description.isNotEmpty ? entry.description : entry.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
          ),
          if (amount == null)
            // Never a zero: this row's amount could not be decrypted, and
            // printing 0,00 ₺ would present that as a fact.
            Text(
              context.l10n.amountUnreadable,
              style: text.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: ObsidianPalette.error,
              ),
            )
          else
            Text(
              '${isCredit ? '+' : '-'}${formatLira(amount)}',
              style: text.bodySmall?.copyWith(
                color: isCredit
                    ? ObsidianPalette.tertiary
                    : ObsidianPalette.error,
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.name,
    required this.meta,
    required this.balance,
    this.highlighted = false,
  });

  final String name;
  final String meta;
  final String balance;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: highlighted
          ? ObsidianPalette.tertiary.withValues(alpha: 0.08)
          : null,
      // No account detail screen yet, so the tile does not offer one.
      child: Row(
        children: [
          if (highlighted) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ObsidianPalette.tertiary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: ObsidianPalette.tertiary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    letterSpacing: 0,
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.stackSm),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                balance,
                maxLines: 1,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: highlighted ? ObsidianPalette.tertiary : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
