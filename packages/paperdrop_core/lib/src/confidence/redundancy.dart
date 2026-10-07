/// Exact sums and the one tolerance.
///
/// Requirement served: `validation-confidence` ·
/// `redundancy-checks-on-amounts` — sums of printed amounts are compared for
/// exact equality, and the single one-minor-unit tolerance applies only where
/// a printed tax is compared with `base × rate`.
library;

import '../money/money.dart';
import '../money/rate.dart';

/// Whether [left] + [right] equals [total] exactly in minor units.
///
/// A sum off by even one minor unit fails; there is no tolerance here.
bool sumMatchesTotal(Money left, Money right, Money total) =>
    (left + right) == total;

/// Whether [tax] is within the one tolerance of `base × rate`.
///
/// With `T` the printed tax and `B` the base in minor units and `R` the rate
/// in basis points, the comparison is `| 10000 · T − B · R | ≤ 10000`. This is
/// the only place that inequality appears in `lib/`; every caller goes through
/// this function.
bool taxWithinTolerance(Money tax, Money base, RateBp rate) {
  final printed = BigInt.from(tax.minor) * BigInt.from(10000);
  final product = BigInt.from(base.minor) * BigInt.from(rate.bp);
  final difference = (printed - product).abs();
  return difference <= BigInt.from(10000);
}
