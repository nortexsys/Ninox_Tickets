import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/features/review/review_amounts.dart';
import 'package:paperdrop/features/review/review_field.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

import 'review_fixtures.dart';

/// The collapse rule of FR-REV-005 and the DEC-007 behaviour that goes with FR-REV-010.
///
/// `review-screen/amounts-block-collapse-rule` is decided by the redundancy check on the extracted
/// values and by nothing else, so every test here is a pure function over two canonical documents:
/// the one extraction produced, and the one the user has edited.
void main() {
  group('[review-screen/amounts-block-collapse-rule]', () {
    test('a confirmed document shows one line', () {
      final CanonicalDocument document = aConfirmedDocument();
      final ReviewAmounts amounts = reviewAmounts(
        extracted: document,
        current: document,
      );
      expect(amounts.collapsed, isTrue);
      expect(amounts.visibleLines, hasLength(1));
      expect(amounts.visibleLines.single.kind, AmountLineKind.total);
      expect(amounts.total, Money(1210, euro));
    });

    test('no breakdown to check means expanded', () {
      final CanonicalDocument document = aTotalOnlyDocument();
      final ReviewAmounts amounts = reviewAmounts(
        extracted: document,
        current: document,
      );
      expect(amounts.collapsed, isFalse);
      expect(
        amounts.visibleLines.map((ReviewAmountLine line) => line.kind),
        <AmountLineKind>[AmountLineKind.total],
      );
      expect(amountsCheckPassed(document), isFalse);
    });

    test('several slots are all visible when the check does not pass', () {
      final CanonicalDocument document = aMultiRateDocument();
      final ReviewAmounts amounts = reviewAmounts(
        extracted: document,
        current: document,
      );
      expect(amountsCheckPassed(document), isFalse);
      expect(amounts.collapsed, isFalse);
      expect(
        amounts.visibleLines.map((ReviewAmountLine line) => line.kind),
        <AmountLineKind>[
          AmountLineKind.base,
          AmountLineKind.tax,
          AmountLineKind.taxSlot,
          AmountLineKind.taxSlot,
          AmountLineKind.total,
        ],
      );
      expect(
        amounts.visibleLines
            .where(
              (ReviewAmountLine line) => line.kind == AmountLineKind.taxSlot,
            )
            .map((ReviewAmountLine line) => line.rate),
        <RateBp>[RateBp(2100), RateBp(1000)],
      );
    });

    test('an amber total does not collapse a document that adds up', () {
      final CanonicalDocument confirmed = aConfirmedDocument();
      final CanonicalDocument amberTotal = CanonicalDocument(
        docDate: confirmed.docDate,
        supplierName: confirmed.supplierName,
        grossTotal: aReadAmount(1210, ConfidenceState.amber),
        currency: confirmed.currency,
        netTotal: confirmed.netTotal,
        taxTotal: confirmed.taxTotal,
        needsReview: false,
        recognitionEngine: 'ocr/mlkit',
        sourceHash: confirmed.sourceHash,
      );
      expect(amountsCheckPassed(amberTotal), isFalse);
      expect(
        reviewAmounts(extracted: amberTotal, current: amberTotal).collapsed,
        isFalse,
      );
    });

    test('a failed arithmetic check keeps the block open even when the total is green', () {
      final CanonicalDocument confirmed = aConfirmedDocument();
      final CanonicalDocument offByOne = CanonicalDocument(
        docDate: confirmed.docDate,
        grossTotal: aReadAmount(1211, ConfidenceState.green),
        currency: confirmed.currency,
        netTotal: confirmed.netTotal,
        taxTotal: confirmed.taxTotal,
        needsReview: false,
        recognitionEngine: 'pdf-text/pdfrx',
        sourceHash: confirmed.sourceHash,
      );
      expect(amountsCheckPassed(offByOne), isFalse);
    });

    test('an edit after a passing check does not re-expand the block', () {
      final CanonicalDocument extracted = aConfirmedDocument();
      final CanonicalDocument current = editReviewField(
        document: extracted,
        field: ReviewField.grossTotal,
        text: '99.95',
      ).document!;
      final ReviewAmounts amounts = reviewAmounts(
        extracted: extracted,
        current: current,
      );
      expect(amounts.collapsed, isTrue);
      expect(amounts.total, Money(9995, euro));
      expect(amounts.totalEdited, isTrue);
    });

    test('an edit of the base leaves the layout to the check as well', () {
      final CanonicalDocument extracted = aConfirmedDocument();
      final CanonicalDocument current = editReviewField(
        document: extracted,
        field: ReviewField.supplierName,
        text: 'Corrected',
      ).document!;
      expect(
        reviewAmounts(extracted: extracted, current: current).collapsed,
        isTrue,
      );
    });
  });

  group('a rate is printed as the document prints it', () {
    test('whole and fractional basis points', () {
      expect(ratePercentText(RateBp(2100)), '21');
      expect(ratePercentText(RateBp(550)), '5.5');
      expect(ratePercentText(RateBp(275)), '2.75');
      expect(ratePercentText(RateBp(0)), '0');
    });
  });
}
