# Archlence Mobile — Roadmap

The Android client for [Archlence](https://github.com/superuser-d0/archlence),
rewritten in Flutter. This file is the pick-up point between sessions: what is
done and how it was proven, what is next, and which decisions are settled so
they are not reopened by accident.

Every claim here was verified against the code on `main` before being written.

## Where things stand

**Done:** the toolchain, all five screens, the three layers underneath them
that are hardest to get right — money, encryption, and the database schema —
and the whole service layer on top: accounts, the ledger, holdings (portfolio
CRUD, buying, selling), recurring payments, the monthly budget and savings
goals. Live price fetching is the one piece left out — see open work 3.

**Wired so far:** Home, Cards and Assets read real data, and the Tools grid
launches a budget screen and a savings screen that do too. Settings still
renders literals, and nothing in the app WRITES except the two card switches
on the Cards tab.

429 unit tests and 12 device tests pass. `flutter analyze` is clean, and the
app runs on the emulator.

## Pick up here

In priority order. Each of these is a self-contained next session.

**1. The remaining write flows.** Opening an account, recording a transaction
and buying or selling a holding are done, and the pattern is settled — see
"The write flows" under what is proven. What is left: a budget line, opening
and funding a savings goal, paying card debt, and editing or cancelling a
subscription. Each has a tested service call and no form.

**2. Onboarding and sign-in.** Designed and not built. They gate the whole
app and depend on nothing but the key provider, which is done.

Open work 3 and 4 below (price fetching, backup/i18n/release) are larger and
neither of the above waits on them.

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
batch fetch, the warm-up thread — is NOT ported; see open work 3, which
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

### 1. Write flows

Opening an account, recording a transaction, and buying or selling a holding
are done — see the sections above for the pattern. What is left still has a
tested service call and no form:

| Action | Service call |
| --- | --- |
| Pay card debt | `AccountService.payCreditCardDebt` |
| Add or edit a budget line | `BudgetService.savePlanItem` |
| Open, fund or close a goal | `SavingsService.createGoal` / `depositToGoal` / `withdrawFromGoal` / `deleteGoal` |
| Edit, skip or cancel a subscription | `RecurringService.updateSubscriptionAmount` / `skipNextOccurrence` / `cancelSubscription` |

### 2. Onboarding

Designed in the published mockup canvas and not built. They gate everything
else in the app, and depend on nothing but the key provider, which is done.

### 3. Price fetching — needs a decision

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

### 4. Not yet considered

Backup and restore, i18n (the desktop has `ui/i18n.py` with a full Turkish/
English map; the mobile screens are English-only strings in the widgets, while
the NUMBERS are already Turkish-formatted — see `lib/ui/money_format.dart`),
app icon and launch screen, release signing, Play Store listing.

### What is NOT coming from the desktop

For the avoidance of re-deriving this each session — the desktop's `services/`
is fully accounted for. What has not been ported is not forgotten:

- **Dashboard, insight, projection and metrics services.** They compute the
  Home tab's forecast and health score. Those cards are drawn with a `NOT YET`
  chip rather than invented figures.
- **Migration engines** (`migration_service`, `savings_migration`,
  `crypto_migration_service`, `startup_recovery`). A fresh mobile install has
  nothing to migrate from; these matter only if restoring a desktop backup
  becomes a feature, which is item 4.
- **Price machinery** (`price_service`, `price_providers`, `price_guard`,
  `asset_price_worker`, `crypto_top100`, `brand_icon_service`, `logo_service`).
  Item 3.
- **Backup service.** Item 4.
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
  Start: `emulator -avd archlence_pixel -no-snapshot -gpu swiftshader_indirect`
- `flutter doctor` reports an Android licence warning. It is **cosmetic**: the
  AUR `android` CLI does not emit the output format `flutter doctor` parses.
  The licences are accepted and builds work — the real check is that
  `flutter build apk` succeeds.

Regenerating parity vectors needs `pycryptodome`, which is not installed
system-wide. A venv was used:
`python3 -m venv aeadvenv && ./aeadvenv/bin/pip install pycryptodome`.

## Working agreement

Three habits, kept because each has repeatedly caught defects that review did
not.

**Run it, don't just read it.** Every screen defect in this file was invisible
in the source: the tab scroll offsets, the clipped card name, the floating
button covering a switch, `setState` handed a closure returning a `Future`, a
change chip drawn empty so a green pill with an upward arrow read as a gain,
and `ServicesScope` placed below the Navigator where no pushed route could
reach it.

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
