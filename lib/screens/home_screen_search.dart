part of 'home_screen.dart';

/// The home search box, and the results panel under it.
///
/// **Inline, not a pushed screen or a menu.** The desktop gives its reason —
/// its dropdown grabbed focus and made a second keystroke impossible — and the
/// mobile reason is the same shape: the keyboard is already up, the field
/// already has focus, and taking either away between characters is the one
/// thing a search box must not do.
///
/// **Debounced by [_debounce].** Every keystroke would otherwise decrypt a
/// window of descriptions; the desktop waits 300ms and so does this. A result
/// from a query the user has already typed past is dropped rather than drawn,
/// which is why the query is checked again when the future returns.
class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

const Duration _debounce = Duration(milliseconds: 300);

/// How many results fit under the field before it stops being a glance.
const int _maxVisibleResults = 5;

class _SearchFieldState extends State<_SearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _pending;

  /// The query the visible results belong to, so a late answer to an older
  /// query can be recognised and dropped.
  String _shown = '';
  List<SearchHit>? _results;
  Object? _error;

  @override
  void dispose() {
    _pending?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _pending?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _shown = '';
        _results = null;
        _error = null;
      });
      return;
    }
    _pending = Timer(_debounce, () => _run(value));
  }

  Future<void> _run(String query) async {
    final services = ServicesScope.of(context);
    try {
      final hits = await services.search.search(query);
      if (!mounted || _controller.text != query) return;
      setState(() {
        _shown = query;
        _results = hits;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted || _controller.text != query) return;
      // A missing key reaches here. Drawing "no results" would say the
      // profile is empty when it is unreadable — the one answer this app
      // never gives.
      setState(() {
        _shown = query;
        _results = null;
        _error = error;
      });
    }
  }

  void _clear() {
    _pending?.cancel();
    _controller.clear();
    setState(() {
      _shown = '';
      _results = null;
      _error = null;
    });
  }

  void _open(SearchHit hit) {
    final shell = AppShellScope.maybeOf(context);
    FocusScope.of(context).unfocus();
    switch (hit.kind) {
      // Where the thing LIVES, which is what the desktop does too. An account
      // and the transactions against it are both on Cards.
      case SearchKind.account:
      case SearchKind.transaction:
        shell?.selectTab(ShellTab.cards);
      case SearchKind.category:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CategorySettingsScreen(),
          ),
        );
    }
    _clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(context),
        if (_error != null) ...[
          const SizedBox(height: Spacing.stackSm),
          DataUnavailable(error: _error!),
        ] else if (_results != null) ...[
          const SizedBox(height: Spacing.stackSm),
          _SearchResults(
            query: _shown,
            hits: _results!,
            onOpen: _open,
          ),
        ],
      ],
    );
  }

  Widget _field(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: context.l10n.homeSearchHint,
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.close, size: 18),
                tooltip: context.l10n.homeSearchClear,
              ),
        prefixIcon: const Icon(Icons.search, size: 20),
        fillColor: ObsidianPalette.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.full),
          borderSide: const BorderSide(color: ObsidianPalette.cardStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.full),
          borderSide: const BorderSide(color: ObsidianPalette.cardStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.full),
          borderSide: BorderSide(
            color: ObsidianPalette.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// What the search found, or that it found nothing.
///
/// The "nothing" case says WHERE it looked. Search here covers account names,
/// category names and the descriptions of recent transactions, and a user who
/// does not know that reads an empty panel as "I never recorded it" — which
/// may be false, because an older description is outside the window the
/// service opens.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.hits,
    required this.onOpen,
  });

  final String query;
  final List<SearchHit> hits;
  final void Function(SearchHit) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;

    if (hits.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(Spacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.homeSearchNoResults, style: text.bodyMedium),
            const SizedBox(height: 2),
            Text(
              l10n.homeSearchScope,
              style: text.bodySmall?.copyWith(
                color: ObsidianPalette.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final visible = hits.take(_maxVisibleResults).toList();
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final hit in visible)
            _SearchResultRow(hit: hit, onTap: () => onOpen(hit)),
          if (hits.length > visible.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.gutter,
                4,
                Spacing.gutter,
                8,
              ),
              child: Text(
                l10n.homeSearchMore(hits.length - visible.length),
                style: text.bodySmall?.copyWith(
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final (icon, label) = switch (hit.kind) {
      SearchKind.account => (
        Icons.account_balance_wallet_outlined,
        l10n.searchKindAccount,
      ),
      SearchKind.category => (Icons.sell_outlined, l10n.searchKindCategory),
      SearchKind.transaction => (
        Icons.receipt_long_outlined,
        l10n.searchKindTransaction,
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.gutter,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: ObsidianPalette.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // The date earns its place on a transaction: two
                      // descriptions can read the same and only the date says
                      // which one this is.
                      hit.date == null
                          ? label
                          : '$label · ${formatStoredDate(hit.date)}',
                      style: text.bodySmall?.copyWith(
                        color: ObsidianPalette.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
