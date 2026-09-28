/// The three-state field value every canonical field carries.
///
/// Requirement served: FR-EXT-011 (`provenance-on-every-value`) — an untagged
/// value cannot be built, and absent is distinct from zero and from
/// `not_in_xml` (BR-13, FR-EXT-003).
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
  final Object? Function(T value) encode;
  final T Function(Object? json) decode;

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

/// A field value: either [Present], [Absent] or [NotInXml].
sealed class FieldValue<T> {
  const FieldValue();

  /// Serialises this field value using [codec] for the inner value.
  Object? toJson(FieldCodec<T> codec);

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
          source: ValueSource.fromJson(json['source']),
          edited: json['edited'] == true,
        );
      case 'absent':
        return Absent<T>();
      case 'not_in_xml':
        return NotInXml<T>();
      default:
        throw FormatException('unknown field value state: ${json['state']}');
    }
  }
}

/// A value that was read, derived, repaired or taken from XML.
final class Present<T> extends FieldValue<T> {
  final T value;
  final Provenance provenance;
  final ConfidenceState confidence;
  final ValueSource source;
  final bool edited;

  const Present(
    this.value,
    this.provenance,
    this.confidence, {
    this.source = ValueSource.document,
    this.edited = false,
  });

  /// Returns a [Present] with [value] recorded as a user edit.
  ///
  /// The original provenance and confidence are kept. Editing never re-imposes
  /// a colour, and which provenance an edited value carries is not specified in
  /// this change.
  Present<T> copyWithEdit(T value) => Present<T>(
    value,
    provenance,
    confidence,
    source: ValueSource.user,
    edited: true,
  );

  @override
  Object? toJson(FieldCodec<T> codec) => <String, Object?>{
    'state': 'present',
    'value': codec.encode(value),
    'provenance': provenance.toJson(),
    'confidence': confidence.toJson(),
    'source': source.toJson(),
    'edited': edited,
  };

  @override
  String toString() =>
      'Present($value, ${provenance.wireName}, ${confidence.name}, '
      'source: ${source.name}, edited: $edited)';

  @override
  bool operator ==(Object other) =>
      other is Present<T> &&
      other.value == value &&
      other.provenance == provenance &&
      other.confidence == confidence &&
      other.source == source &&
      other.edited == edited;

  @override
  int get hashCode =>
      Object.hash(value, provenance, confidence, source, edited);
}

/// Nothing was read. Distinct from zero.
final class Absent<T> extends FieldValue<T> {
  const Absent();

  @override
  Object? toJson(FieldCodec<T> codec) => <String, Object?>{'state': 'absent'};

  @override
  String toString() => 'Absent()';

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

  @override
  String toString() => 'NotInXml()';

  @override
  bool operator ==(Object other) => other is NotInXml<T>;

  @override
  int get hashCode => T.hashCode;
}
