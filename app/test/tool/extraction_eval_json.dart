/// The extraction harness's output (`add-extraction-device-harness`, design).
///
/// **What it is.** One JSON file per document, written beside the input by
/// `app/integration_test/extraction_eval_test.dart` as
/// `<doc_id>.extraction-summary.json`, holding **numbers, enum names and
/// confidence states only**: the route that read the document and the engine
/// names the values record, the state the entry was left in, the stored copy's
/// SHA-256 before and after it was read and the number that says whether the two
/// agree, the milliseconds the extraction took, whether Core asked for review,
/// the confidence state and the provenance tag of every canonical core field, the
/// kind of country detection answer — and, when the route refused the document,
/// the code it refused with.
///
/// **What it cannot carry.** Not one value of a document: no amount, no supplier
/// name, no document number, not a word of its text. That is not a promise made
/// in prose, it is the shape of the writer — every string it emits is the name of
/// a value of an enum of `paperdrop_core` or of the route, an engine name this
/// build ships (`PdfrxTextSource.toolName`, `MlKitOcrTextSource.toolName`), or a
/// SHA-256, and a label that does not parse into one of those throws a
/// [FormatException] instead of being written. The allow-list is asserted in
/// `app/test/tool/extraction_eval_json_test.dart`; nothing here takes a string a
/// caller chose, which is why no document's text can arrive.
///
/// **Where the document's name is.** In the file's name and nowhere inside it, as
/// `ocrEvalJsonFileName` and `evalJsonFileName` do it: the name is the corpus's
/// own and can carry a supplier's.
///
/// **Why it lives here and not in `app/lib/`.** It is the evaluation's own output
/// format and not a shape the application produces: nothing in `app/lib/` writes
/// it, and what the product owner reads is this file and not a screen.
///
/// **What it refuses to do.** It scores nothing and applies no threshold:
/// accuracy needs ground truth (T2.5) and FR-EXT-015's threshold is GAP-003's, so
/// the file reports a route, a set of states and a duration and leaves the
/// decision to the product owner.
library;

import 'dart:convert';

import 'package:paperdrop/adapters/ocr/mlkit_ocr_text_source.dart';
import 'package:paperdrop/adapters/pdf_text/pdfrx_text_source.dart';
import 'package:paperdrop/features/extraction/extraction_router.dart';
import 'package:paperdrop/features/extraction/extraction_service.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

/// The route and the engine of one extraction, split out of the label the stored
/// values carry (`ExtractionRouter`: `<route>/<engine+version>`, and one
/// `[country=<reason>]` after it when no row governs the document).
///
/// Requirement served: `extraction-pipeline` · `invoice-route-priority`
/// (FR-EXT-002) — the route that read the document is recorded, and this is the
/// same string the entry holds, not a second account of it.
final class ExtractionLabel {
  /// Binds a [route] name to the [engine] names that read its pages.
  const ExtractionLabel({required this.route, required this.engine});

  /// The route as [ExtractionRoute] names it: `pdf-text`, `pdf-ocr`, `pdf-mixed`
  /// or `photo-ocr`.
  final String route;

  /// The engines that read the pages, in the adapter's own `toolName` form, with
  /// ` + ` between the two of them for `pdf-mixed`.
  final String engine;

  /// The label as the router wrote it, which is also what the stored values hold
  /// before any country reason is appended.
  @override
  String toString() => '$route/$engine';
}

/// The closed set of route names, from the pipeline's own enum.
final Set<String> _routeNames = <String>{
  for (final ExtractionRoute route in ExtractionRoute.values) route.route,
};

/// The closed set of engine names this build ships, from the adapters themselves.
final Set<String> _engineNames = <String>{
  PdfrxTextSource.toolName,
  MlKitOcrTextSource.toolName,
};

/// The country reason the service appends to the label when no row governs the
/// document: `pdf-text/pdfrx 2.6.5 [country=noEvidence]` (design §4 of
/// `implement-country-detection`).
const String _countryReasonPrefix = ' [country=';

/// [recognitionEngine] split into its route and its engine names, or a
/// [FormatException] when it is not a label this build writes.
///
/// **Why it is parsed and not passed in.** The route is decided inside
/// `ExtractionService`, which hands its caller the stored values and not the
/// `RoutedExtraction`; the label is where the route and the engine survive, and
/// `extraction_router.dart` documents its shape. Parsing it against the closed
/// sets is what keeps an arbitrary string out of the summary: a word of a
/// document cannot arrive here, and one that did would not parse.
ExtractionLabel extractionLabelOf(String recognitionEngine) {
  final String label = _withoutCountryReason(recognitionEngine);
  final int slash = label.indexOf('/');
  if (slash <= 0 || slash == label.length - 1) {
    throw FormatException(
      'the recognition engine is not the `<route>/<engine+version>` label the '
      'router writes',
    );
  }
  final String route = label.substring(0, slash);
  if (!_routeNames.contains(route)) {
    throw FormatException('the label names no route of the pipeline');
  }
  final String engine = label.substring(slash + 1);
  final List<String> engines = engine.split(' + ');
  if (engines.any((String name) => !_engineNames.contains(name))) {
    throw FormatException('the label names no engine this build ships');
  }
  return ExtractionLabel(route: route, engine: engine);
}

/// [label] without the `[country=<reason>]` the service appends, or the label as
/// it was when it carries none.
String _withoutCountryReason(String label) {
  final int start = label.lastIndexOf(_countryReasonPrefix);
  if (start < 0) {
    return label;
  }
  final String reason = label.substring(start + _countryReasonPrefix.length);
  if (!reason.endsWith(']')) {
    throw FormatException('the country reason of the label is not closed');
  }
  final String name = reason.substring(0, reason.length - 1);
  if (!UndetectedReason.values.any(
    (UndetectedReason kind) => kind.name == name,
  )) {
    throw FormatException('the label names no reason Core has for no row');
  }
  return label.substring(0, start);
}

/// The summary one document is reported under, in the schema design names.
///
/// [outcome] is what `ExtractionService.extract` answered, so the state, the
/// values, the country answer and the code a refusal carries are the ones the
/// step itself produced and not a second copy of them: an entry that says
/// `reviewing` while the values are missing cannot be written from here.
///
/// [sha256Before] and [sha256After] are the hash of the **stored copy** — the file
/// the route read — taken around the call, which is the read-only question of
/// ADR-015 (`capture-intake` · `received-files-are-attached-byte-for-byte`,
/// FR-CAP-005). [ms] is how long the extraction took, measured by the harness: the
/// step reports no timing of its own.
String extractionEvalSummaryJson({
  required ExtractionOutcome outcome,
  required String sha256Before,
  required String sha256After,
  required int ms,
}) {
  final CanonicalDocument? values = switch (outcome) {
    ExtractionCompleted(:final document) => document,
    ExtractionRefused() => null,
  };
  final CountryDetection? detection = switch (outcome) {
    ExtractionCompleted(:final detection) => detection,
    ExtractionRefused() => null,
  };
  final String? failureCode = switch (outcome) {
    ExtractionCompleted() => null,
    ExtractionRefused(:final failure) => failure.code.code,
  };
  // A refused document was read by no route, so it records no label: the route
  // that failed is the failure's own code, and inventing a route here would say
  // the document was read.
  final ExtractionLabel? label = values == null
      ? null
      : extractionLabelOf(values.recognitionEngine);
  return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'route': label?.route,
    'recognition_engine': label?.engine,
    'state_after': outcome.entry.state.name,
    'sha256_before': sha256Before,
    'sha256_after': sha256After,
    // The equality of the two hashes as a number, the key the photo harness's
    // summary uses: 0 when reading the stored copy left it as it was (ADR-015),
    // 1 when reading it changed it.
    'sha256_changed': sha256Before == sha256After ? 0 : 1,
    'ms': ms,
    'needs_review': values?.needsReview,
    'fields': fieldStatesOf(values),
    'country': countryKindOf(detection),
    'failure_code': failureCode,
  });
}

/// The confidence state and the provenance tag of every canonical core field of
/// [document], and nothing else of it.
///
/// Requirement served: `extraction-pipeline` · `provenance-on-every-value`
/// (FR-EXT-011) — the model holds a confidence state and one of the four
/// provenance tags on every value, and this is how many of each a device run
/// produced without naming a value.
///
/// **What is a field.** The document's own serialised form decides: every entry
/// whose value is a field value — a map with a `state` — is reported under its
/// Core key, so a field the model gains later is reported without an edit here.
/// The lists (`taxSlots`, `surcharges`) are not field values and are not reported:
/// they hold no single state of their own, and design asks for a state per field.
///
/// **The five states.** `green`, `amber` and `red` are [ConfidenceState]'s own
/// names; `absent` is a field that holds no reading; `edited` is a value the user
/// typed, which carries no provenance and no confidence at all (FR-EXT-011). The
/// XML route's `not_in_xml` is reported as `absent` too: the list design names has
/// one word for a field with no reading, and that route is R1 and absent by cut,
/// so this pipeline cannot produce it.
///
/// The tag is the provenance's wire name — `read`, `from_xml`, `derived`,
/// `repaired` — or null when the field holds no extracted value.
Map<String, Object?> fieldStatesOf(CanonicalDocument? document) {
  final Map<String, Object?> fields = <String, Object?>{};
  if (document == null) {
    return fields;
  }
  document.toJson().forEach((String name, Object? value) {
    if (value is! Map<String, Object?> || !value.containsKey('state')) {
      return;
    }
    fields[name] = <String, Object?>{
      'confidence': _confidenceOf(value),
      'provenance': _provenanceOf(value),
    };
  });
  return fields;
}

/// The state design names for one field value, in the vocabulary of five.
String _confidenceOf(Map<String, Object?> field) => switch (field['state']) {
  'present' => _confidenceStateName(field['confidence']),
  'absent' || 'not_in_xml' => 'absent',
  'edited' => 'edited',
  _ => throw FormatException(
    'the field holds a state the canonical model does not have',
  ),
};

/// [json] as a [ConfidenceState] name, or a [FormatException].
String _confidenceStateName(Object? json) {
  for (final ConfidenceState state in ConfidenceState.values) {
    if (state.name == json) {
      return state.name;
    }
  }
  throw FormatException('the field holds no confidence state of the model');
}

/// The provenance tag of one field value, or null when it carries none.
String? _provenanceOf(Map<String, Object?> field) {
  final Object? tag = field['provenance'];
  if (tag == null) {
    return null;
  }
  for (final Provenance provenance in Provenance.values) {
    if (provenance.wireName == tag) {
      return provenance.wireName;
    }
  }
  throw FormatException('the field holds no provenance tag of the model');
}

/// The kind of [detection] — a row governed the document, or none did and here is
/// why — and never the row's country code or the evidence's words.
///
/// Requirement served: `countries-languages` ·
/// `deterministic-country-detection` (FR-CTR-001) for the row a document's own
/// evidence picked, and `countries-languages` · `universal-core` (FR-CTR-002) for
/// the document no row governs, which was still read and still reaches review
/// with its reason, and never as a failure.
Map<String, Object?>? countryKindOf(CountryDetection? detection) =>
    switch (detection) {
      null => null,
      Detected() => <String, Object?>{'kind': 'row'},
      Undetected(:final UndetectedReason reason) => <String, Object?>{
        'kind': 'undetected',
        'reason': reason.name,
      },
    };

/// The file one document's summary is written under, beside the input.
String extractionSummaryFileName({required String docId}) =>
    '$docId.extraction-summary.json';
