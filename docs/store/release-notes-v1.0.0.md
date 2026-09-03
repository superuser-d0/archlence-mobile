# v1.0.0 — GitHub Release notes

Paste the section below the line into the release body. Everything above it is
the procedure, kept here so a release is a checklist rather than a memory.

## Before publishing

1. **Build and verify.** Three APKs, one per ABI:

   ```bash
   flutter build apk --release --split-per-abi   # the three per-ABI APKs
   flutter build apk --release                   # and the universal one
   for a in build/app/outputs/flutter-apk/app*release.apk; do
     python3 tool/verify_release_artifact.py "$a" || break
   done
   ```

   Every one must end with *"Signed by the expected release certificate."* An
   APK at `minSdk 24` has no `META-INF` certificate, so the script uses
   `apksigner`, not `keytool` — a check that reads the artifact rather than
   the config that produced it.

2. **Rename and checksum.** GitHub shows the filename to the user, and
   `app-arm64-v8a-release.apk` says nothing about what app or version it is:

   ```bash
   mkdir -p /tmp/archlence-release && cd /tmp/archlence-release
   for abi in arm64-v8a armeabi-v7a x86_64; do
     cp <repo>/build/app/outputs/flutter-apk/app-$abi-release.apk \
        archlence-1.0.0-$abi.apk
   done
   cp <repo>/build/app/outputs/flutter-apk/app-release.apk \
      archlence-1.0.0-universal.apk
   sha256sum *.apk > SHA256SUMS.txt
   ```

3. **Tag from a clean tree**, so the tag names exactly what was built:

   ```bash
   git tag -a v1.0.0 -m "Archlence Mobile 1.0.0"
   git push origin v1.0.0
   ```

4. **Attach all five files** — four APKs and `SHA256SUMS.txt`.

**Check the assets already attached before replacing them.** A draft release
sat here for days carrying APKs signed with the key that was later lost;
nothing about them looked wrong. Point the verifier at anything already
uploaded, not only at what you just built — see the roadmap's "A draft
release, one click from stranding everyone".

**Which APK a user needs:** almost every phone since 2019 is `arm64-v8a`.
`armeabi-v7a` is for older 32-bit devices; `x86_64` is emulators and the rare
Intel tablet. The universal APK carries all three at 64MB, roughly triple the
arm64 one, and exists so that somebody who does not know which they have is
not stuck. Listing arm64 first is deliberate — it is the one nearly everybody
wants.

---

## Archlence 1.0.0

Personal finance for Android, built so the data never leaves the phone.
Accounts, cards, transactions, holdings, a budget and savings goals — recorded
locally and encrypted with AES-256-GCM under a key held in the Android
Keystore. There is no account to create and no server to talk to.

### Install

Download **`archlence-1.0.0-arm64-v8a.apk`** unless you know you need another
one — it is the right file for essentially every phone made since 2019.

| File | For | Size |
| --- | --- | --- |
| `archlence-1.0.0-arm64-v8a.apk` | Almost every modern phone | 22MB |
| `archlence-1.0.0-armeabi-v7a.apk` | Older 32-bit devices | 20MB |
| `archlence-1.0.0-x86_64.apk` | Emulators, Intel tablets | 24MB |
| `archlence-1.0.0-universal.apk` | Any of them, if you would rather not choose | 64MB |

The universal file simply contains all three, which is why it is three times
the size. If you know your phone is from the last several years, take the
arm64 one.

Android will ask you to allow installing from this source. That prompt is the
system working correctly: you are installing something that did not come from
a store, so it wants you to say you meant to.

**For updates, use [Obtainium](https://github.com/ImranR98/Obtainium)** and
point it at this repository. It checks for new releases and installs them the
way a store would, without one.

**Verify what you downloaded** against `SHA256SUMS.txt`:

```bash
sha256sum -c SHA256SUMS.txt
```

Every APK here is signed with the same key, whose certificate is
`SHA-256: DF:1C:75:A4:0F:C6:51:92:32:E7:91:E0:37:0E:EE:C3:BD:1C:DB:62:17:E3:B3:6D:2E:74:EE:68:9F:78:6E:6B`.
Android enforces that every future update carries the same one; you can check
it yourself with `apksigner verify --print-certs`.

### What it does

- **Accounts** — cash, bank and card accounts, with balances that stay in step.
- **Cards** — a card's limit, its debt and its statement, and a flow for paying
  it down.
- **Transactions** — income and spending against a category, with a searchable
  register and a calendar you can read a month from.
- **Budget** — a monthly limit per category, and what is left of it.
- **Savings goals** — money set aside rather than spent, so a goal's balance
  leaves your account without pretending to be an expense.
- **Holdings** — crypto, gold and currency at a live price with the time it was
  fetched, alongside what they cost. Istanbul-listed shares too, on an API key
  you supply.
- **Subscriptions and recurring payments**, four **calculators**, an encrypted
  **backup** you choose the destination for, and an optional **screen lock** on
  your device's own biometrics or PIN.

Turkish and English, both written rather than machine-translated. The seeded
category names stay Turkish in both — they are data shared with the desktop
app rather than labels.

### What leaves the phone

Prices, and nothing else. When you hold crypto, gold or a currency, the app
asks a public price source what it is worth. Those requests carry a symbol —
never an amount, never a balance, never anything identifying you. There are
three hosts in the whole app and every URL it can build lives in one file,
[`lib/services/price_providers.dart`](../../lib/services/price_providers.dart).

A profile with no holdings makes **no request at all**, the two keyless price
calls carry **no headers whatsoever**, and two different people holding bitcoin
send **byte-identical requests**. Those are measurements, not claims —
`test/wire_shape_test.dart` fails if any of them stops being true, and
[`docs/data-safety.md`](../data-safety.md) records the traffic they came from.

The [privacy policy](https://superuser-d0.github.io/archlence-mobile/privacy.html)
([Türkçe](https://superuser-d0.github.io/archlence-mobile/gizlilik.html)) is
generated from the app's own copy of the text, so it cannot drift from what
the app actually says.

### Backups are on you

This is the honest cost of an app with no server. Nobody else holds a copy of
your data. **If you lose the phone without a backup, the data goes with it.**
The app writes an encrypted backup file you can put anywhere, tells you how
long ago you last made one, and asks again after a month.

A backup written by the [desktop client](https://github.com/superuser-d0/archlence)
opens here, down to the kuruş, and one written here opens there.

### Not on Google Play

By decision. Archlence tracks what you own and what you owe; it is not a
wallet, an exchange or a broker, holds no money and moves none.

### Known limits

- No tablet layout. Wide screens no longer stretch, but nothing uses the space.
- Two Tools entries — "What if" and "Reset data" — are not built, and are not
  drawn rather than shown greyed out.
- The Home tab's forecast and health score are not built.
- Shares stay at cost unless you supply your own BIST API key; there is no free
  keyless source for them.

### Built and tested

1134 unit tests, 14 device tests against a real Android Keystore and the real
network, `flutter analyze` clean. Everything claiming compatibility with the
desktop app is tested against output generated by the desktop's own modules
rather than against expectations written by hand.
