/// The six core fields the review screen shows, and what an edit to one of them produces.
///
/// Requirement served: FR-REV-004 (`review-screen/six-core-fields-in-fixed-order`) for the fixed
/// order, FR-REV-010 (`review-screen/user-edits-are-authoritative`) for what an edit is, and
/// `validation-confidence/green-is-editable-only-after-unlocking` for the lock rule that decides
/// whether a field can be edited at all. Design §1 and §2 of `implement-review-screen` settle the
/// rest.
///
/// **The order is the requirement's.** [ReviewField.values] is `doc_date`, `supplier_name`,
/// `supplier_tax_id`, `doc_number`, `gross_total`, `currency` and nothing re-sorts it: a screen
/// that iterates the enum has the order of FR-REV-004, on every route, by construction
/// (`six-core-fields-in-fixed-order` · *the order is identical everywhere*).
///
/// **An edit is not a value.** [editReviewField] answers a document whose field is an [Edited] —
/// the core's own case for a value the user typed, which carries no provenance and no confidence
/// and can never confirm anything (BR-02, DEC-007). Nothing here recomputes a field, re-imposes a
/// colour or re-validates a user's correction: the value the user typed is the value, and the
/// screen shows the *edited* mark instead of a colour.
///
/// **Nothing here reads the clock, the store or a screen.** These are pure functions over the
/// core's canonical document, so a host test covers every rule without a device (design §1).
library;

import 'package:paperdrop_core/paperdrop_core.dart'
    show
        Absent,
        CalendarDate,
        CanonicalDocument,
        ConfidenceState,
        CurrencyCode,
        Edited,
        FieldValue,
        Money,
        MoneyRangeError,
        NotInXml,
        Present,
        calendarDateCodec,
        currencyCodec,
        moneyCodec,
        stringCodec;

/// One of the six core fields, in the fixed order of FR-REV-004 (design §2).
enum ReviewField {
  /// The document's date.
  docDate('doc_date', 'docDate'),

  /// The supplier's printed name.
  supplierName('supplier_name', 'supplierName'),

  /// The supplier's tax identifier.
  supplierTaxId('supplier_tax_id', 'supplierTaxId'),

  /// The document's own number.
  docNumber('doc_number', 'docNumber'),

  /// The gross total.
  grossTotal('gross_total', 'grossTotal'),

  /// The currency the amounts are printed in.
  currency('currency', 'currency');

  const ReviewField(this.wireName, this.jsonKey);

  /// The canonical field's own name, as the specification writes it (FR-REV-004).
  ///
  /// It is the field's identity in a test's key and in a diagnostic, never user-facing text
  /// (NFR-I18N-001): the name a person reads comes from `app_en.arb`.
  final String wireName;

  /// The key this field has in the canonical document's own JSON (BR-09).
  ///
  /// An edit is applied by reading the document's JSON, replacing this one key and reading it back
  /// as a document: the core's own round trip, so nothing here can build a value the core would
  /// not have written itself.
  final String jsonKey;
}

/// One core field as the screen shows it.
///
/// [confidence] is the colour the field is drawn in, or `null` when there is none to draw —
/// an edited value carries no colour at all, because the *edited* mark replaces it (DEC-007,
/// `user-edits-are-authoritative` · *editing does not restore a colour*). A field nothing was read
/// for is [ConfidenceState.red]: `validation-confidence/three-confidence-strengths` calls that
/// state *not read at all*, and it is what the focus rule looks for.
final class ReviewFieldValue {
  /// Binds the text the field shows to the colour and the mark it shows with.
  const ReviewFieldValue({
    required this.text,
    required this.confidence,
    required this.edited,
    required this.read,
  });

  /// The value as the field shows it, or the empty string when nothing was read.
  ///
  /// It is the canonical text form — `YYYY-MM-DD` for a date, the decimal form of the amount for a
  /// total, the code for a currency — because what is shown and what is typed have to be the same
  /// text for an inline editor to be honest about what it holds.
  final String text;

  /// The colour of the field, or `null` when the field is edited and shows the mark instead.
  final ConfidenceState? confidence;

  /// Whether the user typed this value, which is what the *edited* mark says (DEC-007).
  final bool edited;

  /// Whether a value was read at all — false for [Absent] and [NotInXml].
  ///
  /// Distinct from [edited] and from a text of `''`: the user may have typed nothing, which is a
  /// value they typed, and nothing read is not the same thing.
  final bool read;

  /// Whether this field can be edited without unlocking it first.
  ///
  /// Amber and red are directly editable, an edited value is already the user's, and green is
  /// editable only after its lock is tapped (`green-is-editable-only-after-unlocking`).
  bool get editableWithoutUnlock => confidence != ConfidenceState.green;

  @override
  bool operator ==(Object other) =>
      other is ReviewFieldValue &&
      other.text == text &&
      other.confidence == confidence &&
      other.edited == edited &&
      other.read == read;

  @override
  int get hashCode => Object.hash(text, confidence, edited, read);

  @override
  String toString() =>
      'ReviewFieldValue(${read ? 'read' : 'not read'}'
      '${edited ? ', edited' : ''}, ${confidence?.name ?? 'no colour'})';
}

/// The six fields of [document], in the order of FR-REV-004.
List<ReviewFieldValue> reviewFieldValues(CanonicalDocument document) =>
    <ReviewFieldValue>[
      for (final ReviewField field in ReviewField.values)
        reviewFieldValue(document, field),
    ];

/// [field] of [document] as the screen shows it.
ReviewFieldValue reviewFieldValue(
  CanonicalDocument document,
  ReviewField field,
) => switch (field) {
  ReviewField.docDate => _shown(document.docDate, _dateText),
  ReviewField.supplierName => _shown(document.supplierName, _textOf),
  ReviewField.supplierTaxId => _shown(document.supplierTaxId, _textOf),
  ReviewField.docNumber => _shown(document.docNumber, _textOf),
  ReviewField.grossTotal => _shown(document.grossTotal, _amountText),
  ReviewField.currency => _shown(document.currency, _currencyText),
};

/// The field of FR-REV-004 that should hold the focus when the screen opens (design §2).
///
/// The first field that was **not read** — [Absent] or [NotInXml], which the screen draws red — or
/// whose state is red, and `doc_date` when every one of the six was read
/// (`six-core-fields-in-fixed-order` · *focus goes to what needs attention*, *a fully read document
/// focuses the first field*).
ReviewField reviewFocusField(CanonicalDocument document) {
  for (final ReviewField field in ReviewField.values) {
    final ReviewFieldValue value = reviewFieldValue(document, field);
    if (!value.read || value.confidence == ConfidenceState.red) {
      return field;
    }
  }
  return ReviewField.docDate;
}

/// Why an edit was not taken.
///
/// A code, never a message: the screen translates it from `app_en.arb` (NFR-I18N-001), exactly as
/// `features/capture/capture_messages.dart` translates the intake's codes.
enum ReviewEditRefusal {
  /// `doc_date` was typed as something that is not a `YYYY-MM-DD` date.
  notADate,

  /// `gross_total` was typed as something that is not an amount in the document's currency —
  /// including an amount with more fractional digits than that currency has.
  notAnAmount,

  /// `currency` was typed as a code ISO 4217 does not know.
  unknownCurrency,

  /// `gross_total` was typed while the document has no currency: an amount is an integer in a
  /// currency's minor unit, and no exponent may be assumed for one (see `CurrencyCode`).
  amountNeedsCurrency,
}

/// What one edit did: the document as it now reads, or why nothing was changed.
final class ReviewEdit {
  /// The edit was taken: [document] carries the typed value as an [Edited].
  const ReviewEdit.accepted(this.document) : refusal = null;

  /// The edit was refused: [refusal] says why, and nothing changed.
  const ReviewEdit.refused(this.refusal) : document = null;

  /// The document after a taken edit, or `null` when the edit was refused.
  final CanonicalDocument? document;

  /// Why the edit was refused, or `null` when it was taken.
  final ReviewEditRefusal? refusal;

  /// Whether the edit was taken.
  bool get accepted => refusal == null;

  @override
  String toString() =>
      'ReviewEdit(${refusal == null ? 'accepted' : refusal!.name})';
}

/// [document] with [field] carrying the value the user typed as [text], or the refusal.
///
/// The typed value is an [Edited] of the core's model — never a [Present]: it has no provenance, no
/// confidence and nothing to confirm, and it is what a save sends
/// (`user-edits-are-authoritative` · *the correction is what reaches Ninox*). Every other field of
/// the document is carried over unchanged, through the core's own JSON (BR-09), so this function
/// cannot invent a value of its own.
ReviewEdit editReviewField({
  required CanonicalDocument document,
  required ReviewField field,
  required String text,
}) {
  final String typed = text.trim();
  switch (field) {
    case ReviewField.docDate:
      final CalendarDate date;
      try {
        date = CalendarDate.parse(typed);
      } on FormatException {
        return const ReviewEdit.refused(ReviewEditRefusal.notADate);
      }
      return ReviewEdit.accepted(
        _withField(
          document,
          field,
          Edited<CalendarDate>(date).toJson(calendarDateCodec),
        ),
      );
    case ReviewField.supplierName:
    case ReviewField.supplierTaxId:
    case ReviewField.docNumber:
      return ReviewEdit.accepted(
        _withField(document, field, Edited<String>(typed).toJson(stringCodec)),
      );
    case ReviewField.grossTotal:
      final CurrencyCode? currency = _currencyOf(document);
      if (currency == null) {
        // An amount is an integer in its currency's minor unit, and a currency without an exponent
        // does not exist: guessing one would put a wrong number in the user's table.
        return const ReviewEdit.refused(ReviewEditRefusal.amountNeedsCurrency);
      }
      final Money amount;
      try {
        amount = Money.parseDecimal(typed, currency);
      } on FormatException {
        return const ReviewEdit.refused(ReviewEditRefusal.notAnAmount);
      } on MoneyRangeError {
        return const ReviewEdit.refused(ReviewEditRefusal.notAnAmount);
      }
      return ReviewEdit.accepted(
        _withField(document, field, Edited<Money>(amount).toJson(moneyCodec)),
      );
    case ReviewField.currency:
      final CurrencyCode? currency = CurrencyCode.parse(typed.toUpperCase());
      if (currency == null) {
        return const ReviewEdit.refused(ReviewEditRefusal.unknownCurrency);
      }
      return ReviewEdit.accepted(
        _withField(
          document,
          field,
          Edited<CurrencyCode>(currency).toJson(currencyCodec),
        ),
      );
  }
}

/// [document] with the JSON of [field] replaced by [json] and read back as a document.
CanonicalDocument _withField(
  CanonicalDocument document,
  ReviewField field,
  Object? json,
) => CanonicalDocument.fromJson(<String, Object?>{
  ...document.toJson(),
  field.jsonKey: json,
});

/// The currency of [document] — read or typed — or `null` when there is none.
CurrencyCode? _currencyOf(CanonicalDocument document) =>
    switch (document.currency) {
      Present<CurrencyCode>(value: final CurrencyCode value) => value,
      Edited<CurrencyCode>(value: final CurrencyCode value) => value,
      _ => null,
    };

/// [value] as the screen shows it.
ReviewFieldValue _shown<T>(
  FieldValue<T> value,
  String Function(T value) text,
) => switch (value) {
  Present<T>(:final T value, :final ConfidenceState confidence) =>
    ReviewFieldValue(
      text: text(value),
      confidence: confidence,
      edited: false,
      read: true,
    ),
  Edited<T>(:final T value) => ReviewFieldValue(
    text: text(value),
    confidence: null,
    edited: true,
    read: true,
  ),
  Absent<T>() || NotInXml<T>() => const ReviewFieldValue(
    text: '',
    confidence: ConfidenceState.red,
    edited: false,
    read: false,
  ),
};

/// A date in the canonical form it is typed in.
String _dateText(CalendarDate value) => value.toString();

/// A text value as it stands.
String _textOf(String value) => value;

/// An amount in the canonical decimal form of its own currency — the form it is typed in.
String _amountText(Money value) => value.toDecimalString();

/// A currency by its ISO 4217 code.
String _currencyText(CurrencyCode value) => value.code;
