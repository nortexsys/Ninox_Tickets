import 'dart:convert';
import 'dart:io';

import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

/// Regression tests for `fix-text-pdf-extraction-yield`.
///
/// The two fixtures are the PO's synthetic invoices, copied from the change
/// evidence. Both have a clean text layer and correct Annex-D-style
/// arithmetic, yet the first end-to-end run read no `gross_total`,
/// `supplier_name` or `doc_number` from them. Each test names the stage that
/// dropped the field.
void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final es = CountryTable.es;
  final table = CountryTable.launch;

  TextPage pageFor(String name) {
    final file = File('test/regressions/fixtures/$name');
    final raw = file.readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final wordsJson = json['words'] as List<dynamic>;
    final words = wordsJson.map((dynamic entry) {
      final list = entry as List<dynamic>;
      return PositionedWord(
        list[0] as String,
        list[1] as int,
        list[2] as int,
        list[3] as int,
        list[4] as int,
      );
    }).toList();
    return TextPage(0, json['width'] as int, json['height'] as int, words);
  }

  CanonicalDocument extract(String name) {
    return extractDocument(
      passes: <ExtractionPass>[
        ExtractionPass(
          passId: 'text',
          routeLabel: 'pdf-text/pdfrx 2.6.5',
          pages: <TextPage>[pageFor(name)],
        ),
      ],
      country: es,
      table: table,
      sourceHash: 'synthetic-invoice',
    );
  }

  test('[extraction-pipeline/read-all-printed-quantities-before-deriving] '
      'the text-layer amount stage keeps several printed total labels and lets '
      'the solver pick the arithmetic one (synthetic invoice 01)', () {
    final document = extract('synthetic_invoice_01.words.json');

    expect(
      document.grossTotal,
      Present<Money>(Money(12100, eur), Provenance.read, ConfidenceState.green),
    );
    expect(
      document.netTotal,
      Present<Money>(Money(10000, eur), Provenance.read, ConfidenceState.green),
    );
    expect(
      document.taxTotal,
      Present<Money>(Money(2100, eur), Provenance.read, ConfidenceState.green),
    );
  });

  test('[extraction-pipeline/read-all-printed-quantities-before-deriving] '
      'the amount solver reads a multi-rate aggregate instead of requiring one '
      'rate to explain it (synthetic invoice 02)', () {
    final document = extract('synthetic_invoice_02.words.json');

    expect(
      document.grossTotal,
      Present<Money>(
        Money(320650, eur),
        Provenance.read,
        ConfidenceState.green,
      ),
    );
    expect(
      document.netTotal,
      Present<Money>(
        Money(274000, eur),
        Provenance.read,
        ConfidenceState.green,
      ),
    );
    expect(
      document.taxTotal,
      Present<Money>(Money(46650, eur), Provenance.read, ConfidenceState.green),
    );
  });

  test('[extraction-pipeline/negative-context-suppresses-non-tax-figures] '
      'a tip printed outside the base is suppressed and captured as a surcharge '
      '(synthetic invoice 01)', () {
    final page = pageFor('synthetic_invoice_01.words.json');
    final operands = readOperands([page], es);
    final result = applyNegativeContext(
      operands: operands,
      pages: [page],
      country: es,
    );

    expect(
      result.suppressed.map((operand) => operand.amount),
      contains(Money(1500, eur)),
    );
    expect(
      result.kept.bases.map((operand) => operand.amount),
      isNot(contains(Money(1500, eur))),
    );
    expect(result.surcharges, hasLength(1));
    expect(result.surcharges.single.label, SurchargeLabel.tip);
    expect(
      result.surcharges.single.amount,
      Present<Money>(Money(1500, eur), Provenance.read, ConfidenceState.amber),
    );
  });

  test('[extraction-pipeline/positional-pdf-text-extraction] '
      'supplier_name binds the value line below a supplier header '
      '(synthetic invoice 02)', () {
    final document = extract('synthetic_invoice_02.words.json');

    expect(
      document.supplierName,
      Present<String>(
        'NORTEX DIGITAL, S.L.',
        Provenance.read,
        ConfidenceState.amber,
      ),
    );
  });

  test('[extraction-pipeline/positional-pdf-text-extraction] '
      'doc_number binds the value on the number line, not a bare Factura total '
      '(synthetic invoices 01 and 02)', () {
    final invoice01 = extract('synthetic_invoice_01.words.json');
    expect(
      invoice01.docNumber,
      Present<String>('DEMO-2026-0001', Provenance.read, ConfidenceState.amber),
    );

    final invoice02 = extract('synthetic_invoice_02.words.json');
    expect(
      invoice02.docNumber,
      Present<String>('ND-2026-0047', Provenance.read, ConfidenceState.amber),
    );
  });

  test('[extraction-pipeline/invoice-route-priority] the engine suffix does '
      'not change the text-layer route result', () {
    final page = pageFor('synthetic_invoice_01.words.json');

    CanonicalDocument run(String routeLabel) => extractDocument(
      passes: <ExtractionPass>[
        ExtractionPass(
          passId: 'text',
          routeLabel: routeLabel,
          pages: <TextPage>[page],
        ),
      ],
      country: es,
      table: table,
      sourceHash: 'h',
    );

    final pdfrx = run('pdf-text/pdfrx 2.6.5');
    final otherEngine = run('pdf-text/other-engine 9.9.9');

    expect(otherEngine.recognitionEngine, 'pdf-text');
    expect(otherEngine.grossTotal, pdfrx.grossTotal);
    expect(otherEngine.netTotal, pdfrx.netTotal);
    expect(otherEngine.taxTotal, pdfrx.taxTotal);
    expect(otherEngine.docNumber, pdfrx.docNumber);
  });
}
