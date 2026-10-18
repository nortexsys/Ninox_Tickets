import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart' show TableRef;
import 'package:paperdrop/adapters/ocr/mlkit_ocr_text_source.dart';
import 'package:paperdrop/adapters/pdf_text/pdfrx_text_source.dart';
import 'package:paperdrop/features/extraction/extraction_failure.dart';
import 'package:paperdrop/features/extraction/extraction_router.dart';
import 'package:paperdrop/features/extraction/extraction_service.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

import 'extraction_eval_json.dart';

/// The JSON writer of the extraction harness (`add-extraction-device-harness`,
/// task 1.1, and `flutter test` stays green with no device and no corpus).
///
/// **What this proves.** Two things, and both are the point of the file rather
/// than of its shape. First that one extraction becomes one summary of the keys
/// design names — the route and the engine names, the state the entry was left
/// in, the two hashes and the flag they agree on, the milliseconds, the review
/// flag, a confidence state and a provenance tag per canonical core field, the
/// kind of country answer, and the code of a refusal. Second, and the reason the
/// file may be read or sent at all, that **no string in it can carry a document's
/// value**: every string is a name of an enum of `paperdrop_core` or of the
/// route, an engine name this build ships, or a SHA-256, and a label that parses
/// into none of them throws instead of being written.
///
/// **Where it stops.** It writes and reads back its own text. It does not read a
/// document, run a route or measure a millisecond: that is the device run's, and
/// the numbers it writes are only as true as the run that produced them.
void main() {
  const String pdfEngine = PdfrxTextSource.toolName;
  const String ocrEngine = MlKitOcrTextSource.toolName;
  final CurrencyCode eur = CurrencyCode.parse('EUR')!;

  /// A SHA-256-shaped value, built and not written out: a literal of sixty-four
  /// hex-looking characters is what the privacy check looks for.
  String aHash([String seed = 'a']) => seed * 64;

  /// A string in the shape `DocumentIntake` assigns, built for the same reason.
  String aDocId() => '1' * 32;

  /// The destination an entry carries. The harness never sends and this is not a
  /// workspace: the three values exist because an entry has the field.
  const TableRef nowhere = TableRef(
    teamId: 'eval',
    databaseId: 'eval',
    tableId: 'eval',
  );

  /// The entry `ExtractionService` wrote back, in [state].
  HistoryEntry anEntry({
    DocumentState state = DocumentState.reviewing,
    CanonicalDocument? values,
    String? failureReason,
  }) => HistoryEntry(
    docId: aDocId(),
    revision: 3,
    createdAt: DateTime.utc(2026, 10, 18, 9),
    state: state,
    documentHash: aHash('b'),
    destination: nowhere,
    values: values,
    failureReason: failureReason,
  );

  /// A document with a value of every kind the summary has something to say
  /// about: a green read, an amber read, a derived red, a user's edited value and
  /// the fields it never read.
  ///
  /// The values are invented and must not reach the file: `Muster GmbH` is no
  /// supplier, `X-2026-99` is no document number, and the amount is a number and
  /// not an invoice's.
  CanonicalDocument aDocument({
    bool needsReview = true,
    String engine = 'pdf-text/$pdfEngine',
  }) => CanonicalDocument(
    docDate: Present<CalendarDate>(
      CalendarDate(2026, 10, 1),
      Provenance.read,
      ConfidenceState.green,
    ),
    supplierName: Present<String>(
      'Muster GmbH',
      Provenance.read,
      ConfidenceState.amber,
    ),
    docNumber: Edited<String>('X-2026-99'),
    grossTotal: Present<Money>(
      Money(1234567, eur),
      Provenance.derived,
      ConfidenceState.red,
    ),
    currency: Present<CurrencyCode>(
      eur,
      Provenance.read,
      ConfidenceState.green,
    ),
    supplierTaxId: Present<String>(
      'B12345678',
      Provenance.repaired,
      ConfidenceState.amber,
    ),
    needsReview: needsReview,
    recognitionEngine: engine,
    sourceHash: aHash('c'),
  );

  /// A completed extraction of [document], as the step answers it.
  ExtractionCompleted completed(
    CanonicalDocument document, {
    CountryDetection detection = const Undetected(
      reason: UndetectedReason.noEvidence,
    ),
  }) => ExtractionCompleted(
    entry: anEntry(values: document),
    document: document,
    detection: detection,
  );

  /// The summary of [outcome], with the same hash on both sides unless a test
  /// says otherwise.
  String summaryOf(
    ExtractionOutcome outcome, {
    String seed = 'd',
    String? sha256After,
    int ms = 1234,
  }) => extractionEvalSummaryJson(
    outcome: outcome,
    sha256Before: aHash(seed),
    sha256After: sha256After ?? aHash(seed),
    ms: ms,
  );

  /// [written] parsed back into its JSON.
  Map<String, Object?> jsonOf(String written) =>
      jsonDecode(written) as Map<String, Object?>;

  test('one extraction becomes one file of the keys design names', () {
    final Map<String, Object?> json = jsonOf(
      summaryOf(
        completed(
          aDocument(),
          detection: Detected(
            row: CountryTable.es,
            evidence: const <CountryEvidenceKind>[CountryEvidenceKind.taxId],
          ),
        ),
      ),
    );

    expect(json.keys.toList(), <String>[
      'route',
      'recognition_engine',
      'state_after',
      'sha256_before',
      'sha256_after',
      'sha256_changed',
      'ms',
      'needs_review',
      'fields',
      'country',
      'failure_code',
    ]);
    expect(json['route'], 'pdf-text');
    expect(json['recognition_engine'], pdfEngine);
    expect(json['state_after'], 'reviewing');
    expect(json['sha256_before'], aHash('d'));
    expect(json['sha256_after'], aHash('d'));
    expect(json['sha256_changed'], 0);
    expect(json['ms'], 1234);
    expect(json['needs_review'], isTrue);
    expect(json['failure_code'], isNull);
    expect(json['country'], <String, Object?>{'kind': 'row'});
  });

  test('a file that was changed while it was read says so, as a number', () {
    final Map<String, Object?> json = jsonOf(
      summaryOf(completed(aDocument()), sha256After: aHash('e')),
    );

    expect(json['sha256_changed'], 1);
    expect(json['sha256_after'], aHash('e'));
  });

  group('the fields of the document', () {
    test(
      'each carries a confidence state and a provenance tag, and no value',
      () {
        final Map<String, Object?> fields =
            jsonOf(summaryOf(completed(aDocument())))['fields']!
                as Map<String, Object?>;

        expect(fields['docDate'], <String, Object?>{
          'confidence': 'green',
          'provenance': 'read',
        });
        expect(fields['supplierTaxId'], <String, Object?>{
          'confidence': 'amber',
          'provenance': 'repaired',
        });
        // The derived total: the state is the model's, the tag says how it was
        // obtained, and neither is the amount.
        expect(fields['grossTotal'], <String, Object?>{
          'confidence': 'red',
          'provenance': 'derived',
        });
        // A typed value is not an extracted one: it carries no tag and no
        // confidence, and its state says so.
        expect(fields['docNumber'], <String, Object?>{
          'confidence': 'edited',
          'provenance': null,
        });
        // A field the document never held is `absent` and not zero.
        expect(fields['supplierAddress'], <String, Object?>{
          'confidence': 'absent',
          'provenance': null,
        });
      },
    );

    test('every canonical core field is reported, and nothing that is not one', () {
      final Map<String, Object?> fields =
          jsonOf(summaryOf(completed(aDocument())))['fields']!
              as Map<String, Object?>;

      // The document's own serialised form decides what a field is: every entry
      // that holds a field value, and no list, flag, engine or hash.
      final Set<String> expected = aDocument()
          .toJson()
          .entries
          .where(
            (MapEntry<String, Object?> entry) =>
                entry.value is Map<String, Object?> &&
                (entry.value! as Map<String, Object?>).containsKey('state'),
          )
          .map((MapEntry<String, Object?> entry) => entry.key)
          .toSet();
      expect(fields.keys.toSet(), expected);
      expect(fields.keys, contains('supplierName'));
      for (final String notAField in <String>[
        'taxSlots',
        'surcharges',
        'needsReview',
        'recognitionEngine',
        'sourceHash',
      ]) {
        expect(fields.containsKey(notAField), isFalse);
      }
    });
  });

  test('a document no row governs names the reason and still names the route', () {
    final Map<String, Object?> json = jsonOf(
      summaryOf(
        completed(
          aDocument(engine: 'pdf-text/$pdfEngine [country=countryWithoutRow]'),
          detection: const Undetected(
            reason: UndetectedReason.countryWithoutRow,
          ),
        ),
      ),
    );

    // The label the values carry has the reason appended to it; the summary
    // reports the route and the engine alone, and the reason where it belongs.
    expect(json['route'], 'pdf-text');
    expect(json['recognition_engine'], pdfEngine);
    expect(json['country'], <String, Object?>{
      'kind': 'undetected',
      'reason': 'countryWithoutRow',
    });
  });

  test('a refused document carries its code and no route at all', () {
    const ExtractionFailureCode code =
        ExtractionFailureCode.textLayerUnreadable;
    final Map<String, Object?> json = jsonOf(
      summaryOf(
        ExtractionRefused(
          entry: anEntry(state: DocumentState.failed, failureReason: code.code),
          failure: const ExtractionFailure(code),
        ),
        ms: 20,
      ),
    );

    expect(json.keys.toList(), <String>[
      'route',
      'recognition_engine',
      'state_after',
      'sha256_before',
      'sha256_after',
      'sha256_changed',
      'ms',
      'needs_review',
      'fields',
      'country',
      'failure_code',
    ]);
    expect(json['state_after'], 'failed');
    expect(json['failure_code'], 'text_layer_unreadable');
    // Nothing was read, so nothing names a route, a value, a field or a country.
    expect(json['route'], isNull);
    expect(json['recognition_engine'], isNull);
    expect(json['needs_review'], isNull);
    expect(json['fields'], isEmpty);
    expect(json['country'], isNull);
    expect(json['ms'], 20);
  });

  test('not one value of the document is in the file', () {
    final String written = summaryOf(completed(aDocument()));

    for (final String value in <String>[
      'Muster',
      'GmbH',
      'X-2026-99',
      '1234567',
      'B12345678',
    ]) {
      expect(
        written,
        isNot(contains(value)),
        reason: 'the summary may be read or sent on: no value of the document',
      );
    }
  });

  test('every string in the file is a name the pipeline writes or a hash', () {
    // Hashes are the one string the file carries that no enum names; they are
    // allowed by their shape and by nothing else.
    final RegExp aSha256 = RegExp('^[0-9a-f]{64}\$');
    final Set<String> allowed = <String>{
      for (final ExtractionRoute route in ExtractionRoute.values) route.route,
      pdfEngine,
      ocrEngine,
      '$pdfEngine + $ocrEngine',
      for (final DocumentState state in DocumentState.values) state.name,
      for (final ConfidenceState state in ConfidenceState.values) state.name,
      for (final Provenance provenance in Provenance.values)
        provenance.wireName,
      for (final UndetectedReason reason in UndetectedReason.values)
        reason.name,
      for (final ExtractionFailureCode code in ExtractionFailureCode.values)
        code.code,
      // The two states design names beside the model's three: a field with no
      // reading, and a value the user typed.
      'absent',
      'edited',
      // The kinds of country answer.
      'row',
      'undetected',
    };

    final List<String> found = <String>[];
    void walk(Object? node) {
      if (node is Map<String, Object?>) {
        node.values.forEach(walk);
      } else if (node is List<Object?>) {
        node.forEach(walk);
      } else if (node is String) {
        found.add(node);
      }
    }

    walk(
      jsonOf(
        summaryOf(
          completed(
            aDocument(),
            detection: Detected(
              row: CountryTable.es,
              evidence: const <CountryEvidenceKind>[CountryEvidenceKind.taxId],
            ),
          ),
        ),
      ),
    );
    // A refusal's code is a string too, and it is a name of its own.
    walk(
      jsonOf(
        summaryOf(
          ExtractionRefused(
            entry: anEntry(state: DocumentState.failed),
            failure: const ExtractionFailure(
              ExtractionFailureCode.recognitionUnreadable,
            ),
          ),
        ),
      ),
    );

    expect(found, isNotEmpty);
    for (final String value in found) {
      expect(
        allowed.contains(value) || aSha256.hasMatch(value),
        isTrue,
        reason: '`$value` is not a name the pipeline writes',
      );
    }
  });

  group('the label the stored values carry', () {
    test('it splits into the route and the engine names', () {
      final ExtractionLabel text = extractionLabelOf('pdf-text/$pdfEngine');
      expect(text.route, 'pdf-text');
      expect(text.engine, pdfEngine);

      // pdf-mixed is the one route both engines read.
      final ExtractionLabel mixed = extractionLabelOf(
        'pdf-mixed/$pdfEngine + $ocrEngine',
      );
      expect(mixed.route, 'pdf-mixed');
      expect(mixed.engine, '$pdfEngine + $ocrEngine');
      expect(mixed.toString(), 'pdf-mixed/$pdfEngine + $ocrEngine');
    });

    test(
      'a label of another route or another engine is refused, not written',
      () {
        // This is what keeps a document's word out of the file: what is not one of
        // the pipeline's names does not become a string in the JSON.
        for (final String label in <String>[
          'own-route/$pdfEngine',
          'pdf-text/Muster GmbH',
          'pdf-text/$pdfEngine + Muster GmbH',
          'pdf-text/$pdfEngine [country=Muster]',
          'Muster GmbH',
          'pdf-text',
          '',
        ]) {
          expect(
            () => extractionLabelOf(label),
            throwsFormatException,
            reason: '`$label` is not a label this build writes',
          );
        }
      },
    );
  });

  test('the file name says what it holds and names the document', () {
    expect(
      extractionSummaryFileName(docId: 'synthetic-01'),
      'synthetic-01.extraction-summary.json',
    );
  });
}
