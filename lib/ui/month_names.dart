/// The three-letter month names, in the interface's language.
///
/// Shared by the budget's month chips and the trend chart's axis, which is why
/// it is here rather than private to either. Both used to hold their own copy
/// of the same twelve English strings.
///
/// Taken from the ARB rather than from `intl`'s date symbols on purpose: both
/// languages are then visible in one file beside every other label, and
/// nothing has to load date data at start-up to draw a chip.
library;

import '../l10n/app_localizations.dart';

/// A `switch` rather than a list indexed by month, so an unhandled case is a
/// compile error rather than a range error at the top of a chart.
String shortMonthName(AppLocalizations l10n, int month) => switch (month) {
  1 => l10n.monthShortJan,
  2 => l10n.monthShortFeb,
  3 => l10n.monthShortMar,
  4 => l10n.monthShortApr,
  5 => l10n.monthShortMay,
  6 => l10n.monthShortJun,
  7 => l10n.monthShortJul,
  8 => l10n.monthShortAug,
  9 => l10n.monthShortSep,
  10 => l10n.monthShortOct,
  11 => l10n.monthShortNov,
  _ => l10n.monthShortDec,
};

/// The full month name, for a calendar heading where three letters read as an
/// abbreviation of nothing.
String fullMonthName(AppLocalizations l10n, int month) => switch (month) {
  1 => l10n.monthJan,
  2 => l10n.monthFeb,
  3 => l10n.monthMar,
  4 => l10n.monthApr,
  5 => l10n.monthMay,
  6 => l10n.monthJun,
  7 => l10n.monthJul,
  8 => l10n.monthAug,
  9 => l10n.monthSep,
  10 => l10n.monthOct,
  11 => l10n.monthNov,
  _ => l10n.monthDec,
};

/// The one-or-two letter weekday heading, Monday first.
///
/// Monday first because both languages this app speaks start the week there;
/// the day numbers are laid out against this, so changing it changes where
/// every date lands.
String shortWeekdayName(AppLocalizations l10n, int weekday) =>
    switch (weekday) {
      DateTime.monday => l10n.weekdayShortMon,
      DateTime.tuesday => l10n.weekdayShortTue,
      DateTime.wednesday => l10n.weekdayShortWed,
      DateTime.thursday => l10n.weekdayShortThu,
      DateTime.friday => l10n.weekdayShortFri,
      DateTime.saturday => l10n.weekdayShortSat,
      _ => l10n.weekdayShortSun,
    };
