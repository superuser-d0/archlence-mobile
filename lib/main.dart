import 'package:flutter/material.dart';

import 'app_services.dart';
import 'app_shell.dart';
import 'theme/obsidian_prime.dart';

void main() {
  // The database and the key store are platform channels; the binding has to
  // exist before either is touched.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArchlenceApp());
}

class ArchlenceApp extends StatelessWidget {
  const ArchlenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Archlence',
      debugShowCheckedModeBanner: false,
      theme: obsidianPrimeTheme(),
      home: const _Bootstrap(),
    );
  }
}

/// Opens the database and key store, settles what has fallen due, and only
/// then shows the shell.
///
/// Settling BEFORE the first draw is deliberate: a future-dated transaction is
/// recorded as `pending` and touches no balance until this runs, so drawing
/// first would show a balance that is about to change on its own.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<AppServices> _startUp = _start();

  Future<AppServices> _start() async {
    final services = await AppServices.open();
    await services.startUp();
    return services;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _startUp,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartUpFailed(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return const _Splash();
        }
        return ServicesScope(services: snapshot.data!, child: const AppShell());
      },
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
