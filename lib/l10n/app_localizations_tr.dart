// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Archlence';

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get navAssets => 'Varlıklar';

  @override
  String get navCards => 'Kartlar';

  @override
  String get navTools => 'Araçlar';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get startUpFailed => 'Archlence başlatılamadı';

  @override
  String get notYetChip => 'HENÜZ YOK';

  @override
  String get couldNotBeRead => 'Bu okunamadı';

  @override
  String get totalBalance => 'Toplam Bakiye';

  @override
  String get savingInProgress => 'Kaydediliyor…';

  @override
  String get toolsTitle => 'Hesaplama Araçları';

  @override
  String get toolsSubtitle =>
      'Finansını iyileştirmek için hesaplayıcıları ve planlayıcıları keşfet.';

  @override
  String get toolBudget => 'Aylık\nBütçe';

  @override
  String get toolCalendar => 'Takvim';

  @override
  String get toolCalculator => 'Hesap\nMakinesi';

  @override
  String get toolInterestReturn => 'Faiz\nGetirisi';

  @override
  String get toolCompoundInterest => 'Bileşik\nFaiz';

  @override
  String get toolLoanCalculator => 'Kredi\nHesaplama';

  @override
  String get toolSavingsGoal => 'Birikim\nHedefi';

  @override
  String get toolWhatIf => 'What-If\nSandbox';

  @override
  String get toolResetData => 'Verileri\nSıfırla';

  @override
  String get lockedTitle => 'Archlence kilitli';

  @override
  String get lockedExplanation =>
      'Bu telefonda kullandığın parmak izi ya da PIN ile aç.';

  @override
  String get lockedRefused => 'Kilit açılmadı.';

  @override
  String get lockedWaiting => 'Bekleniyor…';

  @override
  String get lockedUnlock => 'Kilidi Aç';

  @override
  String get unlockPrompt => 'Archlence kilidini aç';

  @override
  String get savingsGoalsTitle => 'Birikim Hedefleri';

  @override
  String get savingsGoalsExplanation =>
      'Bir hedefteki para bakiyenden ayrı tutulur. Harcama olmadığı için hiçbir gider grafiğinde görünmez.';

  @override
  String get savingsGoalsEmpty =>
      'Henüz birikim hedefi yok. Yukarıdaki + ile bir tane ekle.';

  @override
  String get goalUnreadable => 'Okunamayan hedef';

  @override
  String get goalSaved => 'Toplanan';

  @override
  String get goalTarget => 'Hedef';

  @override
  String get goalTakeBack => 'Geri al';

  @override
  String get goalPutIn => 'Biriktir';

  @override
  String get settingsSectionAccount => 'Hesap ve Tercihler';

  @override
  String get settingsCategorySettings => 'Kategori Ayarları';

  @override
  String get settingsLanguage => 'Dil';

  @override
  String get settingsLanguageSystem => 'Sistem dili';

  @override
  String get settingsEncryptionKey => 'Şifreleme Anahtarı';

  @override
  String get keyMethodAndroidKeystore => 'Android Keystore';

  @override
  String get keyMethodOwnerOnlyFile => 'yalnızca sahibine açık dosya';

  @override
  String get keyProtectionUnknown => 'Bu derlemede bilinmiyor.';

  @override
  String keyProtectionHeldByOs(String method) {
    return '$method — işletim sistemi tarafından tutuluyor.';
  }

  @override
  String keyProtectionLocalFile(String method) {
    return '$method — işletim sisteminin anahtar deposunda DEĞİL; anahtar yalnızca bu uygulamanın okuyabildiği yerel bir dosya.';
  }

  @override
  String get keyWarningOsStoreUnavailable =>
      'İşletim sisteminin anahtar deposu kullanılamıyor; anahtar yalnızca bu uygulamanın okuyabildiği yerel bir dosyada tutuluyor.';

  @override
  String get keyWarningNoPlatformStore =>
      'Bu platformda desteklenen bir işletim sistemi anahtar deposu yok.';

  @override
  String get settingsSectionSecurity => 'Güvenlik';

  @override
  String get lockTileTitle => 'Geri döndüğümde kilitle';

  @override
  String get lockTileExplanation =>
      'Bir dakika uzak kaldıktan sonra parmak izini ya da PIN’ini ister. Telefonu eline alan birinden ekranı gizler — şifreleme eklemez.';

  @override
  String get lockTileUnavailable =>
      'Bu cihazda parmak izi ya da ekran kilidi kurulu değil.';

  @override
  String get settingsSectionYourData => 'Verilerin';

  @override
  String get settingsBackupRestore => 'Yedekle ve Geri Yükle';

  @override
  String get settingsBackupUnavailable => 'Bu derlemede kullanılamıyor.';

  @override
  String get settingsBackupSubtitle =>
      'Saklayabileceğin bir yedek oluştur ya da bir yedeği geri yükle — masaüstü uygulamasının yazdığı yedekler dahil.';

  @override
  String get settingsSectionAppearance => 'Görünüm ve Gizlilik';

  @override
  String get settingsPremiumTheme => 'Premium Mavi Tema';

  @override
  String get settingsPremiumThemeSubtitle =>
      'Kapalıyken standart tema kullanılır';

  @override
  String get settingsDataPrivacy => 'Veriler ve Gizlilik';

  @override
  String get settingsSectionSecurityHistory => 'Güvenlik ve Geçmiş';

  @override
  String get settingsChangePassword => 'Şifre Değiştir';

  @override
  String get settingsChangePasswordSubtitle =>
      'Şifreni buradan yenileyebilirsin.';

  @override
  String get settingsBalanceHistory => 'Bakiye Geçmişi';

  @override
  String get settingsSectionSystem => 'Sistem';

  @override
  String get settingsDarkMode => 'Karanlık Mod';

  @override
  String get settingsDarkModeSubtitle =>
      'Obsidian Prime şimdilik yalnızca koyu';

  @override
  String get settingsContactUs => 'Bize Ulaşın';

  @override
  String get settingsSignOut => 'Çıkış Yap';

  @override
  String get errNotAnAmount => 'Bu bir tutar değil.';

  @override
  String get errAmountNotPositive => 'Sıfırdan büyük bir tutar gir.';

  @override
  String get errAccountEmptyName => 'Hesaba bir ad ver.';

  @override
  String get errAccountUnknownType => 'Bir hesap türü seç.';

  @override
  String get errAccountInvalidStatementDay =>
      'Hesap kesim günü 1 ile 31 arasında olmalı.';

  @override
  String get errAccountCreditLimitRequired =>
      'Kredi kartının sıfırdan büyük bir limiti olmalı.';

  @override
  String get errAccountNegativeOpeningDebt => 'Borç negatif bir tutar olamaz.';

  @override
  String get errAccountOpeningDebtExceedsLimit =>
      'Borç, girdiğin limitten büyük.';

  @override
  String get errAccountNotFound => 'Bu hesap artık yok.';

  @override
  String get errAccountCardFrozen =>
      'Bu kart donduruldu. Harcama yapmak için dondurmayı kaldır.';

  @override
  String get errAccountInsufficientLimit =>
      'Bu, kartın kullanılabilir limitini aşar.';

  @override
  String get errAccountNotACreditCard => 'Bu bir kredi kartı değil.';

  @override
  String get errAccountNoDebtToPay => 'Bu kartta ödenecek borç yok.';

  @override
  String get errAccountPaymentExceedsDebt => 'Bu, kartın borcundan fazla.';

  @override
  String get errAccountSourceMustBeChecking =>
      'Kartı başka bir kartla değil, nakit bir hesaptan öde.';

  @override
  String get errAccountBalanceUpdateFailed =>
      'Bakiye güncellenemedi. Hiçbir şey değişmedi.';

  @override
  String get errAccountUnknownCardPreference => 'Bilinmeyen kart ayarı.';

  @override
  String get errTransactionInstallmentRange =>
      'Taksit sayısı 1 ile 12 arasında olmalı.';

  @override
  String get errTransactionNegativeLimit => 'Limit negatif olamaz.';

  @override
  String get errAssetInvalidAmount =>
      'Fiyat ve adet, sıfırdan büyük birer sayı olmalı.';

  @override
  String get errAssetNotFound => 'Bu varlık artık yok.';

  @override
  String get errSavingsEmptyName => 'Hedefin ne için olduğunu yaz.';

  @override
  String get errSavingsNegativeOpeningAmount =>
      'Bir hedef, içinde hiçten az parayla başlayamaz.';

  @override
  String get errSavingsIdentityMismatch =>
      'Bu hedef, ekran çizildiğinden beri değişti. Hiçbir para taşınmadı — aşağı çekip yenile ve tekrar dene.';

  @override
  String get errSavingsAccountNotFound => 'Bu nakit hesap artık yok.';

  @override
  String get errSavingsGoalNotFoundOrCompleted => 'Bu hedef zaten tamamlandı.';

  @override
  String get errSavingsInsufficientBalance => 'Hedefte o kadar para yok.';

  @override
  String get errSavingsRefundAccountRequired =>
      'Paranın nereye gideceğini seç.';

  @override
  String get errBudgetUnknownItemType => 'Gelir ya da gider seç.';

  @override
  String get errBudgetEmptyName => 'Kaleme bir ad ver.';

  @override
  String get errBudgetInvalidMonth => 'Ocak ile Aralık arasında bir ay seç.';

  @override
  String get errBudgetInvalidAlertThreshold =>
      'Uyarı eşiği yüzde 1 ile 100 arasında olmalı.';

  @override
  String get errRecurringUnknownFrequency =>
      'Bu abonelik, Archlence’in tanımadığı bir düzende tekrarlanıyor.';

  @override
  String get errRecurringInvalidDay => 'Ayın günü 1 ile 31 arasında olmalı.';

  @override
  String get errRecurringInvalidTransactionType =>
      'Bir abonelik gelir ya da gider olmalı.';

  @override
  String get errRecurringUnreadablePayment => 'Bu abonelik okunamadı.';

  @override
  String get commonNext => 'Devam';

  @override
  String get onboardingTagline =>
      'Hesapların, kartların, varlıkların ve bütçen — bu telefonda, başka hiçbir yerde.';

  @override
  String get onboardingNoServerTitle => 'Üyelik yok, sunucu yok';

  @override
  String get onboardingNoServerBody =>
      'Hiçbir şey yüklenmez ve giriş yapılacak bir yer yoktur. Veriler, yalnızca bu uygulamanın okuyabildiği bir dosyada durur.';

  @override
  String get onboardingSameFileTitle => 'Masaüstü uygulamasıyla aynı dosya';

  @override
  String get onboardingSameFileBody =>
      'Birinde alınan yedek, diğerinde kuruşuna kadar açılır.';

  @override
  String get onboardingBackupsTitle => 'Yani yedekler sana kalmış';

  @override
  String get onboardingBackupsBody =>
      'Yedek almadan telefonu kaybedersen veriler de onunla gider. Kimsede başka bir kopya yok.';

  @override
  String get onboardingEncryptedTitle => 'Verilerin şifreli';

  @override
  String get onboardingEncryptedBody =>
      'Her tutar ve açıklama şifreli olarak saklanır. Bunları açan anahtar, verilerden ayrı tutulur.';

  @override
  String get onboardingKeyUnknownTitle => 'Anahtarın yeri bilinmiyor';

  @override
  String get onboardingKeyUnknownBody =>
      'Bu derleme, anahtarın nereye yazıldığını söyleyemedi.';

  @override
  String get onboardingKeySecureBody =>
      'İşletim sistemi tarafından tutuluyor. Bu cihazdan hiç çıkmaz ve başka hiçbir uygulama okuyamaz.';

  @override
  String get onboardingKeyFileBody =>
      'İşletim sisteminin anahtar deposu kullanılamadı; bu yüzden anahtar, yalnızca bu uygulamanın açabildiği bir dosya. Bu, anahtar deposundan daha zayıf ve bilinmesi gereken bir şey.';

  @override
  String get onboardingAccountTitle => 'Paran nerede duruyor?';

  @override
  String get onboardingAccountBody =>
      'Başlangıç için bir nakit hesap. Diğer her şey — harcamalar, kartlar, varlıklar, hedefler — paranın geleceği bir yer ister.';

  @override
  String get onboardingDefaultAccountName => 'Nakit';

  @override
  String get onboardingAccountName => 'Ad';

  @override
  String get onboardingAccountBalance => 'Şu anda içinde ne var';

  @override
  String get onboardingBalanceOptional =>
      'Burayı boş bırakıp sonra ekleyebilirsin.';

  @override
  String get onboardingSettingUp => 'Hazırlanıyor…';

  @override
  String get onboardingStart => 'Archlence’i kullanmaya başla';

  @override
  String get addAccountTitle => 'Yeni hesap';

  @override
  String get accountTypeCash => 'Nakit';

  @override
  String get accountTypeCreditCard => 'Kredi kartı';

  @override
  String get addAccountName => 'Ad';

  @override
  String get addAccountNameHintCard => 'Bonus Flexi';

  @override
  String get addAccountNameHintCash => 'Maaş hesabı';

  @override
  String get addAccountCurrentDebt => 'Mevcut borç';

  @override
  String get addAccountOpeningBalance => 'Açılış bakiyesi';

  @override
  String get addAccountCardLimit => 'Kart limiti';

  @override
  String get addAccountStatementDay => 'Hesap kesim günü (opsiyonel)';

  @override
  String get addAccountCardNumber => 'Kart numarası (opsiyonel)';

  @override
  String get addAccountCardNumberNote =>
      'Yalnızca son dört hane ve kartın ağı saklanır. Numaranın kendisi hiçbir zaman saklanmaz.';

  @override
  String get addAccountAction => 'Hesabı ekle';

  @override
  String get addTransactionTitle => 'Yeni işlem';

  @override
  String get transactionTypeExpense => 'Gider';

  @override
  String get transactionTypeIncome => 'Gelir';

  @override
  String get errEnterAnAmount => 'Bir tutar gir.';

  @override
  String get addTransactionNoAccount =>
      'Önce bir hesap ekle — paranın bir yerden gelmesi gerekir.';

  @override
  String get fieldAccount => 'Hesap';

  @override
  String get fieldAmount => 'Tutar';

  @override
  String get fieldCategory => 'Kategori';

  @override
  String get fieldDescriptionOptional => 'Açıklama (opsiyonel)';

  @override
  String get fieldInstallments => 'Taksit';

  @override
  String get installmentsNone => 'Yok';

  @override
  String installmentMonths(int count) {
    return '$count ay';
  }

  @override
  String get installmentNote =>
      'Tutarın tamamı karta şimdi yazılır — bankanın limitinden bloke ettiği budur. Plan yalnızca aylık dağılımı izler.';

  @override
  String get transactionScheduledNote =>
      'İleri tarihli — o güne kadar bakiyene dokunmaz.';

  @override
  String get addTransactionAction => 'Kaydet';

  @override
  String payDebtTitle(String card) {
    return '$card borcunu öde';
  }

  @override
  String get payDebtAction => 'Öde';

  @override
  String payDebtOwing(String amount) {
    return 'Kalan borç: $amount';
  }

  @override
  String get payDebtAmount => 'Ödenecek tutar';

  @override
  String payDebtAll(String amount) {
    return 'Tamamını öde ($amount)';
  }

  @override
  String get payDebtNoSource => 'Ödeme yapılacak nakit hesap yok.';

  @override
  String get payDebtFrom => 'Ödeme kaynağı';

  @override
  String get payDebtFrozenNote =>
      'Bu kart donduruldu ama yine de ödenebilir. Dondurma yeni harcamayı durdurur, borcunu kapatmanı değil.';

  @override
  String get errChooseSource => 'Paranın nereden geleceğini seç.';

  @override
  String accountWithBalance(String name, String balance) {
    return '$name — $balance';
  }

  @override
  String get subscriptionFallbackName => 'Abonelik';

  @override
  String get subscriptionNoLongerActive => 'Bu abonelik artık aktif değil.';

  @override
  String get errEnterNewPrice => 'Yeni ücreti gir.';

  @override
  String get subscriptionSavePrice => 'Yeni ücreti kaydet';

  @override
  String subscriptionNextOn(String date) {
    return 'Sıradaki: $date';
  }

  @override
  String get subscriptionPrice => 'Ücret';

  @override
  String get subscriptionPriceNote =>
      'Ücreti değiştirmek takvimi olduğu yerde bırakır.';

  @override
  String get subscriptionSkip => 'Sıradakini atla';

  @override
  String get subscriptionSkipNote =>
      'Bir dönem ileri alır. Abonelik çalışmaya devam eder.';

  @override
  String get subscriptionStop => 'Takibi durdur';

  @override
  String get subscriptionStopNote =>
      'Tamamen durdurur. Geçmiş ödemeler geçmişinde kalır.';

  @override
  String get subscriptionStopTitle => 'Takip durdurulsun mu?';

  @override
  String subscriptionStopBody(String name) {
    return '$name artık takip edilmeyecek. Kaydedilmiş ödemeler oldukları yerde kalır.';
  }

  @override
  String get subscriptionStopFallbackName => 'Bu abonelik';

  @override
  String get subscriptionKeep => 'Vazgeç';

  @override
  String get subscriptionStopConfirm => 'Durdur';

  @override
  String get budgetLineTitle => 'Yeni bütçe kalemi';

  @override
  String get budgetLineAction => 'Kalemi kaydet';

  @override
  String get budgetLineName => 'Ad';

  @override
  String get budgetLineNameHint => 'Kira';

  @override
  String get budgetLineAmount => 'Bu ayın tutarı';

  @override
  String get fieldCategoryOptional => 'Kategori (opsiyonel)';

  @override
  String get categoryNone => 'Yok';

  @override
  String get budgetLineCategoryNote =>
      'Yalnızca kategorisi olan bir kalem, gerçekte harcadığına karşı izlenir.';

  @override
  String get budgetLineEveryMonth => 'Her ay';

  @override
  String get budgetLineEveryMonthNote =>
      'Bir ay için farklı bir tutar belirleyene kadar her aya uygulanır.';

  @override
  String get budgetLineRollover => 'Kalanı devret';

  @override
  String get budgetLineRolloverNote =>
      'Geçen aydan kalanı bu ayın limitine ekler. Yalnızca geçen ayınkini — birikmez.';

  @override
  String budgetLineWarnAt(String threshold) {
    return '$threshold olunca uyar';
  }

  @override
  String get newGoalTitle => 'Yeni birikim hedefi';

  @override
  String get newGoalAction => 'Hedefi oluştur';

  @override
  String get newGoalExplanation =>
      'Bir hedefteki para bakiyenden ayrılır. Harcama değildir ve hiçbir gider grafiğinde görünmez.';

  @override
  String get newGoalName => 'Ne için';

  @override
  String get newGoalNameHint => 'Acil Durum Fonu';

  @override
  String get newGoalTarget => 'Hedef tutar';

  @override
  String get errEnterTargetAmount => 'Bir hedef tutar gir.';

  @override
  String get errChooseCashAccount => 'Bir nakit hesap seç.';

  @override
  String get goalFallbackName => 'Birikim hedefi';

  @override
  String get goalSetAside => 'Ayır';

  @override
  String goalProgress(String saved, String target) {
    return '$saved biriktirildi, hedef $target';
  }

  @override
  String goalProgressWithRemaining(
    String saved,
    String target,
    String remaining,
  ) {
    return '$saved biriktirildi, hedef $target — $remaining kaldı';
  }

  @override
  String get goalMoveNoAccount => 'Para taşınacak bir nakit hesap yok.';

  @override
  String get goalMoveFrom => 'Kaynak hesap';

  @override
  String get goalMoveInto => 'Hedef hesap';

  @override
  String get goalMayGoNegative =>
      'Hesabın eksiye düşebilir — Archlence seni durdurmaz.';

  @override
  String get errEnterPriceAndQuantity => 'Bir fiyat ve bir adet gir.';

  @override
  String get errChooseDestination => 'Paranın nereye gideceğini seç.';

  @override
  String get buyAssetTitle => 'Yeni varlık';

  @override
  String get buyAssetAction => 'Varlığı ekle';

  @override
  String get assetName => 'Ad';

  @override
  String get assetNameHint => 'Gram Altın';

  @override
  String get assetCode => 'Kod';

  @override
  String get assetKind => 'Tür';

  @override
  String get assetUnitPrice => 'Birim fiyat';

  @override
  String get assetQuantity => 'Adet';

  @override
  String assetTotalIs(String total) {
    return 'Toplam $total eder.';
  }

  @override
  String get assetAlreadyOwned => 'Bu zaten bende vardı';

  @override
  String get assetAlreadyOwnedNote =>
      'Varlığı, parayı bir hesaptan düşmeden kaydeder.';

  @override
  String get assetNoCashAccount =>
      'Ödeme yapılacak nakit hesap yok. Bir tane ekle ya da bunu zaten sahip olduğun bir şey olarak kaydet.';

  @override
  String get assetPayFrom => 'Ödeme kaynağı';

  @override
  String get assetChooseForMe => 'Benim için seç';

  @override
  String sellAssetTitle(String name) {
    return '$name sat';
  }

  @override
  String get sellAssetAction => 'Sat';

  @override
  String sellAssetHoldingLine(String quantity, String price) {
    return 'Elinde $quantity var, birimi $price alınmış.';
  }

  @override
  String get sellAssetPrice => 'Birim satış fiyatı';

  @override
  String get sellAssetQuantity => 'Satılacak adet';

  @override
  String sellAssetOutcome(String proceeds, String cost, String gain) {
    return 'Giren $proceeds, maliyet $cost — $gain.';
  }

  @override
  String get sellAssetNoAccount => 'Paranın yatırılacağı hesap yok.';

  @override
  String get sellAssetPayInto => 'Yatırılacak hesap';

  @override
  String get homeActiveSubscriptions => 'Aktif Aboneliklerim';

  @override
  String get homeNetWorth => 'Net Servet';

  @override
  String get homeCash => 'Nakit';

  @override
  String get homeCardDebt => 'Kart Borcu';

  @override
  String get homeNoSubscriptions =>
      'Henüz tekrarlanan bir şey yok. Kartla ödenen bir abonelik kendiliğinden fark edilir ve buraya düşer.';

  @override
  String get homeSearchDisabled => 'Arama — henüz yok';

  @override
  String get homeMyWallet => 'Cüzdanım';

  @override
  String get homeForecastTitle => 'Algoritmik Öngörü';

  @override
  String get homeForecastPending =>
      'Harcama eğilimleri ve ay sonu projeksiyonu, içgörü ve projeksiyon servisleriyle birlikte gelecek.';

  @override
  String get homeHealthScoreTitle => 'Finansal Sağlık Skoru';

  @override
  String get homeHealthScorePending =>
      'Skorlama için tasarruf oranı, borç/gelir ve gider oynaklığı gerekir; bunları metrik servisi sağlayacak.';

  @override
  String get subscriptionUnreadableName => 'Okunamayan abonelik';

  @override
  String get amountUnreadable => 'okunamadı';

  @override
  String get subscriptionManage => 'YÖNET';

  @override
  String get budgetTitle => 'Aylık Bütçe';

  @override
  String get budgetCategories => 'Kategoriler';

  @override
  String get budgetPlannedIncome => 'Planlanan Gelir';

  @override
  String get budgetPlannedExpense => 'Planlanan Gider';

  @override
  String get budgetReserved => 'Ayrılan';

  @override
  String get budgetLeftToSpend => 'Harcanabilir kalan';

  @override
  String get budgetLeftToSpendNote =>
      'Planlanan gelirden planlanan gider ve aboneliklerinin götüreceği tutar düşülmüş hâli.';

  @override
  String get budgetReservedForSubscriptions => 'Aboneliklere ayrılan';

  @override
  String budgetOccurrences(int count) {
    return '×$count';
  }

  @override
  String get budgetNoCategoryPlans =>
      'Bu ay için henüz kategori planı yok. Bir plan, her kategoriye bir limit verir ve ondan ne kaldığını izler.';

  @override
  String get budgetSpent => 'Harcanan';

  @override
  String get budgetOverBy => 'Aşım';

  @override
  String get budgetLeft => 'Kalan';

  @override
  String get monthShortJan => 'Oca';

  @override
  String get monthShortFeb => 'Şub';

  @override
  String get monthShortMar => 'Mar';

  @override
  String get monthShortApr => 'Nis';

  @override
  String get monthShortMay => 'May';

  @override
  String get monthShortJun => 'Haz';

  @override
  String get monthShortJul => 'Tem';

  @override
  String get monthShortAug => 'Ağu';

  @override
  String get monthShortSep => 'Eyl';

  @override
  String get monthShortOct => 'Eki';

  @override
  String get monthShortNov => 'Kas';

  @override
  String get monthShortDec => 'Ara';

  @override
  String get backupTitle => 'Yedekle ve Geri Yükle';

  @override
  String get backupNoProfile =>
      'Bu derlemenin diskte bir profili yok, dolayısıyla yedeklenecek bir şey de yok.';

  @override
  String get backupSectionCreate => 'Yedek al';

  @override
  String get backupCreateExplanation =>
      'Bir yedek, veritabanının tamamını ve onu açan anahtarı, senin seçtiğin bir parolayla sarmalanmış hâlde tutar. En az on iki karakter.\n\nPAROLA HİÇBİR YERDE SAKLANMAZ. Parola olmadan yedek açılamaz — bu uygulama tarafından da, başka kimse tarafından da.';

  @override
  String get backupPassphrase => 'Parola';

  @override
  String get backupPassphraseAgain => 'Parola tekrar';

  @override
  String get backupCreateAction => 'Yedek oluştur ve paylaş';

  @override
  String get backupCreateBusy =>
      'Anahtar sarmalanıyor. Bu birkaç saniye sürer — parolayı denemek bilerek yavaştır.';

  @override
  String get backupShareSubject => 'Archlence yedeği';

  @override
  String get backupFileTypeLabel => 'Archlence yedeği';

  @override
  String backupCreated(int records) {
    return 'Yedek yazıldı ve doğrulandı: paylaşılmadan önce $records şifreli kayıt, içindeki anahtarla açıldı.';
  }

  @override
  String get backupSectionRestore => 'Yedekten geri yükle';

  @override
  String get backupRestoreExplanation =>
      'Bu uygulamadaki her şeyi, şifreleme anahtarı dahil, dosyadakiyle değiştirir. Masaüstü uygulamasının yazdığı bir yedek burada da çalışır.\n\nŞu anda burada olan, aynı parolayla önce kendi yedeğine yazılır.';

  @override
  String get backupRestorePassphrase => 'Yedeğin parolası';

  @override
  String get backupRestoreAction => 'Bir dosya seç ve geri yükle';

  @override
  String get backupRestoreConfirmButton => 'Geri yükle';

  @override
  String get backupRestoreBusy =>
      'Yedek doğrulanıyor ve verilerin değiştiriliyor. Uygulamayı kapatma.';

  @override
  String get backupRestoreConfirmTitle =>
      'Bu uygulamadaki her şey değiştirilsin mi?';

  @override
  String get backupRestoreConfirmBody =>
      'Bu telefondaki her hesap, işlem, varlık, bütçe ve hedef, yedektekiyle değiştirilir.\n\nŞu anda burada olan, aynı parolayla önce kendi yedeğine yazılır ve uygulama sana adını söyler.';

  @override
  String get commonCancel => 'Vazgeç';

  @override
  String get backupReplaceConfirm => 'Değiştir';

  @override
  String get backupRestoredNothingBefore =>
      'Geri yüklendi. Öncesinde burada bir şey yoktu, bu yüzden kenara ayrılan da olmadı.';

  @override
  String backupRestoredWithSafety(String file) {
    return 'Geri yüklendi. Önceden burada olan, önce bu uygulamanın kendi alanındaki $file dosyasına yazıldı.';
  }

  @override
  String get backupPassphrasesDiffer => 'İki parola aynı değil.';

  @override
  String get backupWrongPassphrase => 'Bu parola bu yedeği açmıyor.';

  @override
  String get backupFileUnusable => 'Bu dosya yedek olarak kullanılamaz.';

  @override
  String get backupRestoreRolledBack =>
      'Geri yükleme başarısız oldu ve verilerin olduğu gibi geri kondu.';

  @override
  String get backupInterrupted =>
      'Yarım kalmış bir geri yükleme bulundu ve geri alınamadı.';

  @override
  String get backupKeyUnavailable =>
      'Şifreleme anahtarı okunamadı ya da değiştirilemedi.';

  @override
  String get backupUnexpected => 'Bir şeyler ters gitti.';

  @override
  String get cardsMyCards => 'Kartlarım';

  @override
  String get cardsAdd => '+  EKLE';

  @override
  String get cardsNoCards =>
      'Henüz kredi kartı yok. Limitini ve borcunu burada izlemek için bir tane ekle.';

  @override
  String get cardsMyAccounts => 'Hesaplarım';

  @override
  String get cardsActiveAssets => 'Aktif Varlıklarım';

  @override
  String cardsHoldingsMeta(int count) {
    return '$count varlık · maliyetiyle';
  }

  @override
  String get cardsNoCashAccounts =>
      'Henüz nakit hesap yok. Archlence’teki her şeyin, para giriş çıkışı için bir tanesine ihtiyacı var.';

  @override
  String get cardsCashChecking => 'Nakit / Vadesiz';

  @override
  String get cardsCreditCardBadge => 'KREDİ KARTI';

  @override
  String get cardsAvailableLimit => 'Kullanılabilir Limit';

  @override
  String get cardsCurrentDebt => 'Mevcut Borç';

  @override
  String get cardsControls => 'Kart Kontrolleri';

  @override
  String get cardsOnlineShopping => 'İnternet Alışverişi Tercihi';

  @override
  String get cardsOnlineShoppingNote => 'Yalnızca bir tercih olarak saklanır';

  @override
  String get cardsFreeze => 'Kartı Dondur';

  @override
  String get cardsFreezeNote => 'Yeni harcamayı engeller, borç ödemesini değil';

  @override
  String get cardsRecentTransactions => 'Son İşlemler';

  @override
  String get cardsStatement => 'Ekstre';

  @override
  String get cardsPayDebt => 'Borç Öde';

  @override
  String get cardsNothingOnCard => 'Bu kartta henüz bir hareket yok.';

  @override
  String get periodToday => 'Bugün';

  @override
  String get periodWeek => '1 Hafta';

  @override
  String get periodMonth => '1 Ay';

  @override
  String get periodYear => '1 Yıl';

  @override
  String get periodAllTime => 'Hayat Boyu';

  @override
  String get assetsDetails => 'Detaylar';

  @override
  String get assetsIncome => 'Gelir';

  @override
  String get assetsExpense => 'Gider';

  @override
  String get assetsNetBalance => 'Net Bakiye';

  @override
  String get assetsMyActiveAssets => 'Aktif Varlıklarım';

  @override
  String get assetsAtCostNote =>
      'Alış maliyeti üzerinden — henüz fiyat kaynağı yok';

  @override
  String get assetsNoHoldings =>
      'Henüz varlık yok. Aldığın her şey, maliyetiyle birlikte burada görünür.';

  @override
  String get assetsOpeningBalance => 'Açılış Bakiyesi';

  @override
  String get assetsNoDistribution =>
      'Bu dönemde para hareket etmedi, dolayısıyla çizilecek bir dağılım da yok.';

  @override
  String get assetsDistributionTitle => 'Varlık';

  @override
  String get assetsDistributionSubtitle => 'Dağılımı';

  @override
  String get assetsNoTrend =>
      'Son bir yılda gelir ya da gider yok, dolayısıyla çizilecek bir eğilim de yok.';

  @override
  String get assetsHoldingsAtCost => 'Varlıklar (Maliyet)';

  @override
  String get assetsNothingBought => 'Henüz bir şey alınmadı';

  @override
  String assetsHoldingCount(int count) {
    return '$count varlık';
  }

  @override
  String get assetsNoGoals =>
      'Henüz birikim hedefi yok. Bir hedef, harcama sayılmadan parayı bakiyenden ayrı tutar.';

  @override
  String assetsHoldingName(String name, String code) {
    return '$name ($code)';
  }

  @override
  String assetsPurchaseLine(String price, String quantity) {
    return 'Alış: $price × $quantity';
  }

  @override
  String get assetsCost => 'Maliyet';

  @override
  String monthYearShort(String month, String year) {
    return '$month\'$year';
  }
}
