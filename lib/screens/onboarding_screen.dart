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
import '../ui/app_locale.dart';
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
  const _Page({required this.children, this.controller});

  final List<Widget> children;

  /// Only the page with text fields passes one — see `_FirstAccountState`,
  /// which uses it to keep its button clear of the keyboard.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      // The horizontal inset is responsive; the vertical is not. On a
      // tablet this page would otherwise run its sentences the full width of
      // the screen, which is the first thing a new user reads.
      padding: EdgeInsets.symmetric(
        horizontal: contentInset(context),
        vertical: Spacing.containerMargin,
      ),
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
    final l10n = context.l10n;
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
          l10n.onboardingTagline,
          style: text.bodyLarge?.copyWith(
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.stackLg),
        _Point(
          icon: Icons.cloud_off,
          title: l10n.onboardingNoServerTitle,
          body: l10n.onboardingNoServerBody,
        ),
        _Point(
          icon: Icons.sync_alt,
          title: l10n.onboardingSameFileTitle,
          body: l10n.onboardingSameFileBody,
        ),
        _Point(
          icon: Icons.warning_amber,
          title: l10n.onboardingBackupsTitle,
          body: l10n.onboardingBackupsBody,
        ),
        const SizedBox(height: Spacing.stackLg),
        GradientButton(label: l10n.commonNext, onPressed: onNext),
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
    final l10n = context.l10n;
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
        Text(l10n.onboardingEncryptedTitle, style: text.headlineMedium),
        const SizedBox(height: Spacing.stackMd),
        Text(
          l10n.onboardingEncryptedBody,
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
                switch (status?.method) {
                  null => l10n.onboardingKeyUnknownTitle,
                  KeyProtectionMethod.androidKeystore =>
                    l10n.keyMethodAndroidKeystore,
                  KeyProtectionMethod.ownerOnlyFile =>
                    l10n.keyMethodOwnerOnlyFile,
                },
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                switch (status) {
                  null => l10n.onboardingKeyUnknownBody,
                  final KeyProtectionStatus s when s.secureStore =>
                    l10n.onboardingKeySecureBody,
                  _ => l10n.onboardingKeyFileBody,
                },
                style: text.bodySmall?.copyWith(
                  color: ObsidianPalette.onSurfaceVariant,
                ),
              ),
              if (status?.warning != null) ...[
                const SizedBox(height: Spacing.stackSm),
                Text(
                  switch (status!.warning!) {
                    KeyProtectionWarning.osKeyStoreUnavailable =>
                      l10n.keyWarningOsStoreUnavailable,
                    KeyProtectionWarning.platformHasNoKeyStore =>
                      l10n.keyWarningNoPlatformStore,
                  },
                  style: text.bodySmall?.copyWith(
                    color: ObsidianPalette.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.stackLg),
        GradientButton(label: l10n.commonNext, onPressed: onNext),
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

class _FirstAccountState extends State<_FirstAccount>
    with WidgetsBindingObserver {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  final _scroll = ScrollController();
  final _nameFocus = FocusNode();
  final _balanceFocus = FocusNode();

  /// The primary action, so the keyboard can be asked to get out of its way.
  final _actionKey = GlobalKey();

  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// The keyboard has just changed the size of the window.
  ///
  /// WITHOUT THIS the button is SLICED rather than hidden, which is worse
  /// than either. `Scaffold` shrinks the body by the keyboard's height and
  /// the page scrolls, so the button ends up straddling the keyboard's top
  /// edge — about ten pixels of gradient with the page dots sitting on it.
  /// It reads as a rendering fault rather than as something to scroll to,
  /// on the first screen a new user ever fills in. Found by driving a real
  /// emulator; a widget test on a tall surface has no keyboard and would
  /// never have shown it.
  ///
  /// `didChangeMetrics` fires repeatedly while the keyboard animates, so the
  /// content tracks it rather than jumping once at the end. Only while a
  /// field of THIS page holds focus: after that the user is free to scroll
  /// wherever they like and nothing fights them.
  @override
  void didChangeMetrics() {
    if (!_nameFocus.hasFocus && !_balanceFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _actionKey.currentContext;
      if (!mounted || target == null) return;
      // `ensureVisible` rather than a jump to the end: it scrolls the least
      // that reveals the button, so the field being typed into stays on
      // screen too. `alignment: 1` puts the button at the bottom edge.
      Scrollable.ensureVisible(target, alignment: 1, duration: Duration.zero);
    });
  }

  /// Prefilled once the localizations are reachable, and only while the field
  /// is still untouched — retyping over what the user has typed because a
  /// dependency changed would be worse than an empty field.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name.text.isEmpty) {
      _name.text = context.l10n.onboardingDefaultAccountName;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameFocus.dispose();
    _balanceFocus.dispose();
    _scroll.dispose();
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    // Read BEFORE the first await: the `catch` below needs it, and by then
    // this widget's context may be gone.
    final l10n = context.l10n;
    final balanceText = _balance.text.trim();
    final balance = parseAmountInput(balanceText);
    if (balanceText.isNotEmpty && balance == null) {
      setState(() => _error = l10n.errNotAnAmount);
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
        _error = accountErrorMessage(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return _Page(
      controller: _scroll,
      children: [
        const SizedBox(height: Spacing.sectionGap),
        const Icon(
          Icons.savings_outlined,
          size: 48,
          color: ObsidianPalette.primary,
        ),
        const SizedBox(height: Spacing.stackLg),
        Text(l10n.onboardingAccountTitle, style: text.headlineMedium),
        const SizedBox(height: Spacing.stackMd),
        Text(
          l10n.onboardingAccountBody,
          style: text.bodyMedium?.copyWith(
            color: ObsidianPalette.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.stackLg),
        _OnboardingField(
          controller: _name,
          focusNode: _nameFocus,
          label: l10n.onboardingAccountName,
        ),
        const SizedBox(height: Spacing.stackMd),
        _OnboardingField(
          controller: _balance,
          focusNode: _balanceFocus,
          label: l10n.onboardingAccountBalance,
          hint: '0,00',
          numeric: true,
        ),
        const SizedBox(height: Spacing.stackSm),
        Text(
          l10n.onboardingBalanceOptional,
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
          key: _actionKey,
          label: _saving ? l10n.onboardingSettingUp : l10n.onboardingStart,
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
    this.focusNode,
    this.hint,
    this.numeric = false,
  });

  final TextEditingController controller;

  /// Passed where the page needs to know which field the keyboard is for.
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
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
