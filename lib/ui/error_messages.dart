/// Turns a service's error CODE into something a person can act on.
///
/// This file is where "services raise error codes, not sentences" pays off.
/// The services describe what went wrong in terms of their own rules; the
/// wording, the language and the tone belong here, and can be translated
/// without touching a rule. Since i18n landed, the wording is not even here
/// any more — it is in `lib/l10n/`, and this file is the map from rule to
/// label.
///
/// Every code is handled explicitly rather than through a default: an
/// unhandled one should be a compile error the day a service grows a new
/// rule, not a generic "something went wrong" a user cannot act on.
///
/// Several codes share one label on purpose. Six services can all fail to
/// read a typed figure, and "That is not an amount." is the same sentence
/// each time; giving each its own key would be six strings to keep in step
/// and six chances for them to drift apart in one language only.
library;

import '../l10n/app_localizations.dart';
import '../services/account_service.dart';
import '../services/asset_service.dart';
import '../services/budget_service.dart';
import '../services/calculators.dart';
import '../services/recurring_service.dart';
import '../services/savings_service.dart';
import '../services/transaction_service.dart';

String accountErrorMessage(
  AppLocalizations l10n,
  AccountError error,
) => switch (error.code) {
  AccountErrorCode.emptyName => l10n.errAccountEmptyName,
  AccountErrorCode.unknownAccountType => l10n.errAccountUnknownType,
  AccountErrorCode.invalidAmount => l10n.errNotAnAmount,
  AccountErrorCode.invalidStatementDay => l10n.errAccountInvalidStatementDay,
  AccountErrorCode.creditLimitRequired => l10n.errAccountCreditLimitRequired,
  AccountErrorCode.negativeOpeningDebt => l10n.errAccountNegativeOpeningDebt,
  AccountErrorCode.openingDebtExceedsLimit =>
    l10n.errAccountOpeningDebtExceedsLimit,
  AccountErrorCode.accountNotFound => l10n.errAccountNotFound,
  AccountErrorCode.cardFrozen => l10n.errAccountCardFrozen,
  AccountErrorCode.insufficientLimit => l10n.errAccountInsufficientLimit,
  AccountErrorCode.invalidPaymentAmount => l10n.errNotAnAmount,
  AccountErrorCode.paymentNotPositive => l10n.errAmountNotPositive,
  AccountErrorCode.notACreditCard => l10n.errAccountNotACreditCard,
  AccountErrorCode.noDebtToPay => l10n.errAccountNoDebtToPay,
  AccountErrorCode.paymentExceedsDebt => l10n.errAccountPaymentExceedsDebt,
  AccountErrorCode.sourceMustBeChecking => l10n.errAccountSourceMustBeChecking,
  AccountErrorCode.balanceUpdateFailed => l10n.errAccountBalanceUpdateFailed,
  AccountErrorCode.unknownCardPreference =>
    l10n.errAccountUnknownCardPreference,
};

String transactionErrorMessage(AppLocalizations l10n, TransactionError error) =>
    switch (error.code) {
      TransactionErrorCode.invalidAmount => l10n.errNotAnAmount,
      TransactionErrorCode.amountNotPositive => l10n.errAmountNotPositive,
      TransactionErrorCode.installmentCountOutOfRange =>
        l10n.errTransactionInstallmentRange,
      TransactionErrorCode.negativeLimit => l10n.errTransactionNegativeLimit,
    };

String assetErrorMessage(AppLocalizations l10n, AssetError error) =>
    switch (error.code) {
      AssetErrorCode.invalidAmount => l10n.errAssetInvalidAmount,
      AssetErrorCode.assetNotFound => l10n.errAssetNotFound,
    };

String savingsErrorMessage(AppLocalizations l10n, SavingsError error) =>
    switch (error.code) {
      SavingsErrorCode.emptyName => l10n.errSavingsEmptyName,
      SavingsErrorCode.invalidAmount => l10n.errNotAnAmount,
      SavingsErrorCode.amountNotPositive => l10n.errAmountNotPositive,
      SavingsErrorCode.negativeOpeningAmount =>
        l10n.errSavingsNegativeOpeningAmount,
      SavingsErrorCode.identityMismatch => l10n.errSavingsIdentityMismatch,
      SavingsErrorCode.accountNotFound => l10n.errSavingsAccountNotFound,
      SavingsErrorCode.goalNotFoundOrCompleted =>
        l10n.errSavingsGoalNotFoundOrCompleted,
      SavingsErrorCode.insufficientGoalBalance =>
        l10n.errSavingsInsufficientBalance,
      SavingsErrorCode.refundAccountRequired =>
        l10n.errSavingsRefundAccountRequired,
    };

String budgetErrorMessage(AppLocalizations l10n, BudgetError error) =>
    switch (error.code) {
      BudgetErrorCode.unknownItemType => l10n.errBudgetUnknownItemType,
      BudgetErrorCode.emptyName => l10n.errBudgetEmptyName,
      BudgetErrorCode.invalidAmount => l10n.errNotAnAmount,
      BudgetErrorCode.amountNotPositive => l10n.errAmountNotPositive,
      BudgetErrorCode.invalidMonth => l10n.errBudgetInvalidMonth,
      BudgetErrorCode.invalidAlertThreshold =>
        l10n.errBudgetInvalidAlertThreshold,
    };

String recurringErrorMessage(AppLocalizations l10n, RecurringError error) =>
    switch (error.code) {
      RecurringErrorCode.unknownFrequency => l10n.errRecurringUnknownFrequency,
      RecurringErrorCode.invalidRecurrenceDay => l10n.errRecurringInvalidDay,
      RecurringErrorCode.invalidAmount => l10n.errNotAnAmount,
      RecurringErrorCode.amountNotPositive => l10n.errAmountNotPositive,
      RecurringErrorCode.invalidTransactionType =>
        l10n.errRecurringInvalidTransactionType,
      RecurringErrorCode.unreadablePayment =>
        l10n.errRecurringUnreadablePayment,
    };

String calculatorErrorMessage(AppLocalizations l10n, CalculatorError error) =>
    switch (error.code) {
      CalculatorErrorCode.notANumber => l10n.errCalcNotANumber,
      CalculatorErrorCode.notPositive => l10n.errCalcNotPositive,
      // The only one that names a figure, because "too long" without the cap
      // leaves the user guessing at what the app will accept.
      CalculatorErrorCode.termTooLong => l10n.errCalcTermTooLong(
        loanMaxTermMonths,
      ),
      CalculatorErrorCode.invalidExpression => l10n.errCalcInvalidExpression,
    };
