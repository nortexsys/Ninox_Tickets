/// The amount solver: match independent candidates, derive by identity last.
///
/// Requirement served: `extraction-pipeline` ·
/// `read-all-printed-quantities-before-deriving`,
/// `derive-by-identity-never-invent-a-rate` and the producing half of
/// `provenance-on-every-value`. Matching comes before derivation, and a
/// derived value is computed only from read values with a printed, admitted
/// rate.
library;

import '../countries/country_table.dart';
import '../layout/text_page.dart';
import '../model/canonical_document.dart';
import '../model/confidence.dart';
import '../model/field_value.dart';
import '../model/provenance.dart';
import '../money/currency.dart';
import '../money/money.dart';
import '../money/rate.dart';
import 'currency.dart';
import 'negative.dart';
import 'operands.dart';
import 'rate_gate.dart';

/// The solver's answer for the base, tax and gross fields.
class BreakdownSolution {
  /// The base amount, read, derived or absent.
  final FieldValue<Money> base;

  /// The tax amount, read, derived or absent.
  final FieldValue<Money> tax;

  /// The gross total, read, derived or absent.
  final FieldValue<Money> gross;

  /// Creates a breakdown solution.
  const BreakdownSolution({
    required this.base,
    required this.tax,
    required this.gross,
  });

  /// A value-only string form.
  @override
  String toString() =>
      'BreakdownSolution(base: $base, tax: $tax, gross: $gross)';

  /// Value equality on the three field values.
  @override
  bool operator ==(Object other) =>
      other is BreakdownSolution &&
      other.base == base &&
      other.tax == tax &&
      other.gross == gross;

  @override
  int get hashCode => Object.hash(base, tax, gross);
}

/// The amount solver's result for the fields it touches.
class SolverResult {
  /// The document currency, resolved from the document's own evidence.
  final FieldValue<CurrencyCode> currency;

  /// The gross total.
  final FieldValue<Money> grossTotal;

  /// The net total (taxable base).
  final FieldValue<Money> netTotal;

  /// The tax total.
  final FieldValue<Money> taxTotal;

  /// Surcharge-like amounts captured by negative context.
  final List<Surcharge> surcharges;

  /// Printed rates the legal-rate gate discarded.
  final List<ReadOperand> discardedRates;

  /// Figures negative context suppressed, for the tests.
  final List<ReadOperand> suppressedFigures;

  /// Creates a solver result.
  const SolverResult({
    required this.currency,
    required this.grossTotal,
    required this.netTotal,
    required this.taxTotal,
    required this.surcharges,
    required this.discardedRates,
    required this.suppressedFigures,
  });

  /// A value-only string form naming the amounts.
  @override
  String toString() =>
      'SolverResult(currency: $currency, gross: $grossTotal, '
      'net: $netTotal, tax: $taxTotal)';

  /// Value equality on every field.
  @override
  bool operator ==(Object other) =>
      other is SolverResult &&
      other.currency == currency &&
      other.grossTotal == grossTotal &&
      other.netTotal == netTotal &&
      other.taxTotal == taxTotal &&
      _surchargeListEquals(other.surcharges, surcharges) &&
      _operandListEquals(other.discardedRates, discardedRates) &&
      _operandListEquals(other.suppressedFigures, suppressedFigures);

  @override
  int get hashCode => Object.hash(
    currency,
    grossTotal,
    netTotal,
    taxTotal,
    Object.hashAll(surcharges),
    Object.hashAll(discardedRates),
    Object.hashAll(suppressedFigures),
  );
}

/// Runs the amount solver over [pages] under [country] and [table].
///
/// The pipeline order is fixed: read operands, resolve currency, apply
/// negative context, gate printed rates, then match and derive.
SolverResult solveAmounts({
  required Iterable<TextPage> pages,
  required CountryRow country,
  required CountryTable table,
}) {
  final operands = readOperands(pages, country);
  final evidence = readCurrencyEvidence(
    pages,
    issuerCountry: country.countryCode,
  );
  final currency = resolveCurrency(evidence, table);
  final negative = applyNegativeContext(
    operands: operands,
    pages: pages,
    country: country,
  );
  final gate = gatePrintedRates(negative.kept.rates, country);
  final breakdown = solveBreakdown(
    bases: negative.kept.bases,
    taxes: negative.kept.taxes,
    grosses: negative.kept.gross,
    admittedRates: gate.admitted,
  );

  return SolverResult(
    currency: currency,
    grossTotal: breakdown.gross,
    netTotal: breakdown.base,
    taxTotal: breakdown.tax,
    surcharges: negative.surcharges,
    discardedRates: gate.discarded,
    suppressedFigures: negative.suppressed,
  );
}

/// Matches independent candidates, then derives by identity if matching fails.
///
/// [bases], [taxes] and [grosses] are the read amount operands;
/// [admittedRates] are the printed rates the legal-rate gate admitted. A
/// triple is accepted when `base + tax == gross` exactly and, when an admitted
/// rate was printed, the tax is within the one tolerance of `base × rate`.
BreakdownSolution solveBreakdown({
  required List<ReadOperand> bases,
  required List<ReadOperand> taxes,
  required List<ReadOperand> grosses,
  required List<ReadOperand> admittedRates,
}) {
  final accepted = _acceptedTriples(bases, taxes, grosses, admittedRates);

  if (accepted.length == 1) {
    final triple = accepted.single;
    return BreakdownSolution(
      base: _presentRead(triple.base),
      tax: _presentRead(triple.tax),
      gross: _presentRead(triple.gross),
    );
  }

  if (accepted.length > 1) {
    return const BreakdownSolution(
      base: Absent<Money>(),
      tax: Absent<Money>(),
      gross: Absent<Money>(),
    );
  }

  return _deriveByIdentity(bases, taxes, grosses, admittedRates);
}

class _Triple {
  final Money base;
  final Money tax;
  final Money gross;

  const _Triple(this.base, this.tax, this.gross);

  @override
  bool operator ==(Object other) =>
      other is _Triple &&
      other.base == base &&
      other.tax == tax &&
      other.gross == gross;

  @override
  int get hashCode => Object.hash(base, tax, gross);
}

List<_Triple> _acceptedTriples(
  List<ReadOperand> bases,
  List<ReadOperand> taxes,
  List<ReadOperand> grosses,
  List<ReadOperand> admittedRates,
) {
  final seen = <_Triple>{};
  final accepted = <_Triple>[];

  for (final base in bases) {
    for (final tax in taxes) {
      for (final gross in grosses) {
        final triple = _Triple(base.amount!, tax.amount!, gross.amount!);
        if (!seen.add(triple)) {
          continue;
        }
        if (_tripleAccepted(triple, admittedRates)) {
          accepted.add(triple);
        }
      }
    }
  }

  return accepted;
}

bool _tripleAccepted(_Triple triple, List<ReadOperand> admittedRates) {
  if ((triple.base + triple.tax) != triple.gross) {
    return false;
  }
  if (admittedRates.isEmpty) {
    return true;
  }
  return admittedRates.any(
    (ReadOperand operand) =>
        _taxWithinTolerance(triple.tax, triple.base, operand.rate!),
  );
}

BreakdownSolution _deriveByIdentity(
  List<ReadOperand> bases,
  List<ReadOperand> taxes,
  List<ReadOperand> grosses,
  List<ReadOperand> admittedRates,
) {
  if (admittedRates.isEmpty) {
    return _emptyBreakdown();
  }

  if (bases.length == 1 && taxes.length == 1 && grosses.isEmpty) {
    final base = bases.single.amount!;
    final tax = taxes.single.amount!;
    if (_rateAgrees(tax, base, admittedRates)) {
      return BreakdownSolution(
        base: _presentRead(base),
        tax: _presentRead(tax),
        gross: _presentDerived(base + tax),
      );
    }
  }

  if (bases.length == 1 && grosses.length == 1 && taxes.isEmpty) {
    final base = bases.single.amount!;
    final gross = grosses.single.amount!;
    final tax = gross - base;
    if (_rateAgrees(tax, base, admittedRates)) {
      return BreakdownSolution(
        base: _presentRead(base),
        tax: _presentDerived(tax),
        gross: _presentRead(gross),
      );
    }
  }

  if (taxes.length == 1 && grosses.length == 1 && bases.isEmpty) {
    final tax = taxes.single.amount!;
    final gross = grosses.single.amount!;
    final base = gross - tax;
    if (_rateAgrees(tax, base, admittedRates)) {
      return BreakdownSolution(
        base: _presentDerived(base),
        tax: _presentRead(tax),
        gross: _presentRead(gross),
      );
    }
  }

  return _emptyBreakdown();
}

bool _rateAgrees(Money tax, Money base, List<ReadOperand> admittedRates) =>
    admittedRates.any(
      (ReadOperand operand) => _taxWithinTolerance(tax, base, operand.rate!),
    );

BreakdownSolution _emptyBreakdown() => const BreakdownSolution(
  base: Absent<Money>(),
  tax: Absent<Money>(),
  gross: Absent<Money>(),
);

FieldValue<Money> _presentRead(Money value) =>
    Present<Money>(value, Provenance.read, ConfidenceState.amber);

FieldValue<Money> _presentDerived(Money value) =>
    Present<Money>(value, Provenance.derived, ConfidenceState.amber);

bool _taxWithinTolerance(Money tax, Money base, RateBp rate) {
  final printed = BigInt.from(tax.minor) * BigInt.from(10000);
  final product = BigInt.from(base.minor) * BigInt.from(rate.bp);
  final difference = (printed - product).abs();
  return difference <= BigInt.from(10000);
}

bool _operandListEquals(List<ReadOperand> left, List<ReadOperand> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

bool _surchargeListEquals(List<Surcharge> left, List<Surcharge> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}
