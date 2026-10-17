/// The review screen's two message mappings, in one place.
///
/// Requirement served: NFR-I18N-001 (`local-config-privacy/all-user-facing-strings-are-externalised`)
/// — every sentence the screen shows is a key of `app_en.arb` — for the labels of FR-REV-004's six
/// fields, the names of the three confidence states, the lines of the amounts block and the refusal
/// an edit earns.
///
/// **Exhaustive by construction.** Each function switches over its enum without a default, so a new
/// field, state, amount line or refusal cannot be added without the compiler asking for its
/// sentence — the pattern `features/capture/capture_messages.dart` already uses. Nothing here
/// formats a number: an amount arrives as the text the canonical value already has, so what the
/// user reads is what an edit would show and what a test can compare.
library;

import 'package:paperdrop/features/review/review_amounts.dart';
import 'package:paperdrop/features/review/review_field.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';
import 'package:paperdrop_core/paperdrop_core.dart'
    show ConfidenceState, RateBp;

/// The plain-language name of one of the six core fields (FR-REV-004).
String reviewFieldLabel(AppLocalizations l10n, ReviewField field) =>
    switch (field) {
      ReviewField.docDate => l10n.reviewFieldDocDate,
      ReviewField.supplierName => l10n.reviewFieldSupplierName,
      ReviewField.supplierTaxId => l10n.reviewFieldSupplierTaxId,
      ReviewField.docNumber => l10n.reviewFieldDocNumber,
      ReviewField.grossTotal => l10n.reviewFieldGrossTotal,
      ReviewField.currency => l10n.reviewFieldCurrency,
    };

/// The name of one confidence state, for the icon's semantic label (NFR-ACC-001).
///
/// The words carry the meaning `validation-confidence` gives each strength: green is *confirmed*,
/// amber is read and *not confirmed*, red is *not read*. A value the user typed has no state and
/// says [reviewEditedLabel] instead (DEC-007).
String reviewConfidenceLabel(AppLocalizations l10n, ConfidenceState state) =>
    switch (state) {
      ConfidenceState.green => l10n.reviewConfidenceGreen,
      ConfidenceState.amber => l10n.reviewConfidenceAmber,
      ConfidenceState.red => l10n.reviewConfidenceRed,
    };

/// The mark of a value the user typed, which replaces its colour (DEC-007).
String reviewEditedLabel(AppLocalizations l10n) => l10n.reviewEdited;

/// What a field says when nothing was read for it.
String reviewValueNotReadLabel(AppLocalizations l10n) =>
    l10n.reviewValueNotRead;

/// The text of one line of the amounts block, with [amount] as the canonical text of the amount.
///
/// A slot without a printed rate is named as a tax amount: the line is there because the slot is
/// occupied, and a rate nobody read is not a rate to show.
String reviewAmountLineText(
  AppLocalizations l10n,
  ReviewAmountLine line,
  String amount,
) => switch (line.kind) {
  AmountLineKind.base => l10n.reviewAmountsBase(amount),
  AmountLineKind.tax => l10n.reviewAmountsTax(amount),
  AmountLineKind.taxSlot => switch (line.rate) {
    final RateBp rate => l10n.reviewAmountsSlot(ratePercentText(rate), amount),
    _ => l10n.reviewAmountsTax(amount),
  },
  AmountLineKind.total => l10n.reviewAmountsTotal(amount),
};

/// The one confirming line the collapsed block shows (FR-REV-005).
String reviewAmountsConfirmedText(AppLocalizations l10n, String total) =>
    l10n.reviewAmountsConfirmed(total);

/// What the user is told when a value could not be taken (design §2).
String reviewEditRefusalMessage(
  AppLocalizations l10n,
  ReviewEditRefusal refusal,
) => switch (refusal) {
  ReviewEditRefusal.notADate => l10n.reviewErrorNotADate,
  ReviewEditRefusal.notAnAmount => l10n.reviewErrorNotAnAmount,
  ReviewEditRefusal.unknownCurrency => l10n.reviewErrorUnknownCurrency,
  ReviewEditRefusal.amountNeedsCurrency => l10n.reviewErrorAmountNeedsCurrency,
};
