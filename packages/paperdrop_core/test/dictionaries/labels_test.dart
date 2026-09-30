import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  test('positive label seeds match Annex C term by term', () {
    const expectedByKind = <LabelKind, Set<String>>{
      LabelKind.total: <String>{
        'A PAGAR',
        'TOTAL',
        'TOTAL A PAGAR',
        'IMPORTE TOTAL',
        'TOTAL FACTURA',
        'TOTAL GENERAL',
        'SUMA TOTAL',
        'Zu zahlen',
        'Gesamtbetrag',
        'Endbetrag',
        'Rechnungsbetrag',
        'Total',
        'Total TTC',
        'Montant TTC',
        'Total à payer',
        'Importo',
        'Totale',
        'Totale fattura',
      },
      LabelKind.tax: <String>{
        'IVA',
        'CUOTA',
        'Cuota IVA',
        'VAT',
        'MwSt.',
        'USt.',
        'TVA',
        'MWST',
      },
      LabelKind.base: <String>{
        'BASE',
        'Base imponible',
        'BASE IMPONIBLE',
        'NETO',
        'Netto',
        'HT',
        'Subtotal',
        'SUBTOTAL',
        'Zwischensumme',
      },
      LabelKind.supplier: <String>{
        'PROVEEDOR',
        'Emisor',
        'Razón social',
        'Razón Social',
        'Lieferant',
        'Absender',
        'Rechnungsteller',
        'Seller',
        'Merchant',
        'Fornecedor',
        'Fornitore',
      },
      LabelKind.date: <String>{
        'FECHA',
        'Fecha',
        'Fecha de factura',
        'Date',
        'Datum',
        'Rechnungsdatum',
        'Date de facture',
        'Data',
      },
      LabelKind.docNumber: <String>{
        'FACTURA N.º',
        'Nº FACTURA',
        'Factura',
        'Invoice No.',
        'Invoice',
        'Rechnungsnummer',
        'Rechnung Nr.',
        'N.º de factura',
        'Ticket',
        'Recibo',
        'Boleta',
      },
    };

    for (final kind in LabelKind.values) {
      final actual = labelTerms
          .where((term) => term.kind == kind)
          .map((term) => term.term)
          .toSet();
      expect(actual, expectedByKind[kind], reason: 'kind $kind');
    }

    expect(
      labelTerms.length,
      expectedByKind.values.fold(0, (sum, s) => sum + s.length),
    );
  });

  test('negative-context seeds match Annex C term by term', () {
    const expected = <String>{
      'DCC',
      'mark-up',
      'markup',
      'currency conversion',
      'conversión de divisa',
      'Skonto',
      'anticipo',
      'advance payment',
      'adelanto',
      'Registro Mercantil',
      'Tomo',
      'Folio',
      'HRB',
      'Amtsgericht',
      'Handelsregister',
      'commission',
      'comisión',
      'propina',
      'tip',
      'service charge',
      'Gutschein',
      'voucher',
    };

    expect(negativeTerms.map((term) => term.term).toSet(), expected);
    expect(negativeTerms.length, expected.length);
  });

  test('negative surcharge hints match Annex C', () {
    final hints = <String, SurchargeLabel?>{
      for (final term in negativeTerms) term.term: term.surchargeHint,
    };

    expect(hints['DCC'], SurchargeLabel.dccMarkup);
    expect(hints['mark-up'], SurchargeLabel.dccMarkup);
    expect(hints['markup'], SurchargeLabel.dccMarkup);
    expect(hints['currency conversion'], SurchargeLabel.dccMarkup);
    expect(hints['conversión de divisa'], SurchargeLabel.dccMarkup);
    expect(hints['propina'], SurchargeLabel.tip);
    expect(hints['tip'], SurchargeLabel.tip);
    expect(hints['service charge'], SurchargeLabel.serviceCharge);
    expect(hints['Skonto'], isNull);
    expect(hints['Tomo'], isNull);
    expect(hints['commission'], isNull);
  });

  test('[countries-languages/document-dictionaries-are-separate-from-interface-language] '
      'the negative-context list spans the languages of the market', () {
    final languages = negativeTerms.expand((term) => term.languages).toSet();
    expect(languages, containsAll(<String>['es', 'de', 'fr', 'en']));

    final required = <String>{
      'DCC',
      'Skonto',
      'Registro Mercantil',
      'Tomo',
      'Folio',
      'HRB',
      'Amtsgericht',
      'commission',
      'tip',
    };
    expect(
      negativeTerms.map((term) => term.term).toSet(),
      containsAll(required),
    );
    expect(
      negativeTerms.where((term) => term.term == 'commission').single.languages,
      containsAll(<String>['en', 'fr']),
    );
  });
}
