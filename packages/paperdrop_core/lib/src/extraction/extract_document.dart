/// Turns recognition passes into one canonical document.
///
/// Requirement served: `extraction-pipeline` ·
/// `pipeline-order-is-fixed`, `consensus-by-majority`,
/// `read-all-printed-quantities-before-deriving` and
/// `multi-page-consolidation`. A pass produces candidates; this module is the
/// orchestrator-owned rule that chooses one value per field, runs consensus
/// before any derivation, and assigns confidence through the shared rules.
library;

import '../confidence/redundancy.dart';
import '../confidence/states.dart';
import '../consensus/consensus.dart';
import '../countries/country_table.dart';
import '../dictionaries/labels.dart';
import '../dictionaries/lookup.dart';
import '../layout/binding.dart';
import '../layout/lines.dart';
import '../layout/positioned_word.dart';
import '../layout/text_page.dart';
import '../model/calendar_date.dart';
import '../model/canonical_document.dart';
import '../model/confidence.dart';
import '../model/field_value.dart';
import '../model/provenance.dart';
import '../money/currency.dart';
import '../money/money.dart';
import '../money/rate.dart';
import '../solver/currency.dart';
import '../solver/negative.dart';
import '../solver/operands.dart';
import '../solver/rate_gate.dart';
import '../solver/solve.dart';

/// One recognition pass: a route label, a pass identifier and its pages.
///
/// The route label is the route the app selected (`pdf-text`, `pdf-ocr`,
/// `pdf-mixed` or `photo-ocr`). All passes of one extraction share the same
/// label, and [extractDocument] rejects a mixed list rather than guessing a
/// metadata value.
class ExtractionPass {
  /// The identifier of this pass, used by consensus as the reader identity.
  final String passId;

  /// The route label this pass belongs to.
  final String routeLabel;

  /// The pages this pass read, in arrival order.
  final List<TextPage> pages;

  /// Creates a recognition pass.
  ExtractionPass({
    required this.passId,
    required this.routeLabel,
    required List<TextPage> pages,
  }) : pages = List.unmodifiable(pages);

  /// A value-only string form.
  @override
  String toString() =>
      'ExtractionPass($passId, $routeLabel, '
      '${pages.length} pages)';

  /// Value equality on pass id, route label and pages.
  @override
  bool operator ==(Object other) =>
      other is ExtractionPass &&
      other.passId == passId &&
      other.routeLabel == routeLabel &&
      _pageListEquals(other.pages, pages);

  @override
  int get hashCode => Object.hash(passId, routeLabel, Object.hashAll(pages));
}

/// Builds one [CanonicalDocument] from recognition [passes].
///
/// For every pass the pages are read in page order. A field found on several
/// pages of one pass contributes a reading only when every page holds the same
/// value; a disagreement yields no reading from that pass, never a guess.
/// Readings then pass through [resolveConsensus], and only operands that
/// survived consensus are handed to the amount solver.
CanonicalDocument extractDocument({
  required List<ExtractionPass> passes,
  required CountryRow country,
  required CountryTable table,
  required String sourceHash,
}) {
  final route = _routeLabel(passes);

  final grossReadings = <Reading<Money>>[];
  final baseReadings = <Reading<Money>>[];
  final taxReadings = <Reading<Money>>[];
  final rateReadings = <Reading<RateBp>>[];
  final currencyReadings = <Reading<CurrencyCode>>[];
  final dateReadings = <Reading<CalendarDate>>[];
  final supplierReadings = <Reading<String>>[];
  final docNumberReadings = <Reading<String>>[];
  final surcharges = <Surcharge>[];

  for (final pass in passes) {
    final pages = [...pass.pages]..sort(_byPageIndex);

    final operands = readOperands(pages, country);
    final negative = applyNegativeContext(
      operands: operands,
      pages: pages,
      country: country,
    );

    _addReadingIfUnanimous<Money>(grossReadings, <Money>[
      for (final operand in negative.kept.gross) operand.amount!,
    ], pass.passId);
    _addReadingIfUnanimous<Money>(baseReadings, <Money>[
      for (final operand in negative.kept.bases) operand.amount!,
    ], pass.passId);
    _addReadingIfUnanimous<Money>(taxReadings, <Money>[
      for (final operand in negative.kept.taxes) operand.amount!,
    ], pass.passId);
    _addReadingIfUnanimous<RateBp>(rateReadings, <RateBp>[
      for (final operand in negative.kept.rates) operand.rate!,
    ], pass.passId);

    final currency = resolveCurrency(
      readCurrencyEvidence(pages, issuerCountry: country.countryCode),
      table,
    );
    if (currency is Present<CurrencyCode>) {
      currencyReadings.add(
        Reading<CurrencyCode>(currency.value, pass.passId, Provenance.read),
      );
    }

    _addNonAmountReadings<CalendarDate>(
      dateReadings,
      pages,
      LabelKind.date,
      ValueKind.date,
      country,
      pass.passId,
      (LabelBinding binding) => binding.date,
    );
    _addNonAmountReadings<String>(
      supplierReadings,
      pages,
      LabelKind.supplier,
      ValueKind.documentNumber,
      country,
      pass.passId,
      (LabelBinding binding) => binding.documentNumber,
    );
    _addNonAmountReadings<String>(
      docNumberReadings,
      pages,
      LabelKind.docNumber,
      ValueKind.documentNumber,
      country,
      pass.passId,
      (LabelBinding binding) => binding.documentNumber,
    );

    surcharges.addAll(negative.surcharges);
  }

  final grossConsensus = resolveConsensus<Money>(grossReadings);
  final baseConsensus = resolveConsensus<Money>(baseReadings);
  final taxConsensus = resolveConsensus<Money>(taxReadings);
  final rateConsensus = resolveConsensus<RateBp>(rateReadings);

  final grossDisputed =
      grossReadings.isNotEmpty && grossConsensus is NoConsensus<Money>;
  final baseDisputed =
      baseReadings.isNotEmpty && baseConsensus is NoConsensus<Money>;
  final taxDisputed =
      taxReadings.isNotEmpty && taxConsensus is NoConsensus<Money>;

  final FieldValue<Money> grossTotal;
  final FieldValue<Money> netTotal;
  final FieldValue<Money> taxTotal;
  final List<TaxSlot> taxSlots;

  if (grossDisputed || baseDisputed || taxDisputed) {
    // A disputed operand is never handed to the solver: the disputed field
    // stays empty and the surviving operands are kept as read values only.
    grossTotal = _readAmountField(
      _consensusValue<Money>(grossConsensus),
      grossConsensus,
    );
    netTotal = _readAmountField(
      _consensusValue<Money>(baseConsensus),
      baseConsensus,
    );
    taxTotal = _readAmountField(
      _consensusValue<Money>(taxConsensus),
      taxConsensus,
    );
    taxSlots = const <TaxSlot>[];
  } else {
    final grossValue = _consensusValue<Money>(grossConsensus);
    final baseValue = _consensusValue<Money>(baseConsensus);
    final taxValue = _consensusValue<Money>(taxConsensus);
    final rateValue = _consensusValue<RateBp>(rateConsensus);

    final grosses = grossValue == null
        ? const <ReadOperand>[]
        : <ReadOperand>[_amountOperand(OperandRole.gross, grossValue)];
    final bases = baseValue == null
        ? const <ReadOperand>[]
        : <ReadOperand>[_amountOperand(OperandRole.base, baseValue)];
    final taxes = taxValue == null
        ? const <ReadOperand>[]
        : <ReadOperand>[_amountOperand(OperandRole.tax, taxValue)];
    final rates = rateValue == null
        ? const <ReadOperand>[]
        : <ReadOperand>[_rateOperand(rateValue)];

    final gate = gatePrintedRates(rates, country);
    final breakdown = solveBreakdown(
      bases: bases,
      taxes: taxes,
      grosses: grosses,
      admittedRates: gate.admitted,
    );

    final rawTax = taxes.isEmpty ? breakdown.tax : _sumReadTaxes(taxes);
    final check = _amountCheck(breakdown.gross, breakdown.base, rawTax);

    grossTotal = _finalizeAmount(breakdown.gross, grossConsensus, check);
    netTotal = _finalizeAmount(breakdown.base, baseConsensus, check);
    taxTotal = _finalizeAmount(rawTax, taxConsensus, check);
    taxSlots = buildTaxSlots(
      bases: bases,
      taxes: taxes,
      grosses: grosses,
      admittedRates: gate.admitted,
      country: country,
    );
  }

  final docDate = _nonAmountField<CalendarDate>(dateReadings, FieldKind.other);
  final supplierName = _nonAmountField<String>(
    supplierReadings,
    FieldKind.supplierName,
  );
  final docNumber = _nonAmountField<String>(
    docNumberReadings,
    FieldKind.docNumber,
  );
  final currency = _currencyField(currencyReadings);

  final reviewFields = <FieldValue<Object?>>[
    docDate,
    supplierName,
    docNumber,
    grossTotal,
    currency,
    netTotal,
    taxTotal,
  ];

  return CanonicalDocument(
    docDate: docDate,
    supplierName: supplierName,
    docNumber: docNumber,
    grossTotal: grossTotal,
    currency: currency,
    netTotal: netTotal,
    taxTotal: taxTotal,
    taxSlots: taxSlots,
    surcharges: _uniqueSurcharges(surcharges),
    needsReview: _needsReview(reviewFields),
    recognitionEngine: route,
    sourceHash: sourceHash,
  );
}

String _routeLabel(List<ExtractionPass> passes) {
  if (passes.isEmpty) {
    return '';
  }

  final route = passes.first.routeLabel;
  for (final pass in passes.skip(1)) {
    if (pass.routeLabel != route) {
      throw ArgumentError.value(
        passes,
        'passes',
        'all passes must share one route label',
      );
    }
  }
  return route;
}

void _addReadingIfUnanimous<T>(
  List<Reading<T>> readings,
  List<T> values,
  String passId,
) {
  final value = _unanimousValue<T>(values);
  if (value == null) {
    return;
  }
  readings.add(Reading<T>(value, passId, Provenance.read));
}

T? _unanimousValue<T>(List<T> values) {
  if (values.isEmpty) {
    return null;
  }
  final first = values.first;
  for (final value in values.skip(1)) {
    if (value != first) {
      return null;
    }
  }
  return first;
}

void _addNonAmountReadings<T>(
  List<Reading<T>> readings,
  Iterable<TextPage> pages,
  LabelKind labelKind,
  ValueKind valueKind,
  CountryRow country,
  String passId,
  T? Function(LabelBinding binding) value,
) {
  final bindings = _bindingsFor(pages, labelKind, valueKind, country);
  if (bindings.isEmpty) {
    return;
  }

  final first = value(bindings.first);
  if (first == null) {
    return;
  }
  for (final binding in bindings.skip(1)) {
    if (value(binding) != first) {
      return;
    }
  }
  readings.add(Reading<T>(first, passId, Provenance.read));
}

List<LabelBinding> _bindingsFor(
  Iterable<TextPage> pages,
  LabelKind labelKind,
  ValueKind valueKind,
  CountryRow country,
) {
  final bindings = <LabelBinding>[];
  for (final page in pages) {
    for (final line in groupIntoLines(page)) {
      for (final match in findTerms(line.text)) {
        if (match.kind != labelKind) {
          continue;
        }
        final words = _wordsCoveredBy(line, match);
        if (words.isEmpty) {
          continue;
        }
        final binding = bindLabel(
          LabelOccurrence(match, words),
          page,
          valueKind,
          country,
        );
        if (binding != null) {
          bindings.add(binding);
        }
      }
    }
  }
  return bindings;
}

List<PositionedWord> _wordsCoveredBy(LayoutLine line, TermMatch match) {
  final covered = <PositionedWord>[];
  var cursor = 0;
  for (final word in line.words) {
    final start = cursor;
    final end = cursor + word.text.length;
    if (start < match.end && end > match.start) {
      covered.add(word);
    }
    cursor = end + 1;
  }
  return covered;
}

T? _consensusValue<T>(ConsensusResult<T> consensus) => switch (consensus) {
  Agreed<T>(:final value) => value,
  Single<T>(:final value) => value,
  NoConsensus<T>() => null,
};

FieldValue<T> _nonAmountField<T>(List<Reading<T>> readings, FieldKind kind) {
  final consensus = resolveConsensus<T>(readings);
  return switch (consensus) {
    Agreed<T>(:final value) => Present<T>(
      value,
      Provenance.read,
      _finalizeConfidence(agreed: true, kind: kind, check: CheckOutcome.passed),
    ),
    Single<T>(:final value) => Present<T>(
      value,
      Provenance.read,
      _finalizeConfidence(agreed: false, kind: kind),
    ),
    NoConsensus<T>() => Absent<T>(),
  };
}

FieldValue<CurrencyCode> _currencyField(List<Reading<CurrencyCode>> readings) {
  final consensus = resolveConsensus<CurrencyCode>(readings);
  return switch (consensus) {
    Agreed<CurrencyCode>(:final value) => Present<CurrencyCode>(
      value,
      Provenance.read,
      _finalizeConfidence(
        agreed: true,
        kind: FieldKind.currency,
        check: CheckOutcome.passed,
      ),
    ),
    Single<CurrencyCode>(:final value) => Present<CurrencyCode>(
      value,
      Provenance.read,
      _finalizeConfidence(agreed: false, kind: FieldKind.currency),
    ),
    NoConsensus<CurrencyCode>() => const Absent<CurrencyCode>(),
  };
}

ConfidenceState _finalizeConfidence({
  required bool agreed,
  required FieldKind kind,
  CheckOutcome check = CheckOutcome.none,
}) {
  final state = assignConfidence(kind: kind, check: check);
  if (state == ConfidenceState.green && !agreed) {
    // A single pass is a `Single`, never an `Agreed`; confidence is capped
    // below green (consensus.dart documents this distinction).
    return ConfidenceState.amber;
  }
  return state;
}

ReadOperand _amountOperand(OperandRole role, Money value) => ReadOperand.amount(
  role: role,
  amount: value,
  words: const <PositionedWord>[],
  pageIndex: 0,
);

ReadOperand _rateOperand(RateBp value) => ReadOperand.rate(
  rate: value,
  words: const <PositionedWord>[],
  pageIndex: 0,
);

CheckOutcome _amountCheck(
  FieldValue<Money> gross,
  FieldValue<Money> base,
  FieldValue<Money> tax,
) {
  if (gross is! Present<Money> ||
      base is! Present<Money> ||
      tax is! Present<Money>) {
    return CheckOutcome.none;
  }
  if (gross.provenance != Provenance.read ||
      base.provenance != Provenance.read ||
      tax.provenance != Provenance.read) {
    return CheckOutcome.none;
  }
  return checkOutcome(
    arithmeticPassed: sumMatchesTotal(base.value, tax.value, gross.value),
    operands: const <Provenance>[
      Provenance.read,
      Provenance.read,
      Provenance.read,
    ],
  );
}

FieldValue<Money> _finalizeAmount(
  FieldValue<Money> value,
  ConsensusResult<Money> consensus,
  CheckOutcome check,
) {
  if (value is! Present<Money>) {
    return value;
  }
  return Present<Money>(
    value.value,
    value.provenance,
    _finalizeConfidence(
      agreed: consensus is Agreed<Money>,
      kind: FieldKind.amount,
      check: check,
    ),
    source: value.source,
  );
}

FieldValue<Money> _readAmountField(
  Money? value,
  ConsensusResult<Money> consensus,
) {
  if (value == null) {
    return const Absent<Money>();
  }
  return Present<Money>(
    value,
    Provenance.read,
    _finalizeConfidence(
      agreed: consensus is Agreed<Money>,
      kind: FieldKind.amount,
    ),
  );
}

FieldValue<Money> _sumReadTaxes(List<ReadOperand> taxes) {
  var sum = taxes.first.amount!;
  for (final tax in taxes.skip(1)) {
    sum = sum + tax.amount!;
  }
  return Present<Money>(sum, Provenance.read, ConfidenceState.amber);
}

List<Surcharge> _uniqueSurcharges(List<Surcharge> surcharges) {
  final unique = <Surcharge>[];
  for (final surcharge in surcharges) {
    if (!unique.contains(surcharge)) {
      unique.add(surcharge);
    }
  }
  return List<Surcharge>.unmodifiable(unique);
}

bool _needsReview(List<FieldValue<Object?>> fields) {
  var sawPresent = false;
  for (final field in fields) {
    if (field is Present<Object?>) {
      sawPresent = true;
      if (field.confidence != ConfidenceState.green) {
        return true;
      }
    }
  }
  return !sawPresent;
}

int _byPageIndex(TextPage left, TextPage right) =>
    left.index.compareTo(right.index);

bool _pageListEquals(List<TextPage> left, List<TextPage> right) {
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
