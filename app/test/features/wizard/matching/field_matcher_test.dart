import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:paperdrop/features/wizard/matching/field_matcher.dart';
import 'package:paperdrop/features/wizard/matching/similarity.dart';
import 'package:paperdrop/features/wizard/matching/type_rules.dart';
import 'package:paperdrop_core/paperdrop_core.dart'
    show LabelTerm, columnNameTerms, labelTerms;

/// The two-stage matcher, on the fixtures of design §5 (design §5, FR-WIZ-006).
///
/// **No number of the implementation is pinned here.** The threshold and the margin are design §5's
/// starting points, stated there so the lane has one and re-examined on the first real tables of the
/// demo: a test that asserted them would freeze a number no requirement states, which is exactly what
/// `two-stage-matching-with-a-strict-threshold`'s Open Questions refuse. What is pinned is the
/// **outcome** on a named fixture, and the score's own arithmetic where the outcome needs explaining.
///
/// Six synthetic tables, all names invented, no test-base identifier anywhere, no network, no token:
/// the matcher's only input is a `NinoxTable`.
void main() {
  /// One field of a fixture table.
  NinoxField field(String id, String name, String type) =>
      NinoxField(id: id, name: name, type: type);

  NinoxTable tableOf(List<NinoxField> fields) =>
      NinoxTable(id: 'table-1', name: 'Invoices', fields: fields);

  /// The proposal for one core field, or `null` when the matcher left it unmapped.
  NinoxField? proposalFor(NinoxTable table, CoreField coreField) =>
      proposeMappings(table)
          .firstWhere(
            (FieldProposal proposal) => proposal.coreField == coreField,
          )
          .ninoxField;

  test('[setup-wizard/two-stage-matching-with-a-strict-threshold] '
      'a German table receives its proposals', () {
    // The spec's own scenario. Annex C carries neither `Belegdatum` nor `Betrag`: the first is
    // reached as the compound half of `Datum`, the second as the compound half of `Gesamtbetrag`,
    // and `Lieferant` is a term of the dictionary as it stands.
    final NinoxTable table = tableOf(<NinoxField>[
      field('1', 'Belegdatum', 'date'),
      field('2', 'Lieferant', 'string'),
      field('3', 'Betrag', 'number'),
    ]);

    expect(proposalFor(table, CoreField.docDate)?.name, 'Belegdatum');
    expect(proposalFor(table, CoreField.supplierName)?.name, 'Lieferant');
    expect(proposalFor(table, CoreField.grossTotal)?.name, 'Betrag');

    // A table with three columns answers about three columns: everything else is unmapped, and
    // the fields the user does not have are not invented either.
    expect(proposalFor(table, CoreField.docNumber), isNull);
    expect(proposalFor(table, CoreField.netTotal), isNull);
    expect(proposalFor(table, CoreField.taxTotal), isNull);
    expect(proposalFor(table, CoreField.currency), isNull);
    expect(proposalFor(table, CoreField.supplierTaxId), isNull);
  });

  test('the dictionary itself reaches the German columns', () {
    // DEC-014's column names — added by the product owner on 2026-10-07 — are terms of the
    // dictionary now, so each of the three is a **literal** match and no compound rule is involved:
    // `Belegdatum` and `Betrag` used to be reachable only as halves of `Datum` and `Gesamtbetrag`.
    const List<(String, CoreField)> german = <(String, CoreField)>[
      ('Belegdatum', CoreField.docDate),
      ('Betrag', CoreField.grossTotal),
      ('Lieferant', CoreField.supplierName),
    ];
    for (final (String name, CoreField coreField) in german) {
      expect(
        synonymsOf(coreField),
        contains(name),
        reason: '$name is a term of ${coreField.wireName}',
      );
      expect(
        bestSimilarity(name, synonymsOf(coreField)),
        1,
        reason: '$name matches its own term literally',
      );
    }
  });

  test('[setup-wizard/two-stage-matching-with-a-strict-threshold] '
      'the column names of DEC-014 reach the supplier and the tax total', () {
    // `Supplier` and `Tax` are common English column names that Annex C does not carry: before
    // DEC-014's list the matcher left both unmapped, and the model is what changed, not the score.
    final NinoxTable fixtureTable = tableOf(<NinoxField>[
      field('1', 'Supplier', 'string'),
      field('2', 'Tax', 'number'),
    ]);

    expect(proposalFor(fixtureTable, CoreField.supplierName)?.name, 'Supplier');
    expect(proposalFor(fixtureTable, CoreField.taxTotal)?.name, 'Tax');
    // By the dictionary: each is a term of its own kind, and each scores a literal match.
    expect(bestSimilarity('Supplier', synonymsOf(CoreField.supplierName)), 1);
    expect(bestSimilarity('Tax', synonymsOf(CoreField.taxTotal)), 1);
  });

  test(
    'every synonym comes from the dictionary: the wizard adds no term of its '
    'own',
    () {
      // The one property that keeps the score honest: whatever a core field is compared with is a term
      // of `paperdrop_core` — Annex C or DEC-014 — except for the two fields that have no kind at all,
      // whose canonical name is the whole of their comparison.
      final Set<String> dictionary = <String>{
        for (final LabelTerm term in <LabelTerm>[
          ...labelTerms,
          ...columnNameTerms,
        ])
          term.term,
      };
      expect(dictionary, isNotEmpty);

      for (final CoreField coreField in CoreField.values) {
        final bool canonicalOnly =
            coreField == CoreField.supplierTaxId ||
            coreField == CoreField.currency;
        for (final String synonym in synonymsOf(coreField)) {
          expect(
            dictionary.contains(synonym) ||
                (canonicalOnly && synonym == coreField.wireName),
            isTrue,
            reason:
                '${coreField.wireName} is compared with `$synonym`, which is '
                'neither a dictionary term nor the field\'s own canonical name',
          );
        }
      }
    },
  );

  test(
    'the two fields with no dictionary kind keep their canonical name only',
    () {
      // DEC-014 adds no term for them, and no `LabelKind` exists to hang one on: a tax identifier and a
      // currency are compared with `supplier_tax_id` and `currency` and with nothing else.
      expect(synonymsOf(CoreField.supplierTaxId), <String>['supplier_tax_id']);
      expect(synonymsOf(CoreField.currency), <String>['currency']);
    },
  );

  test('an English table receives its proposals, and the two dictionary gaps '
      'stay unmapped', () {
    final NinoxTable table = tableOf(<NinoxField>[
      field('1', 'Date', 'date'),
      field('2', 'Merchant', 'string'),
      field('3', 'Invoice No.', 'string'),
      field('4', 'Total', 'number'),
      field('5', 'Subtotal', 'number'),
      field('6', 'VAT', 'number'),
      field('7', 'Currency', 'string'),
    ]);

    expect(proposalFor(table, CoreField.docDate)?.name, 'Date');
    expect(proposalFor(table, CoreField.supplierName)?.name, 'Merchant');
    expect(proposalFor(table, CoreField.docNumber)?.name, 'Invoice No.');
    // `Total` is the gross total and `Subtotal` the net one: a name that *contains* the term scores
    // below the term itself, so the two do not become an ambiguity between them.
    expect(proposalFor(table, CoreField.grossTotal)?.name, 'Total');
    expect(proposalFor(table, CoreField.netTotal)?.name, 'Subtotal');
    expect(proposalFor(table, CoreField.taxTotal)?.name, 'VAT');
    // Compared with its own canonical name and nothing else, the currency is reached; the tax
    // identifier has no column here at all.
    expect(proposalFor(table, CoreField.currency)?.name, 'Currency');
    expect(proposalFor(table, CoreField.supplierTaxId), isNull);
  });

  test(
    'a Spanish table receives its proposals, and a currency named in Spanish '
    'does not',
    () {
      final NinoxTable table = tableOf(<NinoxField>[
        field('1', 'Fecha de factura', 'date'),
        field('2', 'Proveedor', 'string'),
        field('3', 'Nº Factura', 'string'),
        field('4', 'Base imponible', 'number'),
        field('5', 'IVA', 'number'),
        field('6', 'IMPORTE TOTAL', 'number'),
        field('7', 'Moneda', 'string'),
      ]);

      expect(proposalFor(table, CoreField.docDate)?.name, 'Fecha de factura');
      expect(proposalFor(table, CoreField.supplierName)?.name, 'Proveedor');
      expect(proposalFor(table, CoreField.docNumber)?.name, 'Nº Factura');
      expect(proposalFor(table, CoreField.netTotal)?.name, 'Base imponible');
      expect(proposalFor(table, CoreField.taxTotal)?.name, 'IVA');
      expect(proposalFor(table, CoreField.grossTotal)?.name, 'IMPORTE TOTAL');
      // Annex C has no Spanish term for a currency and no `LabelKind` for one: `Moneda` is not
      // reached, and the lane reports the gap rather than inventing a term (design §5).
      expect(proposalFor(table, CoreField.currency), isNull);
    },
  );

  test('[setup-wizard/two-stage-matching-with-a-strict-threshold] '
      'below the threshold the field stays unmapped', () {
    // No date-like column at all: nothing is proposed and — the part that matters — no weak
    // suggestion is offered in its place.
    final NinoxTable table = tableOf(<NinoxField>[
      field('1', 'Merchant', 'string'),
      field('2', 'Invoice No.', 'string'),
      field('3', 'Total', 'number'),
    ]);

    final FieldProposal docDate = proposeMappings(table).firstWhere(
      (FieldProposal proposal) => proposal.coreField == CoreField.docDate,
    );
    expect(docDate.isProposed, isFalse);
    expect(docDate.ninoxField, isNull);
  });

  test('[setup-wizard/two-stage-matching-with-a-strict-threshold] '
      'the failure mode is a confirmed non-suggestion', () {
    // The functional's own failure mode: a mediocre suggestion the user would confirm without
    // reading it. `Fälligkeitsdatum` is a due date — a real column of a real table, dated, close
    // enough in meaning to be worth a look and not close enough in spelling to be worth a
    // proposal. It is left for the user to map deliberately or not at all.
    final NinoxTable table = tableOf(<NinoxField>[
      field('1', 'Fälligkeitsdatum', 'date'),
      field('2', 'Lieferant', 'string'),
      field('3', 'Betrag', 'number'),
    ]);

    expect(proposalFor(table, CoreField.docDate), isNull);
    // It is not a threshold that failed to be reached by accident: the score is genuinely low,
    // and the two other columns are still proposed.
    expect(
      bestSimilarity('Fälligkeitsdatum', synonymsOf(CoreField.docDate)),
      lessThan(containedTermSimilarity),
    );
    expect(proposalFor(table, CoreField.supplierName)?.name, 'Lieferant');
    expect(proposalFor(table, CoreField.grossTotal)?.name, 'Betrag');
  });

  test('two equally plausible date fields leave the field unmapped', () {
    // Both are literally in the dictionary, so the threshold is not what stops them: the ambiguity
    // is. A coin toss between two real columns is the wrong suggestion the functional fears.
    final NinoxTable table = tableOf(<NinoxField>[
      field('1', 'Datum', 'date'),
      field('2', 'Rechnungsdatum', 'date'),
      field('3', 'Betrag', 'number'),
    ]);

    expect(
      bestSimilarity('Datum', synonymsOf(CoreField.docDate)),
      bestSimilarity('Rechnungsdatum', synonymsOf(CoreField.docDate)),
    );
    expect(proposalFor(table, CoreField.docDate), isNull);
    expect(proposalFor(table, CoreField.grossTotal)?.name, 'Betrag');
  });

  test(
    'a number column and a text column that both resemble the document number: '
    'the type filter decides',
    () {
      // `FACTURA N.º` is the closest name of the two — it is a term of the dictionary verbatim — and
      // it is a number column, so it is not a candidate at all. The text column is proposed.
      final NinoxTable table = tableOf(<NinoxField>[
        field('1', 'FACTURA N.º', 'number'),
        field('2', 'Factura', 'string'),
      ]);

      expect(proposalFor(table, CoreField.docNumber)?.name, 'Factura');
    },
  );

  test('[setup-wizard/two-stage-matching-with-a-strict-threshold] '
      'the type filter runs before similarity', () {
    // A score that throws the moment it is asked for anything.
    double throwing(String name, Iterable<String> synonyms) =>
        throw StateError('the similarity was reached for `$name`');

    // A table whose every column is of a type no core field binds: the score is never reached, and
    // nothing is proposed.
    final NinoxTable noKindsAtAll = tableOf(<NinoxField>[
      field('1', 'Belegdatum', 'choice'),
      field('2', 'Betrag', 'boolean'),
      field('3', 'Lieferant', 'ref'),
    ]);
    final List<FieldProposal> proposals = proposeMappings(
      noKindsAtAll,
      similarity: throwing,
    );
    expect(proposals, hasLength(CoreField.values.length));
    expect(
      proposals.every((FieldProposal proposal) => !proposal.isProposed),
      isTrue,
    );

    // And when the score *is* reached, it is only ever reached about a candidate the filter kept
    // for the core field whose synonyms it was handed. A column of a type that field does not bind
    // cannot arrive here at all — the guard fails the test if one does.
    final NinoxTable mixed = tableOf(<NinoxField>[
      field('1', 'Belegdatum', 'number'),
      field('2', 'Betrag', 'string'),
      field('3', 'Geburtsdatum', 'choice'),
    ]);
    final List<String> asked = <String>[];
    double guard(String name, Iterable<String> synonyms) {
      asked.add(name);
      final NinoxField candidate = mixed.fields.firstWhere(
        (NinoxField field) => field.name == name,
      );
      final bool legal = CoreField.values.any(
        (CoreField coreField) =>
            _sameTerms(synonymsOf(coreField), synonyms) &&
            isTypeCandidate(coreField, candidate),
      );
      expect(
        legal,
        isTrue,
        reason: '`$name` reached the score for a kind its type does not bind',
      );
      return bestSimilarity(name, synonyms);
    }

    proposeMappings(mixed, similarity: guard);

    // The choice column is not a candidate for anything, and the two typed columns are asked about.
    expect(asked, isNotEmpty);
    expect(asked, isNot(contains('Geburtsdatum')));
  });

  test('[setup-wizard/two-stage-matching-with-a-strict-threshold] '
      'formula fields never reach matching', () {
    // The matcher is given a table, and the fields of that table are the only things it ever
    // scores: `.../tables` omits formula fields, so there is nothing else to consider and no
    // second request that could bring one in. Recording what the score is asked about is how the
    // test shows it rather than asserting it.
    final List<String> asked = <String>[];
    double recording(String name, Iterable<String> synonyms) {
      asked.add(name);
      return bestSimilarity(name, synonyms);
    }

    final NinoxTable table = tableOf(<NinoxField>[
      field('1', 'Belegdatum', 'date'),
      field('2', 'Lieferant', 'string'),
      field('3', 'Betrag', 'number'),
      field('4', 'Belegdatum Kopie', 'choice'),
    ]);

    proposeMappings(table, similarity: recording);

    // The columns of the right type — each scored for every core field of its kind — and the choice
    // column never asked about at all. Nothing outside the table is ever scored: a formula field is
    // not absent because something filtered it, but because it was never in the input.
    expect(asked.toSet(), <String>{'Belegdatum', 'Lieferant', 'Betrag'});
    expect(asked, isNotEmpty);
    expect(
      asked.every(
        (String name) => table.fields.any((NinoxField f) => f.name == name),
      ),
      isTrue,
      reason: 'nothing outside the table is ever scored',
    );
  });

  test(
    '[setup-wizard/table-listing-returns-the-schema] the picker cannot offer a '
    'formula field',
    () {
      // `.../tables` omits formula fields, and a `NinoxTable` is the matcher's only input, so the
      // candidates a picker is built from are exactly the columns the endpoint returned. The second
      // half is the defensive one: if a field of a type this project has not met ever did arrive, it
      // is still not a candidate — the filter binds three type names and no others, so the exclusion
      // depends on neither the field's name nor its likeness to a core field.
      final NinoxTable asReturned = tableOf(<NinoxField>[
        field('1', 'Belegdatum', 'date'),
        field('2', 'Lieferant', 'string'),
        field('3', 'Betrag', 'number'),
      ]);
      final Set<String?> candidates = <String?>{
        for (final FieldProposal proposal in proposeMappings(asReturned))
          proposal.ninoxField?.name,
      };
      expect(candidates, <String?>{'Belegdatum', 'Lieferant', 'Betrag', null});

      final NinoxTable withSomethingNew = tableOf(<NinoxField>[
        field('1', 'Total', 'formula'),
        field('2', 'Total', 'number'),
      ]);
      expect(
        proposalFor(withSomethingNew, CoreField.grossTotal)?.id,
        '2',
        reason: 'the number column is proposed; the unknown type is not',
      );
    },
  );

  test(
    'a field is proposed for one core field only, and the best score takes it',
    () {
      // One number column, and it is worth most to the net total: the gross total has no alternative
      // of its own and is left unmapped rather than sharing the column.
      final NinoxTable table = tableOf(<NinoxField>[
        field('1', 'Subtotal', 'number'),
      ]);

      expect(proposalFor(table, CoreField.netTotal)?.name, 'Subtotal');
      expect(proposalFor(table, CoreField.grossTotal), isNull);

      // And the other way round, with a column that carries both readings.
      final NinoxTable twoColumns = tableOf(<NinoxField>[
        field('1', 'Total', 'number'),
        field('2', 'Zwischensumme', 'number'),
      ]);
      expect(proposalFor(twoColumns, CoreField.grossTotal)?.name, 'Total');
      expect(
        proposalFor(twoColumns, CoreField.netTotal)?.name,
        'Zwischensumme',
      );
    },
  );

  test('every mappable core field gets an answer, in the canonical order', () {
    final List<FieldProposal> proposals = proposeMappings(
      tableOf(<NinoxField>[field('1', 'Lieferant', 'string')]),
    );

    expect(
      proposals.map((FieldProposal proposal) => proposal.coreField),
      CoreField.values,
    );
    // The table carries one column and the answer names it once.
    expect(
      proposals.where((FieldProposal proposal) => proposal.isProposed),
      hasLength(1),
    );
  });

  test('an empty table proposes nothing at all', () {
    final List<FieldProposal> proposals = proposeMappings(
      tableOf(<NinoxField>[]),
    );

    expect(proposals, hasLength(CoreField.values.length));
    expect(
      proposals.every((FieldProposal proposal) => !proposal.isProposed),
      isTrue,
    );
  });

  test('the same table always gives the same answer', () {
    // The mapping step is drawn from this answer on every rebuild, so it has to be a pure function
    // of the table — and the tie between two equal scores must resolve the same way twice.
    final NinoxTable table = tableOf(<NinoxField>[
      field('1', 'Datum', 'date'),
      field('2', 'Rechnungsdatum', 'date'),
      field('3', 'Lieferant', 'string'),
      field('4', 'Betrag', 'number'),
    ]);

    expect(proposeMappings(table), proposeMappings(table));
  });
}

/// Whether two lists of terms are the same terms in the same order.
bool _sameTerms(Iterable<String> left, Iterable<String> right) {
  final List<String> a = left.toList();
  final List<String> b = right.toList();
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
