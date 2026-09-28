/// Money as an integer in its currency's minor unit, plus exact rate products.
///
/// Requirement served: BR-09 (`money-as-integer-minor-units`). Amounts are
/// bounded to `|minor| <= 10^15`; every operation throws [MoneyRangeError]
/// outside that bound. There is no rounding function anywhere in this change.
library;

import 'currency.dart';
import 'rate.dart';

/// Thrown when two money values in different currencies are combined or
/// compared. There is no implicit conversion anywhere.
class CurrencyMismatchError extends ArgumentError {
  /// Creates a currency mismatch error with [message].
  CurrencyMismatchError(super.message);
}

/// Thrown when a money value falls outside the representable range.
class MoneyRangeError extends ArgumentError {
  /// Creates a money range error with [message].
  MoneyRangeError(super.message);
}

/// The exact distance between an [ExactAmount] and a [Money] value.
///
/// The distance is kept as the rational `numerator / denominator`, where the
/// denominator is [ExactAmount.denominator]. It never passes through a
/// floating-point value.
class ExactDistance {
  /// The numerator of the exact distance, already reduced to a non-negative
  /// magnitude.
  final BigInt numerator;

  /// The denominator of the exact distance; always 10000.
  final int denominator;

  /// Creates an exact distance from its [numerator] and [denominator].
  ExactDistance(this.numerator, this.denominator);

  /// Whether the distance is exactly zero minor units.
  bool get isZero => numerator == BigInt.zero;

  /// The rational value, as `numerator/denominator`.
  @override
  String toString() => '$numerator/$denominator';

  /// Value equality on numerator and denominator.
  @override
  bool operator ==(Object other) =>
      other is ExactDistance &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);
}

/// An exact product `minor x basis points / 10000` in a currency.
///
/// It is produced by [Money.timesRate] and exists so callers can compare and
/// measure without choosing a rounding policy. Rounding is specified elsewhere
/// (FR-VAL-006) and is deliberately absent here.
class ExactAmount {
  /// The numerator `minor x basis points`.
  final BigInt numerator;

  /// The currency of the amount the product was computed from.
  final CurrencyCode currency;

  /// The fixed denominator of every exact product: 10000.
  int get denominator => 10000;

  ExactAmount._(this.numerator, this.currency);

  /// Compares this exact product to a whole [money] value.
  ///
  /// Returns a negative value, zero, or a positive value when this product is
  /// respectively less than, equal to, or greater than [money].
  int compareToMoney(Money money) {
    _requireSameCurrency(currency, money.currency);
    final other = BigInt.from(money.minor) * BigInt.from(denominator);
    return numerator.compareTo(other);
  }

  /// The exact distance to [money] as a rational `numerator / 10000`.
  ExactDistance distanceInMinorUnits(Money money) {
    _requireSameCurrency(currency, money.currency);
    final other = BigInt.from(money.minor) * BigInt.from(denominator);
    final difference = (numerator - other).abs();
    return ExactDistance(difference, denominator);
  }

  /// The exact product, as `numerator/denominator currency`.
  @override
  String toString() => '$numerator/$denominator ${currency.code}';

  /// Value equality on numerator and currency.
  @override
  bool operator ==(Object other) =>
      other is ExactAmount &&
      other.numerator == numerator &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(numerator, currency);
}

/// An amount of money as `(int minor, CurrencyCode currency)`.
class Money implements Comparable<Money> {
  /// The inclusive bound on `minor.abs()`.
  static const int maxMinorUnits = 1000000000000000;

  /// The amount in the currency's minor unit.
  final int minor;

  /// The currency the amount is expressed in.
  final CurrencyCode currency;

  static final RegExp _decimalPattern = RegExp(r'^-?([0-9]+)(?:\.([0-9]+))?$');

  /// Creates an amount in [currency]'s minor unit, bounded to [maxMinorUnits].
  Money(this.minor, this.currency) {
    if (minor < -maxMinorUnits || minor > maxMinorUnits) {
      throw MoneyRangeError('minor units out of range: $minor');
    }
  }

  static int _pow10(int exponent) {
    const powers = <int>[1, 10, 100, 1000, 10000];
    return powers[exponent];
  }

  /// Parses the canonical decimal form `-?[0-9]+(\.[0-9]+)?` in [currency].
  ///
  /// More fractional digits than the currency's exponent are rejected; the
  /// parser never rounds. Locale formats are not this function's job.
  static Money parseDecimal(String text, CurrencyCode currency) {
    final match = _decimalPattern.firstMatch(text);
    if (match == null) {
      throw FormatException('not a canonical decimal amount: $text');
    }

    final wholeText = match.group(1)!;
    final fractionText = match.group(2) ?? '';
    if (fractionText.length > currency.exponent) {
      throw FormatException(
        'more fractional digits than the currency exponent: $text',
      );
    }

    final factor = BigInt.from(_pow10(currency.exponent));
    final whole = BigInt.parse(wholeText);
    final fraction = fractionText.isEmpty
        ? BigInt.zero
        : BigInt.parse(fractionText.padRight(currency.exponent, '0'));
    final sign = text.startsWith('-') ? BigInt.from(-1) : BigInt.one;
    final minor = (whole * factor + fraction) * sign;

    if (minor < BigInt.from(-maxMinorUnits) ||
        minor > BigInt.from(maxMinorUnits)) {
      throw MoneyRangeError('minor units out of range: $minor');
    }

    return Money(minor.toInt(), currency);
  }

  /// Renders the canonical text form of this amount, for logs and tests only.
  ///
  /// This value is never used to compute.
  String toDecimalString() {
    final exponent = currency.exponent;
    if (exponent == 0) {
      return '$minor';
    }

    final sign = minor < 0 ? '-' : '';
    final absolute = minor.abs();
    final factor = _pow10(exponent);
    final major = absolute ~/ factor;
    final fraction = (absolute % factor).toString().padLeft(exponent, '0');
    return '$sign$major.$fraction';
  }

  /// Adds two amounts in the same currency.
  Money operator +(Money other) {
    _requireSameCurrency(currency, other.currency);
    return Money(minor + other.minor, currency);
  }

  /// Subtracts two amounts in the same currency.
  Money operator -(Money other) {
    _requireSameCurrency(currency, other.currency);
    return Money(minor - other.minor, currency);
  }

  /// Negates this amount, keeping its currency.
  Money operator -() => Money(-minor, currency);

  @override
  int compareTo(Money other) {
    _requireSameCurrency(currency, other.currency);
    return minor.compareTo(other.minor);
  }

  /// Whether this amount is exactly zero.
  bool get isZero => minor == 0;

  /// Whether this amount is negative.
  bool get isNegative => minor < 0;

  /// Multiplies this amount by [rate], returning the exact rational product.
  ///
  /// The numerator is `minor x basis points` over the fixed denominator 10000.
  ExactAmount timesRate(RateBp rate) =>
      ExactAmount._(BigInt.from(minor) * BigInt.from(rate.bp), currency);

  /// The amount as `minor currency`, and nothing more.
  @override
  String toString() => '$minor ${currency.code}';

  /// Value equality on minor units and currency.
  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  /// Serialises this amount as `{"minor": int, "currency": "EUR"}`.
  Map<String, Object?> toJson() => <String, Object?>{
    'minor': minor,
    'currency': currency.toJson(),
  };

  /// Reads a money value from its JSON object.
  static Money fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw FormatException('money JSON must be an object');
    }

    final minor = json['minor'];
    final currency = json['currency'];
    if (minor is! int || currency is! String) {
      throw FormatException('money JSON must hold an integer minor and a code');
    }

    final parsedCurrency = CurrencyCode.parse(currency);
    if (parsedCurrency == null) {
      throw FormatException('unknown currency in money JSON: $currency');
    }

    return Money(minor, parsedCurrency);
  }
}

void _requireSameCurrency(CurrencyCode left, CurrencyCode right) {
  if (left != right) {
    throw CurrencyMismatchError(
      'currency mismatch: ${left.code} and ${right.code}',
    );
  }
}
