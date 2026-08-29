# Archlence Mobile

The Android client for [Archlence](https://github.com/superuser-d0/archlence),
a local-first personal finance app. Written in Flutter; the desktop app is
Python/KivyMD.

Data stays on the device. Amounts and descriptions are encrypted with
AES-256-GCM under a key held in the Android Keystore, and the database file is
schema-compatible with the desktop's, so a backup can move between the two.

## Status

Usable. A fresh install walks through onboarding, opens its first account, and
from there records transactions, buys and sells holdings, plans a budget,
opens and funds savings goals, pays down a card and manages subscriptions.
Every service call has a form behind it and no control in the app is inert.
An optional lock re-asks for the phone's own fingerprint or PIN after a minute
away — it hides the screen, and says plainly that it adds no encryption.

**Backup and restore works, in both directions.** Settings writes a verified
package and hands it to the share sheet; it reads one back, including a
package written by the desktop app, replacing the database and the encryption
key under a journal that can be rolled back. Both directions are proven
against the desktop's own `services/backup_service.py` rather than against a
reading of the format.

**The key can travel on its own.** Beside the whole-database backup, Settings
writes a key recovery package — the encryption key wrapped under a passphrase,
with no data in it — and reads one back after proving it opens what is already
on the phone. That is the case a backup does not cover: the data is still
here, the key is gone. Wire-compatible with the desktop's, both directions
checked against its own module.

**It speaks Turkish and English.** Every label comes from `lib/l10n/`, which
carries both languages in full; a phone set to either gets that language, a
phone set to anything else gets Turkish, and Settings can override the choice.
The numbers stay Turkish either way — `1.234,56 ₺` is the format the design
specifies and the desktop stores, not a translation.

**It looks like itself on the home screen.** The launcher icon is the desktop
app's own mark, and a cold start opens on the app's dark rather than a white
flash.

**Release builds are signed properly or refused** — the Flutter template's
debug-key fallback is gone. Creating the keystore is the one step left, and it
belongs to whoever ships the app; `android/key.properties.example` has the
command.

**Holdings show a live price.** Crypto, gold and currency go through
CoinGecko and Frankfurter, called straight from the phone — no backend, no
API key shipped, matching the app's own "no account, no server" promise.
Shares need an API key of your own, entered in Settings — BIST data is
commercial, and a key shipped inside an app is a public key. Without one they
stay at cost. Each tile says which it got, and how long ago.

**Start at [docs/ROADMAP.md](docs/ROADMAP.md)** — it opens with a "Pick up
here" section listing the next steps in priority order, and records how each
claim was proven and which decisions are already settled.

## Running it

```bash
flutter pub get
dart run build_runner build          # drift codegen
flutter gen-l10n                     # labels, after editing lib/l10n/*.arb
flutter test                         # unit tests
flutter run -d <device>
```

Both generators' output is checked in, so a fresh clone builds without running
either. `flutter run` and `flutter test` re-run `gen-l10n` on their own; the
command above is for when you want the regenerated class before either.

A release build needs `android/key.properties` and the keystore it names.
Without them the build is refused rather than quietly signed with the SDK's
debug key — see `android/key.properties.example`:

```bash
flutter build apk --release
```

Device tests need an emulator or handset. They exercise the real Android
Keystore, the real database file and the real screens — the things an
in-memory test cannot speak for:

```bash
flutter test integration_test/key_provider_device_test.dart -d <device>
flutter test integration_test/app_device_test.dart -d <device>
```

A device round leaves two things running afterwards, both deliberately: the
emulator, and Gradle's daemons. In Task Manager the daemons are *OpenJDK
Platform binary* rather than anything with "Gradle" in the name, and after a
round they hold several GB between them. `./gradlew --stop` from `android/`
takes all of them; the emulator closes with its window.

Environment setup — the toolchain, SDK paths, the emulator AVD, which
`flutter doctor` complaints are safe to ignore, and why the suite takes ten
minutes on this machine — is documented in the roadmap. It is a **Windows**
setup; nothing in the app depends on that, and `.gitattributes` is what keeps
it that way.

## Layout

| Path | What lives there |
| --- | --- |
| `lib/money/` | Decimal amounts and the rounding rules, ported from the desktop |
| `lib/crypto/` | AES-256-GCM, field-level encryption, the key provider |
| `lib/data/` | Database connection and the desktop's schema, verbatim |
| `lib/l10n/` | The Turkish and English label files, and the class generated from them |
| `lib/backup/` | Backup packages: the bounded reader, the writer, the journalled restore |
| `lib/security/` | The resume lock |
| `lib/services/` | Accounts, the ledger, holdings, recurring, budget, savings, live pricing |
| `lib/screens/` | The five tabs, onboarding, and the forms behind them |
| `lib/ui/` | Money formatting, error wording, the language choice, the loading/error/empty contract |
| `lib/theme/` | Obsidian Prime design tokens |
| `lib/widgets/` | Shared surfaces, the balance ring, the sheet frame |
| `assets/icon/` | The launcher icon's SVG sources — the desktop app's own mark |
| `tool/` | Developer utilities: parity vectors, and the launcher PNGs |

## A note on the tests

Anything claiming compatibility with the desktop app is tested against output
generated by the desktop's **own** modules — 12 000 rounding vectors from its
`quantize_financial`, encryption envelopes from its `aead_crypto`, a schema
dump from its `initialize_database()`, and a whole backup package written by
its `create_backup`. Testing a port against expectations written by hand tests
the derivation, not the port.

Which is why `.gitattributes` pins the repository to LF endings rather than
the platform's. Those fixtures are compared against as bytes, and a clone on
Windows rewrites text files to CRLF by default — silently, for most of them.
One fixture broke loudly enough to be caught; the rest would have gone on
being compared against something the desktop never wrote.

The backup reader gets one thing more, because it is the only parser here fed
input the app did not write: a corrupted package must fail as a backup error
and never as anything else. That is not argued from one crafted file per
exception type — a valid package is mangled 400 different ways and every one
of them has to come back the same.

Every rule is also checked for TEETH: the code is deliberately broken and the
suite must fail. A test that cannot fail is decoration, and this habit has
repeatedly caught tests that looked thorough and proved nothing — an
assertion that re-rounded a value before comparing it, a cross-check where two
different ids both happened to be `1`, a timing rule only exercised for three
hours a day.
