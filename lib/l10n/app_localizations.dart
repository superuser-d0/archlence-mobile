import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// The application's name. Not translated.
  ///
  /// In en, this message translates to:
  /// **'Archlence'**
  String get appTitle;

  /// Bottom navigation: the dashboard tab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation: holdings.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get navAssets;

  /// Bottom navigation: accounts and credit cards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get navCards;

  /// Bottom navigation: budget, savings, backup.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get navTools;

  /// Bottom navigation: settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Shown full-screen when the database or key store will not open.
  ///
  /// In en, this message translates to:
  /// **'Archlence could not start'**
  String get startUpFailed;

  /// Chip on a control that has no service behind it yet. Deliberately not 'coming soon' — it states a fact rather than making a promise.
  ///
  /// In en, this message translates to:
  /// **'NOT YET'**
  String get notYetChip;

  /// Stands in for a figure whose source threw, so a failure is never drawn as a zero.
  ///
  /// In en, this message translates to:
  /// **'This could not be read'**
  String get couldNotBeRead;

  /// The label inside the dashboard's balance ring.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get totalBalance;

  /// A sheet's action button while the write is in flight.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get savingInProgress;

  /// Heading of the Tools tab.
  ///
  /// In en, this message translates to:
  /// **'Financial Tools'**
  String get toolsTitle;

  /// No description provided for @toolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore calculators and planners to optimize your finances.'**
  String get toolsSubtitle;

  /// Tool card. The line break is part of the label: the grid gives every card two lines.
  ///
  /// In en, this message translates to:
  /// **'Monthly\nBudget'**
  String get toolBudget;

  /// No description provided for @toolCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get toolCalendar;

  /// No description provided for @toolCalculator.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get toolCalculator;

  /// No description provided for @toolInterestReturn.
  ///
  /// In en, this message translates to:
  /// **'Interest\nReturn'**
  String get toolInterestReturn;

  /// No description provided for @toolCompoundInterest.
  ///
  /// In en, this message translates to:
  /// **'Compound\nInterest'**
  String get toolCompoundInterest;

  /// No description provided for @toolLoanCalculator.
  ///
  /// In en, this message translates to:
  /// **'Loan\nCalculator'**
  String get toolLoanCalculator;

  /// No description provided for @toolSavingsGoal.
  ///
  /// In en, this message translates to:
  /// **'Savings\nGoal'**
  String get toolSavingsGoal;

  /// Kept in English in both languages, as the desktop does.
  ///
  /// In en, this message translates to:
  /// **'What-If\nSandbox'**
  String get toolWhatIf;

  /// No description provided for @toolResetData.
  ///
  /// In en, this message translates to:
  /// **'Reset\nData'**
  String get toolResetData;

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Archlence is locked'**
  String get lockedTitle;

  /// No description provided for @lockedExplanation.
  ///
  /// In en, this message translates to:
  /// **'Unlock with the same fingerprint or PIN you use for this phone.'**
  String get lockedExplanation;

  /// No description provided for @lockedRefused.
  ///
  /// In en, this message translates to:
  /// **'Not unlocked.'**
  String get lockedRefused;

  /// No description provided for @lockedWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting…'**
  String get lockedWaiting;

  /// No description provided for @lockedUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get lockedUnlock;

  /// Reason shown by the platform's own biometric/PIN sheet.
  ///
  /// In en, this message translates to:
  /// **'Unlock Archlence'**
  String get unlockPrompt;

  /// No description provided for @savingsGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings Goals'**
  String get savingsGoalsTitle;

  /// No description provided for @savingsGoalsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Money in a goal is held aside from your balance. It is not spending, so it never appears in any expense chart.'**
  String get savingsGoalsExplanation;

  /// No description provided for @savingsGoalsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No savings goals yet. Add one with the + above.'**
  String get savingsGoalsEmpty;

  /// Stands in for a goal name that will not decrypt.
  ///
  /// In en, this message translates to:
  /// **'Unreadable goal'**
  String get goalUnreadable;

  /// How much is in the goal so far.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get goalSaved;

  /// No description provided for @goalTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get goalTarget;

  /// Withdraw from a completed goal.
  ///
  /// In en, this message translates to:
  /// **'Take back'**
  String get goalTakeBack;

  /// Put money INTO the goal — not the verb for saving a form.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get goalPutIn;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account & Preferences'**
  String get settingsSectionAccount;

  /// No description provided for @settingsCategorySettings.
  ///
  /// In en, this message translates to:
  /// **'Category Settings'**
  String get settingsCategorySettings;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Shown as the Language row's subtitle when no explicit choice has been made and the app follows the phone.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsEncryptionKey.
  ///
  /// In en, this message translates to:
  /// **'Encryption Key'**
  String get settingsEncryptionKey;

  /// The name of the OS key store. A product name, so it is the same in both languages.
  ///
  /// In en, this message translates to:
  /// **'Android Keystore'**
  String get keyMethodAndroidKeystore;

  /// No description provided for @keyMethodOwnerOnlyFile.
  ///
  /// In en, this message translates to:
  /// **'owner-only file'**
  String get keyMethodOwnerOnlyFile;

  /// No platform key provider behind this build — it must say it does not know rather than assume the best case.
  ///
  /// In en, this message translates to:
  /// **'Not known in this build.'**
  String get keyProtectionUnknown;

  /// No description provided for @keyProtectionHeldByOs.
  ///
  /// In en, this message translates to:
  /// **'{method} — held by the operating system.'**
  String keyProtectionHeldByOs(String method);

  /// No description provided for @keyProtectionLocalFile.
  ///
  /// In en, this message translates to:
  /// **'{method} — NOT in an OS key store; the key is a local file readable only by this app.'**
  String keyProtectionLocalFile(String method);

  /// No description provided for @keyWarningOsStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The OS key store is unavailable; the key is kept in a local file readable only by this app.'**
  String get keyWarningOsStoreUnavailable;

  /// No description provided for @keyWarningNoPlatformStore.
  ///
  /// In en, this message translates to:
  /// **'This platform has no supported OS key store.'**
  String get keyWarningNoPlatformStore;

  /// No description provided for @settingsSectionSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSectionSecurity;

  /// No description provided for @lockTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock when I come back'**
  String get lockTileTitle;

  /// No description provided for @lockTileExplanation.
  ///
  /// In en, this message translates to:
  /// **'Asks for your fingerprint or PIN after a minute away. It hides the screen from someone holding your phone — it does not add encryption.'**
  String get lockTileExplanation;

  /// No description provided for @lockTileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device has no fingerprint or screen lock set up.'**
  String get lockTileUnavailable;

  /// No description provided for @settingsSectionYourData.
  ///
  /// In en, this message translates to:
  /// **'Your Data'**
  String get settingsSectionYourData;

  /// No description provided for @settingsBackupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupRestore;

  /// No description provided for @settingsBackupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available in this build.'**
  String get settingsBackupUnavailable;

  /// No description provided for @settingsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write a backup you can keep, or restore one — including a backup made by the desktop app.'**
  String get settingsBackupSubtitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance & Privacy'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsPremiumTheme.
  ///
  /// In en, this message translates to:
  /// **'Premium Blue Theme'**
  String get settingsPremiumTheme;

  /// No description provided for @settingsPremiumThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uses the standard theme when disabled'**
  String get settingsPremiumThemeSubtitle;

  /// No description provided for @settingsDataPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Data & Privacy'**
  String get settingsDataPrivacy;

  /// No description provided for @settingsSectionSecurityHistory.
  ///
  /// In en, this message translates to:
  /// **'Security & History'**
  String get settingsSectionSecurityHistory;

  /// No description provided for @settingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get settingsChangePassword;

  /// No description provided for @settingsChangePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can renew your password here.'**
  String get settingsChangePasswordSubtitle;

  /// No description provided for @settingsBalanceHistory.
  ///
  /// In en, this message translates to:
  /// **'Balance History'**
  String get settingsBalanceHistory;

  /// No description provided for @settingsSectionSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsSectionSystem;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsDarkModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Obsidian Prime is dark-only for now'**
  String get settingsDarkModeSubtitle;

  /// No description provided for @settingsContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get settingsContactUs;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settingsSignOut;

  /// Shared by every service that parses a typed figure.
  ///
  /// In en, this message translates to:
  /// **'That is not an amount.'**
  String get errNotAnAmount;

  /// No description provided for @errAmountNotPositive.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above zero.'**
  String get errAmountNotPositive;

  /// No description provided for @errAccountEmptyName.
  ///
  /// In en, this message translates to:
  /// **'Give the account a name.'**
  String get errAccountEmptyName;

  /// No description provided for @errAccountUnknownType.
  ///
  /// In en, this message translates to:
  /// **'Choose an account type.'**
  String get errAccountUnknownType;

  /// No description provided for @errAccountInvalidStatementDay.
  ///
  /// In en, this message translates to:
  /// **'The statement day has to be between 1 and 31.'**
  String get errAccountInvalidStatementDay;

  /// No description provided for @errAccountCreditLimitRequired.
  ///
  /// In en, this message translates to:
  /// **'A credit card needs a limit above zero.'**
  String get errAccountCreditLimitRequired;

  /// No description provided for @errAccountNegativeOpeningDebt.
  ///
  /// In en, this message translates to:
  /// **'Debt cannot be a negative amount.'**
  String get errAccountNegativeOpeningDebt;

  /// No description provided for @errAccountOpeningDebtExceedsLimit.
  ///
  /// In en, this message translates to:
  /// **'The debt is larger than the limit you entered.'**
  String get errAccountOpeningDebtExceedsLimit;

  /// No description provided for @errAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'That account no longer exists.'**
  String get errAccountNotFound;

  /// No description provided for @errAccountCardFrozen.
  ///
  /// In en, this message translates to:
  /// **'This card is frozen. Unfreeze it to spend on it.'**
  String get errAccountCardFrozen;

  /// No description provided for @errAccountInsufficientLimit.
  ///
  /// In en, this message translates to:
  /// **'That would go past the card\'s available limit.'**
  String get errAccountInsufficientLimit;

  /// No description provided for @errAccountNotACreditCard.
  ///
  /// In en, this message translates to:
  /// **'That is not a credit card.'**
  String get errAccountNotACreditCard;

  /// No description provided for @errAccountNoDebtToPay.
  ///
  /// In en, this message translates to:
  /// **'There is nothing owing on this card.'**
  String get errAccountNoDebtToPay;

  /// No description provided for @errAccountPaymentExceedsDebt.
  ///
  /// In en, this message translates to:
  /// **'That is more than the card owes.'**
  String get errAccountPaymentExceedsDebt;

  /// No description provided for @errAccountSourceMustBeChecking.
  ///
  /// In en, this message translates to:
  /// **'Pay a card from a cash account, not another card.'**
  String get errAccountSourceMustBeChecking;

  /// No description provided for @errAccountBalanceUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'The balance could not be updated. Nothing was changed.'**
  String get errAccountBalanceUpdateFailed;

  /// No description provided for @errAccountUnknownCardPreference.
  ///
  /// In en, this message translates to:
  /// **'Unknown card setting.'**
  String get errAccountUnknownCardPreference;

  /// No description provided for @errTransactionInstallmentRange.
  ///
  /// In en, this message translates to:
  /// **'Instalments have to be between 1 and 12.'**
  String get errTransactionInstallmentRange;

  /// No description provided for @errTransactionNegativeLimit.
  ///
  /// In en, this message translates to:
  /// **'The limit cannot be negative.'**
  String get errTransactionNegativeLimit;

  /// No description provided for @errAssetInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Price and quantity both have to be numbers above zero.'**
  String get errAssetInvalidAmount;

  /// No description provided for @errAssetNotFound.
  ///
  /// In en, this message translates to:
  /// **'That holding no longer exists.'**
  String get errAssetNotFound;

  /// No description provided for @errSavingsEmptyName.
  ///
  /// In en, this message translates to:
  /// **'Say what the goal is for.'**
  String get errSavingsEmptyName;

  /// No description provided for @errSavingsNegativeOpeningAmount.
  ///
  /// In en, this message translates to:
  /// **'A goal cannot start with less than nothing in it.'**
  String get errSavingsNegativeOpeningAmount;

  /// The one error here that has to explain rather than name: a stale card pointing at a reused id is not something a user can reason about, and the only thing that matters is that no money moved.
  ///
  /// In en, this message translates to:
  /// **'This goal has changed since the screen was drawn. Nothing was moved — pull to refresh and try again.'**
  String get errSavingsIdentityMismatch;

  /// No description provided for @errSavingsAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'That cash account no longer exists.'**
  String get errSavingsAccountNotFound;

  /// No description provided for @errSavingsGoalNotFoundOrCompleted.
  ///
  /// In en, this message translates to:
  /// **'This goal is already complete.'**
  String get errSavingsGoalNotFoundOrCompleted;

  /// No description provided for @errSavingsInsufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'The goal does not hold that much.'**
  String get errSavingsInsufficientBalance;

  /// No description provided for @errSavingsRefundAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose where the money should go.'**
  String get errSavingsRefundAccountRequired;

  /// No description provided for @errBudgetUnknownItemType.
  ///
  /// In en, this message translates to:
  /// **'Choose income or expense.'**
  String get errBudgetUnknownItemType;

  /// No description provided for @errBudgetEmptyName.
  ///
  /// In en, this message translates to:
  /// **'Give the line a name.'**
  String get errBudgetEmptyName;

  /// No description provided for @errBudgetInvalidMonth.
  ///
  /// In en, this message translates to:
  /// **'Pick a month between January and December.'**
  String get errBudgetInvalidMonth;

  /// No description provided for @errBudgetInvalidAlertThreshold.
  ///
  /// In en, this message translates to:
  /// **'The alert threshold has to be between 1 and 100 per cent.'**
  String get errBudgetInvalidAlertThreshold;

  /// No description provided for @errRecurringUnknownFrequency.
  ///
  /// In en, this message translates to:
  /// **'This subscription repeats on a schedule Archlence does not recognise.'**
  String get errRecurringUnknownFrequency;

  /// No description provided for @errRecurringInvalidDay.
  ///
  /// In en, this message translates to:
  /// **'The day of the month has to be between 1 and 31.'**
  String get errRecurringInvalidDay;

  /// No description provided for @errRecurringInvalidTransactionType.
  ///
  /// In en, this message translates to:
  /// **'A subscription has to be income or expense.'**
  String get errRecurringInvalidTransactionType;

  /// No description provided for @errRecurringUnreadablePayment.
  ///
  /// In en, this message translates to:
  /// **'This subscription could not be read.'**
  String get errRecurringUnreadablePayment;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @onboardingTagline.
  ///
  /// In en, this message translates to:
  /// **'Your accounts, cards, holdings and budget — on this phone and nowhere else.'**
  String get onboardingTagline;

  /// No description provided for @onboardingNoServerTitle.
  ///
  /// In en, this message translates to:
  /// **'No account, no server'**
  String get onboardingNoServerTitle;

  /// No description provided for @onboardingNoServerBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing is uploaded and there is nothing to sign in to. The data lives in a file only this app can read.'**
  String get onboardingNoServerBody;

  /// No description provided for @onboardingSameFileTitle.
  ///
  /// In en, this message translates to:
  /// **'The same file as the desktop app'**
  String get onboardingSameFileTitle;

  /// No description provided for @onboardingSameFileBody.
  ///
  /// In en, this message translates to:
  /// **'A backup written on one opens in the other, down to the kurus.'**
  String get onboardingSameFileBody;

  /// No description provided for @onboardingBackupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Which means backups are on you'**
  String get onboardingBackupsTitle;

  /// No description provided for @onboardingBackupsBody.
  ///
  /// In en, this message translates to:
  /// **'If you lose the phone without a backup, the data goes with it. Nobody else has a copy.'**
  String get onboardingBackupsBody;

  /// No description provided for @onboardingEncryptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data is encrypted'**
  String get onboardingEncryptedTitle;

  /// No description provided for @onboardingEncryptedBody.
  ///
  /// In en, this message translates to:
  /// **'Every amount and description is stored encrypted. The key that opens them is kept apart from the data.'**
  String get onboardingEncryptedBody;

  /// No description provided for @onboardingKeyUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Key location unknown'**
  String get onboardingKeyUnknownTitle;

  /// No description provided for @onboardingKeyUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'This build could not tell where the key ended up.'**
  String get onboardingKeyUnknownBody;

  /// No description provided for @onboardingKeySecureBody.
  ///
  /// In en, this message translates to:
  /// **'Held by the operating system. It never leaves this device and no other app can read it.'**
  String get onboardingKeySecureBody;

  /// No description provided for @onboardingKeyFileBody.
  ///
  /// In en, this message translates to:
  /// **'The OS key store was not available, so the key is a file only this app can open. That is weaker than the key store, and worth knowing.'**
  String get onboardingKeyFileBody;

  /// No description provided for @onboardingAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Where does your money sit?'**
  String get onboardingAccountTitle;

  /// No description provided for @onboardingAccountBody.
  ///
  /// In en, this message translates to:
  /// **'One cash account to start with. Everything else — spending, cards, holdings, goals — needs somewhere for money to come from.'**
  String get onboardingAccountBody;

  /// Prefilled into the first account's name field. Translated even though it becomes stored DATA, because it is a suggestion the user types over and nothing in either app groups or reports on an account's name — unlike the category literals, which stay verbatim.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get onboardingDefaultAccountName;

  /// No description provided for @onboardingAccountName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get onboardingAccountName;

  /// No description provided for @onboardingAccountBalance.
  ///
  /// In en, this message translates to:
  /// **'What is in it now'**
  String get onboardingAccountBalance;

  /// No description provided for @onboardingBalanceOptional.
  ///
  /// In en, this message translates to:
  /// **'You can leave this empty and add it later.'**
  String get onboardingBalanceOptional;

  /// No description provided for @onboardingSettingUp.
  ///
  /// In en, this message translates to:
  /// **'Setting up…'**
  String get onboardingSettingUp;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Start using Archlence'**
  String get onboardingStart;

  /// No description provided for @addAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get addAccountTitle;

  /// No description provided for @accountTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountTypeCash;

  /// No description provided for @accountTypeCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get accountTypeCreditCard;

  /// No description provided for @addAccountName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get addAccountName;

  /// A placeholder card name. A Turkish bank's product, so it is the same in both languages.
  ///
  /// In en, this message translates to:
  /// **'Bonus Flexi'**
  String get addAccountNameHintCard;

  /// No description provided for @addAccountNameHintCash.
  ///
  /// In en, this message translates to:
  /// **'Salary account'**
  String get addAccountNameHintCash;

  /// On a card the user enters what they OWE as a positive number. Calling it 'balance' here would invite a minus sign that doubles the debt.
  ///
  /// In en, this message translates to:
  /// **'Current debt'**
  String get addAccountCurrentDebt;

  /// No description provided for @addAccountOpeningBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get addAccountOpeningBalance;

  /// No description provided for @addAccountCardLimit.
  ///
  /// In en, this message translates to:
  /// **'Card limit'**
  String get addAccountCardLimit;

  /// No description provided for @addAccountStatementDay.
  ///
  /// In en, this message translates to:
  /// **'Statement day (optional)'**
  String get addAccountStatementDay;

  /// No description provided for @addAccountCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card number (optional)'**
  String get addAccountCardNumber;

  /// No description provided for @addAccountCardNumberNote.
  ///
  /// In en, this message translates to:
  /// **'Only the last four digits and the network are kept. The number itself is never stored.'**
  String get addAccountCardNumberNote;

  /// No description provided for @addAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccountAction;

  /// No description provided for @addTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'New transaction'**
  String get addTransactionTitle;

  /// No description provided for @transactionTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get transactionTypeExpense;

  /// No description provided for @transactionTypeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get transactionTypeIncome;

  /// No description provided for @errEnterAnAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount.'**
  String get errEnterAnAmount;

  /// No description provided for @addTransactionNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Add an account first — money has to come from somewhere.'**
  String get addTransactionNoAccount;

  /// No description provided for @fieldAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get fieldAccount;

  /// No description provided for @fieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fieldAmount;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @fieldDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get fieldDescriptionOptional;

  /// No description provided for @fieldInstallments.
  ///
  /// In en, this message translates to:
  /// **'Instalments'**
  String get fieldInstallments;

  /// No description provided for @installmentsNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get installmentsNone;

  /// The instalment count, never below two — hence no singular form.
  ///
  /// In en, this message translates to:
  /// **'{count} months'**
  String installmentMonths(int count);

  /// No description provided for @installmentNote.
  ///
  /// In en, this message translates to:
  /// **'The whole amount is charged to the card now — that is what the bank blocks against your limit. The plan tracks the monthly split.'**
  String get installmentNote;

  /// No description provided for @transactionScheduledNote.
  ///
  /// In en, this message translates to:
  /// **'Scheduled — it will not touch your balance until that day.'**
  String get transactionScheduledNote;

  /// No description provided for @addTransactionAction.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get addTransactionAction;

  /// The card's name is the user's own text and is substituted AFTER translation, never translated itself.
  ///
  /// In en, this message translates to:
  /// **'Pay {card}'**
  String payDebtTitle(String card);

  /// No description provided for @payDebtAction.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get payDebtAction;

  /// No description provided for @payDebtOwing.
  ///
  /// In en, this message translates to:
  /// **'{amount} owing'**
  String payDebtOwing(String amount);

  /// No description provided for @payDebtAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount to pay'**
  String get payDebtAmount;

  /// No description provided for @payDebtAll.
  ///
  /// In en, this message translates to:
  /// **'Pay it all off ({amount})'**
  String payDebtAll(String amount);

  /// No description provided for @payDebtNoSource.
  ///
  /// In en, this message translates to:
  /// **'No cash account to pay from.'**
  String get payDebtNoSource;

  /// No description provided for @payDebtFrom.
  ///
  /// In en, this message translates to:
  /// **'Pay from'**
  String get payDebtFrom;

  /// No description provided for @payDebtFrozenNote.
  ///
  /// In en, this message translates to:
  /// **'This card is frozen, and can still be paid. Freezing stops new spending, not clearing what you owe.'**
  String get payDebtFrozenNote;

  /// No description provided for @errChooseSource.
  ///
  /// In en, this message translates to:
  /// **'Choose where the money comes from.'**
  String get errChooseSource;

  /// A dropdown row: the user's own account name beside its formatted balance. Identical in both languages, and a template rather than an inline join so the separator can move if a language needs it to.
  ///
  /// In en, this message translates to:
  /// **'{name} — {balance}'**
  String accountWithBalance(String name, String balance);

  /// Stands in for a subscription name that will not decrypt.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscriptionFallbackName;

  /// No description provided for @subscriptionNoLongerActive.
  ///
  /// In en, this message translates to:
  /// **'This subscription is no longer active.'**
  String get subscriptionNoLongerActive;

  /// No description provided for @errEnterNewPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter the new price.'**
  String get errEnterNewPrice;

  /// No description provided for @subscriptionSavePrice.
  ///
  /// In en, this message translates to:
  /// **'Save new price'**
  String get subscriptionSavePrice;

  /// No description provided for @subscriptionNextOn.
  ///
  /// In en, this message translates to:
  /// **'Next on {date}'**
  String subscriptionNextOn(String date);

  /// No description provided for @subscriptionPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get subscriptionPrice;

  /// No description provided for @subscriptionPriceNote.
  ///
  /// In en, this message translates to:
  /// **'Changing the price leaves the schedule where it is.'**
  String get subscriptionPriceNote;

  /// No description provided for @subscriptionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip the next one'**
  String get subscriptionSkip;

  /// No description provided for @subscriptionSkipNote.
  ///
  /// In en, this message translates to:
  /// **'Moves it on one period. The subscription keeps running.'**
  String get subscriptionSkipNote;

  /// No description provided for @subscriptionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop tracking it'**
  String get subscriptionStop;

  /// No description provided for @subscriptionStopNote.
  ///
  /// In en, this message translates to:
  /// **'Stops it for good. Past charges stay in your history.'**
  String get subscriptionStopNote;

  /// No description provided for @subscriptionStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop tracking this?'**
  String get subscriptionStopTitle;

  /// No description provided for @subscriptionStopBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will stop being tracked. Charges already recorded stay where they are.'**
  String subscriptionStopBody(String name);

  /// Substituted into subscriptionStopBody when the name will not decrypt.
  ///
  /// In en, this message translates to:
  /// **'This subscription'**
  String get subscriptionStopFallbackName;

  /// No description provided for @subscriptionKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get subscriptionKeep;

  /// No description provided for @subscriptionStopConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop it'**
  String get subscriptionStopConfirm;

  /// No description provided for @budgetLineTitle.
  ///
  /// In en, this message translates to:
  /// **'New budget line'**
  String get budgetLineTitle;

  /// No description provided for @budgetLineAction.
  ///
  /// In en, this message translates to:
  /// **'Save line'**
  String get budgetLineAction;

  /// No description provided for @budgetLineName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get budgetLineName;

  /// A placeholder budget line. Left in Turkish in both languages: it is an example of the user's own data, and the categories it sits beside are Turkish literals in either interface.
  ///
  /// In en, this message translates to:
  /// **'Kira'**
  String get budgetLineNameHint;

  /// No description provided for @budgetLineAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount for the month'**
  String get budgetLineAmount;

  /// No description provided for @fieldCategoryOptional.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get fieldCategoryOptional;

  /// No description provided for @categoryNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get categoryNone;

  /// No description provided for @budgetLineCategoryNote.
  ///
  /// In en, this message translates to:
  /// **'Only a line with a category is tracked against what you actually spend.'**
  String get budgetLineCategoryNote;

  /// No description provided for @budgetLineEveryMonth.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get budgetLineEveryMonth;

  /// No description provided for @budgetLineEveryMonthNote.
  ///
  /// In en, this message translates to:
  /// **'Applies to every month until you set a different amount for one.'**
  String get budgetLineEveryMonthNote;

  /// No description provided for @budgetLineRollover.
  ///
  /// In en, this message translates to:
  /// **'Carry the balance over'**
  String get budgetLineRollover;

  /// No description provided for @budgetLineRolloverNote.
  ///
  /// In en, this message translates to:
  /// **'Adds last month\'s leftover to this month\'s limit. Only last month\'s — it does not build up.'**
  String get budgetLineRolloverNote;

  /// The threshold arrives already formatted as a Turkish percentage (%80), which is written the same way in both languages.
  ///
  /// In en, this message translates to:
  /// **'Warn me at {threshold}'**
  String budgetLineWarnAt(String threshold);

  /// No description provided for @newGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'New savings goal'**
  String get newGoalTitle;

  /// No description provided for @newGoalAction.
  ///
  /// In en, this message translates to:
  /// **'Create goal'**
  String get newGoalAction;

  /// No description provided for @newGoalExplanation.
  ///
  /// In en, this message translates to:
  /// **'Money in a goal is set aside from your balance. It is not spending and never appears in an expense chart.'**
  String get newGoalExplanation;

  /// No description provided for @newGoalName.
  ///
  /// In en, this message translates to:
  /// **'What it is for'**
  String get newGoalName;

  /// An example goal name — the user's own data, left in Turkish in both languages.
  ///
  /// In en, this message translates to:
  /// **'Acil Durum Fonu'**
  String get newGoalNameHint;

  /// No description provided for @newGoalTarget.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get newGoalTarget;

  /// No description provided for @errEnterTargetAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a target amount.'**
  String get errEnterTargetAmount;

  /// No description provided for @errChooseCashAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose a cash account.'**
  String get errChooseCashAccount;

  /// No description provided for @goalFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Savings goal'**
  String get goalFallbackName;

  /// No description provided for @goalSetAside.
  ///
  /// In en, this message translates to:
  /// **'Set aside'**
  String get goalSetAside;

  /// No description provided for @goalProgress.
  ///
  /// In en, this message translates to:
  /// **'{saved} of {target}'**
  String goalProgress(String saved, String target);

  /// A whole second template rather than a suffix glued onto goalProgress: the clause's position in the sentence belongs to the translation.
  ///
  /// In en, this message translates to:
  /// **'{saved} of {target} — {remaining} to go'**
  String goalProgressWithRemaining(
    String saved,
    String target,
    String remaining,
  );

  /// No description provided for @goalMoveNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No cash account to move money between.'**
  String get goalMoveNoAccount;

  /// No description provided for @goalMoveFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get goalMoveFrom;

  /// No description provided for @goalMoveInto.
  ///
  /// In en, this message translates to:
  /// **'Into'**
  String get goalMoveInto;

  /// No description provided for @goalMayGoNegative.
  ///
  /// In en, this message translates to:
  /// **'Your account may go negative — Archlence will not stop you.'**
  String get goalMayGoNegative;

  /// No description provided for @errEnterPriceAndQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter a price and a quantity.'**
  String get errEnterPriceAndQuantity;

  /// No description provided for @errChooseDestination.
  ///
  /// In en, this message translates to:
  /// **'Choose where the money goes.'**
  String get errChooseDestination;

  /// No description provided for @buyAssetTitle.
  ///
  /// In en, this message translates to:
  /// **'New holding'**
  String get buyAssetTitle;

  /// No description provided for @buyAssetAction.
  ///
  /// In en, this message translates to:
  /// **'Add holding'**
  String get buyAssetAction;

  /// No description provided for @assetName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get assetName;

  /// An example holding name — the user's own data, and the kinds it is filed under are Turkish literals in either interface.
  ///
  /// In en, this message translates to:
  /// **'Gram Altın'**
  String get assetNameHint;

  /// No description provided for @assetCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get assetCode;

  /// The asset type. Its VALUES ('Altın', 'Hisse Senedi') stay verbatim in both languages — the desktop groups and reports on those literals.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get assetKind;

  /// No description provided for @assetUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get assetUnitPrice;

  /// No description provided for @assetQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get assetQuantity;

  /// Shown before anything is written, because `1.234` meaning a thousand rather than a lira and a bit is a judgement the parser makes on the user's behalf.
  ///
  /// In en, this message translates to:
  /// **'That is {total} in total.'**
  String assetTotalIs(String total);

  /// No description provided for @assetAlreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'I already owned this'**
  String get assetAlreadyOwned;

  /// No description provided for @assetAlreadyOwnedNote.
  ///
  /// In en, this message translates to:
  /// **'Records the holding without taking the money from an account.'**
  String get assetAlreadyOwnedNote;

  /// No description provided for @assetNoCashAccount.
  ///
  /// In en, this message translates to:
  /// **'No cash account to pay from. Add one, or record this as something you already owned.'**
  String get assetNoCashAccount;

  /// No description provided for @assetPayFrom.
  ///
  /// In en, this message translates to:
  /// **'Pay from'**
  String get assetPayFrom;

  /// The service picks the first account that can cover it, and the richest one if none can. Saying so beats a silent default.
  ///
  /// In en, this message translates to:
  /// **'Choose for me'**
  String get assetChooseForMe;

  /// No description provided for @sellAssetTitle.
  ///
  /// In en, this message translates to:
  /// **'Sell {name}'**
  String sellAssetTitle(String name);

  /// No description provided for @sellAssetAction.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sellAssetAction;

  /// No description provided for @sellAssetHoldingLine.
  ///
  /// In en, this message translates to:
  /// **'You hold {quantity}, bought at {price} each.'**
  String sellAssetHoldingLine(String quantity, String price);

  /// No description provided for @sellAssetPrice.
  ///
  /// In en, this message translates to:
  /// **'Sale price, per unit'**
  String get sellAssetPrice;

  /// No description provided for @sellAssetQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity to sell'**
  String get sellAssetQuantity;

  /// No description provided for @sellAssetOutcome.
  ///
  /// In en, this message translates to:
  /// **'{proceeds} in, against {cost} paid — {gain}.'**
  String sellAssetOutcome(String proceeds, String cost, String gain);

  /// No description provided for @sellAssetNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account to pay into.'**
  String get sellAssetNoAccount;

  /// No description provided for @sellAssetPayInto.
  ///
  /// In en, this message translates to:
  /// **'Pay into'**
  String get sellAssetPayInto;

  /// No description provided for @homeActiveSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'My Active Subscriptions'**
  String get homeActiveSubscriptions;

  /// No description provided for @homeNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net Worth'**
  String get homeNetWorth;

  /// No description provided for @homeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get homeCash;

  /// No description provided for @homeCardDebt.
  ///
  /// In en, this message translates to:
  /// **'Card Debt'**
  String get homeCardDebt;

  /// No description provided for @homeNoSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Nothing recurring yet. A subscription paid by card is noticed automatically and lands here.'**
  String get homeNoSubscriptions;

  /// No description provided for @homeSearchDisabled.
  ///
  /// In en, this message translates to:
  /// **'Search — not yet'**
  String get homeSearchDisabled;

  /// No description provided for @homeMyWallet.
  ///
  /// In en, this message translates to:
  /// **'My Wallet'**
  String get homeMyWallet;

  /// No description provided for @homeForecastTitle.
  ///
  /// In en, this message translates to:
  /// **'Algorithmic Forecast'**
  String get homeForecastTitle;

  /// No description provided for @homeForecastPending.
  ///
  /// In en, this message translates to:
  /// **'Spending trends and the month-end projection arrive with the insight and projection services.'**
  String get homeForecastPending;

  /// No description provided for @homeHealthScoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Health Score'**
  String get homeHealthScoreTitle;

  /// No description provided for @homeHealthScorePending.
  ///
  /// In en, this message translates to:
  /// **'Scoring needs savings rate, debt-to-income and expense volatility, which the metrics service will supply.'**
  String get homeHealthScorePending;

  /// No description provided for @subscriptionUnreadableName.
  ///
  /// In en, this message translates to:
  /// **'Unreadable subscription'**
  String get subscriptionUnreadableName;

  /// Stands in for an amount that will not decrypt. Never a zero — a false figure is exactly what the money layer refuses.
  ///
  /// In en, this message translates to:
  /// **'unreadable'**
  String get amountUnreadable;

  /// No description provided for @subscriptionManage.
  ///
  /// In en, this message translates to:
  /// **'MANAGE'**
  String get subscriptionManage;

  /// No description provided for @budgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Budget'**
  String get budgetTitle;

  /// No description provided for @budgetCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get budgetCategories;

  /// No description provided for @budgetPlannedIncome.
  ///
  /// In en, this message translates to:
  /// **'Planned Income'**
  String get budgetPlannedIncome;

  /// No description provided for @budgetPlannedExpense.
  ///
  /// In en, this message translates to:
  /// **'Planned Expense'**
  String get budgetPlannedExpense;

  /// No description provided for @budgetReserved.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get budgetReserved;

  /// No description provided for @budgetLeftToSpend.
  ///
  /// In en, this message translates to:
  /// **'Left to spend'**
  String get budgetLeftToSpend;

  /// No description provided for @budgetLeftToSpendNote.
  ///
  /// In en, this message translates to:
  /// **'Planned income, less planned spending, less what your subscriptions will take.'**
  String get budgetLeftToSpendNote;

  /// No description provided for @budgetReservedForSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Reserved for subscriptions'**
  String get budgetReservedForSubscriptions;

  /// How many times a subscription falls due this month. A weekly one falls due four or five times, and showing a single fee would understate it that many-fold.
  ///
  /// In en, this message translates to:
  /// **'×{count}'**
  String budgetOccurrences(int count);

  /// No description provided for @budgetNoCategoryPlans.
  ///
  /// In en, this message translates to:
  /// **'No category plans for this month yet. A plan gives each category a limit and tracks what is left of it.'**
  String get budgetNoCategoryPlans;

  /// No description provided for @budgetSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get budgetSpent;

  /// No description provided for @budgetOverBy.
  ///
  /// In en, this message translates to:
  /// **'Over by'**
  String get budgetOverBy;

  /// No description provided for @budgetLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get budgetLeft;

  /// Three-letter month, for the budget's month chips. Held here rather than taken from `intl`'s date symbols so that both languages are visible in one file and neither needs date data loaded at startup.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthShortJan;

  /// No description provided for @monthShortFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthShortFeb;

  /// No description provided for @monthShortMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthShortMar;

  /// No description provided for @monthShortApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthShortApr;

  /// No description provided for @monthShortMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthShortMay;

  /// No description provided for @monthShortJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthShortJun;

  /// No description provided for @monthShortJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthShortJul;

  /// No description provided for @monthShortAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthShortAug;

  /// No description provided for @monthShortSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthShortSep;

  /// No description provided for @monthShortOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthShortOct;

  /// No description provided for @monthShortNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthShortNov;

  /// No description provided for @monthShortDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthShortDec;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupTitle;

  /// No description provided for @backupNoProfile.
  ///
  /// In en, this message translates to:
  /// **'This build has no profile on disk, so there is nothing to back up.'**
  String get backupNoProfile;

  /// No description provided for @backupSectionCreate.
  ///
  /// In en, this message translates to:
  /// **'Make a backup'**
  String get backupSectionCreate;

  /// No description provided for @backupCreateExplanation.
  ///
  /// In en, this message translates to:
  /// **'A backup holds your whole database and the key that opens it, wrapped under a passphrase you choose. Twelve characters at least.\n\nTHE PASSPHRASE IS NOT STORED ANYWHERE. Without it the backup cannot be opened — not by this app, not by anyone.'**
  String get backupCreateExplanation;

  /// No description provided for @backupPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get backupPassphrase;

  /// No description provided for @backupPassphraseAgain.
  ///
  /// In en, this message translates to:
  /// **'Passphrase again'**
  String get backupPassphraseAgain;

  /// No description provided for @backupCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create and share a backup'**
  String get backupCreateAction;

  /// No description provided for @backupCreateBusy.
  ///
  /// In en, this message translates to:
  /// **'Wrapping the key. This takes a few seconds — the passphrase is deliberately slow to try.'**
  String get backupCreateBusy;

  /// The subject line the share sheet offers, e.g. for an e-mail.
  ///
  /// In en, this message translates to:
  /// **'Archlence backup'**
  String get backupShareSubject;

  /// Names the file kind in the system file picker.
  ///
  /// In en, this message translates to:
  /// **'Archlence backup'**
  String get backupFileTypeLabel;

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup written and checked: {records} encrypted records opened with the key inside it before it was published.'**
  String backupCreated(int records);

  /// No description provided for @backupSectionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get backupSectionRestore;

  /// No description provided for @backupRestoreExplanation.
  ///
  /// In en, this message translates to:
  /// **'Replaces everything in this app with what is in the file, including the encryption key. A backup written by the desktop app works here.\n\nWhat is here now is written to a backup of its own first, under the same passphrase.'**
  String get backupRestoreExplanation;

  /// No description provided for @backupRestorePassphrase.
  ///
  /// In en, this message translates to:
  /// **'The backup\'s passphrase'**
  String get backupRestorePassphrase;

  /// No description provided for @backupRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Choose a file and restore'**
  String get backupRestoreAction;

  /// The system file picker's confirm button.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestoreConfirmButton;

  /// No description provided for @backupRestoreBusy.
  ///
  /// In en, this message translates to:
  /// **'Checking the backup and replacing your data. Do not close the app.'**
  String get backupRestoreBusy;

  /// No description provided for @backupRestoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace everything in this app?'**
  String get backupRestoreConfirmTitle;

  /// No description provided for @backupRestoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Every account, transaction, holding, budget and goal on this phone is replaced by what is in the backup.\n\nWhat is here now is written to a backup of its own first, using the same passphrase, and the app will tell you its name.'**
  String get backupRestoreConfirmBody;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @backupReplaceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get backupReplaceConfirm;

  /// No description provided for @backupRestoredNothingBefore.
  ///
  /// In en, this message translates to:
  /// **'Restored. There was nothing here before, so nothing was set aside.'**
  String get backupRestoredNothingBefore;

  /// No description provided for @backupRestoredWithSafety.
  ///
  /// In en, this message translates to:
  /// **'Restored. What was here before was written to {file} in this app\'s own storage first.'**
  String backupRestoredWithSafety(String file);

  /// No description provided for @backupPassphrasesDiffer.
  ///
  /// In en, this message translates to:
  /// **'The two passphrases are not the same.'**
  String get backupPassphrasesDiffer;

  /// No description provided for @backupWrongPassphrase.
  ///
  /// In en, this message translates to:
  /// **'That passphrase does not open this backup.'**
  String get backupWrongPassphrase;

  /// No description provided for @backupFileUnusable.
  ///
  /// In en, this message translates to:
  /// **'This file cannot be used as a backup.'**
  String get backupFileUnusable;

  /// No description provided for @backupRestoreRolledBack.
  ///
  /// In en, this message translates to:
  /// **'The restore failed, and your data was put back as it was.'**
  String get backupRestoreRolledBack;

  /// No description provided for @backupInterrupted.
  ///
  /// In en, this message translates to:
  /// **'A half-finished restore was found and could not be undone.'**
  String get backupInterrupted;

  /// No description provided for @backupKeyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The encryption key could not be read or replaced.'**
  String get backupKeyUnavailable;

  /// No description provided for @backupUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get backupUnexpected;

  /// No description provided for @cardsMyCards.
  ///
  /// In en, this message translates to:
  /// **'My Cards'**
  String get cardsMyCards;

  /// No description provided for @cardsAdd.
  ///
  /// In en, this message translates to:
  /// **'+  ADD'**
  String get cardsAdd;

  /// No description provided for @cardsNoCards.
  ///
  /// In en, this message translates to:
  /// **'No credit cards yet. Add one to track its limit and debt here.'**
  String get cardsNoCards;

  /// No description provided for @cardsMyAccounts.
  ///
  /// In en, this message translates to:
  /// **'My Accounts'**
  String get cardsMyAccounts;

  /// No description provided for @cardsActiveAssets.
  ///
  /// In en, this message translates to:
  /// **'My Active Assets'**
  String get cardsActiveAssets;

  /// Cost, not value: there is no price feed yet, and the screen has to say which figure it is showing.
  ///
  /// In en, this message translates to:
  /// **'{count} holdings · at cost'**
  String cardsHoldingsMeta(int count);

  /// No description provided for @cardsNoCashAccounts.
  ///
  /// In en, this message translates to:
  /// **'No cash accounts yet. Everything else in Archlence needs one to move money into or out of.'**
  String get cardsNoCashAccounts;

  /// No description provided for @cardsCashChecking.
  ///
  /// In en, this message translates to:
  /// **'Cash / Checking'**
  String get cardsCashChecking;

  /// No description provided for @cardsCreditCardBadge.
  ///
  /// In en, this message translates to:
  /// **'CREDIT CARD'**
  String get cardsCreditCardBadge;

  /// No description provided for @cardsAvailableLimit.
  ///
  /// In en, this message translates to:
  /// **'Available Limit'**
  String get cardsAvailableLimit;

  /// No description provided for @cardsCurrentDebt.
  ///
  /// In en, this message translates to:
  /// **'Current Debt'**
  String get cardsCurrentDebt;

  /// No description provided for @cardsControls.
  ///
  /// In en, this message translates to:
  /// **'Card Controls'**
  String get cardsControls;

  /// No description provided for @cardsOnlineShopping.
  ///
  /// In en, this message translates to:
  /// **'Online Shopping Preference'**
  String get cardsOnlineShopping;

  /// No description provided for @cardsOnlineShoppingNote.
  ///
  /// In en, this message translates to:
  /// **'Stored as a preference only'**
  String get cardsOnlineShoppingNote;

  /// No description provided for @cardsFreeze.
  ///
  /// In en, this message translates to:
  /// **'Freeze Card'**
  String get cardsFreeze;

  /// No description provided for @cardsFreezeNote.
  ///
  /// In en, this message translates to:
  /// **'Blocks new spending, not debt payments'**
  String get cardsFreezeNote;

  /// No description provided for @cardsRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get cardsRecentTransactions;

  /// No description provided for @cardsStatement.
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get cardsStatement;

  /// No description provided for @cardsPayDebt.
  ///
  /// In en, this message translates to:
  /// **'Pay Debt'**
  String get cardsPayDebt;

  /// No description provided for @cardsNothingOnCard.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this card yet.'**
  String get cardsNothingOnCard;

  /// No description provided for @periodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get periodToday;

  /// No description provided for @periodWeek.
  ///
  /// In en, this message translates to:
  /// **'1 Week'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'1 Month'**
  String get periodMonth;

  /// No description provided for @periodYear.
  ///
  /// In en, this message translates to:
  /// **'1 Year'**
  String get periodYear;

  /// No description provided for @periodAllTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get periodAllTime;

  /// No description provided for @assetsDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get assetsDetails;

  /// No description provided for @assetsIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get assetsIncome;

  /// No description provided for @assetsExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get assetsExpense;

  /// No description provided for @assetsNetBalance.
  ///
  /// In en, this message translates to:
  /// **'Net Balance'**
  String get assetsNetBalance;

  /// No description provided for @assetsMyActiveAssets.
  ///
  /// In en, this message translates to:
  /// **'My Active Assets'**
  String get assetsMyActiveAssets;

  /// No description provided for @assetsAtCostNote.
  ///
  /// In en, this message translates to:
  /// **'Valued at purchase cost — no price source yet'**
  String get assetsAtCostNote;

  /// No description provided for @assetsNoHoldings.
  ///
  /// In en, this message translates to:
  /// **'No holdings yet. Anything you buy shows here with what it cost.'**
  String get assetsNoHoldings;

  /// A slice of the distribution chart, not a stored category — the chart is drawn here, so the label belongs here.
  ///
  /// In en, this message translates to:
  /// **'Opening Balance'**
  String get assetsOpeningBalance;

  /// No description provided for @assetsNoDistribution.
  ///
  /// In en, this message translates to:
  /// **'Nothing moved in this period, so there is no distribution to draw.'**
  String get assetsNoDistribution;

  /// The first line inside the donut; assetsDistributionSubtitle is the second.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get assetsDistributionTitle;

  /// No description provided for @assetsDistributionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Distribution'**
  String get assetsDistributionSubtitle;

  /// No description provided for @assetsNoTrend.
  ///
  /// In en, this message translates to:
  /// **'No income or spending in the last year, so there is no trend to draw yet.'**
  String get assetsNoTrend;

  /// No description provided for @assetsHoldingsAtCost.
  ///
  /// In en, this message translates to:
  /// **'Holdings at Cost'**
  String get assetsHoldingsAtCost;

  /// No description provided for @assetsNothingBought.
  ///
  /// In en, this message translates to:
  /// **'Nothing bought yet'**
  String get assetsNothingBought;

  /// No description provided for @assetsHoldingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} holdings'**
  String assetsHoldingCount(int count);

  /// No description provided for @assetsNoGoals.
  ///
  /// In en, this message translates to:
  /// **'No savings goals yet. A goal holds money aside from your balance without counting as spending.'**
  String get assetsNoGoals;

  /// The holding's own name and ticker. Identical in both languages, kept as a template so the brackets can move if a language needs them to.
  ///
  /// In en, this message translates to:
  /// **'{name} ({code})'**
  String assetsHoldingName(String name, String code);

  /// No description provided for @assetsPurchaseLine.
  ///
  /// In en, this message translates to:
  /// **'Purchase: {price} × {quantity}'**
  String assetsPurchaseLine(String price, String quantity);

  /// No description provided for @assetsCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get assetsCost;

  /// The trend chart's x-axis tick, e.g. Sep'25 / Eyl'25.
  ///
  /// In en, this message translates to:
  /// **'{month}\'{year}'**
  String monthYearShort(String month, String year);

  /// No description provided for @recoverySectionExport.
  ///
  /// In en, this message translates to:
  /// **'Just the key'**
  String get recoverySectionExport;

  /// No description provided for @recoveryExportExplanation.
  ///
  /// In en, this message translates to:
  /// **'A key recovery package holds the encryption key and nothing else — no accounts, no transactions. It is for the day the data is still here and the key is not: a reinstall, a phone reset, a screen lock changed in a way that emptied the key store.\n\nA whole backup answers a different question. Restoring one would also throw away everything recorded since it was made.'**
  String get recoveryExportExplanation;

  /// No description provided for @recoveryExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export and share the key'**
  String get recoveryExportAction;

  /// No description provided for @recoveryExportShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Archlence key recovery'**
  String get recoveryExportShareSubject;

  /// No description provided for @recoveryExported.
  ///
  /// In en, this message translates to:
  /// **'The key was written and checked. Keep it somewhere other than this phone — anyone holding it AND its passphrase can read your data.'**
  String get recoveryExported;

  /// No description provided for @recoverySectionImport.
  ///
  /// In en, this message translates to:
  /// **'Put a key back'**
  String get recoverySectionImport;

  /// No description provided for @recoveryImportExplanation.
  ///
  /// In en, this message translates to:
  /// **'Replaces the encryption key with the one in the file, after checking that it opens the data already on this phone. Your accounts and transactions are not touched, and a key that does not open them changes nothing.'**
  String get recoveryImportExplanation;

  /// No description provided for @recoveryImportPassphrase.
  ///
  /// In en, this message translates to:
  /// **'The package\'s passphrase'**
  String get recoveryImportPassphrase;

  /// No description provided for @recoveryImportAction.
  ///
  /// In en, this message translates to:
  /// **'Choose a file and put the key back'**
  String get recoveryImportAction;

  /// The system file picker's confirm button.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get recoveryImportConfirmButton;

  /// Names the file kind in the system file picker.
  ///
  /// In en, this message translates to:
  /// **'Archlence key recovery'**
  String get recoveryFileTypeLabel;

  /// No description provided for @recoveryImportBusy.
  ///
  /// In en, this message translates to:
  /// **'Checking the key against your data. Do not close the app.'**
  String get recoveryImportBusy;

  /// No description provided for @recoveryImportedStored.
  ///
  /// In en, this message translates to:
  /// **'The key is in place. {records} encrypted fields opened with it.'**
  String recoveryImportedStored(int records);

  /// No description provided for @recoveryImportedReplaced.
  ///
  /// In en, this message translates to:
  /// **'The key was replaced. {records} encrypted fields opened with it.'**
  String recoveryImportedReplaced(int records);

  /// No description provided for @recoveryImportedUnchanged.
  ///
  /// In en, this message translates to:
  /// **'That is already the key on this phone. Nothing was changed.'**
  String get recoveryImportedUnchanged;

  /// Appended when the import verified zero fields. 'Verified' and 'verified nothing' are not the same reassurance, and on a fresh profile any key at all would have passed.
  ///
  /// In en, this message translates to:
  /// **'There was nothing encrypted here to check it against, so the key was accepted untested.'**
  String get recoveryVerifiedNothing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
