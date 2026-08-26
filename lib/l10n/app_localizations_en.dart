// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Archlence';

  @override
  String get navHome => 'Home';

  @override
  String get navAssets => 'Assets';

  @override
  String get navCards => 'Cards';

  @override
  String get navTools => 'Tools';

  @override
  String get navSettings => 'Settings';

  @override
  String get startUpFailed => 'Archlence could not start';

  @override
  String get notYetChip => 'NOT YET';

  @override
  String get couldNotBeRead => 'This could not be read';

  @override
  String get totalBalance => 'Total Balance';

  @override
  String get savingInProgress => 'Saving…';

  @override
  String get toolsTitle => 'Financial Tools';

  @override
  String get toolsSubtitle =>
      'Explore calculators and planners to optimize your finances.';

  @override
  String get toolBudget => 'Monthly\nBudget';

  @override
  String get toolCalendar => 'Calendar';

  @override
  String get toolCalculator => 'Calculator';

  @override
  String get toolInterestReturn => 'Interest\nReturn';

  @override
  String get toolCompoundInterest => 'Compound\nInterest';

  @override
  String get toolLoanCalculator => 'Loan\nCalculator';

  @override
  String get toolSavingsGoal => 'Savings\nGoal';

  @override
  String get toolWhatIf => 'What-If\nSandbox';

  @override
  String get toolResetData => 'Reset\nData';

  @override
  String get lockedTitle => 'Archlence is locked';

  @override
  String get lockedExplanation =>
      'Unlock with the same fingerprint or PIN you use for this phone.';

  @override
  String get lockedRefused => 'Not unlocked.';

  @override
  String get lockedWaiting => 'Waiting…';

  @override
  String get lockedUnlock => 'Unlock';

  @override
  String get unlockPrompt => 'Unlock Archlence';

  @override
  String get savingsGoalsTitle => 'Savings Goals';

  @override
  String get savingsGoalsExplanation =>
      'Money in a goal is held aside from your balance. It is not spending, so it never appears in any expense chart.';

  @override
  String get savingsGoalsEmpty =>
      'No savings goals yet. Add one with the + above.';

  @override
  String get goalUnreadable => 'Unreadable goal';

  @override
  String get goalSaved => 'Saved';

  @override
  String get goalTarget => 'Target';

  @override
  String get goalTakeBack => 'Take back';

  @override
  String get goalPutIn => 'Save';

  @override
  String get settingsSectionAccount => 'Account & Preferences';

  @override
  String get settingsCategorySettings => 'Category Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System language';

  @override
  String get settingsEncryptionKey => 'Encryption Key';

  @override
  String get keyMethodAndroidKeystore => 'Android Keystore';

  @override
  String get keyMethodOwnerOnlyFile => 'owner-only file';

  @override
  String get keyProtectionUnknown => 'Not known in this build.';

  @override
  String keyProtectionHeldByOs(String method) {
    return '$method — held by the operating system.';
  }

  @override
  String keyProtectionLocalFile(String method) {
    return '$method — NOT in an OS key store; the key is a local file readable only by this app.';
  }

  @override
  String get keyWarningOsStoreUnavailable =>
      'The OS key store is unavailable; the key is kept in a local file readable only by this app.';

  @override
  String get keyWarningNoPlatformStore =>
      'This platform has no supported OS key store.';

  @override
  String get settingsSectionSecurity => 'Security';

  @override
  String get lockTileTitle => 'Lock when I come back';

  @override
  String get lockTileExplanation =>
      'Asks for your fingerprint or PIN after a minute away. It hides the screen from someone holding your phone — it does not add encryption.';

  @override
  String get lockTileUnavailable =>
      'This device has no fingerprint or screen lock set up.';

  @override
  String get settingsSectionYourData => 'Your Data';

  @override
  String get settingsBackupRestore => 'Backup & Restore';

  @override
  String get settingsBackupUnavailable => 'Not available in this build.';

  @override
  String get settingsBackupSubtitle =>
      'Write a backup you can keep, or restore one — including a backup made by the desktop app.';

  @override
  String get settingsSectionAppearance => 'Appearance & Privacy';

  @override
  String get settingsPremiumTheme => 'Premium Blue Theme';

  @override
  String get settingsPremiumThemeSubtitle =>
      'Uses the standard theme when disabled';

  @override
  String get settingsDataPrivacy => 'Data & Privacy';

  @override
  String get settingsSectionSecurityHistory => 'Security & History';

  @override
  String get settingsChangePassword => 'Change Password';

  @override
  String get settingsChangePasswordSubtitle =>
      'You can renew your password here.';

  @override
  String get settingsBalanceHistory => 'Balance History';

  @override
  String get settingsSectionSystem => 'System';

  @override
  String get settingsDarkMode => 'Dark Mode';

  @override
  String get settingsDarkModeSubtitle => 'Obsidian Prime is dark-only for now';

  @override
  String get settingsContactUs => 'Contact Us';

  @override
  String get settingsSignOut => 'Sign Out';

  @override
  String get errNotAnAmount => 'That is not an amount.';

  @override
  String get errAmountNotPositive => 'Enter an amount above zero.';

  @override
  String get errAccountEmptyName => 'Give the account a name.';

  @override
  String get errAccountUnknownType => 'Choose an account type.';

  @override
  String get errAccountInvalidStatementDay =>
      'The statement day has to be between 1 and 31.';

  @override
  String get errAccountCreditLimitRequired =>
      'A credit card needs a limit above zero.';

  @override
  String get errAccountNegativeOpeningDebt =>
      'Debt cannot be a negative amount.';

  @override
  String get errAccountOpeningDebtExceedsLimit =>
      'The debt is larger than the limit you entered.';

  @override
  String get errAccountNotFound => 'That account no longer exists.';

  @override
  String get errAccountCardFrozen =>
      'This card is frozen. Unfreeze it to spend on it.';

  @override
  String get errAccountInsufficientLimit =>
      'That would go past the card\'s available limit.';

  @override
  String get errAccountNotACreditCard => 'That is not a credit card.';

  @override
  String get errAccountNoDebtToPay => 'There is nothing owing on this card.';

  @override
  String get errAccountPaymentExceedsDebt => 'That is more than the card owes.';

  @override
  String get errAccountSourceMustBeChecking =>
      'Pay a card from a cash account, not another card.';

  @override
  String get errAccountBalanceUpdateFailed =>
      'The balance could not be updated. Nothing was changed.';

  @override
  String get errAccountUnknownCardPreference => 'Unknown card setting.';

  @override
  String get errTransactionInstallmentRange =>
      'Instalments have to be between 1 and 12.';

  @override
  String get errTransactionNegativeLimit => 'The limit cannot be negative.';

  @override
  String get errAssetInvalidAmount =>
      'Price and quantity both have to be numbers above zero.';

  @override
  String get errAssetNotFound => 'That holding no longer exists.';

  @override
  String get errSavingsEmptyName => 'Say what the goal is for.';

  @override
  String get errSavingsNegativeOpeningAmount =>
      'A goal cannot start with less than nothing in it.';

  @override
  String get errSavingsIdentityMismatch =>
      'This goal has changed since the screen was drawn. Nothing was moved — pull to refresh and try again.';

  @override
  String get errSavingsAccountNotFound => 'That cash account no longer exists.';

  @override
  String get errSavingsGoalNotFoundOrCompleted =>
      'This goal is already complete.';

  @override
  String get errSavingsInsufficientBalance =>
      'The goal does not hold that much.';

  @override
  String get errSavingsRefundAccountRequired =>
      'Choose where the money should go.';

  @override
  String get errBudgetUnknownItemType => 'Choose income or expense.';

  @override
  String get errBudgetEmptyName => 'Give the line a name.';

  @override
  String get errBudgetInvalidMonth =>
      'Pick a month between January and December.';

  @override
  String get errBudgetInvalidAlertThreshold =>
      'The alert threshold has to be between 1 and 100 per cent.';

  @override
  String get errRecurringUnknownFrequency =>
      'This subscription repeats on a schedule Archlence does not recognise.';

  @override
  String get errRecurringInvalidDay =>
      'The day of the month has to be between 1 and 31.';

  @override
  String get errRecurringInvalidTransactionType =>
      'A subscription has to be income or expense.';

  @override
  String get errRecurringUnreadablePayment =>
      'This subscription could not be read.';

  @override
  String get commonNext => 'Next';

  @override
  String get onboardingTagline =>
      'Your accounts, cards, holdings and budget — on this phone and nowhere else.';

  @override
  String get onboardingNoServerTitle => 'No account, no server';

  @override
  String get onboardingNoServerBody =>
      'Nothing is uploaded and there is nothing to sign in to. The data lives in a file only this app can read.';

  @override
  String get onboardingSameFileTitle => 'The same file as the desktop app';

  @override
  String get onboardingSameFileBody =>
      'A backup written on one opens in the other, down to the kurus.';

  @override
  String get onboardingBackupsTitle => 'Which means backups are on you';

  @override
  String get onboardingBackupsBody =>
      'If you lose the phone without a backup, the data goes with it. Nobody else has a copy.';

  @override
  String get onboardingEncryptedTitle => 'Your data is encrypted';

  @override
  String get onboardingEncryptedBody =>
      'Every amount and description is stored encrypted. The key that opens them is kept apart from the data.';

  @override
  String get onboardingKeyUnknownTitle => 'Key location unknown';

  @override
  String get onboardingKeyUnknownBody =>
      'This build could not tell where the key ended up.';

  @override
  String get onboardingKeySecureBody =>
      'Held by the operating system. It never leaves this device and no other app can read it.';

  @override
  String get onboardingKeyFileBody =>
      'The OS key store was not available, so the key is a file only this app can open. That is weaker than the key store, and worth knowing.';

  @override
  String get onboardingAccountTitle => 'Where does your money sit?';

  @override
  String get onboardingAccountBody =>
      'One cash account to start with. Everything else — spending, cards, holdings, goals — needs somewhere for money to come from.';

  @override
  String get onboardingDefaultAccountName => 'Cash';

  @override
  String get onboardingAccountName => 'Name';

  @override
  String get onboardingAccountBalance => 'What is in it now';

  @override
  String get onboardingBalanceOptional =>
      'You can leave this empty and add it later.';

  @override
  String get onboardingSettingUp => 'Setting up…';

  @override
  String get onboardingStart => 'Start using Archlence';

  @override
  String get addAccountTitle => 'New account';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get accountTypeCreditCard => 'Credit card';

  @override
  String get addAccountName => 'Name';

  @override
  String get addAccountNameHintCard => 'Bonus Flexi';

  @override
  String get addAccountNameHintCash => 'Salary account';

  @override
  String get addAccountCurrentDebt => 'Current debt';

  @override
  String get addAccountOpeningBalance => 'Opening balance';

  @override
  String get addAccountCardLimit => 'Card limit';

  @override
  String get addAccountStatementDay => 'Statement day (optional)';

  @override
  String get addAccountCardNumber => 'Card number (optional)';

  @override
  String get addAccountCardNumberNote =>
      'Only the last four digits and the network are kept. The number itself is never stored.';

  @override
  String get addAccountAction => 'Add account';

  @override
  String get addTransactionTitle => 'New transaction';

  @override
  String get transactionTypeExpense => 'Expense';

  @override
  String get transactionTypeIncome => 'Income';

  @override
  String get errEnterAnAmount => 'Enter an amount.';

  @override
  String get addTransactionNoAccount =>
      'Add an account first — money has to come from somewhere.';

  @override
  String get fieldAccount => 'Account';

  @override
  String get fieldAmount => 'Amount';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldDescriptionOptional => 'Description (optional)';

  @override
  String get fieldInstallments => 'Instalments';

  @override
  String get installmentsNone => 'None';

  @override
  String installmentMonths(int count) {
    return '$count months';
  }

  @override
  String get installmentNote =>
      'The whole amount is charged to the card now — that is what the bank blocks against your limit. The plan tracks the monthly split.';

  @override
  String get transactionScheduledNote =>
      'Scheduled — it will not touch your balance until that day.';

  @override
  String get addTransactionAction => 'Record';

  @override
  String payDebtTitle(String card) {
    return 'Pay $card';
  }

  @override
  String get payDebtAction => 'Pay';

  @override
  String payDebtOwing(String amount) {
    return '$amount owing';
  }

  @override
  String get payDebtAmount => 'Amount to pay';

  @override
  String payDebtAll(String amount) {
    return 'Pay it all off ($amount)';
  }

  @override
  String get payDebtNoSource => 'No cash account to pay from.';

  @override
  String get payDebtFrom => 'Pay from';

  @override
  String get payDebtFrozenNote =>
      'This card is frozen, and can still be paid. Freezing stops new spending, not clearing what you owe.';

  @override
  String get errChooseSource => 'Choose where the money comes from.';

  @override
  String accountWithBalance(String name, String balance) {
    return '$name — $balance';
  }

  @override
  String get subscriptionFallbackName => 'Subscription';

  @override
  String get subscriptionNoLongerActive =>
      'This subscription is no longer active.';

  @override
  String get errEnterNewPrice => 'Enter the new price.';

  @override
  String get subscriptionSavePrice => 'Save new price';

  @override
  String subscriptionNextOn(String date) {
    return 'Next on $date';
  }

  @override
  String get subscriptionPrice => 'Price';

  @override
  String get subscriptionPriceNote =>
      'Changing the price leaves the schedule where it is.';

  @override
  String get subscriptionSkip => 'Skip the next one';

  @override
  String get subscriptionSkipNote =>
      'Moves it on one period. The subscription keeps running.';

  @override
  String get subscriptionStop => 'Stop tracking it';

  @override
  String get subscriptionStopNote =>
      'Stops it for good. Past charges stay in your history.';

  @override
  String get subscriptionStopTitle => 'Stop tracking this?';

  @override
  String subscriptionStopBody(String name) {
    return '$name will stop being tracked. Charges already recorded stay where they are.';
  }

  @override
  String get subscriptionStopFallbackName => 'This subscription';

  @override
  String get subscriptionKeep => 'Keep it';

  @override
  String get subscriptionStopConfirm => 'Stop it';

  @override
  String get budgetLineTitle => 'New budget line';

  @override
  String get budgetLineAction => 'Save line';

  @override
  String get budgetLineName => 'Name';

  @override
  String get budgetLineNameHint => 'Kira';

  @override
  String get budgetLineAmount => 'Amount for the month';

  @override
  String get fieldCategoryOptional => 'Category (optional)';

  @override
  String get categoryNone => 'None';

  @override
  String get budgetLineCategoryNote =>
      'Only a line with a category is tracked against what you actually spend.';

  @override
  String get budgetLineEveryMonth => 'Every month';

  @override
  String get budgetLineEveryMonthNote =>
      'Applies to every month until you set a different amount for one.';

  @override
  String get budgetLineRollover => 'Carry the balance over';

  @override
  String get budgetLineRolloverNote =>
      'Adds last month\'s leftover to this month\'s limit. Only last month\'s — it does not build up.';

  @override
  String budgetLineWarnAt(String threshold) {
    return 'Warn me at $threshold';
  }

  @override
  String get newGoalTitle => 'New savings goal';

  @override
  String get newGoalAction => 'Create goal';

  @override
  String get newGoalExplanation =>
      'Money in a goal is set aside from your balance. It is not spending and never appears in an expense chart.';

  @override
  String get newGoalName => 'What it is for';

  @override
  String get newGoalNameHint => 'Acil Durum Fonu';

  @override
  String get newGoalTarget => 'Target amount';

  @override
  String get errEnterTargetAmount => 'Enter a target amount.';

  @override
  String get errChooseCashAccount => 'Choose a cash account.';

  @override
  String get goalFallbackName => 'Savings goal';

  @override
  String get goalSetAside => 'Set aside';

  @override
  String goalProgress(String saved, String target) {
    return '$saved of $target';
  }

  @override
  String goalProgressWithRemaining(
    String saved,
    String target,
    String remaining,
  ) {
    return '$saved of $target — $remaining to go';
  }

  @override
  String get goalMoveNoAccount => 'No cash account to move money between.';

  @override
  String get goalMoveFrom => 'From';

  @override
  String get goalMoveInto => 'Into';

  @override
  String get goalMayGoNegative =>
      'Your account may go negative — Archlence will not stop you.';

  @override
  String get errEnterPriceAndQuantity => 'Enter a price and a quantity.';

  @override
  String get errChooseDestination => 'Choose where the money goes.';

  @override
  String get buyAssetTitle => 'New holding';

  @override
  String get buyAssetAction => 'Add holding';

  @override
  String get assetName => 'Name';

  @override
  String get assetNameHint => 'Gram Altın';

  @override
  String get assetCode => 'Code';

  @override
  String get assetKind => 'Kind';

  @override
  String get assetUnitPrice => 'Unit price';

  @override
  String get assetQuantity => 'Quantity';

  @override
  String assetTotalIs(String total) {
    return 'That is $total in total.';
  }

  @override
  String get assetAlreadyOwned => 'I already owned this';

  @override
  String get assetAlreadyOwnedNote =>
      'Records the holding without taking the money from an account.';

  @override
  String get assetNoCashAccount =>
      'No cash account to pay from. Add one, or record this as something you already owned.';

  @override
  String get assetPayFrom => 'Pay from';

  @override
  String get assetChooseForMe => 'Choose for me';

  @override
  String sellAssetTitle(String name) {
    return 'Sell $name';
  }

  @override
  String get sellAssetAction => 'Sell';

  @override
  String sellAssetHoldingLine(String quantity, String price) {
    return 'You hold $quantity, bought at $price each.';
  }

  @override
  String get sellAssetPrice => 'Sale price, per unit';

  @override
  String get sellAssetQuantity => 'Quantity to sell';

  @override
  String sellAssetOutcome(String proceeds, String cost, String gain) {
    return '$proceeds in, against $cost paid — $gain.';
  }

  @override
  String get sellAssetNoAccount => 'No account to pay into.';

  @override
  String get sellAssetPayInto => 'Pay into';

  @override
  String get homeActiveSubscriptions => 'My Active Subscriptions';

  @override
  String get homeNetWorth => 'Net Worth';

  @override
  String get homeCash => 'Cash';

  @override
  String get homeCardDebt => 'Card Debt';

  @override
  String get homeNoSubscriptions =>
      'Nothing recurring yet. A subscription paid by card is noticed automatically and lands here.';

  @override
  String get homeSearchDisabled => 'Search — not yet';

  @override
  String get homeMyWallet => 'My Wallet';

  @override
  String get homeForecastTitle => 'Algorithmic Forecast';

  @override
  String get homeForecastPending =>
      'Spending trends and the month-end projection arrive with the insight and projection services.';

  @override
  String get homeHealthScoreTitle => 'Financial Health Score';

  @override
  String get homeHealthScorePending =>
      'Scoring needs savings rate, debt-to-income and expense volatility, which the metrics service will supply.';

  @override
  String get subscriptionUnreadableName => 'Unreadable subscription';

  @override
  String get amountUnreadable => 'unreadable';

  @override
  String get subscriptionManage => 'MANAGE';

  @override
  String get budgetTitle => 'Monthly Budget';

  @override
  String get budgetCategories => 'Categories';

  @override
  String get budgetPlannedIncome => 'Planned Income';

  @override
  String get budgetPlannedExpense => 'Planned Expense';

  @override
  String get budgetReserved => 'Reserved';

  @override
  String get budgetLeftToSpend => 'Left to spend';

  @override
  String get budgetLeftToSpendNote =>
      'Planned income, less planned spending, less what your subscriptions will take.';

  @override
  String get budgetReservedForSubscriptions => 'Reserved for subscriptions';

  @override
  String budgetOccurrences(int count) {
    return '×$count';
  }

  @override
  String get budgetNoCategoryPlans =>
      'No category plans for this month yet. A plan gives each category a limit and tracks what is left of it.';

  @override
  String get budgetSpent => 'Spent';

  @override
  String get budgetOverBy => 'Over by';

  @override
  String get budgetLeft => 'Left';

  @override
  String get monthShortJan => 'Jan';

  @override
  String get monthShortFeb => 'Feb';

  @override
  String get monthShortMar => 'Mar';

  @override
  String get monthShortApr => 'Apr';

  @override
  String get monthShortMay => 'May';

  @override
  String get monthShortJun => 'Jun';

  @override
  String get monthShortJul => 'Jul';

  @override
  String get monthShortAug => 'Aug';

  @override
  String get monthShortSep => 'Sep';

  @override
  String get monthShortOct => 'Oct';

  @override
  String get monthShortNov => 'Nov';

  @override
  String get monthShortDec => 'Dec';

  @override
  String get backupTitle => 'Backup & Restore';

  @override
  String get backupNoProfile =>
      'This build has no profile on disk, so there is nothing to back up.';

  @override
  String get backupSectionCreate => 'Make a backup';

  @override
  String get backupCreateExplanation =>
      'A backup holds your whole database and the key that opens it, wrapped under a passphrase you choose. Twelve characters at least.\n\nTHE PASSPHRASE IS NOT STORED ANYWHERE. Without it the backup cannot be opened — not by this app, not by anyone.';

  @override
  String get backupPassphrase => 'Passphrase';

  @override
  String get backupPassphraseAgain => 'Passphrase again';

  @override
  String get backupCreateAction => 'Create and share a backup';

  @override
  String get backupCreateBusy =>
      'Wrapping the key. This takes a few seconds — the passphrase is deliberately slow to try.';

  @override
  String get backupShareSubject => 'Archlence backup';

  @override
  String get backupFileTypeLabel => 'Archlence backup';

  @override
  String backupCreated(int records) {
    return 'Backup written and checked: $records encrypted records opened with the key inside it before it was published.';
  }

  @override
  String get backupSectionRestore => 'Restore from a backup';

  @override
  String get backupRestoreExplanation =>
      'Replaces everything in this app with what is in the file, including the encryption key. A backup written by the desktop app works here.\n\nWhat is here now is written to a backup of its own first, under the same passphrase.';

  @override
  String get backupRestorePassphrase => 'The backup\'s passphrase';

  @override
  String get backupRestoreAction => 'Choose a file and restore';

  @override
  String get backupRestoreConfirmButton => 'Restore';

  @override
  String get backupRestoreBusy =>
      'Checking the backup and replacing your data. Do not close the app.';

  @override
  String get backupRestoreConfirmTitle => 'Replace everything in this app?';

  @override
  String get backupRestoreConfirmBody =>
      'Every account, transaction, holding, budget and goal on this phone is replaced by what is in the backup.\n\nWhat is here now is written to a backup of its own first, using the same passphrase, and the app will tell you its name.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get backupReplaceConfirm => 'Replace';

  @override
  String get backupRestoredNothingBefore =>
      'Restored. There was nothing here before, so nothing was set aside.';

  @override
  String backupRestoredWithSafety(String file) {
    return 'Restored. What was here before was written to $file in this app\'s own storage first.';
  }

  @override
  String get backupPassphrasesDiffer => 'The two passphrases are not the same.';

  @override
  String get backupWrongPassphrase =>
      'That passphrase does not open this backup.';

  @override
  String get backupFileUnusable => 'This file cannot be used as a backup.';

  @override
  String get backupRestoreRolledBack =>
      'The restore failed, and your data was put back as it was.';

  @override
  String get backupInterrupted =>
      'A half-finished restore was found and could not be undone.';

  @override
  String get backupKeyUnavailable =>
      'The encryption key could not be read or replaced.';

  @override
  String get backupUnexpected => 'Something went wrong.';

  @override
  String get cardsMyCards => 'My Cards';

  @override
  String get cardsAdd => '+  ADD';

  @override
  String get cardsNoCards =>
      'No credit cards yet. Add one to track its limit and debt here.';

  @override
  String get cardsMyAccounts => 'My Accounts';

  @override
  String get cardsActiveAssets => 'My Active Assets';

  @override
  String cardsHoldingsMeta(int count) {
    return '$count holdings · at cost';
  }

  @override
  String get cardsNoCashAccounts =>
      'No cash accounts yet. Everything else in Archlence needs one to move money into or out of.';

  @override
  String get cardsCashChecking => 'Cash / Checking';

  @override
  String get cardsCreditCardBadge => 'CREDIT CARD';

  @override
  String get cardsAvailableLimit => 'Available Limit';

  @override
  String get cardsCurrentDebt => 'Current Debt';

  @override
  String get cardsControls => 'Card Controls';

  @override
  String get cardsOnlineShopping => 'Online Shopping Preference';

  @override
  String get cardsOnlineShoppingNote => 'Stored as a preference only';

  @override
  String get cardsFreeze => 'Freeze Card';

  @override
  String get cardsFreezeNote => 'Blocks new spending, not debt payments';

  @override
  String get cardsRecentTransactions => 'Recent Transactions';

  @override
  String get cardsStatement => 'Statement';

  @override
  String get cardsPayDebt => 'Pay Debt';

  @override
  String get cardsNothingOnCard => 'Nothing on this card yet.';

  @override
  String get periodToday => 'Today';

  @override
  String get periodWeek => '1 Week';

  @override
  String get periodMonth => '1 Month';

  @override
  String get periodYear => '1 Year';

  @override
  String get periodAllTime => 'All Time';

  @override
  String get assetsDetails => 'Details';

  @override
  String get assetsIncome => 'Income';

  @override
  String get assetsExpense => 'Expense';

  @override
  String get assetsNetBalance => 'Net Balance';

  @override
  String get assetsMyActiveAssets => 'My Active Assets';

  @override
  String get assetsAtCostNote =>
      'Valued at purchase cost — no price source yet';

  @override
  String get assetsNoHoldings =>
      'No holdings yet. Anything you buy shows here with what it cost.';

  @override
  String get assetsOpeningBalance => 'Opening Balance';

  @override
  String get assetsNoDistribution =>
      'Nothing moved in this period, so there is no distribution to draw.';

  @override
  String get assetsDistributionTitle => 'Asset';

  @override
  String get assetsDistributionSubtitle => 'Distribution';

  @override
  String get assetsNoTrend =>
      'No income or spending in the last year, so there is no trend to draw yet.';

  @override
  String get assetsHoldingsAtCost => 'Holdings at Cost';

  @override
  String get assetsNothingBought => 'Nothing bought yet';

  @override
  String assetsHoldingCount(int count) {
    return '$count holdings';
  }

  @override
  String get assetsNoGoals =>
      'No savings goals yet. A goal holds money aside from your balance without counting as spending.';

  @override
  String assetsHoldingName(String name, String code) {
    return '$name ($code)';
  }

  @override
  String assetsPurchaseLine(String price, String quantity) {
    return 'Purchase: $price × $quantity';
  }

  @override
  String get assetsCost => 'Cost';

  @override
  String monthYearShort(String month, String year) {
    return '$month\'$year';
  }
}
