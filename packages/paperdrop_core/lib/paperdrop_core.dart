/// Everything in Paperdrop for Ninox that decides a value.
///
/// Pure Dart. This library imports nothing but `dart:core`, `dart:collection`, `dart:math`,
/// `dart:convert`, `dart:typed_data` and its own files; CI fails on anything else
/// (setup-mvp-foundations, design §2).
library;

export 'src/checks/check_result.dart';
export 'src/checks/ean13.dart';
export 'src/checks/iban.dart';
export 'src/confidence/redundancy.dart';
export 'src/consensus/consensus.dart';
export 'src/countries/country_table.dart';
export 'src/countries/es_cif.dart';
export 'src/countries/es_nie.dart';
export 'src/countries/es_nif.dart';
export 'src/countries/tax_id.dart';
export 'src/dictionaries/labels.dart';
export 'src/dictionaries/lookup.dart';
export 'src/dictionaries/negative.dart';
export 'src/format/date.dart';
export 'src/format/decimal.dart';
export 'src/layout/binding.dart';
export 'src/layout/lines.dart';
export 'src/layout/positioned_word.dart';
export 'src/layout/text_page.dart';
export 'src/model/calendar_date.dart';
export 'src/model/canonical_document.dart';
export 'src/model/confidence.dart';
export 'src/model/doc_time.dart';
export 'src/model/field_value.dart';
export 'src/model/provenance.dart';
export 'src/money/currency.dart';
export 'src/money/money.dart';
export 'src/money/rate.dart';
export 'src/solver/currency.dart';
export 'src/solver/negative.dart';
export 'src/solver/operands.dart';
export 'src/solver/rate_gate.dart';
export 'src/solver/solve.dart';

/// The package's name, so the workspace can prove it resolves before any real API exists.
const String packageName = 'paperdrop_core';
