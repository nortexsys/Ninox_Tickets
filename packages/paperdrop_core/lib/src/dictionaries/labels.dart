/// Positive label dictionary seeds.
///
/// Requirement served: `countries-languages` ·
/// `document-dictionaries-are-separate-from-interface-language` and
/// `extraction-pipeline` · `multilingual-label-dictionaries`. The seeds are
/// Funcional Annex C, copied exactly as printed; terms are stored with accents
/// and punctuation, and never stripped. The extension list added by DEC-014
/// lives beside [labelTerms] and is never mixed into the Annex C seeds.
library;

/// The fields a positive label can bind.
enum LabelKind {
  /// A total amount label.
  total,

  /// A tax amount label.
  tax,

  /// A taxable base label.
  base,

  /// An issuer (supplier) label.
  supplier,

  /// A document date label.
  date,

  /// A document number label.
  docNumber,
}

/// A positive label term with its kind and language codes.
class LabelTerm {
  /// The field this term labels.
  final LabelKind kind;

  /// The term exactly as printed in Annex C.
  final String term;

  /// The ISO 639-1 language codes the term belongs to.
  final Set<String> languages;

  /// Creates a label term.
  const LabelTerm(this.kind, this.term, this.languages);

  /// A value-only string form.
  @override
  String toString() => '$kind: $term ${languages.toList()}';

  /// Value equality on kind, term and languages.
  @override
  bool operator ==(Object other) =>
      other is LabelTerm &&
      other.kind == kind &&
      other.term == term &&
      _setEquals(other.languages, languages);

  @override
  int get hashCode =>
      Object.hash(kind, term, Object.hashAllUnordered(languages));
}

/// The positive label seeds of Annex C, exactly as printed.
const List<LabelTerm> labelTerms = <LabelTerm>[
  // Totals.
  LabelTerm(LabelKind.total, 'A PAGAR', {'es'}),
  LabelTerm(LabelKind.total, 'TOTAL', {'es'}),
  LabelTerm(LabelKind.total, 'TOTAL A PAGAR', {'es'}),
  LabelTerm(LabelKind.total, 'IMPORTE TOTAL', {'es'}),
  LabelTerm(LabelKind.total, 'TOTAL FACTURA', {'es'}),
  LabelTerm(LabelKind.total, 'TOTAL GENERAL', {'es'}),
  LabelTerm(LabelKind.total, 'SUMA TOTAL', {'es'}),
  LabelTerm(LabelKind.total, 'Zu zahlen', {'de'}),
  LabelTerm(LabelKind.total, 'Gesamtbetrag', {'de'}),
  LabelTerm(LabelKind.total, 'Endbetrag', {'de'}),
  LabelTerm(LabelKind.total, 'Rechnungsbetrag', {'de'}),
  LabelTerm(LabelKind.total, 'Total', {'en'}),
  LabelTerm(LabelKind.total, 'Total TTC', {'fr'}),
  LabelTerm(LabelKind.total, 'Montant TTC', {'fr'}),
  LabelTerm(LabelKind.total, 'Total à payer', {'fr'}),
  LabelTerm(LabelKind.total, 'Importo', {'it'}),
  LabelTerm(LabelKind.total, 'Totale', {'it'}),
  LabelTerm(LabelKind.total, 'Totale fattura', {'it'}),

  // Tax.
  LabelTerm(LabelKind.tax, 'IVA', {'es'}),
  LabelTerm(LabelKind.tax, 'CUOTA', {'es'}),
  LabelTerm(LabelKind.tax, 'Cuota IVA', {'es'}),
  LabelTerm(LabelKind.tax, 'VAT', {'en'}),
  LabelTerm(LabelKind.tax, 'MwSt.', {'de'}),
  LabelTerm(LabelKind.tax, 'USt.', {'de'}),
  LabelTerm(LabelKind.tax, 'TVA', {'fr'}),
  LabelTerm(LabelKind.tax, 'MWST', {'de'}),

  // Base.
  LabelTerm(LabelKind.base, 'BASE', {'es'}),
  LabelTerm(LabelKind.base, 'Base imponible', {'es'}),
  LabelTerm(LabelKind.base, 'BASE IMPONIBLE', {'es'}),
  LabelTerm(LabelKind.base, 'NETO', {'es'}),
  LabelTerm(LabelKind.base, 'Netto', {'de'}),
  LabelTerm(LabelKind.base, 'HT', {'fr'}),
  LabelTerm(LabelKind.base, 'Subtotal', {'en'}),
  LabelTerm(LabelKind.base, 'SUBTOTAL', {'en'}),
  LabelTerm(LabelKind.base, 'Zwischensumme', {'de'}),

  // Supplier (issuer).
  LabelTerm(LabelKind.supplier, 'PROVEEDOR', {'es'}),
  LabelTerm(LabelKind.supplier, 'Emisor', {'es'}),
  LabelTerm(LabelKind.supplier, 'Razón social', {'es'}),
  LabelTerm(LabelKind.supplier, 'Razón Social', {'es'}),
  LabelTerm(LabelKind.supplier, 'Lieferant', {'de'}),
  LabelTerm(LabelKind.supplier, 'Absender', {'de'}),
  LabelTerm(LabelKind.supplier, 'Rechnungsteller', {'de'}),
  LabelTerm(LabelKind.supplier, 'Seller', {'en'}),
  LabelTerm(LabelKind.supplier, 'Merchant', {'en'}),
  LabelTerm(LabelKind.supplier, 'Fornecedor', {'pt'}),
  LabelTerm(LabelKind.supplier, 'Fornitore', {'it'}),

  // Date.
  LabelTerm(LabelKind.date, 'FECHA', {'es'}),
  LabelTerm(LabelKind.date, 'Fecha', {'es'}),
  LabelTerm(LabelKind.date, 'Fecha de factura', {'es'}),
  LabelTerm(LabelKind.date, 'Date', {'en'}),
  LabelTerm(LabelKind.date, 'Datum', {'de'}),
  LabelTerm(LabelKind.date, 'Rechnungsdatum', {'de'}),
  LabelTerm(LabelKind.date, 'Date de facture', {'fr'}),
  LabelTerm(LabelKind.date, 'Data', {'pt', 'it'}),

  // Document number.
  LabelTerm(LabelKind.docNumber, 'FACTURA N.º', {'es'}),
  LabelTerm(LabelKind.docNumber, 'Nº FACTURA', {'es'}),
  LabelTerm(LabelKind.docNumber, 'Factura', {'es'}),
  LabelTerm(LabelKind.docNumber, 'Invoice No.', {'en'}),
  LabelTerm(LabelKind.docNumber, 'Invoice', {'en'}),
  LabelTerm(LabelKind.docNumber, 'Rechnungsnummer', {'de'}),
  LabelTerm(LabelKind.docNumber, 'Rechnung Nr.', {'de'}),
  LabelTerm(LabelKind.docNumber, 'N.º de factura', {'es'}),
  LabelTerm(LabelKind.docNumber, 'Ticket', {'es'}),
  LabelTerm(LabelKind.docNumber, 'Recibo', {'es'}),
  LabelTerm(LabelKind.docNumber, 'Boleta', {'es'}),
];

/// The extraction labels added by DEC-014, beside the Annex C seeds.
///
/// DEC-014 extends the dictionary without editing Annex C, so the extension is
/// its own list and the lookup consults [labelTerms] followed by this one.
/// `IMPORTE LIQUIDO` is the total label of an invoice in the private corpus;
/// `Belegdatum` is the German date column the setup wizard expects to
/// recognise. `Betrag` and `Tax` are deliberately not here: `Betrag` labels
/// every amount line and `Tax` opens labels such as *Tax Invoice*.
const List<LabelTerm> labelTermsExtension = <LabelTerm>[
  LabelTerm(LabelKind.total, 'IMPORTE LIQUIDO', {'es'}),
  LabelTerm(LabelKind.date, 'Belegdatum', {'de'}),
];

bool _setEquals(Set<String> left, Set<String> right) {
  if (left.length != right.length) {
    return false;
  }
  return left.containsAll(right);
}
