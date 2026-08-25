import 'package:flutter/material.dart';

import 'app_services.dart';
import 'app_shell.dart';
import 'screens/locked_screen.dart';
import 'screens/onboarding_screen.dart';
import 'security/screen_lock.dart';
import 'theme/obsidian_prime.dart';

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
  late final Future<(AppServices, _Destination)> _startUp = _start();
  _Destination? _override;

  Future<(AppServices, _Destination)> _start() async {
    final services = await AppServices.open();
    await services.startUp();
    return (
      services,
      await services.isSetUp ? _Destination.shell : _Destination.onboarding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(AppServices, _Destination)>(
      future: _startUp,
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        return ArchlenceRoot(
          services: resolved?.$1,
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
      locked: (context, unlock) =>
          LockedScreen(onAuthenticate: lock.authenticate, onUnlocked: unlock),
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
              Text('Archlence could not start', style: text.titleLarge),
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
