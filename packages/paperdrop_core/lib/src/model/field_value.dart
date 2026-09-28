/// The field value every canonical field carries.
///
/// Requirement served: FR-EXT-011 (`provenance-on-every-value`) — an untagged
/// extracted value cannot be built, and absent is distinct from zero and from
/// `not_in_xml` (BR-13, FR-EXT-003). The [Edited] case is a user-typed value,
/// not an extracted value.
library;

import '../money/currency.dart';
import '../money/money.dart';
import '../money/rate.dart';
import 'calendar_date.dart';
import 'confidence.dart';
import 'doc_time.dart';
import 'provenance.dart';

/// Encodes and decodes a field value's inner value for JSON.
class FieldCodec<T> {
  /// Encodes a value into a JSON-compatible object.
  final Object? Function(T value) encode;

  /// Decodes a JSON-compatible object back into a value.
  final T Function(Object? json) decode;

  /// Creates a codec from [encode] and [decode].
  FieldCodec(this.encode, this.decode);
}

/// Encodes plain text field values.
final FieldCodec<String> stringCodec = FieldCodec<String>(
  (value) => value,
  (json) => json as String,
);

/// Encodes integer field values.
final FieldCodec<int> intCodec = FieldCodec<int>(
  (value) => value,
  (json) => json as int,
);

/// Encodes [Money] field values.
final FieldCodec<Money> moneyCodec = FieldCodec<Money>(
  (value) => value.toJson(),
  Money.fromJson,
);

/// Encodes [CurrencyCode] field values.
final FieldCodec<CurrencyCode> currencyCodec = FieldCodec<CurrencyCode>(
  (value) => value.toJson(),
  (json) {
    final currency = CurrencyCode.fromJson(json);
    if (currency == null) {
      throw FormatException('unknown currency code: $json');
    }
    return currency;
  },
);

/// Encodes [RateBp] field values.
final FieldCodec<RateBp> rateBpCodec = FieldCodec<RateBp>(
  (value) => value.toJson(),
  RateBp.fromJson,
);

/// Encodes [CalendarDate] field values.
final FieldCodec<CalendarDate> calendarDateCodec = FieldCodec<CalendarDate>(
  (value) => value.toJson(),
  CalendarDate.fromJson,
);

/// Encodes [DocTime] field values.
final FieldCodec<DocTime> docTimeCodec = FieldCodec<DocTime>(
  (value) => value.toJson(),
  DocTime.fromJson,
);

/// A field value: [Present], [Absent], [NotInXml] or [Edited].
sealed class FieldValue<T> {
  /// Creates a field value. The sealed subclasses are the public cases.
  const FieldValue();

  /// Serialises this field value using [codec] for the inner value.
  Object? toJson(FieldCodec<T> codec);

  /// Returns an [Edited] holding only [value], from any case.
  ///
  /// A typed or corrected value is not an extracted value: it carries no
  /// provenance and no confidence, and it can never confirm anything.
  Edited<T> edit(T value) => Edited<T>(value);

  /// Reads a field value serialised with [codec].
  static FieldValue<T> fromJson<T>(Object? json, FieldCodec<T> codec) {
    if (json is! Map<String, Object?>) {
      throw FormatException('field value JSON must be an object');
    }

    switch (json['state']) {
      case 'present':
        return Present<T>(
          codec.decode(json['value']),
          Provenance.fromJson(json['provenance']),
          ConfidenceState.fromJson(json['confidence']),
          source: json['source'] == null
              ? ValueSource.document
              : ValueSource.fromJson(json['source']),
        );
      case 'edited':
        return Edited<T>(codec.decode(json['value']));
      case 'absent':
        return Absent<T>();
      case 'not_in_xml':
        return NotInXml<T>();
      default:
        throw FormatException('unknown field value state: ${json['state']}');
    }
  }
}

/// An extracted value that was read, derived, repaired or taken from XML.
final class Present<T> extends FieldValue<T> {
  /// The value itself.
  final T value;

  /// The provenance tag every present value must carry.
  final Provenance provenance;

  /// The confidence state the model holds.
  final ConfidenceState confidence;

  /// The separate origin of the value: document or memory.
  final ValueSource source;

  /// Creates an extracted value with a required [provenance].
  ///
  /// [source] is `document` or `memory`; `user` is the [Edited] case and is not
  /// accepted here.
  const Present(
    this.value,
    this.provenance,
    this.confidence, {
    this.source = ValueSource.document,
  });

  @override
  Object? toJson(FieldCodec<T> codec) => <String, Object?>{
    'state': 'present',
    'value': codec.encode(value),
    'provenance': provenance.toJson(),
    'confidence': confidence.toJson(),
    'source': source.toJson(),
  };

  /// The present value and its tags, and nothing more.
  @override
  String toString() =>
      'Present($value, ${provenance.wireName}, ${confidence.name}, '
      'source: ${source.name})';

  /// Value equality on value and every tag.
  @override
  bool operator ==(Object other) =>
      other is Present<T> &&
      other.value == value &&
      other.provenance == provenance &&
      other.confidence == confidence &&
      other.source == source;

  @override
  int get hashCode => Object.hash(value, provenance, confidence, source);
}

/// A value the user typed or corrected on the review screen.
///
/// It carries no provenance tag and no confidence state: it is not an
/// extracted value (FR-EXT-011), and the edited marker replaces the colour
/// (DEC-007). It is always the value sent, and it can never confirm anything
/// (BR-02).
final class Edited<T> extends FieldValue<T> {
  /// The value the user typed or corrected.
  final T value;

  /// Creates an edited value holding only [value].
  const Edited(this.value);

  @override
  Object? toJson(FieldCodec<T> codec) => <String, Object?>{
    'state': 'edited',
    'value': codec.encode(value),
  };

  /// The edited value, and nothing more.
  @override
  String toString() => 'Edited($value)';

  /// Value equality on the edited value.
  @override
  bool operator ==(Object other) => other is Edited<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Nothing was read. Distinct from zero.
final class Absent<T> extends FieldValue<T> {
  const Absent();

  @override
  Object? toJson(FieldCodec<T> codec) => <String, Object?>{'state': 'absent'};

  /// The absent marker.
  @override
  String toString() => 'Absent()';

  /// Absent values of the same field type are equal.
  @override
  bool operator ==(Object other) => other is Absent<T>;

  @override
  int get hashCode => T.hashCode;
}

/// The structured e-invoice route's status for a field its profile does not
/// carry. Never equal to [Absent], never zero.
final class NotInXml<T> extends FieldValue<T> {
  const NotInXml();

  @override
  Object? toJson(FieldCodec<T> codec) => <String, Object?>{
    'state': 'not_in_xml',
  };

  /// The not-in-XML marker.
  @override
  String toString() => 'NotInXml()';

  /// Not-in-XML values of the same field type are equal.
  @override
  bool operator ==(Object other) => other is NotInXml<T>;

  @override
  int get hashCode => T.hashCode;
}
