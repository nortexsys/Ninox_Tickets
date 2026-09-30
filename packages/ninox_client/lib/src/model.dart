/// The value types the port hands back, and the reading of the JSON Ninox returns.
///
/// Every type here is immutable and compares by value, because the wizard, the send pipeline and
/// the tests all compare what was read against what was expected.
///
/// The shapes were taken from the vendored `ninox` skill's verified reference
/// (`references/rest-api.md`, `scripts/ninox_client.py`), from `corpus_test/REPORT.md` §3 for the
/// files response, and from `docs/Plan/SPIKE_GAP-022_schema_formula_fields.md` for the table and
/// record shapes; each fixture of `test/fixtures/classic/` names its own source and states that it
/// is **shape from documentation, to be re-recorded live in §6** of the change's design.
library;

import 'dart:convert';

import 'errors.dart';

/// A Ninox record identifier.
///
/// The create response returns it, and the read, attachment and file endpoints take it as a path
/// segment. It is a value type rather than a bare `String` so that a team id cannot be passed
/// where a record id is expected; the representation is the identifier itself.
extension type const RecordId(String value) {}

/// A Ninox team, as `GET /v1/teams` returns it. Both keys are verified (ADR-004).
final class NinoxTeam {
  /// Builds a team.
  const NinoxTeam({required this.id, required this.name});

  /// Reads one team out of a decoded response object.
  factory NinoxTeam.fromJson(Map<String, Object?> json) => NinoxTeam(
    id: jsonIdentifier(json, 'id', what: 'a team'),
    name: jsonString(json, 'name', what: 'a team'),
  );

  /// The team identifier, the one every other call quotes.
  final String id;

  /// The team's display name, for the wizard to show.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is NinoxTeam && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'NinoxTeam($id, $name)';
}

/// A Ninox database under a team, as `GET /v1/teams/{team}/databases` returns it.
final class NinoxDatabase {
  /// Builds a database.
  const NinoxDatabase({required this.id, required this.name});

  /// Reads one database out of a decoded response object.
  factory NinoxDatabase.fromJson(Map<String, Object?> json) => NinoxDatabase(
    id: jsonIdentifier(json, 'id', what: 'a database'),
    name: jsonString(json, 'name', what: 'a database'),
  );

  /// The database identifier.
  final String id;

  /// The database's display name.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is NinoxDatabase && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'NinoxDatabase($id, $name)';
}

/// One field of a table, as `GET .../tables` returns it.
///
/// The listing endpoint returns exactly `id`, `name` and `type`, plus `choices` on a choice field
/// and the reference keys on a relation (ADR-004, verified across 1,416 fields). The extra keys are
/// **not** modelled yet: the mapping that consumes them — offering the existing options of a choice
/// field — is `destinations-mapping`'s and lands with the wizard (T1.10), so this package passes on
/// what the port's callers need and does not invent the rest.
///
/// **Formula fields are absent from this endpoint**, not marked: of 2,143 fields in the database
/// the spike measured, `.../tables` returned 1,416. The adapter adds no filtering of its own and
/// never reads `.../schema` (`docs/Plan/SPIKE_GAP-022_schema_formula_fields.md` §3).
final class NinoxField {
  /// Builds a field.
  const NinoxField({required this.id, required this.name, required this.type});

  /// Reads one field out of a decoded response object.
  factory NinoxField.fromJson(Map<String, Object?> json) => NinoxField(
    id: jsonIdentifier(json, 'id', what: 'a field'),
    name: jsonString(json, 'name', what: 'a field'),
    type: jsonString(json, 'type', what: 'a field'),
  );

  /// The stable field identifier. A destination stores this, never the name.
  final String id;

  /// The field's **current** name. This is the payload key, and it changes when a column is
  /// renamed (ADR-004: names versus identifiers).
  final String name;

  /// The field's kind, as the endpoint spells it (`number`, `string`, `date`, `choice`, `ref`,
  /// and so on). Read as observed, not as an exhaustive vendor enumeration.
  final String type;

  @override
  bool operator ==(Object other) =>
      other is NinoxField &&
      other.id == id &&
      other.name == name &&
      other.type == type;

  @override
  int get hashCode => Object.hash(id, name, type);

  @override
  String toString() => 'NinoxField($id, $type, $name)';
}

/// A Ninox table with its fields, as `GET .../tables` returns it — one call, no second schema
/// request (ADR-004; `.../tables/{table}/fields` does not exist and answers 404).
final class NinoxTable {
  /// Builds a table.
  const NinoxTable({
    required this.id,
    required this.name,
    required this.fields,
  });

  /// Reads one table out of a decoded response object.
  factory NinoxTable.fromJson(Map<String, Object?> json) {
    final fields = jsonOptionalObjectList(json, 'fields', what: 'a table');
    return NinoxTable(
      id: jsonIdentifier(json, 'id', what: 'a table'),
      name: jsonString(json, 'name', what: 'a table'),
      fields: fields == null
          ? const <NinoxField>[]
          : [for (final field in fields) NinoxField.fromJson(field)],
    );
  }

  /// The table identifier, the one a destination stores and a call quotes.
  final String id;

  /// The table's display name.
  final String name;

  /// The table's fields. Formula fields are absent rather than marked — see [NinoxField].
  final List<NinoxField> fields;

  @override
  bool operator ==(Object other) =>
      other is NinoxTable &&
      other.id == id &&
      other.name == name &&
      _listEquals(other.fields, fields);

  @override
  int get hashCode => Object.hash(id, name, _listHash(fields));

  @override
  String toString() => 'NinoxTable($id, $name, ${fields.length} fields)';
}

/// A Ninox record.
///
/// `createdAt` and `createdBy` are present on every record **regardless of mapping**, which is what
/// makes the read-side reconciliation of an uncertain create possible without a marker field in
/// the user's table (`ninox-send/reconciliation-of-an-uncertain-create`). The list endpoint returns
/// all five keys; the single-record endpoint returns the identifier and the fields and may omit the
/// rest, so they are read when present and `null` when not.
final class NinoxRecord {
  /// Builds a record.
  const NinoxRecord({
    required this.id,
    required this.fields,
    this.createdAt,
    this.createdBy,
    this.modifiedAt,
    this.modifiedBy,
    this.sequence,
  });

  /// Reads one record out of a decoded response object.
  ///
  /// A body without a `fields` object is read as a record with no mapped values rather than as a
  /// malformed response: the endpoint always sends the key, and a record whose values are all
  /// empty is not an error.
  factory NinoxRecord.fromJson(Map<String, Object?> json) => NinoxRecord(
    id: RecordId(jsonIdentifier(json, 'id', what: 'a record')),
    fields: jsonOptionalObject(json, 'fields', what: 'a record') ?? const {},
    createdAt: jsonOptionalString(json, 'createdAt', what: 'a record'),
    createdBy: jsonOptionalString(json, 'createdBy', what: 'a record'),
    modifiedAt: jsonOptionalString(json, 'modifiedAt', what: 'a record'),
    modifiedBy: jsonOptionalString(json, 'modifiedBy', what: 'a record'),
    sequence: jsonOptionalInt(json, 'sequence', what: 'a record'),
  );

  /// The record identifier, as the create response returned it and as the matrix round-trips it.
  final RecordId id;

  /// The record's values, keyed by field **name** and returned exactly as Ninox stored them.
  /// Formula fields and table defaults silently override what was submitted, which is why this
  /// read-back — and not the request — is what the confirmation shows.
  final Map<String, Object?> fields;

  /// When the record was created, as the API returns it (an ISO-8601 stamp). Kept verbatim.
  final String? createdAt;

  /// Who created it, as the API returns it. Kept verbatim.
  final String? createdBy;

  /// When it was last modified, when the endpoint returns it.
  final String? modifiedAt;

  /// Who last modified it, when the endpoint returns it.
  final String? modifiedBy;

  /// The endpoint's own sequence coordinate, when it returns one. It is **not** the response
  /// order: the spike measured the default listing to be out of sequence order.
  final int? sequence;

  @override
  bool operator ==(Object other) =>
      other is NinoxRecord &&
      other.id == id &&
      _jsonEquals(other.fields, fields) &&
      other.createdAt == createdAt &&
      other.createdBy == createdBy &&
      other.modifiedAt == modifiedAt &&
      other.modifiedBy == modifiedBy &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(
    id,
    _jsonHash(fields),
    createdAt,
    createdBy,
    modifiedAt,
    modifiedBy,
    sequence,
  );

  /// Prints the identifier and how many values the record carries — never a value, because a
  /// record's values are a person's data.
  @override
  String toString() => 'NinoxRecord(${id.value}, ${fields.length} fields)';
}

/// One file attached to a record, as `GET .../records/{id}/files` returns it.
///
/// The three keys are `name`, `size` and `contentType`, read live in `corpus_test/REPORT.md` §3
/// when the attachment contract was closed. The read-back is compared against what was uploaded:
/// the document attaches to the **record**, not to a field of type file (ADR-004).
final class NinoxFile {
  /// Builds a file.
  const NinoxFile({
    required this.name,
    required this.size,
    required this.contentType,
  });

  /// Reads one file out of a decoded response object.
  factory NinoxFile.fromJson(Map<String, Object?> json) => NinoxFile(
    name: jsonString(json, 'name', what: 'a file'),
    size: jsonInt(json, 'size', what: 'a file'),
    contentType: jsonString(json, 'contentType', what: 'a file'),
  );

  /// The file's name, as stored.
  final String name;

  /// The file's size in bytes, as stored.
  final int size;

  /// The file's content type, as stored.
  final String contentType;

  @override
  bool operator ==(Object other) =>
      other is NinoxFile &&
      other.name == name &&
      other.size == size &&
      other.contentType == contentType;

  @override
  int get hashCode => Object.hash(name, size, contentType);

  @override
  String toString() => 'NinoxFile($name, $size bytes, $contentType)';
}

// ---------------------------------------------------------------------------------------------
// Reading the JSON. These helpers are package-internal: `lib/ninox_client.dart` does not export
// this file's helpers, only its types.
// ---------------------------------------------------------------------------------------------

/// Reads a whole response body as a JSON object of `<what>`.
///
/// Anything else — a body that is not JSON, a list, a bare string — is
/// [UnexpectedResponse], because the adapter will not guess what it received.
Map<String, Object?> jsonObject(String body, {required String what}) {
  final decoded = _decode(body, what: what);
  if (decoded is! Map) {
    throw UnexpectedResponse('$what: expected a JSON object');
  }
  return _stringKeys(decoded, what: what);
}

/// Reads a whole response body as a JSON array of objects, as `<what>`.
List<Map<String, Object?>> jsonObjectList(String body, {required String what}) {
  final decoded = _decode(body, what: what);
  if (decoded is! List) {
    throw UnexpectedResponse('$what: expected a JSON array');
  }
  return _objectsOf(decoded, what: what);
}

/// The response of a create: the new record's identifier.
///
/// The skill's reference client reads the identifier off an object keyed `id`
/// (`scripts/ninox_client.py`, `create()` then `cmd_create`), which is what the skill's verified
/// trace settled: a `200`, not a `201`, carrying the identifier the attachment call and the deep
/// link both need. Whether that value is a JSON string or a number is **not** settled by the trace,
/// so an integer is accepted and normalised; §6 re-records it.
RecordId recordIdFromJson(Map<String, Object?> json, {required String what}) {
  final id = jsonIdentifier(json, 'id', what: what);
  if (id.isEmpty) throw UnexpectedResponse('$what: the identifier is empty');
  return RecordId(id);
}

/// Reads a required identifier-valued key.
///
/// Identifiers are alphanumeric strings in the endpoints this package uses (team, database and
/// table identifiers), but record and field identifiers look numeric in the traces, so an integral
/// JSON number is accepted and rendered as its digits.
String jsonIdentifier(
  Map<String, Object?> json,
  String key, {
  required String what,
}) {
  final value = json[key];
  if (value is String) return value;
  if (value is int) return value.toString();
  throw UnexpectedResponse('$what: expected a string "$key"');
}

/// Reads a required string-valued key.
String jsonString(
  Map<String, Object?> json,
  String key, {
  required String what,
}) {
  final value = json[key];
  if (value is String) return value;
  throw UnexpectedResponse('$what: expected a string "$key"');
}

/// Reads an optional string-valued key.
String? jsonOptionalString(
  Map<String, Object?> json,
  String key, {
  required String what,
}) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw UnexpectedResponse('$what: expected a string "$key"');
}

/// Reads a required integral key.
int jsonInt(Map<String, Object?> json, String key, {required String what}) {
  final value = json[key];
  if (value is int) return value;
  throw UnexpectedResponse('$what: expected a whole number "$key"');
}

/// Reads an optional integral key.
int? jsonOptionalInt(
  Map<String, Object?> json,
  String key, {
  required String what,
}) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw UnexpectedResponse('$what: expected a whole number "$key"');
}

/// Reads an optional nested object.
Map<String, Object?>? jsonOptionalObject(
  Map<String, Object?> json,
  String key, {
  required String what,
}) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) {
    throw UnexpectedResponse('$what: expected an object "$key"');
  }
  return _stringKeys(value, what: what);
}

/// Reads an optional nested array of objects.
List<Map<String, Object?>>? jsonOptionalObjectList(
  Map<String, Object?> json,
  String key, {
  required String what,
}) {
  final value = json[key];
  if (value == null) return null;
  if (value is! List) {
    throw UnexpectedResponse('$what: expected an array "$key"');
  }
  return _objectsOf(value, what: what);
}

List<Map<String, Object?>> _objectsOf(
  List<Object?> values, {
  required String what,
}) {
  final result = <Map<String, Object?>>[];
  for (final value in values) {
    if (value is! Map) {
      throw UnexpectedResponse(
        '$what: expected every element to be a JSON object',
      );
    }
    result.add(_stringKeys(value, what: what));
  }
  return result;
}

Object? _decode(String body, {required String what}) {
  try {
    return jsonDecode(body);
  } on FormatException {
    throw UnexpectedResponse('$what: the body is not JSON');
  }
}

Map<String, Object?> _stringKeys(
  Map<Object?, Object?> map, {
  required String what,
}) {
  final result = <String, Object?>{};
  for (final entry in map.entries) {
    final key = entry.key;
    if (key is! String) {
      throw UnexpectedResponse('$what: an object key is not a string');
    }
    result[key] = entry.value;
  }
  return result;
}

/// Deep equality over decoded JSON, so a record read twice compares equal.
bool _jsonEquals(Object? one, Object? other) {
  if (one is Map && other is Map) {
    if (one.length != other.length) return false;
    for (final entry in one.entries) {
      if (!other.containsKey(entry.key)) return false;
      if (!_jsonEquals(entry.value, other[entry.key])) return false;
    }
    return true;
  }
  if (one is List && other is List) {
    if (one.length != other.length) return false;
    for (var index = 0; index < one.length; index++) {
      if (!_jsonEquals(one[index], other[index])) return false;
    }
    return true;
  }
  return one == other;
}

/// A hash consistent with [_jsonEquals]: order-independent for maps, order-dependent for lists.
int _jsonHash(Object? value) {
  if (value is Map) {
    var sum = 0;
    for (final entry in value.entries) {
      sum += Object.hash(entry.key, _jsonHash(entry.value));
    }
    return sum;
  }
  if (value is List) return Object.hashAll(value.map(_jsonHash));
  return value.hashCode;
}

bool _listEquals<T>(List<T> one, List<T> other) {
  if (one.length != other.length) return false;
  for (var index = 0; index < one.length; index++) {
    if (one[index] != other[index]) return false;
  }
  return true;
}

int _listHash<T>(List<T> values) => Object.hashAll(values);
