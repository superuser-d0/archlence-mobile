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

**And the screen lock works, which it never did.** `local_auth` needs a
`FragmentActivity` to attach its prompt to, and `MainActivity` extended the
Flutter template's `FlutterActivity` — so the switch had been silently inert
on every build ever made. Found by putting a PIN on the emulator and pressing
it. See "The verification round".

**And the ring says which way it went.** The balance ring's change chip is
back: what the net worth moved over the last 30 days, in lira and per cent,
against a baseline read out of the balance ledger. When the ledger cannot
answer for that day it draws nothing at all rather than a zero.

**And it can work a figure out.** Four calculators — a plain one with its own
keypad, deposit interest, compound growth, and a Turkish consumer loan with
KKDF, BSMV and a full payment plan. Seven of the nine Tools cards are live;
only the What-If sandbox and Reset Data still carry a chip.

**And it has a calendar.** A month grid marks the days that had activity and
opens only the day tapped — the grid needs no encryption key at all, because
which days had rows is the one thing the plain `transaction_date` can answer.

**And it can find things.** The Home search box was a disabled placeholder;
it now searches account names, category names and the descriptions of recent
transactions, folding Turkish properly so "ISI" finds "ısı" and "sirket" finds
"Şirket". Tapping a result goes where that thing lives.

**And it knows what a household chose.** Category Settings marks which
categories are ones a household must have; the Assets tab splits income and
spending along that line and prints both halves. The desktop's own
`financial_summary_service` does the bucketing, checked against vectors that
module generated itself.

**And it speaks Turkish.** Every label in the app comes from `lib/l10n/`,
which carries Turkish and English in full. A phone set to either gets that
language; a phone set to anything else gets Turkish, and Settings can override
the choice. The one thing NOT translated is the backup layer's diagnostic
detail — see "What i18n did not cover".

**And it does not fall apart on a wide screen.** Every screen was walked at
five sizes, from a landscape phone to a 1280dp tablet; nothing overflows, and
content is held to a readable column width rather than running 150 characters
to a line. Not a tablet layout — see "Wide screens" for what that distinction
means.

**And it looks like itself.** The launcher icon is the desktop app's own
mark, the label under it says Archlence rather than `archlence_mobile`, and a
cold start opens on the app's own dark instead of a white flash.

**Release builds are signed properly, or refused.** The debug-key fallback the
Flutter template ships with is gone. What is NOT done — because it cannot be,
by anyone but the person shipping — is the keystore itself: there is no
release key on this machine yet, so no installable release APK exists yet
either. `android/key.properties.example` carries the one command that makes
one.

**And they are shrunk, which they always were.** R8 runs on every release
build and always has — Flutter's Gradle plugin turns it on, so the template's
silence on the subject is not the same as it being off. Measured, and the
minified APK has now been installed and driven on the emulator. See "R8 —
already on, measured, and run".

**And the key can travel on its own.** Settings writes a key recovery
package — the encryption key wrapped under a passphrase, no data with it — and
reads one back after proving it opens what is already on the phone. It answers
the case a whole backup does not: the data is still here and the KEY is gone.
Wire-compatible with the desktop's, checked in both directions against
`services/key_recovery_service.py`.

**And holdings show a live price.** Crypto, gold and currency go through
`LivePriceService` — CoinGecko and Frankfurter, called straight from the
phone, no backend of ours. Shares need an API key of the user's own, entered
in Settings, because BIST data is commercial and a key in an APK is a public
key; without one they stay at cost, and the tab says which it got per
holding rather than carrying a blanket disclaimer that would be wrong for
most of a portfolio.

The share provider is the one piece of the price layer whose live response
has NOT been seen by this codebase — checking it needs a key that belongs to
whoever signs up for it. See "Shares, on the user's own key".

**And it is built on Windows again, on a machine that is not the same one.**
The third move — CachyOS back to Windows 11 — and the first that crossed
between machines rather than between systems on one: a laptop where the last
three setups were a desktop. The crossing cost the repository nothing, which
is what the previous two paid for. It did cost one line of
`android/app/build.gradle.kts`, and not because the machine changed: Google
stopped publishing a bare `android-37` platform, so `compileSdk = 37` needed
`compileSdkMinor = 0` beside it to name a package that exists. Two more
renamings in the SDK's own tooling came with it. See "The move to a laptop".

**And it is public, under Apache-2.0.** There had been no licence file at all,
which means all rights reserved — nobody could legally use, fork or contribute
to a repository that was about to be linked from a store listing. The desktop
app moved to the same licence rather than the two halves carrying different
ones. See "The licence, and the page that shows it".

**And there was a build a store would take.** The release keystore existed, and
`flutter build appbundle --release` — a command this project had never run —
produced a 66.7MB bundle signed by that key rather than by the SDK's debug
one, verified by reading the certificate out of it. What a phone actually
downloads is about 11MB, measured rather than estimated. The key store moved
to `flutter_secure_storage` 11 on the way, which cost two build failures and
turned up a default that had flipped from reporting an error to erasing the
data. See "The key store, moved to version 11" and "The first App Bundle".

**And the key that signed it is gone, and a new one has taken its place.**
That bundle was built on the previous machine and the keystore went with it.
A replacement was made here, and `flutter build appbundle --release` produced
a 62.0MB bundle signed by it — `jarsigner` says `jar verified` and the
certificate reads `CN=Superuser-d0, O=Archlence, C=TR` rather than
`CN=Android Debug`. What that does NOT settle is Play, which knows the old
certificate: adopting this one needs a reset Google performs. Nobody is
stranded — the release was pulled before it reached users. See "The key that
was on the other machine".

**And thirteen defects were found and fixed on the way to a listing.** Two
sweeps did it, both asking the same question the suite had never been asked:
lay out something other than the screen the app opens on. Six came off the
four tabs no test had ever built; seven more came off the sheets, and those
seven were a single missing line repeated across seven dropdowns — one of them
152 pixels wrong at the default font scale, on a sheet with its own end-to-end
test file. None was a regression. All are fixed. See "The six, fixed" and
"The layer under the tabs".

A third sweep walked the nine pushed routes and found none — the comparison
worth keeping, since that is the one layer which already had guideline
coverage. And a fourth question, asked of the test surface rather than of the
app, found three more: every sweep renders a screen in the state it OPENS in,
the per-screen tests drive real states on an 800dp surface, and nothing
covered a real state at a real width. Sixteen defects in all.

1117 unit tests and 14 device tests pass, and `flutter analyze` is clean. No
control in the app is inert. The count grew by 214 because what it did not
cover is now covered rather than assumed.

## Pick up here

**The app is finished, and what stands between it and a listing is a key
rather than any code.** The toolchain now lives on a Windows laptop and every
claim in this file was re-run on it: `flutter analyze` clean, 1117 unit tests
and 14 device tests passing, a debug APK built and driven on the emulator, and
a signed release bundle. That bundle is signed by a NEW key, because the one
that signed `v1.0.0` was on the previous machine and is gone — so what is left
is two questions in Play Console rather than anything buildable. Everything
else that used to be open here is closed: the privacy policy, the Data
safety answers, the TalkBack hour, label quality, and the Turkish that got
the first release pulled.

### Thirteen defects found and fixed, and what found them

A pre-release sweep asked the suite one question it had never been asked —
lay out something other than the screen the app opens on — and it kept
answering. Six defects on the four tabs no test had ever built, then seven
more behind the sheets, and the second seven were one missing line repeated
across seven dropdowns. **All thirteen are fixed**, each one proved by a named
red case turning green. See "The six, fixed" and "The layer under the tabs".

A third sweep then walked the nine pushed routes and found nothing — its own
finding, because that is the layer which already had guideline coverage. Then
the last open decision, about the 800dp surface every widget test uses, was
measured rather than argued: moving it to a phone width surfaced **three more
defects**, in states no sweep can reach because every sweep renders the state
a screen OPENS in. Sixteen in all, all fixed.

Three sweeps, two source rules and a driven-state file hold the line now, and
the suite went from 903 tests to 1117. **No screen is left that nothing lays
out at a phone width, and no state that broke one is left unguarded.**

**One of the fixes was worse than the defect**, which is the part worth
carrying forward: `IntrinsicHeight` removed the Tools overflow, turned every
test green, and grew a 130dp gap the design never had. No test could have
said so. It was found by installing the release build and looking at it.

**The release path itself is clear.** The signed bundle builds, and the
release APK was installed on a clean device and driven by hand: onboarding,
an account, an income, a Bitcoin purchase — and the holding read `Current`
188.480,46 ₺ rather than `Cost`, with R8 on and the release manifest under it.
The last open release-only question is answered; see "The first App Bundle".

### The things that are not coding tasks

The three that used to be here — the TalkBack hour, the privacy policy and
Data safety, and opening the developer account — are done. What replaced them
is smaller and all of it is somebody's judgement rather than a session's work.

1. **Two questions in Play Console, and they set everything after them.**
   Whether the app entry still exists with Play App Signing on it, in which
   case the lost keystore is only an upload key and Google will reset it; or
   whether the app itself was deleted, in which case the package name is spent
   and a new one is the answer. See "The key that was on the other machine".
2. **A new keystore, made by hand and backed up off this machine.** The
   command is in that section and in `android/key.properties.example`. It is a
   credential; no session should type its password. The last one was lost
   because it existed in exactly one place.
3. **Whether the phone PRONOUNCES the Turkish correctly.** The strings are
   right — 57 of them were rewritten out of the informal register — and the
   announcements are in visual order, but no dump can say how TTS reads them
   aloud. It needs Turkish ears and about twenty minutes.

### What recent sessions closed

| | Item | Section |
| --- | --- | --- |
| 1 | The toolchain rebuilt on Arch, and every claim re-verified on it | "Environment" |
| 2 | A wrong diagnosis of the suite's speed, measured and replaced | "The move back to Linux" |
| 3 | The key store moved to version 11, and a default that would have erased it | "The key store, moved to version 11" |
| 4 | The first App Bundle, signed, measured, and 11MB on a real phone | "The first App Bundle" |
| 5 | A release build installed and driven by hand to a live price | "The first App Bundle" |
| 6 | Six defects on four tabs no test had ever opened | "The pre-release sweep" |
| 7 | Those six fixed, and a fix that broke the screen its tests passed | "The six, fixed" |
| 8 | Seven more behind the sheets, all one missing line | "The layer under the tabs" |
| 9 | The third layer swept and clean, and what that comparison says | "The third layer, which was clean" |
| 10 | Three more found by measuring the test surface instead of arguing about it | "What the 800dp surface was hiding" |
| 11 | A privacy policy Play would accept, generated from one source in two languages | "The privacy policy, generated rather than written twice" |
| 12 | The Data safety answers, decided by recording what the app actually sends | "The Data safety declaration, decided by listening to the wire" |
| 13 | The TalkBack hour: two defects, two false alarms, and three instruments that disagreed | "The TalkBack hour, and what the tooling gets wrong" |
| 14 | Label quality: a whole tab that was one sentence, and four smaller things | "Label quality, which is the half a guideline cannot reach" |
| 15 | A first release published, then pulled: the Turkish was in the wrong register | "The Turkish was in the wrong register" |
| 16 | The toolchain rebuilt on a Windows laptop, and every claim re-run on it | "The move to a laptop" |
| 17 | Three renamings in the Android SDK, one of which cost a line of source | "The move to a laptop" |
| 18 | The release keystore, lost with the machine it lived on, and what that blocks | "The key that was on the other machine" |
| 19 | A replacement keystore, and the first signed bundle built on this machine | "The key that was on the other machine" |

The machine moved from Windows 11 to CachyOS and the whole toolchain was
rebuilt under `~/dev` without root; nothing in the repository had to change
for it, which is what the last machine move paid for. Then the dependency
knot that had been filed as "not urgent" turned out to hold a build warning
with a deadline on it, and untying it turned up a default that flips from
"report the error" to "erase the data" between the two versions. The keystore
followed, and with it the first bundle this project has ever produced that a
store would accept.

Then the machine moved once more, to a Windows laptop, and the toolchain was
built from nothing for the fourth time — under `C:\src`, with nothing
installed as Administrator, for the same reason the last one avoided `sudo`.
That rebuild is where the three SDK renamings surfaced, because a toolchain
installed today is the only thing that asks the SDK what it currently ships.
And it is where the keystore turned out not to have come with the project: the
one thing on the release path that no session can install.

### What is deliberately NOT in 1.0

So that the omissions are decisions rather than drift. **None of these is
drawn in the app any more** — see "Not drawn rather than marked" — which is a
change from how this list used to read.

* **The Home forecast card and the health score** — need `dashboard`,
  `insights`, `projection` and `financial_metrics` together. A project, not a
  session, and the biggest single thing left in the app.
* **The history "time machine"** — `history_service.py`'s `diff_between` and
  event attribution. One question out of that module IS ported; see "The
  change chip, and the balance at a past day".
* **The What-If sandbox and Reset Data** — the last two Tools cards without a
  destination.
* **Tablet layouts** — wide screens no longer stretch, but nothing uses the
  space. A design decision for someone holding a tablet.
* **The rest of accessibility** — see item 3 above.

### Two things worth checking the first time they can be

* **A BIST key.** The share-price path is tested against canned responses and
  has never met the live API — see "Shares, on the user's own key" for what to
  look at if the prices stay at cost. The two KEYLESS providers have now met
  theirs; see "The device pass".
* **A phone rather than an emulator.** Everything above ran on
  `archlence_pixel`. The screen lock in particular now has a real credential
  behind it, but a fingerprint sensor is not a PIN.

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
in `ui/i18n.py` and this app now has the same, and a code survives translation
where a matched string does not. That decision paid: turning the whole app
Turkish meant editing `error_messages.dart` and nothing in `services/`.

`KeyProtectionStatus` was moved onto the same footing when the labels landed.
It used to carry `'Android Keystore'` and a sentence about a fallback; it now
carries `KeyProtectionMethod` and `KeyProtectionWarning`, and the words live
in `settings_screen.dart`. A crypto layer does not know what language the
phone is in.

The same line separates data from interface text. `network_logo` values, and
the `Borç Ödeme` category a card payment is filed under, stay verbatim —
the desktop groups and reports on those literals, so translating them would
split one category in two. A `type_label` field was dropped for the opposite
reason: it was a Turkish UI string sitting on a data model.

### The labels come from ARB files, and Turkish leads

`flutter gen-l10n` over `lib/l10n/app_en.arb` and `app_tr.arb`, rather than
the desktop's `tr(text)` map keyed on Turkish source strings. Two reasons, and
both are about what fails loudly:

* A key that does not exist is a **compile error**, where a lookup that misses
  returns its own argument and renders as English nobody notices.
* Placeholders are typed. `l10n.payDebtAll(formatLira(card.debt))` will not
  compile with the wrong arity, where a hand-rolled `trf` finds out at run
  time — on the one screen a user is about to spend money on.

The template is **English**, and Turkish is the FALLBACK. `supportedLocales`
in `lib/ui/app_locale.dart` is written out by hand with `tr` first, because
Flutter resolves an unsupported device locale to `supportedLocales.first`: a
phone set to German gets Turkish, not English. `test/l10n_test.dart` holds
that list against the generated one, and holds each ARB against the other so
that a key present in English and missing in Turkish is a failing test rather
than an English label on a Turkish screen.

The desktop's `ui/i18n.py` was the source for the WORDING, not the mechanism —
its map gives the Turkish this app's users already read on the desktop for
every shared concept, down to `Hayat Boyu` for the all-time filter.

### The numbers do not move with the language

`money_format.dart` writes `1.234,56 ₺` and `%12,5` in either language. The
grouping is what the design specifies and what the desktop stores, not a
translation, and an English label over a Turkish figure is the app being
honest about a lira account. Switching the separators with the labels would
make one balance read as two different amounts.

The same line, drawn again: **category names, asset types and `network_logo`
values stay verbatim in both languages.** The desktop groups and reports on
those literals. The one deliberate exception is the account name onboarding
prefills — `Nakit` / `Cash` — because nothing groups on an account's name and
the user types over it anyway.

**Language names are never translated.** `Türkçe` stays `Türkçe` in the
English interface. Someone stranded in a language they cannot read has to be
able to find their way out of it.

### Upper-casing is a language operation

`SectionLabel` upper-cases its heading, and Dart's `toUpperCase` is
locale-independent: it maps `i` to `I`, which is a different letter in
Turkish. Left alone, the Settings headings came out as `GÜVENLIK` and
`GIZLILIK`. `localizedUpperCase` in `lib/ui/app_locale.dart` fixes the two
Turkish i's and is used everywhere the app upper-cases its own text. It is
never applied to text a user typed.

### Prices come from the phone, from keyless sources

The question had two axes and they are easy to conflate: WHERE the data comes
from, and HOW the phone gets it. The second was decided first, because it
decides the first.

**The phone calls the provider itself.** No backend. The reason is not cost or
effort — it is that `onboarding_screen.dart` tells the user "No account, no
server. Nothing is uploaded and there is nothing to sign in to", and a price
proxy would make that false: the phone would be telling a server of ours which
symbols the user holds, which is a fair sketch of their portfolio. Fetching a
whole index instead of named symbols would blunt that, and it would still leave
an app that stops working when a server we run stops running.

One consequence runs the other way from intuition and is worth writing down:
these providers rate-limit **per IP**. Every phone therefore arrives with its
own budget, where a proxy would concentrate every user onto one address and be
throttled far sooner. For this workload, direct is not just more private, it
is more robust.

**No API key ships in the app.** A key in an APK is a public key — anyone can
pull it out — so only keyless providers are usable by default. What that buys,
and what it costs, is the next decision.

**Crypto, currency and gold go live. BIST does NOT.** Checked in August 2026:
Borsa İstanbul data is commercial. What exists is enterprise feeds, 15-minute
delayed resellers, and pay-per-result scrapers; there is no free tier worth
building on. So shares stay AT COST and the Assets tab goes on saying so —
which is already true today and stays true rather than becoming a lie.

**And the desktop's own source is rejected for a shipped app.** The desktop
reaches BIST through `yfinance`, which drives endpoints Yahoo has never
documented and shut its public API behind in 2017: undocumented limits, no
service contract, and changes that break the library without notice. On one
developer's machine that is a nuisance. On an app installed on other people's
phones, one Yahoo change takes out every install at once, and it would be the
single point of failure for the whole portfolio rather than for shares alone.

**A key the USER supplies is the way BIST opens later.** Entered in Settings,
kept in the platform secure store beside the screen-lock and language
preferences, spending the user's own quota. It is friction most people will
not accept, which is exactly why it is an addition and not the default: the
app works keyless, and someone who wants live shares can pay that price
themselves. Not built yet, and deliberately its own session.

**The providers.** Two of them are the ones the desktop already proved, used
the same way: **CoinGecko** for crypto in USD, **Frankfurter (ECB)** for a
currency's lira value.

Gold needed an answer of its own, and it is the one place this decision does
not simply inherit the desktop's. The desktop takes the ounce from `GC=F` —
Yahoo — which is exactly the source rejected two paragraphs up, and its own
fallback module says in as many words that `GC=F` has no fallback. Keeping the
formula while dropping Yahoo would have left gold with no source at all.

The answer is **PAXG**, tokenised gold, from CoinGecko — the provider already
being called, keyless, no new dependency, one ounce of allocated gold per
token. Measured on 26 August 2026: PAXG 4612.05 USD and XAUT 4602.96 USD,
nine dollars apart, which is the sanity check that the token is tracking the
metal rather than drifting on its own. Gold therefore stays derived, but from
`PAXG x USDTRY / 31.1034768` rather than from anything of Yahoo's.

One thing measured while deciding:

* ECB rates are **daily**, not live — the response carries the previous
  business day's date. Fine for a personal ledger, and it has to be labelled
  rather than presented as a live quote.

(`api.frankfurter.app` answers 301 to `api.frankfurter.dev/v1/`. Checked
separately, with an actual request rather than by inspecting the library:
`dart:io`'s `HttpClient` follows it by default — `followRedirects` defaults to
`true` — the same as `requests`. An earlier version of this entry claimed the
opposite from general expectation rather than a test and was wrong; the port
needs no special handling for it, only the old host as a fallback base if the
provider is ever queried directly without going through the redirect.)

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

### Apache-2.0, on both repositories

Not MIT, which the desktop carried and this one had nothing at all. The two
clauses that decided it are §3's explicit patent grant and §6's statement that
the licence does not hand over the name; the cost is incompatibility with
GPLv2-only projects. Reasoning in full under "The licence, and the page that
shows it", including why the desktop moved with it rather than the two halves
diverging.

### A feature that does not exist is not drawn

**This replaced the opposite decision**, which was that an unbuilt control
should be marked rather than hidden. The chip's rule still holds for a control
that EXISTS and is unavailable in some state; it never fitted a row for
something never built. Reasoning under "Not drawn rather than marked", and the
switch is one constant — `showUnbuiltFeatures` in `lib/widgets/not_yet.dart`.

## Done, and how it was proven

Long, and grouped roughly by layer rather than by date:

| Layer | Sections |
| --- | --- |
| Foundations | Money · Encryption · Database · The REAL column's drift |
| Services | Accounts · Transactions · Holdings · Recurring payments · The monthly budget · Savings goals · Price fetching · Shares on the user's own key · Category settings and the main/extra split · Search · The calendar · The four calculators · The change chip |
| Backup | The backup's cryptographic core · The package around it · Restoring · The key on its own |
| Security | The screen lock · The verification round |
| Language | i18n · What i18n did NOT cover |
| Shipping | The icon and the launch screen · What running it caught · Release signing · R8 |
| Screens | The accessibility pass · Wide screens · The screen–service join · The wired tabs · Every control is live or visibly unavailable · Screens (as first built) |
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
copy of just the key, without the database — has since been ported; see "The
key on its own".

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

**And for a long time none of it ran.** Every decision above was right and the
prompt never appeared: `local_auth` needs a `FragmentActivity` and
`MainActivity` was a plain `FlutterActivity`, so `authenticate()` threw and
the switch did not move. It took putting a PIN on the emulator to find —
see "The verification round".

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

### i18n — `lib/l10n/`, `lib/ui/app_locale.dart`

The app speaks Turkish and English — 348 labels in each. Every user-facing
string in `lib/` comes from the ARB files; what is left as a source literal is the product name, the
numeric hints (`0,00`, `15`, `#### #### #### 1234`), and the technical detail
described below.

**Where the choice lives.** `LanguagePreference` keeps it in the platform
secure store, next to the screen-lock preference and for the reason that one
gives at length: `finance.db`'s schema is a contract shared with the desktop
app, and a UI preference is not financial data. Unset means "follow the
phone", which is a third state and not the same as either language —
`AppLocaleScope` passes `Locale?` and the Settings sheet wraps its result so a
dismissed sheet cannot be mistaken for a choice of "follow the device".

**Read before the first frame.** `main.dart` reads the preference inside
`_start()`, alongside opening the database, rather than in a future of its
own. A second future would draw the shell in the device's language and then
swap it, which reads as a bug even when it settles correctly.

**The Language row in Settings became real.** It used to be a dead tile whose
subtitle said `English` whatever the app was actually drawing — one of the
few places the app stated something false about itself.

**What went with it, beyond substitution:**

* `error_messages.dart` now takes an `AppLocalizations` and maps 45 service
  codes onto 36 labels. Codes that share a sentence share a key: six services
  can all fail to read a typed figure, and six copies of "That is not an
  amount." would be six chances to drift apart in one language only.
* `KeyProtectionStatus` carries codes rather than sentences — see "Services
  raise error codes, not sentences".
* `ScreenLock.authenticate` takes a **required** `reason`. It has no
  `BuildContext` to read labels from, and the platform's own sheet is the one
  moment a user reads closely; a defaulted argument would have left English
  there silently, where a required one is a compile error.
* The Assets tab's period chips are now bare `DashboardPeriod` values with the
  label looked up at draw time. The desktop passes its Turkish UI labels
  (`1 Hafta`, `Hayat Boyu`) as the filter itself — exactly the coupling that
  breaks the moment the language changes.
* The twelve short month names were held twice, in the budget's chips and the
  trend chart's axis. They are now `lib/ui/month_names.dart`, and the lookup
  is a `switch` so an unhandled month is a compile error rather than a range
  error at the top of a chart.

**How it was proven.** `test/l10n_test.dart`:

* Every English key has a Turkish value, and nothing is left over in Turkish.
  Read from the ARB FILES, not through the generated class — a missing key
  compiles and falls back to English, so only the files themselves can tell a
  deliberate English label from an untranslated one.
* The two languages substitute the same placeholder names. `{amount}` dropped
  in translation is a sentence with a hole in it and `{amout}` is a literal
  brace on screen; both compile.
* `supportedLocales` matches the generated set and still leads with `tr`.
* `localizedUpperCase` produces `GÜVENLİK`, not `GÜVENLIK`.
* And the end of the chain rather than the middle: `SettingsScreen` pumped
  under `Locale('tr')` renders `Şifreleme Anahtarı` and `GÜVENLİK`, and the
  English `Encryption Key` is nowhere on it.

The other 568 tests stayed in English on purpose. The test binding reports
an en-US device and the harness passes no locale, so they resolve to English
and go on asserting the strings they always did — which means they still test
the wiring rather than the wording.

Checked for teeth, all three measured: removing `cardsPayDebt` from
`app_tr.arb` fails the completeness test, renaming `{amount}` to `{tutar}` in
one Turkish template fails the placeholder test, and reverting
`localizedUpperCase` to a plain `toUpperCase()` fails two — the dotted-i case
and the Turkish render. The dotless-i case still passes under that last
mutation, which is correct: Unicode already maps `ı` to `I`, and only the
dotted one needed fixing.

### What i18n did NOT cover

The backup layer's ~66 diagnostic messages — a hash that does not match, a
metadata field of the wrong shape, a key of the wrong length. They are still
English, and deliberately.

The screen wraps them: `backup_screen.dart` shows a translated HEADLINE that
says what to do about it (`Bu dosya yedek olarak kullanılamaz.`) with the
untranslated detail underneath, which is the split `DataUnavailable` and the
start-up failure screen already use. Translating sixty sentences that describe
the internals of a malformed package would put them in front of a translator
while the sentence that decides what the user actually DOES is the one above
them.

If that changes, the shape is already there: the codes would go on
`BackupFormatError` the way they went on `AccountError`.

### The icon and the launch screen — `android/app/src/main/res/`

The app looked like a Flutter template on the home screen: the default blue
Flutter logo, the label `archlence_mobile`, and a launch window that painted
white and handed over to a #131313 dashboard.

**The mark is the desktop's, verbatim.** `assets/icon/archlence_icon.svg` is a
copy of `assets/icon_source.svg` from the desktop checkout — same paths, same
`#5444E5` ground. Two clients of one product, and a second icon would say
otherwise. The ground is deliberately NOT an Obsidian Prime token: Obsidian
Prime governs what is inside the app, and a launcher badge that moved with the
mobile theme would break the identity the two share.

**The adaptive icon is where the thinking went.** Android 8 and up draw
`mipmap-anydpi-v26/ic_launcher.xml`, whose foreground is 108dp with only the
centre 66dp circle surviving every launcher mask. The mark's furthest points
from its centre are the two FEET, 167.7 units out in the 360-unit source,
which caps the scale at 0.196.

It is set to **0.18**, not the cap. At the cap the feet touch the circle
exactly — safe, and it looks it: cramped beside every rounder icon in the
drawer. That was measured, not guessed, by putting all three candidates on the
emulator next to Gmail and Chrome; 0.17 read as timid. The direction that
breaks something is the other one — above 0.196 a round mask clips the legs
off the A, which is the part of the letter carrying it, and the desktop
already replaced an earlier logo for going illegible at small sizes.

`<monochrome>` points at the same drawable as `<foreground>`. Android 13's
themed icons take the shape from that layer's alpha and supply their own
colour, and the mark is already a solid silhouette inside the safe zone; a
second file would be the same two paths waiting to drift.

The foreground is a `VectorDrawable` rather than five PNGs — two paths, drawn
natively since API 21. `tool/generate_launcher_icons.sh` renders only what has
to be raster: the five legacy `mipmap-*dpi` PNGs that API 24 and 25 fall back
to, and the launch screen's logo.

**The launch screen was a real defect, not a decoration.** Three parts:

1. `launch_background.xml` used `?android:colorBackground`, which is WHITE on a
   phone in light mode. Every cold start flashed white into a dark app. It is
   now fixed to `@color/launch_background` (#131313 — `ObsidianPalette.surface`),
   and `NormalTheme` with it, in `values/` as well as `values-night/`: this app
   has one theme and the light-mode folder must not disagree with the dark one.
2. Android 12 draws its own splash and IGNORES `android:windowBackground`. It
   falls back to the theme's window background only when that is a plain
   colour; ours is a layer-list, so without `values-v31/styles.xml` setting
   `android:windowSplashScreenBackground` the fix would have been invisible on
   every phone from Android 12 onward — which is most of them.
3. The centred logo is `@drawable/launch_logo`, a PNG, NOT `@mipmap/ic_launcher`.
   From API 26 that name resolves to the adaptive-icon XML, and a `<bitmap>`
   whose source is not a bitmap fails to inflate: a crash on the launch window,
   before Flutter starts, on exactly the devices most people have.

**The label** moved to `@string/app_name` = `Archlence`. Not translated and
there is no `values-tr/`: it is the product's name, and a launcher label is
fixed from the system locale anyway, so one that moved with the in-app
language setting would disagree with the home screen.

**How it was proven.** On the emulator, because none of this is visible in the
source: the launcher icon in the app drawer beside Gmail and Chrome, the
Android 12 splash on #131313 with no white frame, and the app coming up behind
it. `aapt dump badging` confirms the label. iOS and the other platform folders
are untouched — this is an Android client.

### What running it caught, that 578 tests did not

The i18n work had missed three strings: the resume lock's title and its two
subtitles, still English in `settings_screen.dart` while their ARB keys sat
unused. Nothing failed. The other tests run in ENGLISH, where a wired label
and an unwired one render the same string, and `l10n_test.dart` was checking
two labels on that screen and not those.

It took opening the app on a device, in Turkish, and reading "Lock when I come
back" under GÜVENLİK.

The fix is one line each; the test that now holds it is
`no tab leaves an English label on a Turkish screen`, which pumps `AppShell`
under `Locale('tr')`, walks all five tabs, and fails on any rendered string
that is an English ARB value the Turkish file translates differently — upper-
cased variants included, since `SectionLabel` upper-cases what it is given and
the section headings were the visible half of the miss.

It has teeth: putting the literal back fails it with `left in English on the
Ayarlar tab`. What it CANNOT catch is a label that was never given a key at
all — nothing but reading can — and that limit is worth knowing rather than
trusting the green.

### Release signing — `android/app/build.gradle.kts`

**What this replaced is the whole point.** The Flutter template signs release
builds with the DEBUG key, so that `flutter run --release` works out of the
box, and leaves a `TODO` above it. That is the one failure here that looks
like success: the APK builds, installs and runs.

The debug key is a well-known one that ships with the SDK and is byte-identical
on every machine that has Android Studio. An APK carrying it can be replaced by
anything anyone else builds; it can never be updated by a real key afterwards,
because Android compares signatures before allowing an update; and Play refuses
it outright. All three are discovered at the moment someone tries to ship — the
worst moment to find out.

Measured, not assumed. `apksigner verify --print-certs` on what the old
configuration produced:

    Signer #1 certificate DN: C=US, O=Android, CN=Android Debug

**Now:** `signingConfigs` reads `android/key.properties`, which is outside the
repository, and is declared ONLY when that file exists — a config pointing at a
missing keystore fails deep inside AGP with a message about a file path, where
this fails early and says what to do.

**And a release without it is refused, not downgraded.** A `doFirst` guard on
every `assemble*Release` / `bundle*Release` task checks that the file exists,
that all four keys are filled in, and that `storeFile` points at something
real. Falling back to an unsigned or debug-signed APK would put the discovery
back where it was. `assembleDebug` is untouched: development needs none of it.

**The keystore is not created here, and must not be.** It is a credential, it
belongs to whoever ships the app, and its password has no business being typed
into this repository or into a session with a tool that logs its commands.
`android/key.properties.example` carries the `keytool` line, the reasons the
file matters more than it looks (whoever holds it can publish an update over an
installed Archlence; losing it strands every installed copy for good), and the
PKCS12 note — JDK 9 and later default to it, and it has ONE password, so
`storePassword` and `keyPassword` are the same value.

`.gitignore` gets `*.jks` and `*.keystore` at the ROOT. `android/.gitignore`
already covered `key.properties` and both extensions under `android/`; the root
pair catches a keystore dropped anywhere else in the tree, which is the case
that would otherwise go unnoticed.

**How it was proven,** both directions, because a guard that never fires and a
config that never signs look identical from the outside:

* With no `key.properties`, `flutter build apk --release` fails with the guard's
  own message naming the example file — not with an AGP stack trace, and not
  with a build that succeeds. `flutter build appbundle --release` was run too,
  and fails the same way on `bundleRelease`: the Play path is the one that
  would matter most and it would have been easy to leave uncovered.
* With a throwaway PKCS12 keystore wired in, it builds, and
  `apksigner verify --print-certs` reports that certificate rather than
  `CN=Android Debug`.

The throwaway keystore and the release APK it signed were both deleted
afterwards. Neither was ever in the repository, and nothing signed with a
disposable key should be left where it could be mistaken for a build to ship.

### R8 — already on, measured, and run

**This file used to say R8 was off.** It was wrong, and the way it was wrong
is worth keeping: the claim was read out of `android/app/build.gradle.kts`,
which does not mention `isMinifyEnabled` — exactly as the Flutter template
does not. But the template's silence is not a default of `false`. Flutter's
own Gradle plugin sets it:

    if (FlutterPluginUtils.shouldShrinkResources(project)) {
        releaseBuildType.isMinifyEnabled = true
        releaseBuildType.isShrinkResources = isBuiltAsApp(project)
        ...proguard-android-optimize.txt, flutter_proguard_rules.pro,
           and app/proguard-rules.pro if it exists

and `shouldShrinkResources` returns `true` unless `-Pshrink=false` is passed.
So every release build this project has ever produced was minified, resource-
shrunk, and optimized. Reading a build file is not reading a build.

**Measured, both ways,** because "it is on" is the same kind of claim as "it
is off" and deserves the same evidence. Two builds of the same commit:

| | dex | APK |
| --- | --- | --- |
| default | 942,680 B (one `classes.dex`) | 64.9 MB |
| `-Pshrink=false` | 9,928,972 B (`classes.dex` + `classes2.dex`) | 68.3 MB |

R8 removes 90.5% of the Java/Kotlin and 3.4 MB of the APK, and takes the app
back under the 64K method limit that forces the second dex file.

**Which also settles what the 63.7 MB was.** Not "unshrunk code" — the dex is
1.5% of the APK. The rest is three ABIs of `libflutter.so`, `libapp.so` and
`libsqlite3.so`. R8 cannot touch any of it, and no keep rule will. The lever
for APK size is `--split-per-abi` (or an App Bundle, which Play does per
device anyway), not shrinking.

**"That is a shipping decision, not a code one" is what this paragraph used to
end with, and it was wrong.** Play requires an App Bundle for new apps, so the
bundle is not a lever anyone gets to choose — it is the only artefact the
store accepts, and it happens to solve the size question on the way. See
"Getting it into the Play Store".

**What was actually missing was the run.** A minified build had never been
installed and used — which is where R8 damage shows up, because it strips and
renames Java classes that plugins reach by reflection, and the failure is a
`MissingPluginException` or a `ClassNotFoundException` at the moment a feature
is used, not at build time. So it was installed from a throwaway-signed APK on
the `archlence_pixel` emulator and driven, watching logcat for
`FATAL`/`AndroidRuntime`/`ClassNotFound`/`NoSuchMethod`/`PlatformException`/
`MissingPlugin` throughout. Nothing appeared. What was exercised, chosen for
touching native or reflective code:

* **Onboarding through to a working profile** — which generates the encryption
  key through `flutter_secure_storage` into the Android Keystore, creates the
  database, and writes the first account. 5.000,00 ₺ came back on the Home tab
  in Turkish formatting.
* **Cold start after `am force-stop`** — the key is read back out of the
  Keystore and the encrypted database reopens. This is the path where a
  stripped `androidx.security` class would show up, and the one an earlier
  session found a real defect in.
* **The BIST key row** — a dummy key saved and read back, the row changing to
  "A key is set". `flutter_secure_storage`'s write path, in a release build,
  for the feature committed one commit earlier.
* **A whole backup, created and handed to the share sheet** — sqlite3's online
  backup API, the passphrase key-wrap, `archive`, `path_provider`, and
  `share_plus` through a `FileProvider` URI. The system sheet named the file
  `archlence-20260827-102910.archlence-backup`. No share target was picked:
  the point was that the file reached the sheet.
* **The restore file picker** — `file_selector` opening the SAF document
  picker, then cancelled. The button is correctly dead until a passphrase is
  typed.
* **The screen-lock row** — `local_auth` reporting, correctly, that this
  emulator has no fingerprint or screen lock, with the switch disabled and the
  reason written under it.
* **The Assets tab** — `fl_chart` draws its donut.

**Not exercised, and so not claimed:** a live price fetch (no holding was
bought, and the price layer is Dart, which R8 does not touch), a completed
restore, and biometric unlock, which needs a device with a screen lock set up.

**No `proguard-rules.pro` was added.** Nothing needed one: the plugins that
could have needed keeps ship their own consumer rules, which the merged
configuration shows arriving from `biometric-1.1.0`, `window-1.2.0`,
`appcompat-1.2.0` and the plugins' own artifacts, alongside Flutter's
`-if class * implements io.flutter...FlutterPlugin / -keep`. A keep rule
written for a problem nobody has is a rule nobody can ever safely delete.

**One thing to know when this next fails.** `android/gradlew` cannot be run
directly here: `android/local.properties` holds a stale `flutter.sdk` pointing
at an empty `~/.cache/flutter_sdk`, and Gradle fails resolving the Flutter
plugin loader. `flutter build` rewrites and uses its own; go through it.

### The key on its own — `lib/backup/key_recovery_service.dart`

The port of `export_recovery_package` / `import_recovery_package`, and the
form on Backup & Restore that drives them.

**Why it is not just a smaller backup.** A backup holds the database AND the
key, so restoring one replaces both. This answers the other case: the data is
fine and the KEY is gone — a reinstall, a phone reset, a screen lock changed
in a way that emptied the Keystore. Restoring a backup then would work, and
would also throw away everything recorded since it was made. The screen says
so in as many words, and `backup_screen_test.dart` pins the sentence.

The file is a few hundred bytes of JSON: `format`, `created_at`, a
`key_fingerprint`, and the same passphrase-wrapped `recovery` block that
travels inside a backup. The desktop's field names and format string verbatim.

**THE ORDER IS THE SAFETY PROPERTY.** The incoming key is proven against the
database that is here NOW, before the key store is touched at all. A key that
does not open this data would make every encrypted row unreadable the moment
it landed, and by then the old key is gone with nothing to roll back to. A
failure therefore leaves the store exactly as it was — asserted, not assumed:
one test imports a well-formed package belonging to a different key and checks
the stored key afterwards.

**Two things the desktop's version cannot say, and this one does:**

* **How much was actually checked.** `verifyDatabaseKey` returns a count, and
  the outcome carries it. Zero is the number that matters: it means the
  database had nothing encrypted in it, so the key was not really tested and
  any key at all would have passed. The screen appends a sentence saying so
  rather than reporting a bare success.
* **That nothing changed.** The desktop returns `{"imported": True}` whether
  it stored, replaced, or found the key already there. Here they are three
  outcomes, because "that is already the key on this phone" is the reassuring
  answer to the question the user actually asked.

**The import goes through `swapProfile`,** the same restart the restore uses,
and not because the database is being replaced — it is not. `FieldCrypto`
caches the key it first read, so a running app would go on decrypting with the
OLD one and report every row as corrupt.

**The file is untrusted input,** like a backup package: bounded by length
before it is parsed at all (the same 4MiB ceiling the recovery member gets
inside a package — the point is that a 2GB "recovery package" is refused by
its size rather than by the JSON parser running out of memory), then a strict
shape, then `RecoveryMaterial.fromJson`'s own bounds, then the fingerprint.
The fingerprint is checked AFTER decryption and is a check rather than a
secret: SHA-256 of 32 random bytes gives nothing away, and it catches a package
whose wrapped key was swapped for another valid one.

A wrong passphrase is a `WrongPassphraseError`, kept distinct from
`BackupFormatError` for the reason the backup screen already draws: "you
mistyped" and "this file is not what you think" send a user to different
places.

**How it was proven.** Parity in BOTH directions against the desktop's own
module, because a format only one side can produce is not a shared format:

* `tool/emit_recovery_package.py` writes `test/desktop_key_recovery.json` with
  the desktop's own `export_recovery_package`, under a fixed key
  (`bytes(range(32))`) so the Dart test asserts the exact bytes rather than
  that something 32 bytes long came back.
* `tool/emit_mobile_recovery.dart` writes one with THIS app's code, and the
  same script's `--verify` mode opens it with the desktop's
  `read_recovery_package`. Run, and it does.

Then fifteen tests over a real profile on disk: the round trip, the shape, a
refusal that leaves no file at all (not even the `.tmp` it stages through),
six malformed files that must all come back as one kind of error, the size
ceiling, a tampered fingerprint, the wrong passphrase, all three import
outcomes, the zero count on an empty profile, and the stranger's key that must
change nothing.

Checked for teeth, all four measured: skipping the database check, skipping
the fingerprint check, removing the size ceiling, and folding "unchanged" into
"replaced" each fail the suite, and it passes again when they are put back.

**What the screen needed that the service did not.** The two new sections sit
AFTER restore rather than between it and the backup section: the common flow
first, the recovery case last. And the l10n leak test grew a second case for
this screen — it is pushed from Settings, so the tab walk never reaches it,
and it carries more prose than any tab does.

### Price fetching — `lib/services/price_providers.dart`, `live_price_service.dart`

Built on top of `price_guard.dart` and `ticker_mapper.dart` (see those two
entries above) and the decision recorded in "Prices come from the phone, from
keyless sources". This entry is the rest: the two providers, the composition
layer that turns a classified holding into a price, the cache, and the
per-holding UI.

**`price_providers.dart`** calls CoinGecko and Frankfurter through one seam,
`HttpGet = Future<String> Function(Uri)`, so every test in this piece drives a
canned response and no socket ever opens. NEITHER provider function throws —
a network failure, a timeout, a malformed body, or one bad id inside an
otherwise good response all come back as an absent key, matching
`price_guard`'s own "one broken symbol does not sink the batch" rule one
layer up. Frankfurter's rates are `TRY -> code`; every rate is INVERTED before
it leaves this file, because the rest of the app deals in "how many lira is
one unit" — the same direction `formatLira` and a stored purchase price
already use — and nowhere downstream should have to remember which way one
particular provider's numbers point.

One correction on the way here, worth recording because it was stated
confidently and checked only after the fact: the decision doc originally
claimed `dart:io`'s `HttpClient` does not follow the Frankfurter redirect by
default. A real request against `api.frankfurter.app` proved the opposite —
`followRedirects` defaults to `true`, same as `requests` — and both mentions
in this file were corrected rather than left standing. The lesson travels:
a claim about a library's default behaviour is worth one real call before it
goes in a decision record, not just a plausible guess.

**`ticker_mapper.dart` gained one field it was missing.** Every `PriceRequest`
subtype except `GoldPriceRequest` already carried the holding's own `code`;
gold's classification runs on the CODE (`GOLD-CEYREK` etc.), not a
provider-side lookup, so it had never needed to KEEP one. It does now — the
cache is keyed on that exact code, matching the desktop's own `_store_cache`,
and a gold holding needs somewhere of its own to be cached just as much as a
crypto or currency one does. Promoted to the base class rather than added to
one subtype, since all five needed it identically; the four that already had
it lost a duplicate field apiece. The existing parity tests were re-run after
the change and passed unmodified — the classification itself did not move,
only where one already-computed value lives — and one more assertion was
added pinning `request.code` against the fixture for every gold vector.

**`live_price_service.dart`** is the composition point, and nothing above it
in the call graph does the arithmetic or touches `asset_price_cache` on its
own. For a whole batch of holdings it: classifies each one, gathers the
CoinGecko ids and currency codes actually needed (adding PAXG the moment any
gold holding exists, and `USD` the moment either crypto or gold does — both
convert through USDTRY, even for a portfolio with no currency holding of its
own), fetches each provider ONCE regardless of how many holdings share a
symbol, computes a TRY-per-unit price for what it can, and falls back to
`asset_price_cache` for whatever a provider gap left unpriced. A live figure
and a cached one are written and read as the same `CachedPrice` — the caller
never has to ask which kind it got, only how OLD it is.

The one detail this table needed that no other table in the schema does:
`updated_at` is written as `YYYY-MM-DDThh:mm:ss+03:00` — a FIXED Istanbul
offset, not this app's usual `sqliteTimestamp`. The desktop writes the same
shape (`datetime.astimezone(ISTANBUL).isoformat()`), and `MAX(updated_at)` is
a plain TEXT comparison: after a restore, a mobile-written row and a
desktop-written row for different symbols can sit in the same table, and
mixing formats could make an older row read as newer than a fresher one, or
the reverse. No timezone database is needed for this — Turkey has kept no
daylight saving since September 2016, so `+03:00` never changes and three
hours is the whole rule.

**The screen.** `_HoldingTile` shows `Current` with the live total, a
signed P&L percentage, and how long ago the price was fetched (`just now`,
`3m ago`, `2h ago`, `9d ago` — `lib/ui/price_freshness.dart`, coarse on
purpose) wherever a price was found; everywhere else it is unchanged —
`Cost`, no colour, no claim. `_TotalHoldingsCard` was DELIBERATELY left
alone: it sums purchase price across a portfolio that can hold a share at
cost beside a crypto holding at a live price in the same list, and blending
those into one number would present a figure that is part market value and
part cost basis with no way to tell which parts are which from the total
alone. The price-fetching item asked for this PER HOLDING, not as a new
aggregate, and the tiles are where it landed.

**Every widget test needed a seam it didn't have before.** The moment
`AssetsScreen` calls `services.livePrices.priceHoldings(...)`, EVERY widget
test that pumps it — or `AppShell`, which reaches it through the Assets tab —
would open a real connection unless something stood in the way.
`test/support/test_app.dart`'s `testServices()` now wires a `LivePriceService`
whose `HttpGet` throws on every call; `LivePriceService` already treats a
thrown provider error as "nothing to price this fetch" and falls back to
whatever the cache holds, which is the same path a genuinely offline phone
takes — so refusing here is not a special case invented for tests, it
exercises a real one. A test that specifically wants to drive live pricing
passes its own `httpGet` instead.

**How it was proven.** `price_providers_test.dart` (19 cases) drives both
provider functions through the fake seam only — malformed bodies, a
numeric literal that overflows to `Infinity` on the way in (the same defect
`price_guard` exists for, one layer up), a zero rate that would divide by
zero if the guard had not already caught it, and the empty-request case that
must make no call at all. `live_price_service_test.dart` (12 cases) runs
against a REAL in-memory drift database — the crypto/currency/gold formulas,
the dedup (one HTTP call per provider for a four-holding portfolio sharing
symbols), shares and unknown symbols never touching a provider, a
successful fetch surviving into the next read as a cache row, and the
sharpest one: a provider gap falling back to a cache row that still reports
its OWN stale timestamp rather than the moment of the failed retry.

One of those cases exists because of a second self-caught mistake: a cache
row with a `NULL source` — one written before that column existed — was
being read back labelled `CoinGecko`, which this app has never called Yahoo
through. The desktop's own reader resolves a null source to `Yahoo Finance`
(`row["source"] or PRICE_SOURCE`, and `PRICE_SOURCE = "Yahoo Finance"` from
back when it was the only provider there was), and that is the convention
worth matching for a row the desktop actually wrote — not a guess at which of
THIS app's two providers seemed more likely.

`price_freshness_test.dart` (5 cases) pins the four buckets and the negative-
duration case. `assets_screen_test.dart` grew from 12 tests to 14: the old
blanket "no price source" assertion is gone with the banner it tested, split
into a symbol-this-app-cannot-classify case and a provider-gap case, plus one
new test proving a live-priced tile actually says `Current`.

Checked for teeth. `live_price_service_test.dart` caught: the cache write
skipped entirely, the gold multiplier ignored, the legacy-source fallback
reverted to the wrong guess, and a cache-fallback price reporting the CURRENT
time instead of the stale one it actually came from —
the last of which was the point of building the fallback at all, and it is
worth noting that this specific mutation is exactly the kind a less pointed
test would let through, since the PRICE would still be numerically correct
even with the wrong timestamp attached. `assets_screen_test.dart` caught the
`Current`/`Cost` label always resolving to `Cost`. One mutation on
`price_freshness.dart` came back GREEN and was investigated rather than
dismissed: removing an explicit negative-duration clamp did not fail the
suite, because any negative duration already satisfies `inMinutes < 1` and
lands in the same "just now" branch a small positive one does — the clamp
was dead code, confirmed rather than assumed, and removed with a comment
explaining why no clamp is needed at all instead of being restored.

**What came after this, in its own piece:** the user-supplied API key that
opens BIST — see "Shares, on the user's own key" below.

### Shares, on the user's own key — `lib/services/shares_api_key.dart`

The exception the pricing decision named, built. Crypto, gold and currency
stay keyless; BIST needs a key, and it is the USER'S key, entered in Settings
and kept in the platform secure store.

**Why a user's key rather than one in the app.** A key shipped in an APK is a
public key — anyone can pull it out — so a shared one would be spent, abused,
or revoked within days of anyone caring. And BIST data is commercial with no
free tier worth building on (checked August 2026), so there is nothing to
ship even if shipping one were safe. That leaves the person who wants live
share prices bringing their own, which is friction, which is why it is
optional and why the app works completely without it.

**NosyAPI**, chosen for one reason above the others: its request and response
shape is publicly documented, which mattered more here than anywhere else in
the price layer — see "How far this is proven" below. Endpoint,
`code=ASELS,THYAO` comma-separated so a whole portfolio is one request (the
free plan bills per REQUEST, not per symbol), and `latest` as the price.

`latest`, NOT `buying` or `selling`. Those are the two sides of a spread;
valuing a portfolio at either one would report what somebody else would pay
or charge rather than what the holding is worth.

**The key goes in a header** (`X-NSYP`), never the query string, even though
the API accepts `?apiKey=` too. Query strings reach server logs, proxy logs
and `Referer` headers; a credential in one is a credential leaked. There is a
test that fails if the key ever appears anywhere in the request URI.

**Three things the design refuses to do:**

* **Read the key store for a portfolio with no shares.** Proven by a test
  that wires a key store which THROWS: if it were consulted, the test fails.
* **Look in the cache for a share when there is no key.** Nothing has ever
  priced it, so there is nothing to find, and asking would be a database read
  on every refresh for an answer that cannot exist. WITH a key, a share falls
  back like everything else — which is what keeps a portfolio readable when a
  monthly credit runs out mid-month.
* **Show the key.** Not in the row, not masked, and not prefilled into the
  field that edits it. A displayed credential is one a shoulder can read, and
  seeing it buys nothing that "a key is set" does not already say — if it is
  wrong, the fix is pasting the right one, which works either way. The
  mutation that prefills the field fails the suite.

**`UnsupportedSharesPriceRequest` was renamed `SharesPriceRequest`.** The old
name encoded a runtime fact — "nothing can price this" — into a
classification that only ever asked what KIND of holding it is. Whether a
share can be priced now depends on whether a key exists, which belongs to
`LivePriceService`. The parity fixture and its tests were unaffected: the
classification did not move, only its name.

**One instance of the key store, not two.** `AppServices` hands the same
`SharesApiKey` to both `LivePriceService` and the Settings row, so a key
saved on one screen is the key the next fetch uses. Two stores over one entry
would work by accident and break the moment either cached. `testServices()`
wires it the same way, for the same reason.

**The `HttpGet` seam grew headers.** It was `Future<String> Function(Uri)`;
it is now `Future<String> Function(Uri, {Map<String, String> headers})`. One
seam rather than a second one beside it, because "a GET with headers" is
still a GET, and two would mean two things to fake in every test.

**How far this is proven, and how far it is not.** The request shape, the
batching, the header, the fallbacks and the refusals are all tested against
canned responses, and every one of them has teeth — the key in the query
string, a share fetched without a key, and `buying` read instead of `latest`
each fail the suite.

What is NOT proven is the live wire format. Checking it needs a real API key,
a key belongs to the person who signs up for it, and creating one is not
something to do on someone else's behalf. So the parsing above is written
from NosyAPI's published documentation rather than from a response this
codebase has actually seen — which is exactly the kind of gap the rest of
this file closes by generating fixtures from the desktop's own modules, and
cannot here.

**What that means in practice:** the first person to enter a key is the first
real test. The failure mode is mild by construction — a shape mismatch means
`data` or `latest` does not parse, `finitePositivePrice` returns null, and
the holding stays at cost exactly as it does with no key at all. Nothing
breaks and no wrong number appears; the shares simply do not light up. If
that happens, the response body is what to look at first.

### Category settings, and the main/extra split

Item 1 of the road to 1.0. `categories.importance` was a column this app read
and never used; it now has a screen that sets it and a card that shows what it
did.

**The port is `financial_summary_service.py`,** and it is four buckets: main
income, extra income, essential expense, extra expense. The mapping is
asymmetric and that is the desktop's, not a slip — 'main' files income under
`mainIncome` and an expense under `essentialExpense`, because a salary is a
main income and rent is an essential expense and the two words are not
interchangeable.

**Every expectation comes from the desktop's own function.**
`tool/emit_summary_vectors.py` CALLS `summarize_transactions` over encrypted
rows it builds with the desktop's own `encrypt`, and writes one line per case:
each summarised ALONE, so a row landing in the wrong bucket names itself
instead of hiding inside a total, plus a final `ALL` line that sums them. The
amounts are all different on purpose — with one figure repeated down the
column, two buckets swapped would produce the same file.

Three things the vectors pinned down that a hand-written test would have
guessed at: a NULL importance is 'extra' rather than an error, a value from
neither list is also 'extra' rather than a throw, and a transaction that is
neither income nor expense is DROPPED rather than counted as zero somewhere.

**Checked for teeth,** three ways, each failing the suite: the expense buckets
swapped, a neither-side type counted as income, and a missing importance read
as 'main'.

**And a doc comment that was wrong in the one place it mattered.**
`PeriodEntry.importance` said the column holds `'essential'` or `'extra'`. It
holds `'main'` or `'extra'` — 'essential' is the name of the BUCKET a main
expense lands in. Nothing had ever compared the value, so the wrong word cost
nothing right up until the moment it would have cost a bucket. The constant
lives in `category_service.dart` now and both files import it.

**The screen is a list and a switch, and nothing else.** No add, no rename, no
delete. The desktop has none either: `init_db.py` seeds the list and the only
write in that whole codebase is `main.py:2077`'s
`UPDATE categories SET importance`. Inventing more here would fork a schema
that is a contract shared with the desktop, and it would do it in the worst
possible place — `transactions.category` stores the NAME, so a rename would
split a household's history in two, with neither app able to tell the halves
were ever one thing. The screen says all this on itself, in a card at the top,
rather than leaving a user to conclude it is unfinished.

**No Save button.** Every other write in this app goes through a form because
it moves money or creates a row that has to balance. This one flips a flag on
a row that already exists, and a screen of sixty switches behind one Save is a
screen where somebody changes three, leaves, and loses all three. A write that
matches no row puts the switch back and says so instead of throwing — the row
went away underneath, most likely through a restore.

**The visible half is `_SplitCard` on the Assets tab.** Two bars, income and
expense kept apart so nobody reads a salary against the rent as parts of one
whole, with both figures and both percentages printed as well as drawn — a
width answers "how much of it", never "how much". A household that has marked
nothing essential gets a sentence pointing at the screen that decides it,
because two bars pinned to one end look like a broken chart rather than an
untouched setting.

The tab's `income`, `expense` and `net` now read from the same summary instead
of from two inline loops. One definition, so the card underneath cannot add up
to a different total than the line above it.

**What running it caught, that eleven new tests did not.** The bar did not
draw. It was in the tree and laid out, and `Row` centres its children by
default while a `ColoredBox` with no child asks for no height at all — so both
segments came out full width and ZERO tall. Every test passed, because they
asserted the figures and the figures were right. The fix is
`crossAxisAlignment: stretch`; the assertion that would have caught it measures
`tester.getSize` on the painted segments and checks the 3:1 ratio, and it fails
if the stretch is removed again.

That is the third time this file has recorded a defect of exactly this shape:
invisible in the source, invisible to tests that assert values, obvious in the
first second on a device.

**One test changed rather than being loosened.** The Assets summary assertion
started matching two widgets, because the split card prints the same total when
every expense falls on one side of the line. `findsWidgets` would have made it
pass — and made it pass with the SUMMARY showing the wrong figure, which is on
the list of assertions this suite has already been caught by. It is scoped to
`find.descendant(of: find.byType(SummaryRow))` instead.

### Search, and the Turkish letters that break it

Item 2 of the road to 1.0. The Home search field was disabled with the label
"Search — not yet"; it works.

**The scope in "Pick up here" was wrong, and the way it was wrong is the
lesson.** It said account and category names only, with a measured reason —
descriptions are AES-encrypted, so searching them means decrypting rather than
filtering in SQL, and the desktop clocked 1.1s over 50,000 transactions. That
sentence is a faithful summary of `search_service.py`'s DOCSTRING. The module
underneath it defines `search_transactions` and calls it from `search`: the
scope widened and the header did not follow. Reading the prose would have
shipped a search that quietly found less than the desktop's.

That is the third entry in this file where a claim inside a file turned out
not to be the file's behaviour — after R8's absent `isMinifyEnabled` and the
`'essential'` doc comment. The habit that catches it is the same one every
time: open the code the sentence is about.

**So descriptions are searched, the way the desktop searches them:** the most
recent 500 rows, ordered and windowed in SQL over the plain
`transaction_date`, then decrypted one at a time. A row that will not decrypt
is SKIPPED — one broken record must not make the box useless — but a missing
KEY propagates, because "no results" would tell a user their profile is empty
when it is unreadable. The screen draws `DataUnavailable` for that, not an
empty panel.

**Turkish folding is the real work, and Dart cannot do it.** `normalize()` is
`casefold` -> NFKD -> drop combining marks -> `ı`->`i` -> collapse whitespace,
and it is what makes "ISI" find "ısı" and "sirket" find "Şirket". Dart has no
Unicode normalisation in its core library, and this is not worth a dependency.

`tool/emit_search_folding.py` precomputes the whole chain per character,
straight from the desktop's function, into `lib/services/search_folding.dart`
— 2,808 entries for every codepoint below U+3000 that folding changes.

**The generator proves its own premise before it writes anything.** Folding
character by character and collapsing whitespace afterwards is only equal to
running the whole-string function if no character's expansion interacts with
its neighbours' — and one does: U+00A0 decomposes to a SPACE, so a naive table
that folded and collapsed in the wrong order would turn `a\u00A0b` into `ab`
where the desktop gives `a b`. The script checks the equality over every
covered codepoint and 60,000 random strings and refuses to write the file if
one disagrees.

**And it records where the port CANNOT match.** Coverage stops at U+3000, so
`ﬁ` (U+FB01) passes through where the desktop expands it to `fi`. Rather than
quietly trimming that case out of the fixture, the generator writes it as a
`DIVERGES` line carrying both answers, and a test asserts the port lands on
its side of it. Widening the table deletes the line and fails that test until
the fixture is regenerated — a known gap that cannot rot into an unknown one.

**Ranking, because containment alone gives the wrong order.** 0 exact, 1
prefix, 2 contained, ties keeping input order, so typing "Nakit" puts "Nakit"
above "Nakit Olmayan". An empty query returns NOTHING rather than everything:
focusing the box must not dump the whole profile onto the screen.

**Checked for teeth,** three ways, each failing the suite: folding with a
plain `toLowerCase` instead of the table (23 assertions fall), collapsing the
rank to a containment check, and letting one unreadable row abort the search
instead of being skipped.

**The panel is inline, under the field.** The desktop gives its reason — its
dropdown grabbed focus and made a second keystroke impossible — and the mobile
one is the same shape: the keyboard is up and the field has focus, and taking
either away between characters is the one thing a search box must not do.
Debounced 300ms like the desktop, and an answer to a query the user has
already typed past is dropped rather than drawn.

**A result goes where the thing lives,** which is what the desktop does: an
account or a transaction to Cards, where accounts and their statements are,
and a category to Category Settings — a destination that only exists because
item 1 built it. `AppShellScope` is the new inherited widget that lets a
screen move the shell; it exists because passing a callback from the shell to
one field would have put a parameter on every widget in between.

**An empty panel says where it looked.** "Nothing found" alone reads as "I
never recorded that", which can be false: a description older than the window
is outside what the search opens. The line under it names the three places, so
the absence is informative rather than misleading.

### The calendar — `lib/screens/calendar_screen.dart`

Item 3 of the road to 1.0, and the smallest of them: `calendar_service.py` is
94 lines and the port is two queries.

**The split between SQL and Dart IS the design, and it is worth stating
because it is what makes the screen affordable.** `amount` and `description`
are AES-encrypted, so neither can be grouped or filtered in SQL. But what a
month grid needs is a DAY and a COUNT, and both come off the plain
`transaction_date` — so drawing a month opens nothing at all, and only the day
a user taps is decrypted. There is a test for exactly that: a
`CalendarService` built over a key provider with nothing to give still returns
the month's marked days, and raises only when asked for a day's contents.

**No `localtime`, unlike `DashboardPeriod`.** That enum compares against
`now` and must convert; this compares against a date the caller names, and the
stored stamp is already local. Adding a conversion here would shift every day
of the grid by the timezone offset — the same trap, in the opposite
direction, as the one the period predicates were written to avoid.

**The one deliberate departure: an unreadable amount.** The desktop logs it and
substitutes 0.0. This does not, for the reason settled once for the whole app
in "A corrupt row is reported, never counted as zero" — a day listing a real
expense as ₺0,00 is a wrong number presented as a right one, and on a phone
the log has no reader. The row STAYS in the list, because dropping it would
hide that anything happened, and says it cannot be read where its figure would
be. A description that will not open does not take the amount down with it.

**`readStoredAmount` and `readStoredText` moved out of `TransactionService`**
and became top-level, because the calendar reads the same rows and has to
treat a broken one the same way. Two copies of that would have been two places
to forget the rule.

**What the grid draws, and what it refuses to.** A dot per day with activity,
never a count: the number of transactions on the 14th is not something anyone
reads off a 7-column grid on a phone, and drawing it would crowd the cell.
Days with nothing are still TAPPABLE — "was there anything on the 6th" is a
real question and a dead cell leaves it unanswered — and answer "nothing on
this day". The next-month arrow is disabled at the current month, because a
future month can only hold `pending` rows, which the grid does not mark, so
every one of them is empty by construction.

**Changing month drops the selection.** Carrying day 31 from a 31-day month
into a 30-day one would open a day that does not exist.

**Checked for teeth,** six ways across the two files, each failing the suite:
dropping the completed-status filter from the month query, substituting zero
for a corrupt amount in the service AND again in the row that draws it,
removing the month's zero-padding (`'2026-3'` matches nothing), marking every
day of the grid, and letting the selection survive a month change.

**The dot is counted by measuring what is painted,** not by finding text.
There is no text on a dot, and after the split bar drew itself at zero height
with every text assertion passing, "is it in the tree" is not a question this
suite accepts as an answer to "is it drawn".

### The four calculators

Item 4 of the road to 1.0. Four Tools cards opened at once, which takes the
grid from two live cards out of nine to seven.

**Reaching the desktop's arithmetic was the interesting part.** The three
financial calculators live on a Kivy mixin: the methods read
`self.<field>.text` and write `self.<label>.text`, and `kivymd` is not
installed in `aeadvenv`. Transcribing the formulas into a generator would have
tested the transcription. So `tool/emit_calculator_vectors.py` injects fake
`kivy`/`kivymd` modules into `sys.modules`, imports the REAL
`CalculatorMixin`, and drives it against a duck-typed object whose fields are
plain strings — every figure in the fixture came out of the desktop's own
method, formatted by the desktop's own code. If a future version of those
methods reaches into a real widget, the script fails at import rather than
quietly emitting hand-derived numbers.

**The figures are compared AS TEXT,** through this app's `formatLira`, so a
vector proves the arithmetic and the Turkish formatting in one assertion.

**These compute in `double`, in an app whose money layer refuses binary
floats.** That rule is about RECORDED money — a balance, a transaction, a
total that has to agree with the desktop to the kurus. Nothing here is
recorded: these are projections of a deposit that does not exist and an
instalment on a loan nobody has taken, the desktop computes them in `float`,
and matching its answer is worth more than a precision the inputs never had.
Every result is quantized to fiat before it leaves the service, and each
screen says on itself that it writes nothing.

**What the vectors pinned down, that a reading of the formulas would have
guessed at:** interest uses a 365-day year (`/36500`) with 5% withholding;
KKDF and BSMV are 15% each OF THE INTEREST, folded into the rate before the
annuity — so an advertised 3.29% monthly is charged at 4.277%, and a port that
applied them to the payment would be out by a factor and still look plausible;
and compound growth compounds the PRINCIPAL annually while compounding
contributions at `r/12` monthly, which is two frequencies in one answer and is
the desktop's, not a slip here.

**The plain calculator needed a parser.** The desktop walks Python's own
`ast`, so it gets Python's precedence for free; Dart has nothing to borrow.
Three traps, each with its own vector: `**` binds tighter than a unary minus
on its left (`-2**2` is -4), its right operand may be unary (`2**-2`), and it
associates rightwards (`2**3**2` is 512). And `%` takes the sign of the
DIVISOR in Python — Dart's `%` is always non-negative and its `remainder`
takes the sign of the dividend, so neither operator is a drop-in and `10 % -3`
is the line that says so.

**One irreducible divergence, measured rather than hidden.** Dart has no
`log10`. `log(x) / ln10` is a different function in the last bit:
`math.log10(2)` is 0.3010299956639812 and the substitute gives
0.30102999566398114. Exact powers of ten are snapped back — a calculator that
answers 2,9999999999999996 to log(1000) is one nobody trusts again — and
everything else is asserted to be within ONE ULP PER `log` CALL, which is a
bound rather than a number chosen to make a test pass. Every other expression
is compared bit for bit.

**What did NOT come:** the loan's advanced mode. On the desktop that is
arbitrary user-entered charges, a file fee, insurance, longer terms for car
and mortgage loans, and a PDF export. The basic mode is here, 36-month cap
included; the rest is a screen of its own and the PDF is a desktop
affordance.

**Six mutations fail the suite:** the loan without its taxes, interest without
withholding, a 360-day year, contributions compounded annually, `**` made
left-associative, and Dart's own `%`.

**And what running it caught, again.** The keypad was built by filling a 5x5
grid in order, which produced a row reading `4 5 6 1 2`. Every test passed —
they pressed keys by name and the answers were right — and it was wrong the
second the screen was opened. The assertion that now holds it measures
POSITION: each digit's centre against the one that should sit above and beside
it, so 7-8-9 over 4-5-6 over 1-2-3 is a fact the suite checks rather than a
layout someone eyeballed.

### The change chip, and the balance at a past day

Item 5 of the road to 1.0, and the one whose plan was wrong about its own
dependencies.

**"Pick up here" listed this as a 94-line port and it was not.**
`dashboard_period_service.py` is 94 lines and pure, but its baseline comes
from `history_service.get_balance_at` — the 321-line time machine this file
puts OUT of 1.0 by name. The plan named a dependency it had already excluded.

What it needed turned out to be one question out of that module, not the
module: what the accounts held at the end of a given day.

**And answering it BACKWARDS removed the rest.** The desktop starts at the
nearest `daily_balance_snapshot` and replays every event forwards.
`BalanceHistoryService.totalAt` takes what the accounts hold NOW and subtracts
every event since the day asked about. The two are algebraically the same
whenever the ledger is complete — `sum(all) - sum(after d)` is `sum(up to d)`
— so this is a reduction rather than a different answer, and it needs no
snapshot at all. Which is just as well: `daily_balance_snapshot` is in the
schema, shared with the desktop, and nothing in this app writes it.

Where the two CAN differ, the backward derivation is the better one. It
anchors on `SUM(accounts.balance)`, which is the figure the ring itself shows,
so the history cannot tell a second story about the balance printed above it.

**Before the ledger begins, the answer is "not known", never zero** — the
desktop's rule, kept, and the one that matters most here. A date earlier than
the oldest event is a date this app has no information about, and answering
zero would tell a user they had no money at all. That null travels from the
service through `BalanceChange.isKnown` to the ring, which then draws no chip.

**The percentage refuses to be invented too.** A change from an actual zero
has no finite percentage; zero to zero is the one well-defined no-change case
and answers 0%. Those two rules are adjacent and easy to swap, so they have
their own vectors — and when the percentage is absent the chip still shows the
lira figure, which is true either way.

**The vectors come from calling the desktop.** `dashboard_period_service` takes
its balance reader as an ARGUMENT, so `tool/emit_period_vectors.py` drives it
with a stub and every window, baseline and percentage in the fixture is the
module's own output. Writing that generator caught a mistake in itself: a case
labelled `today` had been handed the `1 Ay` filter, and the fixture's baseline
came out a month early. The `history_service` half has no such fixture — it
needs a database — so it is tested against a ledger this suite builds, and the
reduction above is stated in the file rather than assumed.

**Four mutations fail the suite:** a zero baseline reported as 0%, an
off-by-one that makes the window exclusive, an unknown baseline treated as
zero, and a day boundary that excludes the day itself.

**One period, named on the ring.** Home has no period selector — the Assets
tab is where periods are picked — so the chip is fixed at 30 days and the ring
says so: "Net Worth · 30 days" when there is a figure, plain "Net Worth" when
there is not. A change over an unstated period is a number nobody can check.

**And the test caught what the emulator would have.** The chip carries both a
lira figure and a percentage, and `+250,00 ₺ · +%25` overflowed the 256px ring
by 53 pixels. `TrendChip` now shrinks its label to fit, exactly as the balance
above it already did — an overflow here is not a debug stripe, it is a chip
clipped mid-number, which reads as a different amount.

### The verification round

Item 6 of the road to 1.0, minus the keystore, which is not a coding task.
Both halves ran on a RELEASE build — R8-minified, signed with a throwaway key
that was deleted afterwards — because a verification round on a debug build
proves the debug build.

**It found a defect that had shipped in every build ever made: the screen lock
never worked.**

`local_auth` shows Android's BiometricPrompt, which is a fragment and needs a
`FragmentActivity`. `MainActivity` extended `FlutterActivity`, the Flutter
template's default, so `authenticate()` threw `no_fragment_activity` every
time. Three things conspired to hide it:

* `isDeviceSupported()` does NOT need the fragment, so the Settings row went
  on correctly reporting that the phone could authenticate.
* `ScreenLock.authenticate` caught the exception and returned false, which is
  the right answer for a user who declines and is indistinguishable from a
  platform that could not ask.
* No test could see it. The widget tests drive a fake authenticator — which is
  correct, since the real one needs a device — and the emulator had no screen
  lock configured, so the row was always in its "this device cannot" branch.

The switch simply did not move when tapped. Nothing in the log, nothing on
screen.

**The fix is one word in Kotlin**, and it is held by
`test/main_activity_test.dart`, which reads `MainActivity.kt` as source. That
is the only place the rule is expressible — the same shape as
`dead_controls_test.dart`, which asserts a rule the widget tree cannot state.
`authenticate` also logs now: false is still the answer, but a platform
failure leaves a trace where it left none.

**Then the lock was driven end to end.** `adb shell locksettings set-pin`,
then: the row changed to "Asks for your fingerprint or PIN"; the switch raised
BiometricPrompt (visible in logcat as `showAuthenticationDialog` — the prompt
is a secure window and does not appear in a screenshot, which is itself
correct); the PIN turned the switch on; the app was backgrounded for seventy
seconds, and coming back raised the prompt again before showing anything;
entering the PIN gave the screen back.

**And a restore was carried through to the end.** The R8 round stopped at the
file picker. This one pushed `test/desktop_backup.archlence-backup` — the
package generated by the DESKTOP's own `backup_service` — into Downloads and
restored it. The app asked "Replace everything in this app?" first, then took
it: the balance became the fixture's 1.500,00 ₺, and searching `haftalik`
found `haftalık alışveriş`.

That last detail is the one that matters. The description is a field the
desktop encrypted with the key inside that package; finding it proves the KEY
was swapped along with the database, not merely the file copied. And it came
back through the Turkish folding, which had never met a desktop-written row.

**Cleaned up afterwards:** the throwaway keystore, the APK it signed, the
device PIN, the pushed backup, and the app itself.

### The accessibility pass — `test/screens/accessibility_test.dart`

Not one of the six numbered items; started because this file had just called
it "the one that affects every user of the app rather than some of them, and
the one nothing in this repo would notice the absence of". Every screen is
checked by tests that read the widget tree directly, which is exactly what a
screen reader does NOT do.

**The thresholds are Flutter's, not this repo's.** `androidTapTargetGuideline`
is Material's 48x48, `textContrastGuideline` is WCAG AA, and
`labeledTapTargetGuideline` is "a tappable node has a label". Inventing
numbers here would have been inventing a standard.

Ten screens, three guidelines, run on a PHONE-sized surface rather than the
2400px one the other screen tests use — a tap target's size is the thing being
measured, and measuring it on a surface no phone has would measure nothing.
The screens are seeded first: an empty app passes all three trivially.

**Contrast passed everywhere.** Obsidian Prime holds WCAG AA as drawn, which
is worth knowing rather than assuming.

**Four unlabelled controls, all icon-only.** The floating button that records
a transaction — the app's most-used control, announced as "button" — plus the
add buttons on Budget and Savings, and the sixty switches on Category
Settings, which a reader announced as sixty identical "on, switch" with the
category's name in a separate node beside them.

**The calendar's cells cannot meet 48x48, and the exemption is bounded.**
Seven 48dp columns need 336dp; a 360dp phone spends 48 on the screen margin
and 16 on the card, leaving 296 — 42dp a column. The card's own padding was
cut from 32 to 16 to buy what it could, the cells are now 48 TALL since height
is the free dimension, and Material's own date picker makes the same trade.
The test excludes that ONE screen from that ONE guideline, by name, and pins
42x48 in its own assertion — so the cells cannot shrink further under cover of
the exemption, and the calendar is still held to the other two guidelines.

**And the mutation check caught a fix that was worse than the defect.** The
first attempt at the category switches wrote a label by hand onto a
`Semantics` wrapper and put `ExcludeSemantics` around the switch, so a reader
would not hear the state twice. It read beautifully. It also removed the
switch's TAP ACTION — leaving the row unreachable to exactly the assistive
tech it was written for — and it PASSED the guideline, because a node that is
not tappable cannot be an unlabelled tappable node.

Deleting the label left the suite green, which is what said so. `MergeSemantics`
is the answer: it keeps the action and reads the name, the side word and the
state as one thing.

That is the second time in two sessions that a green mutation was the finding
rather than a false alarm. The habit is worth its cost.

**What this cannot see, and does not claim to.** These guidelines read the
semantics tree. They catch an unlabelled control and a target too small to
hit. They do not catch a reading ORDER that makes no sense, a label that is
present and useless, or a layout that breaks at 200% font scale. Those need a
person with TalkBack on, and this file says so rather than implying the box is
ticked.

### Wide screens — `contentInset`, `test/screens/wide_layout_test.dart`

The last item under "Not yet considered at all" that was engineering rather
than judgement.

**Nothing was broken, which was the first finding.** Ten screens at five
sizes — 360x800, a landscape phone, and Material's 600 / 840 / 1280 — and not
one overflow. The layouts are `ListView`s and `Column`s, so a wide screen
stretches them rather than breaking them.

**What a wide screen did instead was make the app unreadable.** Measured, not
guessed: on a 1280dp tablet the Category Settings explainer ran as a single
line 1198dp wide. Material asks for 40 to 75 characters on a line of body
text; that is roughly 150.

**So the side inset became responsive, and the cap is derived.**
`contentInset(context)` is `Spacing.containerMargin` on a phone and whatever
it takes to hold content to `readableContentWidth` on anything wider. 600dp is
not a taste: body text here is 16sp, a character averages about half its point
size, so 600 / 8 lands on 75 — the top of Material's range.

**The padding grows rather than the scroll view narrowing.** A `ConstrainedBox`
would have made the scrollable itself 600dp wide, leaving a thumb reaching for
the right-hand edge of a tablet touching nothing. The scroll surface stays the
full width of the screen; only the content inside it is inset.

**This is not a tablet LAYOUT and does not claim to be.** No second pane, no
list beside a detail, no `NavigationRail`. It is the smallest thing that stops
a wide screen from being worse than a narrow one.

**The test holds both halves of the rule.** A cap alone is half of it: the
other half is that a 360dp phone must NOT gain margins it did not have, and a
mutation that applies the cap everywhere fails on exactly that. Removing the
cap fails the tablet half.

**And running it on a tablet found what the test list had missed.** The
emulator was reshaped to 2400x1600 at density 200, and onboarding — the first
thing a new user reads — was still stretched edge to edge, because it was not
in the list of screens the test walks. Nor were the lock screen or the sheets
every write flow uses. All three are inset now and the first two are in the
list.

A test that walks a list of screens is only ever as good as the list. That is
the same failure shape as `dead_controls_test.dart`'s first draft, which
looped over a finder that matched nothing.

### The move to Windows — `.gitattributes`, and a premise about the machine

The development machine was formatted mid-project and came back as Windows 11,
so the toolchain was rebuilt from nothing: JDK 17, Flutter 3.47.2, the Android
SDK, the `archlence_pixel` AVD. See "Environment", which this replaced rather
than extended. **Nothing in the app changed.** Two things in the REPOSITORY
did, and both were the same shape — something that had quietly depended on the
operating system the developer happened to be using.

**Git for Windows installs with `core.autocrlf=true`, so the clone rewrote
every text file to CRLF.** For source that is cosmetic. For `test/` it is not:
those fixtures are the desktop app's own output, and the tests compare against
them rather than against a reading of them. `desktop_schema.sql` arrived with
`;\r\n` line endings, `schema_parity_test.dart` splits the dump on `;\n`, and
the split simply stopped happening — the whole schema collapsed into one
statement, `desktopObjects()` came back holding a single entry called
`accounts` with the entire dump inside it, and two of that file's six tests
failed.

**That it failed loudly was luck.** The same rewrite went straight through
every other fixture without a word, because they are read with
`readAsLinesSync` and Dart's `LineSplitter` accepts CRLF as happily as LF. A
parity fixture that is quietly no longer the bytes the desktop wrote is worse
than one that breaks the test reading it: the whole point of these files is
that nothing about them was transcribed. The backup package escaped because
git detected it as binary and left it alone — checked rather than assumed, by
comparing its digest against the blob in `HEAD`.

**So the line endings belong to the repository now, not to the platform.**
`.gitattributes` sets `* text=auto eol=lf` and names the binary kinds
explicitly, and the working tree was re-checked-out through it. Proven by
putting the CRLF back by hand: the two schema tests fail, and with LF all six
pass.

**The second was a test premise about the developer's machine.**
`backup_bounds_test.dart` asserted `p.basename(r'..\finance.db')` is
`..\finance.db` — the line that says WHY the name check exists, because a name
the path library takes for a plain file is a name that gets written. But
`package:path`'s bare context follows the HOST, so on Windows `p.basename`
answers `finance.db` and the premise reads as false. It is `p.posix.basename`
now, which is what it always meant: the app runs on Android.
`requirePlainMemberName` itself asks no path library anything — it looks for
both separators and the drive-letter form by hand — so the production code was
right on every host, and only the test moved.

**Checking that test's teeth found a rule that had none.** Delete the
drive-letter rule from `requirePlainMemberName` and every one of the file's 22
tests still passes. The only `C:` input the test carried was `C:\finance.db`,
which has a separator in it, so the check on the line above answers first and
the rule underneath is never reached. The case it was written for is the
drive-RELATIVE form — `C:finance.db`, no separator anywhere in it — and that
is in the test now.

Four mutations, run one at a time against the file:

| Mutation | Result |
| --- | --- |
| Drop `name.contains('\')` from the separator check | fails, as it should |
| Delete the drive-letter rule, with the new input | fails, as it should |
| Delete the drive-letter rule, with the test as it was | **passes** — the rule had no teeth |
| Put the premise back on the host's path context | fails, as it should |

The third line is the finding. A rule whose only input is answered by the rule
above it is a rule that could be deleted without a test noticing, which is the
same thing this file has said twice already about absences: R8's missing
`isMinifyEnabled` line, and the six desktop services that were never mentioned.
Here the absence was a test case, and the rule looked covered because an input
with the right shape was in the list.

### The move back to Linux, and a slow suite that was never the disk

The machine moved again — Windows 11 to CachyOS, an Arch derivative — so the
toolchain was rebuilt from nothing for the second time: JDK 17, Flutter
3.47.2, the Android SDK, the `archlence_pixel` AVD. See "Environment", which
this replaced rather than extended. Everything is under `~/dev` because `sudo`
wants a password this session cannot give it, and `pacman` was never asked for
any of it.

**Nothing in the app changed, and this time nothing in the repository did
either.** That is the return on the last crossing. Both things the Windows
move cost were fixed at the repository level rather than by configuring a
machine, and both survived coming back:

* `.gitattributes` pins `* text=auto eol=lf`, so the checkout is LF here as it
  was there. Checked rather than assumed, and the check was checked first: a
  file with known CRLF is detected by it, and then all 323 tracked files come
  back with no CR byte in any of them.
* `backup_bounds_test.dart` asks `p.posix.basename` rather than the host's
  path context, so its premise reads the same on Linux, Windows and the
  Android the app actually runs on.

Had either been fixed by setting `core.autocrlf=false` on that machine, or by
writing the test around Windows, this move would have broken it again in the
opposite direction and the breakage would have been just as quiet.

**What the move did break was a claim in this file.** The Windows Environment
section said the suite took about ten minutes, that
`backup_service_test.dart` was roughly eight of them, and that the cause was
the checkout's location — under `OneDrive\Documents`, so every temporary
database the backup tests write goes through file sync and the virus scanner.
"Moving the checkout off OneDrive, or excluding it from sync, is the fix."

This machine has no file sync, no virus scanner and an NVMe disk, and the file
still takes four and a half minutes. So it was measured properly:

| Run | Tests | Time |
| --- | --- | --- |
| `flutter test` | 1117 | 4m41s |
| `test/backup_service_test.dart` alone | 23 | 4m35s |
| the same file, from a `/dev/shm` copy | 23 | 4m40s |
| everything else | 1094 | ~25s |

**The tmpfs run is the one that settles it.** A `git archive` of `HEAD`
unpacked into `/dev/shm` — RAM, no disk under it at all — runs the same file
in the same time. Whatever those minutes are, they are not I/O.

They are the key derivation. `_pbkdf2` in `recovery_material.dart` runs
600 000 rounds of PBKDF2-HMAC-SHA256, and instrumenting it to print on every
call gives **182 derivations in that one file, every one of them at the full
600 000 rounds** — there is no reduced-cost path the tests take. One
derivation, measured five times on this CPU, costs 1.50s (1497–1509ms). 182 ×
1.50s is 4m33s, against a measured 4m35s. **The file's runtime is 99% key
derivation**, and the two seconds left over are everything else those 23 tests
do — the databases, the packages, the journalled restores.

The arithmetic is not circular, which is why the round count was measured
rather than assumed: had some tests derived at a lower cost, 182 × 1.50s would
have overshot the measured time instead of landing two seconds under it.

**The lesson is the one this file keeps relearning, in a new shape.** R8 was
believed off because a line was absent. Six desktop services looked considered
because they were never mentioned. Here a cause was believed because it was
*present*: OneDrive really was there, file sync really is slow, and the story
fit well enough that nothing measured the thing it was supposed to explain. A
plausible cause standing next to an unmeasured effect is not a diagnosis, and
the recommended fix — move the checkout — would have bought nothing that could
be measured.

**None of which is a defect.** 600 000 rounds is the KDF doing its job, and
the cost is the point; see "The backup's cryptographic core". What is worth
knowing is only that this suite's clock is a security parameter rather than an
engineering one. It scales with the CPU and with nothing else, it will be
slower on a laptop, and no amount of disk or filesystem tuning will move it.

If it ever does need to be faster, the lever is the tests rather than the
machine: `_requireIterations` already accepts a range, so a fixture could
derive at the format's minimum and leave a handful of cases on the shipping
600 000. That trade has NOT been made — every one of the 182 derivations
currently runs at the parameter that ships, which is the strongest version of
the test and, at four and a half minutes, still cheaper than being wrong about
it.

### The move to a laptop, and what the SDK renamed under us

The machine moved a third time — CachyOS back to Windows 11 — and for the
first time it is a **different machine** rather than the same one reimaged: a
Ryzen 7 260 laptop where the last three setups were a Ryzen 7 9700X desktop.
The repository crossed clean again, for the reason the second move paid for:
`.gitattributes` holds every fixture at LF, and the one test premise that asks
`package:path` a host-dependent question asks `p.posix`. Nothing in the
repository had to change *for the move*.

One line had to change anyway, and the distinction is the point: **it was not
the machine, it was Google.** Three things had been renamed in the Android SDK
since the last setup, and none of them is visible until a build runs.

**1. `sdkmanager` is a shim now.** `cmdline-tools` 23.0.0 — build 16111833,
the current "latest" — retires it and forwards every call to a new `android`
CLI whose package paths use `/` instead of `;`. Installing six packages the
documented way put four of them on the floor:

    Package platforms not found.
    Package android-35 not found.

AGP asks for the NDK by exactly that syntax, so the first Android build on
this machine failed inside a tool nobody typed:

    Process 'command 'C:\src\android-sdk\cmdline-tools\latest\bin\sdkmanager.bat''
    finished with non-zero exit value -1073740791

which is `NTSTATUS 0xC0000409`, STATUS_STACK_BUFFER_OVERRUN — the shim
crashing rather than reporting. Nothing in that message names the cause. The
fix is to hold `cmdline-tools\latest` at 22.0 (build 15859902), which still IS
`sdkmanager`; the difference is one word in their own warnings, "Android CLI
**will be used** instead" against "**Use** Android CLI instead".

**2. There is no `platforms;android-37` any more.** Google ships 37.0, 37.1
and 37.2 as separate packages. With `compileSdk = 37` and nothing else, AGP
asks the SDK for target hash `android-37`, does not find it, downloads
`platforms/android-37.0` on its own initiative, and then fails:

    Failed to find target with hash string 'android-37' in: C:\src\android-sdk

having just installed the thing it could not find. `compileSdkMinor = 0` makes
the hash `android-37.0`, and the build goes through.

**That one is a source change rather than a machine setting,** which is why it
is in the repository: a fresh setup on any OS today hits it. The CachyOS
machine built the first App Bundle against a bare `android-37` that existed
then and does not exist now — so that bundle was compiled against a platform
package which can no longer be installed. Nothing about the app changed; the
SDK's shelf did.

**3. `--licenses` is gone**, in both generations. `sdkmanager --licenses` and
`flutter doctor --android-licenses` both answer "The --licenses option is no
longer needed" and do nothing; licences are accepted at install time instead.
`flutter doctor` has not caught up and still reports "Android license status
unknown" on a machine where every build downloads and accepts what it needs.
The Windows-versus-Linux question this file used to record — that PowerShell
could not pipe `yes` into it — did not need answering again; it stopped
existing.

**What the move cost the app: nothing, and that is measured rather than
assumed.** `flutter analyze` is clean, 1117 unit tests pass, and all 14 device
tests pass on `archlence_pixel` — including the two that open a real socket,
where CoinGecko and Frankfurter both answered from this machine. The release
guard still refuses correctly: `flutter build appbundle --release` fails on
`:app:bundleRelease` with the message naming `android/key.properties.example`
rather than with an AGP stack trace, and `./gradlew
:app:processReleaseMainManifest` puts `android.permission.INTERNET` in the
merged release manifest beside the two biometric ones. Both were claims made
on the last machine, and both hold on this one.

**And one process outlives the command here.** `flutter test` printed "All
tests passed!" and its own `time` reported 7m28s — and a `flutter_tester.exe`
then stayed alive for another three quarters of an hour, slowly accruing CPU,
with the shell that launched the suite not reported as finished until it was
killed. The numbers were all there; only the process was not. Worth knowing
before reading a finished run as a hung one, which is the same trap the
emulator-versus-`backup_service_test.dart` note records from the other side.

### The key that was on the other machine

**The keystore that signed `v1.0.0` is gone.** It lived at
`~/archlence-release.jks` on the CachyOS machine and nowhere else — this file
said so at the time, in the same breath as saying it was not backed up by
anything here. `android/key.properties.example` states the consequence in its
own words: lose it and no future version can ever update an already-installed
one. That is no longer a warning about a possibility.

**What it does and does not block.**

* Everything in this repository still builds, tests and runs. Only
  `assemble*Release` and `bundle*Release` are refused, and by this project's
  own guard rather than by anything downstream.
* **Nobody is stranded.** `v1.0.0` was published and pulled before it reached
  users — see "The Turkish was in the wrong register" — so there is no
  installed base holding a signature this project can no longer produce. The
  loss costs a procedure, not a user.
* What it blocks is uploading to the SAME Play entry, and only if that entry
  still exists.

**The two questions that decide it are in Play Console, not in this file.**

1. **Is Play App Signing enabled on the app?** Uploading an App Bundle
   requires it, and a bundle was uploaded — so Google holds the app SIGNING
   key and what was lost is only the UPLOAD key. That case is recoverable:
   make a new keystore, and ask Play support for an upload key reset with its
   certificate. The app signing key never left Google and is not affected.
2. **Was the release deleted, or the app?** A deleted app takes its package
   name with it permanently: `com.archlence.archlence_mobile` could never be
   used again, and the answer would be a new applicationId and the listing
   done once more. This is a different problem with a different cost, and the
   two look alike from outside the console.

Neither can be answered from the repository, and guessing at them is how a
session spends a day preparing the wrong recovery.

**Making the replacement keystore is not a session's job.** Same reasoning as
when the first one was made: it is a credential, it belongs to whoever ships
the app, and its password has no business being typed into a tool that logs
its commands. The command, with this machine's paths:

```
C:\src\jdk-17\bin\keytool -genkey -v -keystore "$env:USERPROFILE\archlence-release.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias archlence
```

Then copy `android/key.properties.example` to `android/key.properties` and
fill in the four values — `storePassword` and `keyPassword` are the same
string, because JDK 9 and later write PKCS12 and a PKCS12 store has one
password. **And put a copy somewhere that is not this machine**, which is the
part the last keystore did not get.

**A replacement was made, and it builds.** `keytool` on this machine produced
a new PKCS12 store, `android/key.properties` was written to point at it, and
`flutter build appbundle --release` — refused an hour earlier by the guard —
produced `app-release.aab` at 62.0MB in 1m0s. `jarsigner -verify` answers
`jar verified`, and the certificate in it is:

    Owner:  CN=Superuser-d0, OU=Unknown, O=Archlence, L=Unknown, ST=Unknown, C=TR
    SHA256: DF:1C:75:A4:0F:C6:51:92:32:E7:91:E0:37:0E:EE:C3:
            BD:1C:DB:62:17:E3:B3:6D:2E:74:EE:68:9F:78:6E:6B
    Valid:  2026-08-31 to 2054-01-16 (10 000 days)

rather than `CN=Android Debug`, which is the check "Release signing" exists to
make. That fingerprint is written down here on purpose: it is not a secret —
anyone can read it out of a published artifact — and it is exactly what a Play
upload key reset asks for.

**And a phone downloads about 10.7MB of it**, measured with `bundletool`
1.18.3 rather than inferred from the 62.0MB the bundle weighs on disk:

| ABI | Download |
| --- | --- |
| `armeabi-v7a` | 10.36-10.39MB |
| `arm64-v8a` | 10.68-10.72MB |
| `x86_64` | 10.92-10.95MB |

Each ABI is 0.2-0.4MB lighter than the same ABI out of the previous bundle
(10.59 / 11.12 / 11.19MB), on a bundle 4.7MB smaller overall — which is the
comparison worth keeping rather than the figures: a bundle's weight is mostly
the ABIs a given phone will never receive and the debug symbols Play never
sends, so 4.7MB off the bundle is a few hundred kilobytes off the download.

**What the new key does NOT do is answer the two questions above.** Play knows
the old certificate. This one can only replace it by a reset that Google
performs, and only if the app entry is still there with Play App Signing on
it. The bundle that now exists is a bundle this project can build, not yet a
bundle this project can upload.

**Two Windows traps on the way, both silent.**

* `%USERPROFILE%` is cmd.exe syntax. In PowerShell it passes through
  unexpanded, so `keytool` asks all six certificate questions, generates the
  key pair, and only then fails with a `FileNotFoundException` naming a
  directory called `%USERPROFILE%`. Nothing is written and the whole dialogue
  has to be repeated. `"$env:USERPROFILE\..."` is the form that works.
* **`key.properties` is a Java Properties file, where a backslash is an escape
  character.** `storeFile=C:\Users\...` is not the path it looks like — `\U`
  and `\a` are consumed on the way in. This one is written with forward
  slashes, which Java accepts on Windows, and the file says why in a comment
  so the next person does not tidy them back.

### The key store, moved to version 11 — and the default that flipped under it

Open work item 2 was the dependency knot: `share_plus` 12 applies the Kotlin
Gradle Plugin, Flutter warns that plugins doing so will stop building, every
`share_plus` that fixes it needs `win32: ^6`, and `flutter_secure_storage` 9
forbade that through its Windows sibling. It is untied:

| | Before | After |
| --- | --- | --- |
| `flutter_secure_storage` | 9.2.4 | 11.0.0 |
| `share_plus` | 12.0.2 | 13.3.0 |
| `win32` | 5.15.0 | 6.4.0 |

**The API change is not the dangerous part. The default that moved underneath
it is.** All five constructions in `lib/` passed
`AndroidOptions(encryptedSharedPreferences: true)`, and 11 deleted that
parameter — a compile error, which is the kind of breaking change that
announces itself. What does not announce itself is `resetOnError`:

* in 9 it defaults to **false**, and the app took the default;
* in 11 it defaults to **true**, and the package's own doc comment says it
  "will PERMANENTLY erase the data when an error occurs".

What this store holds is the AES-256-GCM key the entire database is encrypted
under. A migration that deleted the removed parameter and left the rest alone
would compile, pass every test, and ship an app that silently destroys every
account, transaction and holding on the device the first time a read fails —
with nothing in the log to say it happened, because from the package's point
of view the error was handled.

It is `AndroidOptions(resetOnError: false)` at all six construction sites now,
five in `lib/` and one in `key_provider_device_test.dart`. **All six, not just
the key's**, because the entries share one store: a reset triggered by the
language preference would take the key with it. `pubspec.yaml` carries the
reason at the dependency line, and `SecureStorageKeyProvider` carries the long
version.

A note on what the old flag meant, since it reads like a downgrade: in 9,
`encryptedSharedPreferences: true` opted INTO Jetpack Security's
`EncryptedSharedPreferences`, which was stronger than that version's default.
10 migrated everyone off it onto its own AES-GCM/RSA-OAEP storage and 11
deleted it. The strongest option is now the default, so the flag is not just
removed — it has nothing left to ask for.

**Then two build failures, neither of which reading the diff would find.**

**One: `compileSdk` 36 is not enough, and it is not a warning.**
`flutter_secure_storage` 11 is compiled against 37 and declares it in its AAR
metadata, so `:app:checkDebugAarMetadata` fails the build. The Flutter tool
prints a *warning* one line earlier — "requires Android SDK version 37 or
higher" — and a warning is what it looks like until Gradle refuses. Checked by
putting `flutter.compileSdkVersion` back: both the plain debug APK and the
integration-test variant fail identically, on that task, with that dependency
named. (The first debug build of the session did report success at 36, once,
which is what made the requirement look optional. It has not reproduced, and
the cause was not established — worth knowing only as a reason not to trust a
single green build here.)

`compileSdk = 37` now, written out in `android/app/build.gradle.kts` rather
than taken from `flutter.compileSdkVersion`. **`targetSdk` did not move.**
Compiling against a newer SDK changes nothing about behaviour; `targetSdk`
changes how Android treats the app at runtime, and that is a decision to make
deliberately and test rather than to inherit from a dependency's build file.

**Two: nothing was compiling `share_plus`'s Kotlin.** The failure reads
`Share.kt:185: Unresolved reference 'SharePlusPendingIntent'` — a class in the
file sitting next to it, in the same source directory. The cause is two
settings that are each reasonable alone:

* `share_plus` 13 stops applying KGP when AGP is 9 or newer — which is the
  entire reason for upgrading to it;
* `android/gradle.properties` carried `android.builtInKotlin=false`, from the
  Flutter template.

Together they leave the plugin with no Kotlin compiler at all. It is
`android.builtInKotlin=true` now. Worth recording because neither line is
wrong on its own and one of them was not written here: a template default and
an upstream fix can be individually correct and jointly fatal, and the error
they produce names a missing class rather than a missing compiler.

**Proof.** `flutter analyze` clean; the 903 unit tests there were at the time;
all 14 device tests on a
CLEAN INSTALL on `emulator-5554`, including the four that drive the real
Android Keystore and the two that open a real socket; and a debug build that
now prints **no warnings at all** — neither the KGP one this work set out to
remove nor the SDK one it uncovered. Three test fakes needed their override
signatures updating too: 11 merged `IOSOptions` and `MacOsOptions` into
`AppleOptions`.

**What could NOT be checked, and is worth saying rather than implying.** The
in-place 9 → 11 upgrade — an installed app with data written by the old store,
receiving the new one — was not exercised. The plan was to run it before the
clean install; the emulator turned out to have no prior install left
(`pm list packages` found none), so there was nothing to upgrade over. That
path rests on `flutter_secure_storage`'s changelog rather than on anything
measured here. **It also does not matter yet, and that is the whole reason
this was done now:** nothing is released, so no device anywhere holds data
written by version 9. The day one does, the road to 11 has to pass through 10.

### The first App Bundle, and what a phone actually downloads

The release keystore exists — made by hand, outside the repository, and its
password typed nowhere near it. `android/key.properties` points at it and is
ignored by git, checked rather than assumed with `git check-ignore`.

**`flutter build appbundle --release` has now been run, for the first time in
this project.** It has been sitting at the top of Open work for months on the
grounds that a build the store cannot accept is worth discovering before
listing day. It built first try, in 54.8s:

```
✓ Built build/app/outputs/bundle/release/app-release.aab (66.7MB)
```

**Signed by the right key**, which is the one thing here that fails silently
if it is wrong. `jarsigner -verify -certs` reads the certificate out of the
bundle and needs no password:

```
Signed by "CN=Archlence, OU=Unknown, O=Archlence, L=Unknown, ST=Unknown, C=TR"
Signature algorithm: SHA256withRSA, 2048-bit key
jar verified.
```

Not `CN=Android Debug`. The refusal wired into `android/app/build.gradle.kts`
— the one that replaced the Flutter template's habit of signing release
builds with the SDK's debug key — held, and this is the first build that could
prove it.

**And the 65MB question is answered by measurement rather than by arithmetic.**
This file has twice said Play serves per-device splits at "roughly a third" of
the bundle. That was a guess and it was pessimistic by half.
`bundletool 1.18.3`, `build-apks` then `get-size total`:

| ABI | What the device downloads |
| --- | --- |
| `armeabi-v7a` | 10.59 MB |
| `arm64-v8a` | 11.12 MB |
| `x86_64` | 11.19 MB |

A 66.7MB bundle reaches a real phone as **about 11MB** — a sixth, not a
third. The size concern that has been carried in this file since the first
release APK is closed.

**Still open, and it is the last engineering item before the listing:** install
that release build on a device, open Assets, and confirm a crypto holding
reads `Current` rather than `Cost`. The merged release manifest carries the
INTERNET permission and the device tests prove the network path in debug; what
no test has seen is prices arriving in a build with R8 on and the release
manifest under it. See "The permission a release build did not have".

### The pre-release sweep, and the four tabs no test had ever opened

Before a listing, everything was run again and then some: `flutter analyze`,
903 unit tests, 14 device tests, a signed App Bundle, a release APK installed
on a clean device and driven by hand to a live price. All of that passed. Then
the suite was asked a question it had never been asked, and **six defects fell
out of one blind spot.**

**The blind spot.** `accessibility_test.dart` applies Flutter's three
guidelines to `AppShell`. `wide_layout_test.dart` lays `AppShell` out at
360x800. Both are good tests and both see the same thing: **the Home tab.**
`AppShell` opens on it, nothing in the file taps anything, and the other four
tabs are never built. Checked rather than assumed — `grep` across `test/` finds
no test anywhere that selects a tab other than the default.

So a temporary sweep was written that opens each of the five tabs and then
applies, to each: the three accessibility guidelines; a layout at 1.5x and
2.0x font scale; a layout on a 320dp phone; and a layout in Turkish, at
default and at 2.0x. 26 cases against the suite's usual 5.

**Its first draft produced findings that were its own fault**, and that is
worth recording because the mistake is easy and invisible. The font scale was
applied by wrapping the app in `MediaQuery(data: MediaQueryData(textScaler:
...))` — which does not override one field, it replaces the whole
`MediaQueryData`. Size, padding and insets all went to defaults, so screens
laid out against a zero-size window and overflowed for reasons that had
nothing to do with fonts. The scale goes through
`platformDispatcher.textScaleFactorTestValue` now, which is the seam that
leaves the rest of the window alone. Every number below is from the corrected
run.

**What it found.** Six defects, at
`tools_screen.dart:192`, `assets_screen.dart:917`, `assets_screen.dart:976`,
`cards_screen.dart:310`, the Cards screen's switch row, and
`assets_screen.dart:295` — listed with their reproductions and their order of
attack under "Open work". One of them, the Tools grid, overflows **at the
default font scale on a 360dp phone**, which is to say on an ordinary device
in an ordinary configuration, and has done since the screen was written.

**Two of the findings are not layout at all**, and one of those was found by
hand rather than by the sweep. Driving the release build on the emulator with
`uiautomator dump` reading Flutter's semantics tree, the `+` button beside
"My Active Assets" is absent from the tree entirely while every other control
is present. It is an `IconButton` with no `tooltip`. The sweep's own label
guideline does NOT catch it — the Assets tab passes that check — which is a
second layer of the same lesson: a guideline only sees what is laid out, and
what is laid out depends on what is above it in a scroll view.

**The count that matters.** 903 unit tests, 14 device tests, a full manual walk
of a release build, and a hand-driven purchase flow all passed while six
defects sat on four tabs. Not one of them is subtle in the code; every one of
them is invisible to a test that never builds the screen.

### The six, fixed — and one fix that passed its test and broke the screen

All six defects from the sweep are closed, in the order the backlog set, and
the order mattered: the instrument went in first so every fix below had a
named red case to turn green rather than an argument to make.

| | Fix | Sweep after |
| --- | --- | --- |
| P1 | `test/screens/tab_sweep_test.dart` — 40 cases, five tabs | **red: 26 pass, 14 fail** |
| P2 | Tools' fixed `mainAxisExtent` replaced by `IntrinsicHeight` rows | 33 / 7 |
| P3 | `MergeSemantics` on the Cards switch row; a `tooltip` on Assets' `+` | 34 / 6 |
| P4-P6a | Month labels `Flexible`, chart legend `Wrap`, card title `maxLines: 1` | 38 / 2 |
| P6b | The credit-card badge made `Flexible` | **40 / 40** |

**The backlog predicted two things and both held.** Tools' contrast and
tap-target failures were listed as "not separate defects — they are the
overflow surfacing, and if they do not disappear with P2 they are real". They
disappeared with P2: seven failures went at once. And `cards_screen.dart:445`
was invisible until `310` was fixed — a 0.6-pixel overflow standing behind a
30-pixel one. Both texts in that row can give ground now, and the name gives
it first because it is the one with a flex factor.

**Then the fix that was worse than the defect.**

`IntrinsicHeight` around a row of two `_ToolCard`s removed the overflow and
turned every test green. It also grew a gap the design never had: about 130dp
of nothing between the subtitle and the first card. **Nothing in the suite
could have said so**, because a gap is not an overflow and no test asserts
what a screen looks like. It was found by installing the release build and
looking at it.

The cause is a trap worth writing down. `_ToolCard`'s `Column` used a
`Spacer()` to push the label to the bottom, which is correct under a fixed
height and wrong under `IntrinsicHeight`: the intrinsic-height pass scales the
inflexible children by the largest flex fraction it finds, so a card whose
content needs about 124dp reported about 215. The card was not too tall
because of its contents — it was too tall because of how it asked to be
measured.

`mainAxisAlignment: MainAxisAlignment.spaceBetween` and a real `SizedBox` do
the same job: the label still sits at the bottom when there is slack, and the
intrinsic height is the content's. Verified on a device, at 411dp — the cards
begin one gutter under the subtitle, and "Monthly Budget", "Interest Return"
and "Compound Interest" all wrap to two lines inside their cards without
clipping.

**This is the working agreement's first line, aimed at a fix rather than at a
feature.** Run it, don't just read it — including after the tests go green,
because a green suite says the defect is gone and says nothing at all about
what replaced it.

**And one rule that reads the source, because the guideline could not.**
`test/icon_button_tooltip_test.dart` requires every enabled `IconButton` in
`lib/` to carry a tooltip. A tooltip IS the semantic label on an
`IconButton`, and without one the control is absent from the semantics tree
rather than merely unnamed — which is why `labeledTapTargetGuideline` did not
catch Assets' `+` on any screen, on any tab: the guideline reads the tree, the
tree holds what was laid out, and that button is below where either test lays
the screen out. A rule that reads the source has no such blind spot. Disabled
buttons are exempt, which is the framework's own exemption and covers
`app_shell.dart`'s notifications bell.

**Checked for teeth, three mutations, one at a time:**

| Mutation | Result |
| --- | --- |
| Drop `MergeSemantics` from the Cards switch row | fails, as it should |
| Put `mainAxisExtent: 168` back in the Tools grid | fails — 26 pixels, again |
| Delete the `tooltip` from Assets' `+` | fails, naming `assets_screen.dart:294` |

### The layer under the tabs, and one line missing from seven places

The tab sweep's own entry ended by saying the sheets were still uncovered and
that opening them through their `show...Sheet` functions was probably the
right seam. Both turned out to be right, and the estimate that it would find
things was low.

`test/screens/sheet_sweep_test.dart`: nine ways into a form — add account, add
transaction (twice, with and without a preselected account), buy, sell, budget
line, pay debt, new goal, move money, subscription — against the same eight
conditions every tab is held to. **80 cases. The first run passed 57.**

**Every one of the 23 failures was the same missing line.**
`DropdownButtonFormField` sizes its button to the selected item, so without
`isExpanded: true` the row takes the item's intrinsic width and a label wider
than the sheet OVERFLOWS rather than ellipsizing. The
`overflow: TextOverflow.ellipsis` sitting on those items does nothing at all,
because there is no width constraint for it to ellipsize against. And the
labels are account rows — a name and a balance, in a sheet, on a phone.

**Seven of the app's nine dropdowns were missing it. Two had it.** That is the
part worth keeping: the fix was already in this codebase, applied twice where
somebody had run into it, and never generalised. An answer that exists in two
places and is needed in nine is not a solved problem, it is a solved instance.

**The worst of them overflowed by 152 pixels at the DEFAULT font scale** — the
pay-debt sheet, which has a widget test file of its own that walks it end to
end, types into it, and asserts on both sides of the transfer.

It walks past this because `pumpScreen` lays out on **800x2400 at a device
pixel ratio of 1**. An 800dp-wide surface. No phone is 800dp. This file has
said for a long time that the wide surface "proves NOTHING about
reachability", and that was true and incomplete: it also means **no widget
test had ever laid a sheet out at a width a phone has.** The sheet sweep uses
360dp and 320dp, and that is the whole difference between a suite that walks
the pay-debt sheet and one that sees it.

Seven lines later the sweep is 80 for 80.

**And a rule, because two of the seven were not failing.**
`test/dropdown_expanded_test.dart` requires every `DropdownButtonFormField` in
`lib/` to set `isExpanded`. Two of the seven do not overflow today, purely
because their item labels are short — a category name, an asset type. They
carry the same defect and no sweep would have found them, for the reason this
file keeps rediscovering: a sweep sees what is laid out, and what is laid out
depends on the data it happens to be given. A rule that reads the source does
not depend on either.

Checked for teeth, one at a time: delete a single `isExpanded` and the rule
fails naming `pay_debt_sheet.dart:162`, and the sweep fails with it.

**What the two sweeps still do not cover**, so it is a decision rather than an
oversight: pushed routes that are not sheets — the four calculators, the
calendar, category settings, backup — are each held to the guidelines by
`accessibility_test.dart`, but on its own surface rather than at 320dp and not
at any font scale. That is the next thinnest layer, and on this evidence it is
worth walking too.

### The third layer, which was clean — and why that is the finding

`test/screens/route_sweep_test.dart` walks the nine pushed routes — budget,
savings, the calendar, category settings, Backup & Restore and the four
calculators — at 360dp and 320dp, at 1.5x and 2.0x, and in Turkish. 62 cases.

**All 62 passed on the first run, and nothing was fixed.**

That is worth writing down rather than skipping, because of what it contrasts
with. Three layers were swept in the same session, under the same conditions:

| Layer | Guidelines it already had | Cases | Defects found |
| --- | --- | --- | --- |
| Tabs | none — only the Home tab was ever built | 40 | **6** |
| Sheets | none | 80 | **7** |
| Pushed routes | all three, per screen, in `accessibility_test.dart` | 62 | **0** |

The layer that already had guideline coverage had nothing wrong with it. The
two that had none had thirteen between them. That is not proof of causation
from a sample of three, but it is the shape you would expect if the coverage —
rather than the care taken while writing those screens — is what makes the
difference. The routes were written by the same hand as the tabs.

**A sweep that finds nothing proves nothing until it can fail**, which is this
file's most-paid-for habit and applies hardest to a green result. A `Row` of
two 500dp boxes was put into `budget_screen.dart`'s column and the sweep
caught it, 688 pixels over, on every condition. Removed again, and 62 for 62.

Worth being precise about what the table's third row does NOT say.
`accessibility_test.dart` runs those screens at **one font scale, on
`pumpScreen`'s 800dp surface** — so the coverage it gave them was the three
guidelines, not the widths and scales this file adds. The routes passed the
new conditions on their own merit. What the table shows is that a screen held
to guidelines from the start also came out sound under conditions those
guidelines never applied, and the two layers with no guideline at all did not.

The calendar keeps its one exemption from `androidTapTargetGuideline`, argued
in full in `accessibility_test.dart` and unchanged here: seven columns cannot
each have 48dp on a 360dp phone, and its cells are 48 TALL, which is the
dimension that is free. It is laid out at every width and scale like
everything else.

### What the 800dp surface was hiding

Open work item 2 was a decision: `pumpScreen` lays every screen and sheet test
out on 800x2400 at a device pixel ratio of 1, no phone is 800dp, and nobody
had chosen that — it was inherited from a trade made for a different reason.
Rather than argue it, it was measured. The default was changed to 360dp and
the suite was run.

**32 of 1087 tests failed, and the split is the whole answer:**

| | |
| --- | --- |
| Overflow assertions, at three sites | **12** |
| Unreachable taps — the known cost of the wide surface | 4 |
| Consequences of the above | the rest |

**The three sites were places the sweeps structurally cannot reach.**

| Site | The state that breaks it |
| --- | --- |
| `calculator_screens.dart` result row | a calculator **showing a result** — 9 of the 12 |
| `calendar_screen.dart` entry row | a day whose amount **cannot be read** |
| `assets_screen.dart` holding row | a holding **once a live price arrives** |

Read the middle column again, because it is the finding rather than the three
defects. `tab_sweep_test.dart`, `sheet_sweep_test.dart` and
`route_sweep_test.dart` lay every screen out at 360dp, 320dp, 1.5x, 2.0x and
in both languages — **in the state the screen OPENS in.** A calculator with no
result. A calendar with no day picked. A holding with no price yet. The
per-screen test files DO drive those states, and they drive them on an 800dp
surface. So the intersection — **a real state at a real width** — was covered
by nothing at all, and it held three overflows, one of them on the screen a
calculator exists to produce.

Three sweeps, 182 cases, and the gap between them was not a screen. It was a
dimension: every screen was covered at every width in one state, and in every
state at one width.

**Fixed, and one of them is worth the line it took.** The calculator's figure
now shrinks rather than truncating — `FittedBox(fit: BoxFit.scaleDown)`, the
same thing the card face does with a long card number. An ellipsized money
amount is a WRONG number; a slightly smaller one is the right one. The label
takes the space it can and the figure keeps its meaning. The other two are the
familiar shape: a trailing element that could not give ground made `Flexible`,
which is now the fourth and fifth time that exact fix has appeared in this
file.

At 360dp after the fixes: **zero overflows.** The 22 failures left are all
reachability — tests tapping what is now below the fold.

**And then the surface was put back.** `pumpScreen` is 800dp again, and that
is now a decision rather than an inheritance:

* moving it costs 22 tests learning to scroll, and this file has a whole entry
  on how that failure mode reads as something else entirely;
* the benefit was the three defects — and those are already fixed, without
  moving it.

What replaced the move is `test/screens/driven_state_test.dart`: the three
states that broke, at the four widths and scales that broke them, twelve
cases. The cheap half of the experiment, kept. It is three states rather than
a policy, and a fourth belongs there rather than in a wider surface change.

**Checked for teeth**, because a file written to guard three fixes is exactly
the kind that could guard nothing:

| Mutation | Result |
| --- | --- |
| Put the calculator's result row back as a plain `Row` | fails — 76 pixels |
| Drop the `Flexible` from the calendar's entry row | fails — 150 and 190 pixels |

The honest summary of the decision: the 800dp surface was hiding three
defects, they are fixed, the surface stays, and what stops the next one is a
file that names the states rather than a number that names a width.

### The privacy policy, generated rather than written twice

Play requires a policy at a public URL, and the first draft of one was written
from the source rather than from a template — the three hosts out of
`price_providers.dart`, the request contents off the `Uri.https` calls, the
permissions off the merged manifest. Then it was compared against what Play
and the two privacy regimes this app lives under actually ask for, and the
comparison found a requirement the draft did not meet at all.

**Play requires the policy to be reachable from INSIDE the app, not only from
the store listing.** It accepts a link or the text. There was no privacy row
in Settings.

The rest of the comparison, against Play's own page, the GDPR's Article 13
list and the KVKK's aydınlatma requirements:

| Missing | Required by |
| --- | --- |
| The controller's identity | KVKK's first listed element; GDPR Art. 13(1)(a) |
| A legal basis for processing | GDPR Art. 13(1)(c) |
| Data subject rights, and the right to complain to a supervisory authority | GDPR; KVKK Art. 11 |
| International transfers | all three price providers are outside Turkey |
| Retention, third-party policies, an explicit "no tracking, no cookies, no ads" | standard, and expected |
| **A Turkish version** | a Turkish-first app under the KVKK |

All of it is in now, in both languages.

**And the shape it is in matters more than the words.** Play treats a policy
that says something untrue as a policy violation rather than a typo, and the
requirement above means two copies of a legal document that must never
contradict each other — the exact arrangement this file refuses everywhere
else. So:

* `lib/legal/privacy_policy.dart` holds the text, in English and Turkish, as
  structured sections rather than a blob;
* `lib/screens/privacy_screen.dart` renders it, reached from Settings;
* `tool/emit_privacy_pages.dart` generates `docs/privacy.html` and
  `docs/gizlilik.html`;
* `test/privacy_pages_test.dart` fails if the committed pages have drifted
  from the source, if one language has a section the other does not, or if
  the number of blocks in a section differs between them.

**The in-app copy is the TEXT, not a link**, and that is the decision worth
recording. A link would have meant adding `url_launcher` and a fourth URL to a
codebase whose README invites the reader to run `grep -rn "Uri.https" lib/`
and count three. The requirement would have been met by making the app's
central claim harder to check. Rendering the text meets it, works with no
network — which for a policy that opens by saying the app does not need one is
the difference between a claim and a demonstration — and leaves the grep at
three.

**One test in that file is not about the document at all.** It reads every
`Uri.https` host out of `lib/` and requires the set to be exactly the three
the policy names, in both languages. A fourth host added to the app fails the
build before the policy can become false. That is the same instinct as the
parity generators: the claim is checked against the thing it describes, not
against a memory of it.

The Settings row cost two chevrons in `settings_screen_test.dart`, which
counts what the screen offers to go to. Four became five and five became six,
and that test failing was the correct outcome rather than an inconvenience —
it is the file that would notice a row appearing by accident.

The new screen went into `route_sweep_test.dart` with the rest, and passes at
320dp and 2.0x like everything else.

### The Data safety declaration, decided by listening to the wire

Play's Data safety form has to be re-confirmed at every release and a false
answer is a policy violation rather than a correction, so it was worth getting
right rather than getting done.

**The first attempt at it was wrong, and the argument that corrected it came
from the publisher.** Play defines collection as transmitting data off the
device — explicitly *"irrespective of whether data is transmitted to you or a
third-party server"* — so the price requests looked declarable, and the
recommendation was to declare Financial info as collected and shared. The
objection was that the app collects nothing: the user enters their own data,
none of it is gathered for product development or marketing, and a symbol list
is not what Play's "Other financial info" describes, which its own definition
exemplifies as *"user salary or debts"* — amounts attached to a person.

That objection is correct, and over-declaring would have put
**"Financial info · shared"** on the store listing of an app whose entire
argument is that it sends nothing about you. Misleading in the direction
nobody checks.

**So the question was settled by measurement rather than by reading.** A
recording `HttpGet` behind the real screens, driven with real portfolios:

| Profile | Requests |
| --- | --- |
| No holdings at all | **0** |
| Crypto, gold and two currencies | 2 |
| Two share holdings, no API key | **0** |
| The same, with a key | 1 |

```
api.coingecko.com   ?ids=bitcoin,pax-gold&vs_currencies=usd   headers={}
api.frankfurter.dev ?from=TRY&to=EUR,USD                      headers={}
www.nosyapi.com     ?code=GARAN,THYAO                         headers={X-NSYP: the user's own key}
```

**The finding that decides it: two different profiles holding bitcoin send
byte-identical requests.** Different account, different amounts, different
name on the holding — the same bytes. The two keyless calls carry no headers
at all. There is nothing in a request that could distinguish one person from
another, which is Play's own description of data *fully de-associated from
individual users*.

Three structural facts came out of the same audit and are worth having
written down: `price_providers.dart` is the only file in `lib/` that touches
`HttpClient` and `assets_screen.dart:140` is its only caller; the app's
manifest declares **zero** `service`, `receiver` and `provider` elements, so
it cannot run when it is not open; and none of the 14 direct dependencies —
nor anything in the resolved graph — is analytics, crash reporting or
advertising.

**The answer is "no data collected, no data shared".**

**One near-miss, recorded because it is the kind that gets published.** The
first audit run gave a gold holding the code `GC=F` and CoinGecko was asked
only for `bitcoin` — which read as a defect in gold pricing. It was the test's
fault: `GC=F` is a Yahoo ticker and the app's internal gold codes are `GRAM`,
`ALTIN`, `XAU` and the four coin forms. With `GRAM` the request is
`ids=bitcoin,pax-gold` as designed. A wrong fixture that produces a
plausible-looking defect is worse than one that crashes.

**What keeps the declaration true.** `test/wire_shape_test.dart` pins every
string above, and fails if a header is added, a query parameter is added, a
fourth host appears, a request fires with no holdings, or two profiles stop
sending the same bytes. Checked by mutation:

| Mutation | Result |
| --- | --- |
| Add a `User-Agent` to the keyless calls | fails, naming the host |
| Add `client=archlence-9f2a` to the CoinGecko query | fails, printing both strings |

It found one thing about itself on the way, which is why the file says so in
place: pumping a second profile's screen after the first reused the element
tree, `initState` did not run again, and the second profile made no request at
all — a green comparison between one set of requests and nothing. The tree is
torn down between them now.

`docs/data-safety.md` holds the answers, the evidence and a three-step check
to run at each release: run those two test files, and if they pass, re-confirm
the form unchanged. The judgement in it belongs to whoever signs the
declaration; what the tests guarantee is that the facts it was made from are
still the facts.

### The TalkBack hour, and what the tooling gets wrong

This was the last item on the list that "needs a person with TalkBack on
rather than another test", and it was done with TalkBack genuinely running:
`com.google.android.marvin.talkback` enabled through `settings put secure`,
the release build installed, and the green focus rectangle measured out of
screenshots to see where focus actually landed.

**Two defects, and two false alarms.** The false alarms are the more useful
half, because both came from trusting the wrong instrument.

#### The header was read last, on every tab

`Scaffold(extendBodyBehindAppBar: true)` lays the body out FIRST — it sits
behind the header — and semantics traversal follows layout order. So a screen
reader read the search box, the balances and the subscriptions block, and
only then said "Archlence". On all five tabs.

**No guideline checks reading order.** `accessibility_test.dart` and the three
sweeps read the tree for labels, sizes and contrast; a screen that announces
everything correctly in a senseless sequence passes every one of them. That is
exactly what this file has said for months about the TalkBack hour, and it
turned out to be true in the most literal way.

`Semantics(sortKey: OrdinalSortKey(...))` on the header, body, action button
and tab bar puts it back. Verified on the device: `Archlence` first, then the
body, then `Record a transaction`, then the five tabs.

#### The notifications bell was a button with no name

An `IconButton` with `onPressed: null` and no tooltip, in the app bar, for a
feature that does not exist. In the semantics tree it is a BUTTON with an
empty label, which a screen reader announces as an unnamed disabled control.
`labeledTapTargetGuideline` does not catch it — a disabled button is not a tap
target — and neither did `icon_button_tooltip_test.dart`, which exempts
`onPressed: null` for exactly that reason.

It is behind `showUnbuiltFeatures` now, like every other unbuilt thing. It had
simply been missed when the rest were removed. A `SizedBox` of the same width
keeps the title centred.

#### The first false alarm: "no text field has a label"

`uiautomator dump` showed every `EditText` in the app with `content-desc=""`,
no text, and Android's own `NAF="true"` — *Not Accessibility Friendly*. That
looked conclusive, and it was reported as a systematic defect affecting every
field in the app.

It is wrong. Reading Flutter's own semantics tree instead shows the labels are
there: `"Search accounts, categories, notes"`, `"Name / Salary account"`,
`"Opening balance"`. Flutter puts a text field's label in the Android node's
`hintText`, **uiautomator does not dump that attribute, and its NAF heuristic
is computed without it.**

**`uiautomator dump` is not what a screen reader hears.** It is a good map of
what exists and a bad witness for what is announced. The instrument for that
is `tester.semantics` in a widget test, or TalkBack itself on a device.

#### The second false alarm: "the Add card button is unreachable"

The tree showed the whole Cards body as one merged node with `+  ADD` buried
in its text, and no separate node for the button anywhere in the XML. It was
reported as: a screen reader user cannot add a card.

Then the button was tapped, and the sheet opened. The merged node was the
summary region above it, not the button. Two wrong calls in one session, both
from reading a dump as if it were speech.

#### And the test that said the fix had not worked

`reading_order_test.dart` pins the new order. Its first draft walked the tree
with `visitChildren` and reported the header still at index 5 — while the
device, with the fix installed, read it first. `visitChildren` returns
INSERTION order; sort keys are applied when the update is compiled for the
platform. Flutter has a public API for the real thing,
`tester.semantics.simulatedAccessibilityTraversal()`, and with it the test
agrees with the device.

Three instruments, three different answers, and only the device was right
every time. Checked for teeth: take the sort keys out and the header goes back
to index 5, named in the failure.

#### What the hour could not check, and still cannot

Whether the labels are any GOOD to listen to. "Total Balance / 0,00 ₺ / Net
Worth / Cash / 0,00 ₺ / Card Debt / 0,00 ₺" is one announcement, correct and
complete, and read aloud it is a run-on sentence with the caption for one
figure sitting between two others. Nothing here can tell you that; it needs
ears, and a Turkish speaker's ears for the Turkish half. That part of the hour
is still open and still belongs to a person.

### Label quality, which is the half a guideline cannot reach

The TalkBack entry above ended by saying what was still open: whether the
labels are any GOOD to listen to. Every announcement in the app was dumped in
order, in both languages, and read as speech rather than as text. Five things
came out of it.

**The biggest was not a label at all — it was the size of one.** The Assets
tab was a SINGLE announcement: about sixty words carrying twelve figures and
a three-sentence explainer, in one breath, with no way to step inside it or
hear one part again. Cards was the same. A sighted reader takes a card in at
a glance; a listener had to take the whole screen.

`AppCard` is a `Semantics(container: true)` now — one change, because every
card in the app is that widget. Assets went from one utterance to nine.

**Then the residue, which only a device showed.** Splitting the cards left a
node spanning the whole scroll body, labelled with the text that was NOT in
any card — the section heading and the pricing explainer — and **announced
before everything it contained**. Three sentences of explanation arriving
ahead of the figures they explain is the worst order available. Loose text in
a scroll body merges upward; making the heading and the explainer containers
took them out of that node, and with no label left the node disappeared from
the traversal entirely.

Measured on the device, because a widget test cannot see it: `SemanticsNode.rect`
is local, so every node reports `y=0` and the order cannot be checked against
the screen. The device dump carries real coordinates, and after the fix the
Assets tab reads in strictly increasing vertical order — 173, 325, 441, 630,
861, 1212, 1449, 1685, 2073, then the action and the tabs.

**The balance ring said its caption after its figure.** On screen "Net Worth"
sits under the number, which is right; read aloud it landed after the amount
and immediately before an unrelated one, so a listener heard "Net Worth, Cash"
as a pair. It is one composed label now — `Net worth 19.769,25 ₺` — with the
three separate texts inside excluded. Home reads as three clean sentences:
the ring, then Cash, then Card Debt.

**Three smaller ones.**

| | Was | Is |
| --- | --- | --- |
| `assetsHoldingCount` | "1 holdings" | an ICU plural; Turkish was already right |
| The masked card number | sixteen bullets, read as sixteen words or as nothing | `semanticsLabel`: "Card ending 0000" |
| The card face's "Archlence" | the app's name announced twice on one screen | `ExcludeSemantics` — it is the brand printed on the plastic |

**Two things were left alone, deliberately.**

`%95,15` in the English build reads aloud as "percent ninety five comma
fifteen". The decision that numbers do not move with the language is recorded
above and its reasoning holds — switching separators with labels would make
one balance read as two amounts — but it was made without the speech case in
front of it. Recorded here so that if it is ever revisited, it is revisited
knowingly.

And `Tab 1 of 5` / `Sekme 1 / 5` is Flutter's own `MaterialLocalizations`,
not this app's string. The Turkish slash may well read as "bölü". It is not
ours to fix and it is worth knowing before someone goes looking for it in the
ARB files.

**What is still open, and now genuinely needs ears.** Everything above was
found by reading announcements as text. Whether the Turkish ones are
pronounced correctly — a lira sign, a date, a decimal comma, an all-caps
heading — depends on the TTS engine on the phone, and no dump can answer it.
That is the last piece of the accessibility work and it needs a person
listening, in Turkish.

### The Turkish was in the wrong register, and nothing here could have said so

`v1.0.0` was published and then deleted, because of the Turkish.

**Every string that addressed the user was in the informal second person.**
`sen`: "Hesapların, kartların… bütçen", "kaybedersen", "bir tane ekle",
"Archlence'i kullanmaya başla". English has one "you" and no choice to make.
Turkish makes you choose, and for an app that holds somebody's money the
familiar form reads as presumptuous — the publisher's word for it was that it
sounded like the app was joking around with you.

**Not one instrument in this project could have caught it.** `l10n_test`
checks that every key exists in both files and that the placeholders match —
both were fine. The sweeps check layout, the guidelines check labels and
contrast, the wire test checks what is sent. A translation can be complete,
accurate, correctly placeheld, and wrong in a way that only a native speaker
reading the screen will name. That is a harder version of the same lesson as
the TalkBack hour, and it is the reason the release was pulled rather than
patched later.

**57 of the 478 strings were rewritten.** 286 are single-word labels — nouns,
untouched. Of the 192 that are sentences, the ones addressing the user moved
to `siz`, and the ones already impersonal were left exactly as they were:
`assetsLivePricingNote`, `errNotAnAmount`, `backupFileUnusable` and their kind
never had the problem.

Two changes beyond the register:

* **Tone.** "Yani yedekler **sana kalmış**" — the `-mış` suffix adds hearsay,
  which is a strange thing for an app to do about its own behaviour; now
  "Yani yedek almak size kalıyor". And `toolsSubtitle`'s "**keşfet**" was
  marketing language where the English said "explore"; "inceleyin" is what a
  Turkish app says.
* **One title out of line.** Every sheet title is a noun phrase — "Yeni
  hesap", "Yeni varlık", "Yeni bütçe kalemi" — except `payDebtTitle`, which
  was the imperative "{card} borcunu öde". It is "{card} borç ödemesi" now.

**Button labels were deliberately NOT changed.** "Kaydet", "Öde", "Ekle",
"Hedefi oluştur". A Turkish button carries the short imperative; "Kaydedin" on
a button reads as artificial. The polite form belongs in sentences addressed
to the reader, not on controls. A scan for informal endings flags all 18 of
them, which is why the scan is a starting point and not the answer.

**And a default that stuttered.** The onboarding prefill for the first account
was `Nakit`, and the account type beside it is `Nakit / Vadesiz` — so every new
Turkish user got a row that reads "Nakit, Nakit, Vadesiz". It is `Cüzdan` now.
The English had the identical defect — `Cash` against `Cash / Checking` — and
is `Wallet`.

### The button that was the whole screen

Fixing the Cards tab's remaining announcement blob turned up a root cause
worth more than the fix.

After the cards were split into their own containers, one node still spanned
the Cards body — `[0,325][1080,1454]`, 1080x1129 — **tappable, and labelled
`+  EKLE`**. Wrapping the section headings took the headings out of it, and the
button was still there.

`InkWell` does not create a semantics node. It adds a tap ACTION to the
nearest one. `GradientButton` is an `InkWell` around a `Text`, so it had no
node of its own and merged upward, taking its label with it and turning the
entire scroll body into one tappable region announced before everything it
contained.

`Semantics(container: true, button: true, label:, enabled:)` gives it a
boundary and a role — and because `GradientButton` is the app's shared primary
action, that one change fixed **every** primary button in the app: every
sheet's save, add, pay and create. Cards now reads as nine items in visual
order, with `+  EKLE` a 274x137 button where the button is.

The general shape, now seen three times in three different widgets: **a
tappable ancestor with no semantics boundary absorbs everything beneath it.**
`AppCard` needed `container`, the loose section headings needed `container`,
and `GradientButton` needed `container` and `button`. None of it is visible in
the source; all of it is obvious in a device dump.

### The permission a release build did not have

Found while checking this file's own claims, not by running anything — which
is the only reason it is written down before a device found it instead.

`android/app/src/main/AndroidManifest.xml` declared NO permissions. The
Flutter template puts `android.permission.INTERNET` in the `debug` and
`profile` manifests only, and the comment there says why: the tool needs it
for hot reload. It is not there for the app. So the release manifest — the
one that becomes the APK a person installs — had no internet permission at
all, while `price_providers.dart` calls CoinGecko and Frankfurter through
`dart:io`'s `HttpClient`, which Android refuses without it.

**What makes it worth a section rather than a line.** It fails silently, in
the exact shape a correct offline phone fails:

    try {
      payload = jsonDecode(await get(uri));
    } on Object {
      return const {};
    }

That `on Object` is deliberate and stays — `price_providers.dart`'s contract
is that a provider gap is an absent key, never a throw. `LivePriceService`
then falls back to `asset_price_cache`, which on a fresh install is empty, so
every holding reads `Cost`. No error, no banner, nothing red. The feature
built in "Price fetching" would have been off in the only configuration that
ships, and on in every configuration it was developed and tested in.

**Why no test could have caught it.** Every test in that piece drives the
providers through the `HttpGet` seam, so no socket has ever opened from this
app — a good decision, and this is its blind spot. The manifest is not a file
any Dart test reads, and the debug APK the device tests run against carries
the permission from `src/debug/`. Green everywhere, broken where it counts.

**The fix** is the one line, in `src/main/` where it belongs, with the reason
above it so it is not tidied away as duplication of the debug manifest. The
two template manifests are left alone: the merger de-duplicates, and editing
files the template owns to make a point is how the next `flutter create`
diff becomes unreadable.

The comment above it was written twice. The first version used ` -- ` as a
dash, and XML forbids `--` inside a comment: it would have failed the build
at `aapt2`, in the one file no test parses, to explain a bug in the one file
no test parses. Caught by running an XML parser over the manifest rather than
by rereading it, which is worth keeping as the habit: every file this
project edits by hand has a parser somewhere that will answer for free.

**Half of it is verified now, and the half that is was verified without a
keystore.** This section was written on a branch and said the whole check
needed a release build, which needed the keystore, which does not exist. That
was one step too pessimistic: the manifest MERGER is a Gradle task of its own,
and `./gradlew :app:processReleaseMainManifest` runs it for the release
variant without going anywhere near packaging or signing. Its output at
`build/app/intermediates/merged_manifest/release/` now lists
`android.permission.INTERNET` beside the two biometric ones. The release
manifest gets the permission — that is no longer an argument from the
platform's documentation, it is Gradle's own answer.

**What is still NOT verified is the behaviour,** and this file does not get to
claim it: a release APK on a device, Assets open, a crypto holding reading
`Current` rather than `Cost`. That needs the keystore, and it is the extra
thing making the keystore buys — see "The one thing left".

The correction is the same shape as R8's: the branch reasoned that because the
END of the check needed a keystore, all of it did. A build pipeline is a
series of tasks and most of them can be asked on their own.

### The device pass, and the four things only a device could see

Open work item 1 was "what a device has still not answered". It has been
answered, and the answer cost four defects — none of which was visible in the
source, which is now the fifth time this file has had to write that sentence.

**Live pricing has a socket behind it at last.** Until
`integration_test/live_price_device_test.dart` existed, NO HTTP REQUEST HAD
EVER LEFT THIS APP. Every test drives the providers through the `HttpGet`
seam, which is the right seam and was also the blind spot that hid the missing
INTERNET permission for as long as it hid. Both providers answer, both parsers
read what came back, and a holding on the emulator read `37.608,30 ₺` against
a figure of `37.624` worked out by hand from the two rates. The Frankfurter
test asserts the DIRECTION as well as the value: one dollar has to read as
MORE than one lira, because "positive" passes just as happily on the
un-inverted rate. Both halves proven by mutation.

**The version string was hard-coded.** `pubspec.yaml` had been moved to
`1.0.0` and Settings went on drawing `Archlence v0.1.0` from a literal in the
widget — so the store listing and the app itself would have disagreed about
what was installed. No test could have caught it: one written the obvious way
asserts the same stale literal back. It reads `lib/app_version.dart` now, and
`test/app_version_test.dart` reads `pubspec.yaml`.

That test's second half was decoration on its first draft, and worth recording
because the mistake is subtle. It scanned `lib/` for a hard-coded version with
a pattern that put the quote immediately before the digits. The string it
existed to catch is `'Archlence v1.0.0'`, where the quote is nowhere near
them. It passed the exact mutation it was written for. The pattern is two now,
and both were checked against `lib/` before being trusted.

**No passphrase field was obscured.** All six on the backup screen typed in
the clear. This project's own rule, written down for the shares API key, is
that a displayed credential is one a shoulder can read — and `obscureText`
appeared nowhere in the app. They are obscured now with a deliberate reveal,
because a passphrase here CANNOT BE RECOVERED and a typo nobody can see is a
package that never opens again. `autocorrect` and `enableSuggestions` go off
with them, and not as tidiness: a keyboard dictionary LEARNS what is typed
into it, which would put the passphrase somewhere this app neither controls
nor can clear.

**And a 176-pixel overflow on a 360dp phone, which this session revealed
rather than caused.** The subscriptions heading on Home had never been wrapped
and had been overflowing since it was written. `wide_layout_test` walks that
screen at 360x800 and passed every time, because a `ListView` lays out only
what is near the viewport and the two cards removed below (see the next
section) had been pushing that row past the cache extent. Nothing had ever
laid it out. Anyone who scrolled saw it.

That is the same lesson as "a finder matching is not a user reaching", from
the other side: there, a test tapped something that was in the tree and off
screen. Here, a test walked a screen and never reached the defect on it. **A
layout test only sees what gets laid out**, and what gets laid out depends on
what is above it.

### Not drawn rather than marked — `showUnbuiltFeatures`

**This reverses a decision made deliberately, so the reasoning replaces it
rather than sitting beside it.** Every unbuilt control used to be drawn with a
`NOT YET` chip, on the argument that saying so is more honest than hiding it.

Running the app on a device is what changed the argument. Settings showed FOUR
of them in a single screenful, Home drew a forecast card whose entire content
was a chip saying it did not exist — directly under the balance ring, the
first thing a new user sees — and Tools dimmed two of its seven cards. Seven
Settings rows in total, across three section headings that existed for nothing
else.

**The distinction the chip's rule actually rests on:** it is about a control
that EXISTS and is inert in some state. A Pay Debt button on a card that owes
nothing; an export that needs a passphrase first. Marking those is honest,
because the user can reach them by changing something. A row for a feature
that has never been built is not that. It is an advertisement for an absence,
and "Change Password — NOT YET" tells a reader nothing they can act on.

Two of them said something worse than nothing. **`Sign Out`, in an app whose
whole premise is that there is no account**, and `Dark Mode`, in an app with
no other theme to leave. Both were mockup carried forward.

The code stays, behind one constant. Exactly one chip is left in Settings —
Backup & Restore with no profile behind it — which is the case the rule was
written for. Flip `showUnbuiltFeatures` to see the rest again; the screen
tests are pinned to the constant rather than to the count, so they follow it.

### The backup reminder — `lib/services/backup_reminder.dart`

The largest structural gap in the app, and it was never a defect in anything:
no account and no server means nobody else holds a copy, so a lost phone is a
lost financial history. Onboarding says exactly that in its third card — at
the one moment the user has nothing to lose yet — and nothing said it again.
Every competitor's cloud sync is a safety net this app deliberately does not
have, which makes "your data is yours" a principle only if the app helps
someone act on it, and a trap otherwise.

Settings now says how long ago; Home says something once there is something to
lose AND a month has passed. Both conditions, because a reminder on an empty
install is a nag about nothing and one that appears weekly is one a user
learns not to read.

Kept in the platform secure store beside the screen-lock and language
preferences rather than in `finance.db`, for the reason `screen_lock.dart`
gives at length — the schema is a contract shared with the desktop. It also
means a RESTORED backup does not bring a stale timestamp with it, which is
right: the reminder is about this phone.

Eight tests, and the interesting ones are the wrong answers: a clock that
moved backwards reads as today rather than as a negative age; a value that
will not parse reads as never; a store that throws reads as never rather than
taking a screen down; and a store that throws during `recordBackup` does not
fail the backup that already succeeded.

### The licence, and the page that shows it

There was no `LICENSE` file at all, which means all rights reserved — nobody
could legally use, fork or contribute, and the repository was about to be
linked from a store listing.

**Apache-2.0**, and the desktop app moved with it rather than the two halves
carrying different licences. Both are permissive and OSI-approved, so this is
not a change in how free the project is; Apache gives downstream MORE than MIT
does. Two clauses are the reason: §3 grants a patent licence explicitly where
MIT is silent, and §6 states that the licence does not hand over the name.
Neither stops anyone forking this — both allow that deliberately, and the only
lever against a store clone is trademark rather than a code licence.

**The one real cost, named rather than glossed:** Apache-2.0 cannot be
combined into a GPLv2-only project, where MIT can. It is compatible with
GPLv3. For a Flutter Android app that set is empty in practice, but it is the
honest answer to "does this narrow anything".

Desktop releases up to v1.0.1 stay MIT. Relicensing is not retroactive and
withdraws no right anyone already holds, which is recorded in `NOTICE` —
because `NOTICE` is the file Apache requires downstream to carry, so it says
it where it cannot be lost.

**And it is visible in the app**, under Settings → About, through Flutter's
own licence page. Written twice: the first version also registered this app's
own licence by hand, on the assumption that the page only knows about
packages. Opening it showed the app listed TWICE under two names — Flutter
picks the root package's `LICENSE` up without being asked. The hand-written
half is gone and the comment says why, so nobody adds it back. One more entry
in the long list of things this file records because running it was the only
way to find out.

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

- Holdings were shown AT COST and said so, because when this was written there
  was no price feed: the mockup's "Current" column, its
  `+7.858,53 ₺ (+1.52%) Today` chip and its "Last updated: 23:00" line were
  all figures that did not exist, and a cost basis presented as a market value
  is a lie the user cannot see through. **Since then the price layer arrived**
  — see "Price fetching" and "Shares, on the user's own key". Crypto, gold and
  currency now carry a live price and the time it was got; shares do unless no
  BIST key is set, and each tile says which of the two it is showing. The rule
  did not change, only the number of holdings it applies to.
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
batch fetch, the warm-up thread — is NOT ported as the desktop wrote it, and
did not need to be to reach it: `calculatePnl` took a current price as a
plain argument from the start, and "Price fetching" further down builds what
supplies one, on its own terms rather than a straight port of this file's
other half.

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

### 1. Getting it into the Play Store

**Every engineering item in this section is done, and one of them came
undone.** No code work stands between this app and a submission — but the
keystore that signs the submission was lost with the machine it lived on, so
nothing can be uploaded until that is settled. It is a credential problem, not
an engineering one, and it is the first thing to pick up.

- **The keystore, again.** The one that signed `v1.0.0` is gone; a
  replacement has been made and a signed 62.0MB bundle built with it. What is
  NOT done is Play's side — two questions in the console decide whether this
  certificate can be adopted — and **a backup of the new keystore somewhere
  that is not this machine**, which is the whole reason the last one had to be
  replaced. See "The key that was on the other machine".
- ~~**An App Bundle, not an APK.**~~ Done. `flutter build appbundle --release`
  built first try, 66.7MB, signed by the release key — verified with
  `jarsigner` rather than assumed. And it answered the 65MB question by
  measurement: `bundletool get-size` puts what a device actually downloads at
  10.6–11.2MB depending on ABI. See "The first App Bundle".
- ~~**The keystore itself.**~~ Was done, by hand, outside the repository —
  and outside any backup. See the item above.
- ~~**Install that release build and confirm a price arrives.**~~ Done. The
  release APK was installed on a clean emulator and driven by hand through
  onboarding, an account, an income and a Bitcoin purchase; the holding read
  `Current` 188.480,46 ₺ against a cost of 50.000,00 ₺, priced through
  CoinGecko and Frankfurter with R8 on and the release manifest under it.
  `dumpsys package` confirms the INSTALLED package carries
  `android.permission.INTERNET`, which until now had only been read out of the
  manifest merger. See "The first App Bundle".
- ~~**An hour with TalkBack on.**~~ Done, with TalkBack genuinely running on
  a device. It found the two things no guideline reads: the header was
  announced AFTER the whole screen on every tab, and the notifications bell
  was a button with no name. Both fixed and pinned. What is still open out of
  that hour is label QUALITY — whether the announcements are good to listen
  to — which needs ears, and Turkish ears for the Turkish half. See "The
  TalkBack hour, and what the tooling gets wrong".
- ~~**Label quality.**~~ Done too. The Assets tab was a single sixty-word
  announcement; it is nine now, in visual order. The balance ring said its
  caption after its figure. "1 holdings", a card number read as sixteen
  bullets, and the app's name announced twice on one screen are all fixed.
  See "Label quality, which is the half a guideline cannot reach". What is
  left of it needs ears rather than eyes: whether the Turkish is PRONOUNCED
  correctly by the phone's TTS, which no dump can answer.

Not engineering. **The privacy policy is done**, in both languages, generated
from the app's own copy of the text and reachable from inside the app as Play
requires — see "The privacy policy, generated rather than written twice".

**Play's Data safety form is answered** — "no data collected, no data shared",
decided by recording what the app actually puts on the wire rather than by
reading the definitions. `docs/data-safety.md` holds the answers, the evidence
and the check to run at each release; `test/wire_shape_test.dart` fails if any
of the evidence stops being true. The judgement belongs to whoever signs it;
see "The Data safety declaration, decided by listening to the wire".

Worth doing first rather than last: open the developer account. A new personal
account may face a closed-testing period before production access, which moves
a launch date by weeks rather than days — so it is the item that sets the
schedule, and it can run while everything else is finished.

### 2. Judgement rather than engineering



* **Anything to do with more than one user or device.** Untouched, and the
  app's whole shape argues against it — "no account, no server".
* **The rest of accessibility.** A first pass is done — see "The accessibility
  pass". What it cannot see is reading order, label quality and large font
  scales, and those need a person with TalkBack on rather than another test.
  An hour before launch.
* **A real tablet layout.** Wide screens no longer stretch — see "Wide
  screens" — but nothing uses the space: no second pane, no `NavigationRail`.
  That is a design decision, and it should be made by someone looking at a
  tablet rather than inferred from a breakpoint table.
* **Crash visibility.** There is no telemetry, by decision, and that means no
  way to learn about a data-corrupting bug except a one-star review. Play
  Console's Android vitals reports crashes and ANRs with no SDK and no code —
  the app never phones anywhere, the platform reports — so it costs nothing
  against the "no server of ours" promise. Turn it on and read it.

### What is NOT coming from the desktop

For the avoidance of re-deriving this each session. **This list used to open
by claiming the desktop's `services/` was fully accounted for, and it was
not.** Six modules were neither ported nor named here: `search_service`,
`calendar_service`, `dashboard_period_service`, `financial_summary_service`,
`history_service` and `queries`. The first four are items 1-5 of "Pick up
here"; `history_service` has its own entry below; and
`queries.py` is a 77-line helper whose only mobile-relevant call,
`get_categories`, already lives in `TransactionService.getCategories`.

The lesson is the same one R8 taught two entries above: an absence is not
evidence. Nothing had checked this list AGAINST `ls services/`, so the six
that were never mentioned looked exactly like the ones that had been
considered and dismissed.

What has not been ported is not forgotten:

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
  Answered rather than ported, and the distinction matters: this app has a
  `price_providers.dart` and a `price_guard.dart` of its own, sharing the
  names and the "one broken symbol does not sink the batch" rule and nothing
  else — the desktop's are built on `yfinance` and a spawned subprocess,
  neither of which exists on Android. See "Prices come from the phone, from
  keyless sources", "Price fetching" and "Shares, on the user's own key".
  `crypto_top100` is genuinely not ported and not missed. Nor are
  `brand_icon_service` and `logo_service` — and those two are a decision
  rather than an oversight: both fetch a logo per holding from the network,
  which is a request per symbol to somebody else's server for decoration.
- **Backup service.** Ported. `key_recovery_service.py` is the exception —
  see "What the backup work did NOT port".
- **`history_service`.** The "time machine": the balance at any past date,
  `diff_between`, and event attribution by source. Out of 1.0 by size rather
  than by principle — 321 lines, two tables whose write behaviour would have
  to be matched exactly.

  **One question out of it IS ported**, because the change chip needed it:
  what the accounts held at the end of a given day, in
  `lib/services/balance_history.dart`. It derives backwards from the current
  balance instead of replaying forwards from a snapshot, which is why
  `daily_balance_snapshot` still has nothing writing it. See "The change chip,
  and the balance at a past day".
- **`background_task_manager`.** Flutter has its own answer; the desktop's
  thread pool does not port.

## Environment

Set up on this machine and verified working. **The machine changed again, and
this time it is a different machine rather than a different system on the same
one** — a Windows 11 laptop, where the last three setups were all the desktop.
It is this project's fourth from-scratch toolchain and its second Windows. The
checkout is back under `OneDrive\Documents\archlence-mobile`, which the
"Environment" section used to blame for the suite's speed and no longer does;
see "What the suite costs".

The machine: AMD Ryzen 7 260, 8 cores and 16 threads, 31GB of RAM, a WD PC
SN5000S NVMe disk, a Radeon 780M integrated GPU beside an NVIDIA RTX 5060
Laptop, Windows 11 Pro 25H2 (build 26200). It is a laptop, and the suite's
clock says so: the CPU is the measurement, exactly as the last section
predicted it would be.

**Nothing was installed as Administrator.** The whole toolchain lives under
`C:\src`, no MSI and no `winget` package touched Program Files, and the
environment variables are user-scope registry values rather than machine ones.
Same reasoning as the `~/dev` layout on the last machine: a toolchain owned by
the user is one that can be replaced or thrown away without touching the
system.

- JDK 17.0.20.1 LTS — Microsoft Build of OpenJDK, the **zip** rather than the
  MSI, unpacked to `C:\src\jdk-17`, SHA-256 checked against Microsoft's own
  `.sha256sum.txt` —
  `3d9006956fc8af5601cd24ffc4f468bef48279c7ebd8171b9bdf90d0aabfbf1f`. The same
  version the CachyOS setup ran, and **not** a newer JDK, for the reasons that
  setup gives: AGP 9.1.0 and Kotlin 2.4.0 in `android/` were proven against 17.
- Flutter 3.47.2 stable at `C:\src\flutter`. It was already here and did not
  have to be fetched; it is the same version and the same channel the last two
  setups ran, so nothing in `pubspec.lock` moved on arrival.
- Android SDK at `C:\src\android-sdk`, installed with `cmdline-tools`' own
  `sdkmanager`: platform-tools 37.0.1, platforms 35 and 36, build-tools 36.0.0,
  emulator 37.1.11, and `system-images;android-35;google_apis;x86_64`. Gradle
  then added `platforms;android-37.0`, `ndk;28.2.13676358` and `cmake;3.22.1`
  itself on the first two builds.
- **The command-line tools are deliberately one release behind, and that is
  the finding of this setup rather than a preference.** `cmdline-tools` 23.0.0
  (build 16111833, the current "latest") retires `sdkmanager` and forwards
  every call to a new `android` CLI which does not understand `;`-separated
  package names. AGP asks for the NDK by exactly that syntax, so the first
  Android build died with `NTSTATUS 0xC0000409` out of a tool nobody typed.
  22.0 (build 15859902) still is the real `sdkmanager`, and is what
  `cmdline-tools\latest` holds; 23.0.0 is kept beside it as
  `cmdline-tools\23.0.0-deprecated-sdkmanager` so the next session can see
  what was rejected and why. See "The move to a laptop".
- **Licences are not accepted the way this file used to say.** The Windows
  setup could not pipe `yes` into `sdkmanager --licenses` from PowerShell and
  the CachyOS setup could; on this machine the question dissolved, because
  both tool generations now answer `--licenses` with *"The --licenses option
  is no longer needed"* and accept at install time instead. `flutter doctor`
  has not caught up and still reports "Android license status unknown" while
  every build downloads and accepts what it needs. It is noise, not a state.
- Environment, set once in `HKCU:\Environment` (no Administrator, no reboot):
  `JAVA_HOME=C:\src\jdk-17`, `ANDROID_HOME` and `ANDROID_SDK_ROOT` both
  `C:\src\android-sdk`, and five `PATH` entries — `C:\src\flutter\bin`,
  `C:\src\jdk-17\bin`, and the SDK's `platform-tools`,
  `cmdline-tools\latest\bin` and `emulator`. **A shell started before that
  write does not have them**, which is the same trap the fish file was, and
  worth knowing before concluding a tool failed to install. Belt and braces,
  `flutter config --android-sdk C:\src\android-sdk` writes the path into
  `~\.flutter_settings`, where it does not depend on any shell's environment.
- Emulator AVD `archlence_pixel` (Pixel 7, Android 15, `google_apis/x86_64`),
  created with `avdmanager` and then edited: `hw.ramSize=4096` against the
  profile's 2G, `hw.keyboard=yes`, and `hw.gpu.enabled=yes` — the `pixel_7`
  device profile ships that last one as `no`, which would have put the whole
  emulator on software rendering. `disk.dataPartition.size` was left at the
  profile's 10G. Start:

  ```
  C:\src\android-sdk\emulator\emulator.exe -avd archlence_pixel -no-snapshot -no-boot-anim
  ```

  No `-gpu` override, and the fourth answer this project has given that
  question is the same as the third. `emulator -accel-check` reports
  **WHPX (10.0.26200) installed and usable** — the Windows hypervisor path,
  where the last machine had KVM. Nothing had to be enabled for it.
- `flutter doctor` reports Chrome and Visual Studio missing. Both are
  **irrelevant** — they are the web and Windows-desktop toolchains and this is
  an Android client. It also reports the Android licence status above.
- **`flutter pub get` needs nothing special here either.** The first Windows
  setup needed a paragraph about symlink support and Developer Mode; that was
  a Flutter-tool requirement which no longer applies to this version, and
  `pub get` ran clean on a machine where Developer Mode was never touched.
- **The two Android settings that depart from the Flutter template are
  unchanged and still load bearing**, and a third joined them here.
  `android/app/build.gradle.kts` pins `compileSdk = 37` rather than taking
  `flutter.compileSdkVersion` (36), because `flutter_secure_storage` 11
  declares 37 in its AAR metadata; `android/gradle.properties` sets
  `android.builtInKotlin=true` where the template ships `false`, because
  `share_plus` 13 stops applying the Kotlin Gradle Plugin on AGP 9. **New:**
  `compileSdkMinor = 0` beside the first of those, because Google no longer
  publishes a bare `android-37` platform. See "The move to a laptop".
- **Building a release needs `android/key.properties` and the keystore it
  names.** The keystore that signed `v1.0.0` was on the previous machine and is
  gone; a replacement lives at `C:\Users\ckrgz\archlence-release.jks` and is in
  no backup yet. `key.properties` points at it with FORWARD slashes, which is
  not a style choice — see "The key that was on the other machine".
- `bundletool` is not part of the SDK install and is not needed for a build.
  1.18.3 was fetched once, as a jar from its GitHub releases, to measure what
  Play would actually deliver from this bundle: `build-apks` then
  `get-size total`. It signs the APK set with the SDK's debug key, which is
  correct here — the measurement is of size, and nothing produced this way is
  installable on anyone's phone.

### What the suite costs, and what it is spent on

The first Windows setup recorded `flutter test` at about ten minutes and
blamed the checkout's location — OneDrive's file sync and the virus scanner —
with `backup_service_test.dart` named as roughly eight of them. **The first
half of that was right and the second half was wrong.** The CachyOS machine
measured it and found a key derivation benchmark; that section ends by
predicting the suite "will be slower on a laptop, and no amount of disk or
filesystem tuning will move it".

This machine is that laptop, and the checkout is back under OneDrive — which
makes it the experiment the two claims disagree about. Measured here:

| Run | Tests | This laptop | The desktop, on Linux |
| --- | --- | --- | --- |
| `flutter test` | 1117 | 7m28s | 4m41s |
| `test/backup_service_test.dart` alone | 23 | 7m18s | 4m35s |
| everything else | 1094 | ~35s | ~25s |
| `flutter analyze` | — | 34.8s | under 10s |

**Both totals are 1.59× the Linux ones**, and they are 1.59× by the same
factor — 182 PBKDF2 derivations at 600 000 rounds, 2.38s each here against
1.50s there. If OneDrive were paying any part of this bill, the full suite
would be inflated more than the single CPU-bound file it contains; it is
inflated by exactly as much. The disk is not in the measurement, on the
machine where it was originally accused.

Ten seconds separate the whole suite from that one file, the same six-to-ten
seconds the last machine saw: `flutter test` runs files in parallel and the
other 1094 finish long before it does. **The suite's wall clock is one file's
key derivation and almost nothing else,** on any machine.

`flutter analyze` is the one number where the checkout's location may show —
34.8s against under 10s, on a difference of CPU that is only 1.59×. It reads
the whole tree rather than deriving keys, so it is the run this file would
look at first if the OneDrive question is ever reopened. It has not been
measured off OneDrive here, and this file does not claim it.

- **The device tests assert ENGLISH strings.** Six of the eight in
  `app_device_test.dart` read UI text, so running them against an emulator
  set to Turkish fails all six at once and reads exactly like the app having
  broken. It happened here, while the emulator was in `tr-TR` to review the
  translation. `adb shell setprop persist.sys.locale en-US` needs a full
  `adb reboot` to take — restarting zygote is not enough.
- **Do not run the emulator and `flutter test` at the same time.** Carried
  over from the Windows setup, where it cost a diagnosis: with the emulator
  up, `backup_service_test.dart` crossed its timeout and the whole file
  reported as "did not complete", which reads exactly like a hang in the code.
  This session kept them serialised on the strength of that finding and did
  not re-test it, and the timings above say why it is plausible — that file is
  CPU-bound for four and a half minutes and an emulator is not a light
  neighbour. Anything that looks like a hang in that file, check what else is
  running first.

**An Android session does not end when the command does.** Three kinds of
process outlive it here, two of them by design:

* **The emulator** — `qemu-system-x86_64`, holding a few GB. `adb -s
  emulator-5554 emu kill` from a shell, or close its window.
* **Gradle's daemons** — JVMs, one Gradle and two Kotlin compile daemons after
  a device-test round, and on Windows that was 4.5GB of idle memory. They
  persist deliberately so the next build does not rebuild a JVM and a
  configuration, and they respawn on their own. Stop them with
  `./gradlew --stop` from `android/`; the Kotlin daemons go with the Gradle
  one. Checked afterwards here rather than assumed: `--stop` reported one
  daemon stopped and nothing was left holding memory.
* **`flutter_tester.exe`, which is not by design.** On this machine one of
  them survived a completed `flutter test` by three quarters of an hour,
  slowly accruing CPU, and the shell that launched the suite was not reported
  as finished until it was killed — with the full result and its own timing
  already printed. See "The move to a laptop". If a finished-looking run will
  not close, look for a tester process before looking for a hang.

Neither of the first two is a leak and neither needs stopping to be correct.
It is worth knowing which is which before concluding the emulator is still up.

Disk, for planning a rebuild: `C:\src\android-sdk` 7.46GB (with the NDK and
CMake that Gradle fetched itself), `C:\src\flutter` 1.35GB, `C:\src\jdk-17`
0.29GB, and `~\.gradle` 5.11GB after four Android builds and a device-test
round. The downloads: 187MB for the JDK zip and 155MB for the command-line
tools — twice, because the current release had to be swapped for the previous
one. Flutter was already on the machine.

Verified on this machine, in this order: `flutter analyze` clean in 34.8s,
1117 unit tests pass in 7m28s, a debug APK builds, and all 14 device tests
pass on `emulator-5554` — four in `key_provider_device_test.dart` against the
real Keystore, eight in `app_device_test.dart` driving the real screens, and
two in `live_price_device_test.dart` against the real network, where CoinGecko
and Frankfurter both answered. The tests themselves take 1m17s; the round
around them is three `assembleDebug` builds at 28.5s, 20.0s and 18.8s, one per
test file, plus an install each. Then `flutter build appbundle --release` was
run to confirm it still fails on the missing keystore rather than signing with
anything, and `./gradlew :app:processReleaseMainManifest` to confirm the
release manifest still carries `android.permission.INTERNET`.

### The parity generators

Regenerating parity vectors needs `pycryptodome` and `platformdirs`, neither
installed system-wide. Python itself IS here and is a real one — the Windows
setup had to work around the Microsoft Store stub first. The desktop checkout
is at `~/Documents/archlence`, and the venv goes in it, which is where each
generator's doc comment already says it goes:

```bash
python3 -m venv aeadvenv
./aeadvenv/bin/pip install pycryptodome platformdirs
```

`bin/` rather than `Scripts\`, which puts the doc comments back to being
literally correct. **And one thing about the OUTPUT goes back too:** Python
opens files in text mode, so a generator run on Windows wrote CRLF where the
same script on Linux writes LF. `.gitattributes` normalised it on the way in
either way, but the regenerated file no longer looks modified when it is not.

**All of which describes the CachyOS machine, and this one is Windows again.**
The desktop checkout is here — `OneDrive\Documents\archlence` — but the venv
paths revert to `Scripts\` and the CRLF question comes back with them, so the
two paragraphs above read as history rather than as instructions until
somebody needs a generator. **Nothing has been regenerated on this machine**
and no vector under `test/` was touched, so nothing in this session rests on
sorting that out first.

Checked rather than reasoned about, on that machine, with pycryptodome 3.23.0:
`emit_summary_vectors.py` run through the desktop's own
`financial_summary_service.py` rewrites `test/summary_vectors.txt` to
`b344021b062d6cac6be18e90daac5a35e4d0d5149dba60cdc54ff373b402dca3` — the
digest it already had — and `git status` on it is empty.

The generators live in `tool/` and are run from the desktop checkout, because
each reads that project's own modules:

| Script | Regenerates |
| --- | --- |
| `tool/emit_backup_vectors.py` | `test/backup_vectors.txt` |
| `tool/emit_backup_package.py` | `test/desktop_backup.archlence-backup` |
| `tool/emit_default_categories.py` | `lib/data/default_categories.dart` |
| `tool/emit_summary_vectors.py` | `test/summary_vectors.txt` |
| `tool/emit_search_folding.py` | `lib/services/search_folding.dart` + `test/search_folding_vectors.txt` |
| `tool/emit_calculator_vectors.py` | `test/calculator_vectors.txt` |
| `tool/emit_period_vectors.py` | `test/period_vectors.txt` |
| `tool/emit_aead_vectors.dart` | the Dart-written AEAD envelopes the desktop reads back |
| `tool/emit_mobile_backup.dart` | a package for the desktop to read back |

The last two run the other way — this app writes, the desktop reads — and are
run by hand, because the assertion lives in the desktop checkout. Each file's
doc comment carries the exact command and the fixed key to check the answer
against. `emit_mobile_backup.dart` goes through `flutter test`, which is the
only runner that has this package's Flutter dependencies.

`keyring` is deliberately absent from `aeadvenv`: without it the desktop's
`create_platform_key_provider` falls back to its file provider, so the key a
generator writes is the key its encryption uses. With a real credential store
reachable — a Secret Service on this machine — it would instead pick up
whatever that store happens to hold for the developer.

Nothing that claims parity is transcribed by hand. A generator kept outside
the repository is a generator that does not exist the next time it is needed.

## Working agreement

Three habits, kept because each has repeatedly caught defects that review did
not.

**Run it, don't just read it.** And a build file is not a build: this file
claimed for several sessions that R8 was off because `isMinifyEnabled` did not
appear in `android/app/build.gradle.kts`, when Flutter's Gradle plugin had
been setting it to `true` the whole time. An absent line is evidence of
nothing. Every screen defect in this file was invisible
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

**`flutter test` does not run the device tests, and one of them rotted.**
`integration_test/` needs `-d <device>` and an emulator, so it sits outside
the command every session runs. `key_provider_device_test.dart` asserted
`status.method == 'Android Keystore'` — a string — and kept asserting it after
i18n turned that field into a `KeyProtectionMethod` enum. It failed from that
day, silently, while this file went on reporting "12 device tests pass" for
months. Run them:

```bash
flutter test integration_test/ -d emulator-5554
```

The same blind spot is what let the screen lock ship broken: the thing no
routine command exercises is the thing that quietly stops working.

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
