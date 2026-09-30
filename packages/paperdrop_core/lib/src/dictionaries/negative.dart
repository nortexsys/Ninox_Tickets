/// Negative-context dictionary seeds.
///
/// Requirement served: `countries-languages` ·
/// `document-dictionaries-are-separate-from-interface-language` and
/// `extraction-pipeline` · `negative-context-suppresses-non-tax-figures`
/// (the list only). The seeds are Funcional Annex C, copied exactly as printed.
library;

import '../model/canonical_document.dart';

/// A negative-context term with its language codes and surcharge hint.
class NegativeTerm {
  /// The term exactly as printed in Annex C.
  final String term;

  /// The ISO 639-1 language codes the term belongs to.
  final Set<String> languages;

  /// The surcharge label this term names, or `null` when it names none.
  final SurchargeLabel? surchargeHint;

  /// Creates a negative-context term.
  const NegativeTerm(this.term, this.languages, [this.surchargeHint]);

  /// A value-only string form.
  @override
  String toString() =>
      '$term ${languages.toList()} ${surchargeHint?.wireName ?? ''}';

  /// Value equality on term, languages and hint.
  @override
  bool operator ==(Object other) =>
      other is NegativeTerm &&
      other.term == term &&
      other.surchargeHint == surchargeHint &&
      _setEquals(other.languages, languages);

  @override
  int get hashCode =>
      Object.hash(term, surchargeHint, Object.hashAllUnordered(languages));
}

/// The negative-context seeds of Annex C, exactly as printed.
///
/// `commission` is spelled the same in English and French and is tagged with
/// both; it is Annex C's only French negative term, and this change adds no
/// other.
const List<NegativeTerm> negativeTerms = <NegativeTerm>[
  NegativeTerm('DCC', {'en'}, SurchargeLabel.dccMarkup),
  NegativeTerm('mark-up', {'en'}, SurchargeLabel.dccMarkup),
  NegativeTerm('markup', {'en'}, SurchargeLabel.dccMarkup),
  NegativeTerm('currency conversion', {'en'}, SurchargeLabel.dccMarkup),
  NegativeTerm('conversión de divisa', {'es'}, SurchargeLabel.dccMarkup),
  NegativeTerm('Skonto', {'de'}),
  NegativeTerm('anticipo', {'es'}),
  NegativeTerm('advance payment', {'en'}),
  NegativeTerm('adelanto', {'es'}),
  NegativeTerm('Registro Mercantil', {'es'}),
  NegativeTerm('Tomo', {'es'}),
  NegativeTerm('Folio', {'es'}),
  NegativeTerm('HRB', {'de'}),
  NegativeTerm('Amtsgericht', {'de'}),
  NegativeTerm('Handelsregister', {'de'}),
  NegativeTerm('commission', {'en', 'fr'}),
  NegativeTerm('comisión', {'es'}),
  NegativeTerm('propina', {'es'}, SurchargeLabel.tip),
  NegativeTerm('tip', {'en'}, SurchargeLabel.tip),
  NegativeTerm('service charge', {'en'}, SurchargeLabel.serviceCharge),
  NegativeTerm('Gutschein', {'de'}),
  NegativeTerm('voucher', {'en'}),
];

bool _setEquals(Set<String> left, Set<String> right) {
  if (left.length != right.length) {
    return false;
  }
  return left.containsAll(right);
}
