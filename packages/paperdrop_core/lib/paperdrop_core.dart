/// Everything in Paperdrop for Ninox that decides a value.
///
/// Pure Dart. This library imports nothing but `dart:core`, `dart:collection`, `dart:math`,
/// `dart:convert`, `dart:typed_data` and its own files; CI fails on anything else
/// (setup-mvp-foundations, design §2).
library;

export 'src/model/calendar_date.dart';
export 'src/model/canonical_document.dart';
export 'src/model/confidence.dart';
export 'src/model/doc_time.dart';
export 'src/model/field_value.dart';
export 'src/model/provenance.dart';
export 'src/money/currency.dart';
export 'src/money/money.dart';
export 'src/money/rate.dart';

/// The package's name, so the workspace can prove it resolves before any real API exists.
const String packageName = 'paperdrop_core';
