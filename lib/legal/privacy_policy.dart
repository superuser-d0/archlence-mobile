/// The privacy policy, in one place, in both languages.
///
/// **Why this is Dart and not two HTML files.** Google Play requires the
/// policy to be reachable BOTH from the store listing and from inside the
/// app, and it treats a policy that says something untrue as a policy
/// violation rather than a typo. Two hand-maintained copies of a document
/// that must not contradict each other is exactly the arrangement this
/// project refuses everywhere else — see the roadmap on parity fixtures. So
/// the text lives here, the app renders it, and `tool/emit_privacy_pages.dart`
/// generates `docs/privacy.html` and `docs/gizlilik.html` from it.
/// `test/privacy_pages_test.dart` fails if the committed pages have drifted
/// from this file.
///
/// **The in-app copy is TEXT, not a link, and that is deliberate.** Play
/// accepts either. A link would mean adding `url_launcher` and a fourth URL
/// to a codebase whose README invites the reader to run
/// `grep -rn "Uri.https" lib/` and count three. Rendering the text keeps that
/// claim true, works with no network, and satisfies the requirement.
///
/// Every factual claim below was checked against the code before it was
/// written: the three hosts against `price_providers.dart`, the request
/// contents against the `Uri.https` calls, the permissions against the
/// merged manifest, and the absence of analytics against `pubspec.yaml`.
library;

/// One block of the document.
sealed class PolicyBlock {
  const PolicyBlock();
}

/// A paragraph. `**bold**` is the only markup, and it is deliberately the
/// only one: two renderers have to agree on it.
class PolicyParagraph extends PolicyBlock {
  const PolicyParagraph(this.text);
  final String text;
}

/// A bulleted list.
class PolicyBullets extends PolicyBlock {
  const PolicyBullets(this.items);
  final List<String> items;
}

/// A table with a header row. Used once, for the three hosts.
class PolicyTable extends PolicyBlock {
  const PolicyTable({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;
}

class PolicySection {
  const PolicySection({required this.title, required this.blocks});
  final String title;
  final List<PolicyBlock> blocks;
}

class PrivacyPolicy {
  const PrivacyPolicy({
    required this.languageCode,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.sections,
  });

  final String languageCode;
  final String title;
  final String subtitle;

  /// The one-paragraph version, shown before the sections in both renderers.
  final String summary;

  final List<PolicySection> sections;
}

/// The date the text last changed. Bumped by hand when it does, because a
/// generated date would change on every build and say nothing.
const String privacyPolicyUpdated = '2026-08-30';

/// Where the published copy lives. Used by the store listing, and printed in
/// the generated pages so a reader can tell which URL is canonical.
const String privacyPolicyUrl =
    'https://superuser-d0.github.io/archlence-mobile/privacy.html';

const PrivacyPolicy privacyPolicyEn = PrivacyPolicy(
  languageCode: 'en',
  title: 'Archlence — Privacy Policy',
  subtitle:
      'For the Android app com.archlence.archlence_mobile. '
      'Last updated $privacyPolicyUpdated.',
  summary:
      '**Archlence has no account, no server of ours, and no analytics.** '
      'Everything you record stays in a file on your phone, encrypted. We do '
      'not receive your financial data, and there is nowhere for us to '
      'receive it — the app has no backend. This page says exactly what '
      'leaves the device and what does not, and the last section says how to '
      'check it rather than take our word for it.',
  sections: [
    PolicySection(
      title: 'Who is responsible',
      blocks: [
        PolicyParagraph(
          'Archlence is developed and published by an individual developer, '
          'not a company. For the purposes of the GDPR and of Turkey\'s KVKK, '
          'that developer is the data controller for anything this policy '
          'describes — which, as the next section explains, is nothing.',
        ),
        PolicyParagraph(
          'The developer can be reached through the issue tracker of the '
          'app\'s public repository, or at the contact address shown on the '
          'app\'s Google Play listing.',
        ),
      ],
    ),
    PolicySection(
      title: 'What we collect',
      blocks: [
        PolicyParagraph(
          '**Nothing.** The developer operates no server, no account system, '
          'no analytics, no crash reporting, no advertising and no tracking '
          'of any kind. No data about you or your use of the app is '
          'transmitted to us, because there is no endpoint belonging to us '
          'for it to be transmitted to.',
        ),
        PolicyParagraph(
          'The app contains no advertising SDK, no analytics SDK and no '
          'cookies. It does not build a profile of you, does not use your '
          'data for advertising, and has nothing to sell to anyone because it '
          'holds nothing.',
        ),
      ],
    ),
    PolicySection(
      title: 'What the app stores, and where',
      blocks: [
        PolicyBullets([
          'Accounts, cards, transactions, holdings, budgets and savings goals '
              'are stored in a database file in the app\'s private storage on '
              'your device.',
          'Amounts and descriptions are **encrypted with AES-256-GCM**. The '
              'encryption key is held by the Android Keystore, apart from the '
              'data it opens.',
          'Your language choice, the screen-lock preference and the date of '
              'your last backup are stored in the platform\'s secure storage.',
          'If you enter a BIST share-price API key of your own, it is stored '
              'in that same secure storage. It is never sent anywhere except '
              'to the provider it belongs to.',
        ]),
        PolicyParagraph(
          '**Retention:** the app keeps this data until you delete it or '
          'uninstall the app. Uninstalling removes all of it. There is no '
          'other copy, and no server-side backup for us to keep.',
        ),
      ],
    ),
    PolicySection(
      title: 'What leaves the device',
      blocks: [
        PolicyParagraph(
          'The app makes network requests for one purpose only: fetching '
          'prices for holdings you have recorded. There are three '
          'destinations in the entire codebase, and no others are possible.',
        ),
        PolicyTable(
          headers: ['Destination', 'What is sent', 'When'],
          rows: [
            [
              'api.coingecko.com',
              'A list of the crypto identifiers you hold, and the string '
                  '"usd". No credential, no identifier for you or your '
                  'device.',
              'When a screen showing crypto holdings is opened.',
            ],
            [
              'api.frankfurter.dev',
              'A list of currency codes, and "TRY" as the base. No '
                  'credential.',
              'When a screen showing currency or gold holdings is opened.',
            ],
            [
              'www.nosyapi.com',
              'A list of the BIST share codes you hold, and **your own API '
                  'key** in a request header.',
              '**Only** if you have entered a key in Settings. Without one, '
                  'no request is ever made to this host.',
            ],
          ],
        ),
        PolicyParagraph(
          'So a price provider can see *which* assets you asked about, which '
          'is unavoidable when asking a third party for a price. **What none '
          'of them receives is how much you hold, what it is worth, what you '
          'paid, any description, any account name, or any identifier for you '
          'or your device.** The symbol lists are sorted and deduplicated '
          'before being sent, so they do not carry the order in which you '
          'added things either.',
        ),
        PolicyParagraph(
          '**Legal basis.** These requests are made to deliver a feature you '
          'asked for by recording a holding, and carry no personal data. '
          'Where a legal basis is required for the incidental disclosure of '
          'your IP address to those providers, it is our legitimate interest '
          'in showing you a current price — an interest you can decline '
          'entirely by not recording a holding, or by leaving the shares key '
          'unset.',
        ),
        PolicyParagraph(
          '**International transfers.** Those three services are operated by '
          'third parties outside Turkey, so a request necessarily reaches a '
          'server abroad and discloses your IP address to it, as any web '
          'request does. Each has its own privacy policy: coingecko.com, '
          'frankfurter.dev and nosyapi.com. We have no relationship with '
          'them, send them nothing about you, and receive nothing from them '
          'about you.',
        ),
      ],
    ),
    PolicySection(
      title: 'Backups',
      blocks: [
        PolicyParagraph(
          'You can write an encrypted backup package from the Settings '
          'screen. The app hands the finished file to Android\'s share sheet, '
          'and **you** choose where it goes. The app cannot put a backup '
          'anywhere on its own, and does not upload one anywhere. A backup is '
          'protected by a passphrase you choose; that passphrase is stored '
          'nowhere and cannot be recovered.',
        ),
        PolicyParagraph(
          'If you send a backup to a cloud drive or a messaging app, that '
          'service\'s own privacy policy applies to the copy you sent. The '
          'file is encrypted, but where it goes after it leaves the share '
          'sheet is outside this app\'s control.',
        ),
      ],
    ),
    PolicySection(
      title: 'Permissions',
      blocks: [
        PolicyBullets([
          '**Internet** — for the three price requests above, and nothing '
              'else.',
          '**Biometric / device credential** — only if you turn on the '
              'optional screen lock. Authentication is performed by Android; '
              'the app never sees your fingerprint, PIN or password.',
        ]),
        PolicyParagraph(
          'The app requests no location, contacts, camera, microphone, '
          'storage-wide or advertising permissions.',
        ),
      ],
    ),
    PolicySection(
      title: 'Your rights',
      blocks: [
        PolicyParagraph(
          'Under the GDPR, the KVKK and comparable laws you have rights of '
          'access, rectification, erasure, restriction, portability and '
          'objection over personal data a controller holds about you. **We '
          'hold none**, so there is nothing for us to produce, correct or '
          'delete — and no request to us could return anything.',
        ),
        PolicyParagraph(
          'In practice you exercise those rights on the device itself, '
          'without asking anyone:',
        ),
        PolicyBullets([
          '**Access and portability** — Settings writes a complete, encrypted '
              'backup of your data that you can take anywhere.',
          '**Rectification** — every record can be edited or deleted in the '
              'app.',
          '**Erasure** — uninstalling the app removes the database and the '
              'encryption key. Nothing survives it.',
        ]),
        PolicyParagraph(
          'If you nevertheless believe your data has been mishandled, you may '
          'complain to your national data protection authority — in Turkey, '
          'the Kişisel Verileri Koruma Kurumu (KVKK); in the EU, your local '
          'supervisory authority.',
        ),
      ],
    ),
    PolicySection(
      title: 'Children',
      blocks: [
        PolicyParagraph(
          'Archlence is a personal finance tool intended for a general '
          'audience and is not directed at children. It collects nothing from '
          'anyone, including children, and contains no advertising, no '
          'in-app purchases and no social features.',
        ),
      ],
    ),
    PolicySection(
      title: 'Changes to this policy',
      blocks: [
        PolicyParagraph(
          'If the app ever begins sending something it does not send today, '
          'this policy will be updated before that version is published. '
          'Because the text is generated from a single file in the app\'s own '
          'source, the change will be visible in the repository\'s history '
          'alongside the code that caused it, and the copy inside the app '
          'cannot fall out of step with the copy on the web.',
        ),
      ],
    ),
    PolicySection(
      title: 'How to check all of this',
      blocks: [
        PolicyParagraph(
          'Archlence is open source under the Apache License 2.0. Every claim '
          'above is checkable in the source rather than taken on trust:',
        ),
        PolicyBullets([
          'Every URL the app can build is in one file, '
              'lib/services/price_providers.dart. Running '
              'grep -rn "Uri.https" lib/ over the repository finds all three '
              'and nothing else.',
          'The encryption lives in lib/crypto/.',
          'There is exactly one test in the whole suite that opens a network '
              'socket: integration_test/live_price_device_test.dart.',
          'There is no analytics, crash-reporting or advertising dependency '
              'in pubspec.yaml.',
          'This policy is generated from lib/legal/privacy_policy.dart, and a '
              'test fails the build if the published pages have drifted from '
              'it.',
        ]),
        PolicyParagraph(
          'The repository is at github.com/superuser-d0/archlence-mobile.',
        ),
      ],
    ),
  ],
);

const PrivacyPolicy privacyPolicyTr = PrivacyPolicy(
  languageCode: 'tr',
  title: 'Archlence — Gizlilik Politikası',
  subtitle:
      'com.archlence.archlence_mobile Android uygulaması için. '
      'Son güncelleme $privacyPolicyUpdated.',
  summary:
      '**Archlence\'ın hesabı, bize ait bir sunucusu ve analitiği yoktur.** '
      'Kaydettiğiniz her şey telefonunuzda, şifreli bir dosyada kalır. '
      'Finansal verilerinizi almıyoruz ve alabileceğimiz bir yer de yok — '
      'uygulamanın arka ucu yok. Bu sayfa cihazdan neyin çıkıp neyin '
      'çıkmadığını tam olarak yazar; son bölüm de bunu bize inanmak yerine '
      'nasıl doğrulayacağınızı anlatır.',
  sections: [
    PolicySection(
      title: 'Sorumlu kim',
      blocks: [
        PolicyParagraph(
          'Archlence bir şirket tarafından değil, bireysel bir geliştirici '
          'tarafından geliştirilip yayınlanmaktadır. GDPR ve KVKK anlamında '
          'bu politikanın kapsadığı her şeyin veri sorumlusu o '
          'geliştiricidir — ki bir sonraki bölümün açıkladığı gibi, o kapsam '
          'boştur.',
        ),
        PolicyParagraph(
          'Geliştiriciye uygulamanın herkese açık deposundaki issue '
          'sayfasından ya da Google Play sayfasında gösterilen iletişim '
          'adresinden ulaşabilirsiniz.',
        ),
      ],
    ),
    PolicySection(
      title: 'Ne topluyoruz',
      blocks: [
        PolicyParagraph(
          '**Hiçbir şey.** Geliştiricinin sunucusu, hesap sistemi, analitiği, '
          'çökme raporlaması, reklamı ve herhangi bir izleme mekanizması '
          'yoktur. Sizinle ya da uygulamayı kullanımınızla ilgili hiçbir veri '
          'bize iletilmez; çünkü iletilebileceği, bize ait bir uç nokta yok.',
        ),
        PolicyParagraph(
          'Uygulamada reklam SDK\'sı, analitik SDK\'sı ve çerez '
          'bulunmamaktadır. Profilinizi çıkarmaz, verilerinizi reklam için '
          'kullanmaz, ve kimseye satacak bir şeyi de yoktur — çünkü elinde '
          'hiçbir şey tutmuyor.',
        ),
      ],
    ),
    PolicySection(
      title: 'Uygulama neyi, nerede saklıyor',
      blocks: [
        PolicyBullets([
          'Hesaplar, kartlar, işlemler, varlıklar, bütçeler ve birikim '
              'hedefleri cihazınızdaki uygulamaya özel depolama alanında bir '
              'veritabanı dosyasında tutulur.',
          'Tutarlar ve açıklamalar **AES-256-GCM ile şifrelenir**. Şifreleme '
              'anahtarı, açtığı verilerden ayrı olarak Android Keystore '
              'tarafından tutulur.',
          'Dil tercihiniz, ekran kilidi ayarınız ve son yedeğinizin tarihi '
              'platformun güvenli deposunda saklanır.',
          'Kendi BIST hisse fiyatı API anahtarınızı girerseniz o da aynı '
              'güvenli depoda tutulur. Ait olduğu sağlayıcı dışında hiçbir '
              'yere gönderilmez.',
        ]),
        PolicyParagraph(
          '**Saklama süresi:** uygulama bu verileri siz silene ya da '
          'uygulamayı kaldırana kadar tutar. Kaldırmak hepsini siler. Başka '
          'bir kopya yoktur ve bizim tutabileceğimiz sunucu tarafında bir '
          'yedek de yoktur.',
        ),
      ],
    ),
    PolicySection(
      title: 'Cihazdan ne çıkıyor',
      blocks: [
        PolicyParagraph(
          'Uygulama tek bir amaçla ağ isteği yapar: kaydettiğiniz varlıklar '
          'için fiyat çekmek. Kod tabanının tamamında üç adres vardır ve '
          'başkası mümkün değildir.',
        ),
        PolicyTable(
          headers: ['Adres', 'Ne gönderiliyor', 'Ne zaman'],
          rows: [
            [
              'api.coingecko.com',
              'Elinizdeki kripto tanımlayıcılarının listesi ve "usd" '
                  'metni. Kimlik bilgisi yok; sizi ya da cihazınızı '
                  'tanımlayan hiçbir şey yok.',
              'Kripto varlık gösteren bir ekran açıldığında.',
            ],
            [
              'api.frankfurter.dev',
              'Para birimi kodlarının listesi ve taban olarak "TRY". '
                  'Kimlik bilgisi yok.',
              'Döviz veya altın varlığı gösteren bir ekran açıldığında.',
            ],
            [
              'www.nosyapi.com',
              'Elinizdeki BIST hisse kodlarının listesi ve bir istek '
                  'başlığında **kendi API anahtarınız**.',
              '**Yalnızca** Ayarlar\'da bir anahtar girdiyseniz. Anahtar '
                  'yoksa bu adrese hiçbir istek gitmez.',
            ],
          ],
        ),
        PolicyParagraph(
          'Yani bir fiyat sağlayıcısı *hangi* varlıkları sorduğunuzu '
          'görebilir; bu, birinden fiyat isterken kaçınılmazdır. **Hiçbirine '
          'gitmeyen şeyler: ne kadar tuttuğunuz, ne ettiği, ne ödediğiniz, '
          'herhangi bir açıklama, herhangi bir hesap adı, ve sizi ya da '
          'cihazınızı tanımlayan herhangi bir bilgi.** Sembol listeleri '
          'gönderilmeden önce sıralanır ve tekrarlardan arındırılır; '
          'dolayısıyla eklediğiniz sırayı da taşımazlar.',
        ),
        PolicyParagraph(
          '**Hukuki sebep.** Bu istekler, bir varlık kaydederek talep '
          'ettiğiniz bir özelliği sunmak için yapılır ve kişisel veri '
          'taşımaz. IP adresinizin bu sağlayıcılara zorunlu olarak açılması '
          'için bir hukuki sebep gerektiği ölçüde, bu bizim size güncel bir '
          'fiyat gösterme yönündeki meşru menfaatimizdir — varlık '
          'kaydetmeyerek ya da hisse anahtarını boş bırakarak bunu tamamen '
          'reddedebilirsiniz.',
        ),
        PolicyParagraph(
          '**Yurt dışına aktarım.** Bu üç servis Türkiye dışındaki üçüncü '
          'taraflarca işletilmektedir; dolayısıyla bir istek zorunlu olarak '
          'yurt dışındaki bir sunucuya ulaşır ve her web isteğinde olduğu '
          'gibi IP adresinizi ona açar. Her birinin kendi gizlilik politikası '
          'vardır: coingecko.com, frankfurter.dev ve nosyapi.com. Onlarla bir '
          'ilişkimiz yok; onlara sizinle ilgili hiçbir şey göndermiyor ve '
          'onlardan sizinle ilgili hiçbir şey almıyoruz.',
        ),
      ],
    ),
    PolicySection(
      title: 'Yedekler',
      blocks: [
        PolicyParagraph(
          'Ayarlar ekranından şifrelenmiş bir yedek paketi yazabilirsiniz. '
          'Uygulama hazır dosyayı Android\'in paylaşım sayfasına verir, '
          'nereye gideceğine **siz** karar verirsiniz. Uygulama bir yedeği '
          'kendi başına hiçbir yere koyamaz ve hiçbir yere yüklemez. Yedek, '
          'sizin seçtiğiniz bir parola ile korunur; o parola hiçbir yerde '
          'saklanmaz ve kurtarılamaz.',
        ),
        PolicyParagraph(
          'Bir yedeği bulut sürücüsüne ya da bir mesajlaşma uygulamasına '
          'gönderirseniz, gönderdiğiniz kopya için o servisin kendi gizlilik '
          'politikası geçerli olur. Dosya şifrelidir, ama paylaşım '
          'sayfasından çıktıktan sonra nereye gittiği bu uygulamanın '
          'denetimi dışındadır.',
        ),
      ],
    ),
    PolicySection(
      title: 'İzinler',
      blocks: [
        PolicyBullets([
          '**İnternet** — yukarıdaki üç fiyat isteği için, başka hiçbir şey '
              'için değil.',
          '**Biyometrik / cihaz kimlik bilgisi** — yalnızca isteğe bağlı '
              'ekran kilidini açarsanız. Doğrulamayı Android yapar; uygulama '
              'parmak izinizi, PIN\'inizi ya da parolanızı hiçbir zaman '
              'görmez.',
        ]),
        PolicyParagraph(
          'Uygulama konum, rehber, kamera, mikrofon, geniş depolama ya da '
          'reklam izni istemez.',
        ),
      ],
    ),
    PolicySection(
      title: 'Haklarınız',
      blocks: [
        PolicyParagraph(
          'KVKK, GDPR ve benzeri mevzuat kapsamında, bir veri sorumlusunun '
          'sizinle ilgili tuttuğu kişisel veriler üzerinde erişim, düzeltme, '
          'silme, işlemenin sınırlandırılması, taşınabilirlik ve itiraz '
          'haklarınız vardır. **Biz hiçbir veri tutmuyoruz**; dolayısıyla '
          'üretebileceğimiz, düzeltebileceğimiz ya da silebileceğimiz bir şey '
          'yok — bize yapılacak bir başvuru hiçbir şey döndüremez.',
        ),
        PolicyParagraph(
          'Pratikte bu hakları kimseye başvurmadan, doğrudan cihaz üzerinde '
          'kullanırsınız:',
        ),
        PolicyBullets([
          '**Erişim ve taşınabilirlik** — Ayarlar, verilerinizin '
              'istediğiniz yere götürebileceğiniz eksiksiz ve şifreli bir '
              'yedeğini yazar.',
          '**Düzeltme** — her kayıt uygulama içinde düzenlenebilir ya da '
              'silinebilir.',
          '**Silme** — uygulamayı kaldırmak veritabanını ve şifreleme '
              'anahtarını siler. Ardından hiçbir şey kalmaz.',
        ]),
        PolicyParagraph(
          'Buna rağmen verilerinizin hatalı işlendiğini düşünüyorsanız ulusal '
          'veri koruma otoritenize şikâyette bulunabilirsiniz — Türkiye\'de '
          'Kişisel Verileri Koruma Kurumu (KVKK), AB\'de yerel denetim '
          'makamınız.',
        ),
      ],
    ),
    PolicySection(
      title: 'Çocuklar',
      blocks: [
        PolicyParagraph(
          'Archlence genel kitleye yönelik bir kişisel finans aracıdır ve '
          'çocuklara yönelik değildir. Çocuklar dahil hiç kimseden hiçbir '
          'şey toplamaz; reklam, uygulama içi satın alma ve sosyal özellik '
          'içermez.',
        ),
      ],
    ),
    PolicySection(
      title: 'Bu politikadaki değişiklikler',
      blocks: [
        PolicyParagraph(
          'Uygulama bugün göndermediği bir şeyi göndermeye başlarsa, o sürüm '
          'yayınlanmadan önce bu politika güncellenecektir. Metin '
          'uygulamanın kendi kaynağındaki tek bir dosyadan üretildiği için, '
          'değişiklik ona sebep olan kodla birlikte deponun geçmişinde '
          'görünür — ve uygulamanın içindeki kopya ile web\'deki kopya '
          'birbirinden ayrı düşemez.',
        ),
      ],
    ),
    PolicySection(
      title: 'Bütün bunları nasıl doğrularsınız',
      blocks: [
        PolicyParagraph(
          'Archlence, Apache License 2.0 altında açık kaynaktır. Yukarıdaki '
          'her iddia güvenmek yerine kaynaktan doğrulanabilir:',
        ),
        PolicyBullets([
          'Uygulamanın kurabileceği her URL tek bir dosyadadır: '
              'lib/services/price_providers.dart. Depoda '
              'grep -rn "Uri.https" lib/ komutu üçünü de bulur, başkasını '
              'bulmaz.',
          'Şifreleme lib/crypto/ altındadır.',
          'Suite\'in tamamında ağ soketi açan tek test '
              'integration_test/live_price_device_test.dart dosyasıdır.',
          'pubspec.yaml içinde analitik, çökme raporlama ya da reklam '
              'bağımlılığı yoktur.',
          'Bu politika lib/legal/privacy_policy.dart dosyasından üretilir ve '
              'yayınlanan sayfalar ondan ayrı düşerse bir test derlemeyi '
              'düşürür.',
        ]),
        PolicyParagraph(
          'Depo: github.com/superuser-d0/archlence-mobile',
        ),
      ],
    ),
  ],
);
