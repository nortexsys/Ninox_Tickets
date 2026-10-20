/// Amount coherence rules for the photo route.
///
/// The two ported photo readers are run unchanged. This file applies the
/// PO's coherence rules to the amounts the readers chose, before those
/// amounts enter consensus:
///
///  1. when gross, net and tax are all equal, the gross is kept and net and
///     tax are dropped;
///  2. a net or tax amount equal to a printed rate is not an amount and is
///     dropped;
///  3. a tax amount equal to the gross is impossible and is dropped;
///  4. when base + tax does not equal the gross and the arithmetic reader has
///     a consistent triple, that triple is preferred.
///
/// A rule only drops or prefers; it never invents a value. A dropped value is
/// absent, never guessed, and a preferred arithmetic triple keeps the derived
/// provenance the photo route already assigns to arithmetic values.
library;

import 'labelled_reader.dart';

/// Where a coherent photo amount came from.
enum PhotoAmountSource {
  /// The labelled reader produced the value.
  labelled,

  /// The arithmetic reader produced the value.
  arithmetic,

  /// No value is present.
  none,
}

/// One photo amount after the coherence rules ran.
class CoherentPhotoAmount {
  /// The amount value, or the absent value.
  final ReceiptValue value;

  /// The reader the [value] came from.
  final PhotoAmountSource source;

  /// Creates a coherent photo amount.
  const CoherentPhotoAmount(this.value, this.source);

  /// Whether an amount is present.
  bool get has => value.has;

  /// The double amount, when present.
  double? get amount => value.value;
}

/// The three photo amounts one pass contributes after the coherence rules.
class CoherentPhotoAmounts {
  /// The net/base amount.
  final CoherentPhotoAmount net;

  /// The tax amount.
  final CoherentPhotoAmount vat;

  /// The gross total.
  final CoherentPhotoAmount gross;

  /// Creates a coherent photo amount triple.
  const CoherentPhotoAmounts({
    required this.net,
    required this.vat,
    required this.gross,
  });
}

/// Applies rules 1-4 to the amounts the readers chose.
///
/// The rules run in proposal order: first the all-equal rule, then the
/// printed-rate rule, then the tax-equals-gross rule, then the arithmetic
/// triple preference. Earlier drops take precedence over the later
/// arithmetic-preference rule, so a dropped amount stays dropped.
CoherentPhotoAmounts applyAmountCoherenceRules({
  required Receipt labelled,
  required Receipt arithmetic,
}) {
  var net = _choose(labelled.net, arithmetic.net);
  var vat = _choose(labelled.vat, arithmetic.vat);
  var gross = _choose(labelled.gross, arithmetic.gross);

  final printedRates = <double>{
    if (labelled.rate != null) labelled.rate!,
    if (arithmetic.rate != null) arithmetic.rate!,
  };

  // Rule 1: three equal figures are one gross, not a breakdown.
  if (net.has &&
      vat.has &&
      gross.has &&
      _sameAmount(net.amount!, vat.amount!) &&
      _sameAmount(net.amount!, gross.amount!)) {
    net = const CoherentPhotoAmount(ReceiptValue.none, PhotoAmountSource.none);
    vat = const CoherentPhotoAmount(ReceiptValue.none, PhotoAmountSource.none);
  }

  // Rule 2: an amount equal to a printed rate is the rate misread as money.
  if (net.has && _equalsPrintedRate(net.amount!, printedRates)) {
    net = const CoherentPhotoAmount(ReceiptValue.none, PhotoAmountSource.none);
  }
  if (vat.has && _equalsPrintedRate(vat.amount!, printedRates)) {
    vat = const CoherentPhotoAmount(ReceiptValue.none, PhotoAmountSource.none);
  }

  // Rule 3: a tax equal to the gross is impossible.
  if (vat.has && gross.has && _sameAmount(vat.amount!, gross.amount!)) {
    vat = const CoherentPhotoAmount(ReceiptValue.none, PhotoAmountSource.none);
  }

  // Rule 4: when the surviving triple does not add up, but the arithmetic
  // reader found one that does, prefer the arithmetic triple.
  if (net.has &&
      vat.has &&
      gross.has &&
      (net.amount! + vat.amount! - gross.amount!).abs() > 0.02 &&
      arithmetic.reconciles == true) {
    net = CoherentPhotoAmount(arithmetic.net, PhotoAmountSource.arithmetic);
    vat = CoherentPhotoAmount(arithmetic.vat, PhotoAmountSource.arithmetic);
    gross = CoherentPhotoAmount(arithmetic.gross, PhotoAmountSource.arithmetic);
  }

  return CoherentPhotoAmounts(net: net, vat: vat, gross: gross);
}

CoherentPhotoAmount _choose(ReceiptValue labelled, ReceiptValue arithmetic) {
  if (labelled.has) {
    return CoherentPhotoAmount(labelled, PhotoAmountSource.labelled);
  }
  if (arithmetic.has) {
    return CoherentPhotoAmount(arithmetic, PhotoAmountSource.arithmetic);
  }
  return const CoherentPhotoAmount(ReceiptValue.none, PhotoAmountSource.none);
}

bool _sameAmount(double a, double b) => (a - b).abs() < 1e-9;

bool _equalsPrintedRate(double amount, Set<double> rates) =>
    rates.any((rate) => _sameAmount(amount, rate));
