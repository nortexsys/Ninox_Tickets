import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/features/review/review_field.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

import 'review_fixtures.dart';

/// The six core fields of FR-REV-004 and the edit rule of FR-REV-010, as pure functions.
///
/// FR-REV-004 (`review-screen/six-core-fields-in-fixed-order`) owns the order, the focus rule and
/// the colour-and-cue of a value; FR-REV-010 (`review-screen/user-edits-are-authoritative`) owns
/// what an edit produces. Both are decided over the core's canonical document, so no test here
/// needs a widget, a store or a device.
void main() {
  group('[review-screen/six-core-fields-in-fixed-order]', () {
    test('the six fields are in the requirement\'s fixed order', () {
      expect(
        ReviewField.values.map((ReviewField field) => field.wireName),
        <String>[
          'doc_date',
          'supplier_name',
          'supplier_tax_id',
          'doc_number',
          'gross_total',
          'currency',
        ],
      );
    });

    test('the values of a document are produced in that order', () {
      final CanonicalDocument document = aConfirmedDocument();
      expect(reviewFieldValues(document), <ReviewFieldValue>[
        for (final ReviewField field in ReviewField.values)
          reviewFieldValue(document, field),
      ]);
      expect(reviewFieldValues(document), hasLength(6));
    });

    test('a value is shown with its colour, in its canonical text form', () {
      final CanonicalDocument document = aConfirmedDocument();
      expect(
        reviewFieldValue(document, ReviewField.docDate).text,
        '2026-10-01',
      );
      expect(reviewFieldValue(document, ReviewField.grossTotal).text, '12.10');
      expect(reviewFieldValue(document, ReviewField.currency).text, 'EUR');
      expect(
        reviewFieldValue(document, ReviewField.docDate).confidence,
        ConfidenceState.green,
      );
      expect(
        reviewFieldValue(document, ReviewField.supplierName).confidence,
        ConfidenceState.amber,
      );
    });

    test('a field nothing was read for is red and says so', () {
      final ReviewFieldValue value = reviewFieldValue(
        anUnreadDocument(),
        ReviewField.supplierName,
      );
      expect(value.read, isFalse);
      expect(value.text, isEmpty);
      expect(value.confidence, ConfidenceState.red);
      expect(value.edited, isFalse);
    });

    test('focus goes to what needs attention', () {
      final CanonicalDocument confirmed = aConfirmedDocument();
      final CanonicalDocument withoutSupplier = CanonicalDocument(
        docDate: confirmed.docDate,
        supplierTaxId: confirmed.supplierTaxId,
        docNumber: confirmed.docNumber,
        grossTotal: confirmed.grossTotal,
        currency: confirmed.currency,
        netTotal: confirmed.netTotal,
        taxTotal: confirmed.taxTotal,
        needsReview: false,
        recognitionEngine: 'pdf-text/pdfrx',
        sourceHash: confirmed.sourceHash,
      );
      expect(reviewFocusField(withoutSupplier), ReviewField.supplierName);
    });

    test('a red value is where the focus goes', () {
      final CanonicalDocument confirmed = aConfirmedDocument();
      final CanonicalDocument redTaxId = CanonicalDocument(
        docDate: confirmed.docDate,
        supplierName: confirmed.supplierName,
        supplierTaxId: Present<String>(
          'B00000000',
          Provenance.read,
          ConfidenceState.red,
        ),
        docNumber: confirmed.docNumber,
        grossTotal: confirmed.grossTotal,
        currency: confirmed.currency,
        netTotal: confirmed.netTotal,
        taxTotal: confirmed.taxTotal,
        needsReview: false,
        recognitionEngine: 'pdf-text/pdfrx',
        sourceHash: confirmed.sourceHash,
      );
      expect(reviewFocusField(redTaxId), ReviewField.supplierTaxId);
    });

    test('a fully read document focuses its first field', () {
      expect(reviewFocusField(aConfirmedDocument()), ReviewField.docDate);
    });
  });

  group('[review-screen/user-edits-are-authoritative]', () {
    test('a typed total is an Edited value in the document\'s currency', () {
      final ReviewEdit edit = editReviewField(
        document: aConfirmedDocument(),
        field: ReviewField.grossTotal,
        text: '99.95',
      );
      final CanonicalDocument edited = edit.document!;
      expect(edited.grossTotal, Edited<Money>(Money(9995, euro)));
      expect(reviewFieldValue(edited, ReviewField.grossTotal).edited, isTrue);
    });

    test('editing does not restore a colour, and marks the field', () {
      final CanonicalDocument edited = editReviewField(
        document: aConfirmedDocument(),
        field: ReviewField.supplierName,
        text: 'Corrected S.L.',
      ).document!;
      final ReviewFieldValue value = reviewFieldValue(
        edited,
        ReviewField.supplierName,
      );
      expect(value.confidence, isNull);
      expect(value.edited, isTrue);
      expect(value.text, 'Corrected S.L.');
      expect(value.editableWithoutUnlock, isTrue);
    });

    test('nothing else is recomputed by an edit', () {
      final CanonicalDocument document = aConfirmedDocument();
      final CanonicalDocument edited = editReviewField(
        document: document,
        field: ReviewField.grossTotal,
        text: '20.00',
      ).document!;
      expect(edited.netTotal, document.netTotal);
      expect(edited.taxTotal, document.taxTotal);
      expect(edited.currency, document.currency);
      expect(edited.docDate, document.docDate);
    });

    test('a date is typed as YYYY-MM-DD and anything else is refused', () {
      final ReviewEdit accepted = editReviewField(
        document: aConfirmedDocument(),
        field: ReviewField.docDate,
        text: '2026-11-30',
      );
      expect(
        accepted.document!.docDate,
        Edited<CalendarDate>(CalendarDate(2026, 11, 30)),
      );
      expect(
        editReviewField(
          document: aConfirmedDocument(),
          field: ReviewField.docDate,
          text: '30.11.2026',
        ).refusal,
        ReviewEditRefusal.notADate,
      );
    });

    test(
      'a currency is a code ISO 4217 knows, and an unknown one is refused',
      () {
        expect(
          editReviewField(
            document: aConfirmedDocument(),
            field: ReviewField.currency,
            text: 'usd',
          ).document!.currency,
          Edited<CurrencyCode>(CurrencyCode.parse('USD')!),
        );
        expect(
          editReviewField(
            document: aConfirmedDocument(),
            field: ReviewField.currency,
            text: 'XYZ',
          ).refusal,
          ReviewEditRefusal.unknownCurrency,
        );
      },
    );

    test(
      'an amount is refused when it is not one, or when there is no currency',
      () {
        expect(
          editReviewField(
            document: aConfirmedDocument(),
            field: ReviewField.grossTotal,
            text: 'twelve',
          ).refusal,
          ReviewEditRefusal.notAnAmount,
        );
        expect(
          editReviewField(
            document: anUnreadDocument(),
            field: ReviewField.grossTotal,
            text: '12.00',
          ).refusal,
          ReviewEditRefusal.amountNeedsCurrency,
        );
      },
    );

    test('a refused edit changes nothing', () {
      final ReviewEdit refused = editReviewField(
        document: aConfirmedDocument(),
        field: ReviewField.docDate,
        text: 'not a date',
      );
      expect(refused.accepted, isFalse);
      expect(refused.document, isNull);
    });

    test('a green value is locked, an amber or edited one is not', () {
      final CanonicalDocument document = aConfirmedDocument();
      expect(
        reviewFieldValue(
          document,
          ReviewField.grossTotal,
        ).editableWithoutUnlock,
        isFalse,
      );
      expect(
        reviewFieldValue(
          document,
          ReviewField.supplierName,
        ).editableWithoutUnlock,
        isTrue,
      );
      final CanonicalDocument unread = anUnreadDocument();
      expect(
        reviewFieldValue(unread, ReviewField.currency).editableWithoutUnlock,
        isTrue,
      );
    });
  });
}
