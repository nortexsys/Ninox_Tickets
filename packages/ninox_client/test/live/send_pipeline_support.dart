/// The pure helpers behind the T1.11 live send run (`send_pipeline_live_test.dart`).
///
/// They live here, apart from the live test, because they are testable **without a token**: the
/// payload has to be built only from fields the resolved schema shows, a date has to be a calendar
/// date before anything is sent, and the read-back comparison has to say what does not match
/// **without repeating a value**. All three are proved in CI by
/// `test/live/send_pipeline_support_test.dart`, which runs in every lane and in every CI run.
///
/// Nothing here touches the network, the environment or a file.
library;

import 'package:ninox_client/ninox_client.dart';

import 't19_support.dart';

/// The field the live send writes its date into.
///
/// It is the field the approved T1.9 contract wrote, and the one the disposable table `EF` shows as
/// a `date` (change design §1: the same contract as `write_limits_test.dart`). It is a literal on
/// purpose: the run writes a named column of the product owner's table, and a table that no longer
/// shows it refuses the run rather than having another column chosen for it.
const String dateFieldName = 'Fecha';

/// The field the live send writes its amount into: the `number` field the T1.9 contract wrote.
///
/// See [dateFieldName] for why it is a literal rather than a search.
const String amountFieldName = 'Importe';

/// The date the live send writes, as `YYYY-MM-DD` (ADR-004, `ninox-send/payload-shape`).
///
/// It is the day of the product owner's approval of this run — an invention that is only ever
/// written into the disposable table, never into a real one.
const String inventedDate = '2026-10-17';

/// The amount the live send writes: an **integer** in the currency's minor unit (ADR-004).
///
/// `1999` is 19.99 in the major unit. The type matters: an amount that round-trips through a binary
/// float is an amount that can come back a cent wrong, so the payload never carries a decimal.
const int inventedAmount = 1999;

/// The local document identifier the send reports its steps under — invented.
///
/// It is the key the run reads its own journal by (`InMemorySendJournal.stepsOf`), and it is not
/// the record identifier: the document is local, the record is Ninox's.
const String inventedDocId = 'paperdrop-live-send-1';

/// The name the synthetic document is attached under.
const String inventedFilename = 'paperdrop-send-pipeline.pdf';

/// The content type declared for the synthetic document.
const String inventedContentType = 'application/pdf';

/// Whether [field] is a formula field, which is never a write target.
///
/// `.../tables` returns **no** formula field at all — 1,416 of the database's 2,143 fields came back
/// (`docs/Plan/SPIKE_GAP-022_schema_formula_fields.md` §3) — so a formula field is normally absent
/// from the resolved schema rather than marked. The `.../schema` endpoint is the one that marks each
/// of them with the key `fn`, whose base type is `fn`; a listing that ever marks one, in `type`
/// (which is how this package reads `base`), must be skipped rather than sent, because writing one
/// answers **HTTP 500**, which the retry matrix reports as a mapping error rather than as an outage
/// (`ninox-send/the-retry-matrix`).
bool isFormulaField(NinoxField field) => field.type == 'fn';

/// The fields of [fields] a payload may target: everything but the formula fields (design §2.1).
List<NinoxField> writableFields(List<NinoxField> fields) => <NinoxField>[
  for (final NinoxField field in fields)
    if (!isFormulaField(field)) field,
];

/// The resolved schema as one sentence: each field's name and type, formula fields included.
///
/// It names fields and types and never a value, which is what a refusal and the run's own stdout
/// need: the product owner approves a **shape** before the run, not a record's contents.
String describeFields(List<NinoxField> fields) => fields
    .map((NinoxField field) => '${field.name} (${field.type})')
    .join(', ');

/// Whether [value] is a calendar date written `YYYY-MM-DD`.
///
/// ADR-004 sends a date as that string and the API stores it verbatim, so the run validates the one
/// date it writes before anything is sent: `2026-02-30` matches the pattern and is not a day, and a
/// date that is not a day is not something to learn from a 500.
bool isIsoDate(String value) {
  if (!_isoDate.hasMatch(value)) return false;
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) return false;
  // `DateTime.parse` rolls an impossible day over into the next month (`2026-02-30` becomes
  // 2 March), so the parts are compared back rather than trusted.
  return parsed.year == int.parse(value.substring(0, 4)) &&
      parsed.month == int.parse(value.substring(5, 7)) &&
      parsed.day == int.parse(value.substring(8, 10));
}

final RegExp _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// The payload of the live send: the two fields it targets, and the body the pipeline sends.
///
/// The body is built **once**, before the first write, and the same map is handed to the send and
/// compared with the read-back afterwards. Building it twice — once to send and once to compare —
/// is what made the 2026-10-08 T1.9 run report a difference that was its own doing (that run's
/// defect 1), and this run does not repeat it.
final class SendPayload {
  /// Builds a payload from the names its two fields resolved to and the body that carries them.
  ///
  /// The body is wrapped in [Map.unmodifiable] so that nothing between here and the port can change
  /// what was sent after the read-back is compared with it.
  SendPayload({
    required this.dateField,
    required this.amountField,
    required Map<String, Object?> fieldsByName,
  }) : fieldsByName = Map<String, Object?>.unmodifiable(fieldsByName);

  /// The name of the field the date is written into, as the schema resolves it.
  final String dateField;

  /// The name of the field the amount is written into, as the schema resolves it.
  final String amountField;

  /// The body: keyed by the destination's **current field names** (ADR-004), and nothing else.
  final Map<String, Object?> fieldsByName;

  /// How many fields the payload writes — the count, for stdout and the results file.
  int get fieldCount => fieldsByName.length;

  /// The payload's keys, in the order it sends them: a shape, never a value.
  List<String> get keys => fieldsByName.keys.toList();

  /// The shape, printed before the run and after it. No value appears here.
  @override
  String toString() =>
      'SendPayload($fieldCount fields: ${keys.join(', ')}; date $dateField, '
      'amount $amountField)';
}

/// The payload of the live send, built **only** from fields the resolved schema shows (design §2.1).
///
/// [fields] are the fields of the resolved `EF` table, exactly as `GET .../tables` returned them.
/// Every refusal below happens before the first write, and each one says what it saw:
///
/// * a field of the payload is a **formula field** (`fn`) — writing one answers HTTP 500, so it is
///   skipped rather than sent, and a payload that would have to target one is a refusal;
/// * a field of the payload is **not there**, or not of the type its value needs — the run does not
///   choose another column of the product owner's table;
/// * the invented date is not a real `YYYY-MM-DD` calendar date.
///
/// A refusal is a [StateError]; the run turns it into its own refusal before any request that
/// writes is made.
SendPayload buildSendPayload(List<NinoxField> fields) {
  final List<NinoxField> writable = writableFields(fields);
  final NinoxField date = _fieldFor(
    writable,
    name: dateFieldName,
    type: 'date',
    holds: 'the date of the document',
    formulaFields: _formulaFieldsAmong(fields, dateFieldName),
  );
  final NinoxField amount = _fieldFor(
    writable,
    name: amountFieldName,
    type: 'number',
    holds: 'the gross total of the document',
    formulaFields: _formulaFieldsAmong(fields, amountFieldName),
  );
  if (!isIsoDate(inventedDate)) {
    throw StateError(
      'the live send refuses to run: the invented date "$inventedDate" is not a YYYY-MM-DD '
      'calendar date, and a date that is not one is never sent (ADR-004). Nothing was written.',
    );
  }
  return SendPayload(
    dateField: date.name,
    amountField: amount.name,
    fieldsByName: <String, Object?>{
      date.name: inventedDate,
      amount.name: inventedAmount,
    },
  );
}

/// The formula fields of [fields] that carry [name]: the reason a payload field is not writable
/// even though the table shows the name at all.
List<NinoxField> _formulaFieldsAmong(List<NinoxField> fields, String name) =>
    <NinoxField>[
      for (final NinoxField field in fields)
        if (field.name == name && isFormulaField(field)) field,
    ];

/// Resolves one field of the payload by its current name and the type its value needs.
NinoxField _fieldFor(
  List<NinoxField> writable, {
  required String name,
  required String type,
  required String holds,
  required List<NinoxField> formulaFields,
}) {
  if (formulaFields.isNotEmpty) {
    throw StateError(
      'the live send refuses to run: the field "$name", which $holds, is a formula field (the '
      '`fn` marker) and a formula field cannot be written — the API answers HTTP 500 for one '
      '(SPIKE_GAP-022, `ninox-send/the-retry-matrix`). A formula field is not a mapping target. '
      'Nothing was written.',
    );
  }
  for (final NinoxField field in writable) {
    if (field.name != name) continue;
    if (field.type != type) {
      throw StateError(
        'the live send refuses to run: the field "$name", which $holds, is a "${field.type}" and '
        'not a $type, so the value this run would write is not the value the column holds. '
        'Nothing was written.',
      );
    }
    return field;
  }
  throw StateError(
    'the live send refuses to run: the table shows no field called "$name", which $holds; it '
    'shows ${describeFields(writable)}. The run writes the two fields the approved contract names '
    'and does not choose another column of the product owner\'s table. Nothing was written.',
  );
}

/// What the read-back of the live send agrees with, and what it does not — and never a value.
///
/// `ninox-send/create-attach-read-back` (FR-SND-001) is the reason the read-back and not the request
/// is the evidence: a table default or a formula field can silently override what was submitted, and
/// the create response does not reveal it. So the run compares the **stored** values and the stored
/// file with what it sent, and reports every disagreement by **field name**, never by value: the
/// results file is written on the product owner's machine and stays free of a record's contents
/// (change design §2.4).
final class ReadBackCheck {
  const ReadBackCheck._({
    required this.checkedFieldCount,
    required this.fieldsNotStored,
    required this.fieldsThatDiffer,
    required this.fileCount,
    required this.fileFound,
    required this.nameMatches,
    required this.sizeMatches,
    required this.contentTypeMatches,
  });

  /// Compares [readBack] and [files] with what the send asked Ninox to store.
  ///
  /// [dateField] is the payload's date field: the stored value may be the `YYYY-MM-DD` that was
  /// sent or an ISO-8601 stamp of the same day, and both are the date that was sent.
  factory ReadBackCheck.of({
    required Map<String, Object?> sent,
    required NinoxRecord readBack,
    required List<NinoxFile> files,
    required String filename,
    required int size,
    required String contentType,
    required String dateField,
  }) {
    final List<String> notStored = <String>[];
    final List<String> differ = <String>[];
    for (final MapEntry<String, Object?> entry in sent.entries) {
      if (!readBack.fields.containsKey(entry.key)) {
        notStored.add(entry.key);
      } else if (!sameValue(
        entry.value,
        readBack.fields[entry.key],
        asDate: entry.key == dateField,
      )) {
        differ.add(entry.key);
      }
    }
    NinoxFile? found;
    for (final NinoxFile file in files) {
      if (file.name == filename) found = file;
    }
    return ReadBackCheck._(
      checkedFieldCount: sent.length,
      fieldsNotStored: List<String>.unmodifiable(notStored),
      fieldsThatDiffer: List<String>.unmodifiable(differ),
      fileCount: files.length,
      fileFound: found != null,
      nameMatches: found != null && found.name == filename,
      sizeMatches: found != null && found.size == size,
      contentTypeMatches: found != null && found.contentType == contentType,
    );
  }

  /// How many payload fields were compared.
  final int checkedFieldCount;

  /// The payload's field names the read-back does not carry at all.
  final List<String> fieldsNotStored;

  /// The payload's field names the read-back stores with a different value than the one sent.
  ///
  /// A field appearing here is a **finding**, not something to fix in this change: the read-back is
  /// the truth, and a formula field or a table default overriding a submitted value is exactly what
  /// ADR-004 says can happen — and exactly what the confirmation has to show.
  final List<String> fieldsThatDiffer;

  /// How many files the read-back lists for the record.
  final int fileCount;

  /// Whether the read-back lists an attachment under the name that was uploaded.
  final bool fileFound;

  /// Whether that attachment's name is the one that was uploaded.
  final bool nameMatches;

  /// Whether that attachment's size is the size of the bytes that were uploaded.
  final bool sizeMatches;

  /// Whether that attachment's content type is the one that was declared.
  final bool contentTypeMatches;

  /// Whether everything compared agrees: the values, the name, the size and the content type.
  bool get allMatch =>
      fieldsNotStored.isEmpty &&
      fieldsThatDiffer.isEmpty &&
      nameMatches &&
      sizeMatches &&
      contentTypeMatches;

  /// Every disagreement as a sentence that names no value: field names, and what about the file.
  List<String> get differences => <String>[
    for (final String name in fieldsNotStored)
      'the read-back does not carry "$name"',
    for (final String name in fieldsThatDiffer)
      'the read-back stores a different value under "$name" than the one that was sent — the '
          'read-back is what counts, so this is a finding about the destination',
    if (!fileFound)
      'the read-back lists no attachment under the uploaded name, among $fileCount file(s)',
    if (fileFound && !sizeMatches) 'the read-back stores the attachment with a size other than the bytes that were uploaded',
    if (fileFound && !contentTypeMatches) 'the read-back stores the attachment with a content type other than the one declared',
  ];

  /// The check, for the results file: counts, names and booleans only — no value, no stored value.
  Map<String, Object?> toJson() => <String, Object?>{
    'checkedFieldCount': checkedFieldCount,
    'fieldsNotStored': fieldsNotStored,
    'fieldsThatDiffer': fieldsThatDiffer,
    'fileCount': fileCount,
    'fileFound': fileFound,
    'nameMatches': nameMatches,
    'sizeMatches': sizeMatches,
    'contentTypeMatches': contentTypeMatches,
    'allMatch': allMatch,
  };

  @override
  String toString() =>
      'ReadBackCheck($checkedFieldCount fields, $fileCount files, '
      '${allMatch ? 'all match' : 'differences: ${differences.length}'})';
}
