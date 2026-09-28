/// Where a value came from, and the source that supplied it.
///
/// Requirement served: FR-EXT-011 (`provenance-on-every-value`) — every
/// extracted value carries one of the four provenance tags, and whether a
/// consuming check may confirm depends on that tag.
library;

/// The four provenance tags of Funcional §6.2.1.
enum Provenance {
  /// Taken directly from the document's text, OCR consensus or positional
  /// extraction.
  read('read'),

  /// Taken from a structured e-invoice's embedded or attached XML.
  fromXml('from_xml'),

  /// Computed from other read values through an identity the document supports.
  derived('derived'),

  /// One implausible character replaced by the unique value a check digit
  /// admits.
  repaired('repaired');

  /// Creates a provenance tag with its [wireName].
  const Provenance(this.wireName);

  /// The wire name used for serialisation.
  final String wireName;

  /// Whether a value with this provenance may confirm a consuming check.
  ///
  /// Only [read] and [fromXml] may confirm.
  bool get mayConfirm => this == read || this == fromXml;

  /// Serialises this tag by its wire name.
  String toJson() => wireName;

  /// Reads a tag from its wire name.
  static Provenance fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('provenance JSON must be a string');
    }

    for (final value in values) {
      if (value.wireName == json) {
        return value;
      }
    }

    throw FormatException('unknown provenance: $json');
  }
}

/// The separate origin of an extracted value: from the document or from
/// memory.
///
/// This is deliberately separate from [Provenance] (GAP-028): the four tags
/// describe how a value was obtained *from the document*, and §6.1.1's
/// "memory" for `supplier_name` is recorded here. A value typed or corrected
/// by the user is the `Edited` case of `FieldValue`, not a source.
enum ValueSource {
  /// The value came from the document.
  document,

  /// The value came from supplier memory.
  memory;

  /// Serialises this source by its name.
  String toJson() => name;

  /// Reads a source from its name.
  static ValueSource fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('value source JSON must be a string');
    }

    for (final value in values) {
      if (value.name == json) {
        return value;
      }
    }

    throw FormatException('unknown value source: $json');
  }
}
