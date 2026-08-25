import 'package:flutter/material.dart';

import '../theme/obsidian_prime.dart';
import '../widgets/summary_row.dart';
import '../widgets/surfaces.dart';

/// Cards and accounts.
class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  static const _cards = <_BankCard>[
    _BankCard(
      name: 'World Platinum',
      kind: 'Credit Card',
      last4: '4826',
      network: 'VISA',
      availableLimit: '₺70.464,50',
      currentDebt: '₺49.535,50',
      usage: 0.41,
    ),
    _BankCard(
      name: 'Bonus Flexi',
      kind: 'Credit Card',
      last4: '7391',
      network: 'MC',
      availableLimit: '₺63.423,27',
      currentDebt: '₺11.576,73',
      usage: 0.18,
    ),
  ];

  final _controller = PageController(viewportFraction: 0.88);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final inset = MediaQuery.paddingOf(context);
    final card = _cards[_index];

    // No floating action button here. The reference design carries one on top
    // of the "+ ADD" header button — two affordances for the same action —
    // and, floating, it lands squarely on the Freeze Card switch, making that
    // control untappable mid-scroll. "+ ADD" stays: it is discoverable, it
    // never covers anything, and it does not need scrolling to reach.
    return ListView(
      key: const PageStorageKey('cards'),
      padding: EdgeInsets.only(
        top: inset.top + Spacing.stackMd,
        bottom: inset.bottom + Spacing.stackLg,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.containerMargin,
          ),
          child: const SummaryRow(
            stats: [
              SummaryStat(
                label: 'Cash',
                value: '₺706.919,03',
                tone: SummaryTone.positive,
              ),
              SummaryStat(
                label: 'Card Debt',
                value: '₺61.112,23',
                tone: SummaryTone.negative,
              ),
              SummaryStat(label: 'Net Worth', value: '₺645.806,80'),
            ],
          ),
        ),
        const SizedBox(height: Spacing.stackLg),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.containerMargin,
          ),
          child: Row(
            children: [
              Expanded(child: Text('My Cards', style: text.titleLarge)),
              GradientButton(label: '+  ADD', expand: false, onPressed: () {}),
            ],
          ),
        ),
        const SizedBox(height: Spacing.stackMd),

        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _controller,
            itemCount: _cards.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _CardFace(card: _cards[i]),
            ),
          ),
        ),
        const SizedBox(height: Spacing.stackMd),
        _PageDots(count: _cards.length, active: _index),
        const SizedBox(height: Spacing.stackMd),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.containerMargin,
          ),
          child: _CardDetail(card: card),
        ),
        const SizedBox(height: Spacing.sectionGap),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.containerMargin,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Accounts', style: text.titleLarge),
              const SizedBox(height: Spacing.stackMd),
              const _AccountTile(
                name: 'My Active Assets',
                meta: '9/9 assets · Last known price',
                balance: '₺572.190,00',
                highlighted: true,
              ),
              const SizedBox(height: Spacing.stackMd),
              const _AccountTile(
                name: 'Everyday Account',
                meta: 'Cash / Checking',
                balance: '₺29.949,53',
              ),
              const SizedBox(height: Spacing.stackMd),
              const _AccountTile(
                name: 'Salary & Savings',
                meta: 'Cash / Checking',
                balance: '₺154.212,17',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BankCard {
  const _BankCard({
    required this.name,
    required this.kind,
    required this.last4,
    required this.network,
    required this.availableLimit,
    required this.currentDebt,
    required this.usage,
  });

  final String name;
  final String kind;
  final String last4;
  final String network;
  final String availableLimit;
  final String currentDebt;
  final double usage;
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card});

  final _BankCard card;

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
              '••••  ••••  ••••  ${card.last4}',
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
                card.network,
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
  const _CardDetail({required this.card});

  final _BankCard card;

  @override
  State<_CardDetail> createState() => _CardDetailState();
}

class _CardDetailState extends State<_CardDetail> {
  bool _onlineShopping = true;
  bool _frozen = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final card = widget.card;

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
                  card.kind.toUpperCase(),
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
                  label: 'Available Limit',
                  value: card.availableLimit,
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Current Debt',
                  value: card.currentDebt,
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
              value: card.usage,
              minHeight: 5,
              backgroundColor: ObsidianPalette.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation(ObsidianPalette.primary),
            ),
          ),
          const SizedBox(height: Spacing.stackLg),

          const SectionLabel('Card Controls'),
          const SizedBox(height: Spacing.stackSm),
          _ControlRow(
            icon: Icons.public,
            title: 'Online Shopping Preference',
            subtitle: 'Stored as a preference only',
            value: _onlineShopping,
            onChanged: (v) => setState(() => _onlineShopping = v),
          ),
          _ControlRow(
            icon: Icons.ac_unit,
            title: 'Freeze Card',
            value: _frozen,
            onChanged: (v) => setState(() => _frozen = v),
          ),
          const SizedBox(height: Spacing.stackMd),

          const SectionLabel('Recent Transactions'),
          const SizedBox(height: Spacing.stackSm),
          const _TxRow(date: '08-06', name: 'Fuel', amount: '-₺1.893,95'),
          const _TxRow(date: '08-06', name: 'Team lunch', amount: '-₺420,00'),
          const _TxRow(
            date: '08-05',
            name: 'Lunch or dinner',
            amount: '-₺402,19',
          ),
          const SizedBox(height: Spacing.stackMd),

          Row(
            spacing: Spacing.stackMd,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Statement'),
                ),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Pay Debt'),
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

class _TxRow extends StatelessWidget {
  const _TxRow({required this.date, required this.name, required this.amount});

  final String date;
  final String name;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            date,
            style: text.bodySmall?.copyWith(
              color: ObsidianPalette.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
          ),
          Text(
            amount,
            style: text.bodySmall?.copyWith(color: ObsidianPalette.error),
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
      onTap: () {},
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
