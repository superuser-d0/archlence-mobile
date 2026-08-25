# Archlence Mobile — Roadmap

The Android client for [Archlence](https://github.com/superuser-d0/archlence),
rewritten in Flutter. This file is the pick-up point between sessions: what is
done and how it was proven, what is next, and which decisions are settled so
they are not reopened by accident.

Every claim here was verified against the code on `main` before being written.

## Where things stand

**Done:** the toolchain, all five screens, and the three layers underneath
them that are hardest to get right — money, encryption, and the database
schema.

**Not done:** anything that connects the two. Every screen still renders
hard-coded figures; nothing reads or writes the database yet.

59 unit tests and 4 device tests pass. `flutter analyze` is clean.

## Settled decisions

These were argued through and are not open questions. Reopening one is fine,
but it should be a deliberate decision with a reason, not a drift.

### Flutter rather than keeping Python, or wrapping the web design

The reason is not the UI. Archlence's value sits in its financial correctness
and its encryption, and those have mature Dart packages where a WebView would
have neither a decimal type nor Argon2 nor direct Keystore access. Packaging
Python for Android (Kivy/BeeWare/Flet) hits native-dependency walls —
`curl_cffi` has no p4a recipe, `argon2-cffi` needs a C toolchain — that the
UI framework choice does not remove.

The web-design output from Stitch was not wasted: it settled the visual
direction, which is now `lib/theme/obsidian_prime.dart`.

### Schema-compatible with the desktop `finance.db`

A backup written by one app must be readable by the other. This is what makes
the wire-compatibility work in the money and crypto layers pay off; without
it, that work would have been pointless.

The consequence is that the schema is applied as **recorded SQL**, not
declared as drift tables. The desktop's shape carries columns appended by past
`ALTER TABLE` migrations — `accounts` gained seven, `active_debts` three — and
a re-declaration in Dart would produce a tidier database that is not the same
database. Data access is written as SQL for the same reason: the tables are an
existing external contract, not something this app defines.

### Obsidian Prime, with four deliberate deviations

The design system in `Pictures/Archlence Mobile/.../obsidian_prime/DESIGN.md`
is followed, with four documented departures. Each is commented at its call
site:

1. **Cards are opaque, not glassmorphic.** They sit on a flat backdrop, so the
   blur is invisible while still costing a `saveLayer` per card. The blur is
   kept on the header and nav bar, which do overlay scrolling content.
2. **The balance amount shrinks to fit its ring.** At the specified fixed 40px
   it already overflows at six digits.
3. **Summary figures share the row width** instead of scrolling horizontally,
   so Net Worth is never hidden behind a swipe.
4. **Amounts scale down rather than truncate.** A clipped figure reads as a
   different number.

Note also that `DESIGN.md`'s prose and its token block disagree — the prose
names `#0A0A0A` / `#10B981` / `#F43F5E`, the tokens say `#131313` / `#4edea3` /
`#ffb4ab`. **The token block is the source of truth**; the generated reference
screens follow it. Reading a colour off the prose introduces a second green.

## Done, and how it was proven

Parity with the desktop is asserted against output from the desktop's own
modules, never against expectations derived by hand. A parity test that always
passes is decoration, so the schema one was checked for teeth by deliberately
breaking the schema and confirming it failed.

### Money — `lib/money/financial_decimal.dart`

Port of `utils/financial_decimal.py`. Values are routed through their text
form so a binary float never reaches an amount; non-numeric and non-finite
input raises rather than defaulting to zero.

**The trap:** Dart's `decimal` package offers only truncate/floor/ceil/
half-up — no banker's rounding. Python uses `ROUND_HALF_EVEN`. Using the
package's `round()` would have made `1.005` become `1.00` on desktop and
`1.01` on the phone, silently. Half-even is implemented in this file.

**Proof:** `test/cpython_parity_test.dart` runs 12 000 vectors produced by the
desktop's own `quantize_financial`, weighted toward exact-half cases. All
match. Regenerate with the script in that test's doc comment.

### Encryption — `lib/crypto/`

- `aead_crypto.dart` — AES-256-GCM, envelope layout `version | algo | nonce |
  TAG | ciphertext`. The tag sitting *before* the ciphertext is unusual but is
  what the desktop writes.
- `field_crypto.dart` — the storage contract: `AEADv1:` prefix, blank and null
  values passing through **unencrypted**, failure raising instead of
  substituting. Blank passthrough matters more than it looks: encrypting an
  empty description would make it indistinguishable from a present one and
  break every `IS NULL` query the desktop relies on.
- `key_provider.dart` — Android Keystore via EncryptedSharedPreferences, with
  an owner-only file fallback and a `MigratingKeyProvider` that moves a legacy
  file key into the Keystore, deleting the file only after the move is read
  back and verified.

**Proof:** interoperability is demonstrated in **both** directions — Dart reads
29 envelopes written by the desktop under pycryptodome, and that module reads
9 written by Dart (`tool/emit_aead_vectors.dart`). Field-level tokens are
checked against desktop output under a fixed key, blank passthrough included.
The Keystore itself is exercised on a real device in
`integration_test/key_provider_device_test.dart`; no unit test can prove it
works, because the unit tests use an in-memory stand-in.

### Database — `lib/data/`

`schema.dart` is generated from a dump of a database built by the desktop's
own `initialize_database()`. It must not be hand-edited.

**Proof:** `test/schema_parity_test.dart` compares a database created here,
object by object, against `test/desktop_schema.sql`. Also asserted: every
column in `encryptedFields` exists on its table, and foreign keys are enforced
— SQLite ignores a declared foreign key unless it is switched on per
connection.

`installment_plans` is exempt from the table checks: the desktop creates it
lazily on the first instalment plan, so it is legitimately absent from a fresh
schema.

### Screens — `lib/screens/`

All five tabs are built and were verified by running them on the emulator, not
by reading the code. Three defects surfaced only that way:

- Every tab's list attached to the same `PrimaryScrollController`, so
  switching tabs carried the previous tab's scroll offset across — Assets and
  Tools opened already scrolled past their headers. Each list now owns a
  `PageStorageKey`.
- The card detail header paired `Flexible` with `Spacer` at equal flex, so the
  two split the free space and clipped the name to "World Pl…" with blank
  space beside it.
- The floating action button duplicated the "+ ADD" header button and,
  floating, covered the Freeze Card switch. Dropped.

## Open work

### 1. Services — the layer that connects screens to the database

Nothing here yet. The desktop's `services/` is the reference; port in this
order, since each depends on the one before:

1. `account_service` — accounts and balances.
2. `transaction_service` — the ledger, and the balance invariants that guard
   it.
3. `asset_service` / `asset_purchase_service` / `asset_sale_service`.
4. `budget_service`, `savings_service`, `recurring_service`.

Port the desktop's precision and integrity tests alongside each — they are the
specification. `test_money_decisions_precision`, `test_portfolio_total_precision`,
`test_monetary_boundary_invariants`, `test_real_balance_invariants` and
`test_debt_total_matches_ledger` are the ones that encode rules not visible in
the code itself.

### 2. Wire the screens to real data

Only after (1). Every figure on every screen is currently a literal.

### 3. Price fetching — needs a decision

The desktop runs `services/asset_price_worker.py` as a **subprocess**
(`asset_service.py:700`). That architecture does not work on Android: there is no
second Python interpreter to spawn. It has to become an in-process background
task, and the price source itself needs deciding — `yfinance` has no Dart
equivalent, so this is either a direct HTTP call to a chosen provider or a
backend of your own.

### 4. Onboarding and sign-in screens

Designed (in the published mockup canvas) but not built. They gate everything
else in the app, so they are needed before the app is usable end to end, but
they depend on nothing but the key provider, which is done.

### 5. Not yet considered

Backup and restore, i18n (the desktop has `ui/i18n.py` with a full Turkish/
English map; the mobile screens are currently English-only strings in the
widgets), app icon and launch screen, release signing, Play Store listing.

## Environment

Set up on this machine and verified working:

- JDK 17 (`jdk17-openjdk`). **Not** a newer JDK: Gradle/AGP support for the
  latest releases lags, and 17 is what Flutter's Android build is most widely
  tested against.
- Flutter 3.47.1 stable, Android SDK at `~/Android/Sdk` (platform 35 and 36,
  build-tools, NDK), `ANDROID_HOME` exported from `~/.config/fish/config.fish`.
- Emulator AVD `archlence_pixel` (Pixel 7, Android 15).
  Start: `emulator -avd archlence_pixel -no-snapshot -gpu swiftshader_indirect`
- `flutter doctor` reports an Android licence warning. It is **cosmetic**: the
  AUR `android` CLI does not emit the output format `flutter doctor` parses.
  The licences are accepted and builds work — the real check is that
  `flutter build apk` succeeds.

Regenerating parity vectors needs `pycryptodome`, which is not installed
system-wide. A venv was used:
`python3 -m venv aeadvenv && ./aeadvenv/bin/pip install pycryptodome`.

## Working agreement

Two habits are worth keeping, because both caught real defects that review
would not have:

- **Run it, don't just read it.** All three screen defects above were invisible
  in the source and obvious on the first screenshot.
- **Prove parity against the real thing.** Testing a port against expectations
  derived by hand tests the derivation, not the port. Every parity claim in
  this file rests on output generated by the desktop's own modules.
