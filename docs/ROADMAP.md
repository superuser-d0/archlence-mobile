# Archlence Mobile — Roadmap

The Android client for [Archlence](https://github.com/superuser-d0/archlence),
rewritten in Flutter. This file is the pick-up point between sessions: what is
done and how it was proven, what is next, and which decisions are settled so
they are not reopened by accident.

Every claim here was verified against the code on `main` before being written.

## Where things stand

**The app is usable.** A fresh install walks through onboarding, opens its
first account, and from there records transactions, buys and sells holdings,
plans a budget, opens and funds savings goals, pays down a card and manages
subscriptions. Every service call has a form behind it and no control is
disabled for want of one.

**Underneath:** the three layers that are hardest to get right — money,
encryption, the database schema — and the whole service layer on top:
accounts, the ledger, holdings, recurring payments, the budget, savings.

**And it can move its data.** Settings writes a verified backup package and
hands it to the share sheet; it reads one back — including a package the
desktop app wrote — replacing the database and the encryption key under a
journal that survives the process being killed. Proven in both directions
against `services/backup_service.py` itself.

**What it cannot do yet:** show a live price, or speak Turkish in its labels.

568 unit tests and 12 device tests pass. `flutter analyze` is clean, no
control in the app is inert, and it runs on the emulator.

## Pick up here

In priority order. Each of these is a self-contained next session.

**1. i18n.** The numbers are already Turkish-formatted; the labels are English
strings sitting in widgets. The desktop's `ui/i18n.py` has the full map, so
this is mechanical — but it touches every screen, and it is the difference
between an app for its author and an app for its users. `error_messages.dart`
was written for exactly this.

**2. Icon, launch screen, release signing.** Small and mechanical, and nothing
above waits on them.

**3. `key_recovery_service.py`.** The one piece of the backup work deliberately
left out — see "What the backup work did NOT port". It matters for someone who
still has their database but has lost the key, which a whole backup package
does not help with.

Open work 1 (price fetching) needs a DECISION before it needs code, and open
work 3 lists what has not been considered at all.

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

### A corrupt row is reported, never counted as zero

The desktop logs an unreadable amount and substitutes 0.0. On a phone that log
has no reader, and a false ₺0,00 on screen is exactly what the money layer
refuses — "showing no total is safer than showing a false one". So
`LedgerEntry.amount` is nullable and carries `isCorrupt`, and
`settleDueTransactions` returns how many due rows it had to skip. A build that
ignores that count silently loses money off the screen.

The distinction the desktop draws is kept: a missing KEY is rethrown, never
swallowed. It says nothing about any particular row, and treating every row as
corrupt because of it would report a settings problem as data loss.

### Services raise error codes, not sentences

The desktop raises `ValueError` with the Turkish user-facing text baked into
it, and its tests match on substrings. The port raises a typed error carrying
a code (`AccountErrorCode.insufficientLimit` and so on) with a developer-facing
English message beside it. The reason is i18n: the desktop has both languages
in `ui/i18n.py` and this app will need the same, and a code survives
translation where a matched string does not.

The same line separates data from interface text. `network_logo` values, and
the `Borç Ödeme` category a card payment is filed under, stay verbatim —
the desktop groups and reports on those literals, so translating them would
split one category in two. A `type_label` field was dropped for the opposite
reason: it was a Turkish UI string sitting on a data model.

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

Long, and grouped roughly by layer rather than by date:

| Layer | Sections |
| --- | --- |
| Foundations | Money · Encryption · Database · The REAL column's drift |
| Services | Accounts · Transactions · Holdings · Recurring payments · The monthly budget · Savings goals |
| Backup | The backup's cryptographic core · The package around it · Restoring |
| Security | The screen lock |
| Screens | The screen–service join · The wired tabs · Every control is live or visibly unavailable · Screens (as first built) |
| Write flows | The first write flow · Recording a transaction · Buying and selling a holding · Savings goals (sheets) · A budget line · Managing a subscription · Paying card debt · The first run · Backup & Restore |

Each section says what the thing does, which departures from the desktop or
the mockup were deliberate, and how the claim was checked — including, where
it happened, what a mutation revealed that the tests had missed.


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

### Accounts — `lib/services/account_service.dart`

Port of `services/account_service.py`, and the only writer of the `accounts`
table. Its substance is the sign convention: `balance` is the account's
signed contribution to net worth, so card debt is stored NEGATIVE and net
worth stays correct from a plain `SUM(balance)`. The positive `debt` and
`available_limit` a screen shows are derived, never stored.

`lib/data/balance_events.dart` came with it — the ledger that has to land in
the same commit as the balance change it records.

**Proof:** `test/account_service_test.dart`, 40 tests. Rather than trusting a
green suite, each rule was checked for teeth by breaking it: storing card debt
positive, dropping the zero clamp on the available limit, testing Visa's
one-digit prefix before Troy's four, limiting a checking account by its
balance, reading `credit_limit = 0` as "no room" instead of "no limit
recorded", skipping the frozen check for income, letting a checking account
keep a card limit, dropping the opening ledger event, leaving recurring
payments behind on delete, defaulting a null `online_payments_enabled` to
disabled, and moving the amount validation below the account lookups. Every
one of those failed the suite.

One line is deliberately NOT covered, and says so at its call site: the
`balance <= ?` re-check inside the card-payment UPDATE. Drift's sqlite3
executor opens transactions with `BEGIN IMMEDIATE`, so within this app the
decision already reads under the write lock and no second writer can
interleave; what the guard defends against is the desktop holding the same
file, which a unit test cannot stage.

The acceptance scenario the desktop encodes — a card spend lowering net worth
by exactly its amount — needs the transaction service and is not written yet.

### The screen–service join — `lib/app_services.dart`, `lib/ui/`

`AppServices` builds one graph over ONE database connection and ONE
`FieldCrypto`: the first holds a write lock, the second holds the decryption
key, and a second of either defeats both. `ServicesScope` carries it down the
tree; screens read it in `didChangeDependencies` and keep a `Future` they can
replace to reload.

**WHERE THE SCOPE SITS IS LOAD-BEARING.** It goes in `MaterialApp.builder`,
which is ABOVE the Navigator — not in `home`, which is below it. With the
scope in `home`, a pushed route is a SIBLING of home rather than a descendant
and finds no scope at all. That was a real defect, shipped in the commit that
wired Home and Cards and caught only when the Tools grid first pushed a route.
The placement now lives in a shared `ArchlenceRoot` used by `main.dart`, the
widget tests and the device test, so a copy of it in a test cannot let the
real one drift.

Start-up opens the database and key store, then calls `settleDueTransactions`
BEFORE the first draw. Nothing else posts a future-dated transaction, so
without that call a scheduled rent or salary is recorded and never arrives —
and drawing first would show a balance about to change on its own.

`AsyncData` is the one place that decides what a screen shows while loading
and when a load fails, and it exists to enforce a single rule: **a failure is
never drawn as a zero.** Every service refuses to substitute a plausible
number for one it could not read; a screen that caught the exception and
rendered `0,00 ₺` would undo all of it at the last step. `DataUnavailable` and
`NothingYet` stay separate for the same reason — "we could not read what you
added" and "you have not added anything" call for different reactions.

Two things on the dashboard are deliberately drawn WITHOUT figures. The
forecast and health-score cards come from the desktop's insight, projection
and metrics services, none of them ported; the mockup fills both with numbers,
and showing those would be presenting invented financial advice as analysis.
They say what they are waiting for and carry a `NOT YET` chip.

`lib/ui/money_format.dart` is presentation only, and must NEVER converge with
`formatWithThousands` in `asset_service.dart`. That one produces the Western
`1,234.56` that goes INTO a stored `transactions.description` and has to match
what the desktop writes; this one produces `1.234,56 ₺` for a screen. A test
pins both against each other so a well-meaning unification fails loudly.

**Proof:** `test/screens/` (15 tests) drives the real service graph over an
in-memory database — no stubs, because what is being tested IS the join.
`integration_test/app_device_test.dart` (3 tests) runs the same screens
against the real database file and the real Android Keystore, which is the
only way to know that a figure encrypted through the platform store comes back
the same on screen, and that start-up really does post what has fallen due.

Broken to check for teeth: Turkish grouping switched to Western, trailing
zeros dropped, the minus sign lost, the percent sign moved after the number, a
bad date stamp rendered anyway, the statement zeroing an unreadable amount,
the summary showing cash where net worth belongs, the freeze switch not
writing through, a fixed network label, limit and debt swapped, holdings
relabelled as a market value, empty states drawn as nothing, the ring showing
cash, an unreadable subscription given a plausible placeholder, and the
insight cards inventing a score again.

**Three defects surfaced only by running it**, which is the habit's whole
point:

- `setState(() => _data = _load())` — an arrow body returns the assignment's
  value, a `Future`, and Flutter asserts on that. It was in two screens.
- The balance ring drew its change chip even when there was nothing to report,
  so the emulator showed a bare green pill with an upward arrow and no number:
  it reads as a gain. The chip is now omitted entirely when the label is empty.
- The device test's own first draft flipped a completed transaction to
  `pending` after the fact, leaving the balance already applied — settling then
  added it twice and the test would have passed on a doubled figure.

### The first write flow — `lib/screens/add_account_sheet.dart`

Opening an account, and the pattern the rest should follow.

**The form is a thin collector.** It does not re-implement a rule:
`createAccount` owns them, and the form shows what came back. Duplicating a
rule in a form is exactly how the desktop ended up with
`monthly_budget_plan.amount` validated only inside its Kivy mixin, where the
next caller bypassed it without ever seeing it.

`lib/ui/error_messages.dart` is where "services raise error codes, not
sentences" finally pays off: every code becomes a sentence in ONE place, with
no `default` branch, so a service growing a new rule is a compile error rather
than a generic "something went wrong".

**Amount parsing is presentation, and it is where money can quietly go
wrong.** `parseAmountInput` accepts both `1.234,56` and `1.234.56` because the
same user types both. The rules are documented at the function; the one that
can lose money is that lone dots in groups of exactly three are GROUPING —
`1.234` is a thousand, not a lira and a bit. A round-trip test pins the thing
that matters most: what the app prints, the app can read back.

Blank means zero — a real answer, an account opened with nothing in it. Text
that is NOT a number is not zero, and saying so is the difference between
quietly opening an empty account and telling the user their typo was ignored.

The debt field on a card is labelled "Current debt", not "balance": the user
enters what they OWE as a positive number and the service stores it negative.
A "balance" label would invite a minus sign and double the debt.

### The first run — `lib/screens/onboarding_screen.dart`

**The gate asks the DATA, not a preference flag.** `hasAnyAccount()` is the
desktop's own condition and the right one: "has the user seen a welcome
screen" is the wrong question, because a flag would survive a wiped or
restored-empty database and strand a fresh install on a dashboard of zeroes
with no way to add anything.

The last step CREATES an account rather than offering to. Nothing works
without one — a transaction has nowhere to come from, a goal nothing to hold
money aside from — so an onboarding that ends without one has not finished.

Two things it says that a welcome screen is tempted to leave out. The
local-first trade cuts both ways, so **"backups are on you"** sits beside "no
account, no server". And the key page reports what the key provider ACTUALLY
did: on a device whose store is unavailable it says the key is a file and that
this is weaker, rather than implying Keystore protection that is not there.
Verified on the emulator, where it reads "Android Keystore — held by the
operating system".

### The backup's cryptographic core — `lib/backup/recovery_material.dart`

The first half of backup: the passphrase-wrapped copy of the encryption key
that travels inside a package, and the HMAC that authenticates its metadata.

**THIS IS A WIRE FORMAT.** A package written by either app must open in the
other, so the KDF, the round count, the field lengths and the exact JSON the
tag is computed over are all fixed by the desktop and not ours to tidy. The
canonical serialiser is written out by hand because `jsonEncode` does not sort
keys, and the tag is over those exact bytes — key order is format, not style.

**Proof:** `test/backup_vectors.txt` was produced by running
`services/backup_service.py`'s OWN functions, not by re-deriving what they
ought to produce. 14 tests, including every key the desktop wrapped and every
tag it computed.

One mutation exposed a hole in the vectors rather than in the code: every
vector used the default 600 000 rounds, so a port that ignored the count a
package DECLARES and always used its own passed all of them. The generator now
emits a payload at 150 000 rounds — still through the module's own code path,
with the constant swapped rather than the algorithm — and the test refuses to
run without one.

Bounds on a round count read from a package are load-bearing: a crafted backup
naming one round has its passphrase brute-forced in seconds, and one naming a
billion hangs the phone. A wrong passphrase is reported as WRONG rather than
as corruption, because "you mistyped" and "this file is not a backup" send a
user to different places.

The cost is deliberate. PBKDF2 at 600 000 rounds takes seconds on a phone —
that is what a KDF is for — and it must not run on the UI isolate.

### The package around it — `lib/backup/backup_package.dart`

The ZIP a backup travels in, and **the bounds it is read under**. This is the
only parser in the app fed input the app did not write: a backup arrives from
the user's storage, a cloud folder or a chat app, and nothing about it has been
proven when this code first looks at it.

Decided from the CENTRAL DIRECTORY, before a byte is decompressed — the cheap
half, and the half that stops a bomb from ever being paid for: at most four
members, only the four allowed names, no duplicates, no directory entry, no
ZIP-level encryption, no symbolic link, deflate or stored only, 256 MB for
`finance.db` and 4 MB for the rest, and a compression-ratio ceiling of 200.
Then, while extracting: a SECOND counter over the bytes ACTUALLY PRODUCED,
because a header is written by whoever built the file and can lie.

Three departures from the desktop, all tightenings:

1. **Every member is checked against its CRC and its declared size.** Deflate
   is not self-checking — decoding damaged bits mostly yields damaged bytes
   rather than an error — and it was measured: with the check removed, a
   package with 32 bytes flipped inside `config.json` staged CLEANLY and left
   64 KB of garbage on disk. The other three members are separately
   authenticated (the database by its SHA-256, the metadata by its HMAC, the
   recovery material by its own GCM tag); `config.json` is covered by nothing
   else, which is exactly why the check belongs here.
2. **bzip2 is refused** rather than decompressed. The desktop never writes it,
   and the decoder available here has no bounded mode.
3. **A directory entry is recognised by its ATTRIBUTES too**, not only a
   trailing `/`. A name ending in `/` is not one of the four allowed names, so
   the allowed-names check rejects it first and the trailing-slash test can
   never fire; the reachable shape is an entry named exactly `config.json`
   with `S_IFDIR` set.

`package:archive`'s own streaming helper is deliberately NOT used for the
extraction. Its `decodeStream` collects every decompressed chunk in memory and
hands them over only at close, so a bound applied to its output is applied
after the memory has already been spent — and its `decodeBytes` path
decompresses a member whole. dart:io's zlib is driven directly instead, a
chunk at a time, so the byte counter can abandon a member mid-stream.

**Proof:** 22 tests, each a hostile file built in the test rather than
described. Every bound was checked for teeth by removing it and requiring the
matching test to fail; **three had none** and were fixed rather than excused:

- the directory-entry test was being rejected by the allowed-names check, so
  the directory check itself was decoration — hence departure 3 above;
- the over-size test was ALSO caught by the extraction counter, so it could
  not tell the two layers apart; the header-only gate is now exercised on its
  own, because which layer refuses a 250 MB member decides whether it is ever
  decompressed;
- the catch-all that converts a ZIP reader's own exceptions had no test that
  reached it. Rather than engineering one input per exception type, a valid
  package is now mangled **400 different ways** from a fixed seed, and every
  one has to come back as a backup error and nothing else.

### Restoring — `lib/backup/backup_service.dart`

Writing a package: a SQLite-level copy of the database through sqlite3's own
online-backup API (not a copy of the file's bytes, which would catch a write
in progress), `PRAGMA integrity_check`, `PRAGMA foreign_key_check`, then every
AEAD field opened with the key that is about to travel with it. The package is
read back through the public entry point BEFORE this returns — a backup that
cannot be restored is worse than none, because it is believed.

Reading one: the metadata's HMAC first, since everything below it reads the
metadata; then the database's SHA-256, the key unwrapped from the recovery
material, its fingerprint against the metadata's, SQLite's integrity check,
and finally every AEAD field opened with that key and the count compared with
the one recorded.

**A wrong passphrase and a tampered file are told apart.** The metadata tag
fails identically for both, so on a mismatch the recovery material — which
carries its own GCM tag and a bounded round count — is tried with the same
passphrase. If it opens, the passphrase was right and the metadata was
altered. The extra derivation costs seconds and only on a path that has
already failed.

**The restore is journalled, and the KEY IS SWAPPED LAST.** That is the one
real design change from the desktop, and it exists because the desktop's order
loses data on a phone. The desktop replaces the key in the middle and its
journal never records the old one, so a restore killed after that step and
rolled back at the next start brings the OLD database back under the NEW key —
which opens nothing. Android kills apps as a matter of routine.

Moving the swap to the end makes every earlier state unambiguous: the old key
is still in the store, so rolling the database back restores a generation that
still opens. The database is verified with the incoming key held IN MEMORY,
before that key is anywhere near the store. Writing the old key to disk for
the duration would have worked too, and was rejected: on a device with a
Keystore, the key's whole value is that it is not a file.

One state cannot be decided from its name — the process died inside the key
store's own write — so the journal records the SHA-256 of both possible keys
before the swap begins, and recovery asks the store which one it holds. A
store holding neither is not guessed at; it fails closed. Fingerprints, not
keys: a hash of a 32-byte random key tells an attacker nothing.

SQLite's sidecar files (`-journal`, `-wal`, `-shm`) move with the database they
belong to and come back with it. The desktop does not do this. A stale
rollback journal left beside a restored database is one SQLite would replay
into the new file.

**Proof:** 23 tests. The cross-app ones are the point:
`test/desktop_backup.archlence-backup` was written by
`services/backup_service.py`'s own `create_backup` over a database built by
its own `initialize_database()`, and the assertion is that this app recovers
THE KNOWN KEY inside it — not merely that something 32 bytes long came out.
The other direction was checked by hand and is repeatable with
`tool/emit_mobile_backup.dart`: a package written here, restored by the
desktop, whose `initialize_database()` then accepted the schema unchanged and
decrypted the rows.

Every step of the restore is driven into failure in turn and the previous
database, key and settings are required back each time; a killed process is
reproduced by snapshotting the whole profile mid-flight and running recovery
over the snapshot, which is what the next start of the app actually sees.
Mutation-checking the verification found two tests without teeth: the
"metadata altered" test was changing a field the record-count check ALSO
looked at, so it passed with the signature check deleted, and nothing isolated
the key fingerprint at all — a substituted key is normally caught when it
fails to open a row, but a profile with nothing encrypted has no row to fail
on, and that is the case the fingerprint is for.

**A defect this found in the app, not the port:** `ArchlenceDatabase` declared
`schemaVersion = 1` while `database/init_db.py` stamps `SCHEMA_VERSION = 2`.
Every schema comparison passed — the SHAPE was right, only the number was
wrong — and the cost was that a database restored from a desktop backup looked
to drift like a file from a future it had no migration for, so **the app
refused to open its own data.** Nothing but actually restoring a desktop
backup could have caught it.

### What the backup work did NOT port

`key_recovery_service.py`, deliberately, and for two different reasons.

`export_recovery_package` / `import_recovery_package` — a passphrase-wrapped
copy of just the key, without the database — is worth having and is item 3 in
"Pick up here". It answers a case a whole backup does not: still having the
data, having lost the key.

`rotate_encryption_key` is a different matter. It refuses to run until the
desktop's legacy CBC migration has finished, and that migration is explicitly
not coming here; a rotation is also the one operation that can make every row
unreadable at once. Neither belongs in a first mobile release.

### The Backup & Restore screen — `lib/screens/backup_screen.dart`

Where the engine above becomes something a user can reach. Two sentences on it
are pinned by tests, because they are the difference between a user who keeps
their data and one who does not: **the passphrase is not stored anywhere**, and
**restoring replaces everything** — followed immediately by what is kept, since
"replaced" and "gone" are different and the difference is the backup the app
writes first.

The file leaves and arrives through the platform's own pickers, not a folder
this app writes into. Since Android 11 an app cannot hand another app a path,
and a backup that cannot be moved off the phone is not a backup. The chooser
is opened with no type filter: `.archlence-backup` maps to no MIME type, and a
filter would grey out the only file the user came for.

A restore cannot happen underneath a running app — it replaces the database
file, and a drift connection still holding the old one would write into a file
that is no longer the app's data. So the screen asks the root, through
`AppRestartScope`, to close the graph, run the restore against a profile
nothing has open, and build everything again. The rebuild happens in a
`finally`: a restore that fails has already rolled itself back, and the app
has to come up on the previous data rather than sit on a closed database.

`share_plus` and `file_selector` are the two new dependencies. `file_picker`
was tried first and abandoned: its current release needs `win32: ^6`, which
`flutter_secure_storage` 9 forbids through its Windows sibling — and that
sibling is compiled even for an Android build, so the conflict is real rather
than theoretical. Resolving it meant moving the key store to
`flutter_secure_storage` 11, which is a change to where the encryption key
LIVES and does not belong in a change about backups.

**Proof:** widget tests for the wording and both gates, and the whole flow
walked on the emulator — onboarding, Settings, a package created and handed to
the share sheet, that package pulled off the device and restored by the
desktop app, and the desktop's own fixture restored onto the phone with the
app coming back up on 1.500,00 ₺ of somebody else's data.

**Two defects the emulator found and no test had:** a fresh install that had
opened an account but recorded nothing had a database and NO KEY — nothing on
that path encrypts anything, so nothing had ever asked for one — and Backup &
Restore answered "there is no encryption key to back up" at exactly the moment
a user is most likely to make their first backup. The key is now created with
the profile, in `AppServices.open`. The other was `GradientButton`; see "Every
control is live or visibly unavailable".

### The screen lock — `lib/security/screen_lock.dart`

**A UI gate, not cryptography, and the app says so.** The database key lives
in the Keystore and opens without any of this; someone with root or a forensic
image is not stopped by a lock screen the app draws. What it stops is the
realistic case — a phone already unlocked and briefly in someone else's hands.
The Settings switch says "it hides the screen … it does not add encryption",
and a test pins that wording, because a lock that claimed more would be the
app making a promise it cannot keep.

Three decisions worth not re-deriving:

- **A sixty-second grace period.** Asking on every return — after a
  notification glance, a copied code — is how a lock gets switched off in the
  first week, and a lock the user disabled protects nothing.
- **`biometricOnly: false`.** A device credential must work too, or a user
  with no fingerprint enrolled is locked out of an app they set up themselves.
- **Turning it ON asks first.** A lock switched on by someone who cannot then
  pass it is a lock on the owner's own data.

The preference lives in the platform secure store, not `finance.db`: that
file's schema is a contract with the desktop and a UI preference is not
financial data. A read that fails reports OFF rather than locking someone out
over a storage error.

The gate takes an injectable clock. Reading `DateTime.now()` inline made the
grace period untestable without waiting out a real minute — the seam exists
because the first test could not be written otherwise.

Still open, deliberately: `FLAG_SECURE` would also blank the app in the
recents list, which is the same threat. It is not set, because it blocks
legitimate screenshots too and that is a product call.

### Paying card debt — `lib/screens/pay_debt_sheet.dart`

The last write flow. Two things it gets right by refusing rather than
allowing: a CARD is not offered as somewhere to pay from, and the "Pay Debt"
button does not appear at all on a card that owes nothing. The service refuses
both, and offering them would be inviting the error rather than preventing it
— the affordance and the rule say the same thing.

"Pay it all off" fills in exactly what is owed. Typing that figure by hand is
the step most likely to go wrong by a kurus, and paying more than the debt is
refused.

A FROZEN card can still be paid, and the sheet says so. Freezing stops new
debt; trapping the user with a balance they cannot clear would be the opposite
of what the switch is for, and the absence of that guard is invisible
otherwise.

### Managing a subscription — `lib/screens/subscription_sheet.dart`

Three actions with three meanings, and the pair a user is most likely to
confuse is SKIP against STOP. Skip moves the due date on one period and leaves
the subscription running — "not this month", not "no more". Stop deactivates
it for good, and stopping is the only irreversible thing on the sheet, so it
asks first.

**Stopping does not delete the row.** Past transactions and the radar's
"already tracked" check both rely on it existing, and a physical delete would
turn settled history back into a fresh candidate to rediscover.

Changing the price leaves the schedule where it is, which is why this is not
"delete and re-add" — that would reset the due history and the alignment of
the next charge.

### A budget line — `lib/screens/budget_line_sheet.dart`

Two of its fields need explaining rather than labelling, because neither says
what it does: **"Every month"** makes the line a TEMPLATE, applying to every
month until a concrete line of the same identity overrides it in one; and
**"Carry the balance over"** takes LAST MONTH's leftover into this month's
limit and does not chain past it.

The category is optional and the sheet says what leaving it out costs: the
line still counts towards the month's total, but nothing tracks it against
what was actually spent. That consequence is invisible otherwise.

### Savings goals — `lib/screens/savings_sheets.dart`

Opening a goal, and moving money in and out of one. Every call passes
`goalUid`: that is the whole point of the field, since a numeric id can be
reused after a restore and a screen still holding an old card would otherwise
fund a goal the user never meant. The identity error is the one message in
`error_messages.dart` that explains rather than names — a stale card pointing
at a reused id is not something a user can reason about, and the only thing
that matters is that no money moved.

Two absences of a guard are said out loud, because a user cannot see a rule
that is not there: **the account may go negative** to fund a goal, and money
in a goal **is not spending** and never appears in an expense chart.

A credit card is not offered to move money between. A goal holds money aside
from a BALANCE, and a card has none — only a limit.

**One deliberate divergence from the desktop:** `createGoal` now refuses a
blank name. The desktop validates the amounts and not the name, which reads as
an oversight beside `create_account`, and an unnamed goal is indistinguishable
from its neighbours in a list. Nothing in the storage contract depends on a
goal being nameless.

### Buying and selling a holding — `lib/screens/asset_sheets.dart`

One thing here has to be said in words, because no layout says it: **"I
already owned this" writes the holding WITHOUT taking the money from any
account.** Getting that wrong either invents a purchase that never happened or
loses one that did.

Both forms show the arithmetic BEFORE anything is written — the purchase total,
and the sale's proceeds against its cost with the gain or loss signed. That is
not decoration: `parseAmountInput` makes a judgement on the user's behalf
(`1.234` is a thousand), and this is where they can see what it decided.

A credit card is not offered as somewhere to pay from. Charging a purchase to
a card as debt is a separate product decision, which the service refuses to
make silently and the form does not either.

### Recording a transaction — `lib/screens/add_transaction_sheet.dart`

The app's most frequent action, on the shell's one floating button. Cards
still has none: the reference design put one there on top of its own "+ ADD"
and it landed on the Freeze Card switch.

Two things here are more than form-filling:

- **A future date is explained, not just accepted.** The row is recorded as
  `pending` and reaches no balance until start-up settles it, so the form says
  so in place. Without that line a user records tomorrow's rent, sees the
  balance unchanged, and concludes the app dropped it.
- **The subscription radar is connected here** — the hook the desktop's
  `add_transaction` calls after a card expense, and the last piece of
  `transaction_service.py` that was still unported. A card is the GATE: the
  same spend from cash is simply an expense.

Instalments are cleared when the account changes. The service does not reject
a count on a cash account — it would simply write a plan against one — so the
form must not carry a choice made for a card onto something else.

**`categories` is seeded on database creation.** The schema dump carries no
rows, but the desktop seeds its category list on first run and those names are
matched as LITERALS by the budget, the distribution chart and the radar. A
database created here without them would agree on shape and disagree on
content. `lib/data/default_categories.dart` is GENERATED from the desktop's
own `default_categories`, not transcribed — a typo would quietly split a
category in two across the two apps.

### Every control is live or visibly unavailable

There is no third state. A user cannot tell an inert button from a slow one,
so they tap it again and conclude the app is broken rather than unfinished.
Nineteen `onTap: () {}` / `onPressed: () {}` are gone: disabled buttons, a
disabled search field, and a `NotYetChip` where a label alone would not
explain.

**The guard goes on the affordance, not inside the handler.** `onPressed: null`
removes the ripple and the pointer behaviour; an early `return` leaves both
and still invites the tap.

Settings gained the one real thing it can report: **where the encryption key
actually is**, from `KeyProtectionStatus`. It used to be a hard-coded sentence
claiming an owner-only file, which on a device with a working Keystore said
the exact opposite of the truth — the worst thing on that screen to be wrong
about. An unknown store reports "not known" rather than assuming the best
case. Its two dead switches went too: they moved local state and nothing else,
so a user could turn Dark Mode off and watch nothing happen.

It later gained its first row with a DESTINATION — Backup & Restore — and with
it a third shape the tile had to learn: available and tappable (a chevron),
available and static (neither chevron nor chip), unavailable (the chip). A
build with no profile behind it says so on the row itself rather than opening
a screen that then reports it can do nothing.

**And a defect that had been sitting in the shared primary button all along.**
`GradientButton` painted its gradient at full strength whatever `onPressed`
held, so a button waiting on a field the user had not filled was
indistinguishable from one that would work. Every widget test was asserting
`onPressed` — correctly null the whole time — and passing. It was invisible in
the source and obvious the moment the backup screen was opened on the
emulator. The tests now assert both halves.

**Proof:** `test/screens/dead_controls_test.dart` holds the rule for the whole
app rather than per screen, so a new dead control cannot arrive with a screen
that has no such test. The enforcement is a source-shape check — at runtime an
empty handler is indistinguishable from a real one — plus a walk pinning the
controls that currently have no flow.

Writing it produced a lesson worth keeping: the first version looped over
`find.byType(ButtonStyleButton)` asserting every button was live or disabled.
That was doubly worthless. The assertion is a tautology, since
`ButtonStyleButton.enabled` is DEFINED as `onPressed != null`; and
`find.byType` matches the EXACT runtime type, so the finder matched nothing
and the loop body never ran at all. Use `find.bySubtype<T>()` for a base
class.

### The wired tabs — what departs from the mockup, and why

**Home** shows net worth, cash and card debt from `AccountService`, and the
subscriptions from `RecurringService`. The balance ring's change chip is
omitted when there is nothing to report; an empty chip still drew a green pill
with an upward arrow, which reads as a gain.

**Cards** shows accounts, a card's limit and debt, its statement, and writes
the two card switches — the only writes in the app so far.

**Assets** reads the ledger for its period summary, its distribution and a
twelve-month trend, and `AssetService`/`SavingsService` for holdings and
goals. Three deliberate departures:

- Holdings are shown AT COST and say so. There is no price feed, so the
  mockup's "Current" column, its `+7.858,53 ₺ (+1.52%) Today` chip and its
  "Last updated: 23:00" line are all figures that do not exist. A cost basis
  presented as a market value is a lie the user cannot see through.
- The single hard-coded "Emergency Fund" became the savings goals, however
  many there are. Showing only the first would hide the rest.
- The trend is bucketed in Dart, not in SQL: `transactions.amount` is
  encrypted, so a `SUM() GROUP BY month` would add up ciphertext. Every month
  in the window is emitted, including the empty ones — a gap silently closed
  makes a quiet month look like it never happened.

**Tools** launches a monthly budget (`BudgetService`) and a savings-goal list
(`SavingsService`). The other seven cards are dimmed with a `NOT YET` chip and
are NOT tappable. The guard is on the affordance, not inside the handler: a
handler that returns early leaves the ripple and the pointer behaviour in
place, and a card that looks live and does nothing is a defect the user cannot
tell from a slow one.

The savings goal card is shared between Assets and the savings tool rather
than duplicated. The desktop has already paid for that kind of duplication:
its goal dictionary was built in two places, and a field added to one and not
the other made goal cards lose their colour after an operation.

### Savings goals — `lib/services/savings_service.dart`

Port of `services/savings_service.py`. A deposit ISOLATES money rather than
spending it: `accounts.balance` falls and the goal's `current_amount` rises in
one commit, and NOTHING is written to `transactions` — setting money aside
must not show up as spending in any chart. Withdrawal is the exact inverse.

**The status comparisons round in SQL, and that is the whole point.**
`current_amount` is a REAL updated with `current_amount + ?`, so it drifts:
nine deposits of 0.60 against a 5.40 target leave the raw column at
5.3999999999999994. Comparing raw values would leave a goal the user can see
is finished marked "active" — and on the withdrawal side would refuse them
their own money by a fraction of a kurus. The complementary rule matters as
much: a withdrawal that REALLY drops below the target reopens the goal, so
"completed" never becomes sticky.

Identity is checked fail-closed BEFORE any money moves. A numeric `id` can be
reused after a restore — delete a goal, restore a backup taken before it, and
the id is free for the next goal to take — so a screen still holding the old
card would otherwise fund a goal the user never meant. `goalUid` is the
durable identity; passing null skips the check, a deliberate door for tests
and maintenance that no screen may use.

`accountId` is required rather than defaulting to `DEFAULT_ACCOUNT_ID`: the
desktop removed its seeded default account, so that constant matches no row on
a fresh install and the default only ever produced ownerless writes.

**Proof:** `test/savings_service_test.dart`, 34 tests. Broken to check for
teeth: the identity check skipped or moved after the money moves, a deposit
also written as an expense, depositing to a completed goal, a missing account
undetected, the completion and reopening comparisons made raw, overdrawing
allowed, the ledger pointing both events at the wrong counterpart, the goal
side of a deposit dropped, a discarded goal recorded as refunded, a refund
reaching a credit card or silently skipped, deleting refunding when asked not
to, opening at the target not completing, a negative opening amount accepted,
the opening ledger line skipped at zero, every goal sharing one identity, and
`onlyActive` ignored.

Two of those came back green first time and both were real test weaknesses,
not equivalent mutants:

- The ledger's `ref_id` cross-check passed with the wrong counterpart because
  the account and the goal both had id 1 — each table starts its own
  AUTOINCREMENT at 1. The test now forces them apart and says why.
- The COMPLETION rule's rounding was never exercised: in the desktop's own
  drift sequence the raw value sits comfortably ABOVE the target at the moment
  completion is decided, so a raw comparison passes too. It needed its own
  scenario that lands the raw column just below.

### The monthly budget — `lib/services/budget_service.dart`

Port of `services/budget_service.py`: plan items, the subscription
reservation, category progress, rollover, suggestions and the trend series.

NO MONEY IS AGGREGATED IN SQL. `transactions.amount` is encrypted, so a
`SUM()` over it would add up ciphertext; every total is decrypted and summed
in Dart. `monthly_budget_plan.amount` is a plain REAL but goes through the
same reader, which tries the plain value first and decryption second, so one
rule covers both.

An amount that cannot be read invalidates the WHOLE derived result rather than
counting as zero — different from `LedgerEntry.isCorrupt`, and for a reason: a
statement row that says "unreadable" is honest, but a budget silently short by
one category is a wrong number presented as a right one.

The plan model is templates plus overrides. A template applies to every month
until a CONCRETE item of the same identity overrides it in one; identity is
the category if there is one, else the name, both compared case-insensitively
so "Market" and "market" do not become two lines. Among templates of one
identity, the LATEST wins.

Rollover carries the previous month's own `planned - actual` and DOES NOT
chain — one frugal January must not inflate every month after it.

**Proof:** `test/budget_service_test.dart`, 43 tests. Broken to check for
teeth: identity made case-sensitive or left untrimmed, templates not
overridden, earlier templates winning, the target year ignored, subscriptions
not reserved, an unusable subscription amount skipped instead of raised,
occurrences counted as one per month regardless of frequency, pending
transactions counted as spending, an unreadable amount zeroed, rollover
applied with the flag off or chained through the year, the suggestion
including the current month or summing instead of averaging, an existing
identity overwritten, templates copied by `applyPlanToYearEnd`, the positivity
/ blank-name / threshold checks dropped, the copy list validated inside the
transaction instead of before it, a derived item left as a template,
propagated copies written as templates, the source month copied onto itself,
the trend series run forwards, and the planner offering months already gone.

One mutant turned out to be genuinely EQUIVALENT rather than uncaught:
`applyPlanToYearEnd` starting at the source month instead of the one after it
changes nothing, because the identity skip eliminates the source month's own
rows anyway. It is documented at that line rather than papered over with a
test that would only have restated the deduplication.

### Recurring payments — `lib/services/recurring_service.dart`

Port of `services/recurring_service.py` plus the `recurring_payments` helpers
that live in the desktop's `database/db.py`. The subscription radar, the
charge/refund pair, and the date arithmetic underneath both.

The date arithmetic is where the traps are, and Dart makes one of them worse
than Python does: `DateTime(2026, 1, 31 + 31)` silently rolls into March
rather than failing, so every advance clamps its day explicitly. 31 January
plus one month is 28 February; plus three months is 30 April, not 90 days
later; and a payment pinned to the 31st that fell due on the 28th goes BACK to
the 31st next month rather than staying there. An unrecognised frequency
raises instead of defaulting to monthly — a payment quietly rescheduled to the
wrong period is worse than one that fails.

Charging is idempotent through SQLite, not through UI state: the marker's
primary key is `(payment, due date, 'charge')` and it is keyed on the due date
the payment had GOING IN, so a stale object still holding the old date
collides with the same marker instead of minting a second charge. The spending
rule runs on the charge's own transaction handle, inside the write lock.

Two departures worth knowing:

- An unreadable name or a non-positive amount reads back as `null`, not as
  `"Bilinmeyen Ödeme"` / `0.0`. The desktop learned the cost of the second
  one: `recurring_payments.amount` is a MAGNITUDE (direction lives in
  `transaction_type`), so a stored `-10.00` is an invalid record, not a
  reversed payment — and it entered the monthly budget as a `-10.00` reserve,
  overstating the spendable amount by 10 lira. Silently.
- `processDueRecurringPayment` REFUSES a payment whose name will not decrypt,
  where the desktop charges it under a placeholder. The description is the
  only handle `findCurrentPeriodCharge` has, so such a charge could never be
  refunded — and two of them would make a refund match the wrong one.

**Proof:** `test/recurring_service_test.dart`, 47 tests. Broken to check for
teeth: the monthly advance letting a day overflow, quarterly as 90 days, the
leap-day fallback spilling into March, an unknown frequency defaulting to
monthly, the recurrence day not pinned back, the initial-income clamp dropped,
a card counted as a subscription signal on its own, the card gate dropped, the
duplicate check made case-sensitive or made to count cancelled rows, a
non-positive stored amount read as valid, the charge marker keyed on the new
due date, an already-claimed marker ignored, the spending rule skipped, the
due date not advanced, the marker's transaction id never recorded, a corrupt
amount charged under a substitute, an unreadable name charged under a
placeholder, the refund made non-idempotent or treating a corrupt charge as no
charge, a price change resetting the due date or reaching a cancelled row,
cancel deleting instead of deactivating, and skipping not moving the date.
Every one failed the suite.

Two of those started as mutations that did NOT fail the suite — and both times
the mutation was the problem, not the tests: they had been written to add a
comment or a dead branch rather than to change behaviour. Worth remembering
when a mutation comes back green: check that it actually mutated something.

### Holdings — `lib/services/asset_service.dart` and friends

Port of the CRUD-and-arithmetic half of `services/asset_service.py` plus
`services/asset_purchase_service.py` and `services/asset_sale_service.py`.
The other half — `fetch_current_price`, the portfolio cache, the BIST100
batch fetch, the warm-up thread — is NOT ported; see open work 2, which
this doesn't need to be resolved to build.

`calculatePnl` is arithmetic only: Decimal throughout, quantized only on the
way out, and the signal decided from the unrounded ratio so a position up
0.0000001% still reads `profit`. One quirk is deliberately kept rather than
fixed: a zero purchase price reports `breakeven` despite a real `pnlAmount`,
because a zero cost defines no ratio — changing that is a product decision,
not part of a port.

Buying and selling are each one commit: the holding, the wallet transaction,
the balance move and the ledger entry together, in that order — the frozen
check on a purchase runs BEFORE the holding is inserted, so a rejection
leaves nothing behind. A sale is NOT frozen-checked at all; freezing stops
new debt, not access to money a sale is realising. Funding an unattributed
purchase never auto-selects a credit card, and among checking accounts
prefers the first one that can afford it over the richest one — a real
distinction, not just phrasing, and worth keeping in mind if refactoring the
picker.

A corrupt row is NOT skipped-and-reported the way a transaction row is
(compare `LedgerEntry.isCorrupt`). `getAllAssets` fails the whole read: a
portfolio total built by silently dropping one holding would understate
itself without saying so, and that is the desktop's own choice in
`get_all_assets`, not a departure.

Purchase/sale descriptions carry Western `1,234.56` grouping — deliberately
NOT the Turkish formatting `AccountService`'s errors avoid entirely. Unlike
those errors, a description is DATA: it is encrypted and stored in
`transactions.description`, and a backup restored on the other app has to
read the string the desktop itself would have written.

**Proof:** three test files, 44 tests. The purchase quantization test is
worth noting for HOW it checks: Decimal arithmetic here carries no
representation artefact the way the desktop's raw floats did (2456.78 x
0.12345678 is an *exact* decimal, just a long one), so comparing the stored
amount against an expected value after re-quantizing it in the assertion
would pass even on a mutant that skipped quantizing entirely. The test
instead checks that quantizing the STORED value again is a no-op — genuine
evidence it was already rounded before it reached the ledger.

Checked for teeth by breaking each rule: the signal decided from the rounded
percentage instead of the raw ratio, inputs rounded before the arithmetic
instead of after, a corrupt row silently dropped, the positivity check
skipped, `deleteAsset` reporting success on a no-op, the frozen check moved
after the asset insert, the invested amount left unquantized, the funding
picker preferring the richest account over the first affordable one, the
picker allowed to choose a credit card, selling more than is owned, sale
proceeds left unquantized, a partial sale deleting the holding anyway, a sale
crediting an unrelated account, and the profit/loss sign hard-coded positive.
Every one of those failed the suite.

### Transactions — `lib/services/transaction_service.dart`

Port of `services/transaction_service.py`: everything that writes to
`transactions`, plus `adjustAccountBalance` in `lib/data/balance_events.dart`.
Two rules carry it. A transaction and the balance it moves are ONE commit,
with the credit-limit decision taken inside that commit against the snapshot
the write will use. And a future-dated transaction is `pending` and touches no
balance — money does not appear in an account before its date — which means
`settleDueTransactions` is the only thing that posts one, and a build that
never calls it never posts a future-dated row at all.

The dashboard's period queries were held back until a screen actually needed
them; the Assets tab brought that need. They are here as a `DashboardPeriod`
enum plus `getTransactionsByPeriod` and the two opening-balance readers. The
desktop passes its Turkish UI labels ('1 Hafta', 'Hayat Boyu') as the filter
value, which makes the interface's wording part of the query; an enum keeps
the period a decision and leaves the wording to the chips. Two details worth
not re-deriving: every window that asks SQLite for `'now'` also asks for
`'localtime'`, or the comparison runs against UTC and "today" silently starts
yesterday for the hours a timezone runs across the date boundary; and an
opening balance never reaches `transactions` at all, which is why the
distribution chart reads it from `balance_events` instead.

**Proof:** `test/transaction_service_test.dart`, 43 tests, including the
acceptance scenario the desktop was originally asked for: a 10,000-limit card,
a 500 supermarket spend, net worth down exactly 500 and cash untouched.

Checked for teeth by breaking each rule and confirming the suite failed:
posting a future-dated row to the balance, writing everything as `completed`,
dropping the per-row savepoint in settle, settling on a frozen account, never
marking a settled row `completed`, comparing the due date strictly, truncating
the monthly instalment, rounding it half-UP, charging the monthly amount
instead of the whole one, making a single instalment a plan, cancelling a
posted transaction, rescheduling to a date-only value, showing pending rows on
a statement, reporting an unreadable amount as zero, flipping the balance
sign, writing off a missing account silently, and skipping the ledger event.

The instalment rounding case is worth keeping in mind: `100 / 3` does not
separate truncation from half-even from half-up — all three give 33.33. The
values that do are in the test's comment, and the first version of that test
missed a truncation mutation because it only used `100 / 3`.

### The REAL column's drift — `test/real_balance_drift_test.dart`

Port of `tests/test_real_balance_invariants.py`, and the reason it exists is
not obvious from any one file. `accounts.balance` is a `REAL` column updated
with `balance = balance + ?`, so the accumulation happens in SQLite's binary
floating point no matter how much `Decimal` the Dart side uses: 0.01 added ten
thousand times lands at 100.00000000001425.

The guarantee is not that the raw column is exact — it is that **the figure
shown is correct and the decision agrees with the figure shown**. Quantizing
on the way out of the column is what delivers it. The test drifts a real
account and then asserts the whole displayed balance is spendable, and the
whole displayed available limit too.

One measured difference from the desktop: it records that removing either one
of its two guard layers left the test green, the other absorbing the drift.
That is not true here — each removal fails this file alone, because once a
value is a `Decimal` the arithmetic after it is exact and there is no second
place for drift to hide.

### Screens — `lib/screens/`

The five tabs as first BUILT, before any of them read data — the wiring that
came later is under "The screen–service join" above. All five were verified by
running them on the emulator, not by reading the code, and three defects
surfaced only that way:

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

### 1. Price fetching — needs a decision

The desktop runs `services/asset_price_worker.py` as a **subprocess**
(`asset_service.py:700`). That architecture does not work on Android: there is
no second Python interpreter to spawn. It has to become an in-process
background task, and the price source itself needs deciding — `yfinance` has
no Dart equivalent, so this is either a direct HTTP call to a chosen provider
or a backend of your own.

Until it is settled, the Assets tab shows holdings AT COST and says so. That
is a deliberate holding position, not an oversight: `AssetService.calculatePnl`
already takes a current price as a plain argument, so wiring a feed in is a
small change once the source exists.

### 2. i18n

The desktop has `ui/i18n.py` with a full Turkish/English map. Here the NUMBERS
are already Turkish-formatted — `lib/ui/money_format.dart` — while the labels
are English strings sitting in widgets, which is the wrong way round for a
Turkish user reading `1.234,56 ₺` under the word "Cash".

Mechanical, but it touches every screen, and `error_messages.dart` was written
for exactly this: the services raise codes and one file turns them into
sentences, so the wording moves without a rule moving with it.

### 3. Shipping

App icon, launch screen, release signing, Play Store listing. The last of
those is not engineering.

### 4. Not yet considered at all

Widening beyond a phone (tablet layouts), accessibility beyond what Material
gives by default, and anything to do with more than one user or device.

### What is NOT coming from the desktop

For the avoidance of re-deriving this each session — the desktop's `services/`
is fully accounted for. What has not been ported is not forgotten:

- **Dashboard, insight, projection and metrics services.** They compute the
  Home tab's forecast and health score. Those cards are drawn with a `NOT YET`
  chip rather than invented figures.
- **Migration engines** (`migration_service`, `savings_migration`,
  `crypto_migration_service`, `startup_recovery`). A fresh mobile install has
  nothing to migrate from. Restoring a desktop backup now works, so the
  question is live — and the answer is that a desktop database is migrated BY
  THE DESKTOP before it is backed up. A database stamped at a schema version
  this app does not know is refused with a message saying to open it on the
  desktop once; see "The package around it".
- **Price machinery** (`price_service`, `price_providers`, `price_guard`,
  `asset_price_worker`, `crypto_top100`, `brand_icon_service`, `logo_service`).
  Item 1.
- **Backup service.** Ported. `key_recovery_service.py` is the exception —
  see "What the backup work did NOT port".
- **`background_task_manager`.** Flutter has its own answer; the desktop's
  thread pool does not port.

## Environment

Set up on this machine and verified working:

- JDK 17 (`jdk17-openjdk`). **Not** a newer JDK: Gradle/AGP support for the
  latest releases lags, and 17 is what Flutter's Android build is most widely
  tested against.
- Flutter 3.47.1 stable, Android SDK at `~/Android/Sdk` (platform 35 and 36,
  build-tools, NDK), `ANDROID_HOME` exported from `~/.config/fish/config.fish`.
- Emulator AVD `archlence_pixel` (Pixel 7, Android 15).
  Start:
  `$ANDROID_HOME/emulator/emulator -avd archlence_pixel -no-snapshot -gpu swiftshader_indirect`

  The full path is not decoration: `config.fish` adds `cmdline-tools`,
  `platform-tools` and `build-tools` to the PATH but NOT `emulator`, so the
  bare command fails with "no such file". Either use the path above or add
  `fish_add_path $ANDROID_HOME/emulator` to the config.
- `flutter doctor` reports an Android licence warning. It is **cosmetic**: the
  AUR `android` CLI does not emit the output format `flutter doctor` parses.
  The licences are accepted and builds work — the real check is that
  `flutter build apk` succeeds.

Regenerating parity vectors needs `pycryptodome` and `platformdirs`, neither
installed system-wide. A venv in the DESKTOP checkout is used:

```bash
python3 -m venv aeadvenv
./aeadvenv/bin/pip install pycryptodome platformdirs
```

The generators live in `tool/` and are run from the desktop checkout, because
each reads that project's own modules:

| Script | Regenerates |
| --- | --- |
| `tool/emit_backup_vectors.py` | `test/backup_vectors.txt` |
| `tool/emit_backup_package.py` | `test/desktop_backup.archlence-backup` |
| `tool/emit_default_categories.py` | `lib/data/default_categories.dart` |
| `tool/emit_aead_vectors.dart` | the Dart-written AEAD envelopes the desktop reads back |
| `tool/emit_mobile_backup.dart` | a package for the desktop to read back |

The last two run the other way — this app writes, the desktop reads — and are
run by hand, because the assertion lives in the desktop checkout. Each file's
doc comment carries the exact command and the fixed key to check the answer
against. `emit_mobile_backup.dart` goes through `flutter test`, which is the
only runner that has this package's Flutter dependencies.

`keyring` is deliberately absent from `aeadvenv`: without it the desktop's
`create_platform_key_provider` falls back to its file provider, so the key a
generator writes is the key its encryption uses. With a Secret Service
available it would pick up whatever the developer's session keyring holds.

Nothing that claims parity is transcribed by hand. A generator kept outside
the repository is a generator that does not exist the next time it is needed.

## Working agreement

Three habits, kept because each has repeatedly caught defects that review did
not.

**Run it, don't just read it.** Every screen defect in this file was invisible
in the source: the tab scroll offsets, the clipped card name, the floating
button covering a switch, `setState` handed a closure returning a `Future`, a
change chip drawn empty so a green pill with an upward arrow read as a gain,
`ServicesScope` placed below the Navigator where no pushed route could reach
it, a primary button that painted itself enabled whatever its callback held,
and a profile whose encryption key did not exist until something happened to
need one.

The last two are worth a second look, because both had passing tests over the
exact code that was wrong. The button's tests asserted `onPressed` — correctly
null — and never asked what the user could SEE. The key's absence needed a real
profile that had written an account and nothing else, which no test built and
every fresh install does.

**A finder matching is not a user reaching.** A lazy list builds a cache
extent beyond the viewport, so a widget can be in the tree and still off
screen — and `tester.tap` on one computes a point outside the viewport and
lands nowhere. That cost a whole session's wrong diagnosis: it looked like a
screen opening without its data, when the screen had never opened. The device
tests scroll with `ensureVisible`; the widget tests sidestep it entirely by
laying out on a 2400px surface, which is fine for testing the screen–service
join and proves NOTHING about reachability. Only the device tests speak for
that.

**Prove parity against the real thing.** Testing a port against expectations
derived by hand tests the derivation, not the port. Every parity claim here
rests on output generated by the desktop's own modules — its
`quantize_financial`, its `aead_crypto`, its `initialize_database()`.

**`setState` must never be handed a callback that returns a Future.**
`setState(() => _data = _load())` reads as an assignment and is not one: the
arrow body RETURNS the assignment's value, Flutter asserts on that, the
assertion is swallowed, and the state is simply never updated — a screen that
does not change with nothing in the log to say why. It has been walked into
three times here, and twice it surfaced as a widget test failing for a reason
that looked unrelated. `test/no_async_set_state_test.dart` now holds the line,
with no exception for calls that happen to be synchronous: text cannot tell
`_load()` from `value.round()`, and a rule with a judgement call in it gets
argued with.

**Check the tests for teeth.** Break the rule deliberately and require the
suite to fail. This is the habit that has paid the most, because a green suite
says nothing on its own. What it has caught, all of it in tests that looked
thorough:

- an assertion that re-quantized a stored amount before comparing it, so it
  passed even with the quantizing removed entirely;
- a `ref_id` cross-check where the account and the goal both happened to be
  id 1, because each table starts its own `AUTOINCREMENT` at 1;
- a completion rule whose rounding was never exercised, because in the
  sequence used the raw value sat safely above the target at the moment the
  decision was made;
- an instalment-rounding test using `100 / 3`, which does not separate
  truncation from half-even from half-up — all three give 33.33;
- a timezone rule only exercised for the few hours a day when UTC and local
  dates differ, so it would have passed on most runs and failed on some;
- `findsWidgets` on a figure that also appeared in a total above it, so the
  tile could show the wrong number and the assertion still held.

Two related notes. A mutation that comes back GREEN is not automatically an
uncaught defect — check first that it actually changed behaviour (twice it had
only added a comment or a dead branch), and second whether it is genuinely
EQUIVALENT (`applyPlanToYearEnd`'s `+ 1` is, and says so at the line). And a
test that cannot be made deterministic should say why in place, rather than
being left to look like flakiness.
