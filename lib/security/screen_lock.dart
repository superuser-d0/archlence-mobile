/// Re-asking for the phone's own credential when the app comes back.
///
/// WHAT THIS IS, SAID PLAINLY: a UI gate, not cryptography. The database key
/// lives in the Android Keystore and opens without any of this; someone with
/// root, or a forensic image of the device, is not stopped by a lock screen
/// the app draws. What it stops is the realistic case — a phone already
/// unlocked and briefly in someone else's hands.
///
/// The app must say that where a user reads it, or the lock is a claim of
/// protection it does not provide.
///
/// The preference lives in the platform secure store rather than in
/// `finance.db`: that file's schema is a contract shared with the desktop app,
/// and a UI preference is not financial data. `flutter_secure_storage` is
/// already a dependency for the key provider, so this costs nothing new.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// How long the app may sit in the background before it asks again.
///
/// Not zero. Asking on every return — after a notification glance, a copied
/// code, a camera trip — is how a lock gets switched off in the first week,
/// and a lock the user disabled protects nothing at all.
const Duration lockGracePeriod = Duration(seconds: 60);

class ScreenLock {
  ScreenLock({FlutterSecureStorage? storage, LocalAuthentication? auth})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          ),
      _auth = auth ?? LocalAuthentication();

  static const _entryKey = 'archlence.screen-lock-enabled';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  /// Whether this device can authenticate at all.
  ///
  /// A device with neither a biometric nor a PIN cannot, and offering the
  /// switch there would let a user turn on a lock that then refuses to open.
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  /// Off unless explicitly turned on. A read that fails reports off rather
  /// than locking someone out of their own data over a storage error.
  Future<bool> isEnabled() async {
    try {
      return await _storage.read(key: _entryKey) == 'true';
    } on Exception {
      return false;
    }
  }

  Future<void> setEnabled(bool enabled) =>
      _storage.write(key: _entryKey, value: enabled ? 'true' : 'false');

  /// Asks the platform. Returns whether the user got through.
  ///
  /// `biometricOnly: false` on purpose: a device credential — PIN, pattern,
  /// password — must work too, or a user with no fingerprint enrolled is
  /// locked out of an app they set up themselves.
  ///
  /// [reason] is the sentence the platform's OWN sheet shows, and it is
  /// required rather than defaulted: this class has no `BuildContext` to read
  /// the labels from, and a caller that forgot would leave an English line on
  /// a Turkish phone at the one moment the user is reading closely. A missing
  /// argument is a compile error instead.
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        // Survives the prompt itself being backgrounded — otherwise a
        // fingerprint sheet interrupted by a notification counts as a
        // refusal and the user is asked again for no reason.
        persistAcrossBackgrounding: true,
      );
    } on Exception {
      return false;
    }
  }
}

/// Covers [child] until the user authenticates, after a long enough absence.
class ScreenLockGate extends StatefulWidget {
  const ScreenLockGate({
    required this.lock,
    required this.locked,
    required this.child,
    this.now = DateTime.now,
    super.key,
  });

  final ScreenLock lock;

  /// The screen shown while locked.
  final Widget Function(BuildContext context, VoidCallback unlock) locked;

  final Widget child;

  /// The clock, injectable so the grace period can be tested without waiting
  /// out a real minute. Reading `DateTime.now()` inline made this logic
  /// untestable, which is how the seam came to exist.
  final DateTime Function() now;

  @override
  State<ScreenLockGate> createState() => _ScreenLockGateState();
}

class _ScreenLockGateState extends State<ScreenLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Stamped on the way OUT, not measured on the way back, so a clock
        // that moves while the app is asleep cannot shorten the window.
        _leftAt ??= widget.now();
      case AppLifecycleState.resumed:
        _lockIfAway();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _lockIfAway() async {
    final leftAt = _leftAt;
    _leftAt = null;
    if (leftAt == null || _locked) return;
    if (widget.now().difference(leftAt) < lockGracePeriod) return;
    if (!await widget.lock.isEnabled()) return;
    if (!mounted) return;
    setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    // A Stack, not a replacement: the app keeps its state and its scroll
    // positions behind the cover, so unlocking puts the user back where they
    // were rather than on a freshly rebuilt dashboard.
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: widget.locked(context, () => setState(() => _locked = false)),
        ),
      ],
    );
  }
}
