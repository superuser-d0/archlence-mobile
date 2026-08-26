/// How long ago a fetched price was fetched, in words.
///
/// Coarse on purpose — a live-price feed is not a clock, and "3 minutes ago"
/// tells a user everything "3 minutes 12 seconds ago" would, at the one
/// precision a phone screen actually reads. See `lib/ui/month_names.dart` for
/// the same reasoning applied to a different small, shared piece of text.
library;

import '../l10n/app_localizations.dart';

/// [elapsed] may be negative — a clock skew between this device and whatever
/// wrote the cache row is possible — and no separate clamp is needed for it:
/// any negative duration already has `inMinutes < 1`, so it falls into the
/// SAME "just now" branch a small positive one does, with nothing shown that
/// would read as a negative age. A mutation test proved this by removing an
/// earlier explicit clamp and finding the suite still passed; the clamp was
/// dead code, and this comment is what replaced it rather than restoring it.
String priceAge(AppLocalizations l10n, Duration elapsed) {
  if (elapsed.inMinutes < 1) return l10n.priceJustNow;
  if (elapsed.inHours < 1) return l10n.priceMinutesAgo(elapsed.inMinutes);
  if (elapsed.inDays < 1) return l10n.priceHoursAgo(elapsed.inHours);
  return l10n.priceDaysAgo(elapsed.inDays);
}
