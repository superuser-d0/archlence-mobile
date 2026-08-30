# Play's Data safety form — the answers, and what they rest on

Play requires this declaration to be re-confirmed at every release, and treats
a false one as a **policy violation** rather than a mistake to correct. So the
answers are written down here with their evidence, and the evidence is pinned
by a test — `test/wire_shape_test.dart` — so that at the next release this can
be re-*verified* rather than re-*reasoned*.

The declaration below was decided from what the app actually puts on the wire,
recorded through the `HttpGet` seam, not from a reading of the code.

## The answers

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **No** |
| All 13 data type categories | **None** |
| Encryption in transit | *(not asked — it applies to collected data)* |
| Data deletion request mechanism | *(not asked, for the same reason)* |

Nothing in Location, Personal info, Financial info, Health and fitness,
Messages, Photos and videos, Audio files, Files and docs, Calendar, Contacts,
App activity, Web browsing, or App info and performance.

## Why "no", when the app does make network requests

Play defines **collection** as *transmitting data off the user's device*, and
it is explicit that this counts *"irrespective of whether data is transmitted
to you or a third-party server"*. So the question is not whether the developer
receives anything — the developer receives nothing, and has no server to
receive it with — but whether what leaves the device is **personal or
sensitive user data**.

It is not, and that is a measurement rather than an opinion.

### What actually goes on the wire

Recorded by driving the real screens with a recording `HttpGet`. These are the
complete requests, verbatim:

```
https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,pax-gold&vs_currencies=usd
    headers: {}

https://api.frankfurter.dev/v1/latest?from=TRY&to=EUR,USD
    headers: {}

https://www.nosyapi.com/apiv2/service/economy/bist/exchange-rate?code=GARAN,THYAO
    headers: {X-NSYP: <the user's own key>}
```

* **A profile with no holdings makes no request at all.** Not few — none. The
  app does not phone anywhere on start, on install, or on any schedule.
* **The two keyless requests carry no headers whatsoever.** No user agent of
  ours, no client id, no install id, no cookie.
* **Two different people holding bitcoin send byte-identical requests.**
  Different accounts, different amounts, different names on the holding — the
  same bytes. There is nothing in the payload that distinguishes one profile
  from another.
* **Symbol lists are sorted and deduplicated**, so they do not carry the order
  in which holdings were added either.
* **A share holding with no API key produces no request to its provider** —
  the secure store is not even read.

What is *not* in any request: the amount held, the quantity, the current
value, the purchase price, any description, any account name, any date, and
any identifier for the user or the device.

That is Play's own description of data **fully de-associated from individual
users**, which is one of the listed exemptions.

### And "Other financial info" does not fit

Play defines that subtype as *"any other financial information such as user
salary or debts"* — amounts attached to a person. What leaves here is a list
of public ticker symbols with no amounts and no person attached. A dictionary
app sending the word you looked up is the closer analogy; a weather app
sending your location is not, because location is itself a listed data type
and a ticker symbol is not.

### The one identifier, and why it is still not a declaration

If — and only if — the user enters their own BIST API key in Settings, that
key is sent to the provider that issued it. It identifies them to **that
provider**, whom they registered with. Play exempts *"transferring user data
to a third party based on a specific user-initiated action, where the user
reasonably expects the data to be shared"*, and entering a provider's key so
the app can query that provider is that action exactly. It is described in
full in the privacy policy regardless.

## The structural evidence

* **One network path.** `lib/services/price_providers.dart` is the only file
  in `lib/` that touches `HttpClient`, and `assets_screen.dart:140` is its
  only caller. Opening the Assets tab is the only thing that can cause a
  request.
* **No background surface.** The app's `AndroidManifest.xml` declares **zero**
  `service`, `receiver` and `provider` elements. The app cannot run when it is
  not open.
* **No third-party telemetry.** 14 direct dependencies, none of them
  analytics, crash reporting or advertising; and no Firebase, Google
  Analytics, ads, or Sentry anywhere in the resolved graph.
* **Two permissions.** `INTERNET`, and the biometric pair that `local_auth`
  contributes for the optional screen lock.

## What keeps this true

`test/wire_shape_test.dart` pins every string above. It fails if a header is
added, if a query parameter is added, if a fourth host appears, if a request
fires with no holdings, or if two profiles ever stop sending the same bytes.
Checked by mutation, one at a time:

| Mutation | Result |
| --- | --- |
| Add a `User-Agent` header to the keyless calls | fails, naming the host |
| Add a `client=archlence-9f2a` parameter to CoinGecko | fails, printing both strings |

`test/privacy_pages_test.dart` separately requires the set of hosts in `lib/`
to be exactly the three the privacy policy names, in both languages.

**If any of those tests goes red, this file is out of date and so is the
declaration.** Do not relax an assertion to make one pass.

## At the next release

1. Run `flutter test test/wire_shape_test.dart test/privacy_pages_test.dart`.
2. If both pass, the answers above are still correct — re-confirm the form
   unchanged.
3. If either fails, the app now sends something it did not. Update
   `lib/legal/privacy_policy.dart`, regenerate the pages, revisit the table at
   the top of this file, and only then re-submit.

The judgement in "Why 'no'" is the publisher's to make and to sign. What this
file guarantees is that the facts it was made from are still the facts.
