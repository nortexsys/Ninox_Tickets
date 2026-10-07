import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/features/wizard/matching/similarity.dart';

/// The score of the second stage, and the two rules that carry design §5's own German fixture
/// (design §5, FR-WIZ-006).
///
/// **Why this file exists at all.** Design §5 states the score as *the greater of the whole-string
/// similarity (one minus normalised edit distance) and the token-set similarity*. Measured against
/// the dictionary the project actually ships, that sketch cannot produce the outcome the same design
/// requires of `Belegdatum` and `Betrag`: Annex C carries neither term, and `Belegdatum` against the
/// nearest one that exists (`Datum`) is one half by edit distance and zero by token set — both below
/// any strict threshold. The two rules below are the difference, and they are pinned here one by one
/// so a reviewer can argue with each of them instead of with a number.
///
/// No test here names the threshold or the margin: those are `field_matcher.dart`'s, and the fixtures
/// in `field_matcher_test.dart` are what speak for the outcomes.
void main() {
  test('normalisation folds case, diacritics, camel case, separators and '
      'punctuation to one form', () {
    // The spellings of one term of Annex C, and two invented column names in the same shapes. `º`
    // is not punctuation: it is U+00BA, a Unicode *letter*, so it stays — consistently on both sides
    // of a comparison, which is what matters.
    expect(normalise('Nº FACTURA'), normalise('Nº Factura'));
    expect(normalise('Nº Factura'), 'nº factura');
    expect(normalise('DocNumber'), 'doc number');
    expect(normalise('doc_number'), 'doc number');
    expect(normalise('DOC-NUMBER'), 'doc number');
    expect(normalise('  Total   à   payer  '), 'total a payer');
    // `MwSt.` carries a lower-case-to-upper-case boundary inside an abbreviation, so the camel rule
    // splits it — applying the same rule to the dictionary's own `MwSt.` entry, which is what makes
    // a column written that way agree with it. `MWST`, Annex C's other spelling of the same tax, is
    // one word and stays one.
    expect(normalise('MwSt.'), 'mw st');
    expect(normalise('MWST'), 'mwst');
    expect(normalise('Base imponible'), 'base imponible');
    expect(normalise(''), '');
  });

  test(
    'a name and a term that differ only in one of those ways are one string',
    () {
      expect(termSimilarity('DocNumber', 'doc_number'), 1);
      expect(termSimilarity('Nº FACTURA', 'N.º de factura'), isNot(1));
      expect(termSimilarity('Kunden-Nummer', 'Kunden Nummer'), 1);
      expect(termSimilarity('Gesamtbetrag', 'gesamtbetrag'), 1);
    },
  );

  test('a letter the folding map does not carry is kept, not dropped', () {
    // Only punctuation and separators go; a name in an alphabet the map does not know is still
    // compared as it is written.
    expect(normalise('Дата'), 'дата');
    expect(normalise('Faktura-Nr.'), 'faktura nr');
  });

  test('an exact match is the highest score there is', () {
    for (final String term in <String>[
      'Datum',
      'Betrag',
      'Lieferant',
      'Nº FACTURA',
      'Zwischensumme',
    ]) {
      expect(termSimilarity(term, term), 1);
      expect(termSimilarity(term, term), greaterThan(containedTermSimilarity));
    }
  });

  test('the whole-string component reads a near miss as a near miss', () {
    // One letter apart in a seven-letter word, and two apart in a longer one: both are scores, and
    // both are below an exact match — which is all this test claims. Whether they are *proposed* is
    // the threshold's business, and the fixture tests are where that is decided.
    expect(termSimilarity('faktura', 'factura'), 1 - 1 / 7);
    expect(bestSimilarity('Factura', <String>['Factura']), 1);
  });

  test('the token component carries what the whole string cannot', () {
    // `Fecha` against `Fecha de factura`: the whole-string comparison is weak because the term is
    // four times as long, and the shared token is what makes them the same claim. Its value is the
    // Sørensen–Dice coefficient of the two token sets, 2·1/(1+3).
    expect(termSimilarity('Fecha', 'Fecha de factura'), 0.5);
    expect(termSimilarity('Fecha', 'Fecha de factura'), greaterThan(0.4));
  });

  test('a term a name contains is a compound part of it', () {
    // The rule design §5's German fixture needs, and the cases it names: a compound whose two halves
    // are of comparable length — `Beleg`+`Datum`, `Gesamt`+`Betrag` — is a term inside a name.
    expect(termSimilarity('Belegdatum', 'Datum'), containedTermSimilarity);
    expect(termSimilarity('Gesamtbetrag', 'Betrag'), containedTermSimilarity);
    expect(termSimilarity('Endbetrag', 'Betrag'), containedTermSimilarity);
    // Symmetric: which of the two is "the name" and which "the term" is not a difference.
    expect(termSimilarity('Datum', 'Belegdatum'), containedTermSimilarity);
    // A contained term scores below a literal one, which is what lets an exact column name win
    // against a longer name that merely contains it.
    expect(
      termSimilarity('Gesamtbetrag', 'Betrag'),
      lessThan(termSimilarity('Betrag', 'Betrag')),
    );
  });

  test('a term inside a much longer compound is not a compound part', () {
    // The one bound on the rule, and it is deliberately tight: the two halves have to be of
    // comparable length. A German modifier longer than its head is not seen this way —
    // `Rechnungsdatum`, `Buchungsdatum` and `Fälligkeitsdatum` all carry `Datum` and none of them is
    // this term inside a longer word. Two of those do not need the rule (`Rechnungsdatum` is itself
    // a term of Annex C, and is matched as one); the third is a due date, and leaving it unmapped is
    // the direction the threshold wants.
    expect(
      termSimilarity('Rechnungsdatum', 'Datum'),
      lessThan(containedTermSimilarity),
    );
    expect(
      termSimilarity('Buchungsdatum', 'Datum'),
      lessThan(containedTermSimilarity),
    );
    expect(
      termSimilarity('Fälligkeitsdatum', 'Datum'),
      lessThan(containedTermSimilarity),
    );
    expect(termSimilarity('Rechnungsdatum', 'Rechnungsdatum'), 1);
  });

  test('a short term inside a long word is not a compound part', () {
    // The same bound seen from the other side: `IVA` covers a quarter of `Privatanteil` and `Netto`
    // a little over two fifths of `Nettogewicht`.
    expect(
      termSimilarity('Privatanteil', 'IVA'),
      lessThan(containedTermSimilarity),
    );
    expect(
      termSimilarity('Nettogewicht', 'Netto'),
      lessThan(containedTermSimilarity),
    );
    expect(
      termSimilarity('Totalgewicht', 'Total'),
      lessThan(containedTermSimilarity),
    );
  });

  test(
    'a name that is neither contained nor exact is measured window by window',
    () {
      // `Invoice No.` and a column called `Invoice Number`: neither contains the other, and the best
      // window of the longer is one letter from the shorter — which is what *one minus normalised
      // edit distance* means for a name that is a prefix of a longer one.
      expect(
        termSimilarity('Invoice Number', 'Invoice No.'),
        greaterThan(containedTermSimilarity),
      );
      expect(termSimilarity('Invoice Number', 'Invoice No.'), lessThan(1));
    },
  );

  test('the minimum over synonyms is the score of the candidate', () {
    // The maximum over a field's terms, and nothing at all for a field the dictionary does not
    // describe.
    expect(
      bestSimilarity('Lieferant', <String>['Seller', 'Lieferant', 'Merchant']),
      1,
    );
    expect(bestSimilarity('Lieferant', <String>[]), 0);
    expect(bestSimilarity('Lieferant', <String>['Seller']), lessThan(1));
  });

  test('every score is a real number between nothing and one', () {
    const List<(String, String)> pairs = <(String, String)>[
      ('Belegdatum', 'Datum'),
      ('Betrag', 'Gesamtbetrag'),
      ('', 'Datum'),
      ('Datum', ''),
      ('zzzzzzzzzzzzzz', 'Datum'),
      ('Datum', 'Datum'),
    ];
    for (final (String name, String term) in pairs) {
      final double score = termSimilarity(name, term);
      expect(score, greaterThanOrEqualTo(0), reason: '`$name` / `$term`');
      expect(score, lessThanOrEqualTo(1), reason: '`$name` / `$term`');
      expect(
        termSimilarity(term, name),
        score,
        reason: 'the score is symmetric: `$name` / `$term`',
      );
    }
  });
}
