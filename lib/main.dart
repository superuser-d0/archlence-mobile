import 'package:flutter/material.dart';

import 'app_services.dart';
import 'app_shell.dart';
import 'screens/locked_screen.dart';
import 'screens/onboarding_screen.dart';
import 'security/screen_lock.dart';
import 'theme/obsidian_prime.dart';
import 'ui/app_locale.dart';

void main() {
  // The database and the key store are platform channels; the binding has to
  // exist before either is touched.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArchlenceApp());
}

/// Opens the database and key store, settles what has fallen due, and only
/// then shows the shell.
///
/// Settling BEFORE the first draw is deliberate: a future-dated transaction is
/// recorded as `pending` and touches no balance until this runs, so drawing
/// first would show a balance that is about to change on its own.
class ArchlenceApp extends StatefulWidget {
  const ArchlenceApp({super.key});

  @override
  State<ArchlenceApp> createState() => _ArchlenceAppState();
}

/// What the root shows once the services are open.
enum _Destination { onboarding, shell }

class _ArchlenceAppState extends State<ArchlenceApp> {
  // Not `final`: a restore replaces the database file, which means closing
  // this graph and building another one over what the restore put there.
  late Future<(AppServices, _Destination)> _startUp = _start();
  _Destination? _override;

  final LanguagePreference _language = LanguagePreference();

  /// The chosen language, or null to follow the device.
  ///
  /// Read inside [_start] rather than in its own future, so the first frame
  /// that shows a label already knows which language it is in. A second
  /// future would draw the shell in the device's language and then swap it,
  /// which reads as a bug even when it settles correctly.
  Locale? _locale;

  Future<(AppServices, _Destination)> _start() async {
    _locale = await _language.read();
    final services = await AppServices.open();
    await services.startUp();
    return (
      services,
      await services.isSetUp ? _Destination.shell : _Destination.onboarding,
    );
  }

  Future<void> _selectLocale(Locale? locale) async {
    await _language.write(locale);
    if (mounted) setState(() => _locale = locale);
  }

  /// Closes the database, lets [work] replace the profile, and opens again.
  ///
  /// The `finally` is the point: if the restore fails, its own rollback has
  /// already put the previous data back, and the app has to come back up on
  /// that rather than sit on a closed database. The error is re-thrown so the
  /// screen that asked can say what happened.
  Future<void> _swapProfile(Future<void> Function() work) async {
    final (services, _) = await _startUp;
    await services.close();
    try {
      await work();
    } finally {
      // A block body. `setState(() => _startUp = _start())` returns the
      // assignment's value — a Future — which Flutter asserts on and then
      // swallows, leaving the state unchanged. See
      // `test/no_async_set_state_test.dart`.
      setState(() {
        _startUp = _start();
        _override = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(AppServices, _Destination)>(
      future: _startUp,
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        return ArchlenceRoot(
          services: resolved?.$1,
          swapProfile: _swapProfile,
          locale: _locale,
          selectLocale: _selectLocale,
          theme: obsidianPrimeTheme(),
          home: switch ((snapshot.error, resolved)) {
            (final Object error, _) => _StartUpFailed(error: error),
            (_, null) => const _Splash(),
            (_, final r) => _Gated(
              lock: r!.$1.screenLock,
              child: (_override ?? r.$2) == _Destination.onboarding
                  ? OnboardingScreen(
                      onFinished: () =>
                          setState(() => _override = _Destination.shell),
                    )
                  : const AppShell(),
            ),
          },
        );
      },
    );
  }
}

/// Wraps the app in the resume gate.
///
/// Inside `home`, so the lock covers whatever the app is showing — including
/// onboarding, where the first account's balance is already on screen.
class _Gated extends StatelessWidget {
  const _Gated({required this.lock, required this.child});

  final ScreenLock lock;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScreenLockGate(
      lock: lock,
      locked: (context, unlock) => LockedScreen(
        onAuthenticate: () => lock.authenticate(reason: context.l10n.unlockPrompt),
        onUnlocked: unlock,
      ),
      child: child,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// The database or the key store could not be opened.
///
/// There is nothing to show behind this — every figure in the app comes from
/// one or the other — so it takes the whole screen rather than appearing as a
/// card inside a shell full of blanks.
class _StartUpFailed extends StatelessWidget {
  const _StartUpFailed({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(Spacing.containerMargin),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 40,
                color: ObsidianPalette.error,
              ),
              const SizedBox(height: Spacing.stackMd),
              Text(context.l10n.startUpFailed, style: text.titleLarge),
              const SizedBox(height: Spacing.stackSm),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
