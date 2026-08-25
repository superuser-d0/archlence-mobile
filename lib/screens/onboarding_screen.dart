/// The first run: what this app is, where the key lives, and one account.
///
/// The gate condition is `AccountService.hasAnyAccount()` — the desktop's own
/// choice, and the right one: the question is not "has the user seen a
/// welcome screen" but "is there anything to show them". A flag in
/// preferences would survive a wipe of the database and strand a fresh
/// install on an empty dashboard.
///
/// The last step CREATES AN ACCOUNT rather than offering to. Nothing in the
/// app works without one — a transaction has nowhere to come from, a goal has
/// nothing to hold money aside from — so an onboarding that ends without one
/// has not finished the job.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_services.dart';
import '../crypto/key_provider.dart';
import '../services/account_service.dart';
import '../theme/obsidian_prime.dart';
import '../ui/error_messages.dart';
import '../ui/money_format.dart';
import '../widgets/surfaces.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onFinished, super.key});

  /// Called once an account exists and the app can be entered.
  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() => _controller.nextPage(
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final keyProtection = ServicesScope.of(context).keyProtection;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  _WhatThisIs(onNext: _next),
                  _WhereTheKeyIs(status: keyProtection, onNext: _next),
                  _FirstAccount(onCreated: widget.onFinished),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.stackLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? ObsidianPalette.primary
                            : ObsidianPalette.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(Radii.full),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.containerMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _WhatThisIs extends StatelessWidget {
  const _WhatThisIs({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Page(
      children: [
        const SizedBox(height: Spacing.sectionGap),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: ObsidianPalette.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance_wallet,
            size: 32,
            color: ObsidianPalette.onPrimary,
          ),
        ),
        const SizedBox(height: Spacing.stackLg),
        Text('Archlence', style: text.displayLarge),
        const SizedBox(height: Spacing.stackMd),
        Text(
          'Your accounts, cards, holdings and budget — on this phone and '
          'nowhere else.',
          style: text.bodyLarge?.copyWith(
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.stackLg),
        const _Point(
          icon: Icons.cloud_off,
          title: 'No account, no server',
          body:
              'Nothing is uploaded and there is nothing to sign in to. '
              'The data lives in a file only this app can read.',
        ),
        const _Point(
          icon: Icons.sync_alt,
          title: 'The same file as the desktop app',
          body:
              'A backup written on one opens in the other, down to the '
              'kurus.',
        ),
        const _Point(
          icon: Icons.warning_amber,
          title: 'Which means backups are on you',
          body:
              'If you lose the phone without a backup, the data goes with '
              'it. Nobody else has a copy.',
        ),
        const SizedBox(height: Spacing.stackLg),
        GradientButton(label: 'Next', onPressed: onNext),
      ],
    );
  }
}

class _WhereTheKeyIs extends StatelessWidget {
  const _WhereTheKeyIs({required this.status, required this.onNext});

  final KeyProtectionStatus? status;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Told plainly and WITHOUT flattery. On a device whose key store is
    // unavailable the key sits in a file, and a welcome screen that implied
    // otherwise would be the app's first lie.
    final secure = status?.secureStore ?? false;

    return _Page(
      children: [
        const SizedBox(height: Spacing.sectionGap),
        Icon(
          secure ? Icons.lock : Icons.lock_open,
          size: 48,
          color: secure ? ObsidianPalette.tertiary : ObsidianPalette.secondary,
        ),
        const SizedBox(height: Spacing.stackLg),
        Text('Your data is encrypted', style: text.headlineMedium),
        const SizedBox(height: Spacing.stackMd),
        Text(
          'Every amount and description is stored encrypted. The key that '
          'opens them is kept apart from the data.',
          style: text.bodyMedium?.copyWith(
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.stackLg),
        AppCard(
          color: (secure ? ObsidianPalette.tertiary : ObsidianPalette.secondary)
              .withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status == null ? 'Key location unknown' : status!.method,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                switch (status) {
                  null => 'This build could not tell where the key ended up.',
                  final KeyProtectionStatus s when s.secureStore =>
                    'Held by the operating system. It never leaves this '
                        'device and no other app can read it.',
                  _ =>
                    'The OS key store was not available, so the key is a file '
                        'only this app can open. That is weaker than the key '
                        'store, and worth knowing.',
                },
                style: text.bodySmall?.copyWith(
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
              if (status?.warning != null) ...[
                const SizedBox(height: Spacing.stackSm),
                Text(
                  status!.warning!,
                  style: text.bodySmall?.copyWith(
                    color: ObsidianPalette.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.stackLg),
        GradientButton(label: 'Next', onPressed: onNext),
      ],
    );
  }
}

class _FirstAccount extends StatefulWidget {
  const _FirstAccount({required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<_FirstAccount> createState() => _FirstAccountState();
}

class _FirstAccountState extends State<_FirstAccount> {
  final _name = TextEditingController(text: 'Nakit');
  final _balance = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final balanceText = _balance.text.trim();
    final balance = parseAmountInput(balanceText);
    if (balanceText.isNotEmpty && balance == null) {
      setState(() => _error = 'That is not an amount.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ServicesScope.of(context).accounts.createAccount(
        name: _name.text,
        accountType: AccountType.checking,
        initialBalance: balance ?? 0,
      );
      widget.onCreated();
    } on AccountError catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = accountErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Page(
      children: [
        const SizedBox(height: Spacing.sectionGap),
        const Icon(
          Icons.savings_outlined,
          size: 48,
          color: ObsidianPalette.primary,
        ),
        const SizedBox(height: Spacing.stackLg),
        Text('Where does your money sit?', style: text.headlineMedium),
        const SizedBox(height: Spacing.stackMd),
        Text(
          'One cash account to start with. Everything else — spending, cards, '
          'holdings, goals — needs somewhere for money to come from.',
          style: text.bodyMedium?.copyWith(
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.stackLg),
        _OnboardingField(controller: _name, label: 'Name'),
        const SizedBox(height: Spacing.stackMd),
        _OnboardingField(
          controller: _balance,
          label: 'What is in it now',
          hint: '0,00',
          numeric: true,
        ),
        const SizedBox(height: Spacing.stackSm),
        Text(
          'You can leave this empty and add it later.',
          style: text.labelMedium?.copyWith(
            letterSpacing: 0,
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Spacing.stackMd),
          Text(
            _error!,
            style: text.bodySmall?.copyWith(color: ObsidianPalette.error),
          ),
        ],
        const SizedBox(height: Spacing.stackLg),
        GradientButton(
          label: _saving ? 'Setting up…' : 'Start using Archlence',
          onPressed: _saving ? null : _create,
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.stackMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ObsidianPalette.primary),
          const SizedBox(width: Spacing.stackMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: text.bodySmall?.copyWith(
                    color: ObsidianPalette.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingField extends StatelessWidget {
  const _OnboardingField({
    required this.controller,
    required this.label,
    this.hint,
    this.numeric = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: ObsidianPalette.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: ObsidianPalette.cardStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: ObsidianPalette.cardStroke),
        ),
      ),
    );
  }
}
