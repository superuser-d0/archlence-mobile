part of 'cards_screen.dart';

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
              Expanded(
                // Decoration: the brand printed on the plastic. The header
                // already says the app's name, and a screen reader hearing
                // "Archlence" twice on one screen learns nothing the second
                // time.
                child: ExcludeSemantics(
                  child: Text(
                    'Archlence',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleLarge,
                  ),
                ),
              ),
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
              // Read aloud, a row of bullets is either sixteen repetitions of
              // the word or nothing at all. The last four digits are the part
              // that identifies the card to its owner, so that is what is
              // said.
              semanticsLabel: context.l10n.a11yCardEnding(
                card.maskedNumber.replaceAll(RegExp(r'[^0-9]'), ''),
              ),
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
