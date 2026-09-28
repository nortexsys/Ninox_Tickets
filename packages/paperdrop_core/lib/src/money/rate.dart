/// A tax rate expressed exactly as an integer number of basis points.
///
/// Requirement served: BR-09 (`money-as-integer-minor-units`) — every tax rate
/// is an integer in basis points, never a floating-point value.
library;

class RateBp {
  /// The largest representable rate: 100 %, or 10000 basis points.
  static const int maxBasisPoints = 10000;

  /// The rate in basis points, from 0 to [maxBasisPoints] inclusive.
  final int bp;

  /// Creates a rate from an integer number of basis points.
  ///
  /// A rate below 0 or above 100 % is rejected: a tax rate above 100 % is not a
  /// value the model admits.
  RateBp(this.bp) {
    if (bp < 0 || bp > maxBasisPoints) {
      throw ArgumentError.value(
        bp,
        'bp',
        'must be between 0 and $maxBasisPoints',
      );
    }
  }

  static final RegExp _percentPattern = RegExp(r'^([0-9]+)(?:\.([0-9]+))?$');

  /// Parses a canonical percentage text such as `'21'`, `'5.5'` or `'2.75'`.
  ///
  /// A percentage with more than two fractional digits is not a basis-point
  /// value and is rejected. Locale formats (`5,5`) are rejected as well.
  static RateBp parsePercent(String text) {
    final match = _percentPattern.firstMatch(text);
    if (match == null) {
      throw FormatException('not a canonical percentage: $text');
    }

    final whole = match.group(1)!;
    final fraction = match.group(2) ?? '';
    if (fraction.length > 2) {
      throw FormatException('more than two fractional digits: $text');
    }

    final wholeBp = BigInt.parse(whole) * BigInt.from(100);
    final fractionBp = fraction.isEmpty
        ? BigInt.zero
        : BigInt.parse(fraction.padRight(2, '0'));
    final total = wholeBp + fractionBp;

    if (total > BigInt.from(maxBasisPoints)) {
      throw ArgumentError.value(text, 'text', 'rate is above 100 %');
    }

    return RateBp(total.toInt());
  }

  /// The basis-point value, as the value itself.
  @override
  String toString() => '$bp';

  /// Value equality on basis points.
  @override
  bool operator ==(Object other) => other is RateBp && other.bp == bp;

  @override
  int get hashCode => bp.hashCode;

  /// Serialises this rate as an integer number of basis points.
  int toJson() => bp;

  /// Reads a rate from an integer number of basis points.
  static RateBp fromJson(Object? json) => RateBp(json as int);
}
