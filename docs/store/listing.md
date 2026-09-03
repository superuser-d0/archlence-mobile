# Store listing copy

Draft. **The text is a product decision and needs a human signature** — the
same rule the wire measurements are under. What this file guarantees is the
mechanical half: the lengths fit, both languages exist, and nothing here
promises a feature the app does not currently ship.

**Written for Play and now channel-neutral.** Play is not a channel this app
uses — see the roadmap's "Getting it into people's hands" — so the limits
below are kept as the TIGHTEST constraint any channel imposes rather than as
Play's rules. Nothing else is stricter: F-Droid's summary is 80 characters and
its full description has no hard ceiling; a GitHub release description has no
limit at all. Copy that fits here fits anywhere.

Lengths are checked by `tool/check_listing.py`, which reads THIS file and
fails if any field is over. Run it before pasting anything anywhere.

Limits: short description **80 characters**, full description **4000**.
Both are counted in characters, not bytes — which matters here, because
Turkish `ı`, `ş`, `ğ` and `ç` are two bytes each and a byte count would
reject copy every one of these channels accepts.

## What is deliberately NOT claimed

The full descriptions below list only what a user can actually do today.
Kept out on purpose:

- the Home tab's forecast and financial health score;
- the two Tools entries that are not built — "What if" and "Reset data";
- anything involving a second device, an account, or sync;
- a tablet layout — wide screens do not stretch, but nothing uses the space.

`showUnbuiltFeatures` in `lib/widgets/not_yet.dart` governs the first two, and
it is `false`, which means those things are **not drawn at all** rather than
drawn with a `NOT YET` chip. So a shopper comparing screenshots to the app
sees the same set both times. Counted from `lib/screens/tools_screen.dart`
rather than remembered: nine entries, seven with a destination, two without.

This is worth stating because the roadmap says both things in two places —
"the other seven cards are dimmed with a NOT YET chip" in "The wired tabs",
written when two were live, and "from two live cards out of nine to seven" in
"The four calculators", written after. The second is the current one. If a
release ever flips `showUnbuiltFeatures`, this file is part of what changes
with it.

---

## English (en-US)

### Title (30 max)

```
Archlence
```

### Short description (80 max)

```
Your accounts, cards, holdings and budget — on this phone and nowhere else.
```

### Full description (4000 max)

```
Archlence is a personal finance app that keeps your money's record on your phone.

No account. No server. Nothing to sign in to. Your data is written to an encrypted file that only this app can open, and the key that opens it is held by Android's own key store, apart from the data. Nothing is uploaded, because there is nowhere to upload it to.

WHAT YOU CAN DO

• Accounts — cash, bank and card accounts, with balances that stay in step as you record what happens to them.
• Cards — a card's limit, its debt and its statement, and a flow for paying that debt down.
• Transactions — income and spending against a category, with a register you can search and a calendar you can read a month from.
• Budget — a monthly limit per category, and what is left of it.
• Savings goals — money set aside rather than spent, so a goal's balance leaves your account without pretending to be an expense.
• Holdings — crypto, gold and currency carried at a live price with the time it was fetched, alongside what they cost you. Istanbul-listed shares are priced too, on an API key you supply.
• Subscriptions and recurring payments — what is due, and when.
• Calculators — four of them, for the arithmetic this kind of app keeps asking you to do in your head.
• Backup and restore — an encrypted backup file you choose the destination for, through Android's own picker, so it can go anywhere you can put a file.
• A screen lock, on your device's own biometrics or PIN.

IN TWO LANGUAGES

Turkish and English, both written rather than translated by machine, with Turkish number and currency formatting throughout.

THE SAME FILE AS THE DESKTOP APP

A backup written on the desktop client opens here, down to the kuruş. Money is handled as exact decimals rather than as binary floating point, on the phone and on the desktop alike, so a figure does not drift by a kuruş because it made a round trip.

WHICH MEANS BACKUPS ARE ON YOU

This is the honest cost of an app with no server. Nobody else holds a copy of your data. If you lose the phone without a backup, the data goes with it — so the app asks you about backups rather than assuming you thought of it.

WHAT LEAVES THE PHONE

Prices, and nothing else. When you hold crypto, gold or a currency, the app asks a public price source what it is worth. Those requests carry a symbol — never an amount, never a balance, never anything about you. Everything else stays on the device. The privacy policy is linked from Settings and says the same thing at length.

Archlence tracks what you own and what you owe. It is not a wallet, an exchange or a broker: it holds no money, moves no money, and cannot make a payment for you.
```

---

## Türkçe (tr-TR)

### Başlık (30 max)

```
Archlence
```

### Kısa açıklama (80 max)

```
Hesaplarınız, kartlarınız ve bütçeniz — bu telefonda, başka hiçbir yerde.
```

### Tam açıklama (4000 max)

```
Archlence, paranızın kaydını telefonunuzda tutan bir kişisel finans uygulamasıdır.

Üyelik yok. Sunucu yok. Giriş yapılacak bir yer yok. Verileriniz, yalnızca bu uygulamanın açabildiği şifreli bir dosyaya yazılır; onu açan anahtarı ise Android'in kendi anahtar deposu, verilerden ayrı olarak tutar. Hiçbir şey yüklenmez, çünkü yüklenecek bir yer yoktur.

NELER YAPABİLİRSİNİZ

• Hesaplar — nakit, banka ve kart hesapları; kaydettiklerinizle birlikte güncel kalan bakiyeler.
• Kartlar — bir kartın limiti, borcu ve ekstresi; borcu ödemek için bir akış.
• İşlemler — kategoriye göre gelir ve harcama; arayabildiğiniz bir kayıt defteri ve bir ayı okuyabildiğiniz bir takvim.
• Bütçe — kategori başına aylık bir sınır ve ondan geriye ne kaldığı.
• Birikim hedefleri — harcanan değil, ayrılan para; hedefin bakiyesi hesabınızdan çıkar ama harcama gibi görünmez.
• Varlıklar — kripto, altın ve döviz; maliyetlerinin yanında, çekildiği saatle birlikte canlı fiyatla. Borsa İstanbul hisseleri de fiyatlanır, sizin sağladığınız bir API anahtarıyla.
• Abonelikler ve düzenli ödemeler — neyin, ne zaman ödeneceği.
• Hesap makineleri — bu tür uygulamaların sizden kafadan yapmanızı beklediği dört hesap için.
• Yedekleme ve geri yükleme — hedefini kendinizin seçtiği şifreli bir yedek dosyası; Android'in kendi seçicisi üzerinden, yani dosya koyabildiğiniz her yere.
• Cihazınızın kendi biyometrisi veya PIN'iyle ekran kilidi.

İKİ DİLDE

Türkçe ve İngilizce; ikisi de makineyle çevrilmek yerine yazıldı. Sayı ve para biçimlendirmesi baştan sona Türkçe.

MASAÜSTÜ UYGULAMASIYLA AYNI DOSYA

Masaüstü istemcisinde alınan bir yedek burada kuruşuna kadar açılır. Para, telefonda da masaüstünde de ikili kayan noktayla değil, tam ondalıklarla işlenir; böylece bir tutar, gidip geldi diye bir kuruş kaymaz.

YANİ YEDEK ALMAK SİZE KALIYOR

Sunucusu olmayan bir uygulamanın dürüst bedeli budur. Verilerinizin başka kimsede kopyası yok. Yedek almadan telefonu kaybederseniz veriler de onunla gider — bu yüzden uygulama, aklınıza gelmiştir diye varsaymak yerine yedeği size sorar.

TELEFONDAN NE ÇIKIYOR

Fiyatlar, başka bir şey değil. Kripto, altın veya döviz tuttuğunuzda uygulama, herkese açık bir fiyat kaynağına bunun ne ettiğini sorar. Bu isteklerde yalnızca bir sembol gider — tutar değil, bakiye değil, sizinle ilgili hiçbir şey değil. Geri kalan her şey cihazda kalır. Gizlilik politikası Ayarlar'dan açılır ve aynı şeyi uzun uzun anlatır.

Archlence neyiniz olduğunu ve neye borçlu olduğunuzu takip eder. Cüzdan, borsa ya da aracı kurum değildir: para tutmaz, para taşımaz ve sizin adınıza ödeme yapamaz.
```

---

## The questions a channel asks, in one place

Gathered from where the answers already live, so a submission does not have to
re-derive them. Each says where it comes from.

| Question | Answer | Where it comes from |
| --- | --- | --- |
| Does it collect or share user data? | **No** | `docs/data-safety.md`, evidence pinned by `test/wire_shape_test.dart` |
| Privacy policy URL | `https://superuser-d0.github.io/archlence-mobile/privacy.html` | `docs/privacy.html`, live and returning 200 |
| Account required? | None. All functionality available with no restrictions | There is nothing to sign in to |
| Ads | None | Nothing in the app serves any |
| Category | Finance | |
| Licence | See `LICENSE` and `NOTICE` | In the repository |
| Source code | `https://github.com/superuser-d0/archlence-mobile` | |

**F-Droid specifically** will likely apply a **NonFreeNet** anti-feature label,
because prices come from CoinGecko, Frankfurter and NosyAPI. That is a label
rather than a refusal, and the honest answer to it is in this file's own copy:
the app works with no network at all, and holdings simply stay at cost.

## Assets, and where they are

| Asset | File | Verified |
| --- | --- | --- |
| App icon 512×512 | `docs/store/play_store_512.png` | 32-bit PNG **with** alpha, 11KB |
| Feature graphic 1024×500 | `docs/store/feature_graphic_1024x500.png` | 24-bit PNG, no alpha, 22KB |
| Screenshots ×4 | `docs/store/screenshots/*.png` | 1200×2400, exactly 2.000:1, 24-bit PNG no alpha |

The screenshots in `docs/store/screenshots/` are the ones to upload, NOT the
captures in `docs/screenshots/`. The captures are 1080×2400 — 2.222:1 — which
Play refused outright and which no channel has a reason to prefer; the
conformed pair is exactly 2.000:1 with every original pixel intact. See
`tool/emit_store_screenshots.py`. The README embeds the CAPTURES, deliberately:
there the 9:20 shape is what a phone actually looks like.
