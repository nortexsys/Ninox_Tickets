/// The review screen's two message mappings, in one place.
///
/// Requirement served: NFR-I18N-001 (`local-config-privacy/all-user-facing-strings-are-externalised`)
/// — every sentence the screen shows is a key of `app_en.arb` — for the labels of FR-REV-004's six
/// fields, the names of the three confidence states, the lines of the amounts block, the refusal an
/// edit earns, and the country line and second read of `adopt-app-cust-readers`.
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
    show ConfidenceState, RateBp, ValueSource;

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

/// The country in force for the ticket, as the country line shows it
/// (`review-screen` · `country-shown-and-editable-per-ticket`).
///
/// The value is the ISO 3166-1 alpha-2 code the settings hold — `ES`, `DE`, `PT` — because that is
/// what the country is and what the country table answers for; a country the app has no name for in
/// its dictionaries is still a country, and inventing a display name here would be data no
/// requirement asked for. `null` is the settings' *no country at all*, and it is said in words
/// rather than left blank.
String reviewCountryText(AppLocalizations l10n, String? countryCode) =>
    countryCode ?? l10n.reviewCountryUnset;

/// Where the country on the ticket came from: the settings, or a change made for this ticket.
///
/// The two are told apart on purpose — DEC-023's origin has to be visible for the currency, and the
/// same is true of the country itself: a user who changed the country of one ticket must be able to
/// see that the next one goes back to the default.
String reviewCountrySource(AppLocalizations l10n, bool fromSettings) =>
    fromSettings ? l10n.reviewCountryFromSettings : l10n.reviewCountryForTicket;

/// The warning a ticket owes the user when no country row is in force (GAP-036).
///
/// Two cases, one consequence: a country the table has no row for, and a settings file that names
/// no country at all. Neither applies a row in the other's place, and both leave the fields to the
/// user.
String reviewCountryWarning(AppLocalizations l10n, String? countryCode) =>
    countryCode == null
    ? l10n.reviewCountryUnsetWarning
    : l10n.reviewCountryNoRowWarning;

/// Where a value came from, when that is worth a line of its own — `null` when it is not.
///
/// The photo route's currency is green *because* its source is the country setting and not a reading
/// (DEC-023), so the screen says so; a value read from the document needs no such line, and supplier
/// memory (`ValueSource.memory`) has none in this change.
String? reviewValueSourceLabel(AppLocalizations l10n, ValueSource? source) =>
    switch (source) {
      ValueSource.countrySetting => l10n.reviewCurrencySourceCountrySetting,
      ValueSource.document || ValueSource.memory || null => null,
    };
