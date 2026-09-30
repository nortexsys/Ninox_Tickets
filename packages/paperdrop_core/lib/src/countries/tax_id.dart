/// Tax identifier types, normalisation and classification by shape.
///
/// Requirement served: `countries-languages` · `tax-identifier-normalisation`
/// and `country-identifier-check-digits`. Classification is by shape only; the
/// three Spanish algorithms live in three separate files and are never guessed
/// by trying every algorithm.
library;

import '../checks/check_result.dart';

/// The tax identifier types the country table recognises.
enum TaxIdType {
  /// Spanish natural-person NIF: 8 digits + letter.
  esNif('ES_NIF'),

  /// Spanish foreign natural-person NIE: X/Y/Z + 7 digits + letter.
  esNie('ES_NIE'),

  /// Spanish legal-entity CIF: issuing letter + 7 digits + control.
  esCif('ES_CIF'),

  /// German intra-EU VAT identifier: `DE` + 9 digits.
  deUstid('DE_USTID'),

  /// German Steuernummer; deliberately not validated.
  deStnr('DE_STNR');

  /// Creates a type with its [wireName].
  const TaxIdType(this.wireName);

  /// The wire name used for serialisation.
  final String wireName;

  /// Serialises this type by its wire name.
  String toJson() => wireName;

  /// Reads a type from its wire name, or returns `null` for an unknown name.
  static TaxIdType? fromWireName(String wireName) {
    for (final type in values) {
      if (type.wireName == wireName) {
        return type;
      }
    }
    return null;
  }
}

final RegExp _esNifShape = RegExp(r'^[0-9]{8}[A-Z]$');
final RegExp _esNieShape = RegExp(r'^[XYZ][0-9]{7}[A-Z]$');
final RegExp _esCifShape = RegExp(r'^[ABCDEFGHJNPQRSUVW][0-9]{7}[0-9A-J]$');
final RegExp _deUstidShape = RegExp(r'^DE[0-9]{9}$');

/// Normalises a printed tax identifier: upper-case, with spaces, dots and
/// hyphens removed.
///
/// The country prefix is kept where the printed number carries one
/// (`DE 123 456 789` becomes `DE123456789`, `A-28.017.895` becomes
/// `A28017895`).
String normaliseTaxId(String raw) =>
    raw.toUpperCase().replaceAll(RegExp(r'[ .\-]'), '');

/// Classifies [normalised] by shape, returning `null` when no shape matches.
///
/// A Spanish identifier printed with an `ES` prefix has its type decided on
/// the part after the prefix (`ESA28017895` is an `ES_CIF`). `DE_STNR` has no
/// stable national shape and is therefore never classified from shape.
TaxIdType? classifyTaxId(String normalised) {
  final value = normalised.toUpperCase();
  final spanishPart = value.startsWith('ES') && value.length > 2
      ? value.substring(2)
      : value;

  if (_esNifShape.hasMatch(spanishPart)) {
    return TaxIdType.esNif;
  }
  if (_esNieShape.hasMatch(spanishPart)) {
    return TaxIdType.esNie;
  }
  if (_esCifShape.hasMatch(spanishPart)) {
    return TaxIdType.esCif;
  }
  if (_deUstidShape.hasMatch(value)) {
    return TaxIdType.deUstid;
  }
  return null;
}

/// Returns [CheckResult.notChecked] for a normalised `DE_USTID`.
///
/// The shape, classification and normalisation are implemented; the published
/// check-digit algorithm is blocked on GAP-030, so no algorithm is applied
/// here.
CheckResult isValidDeUstid(String normalised) => CheckResult.notChecked;

/// Returns [CheckResult.notChecked] for a normalised `DE_STNR`.
///
/// The German Steuernummer has no stable national format and therefore no
/// reliable check digit (`country-identifier-check-digits`, *the German
/// Steuernummer is deliberately left unchecked*).
CheckResult isValidDeStnr(String normalised) => CheckResult.notChecked;

/// A printed tax identifier and its normalised form.
class TaxId {
  /// The identifier exactly as printed.
  final String raw;

  /// The normalised form: upper-case, no spaces, dots or hyphens.
  final String normalised;

  const TaxId._(this.raw, this.normalised);

  /// Parses [raw], keeping it as printed and computing [normalised].
  factory TaxId.parse(String raw) => TaxId._(raw, normaliseTaxId(raw));

  /// The identifier type by shape, or `null` when it is unclassified.
  TaxIdType? get type => classifyTaxId(normalised);

  /// The normalised identifier, as the value itself.
  @override
  String toString() => normalised;

  /// Value equality on the raw and normalised forms.
  @override
  bool operator ==(Object other) =>
      other is TaxId && other.raw == raw && other.normalised == normalised;

  @override
  int get hashCode => Object.hash(raw, normalised);
}
