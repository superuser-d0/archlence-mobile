/// Which language the labels are drawn in, and where that choice is kept.
///
/// The NUMBERS do not move with it. `money_format.dart` writes `1.234,56 ₺`
/// in either language on purpose: the grouping is what the design specifies
/// and what the desktop stores, not a translation. An English label over a
/// Turkish figure is the app being honest about a Turkish-lira account, and
/// switching the separators with the labels would make the same balance read
/// as two different amounts.
///
/// The preference lives in the platform secure store, for the reason
/// `screen_lock.dart` gives at length: `finance.db`'s schema is a contract
/// shared with the desktop app, and a UI preference is not financial data.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/app_localizations.dart';

/// The languages the app has labels for, FALLBACK FIRST.
///
/// Order is load-bearing. Flutter resolves a device locale it does not
/// support to `supportedLocales.first`, so Turkish leading means a phone set
/// to German gets Turkish rather than English — this is a Turkish app that
/// also speaks English, not the other way round.
///
/// `test/l10n_test.dart` holds this against what the generated
/// [AppLocalizations] actually carries, so a locale added to the ARB files
/// and forgotten here is a failing test rather than a language nobody can
/// select.
const supportedLocales = <Locale>[Locale('tr'), Locale('en')];

/// Reads and writes the language choice.
class LanguagePreference {
  LanguagePreference({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _entryKey = 'archlence.language';

  final FlutterSecureStorage _storage;

  /// The chosen language, or null to follow the device's own setting.
  ///
  /// A stored code that is no longer supported reads as null rather than as
  /// an error: the app follows the phone instead of refusing to start over a
  /// preference.
  Future<Locale?> read() async {
    final String? code;
    try {
      code = await _storage.read(key: _entryKey);
    } on Exception {
      return null;
    }
    for (final locale in supportedLocales) {
      if (locale.languageCode == code) return locale;
    }
    return null;
  }

  /// Stores [locale], or clears the choice when it is null.
  Future<void> write(Locale? locale) => _storage.write(
    key: _entryKey,
    value: locale?.languageCode,
  );
}

/// Carries the current choice and the way to change it down to Settings.
///
/// Separate from the services scope because it is not a service: it belongs
/// to the root widget that rebuilds the whole app under a new locale.
class AppLocaleScope extends InheritedWidget {
  const AppLocaleScope({
    required this.selected,
    required this.select,
    required super.child,
    super.key,
  });

  /// Null means "follow the device".
  final Locale? selected;

  final Future<void> Function(Locale?) select;

  /// Null where nothing can change the language — the widget tests, which
  /// build a screen directly rather than through the root.
  static AppLocaleScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();

  @override
  bool updateShouldNotify(AppLocaleScope oldWidget) =>
      selected != oldWidget.selected || select != oldWidget.select;
}

/// `context.l10n.someLabel`, so a screen reads as text rather than as a
/// lookup.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Upper case that does not turn `i` into `I` in Turkish.
///
/// Dart's `toUpperCase` is locale-independent, and Unicode's default mapping
/// for `i` is `I`. Turkish has two i's and they do not cross: dotted `i`
/// upper-cases to dotted `İ`, and dotless `ı` to `I`. Left alone, the section
/// headings on the Settings screen come out as GÜVENLIK and GIZLILIK — a word
/// with a letter Turkish does not have in it.
///
/// Applied only where the app itself upper-cases something. Text a user typed
/// is never put through this.
String localizedUpperCase(String value, Locale locale) =>
    locale.languageCode == 'tr'
    ? value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase()
    : value.toUpperCase();
