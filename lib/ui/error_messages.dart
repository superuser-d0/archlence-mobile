/// Turns a service's error CODE into something a person can act on.
///
/// This file is where "services raise error codes, not sentences" pays off.
/// The services describe what went wrong in terms of their own rules; the
/// wording, the language and the tone belong here, and can be translated
/// without touching a rule.
///
/// Every code is handled explicitly rather than through a default: an
/// unhandled one should be a compile error the day a service grows a new
/// rule, not a generic "something went wrong" a user cannot act on.
library;

import '../services/account_service.dart';
import '../services/transaction_service.dart';

String accountErrorMessage(AccountError error) => switch (error.code) {
  AccountErrorCode.emptyName => 'Give the account a name.',
  AccountErrorCode.unknownAccountType => 'Choose an account type.',
  AccountErrorCode.invalidAmount => 'That is not an amount.',
  AccountErrorCode.invalidStatementDay =>
    'The statement day has to be between 1 and 31.',
  AccountErrorCode.creditLimitRequired =>
    'A credit card needs a limit above zero.',
  AccountErrorCode.negativeOpeningDebt => 'Debt cannot be a negative amount.',
  AccountErrorCode.openingDebtExceedsLimit =>
    'The debt is larger than the limit you entered.',
  AccountErrorCode.accountNotFound => 'That account no longer exists.',
  AccountErrorCode.cardFrozen =>
    'This card is frozen. Unfreeze it to spend on it.',
  AccountErrorCode.insufficientLimit =>
    'That would go past the card\'s available limit.',
  AccountErrorCode.invalidPaymentAmount => 'That is not an amount.',
  AccountErrorCode.paymentNotPositive => 'Enter an amount above zero.',
  AccountErrorCode.notACreditCard => 'That is not a credit card.',
  AccountErrorCode.noDebtToPay => 'There is nothing owing on this card.',
  AccountErrorCode.paymentExceedsDebt => 'That is more than the card owes.',
  AccountErrorCode.sourceMustBeChecking =>
    'Pay a card from a cash account, not another card.',
  AccountErrorCode.balanceUpdateFailed =>
    'The balance could not be updated. Nothing was changed.',
  AccountErrorCode.unknownCardPreference => 'Unknown card setting.',
};

String transactionErrorMessage(TransactionError error) => switch (error.code) {
  TransactionErrorCode.invalidAmount => 'That is not an amount.',
  TransactionErrorCode.amountNotPositive => 'Enter an amount above zero.',
  TransactionErrorCode.installmentCountOutOfRange =>
    'Instalments have to be between 1 and 12.',
  TransactionErrorCode.negativeLimit => 'The limit cannot be negative.',
};
