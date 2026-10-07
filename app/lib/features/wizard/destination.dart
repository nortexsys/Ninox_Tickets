/// What a destination is, as far as the wizard is concerned (design §5 and §6).
///
/// Requirement served: FR-DST-001 (`destinations-mapping/what-a-destination-is`), FR-DST-003
/// (`destinations-store-identifiers-not-names`) and FR-DST-006
/// (`destinations-mapping/per-field-absent-setting`). The wizard builds a destination; what is done
/// with it afterwards is the send pipeline's.
///
/// **Identifiers, not names.** [FieldMapping] carries the field's identifier as the thing that
/// identifies it and the name only to display it: the name is what a payload is keyed by and it
/// changes when a column is renamed (ADR-004).
library;

import 'package:ninox_client/ninox_client.dart';

/// The core fields a destination may map (design §5).
///
/// The six of FR-WIZ-005 in the fixed order `review-screen` names them, then the two the design
/// adds as mappable. The [wireName] is the canonical document's own name and is what a stored
/// destination is written with; it is not user-facing text.
enum CoreField {
  /// The document's date.
  docDate('doc_date'),

  /// The supplier's printed name.
  supplierName('supplier_name'),

  /// The supplier's tax identifier.
  supplierTaxId('supplier_tax_id'),

  /// The document's own number.
  docNumber('doc_number'),

  /// The gross total.
  grossTotal('gross_total'),

  /// The currency the amounts are printed in.
  currency('currency'),

  /// The net total, where the document prints one.
  netTotal('net_total'),

  /// The tax total, where the document prints one.
  taxTotal('tax_total');

  /// Creates a core field with its canonical name.
  const CoreField(this.wireName);

  /// The name the canonical document and a stored destination use.
  final String wireName;
}

/// What a mapped field is written as when the document prints no value for it (FR-DST-006).
///
/// The setting is a property of the **destination field** and never of the canonical model: the
/// same document may legitimately leave one column empty and write a zero into another. Its
/// consumer is Core's extraction solver; the wizard hardcodes neither outcome.
enum AbsentSetting {
  /// Leave the Ninox field empty. The default.
  empty,

  /// Write a zero.
  zero,
}

/// One core field mapped onto one Ninox field (design §6).
final class FieldMapping {
  /// Binds a core field to a Ninox field, by identifier, with its absent setting.
  const FieldMapping({
    required this.coreField,
    required this.ninoxFieldId,
    required this.ninoxFieldName,
    this.absent = AbsentSetting.empty,
  });

  /// Reads one mapping out of the JSON a [DestinationStore] wrote.
  ///
  /// Throws [FormatException] when the object is not one this class can read — a file the app wrote
  /// is read strictly, because reading it as "no mapping" would silently throw the user's work away.
  factory FieldMapping.fromJson(Object? json) {
    final Map<String, Object?> object = _objectOf(
      json,
      what: 'a field mapping',
    );
    final String coreFieldName = _stringOf(
      object,
      'core_field',
      what: 'a field mapping',
    );
    final CoreField coreField = _coreFieldNamed(coreFieldName);
    final String absentName = _stringOf(
      object,
      'absent',
      what: 'a field mapping',
    );
    return FieldMapping(
      coreField: coreField,
      ninoxFieldId: _stringOf(object, 'field_id', what: 'a field mapping'),
      ninoxFieldName: _stringOf(object, 'field_name', what: 'a field mapping'),
      absent: _absentSettingNamed(absentName),
    );
  }

  /// The core field this mapping supplies.
  final CoreField coreField;

  /// The Ninox field's stable identifier — what a destination stores (FR-DST-003).
  final String ninoxFieldId;

  /// The Ninox field's name as it was when it was mapped, **for display only**: a payload is keyed
  /// by the current name, which the send pipeline resolves again (`FR-DST-003`).
  final String ninoxFieldName;

  /// What is written when the document prints no value. [AbsentSetting.empty] unless the user
  /// chooses otherwise.
  final AbsentSetting absent;

  /// The stored form (design §6): the identifier that identifies the column, the name that displays
  /// it, the canonical field it belongs to, and the absent setting.
  Map<String, Object?> toJson() => <String, Object?>{
    'core_field': coreField.wireName,
    'field_id': ninoxFieldId,
    'field_name': ninoxFieldName,
    'absent': absent.name,
  };

  @override
  bool operator ==(Object other) =>
      other is FieldMapping &&
      other.coreField == coreField &&
      other.ninoxFieldId == ninoxFieldId &&
      other.ninoxFieldName == ninoxFieldName &&
      other.absent == absent;

  @override
  int get hashCode =>
      Object.hash(coreField, ninoxFieldId, ninoxFieldName, absent);

  /// Prints the core field and the Ninox identifier; nothing here is a secret.
  @override
  String toString() =>
      'FieldMapping(${coreField.wireName} -> $ninoxFieldName [$ninoxFieldId], '
      'absent: ${absent.name})';
}

/// A destination: the host, the three identifiers and the field mapping (design §6).
///
/// FR-DST-001's tuple, with the host inside it rather than beside it: a private-cloud customer's
/// host travels with the destination (ADR-017, FR-DST-008). The MVP configures one destination;
/// the type holds the mapping of one and knows nothing about how many exist.
///
/// **No secret lives in a destination.** The token is not here, and never is: it is the platform
/// keystore's (FR-CFG-004). Everything a destination holds is public configuration — a host, three
/// identifiers and field identifiers.
final class Destination {
  /// Binds a host, a team, a database, a table and the mapping between them.
  const Destination({
    required this.endpoint,
    required this.teamId,
    required this.databaseId,
    required this.tableId,
    this.mappings = const <FieldMapping>[],
  });

  /// Reads one destination out of the JSON a [DestinationStore] wrote.
  ///
  /// The host is read with `NinoxEndpoint.parse`, exactly as the token step reads what the user
  /// typed: a stored host that is not an accepted form is a [FormatException] and not a default,
  /// because falling back to the vendor's cloud would send the user's documents somewhere they did
  /// not choose.
  factory Destination.fromJson(Object? json) {
    final Map<String, Object?> object = _objectOf(json, what: 'a destination');
    final String host = _stringOf(object, 'host', what: 'a destination');
    final NinoxEndpoint? endpoint = NinoxEndpoint.parse(host);
    if (endpoint == null) {
      throw FormatException(
        'a destination: `$host` is not a host NinoxEndpoint accepts',
      );
    }
    return Destination(
      endpoint: endpoint,
      teamId: _stringOf(object, 'team', what: 'a destination'),
      databaseId: _stringOf(object, 'database', what: 'a destination'),
      tableId: _stringOf(object, 'table', what: 'a destination'),
      mappings: <FieldMapping>[
        for (final Object? mapping in _listOf(
          object,
          'mappings',
          what: 'a destination',
        ))
          FieldMapping.fromJson(mapping),
      ],
    );
  }

  /// The Ninox host this destination is on.
  final NinoxEndpoint endpoint;

  /// The team identifier.
  final String teamId;

  /// The database identifier, inside [teamId].
  final String databaseId;

  /// The table identifier, inside [databaseId].
  final String tableId;

  /// The field mappings, by identifier. Empty is a legitimate destination: nothing is mandatory
  /// (FR-WIZ-007).
  final List<FieldMapping> mappings;

  /// The stored form (design §6): the configured host, the three identifiers and the mappings.
  ///
  /// **No secret is here, and none ever can be.** A destination holds the host — a public address —
  /// three identifiers and field identifiers; the token lives in the platform's keystore (FR-CFG-004)
  /// and a test reads this file after a full run of the wizard to show that nothing of the token
  /// reached it.
  Map<String, Object?> toJson() => <String, Object?>{
    'host': endpoint.port == null
        ? endpoint.host
        : '${endpoint.host}:${endpoint.port}',
    'team': teamId,
    'database': databaseId,
    'table': tableId,
    'mappings': <Object?>[
      for (final FieldMapping mapping in mappings) mapping.toJson(),
    ],
  };

  @override
  bool operator ==(Object other) =>
      other is Destination &&
      other.endpoint == endpoint &&
      other.teamId == teamId &&
      other.databaseId == databaseId &&
      other.tableId == tableId &&
      _sameList(other.mappings, mappings);

  @override
  int get hashCode => Object.hash(
    endpoint,
    teamId,
    databaseId,
    tableId,
    Object.hashAll(mappings),
  );

  /// Prints the host, the three identifiers and how many fields are mapped — no field value, and
  /// no token, because a destination holds none.
  @override
  String toString() =>
      'Destination($endpoint, $teamId/$databaseId/$tableId, '
      '${mappings.length} mappings)';
}

/// Value equality over two lists, so that [Destination] compares by value.
bool _sameList<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// The core field with this wire name, or a [FormatException].
CoreField _coreFieldNamed(String wireName) {
  for (final CoreField coreField in CoreField.values) {
    if (coreField.wireName == wireName) {
      return coreField;
    }
  }
  throw FormatException('a field mapping: `$wireName` is not a core field');
}

/// The absent setting with this name, or a [FormatException].
AbsentSetting _absentSettingNamed(String name) {
  for (final AbsentSetting absent in AbsentSetting.values) {
    if (absent.name == name) {
      return absent;
    }
  }
  throw FormatException('a field mapping: `$name` is not an absent setting');
}

/// One stored object, or a [FormatException].
Map<String, Object?> _objectOf(Object? json, {required String what}) {
  if (json is! Map) {
    throw FormatException('$what: expected a JSON object');
  }
  return <String, Object?>{
    for (final MapEntry<Object?, Object?> entry in json.entries)
      '${entry.key}': entry.value,
  };
}

/// One stored list, or a [FormatException].
List<Object?> _listOf(
  Map<String, Object?> json,
  String key, {
  required String what,
}) {
  final Object? value = json[key];
  if (value is! List) {
    throw FormatException('$what: expected a JSON array under `$key`');
  }
  return <Object?>[...value];
}

/// One stored string, or a [FormatException].
String _stringOf(
  Map<String, Object?> json,
  String key, {
  required String what,
}) {
  final Object? value = json[key];
  if (value is! String) {
    throw FormatException('$what: expected a string under `$key`');
  }
  return value;
}
