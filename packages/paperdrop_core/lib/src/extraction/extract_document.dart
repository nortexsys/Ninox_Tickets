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
import '../format/date.dart';
import '../format/decimal.dart';
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
  required CountryRow? country,
  required CountryTable table,
  required String sourceHash,
}) {
  final route = _routeLabel(passes);
  final textLayerReading = route == 'pdf-text';

  final DecimalConvention? decimalConvention;
  final DateOrder? dateOrder;
  final CurrencyCode? documentCurrency;
  if (country == null) {
    final allPages = <TextPage>[for (final pass in passes) ...pass.pages];
    final printedTokens = <String>[
      for (final page in allPages)
        for (final word in page.words) word.text,
    ];
    decimalConvention = inferDecimalConvention(printedTokens);
    dateOrder = inferDateOrder(printedTokens);
    documentCurrency = _resolveUniversalCurrency(allPages, table);
  } else {
    decimalConvention = country.decimalConvention;
    dateOrder = country.dateOrder;
    documentCurrency = country.currency;
  }

  final grossReadings = <Reading<Money>>[];
  final baseReadings = <Reading<Money>>[];
  final taxReadings = <Reading<Money>>[];
  final rateReadings = <Reading<RateBp>>[];
  final currencyReadings = <Reading<CurrencyCode>>[];
  final dateReadings = <Reading<CalendarDate>>[];
  final supplierReadings = <Reading<String>>[];
  final docNumberReadings = <Reading<String>>[];
  final surcharges = <Surcharge>[];

  // A text-layer pass is deterministic, so it can print several candidates for
  // one role (`Total líneas`, `TOTAL FACTURA` and `TOTAL A PAGAR`). They are
  // all read and handed to the amount solver, which matches the arithmetic
  // identity; collapsing them to one unanimous value first is what made the
  // solver see no gross total at all.
  final textGrossOperands = <ReadOperand>[];
  final textBaseOperands = <ReadOperand>[];
  final textTaxOperands = <ReadOperand>[];
  final textRateOperands = <ReadOperand>[];

  for (final pass in passes) {
    final pages = [...pass.pages]..sort(_byPageIndex);

    final operands = readOperands(
      pages,
      country,
      decimalConvention: decimalConvention,
      currency: documentCurrency,
    );
    final negative = applyNegativeContext(
      operands: operands,
      pages: pages,
      country: country,
      decimalConvention: decimalConvention,
      currency: documentCurrency,
    );

    if (textLayerReading) {
      textGrossOperands.addAll(negative.kept.gross);
      textBaseOperands.addAll(negative.kept.bases);
      textTaxOperands.addAll(negative.kept.taxes);
      textRateOperands.addAll(negative.kept.rates);
    } else {
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
    }

    final currency = resolveCurrency(
      readCurrencyEvidence(pages, issuerCountry: country?.countryCode),
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
      dateOrder,
      pass.passId,
      (LabelBinding binding) => binding.date,
    );
    _addNonAmountReadings<String>(
      supplierReadings,
      pages,
      LabelKind.supplier,
      ValueKind.documentNumber,
      country,
      dateOrder,
      pass.passId,
      (LabelBinding binding) => binding.documentNumber,
    );
    _addNonAmountReadings<String>(
      docNumberReadings,
      pages,
      LabelKind.docNumber,
      ValueKind.documentNumber,
      country,
      dateOrder,
      pass.passId,
      (LabelBinding binding) => binding.documentNumber,
    );

    surcharges.addAll(negative.surcharges);
  }

  final FieldValue<Money> grossTotal;
  final FieldValue<Money> netTotal;
  final FieldValue<Money> taxTotal;
  final List<TaxSlot> taxSlots;

  if (textLayerReading) {
    final grosses = _uniqueAmountOperands(textGrossOperands);
    final bases = _uniqueAmountOperands(textBaseOperands);
    final taxes = _uniqueAmountOperands(textTaxOperands);
    final rates = _uniqueRateOperands(textRateOperands);

    final RateGateResult gate;
    if (country == null) {
      // The universal core has no legal-rate set: every printed rate is
      // admitted and none is discarded.
      gate = RateGateResult(admitted: rates, discarded: const <ReadOperand>[]);
    } else {
      gate = gatePrintedRates(rates, country);
    }

    final breakdown = solveBreakdown(
      bases: bases,
      taxes: taxes,
      grosses: grosses,
      admittedRates: gate.admitted,
    );

    // Prefer the tax value the solver matched (read or derived) over a blind
    // sum of every printed `IVA` candidate. A tax-total label and several tax
    // line amounts are all labelled `IVA`; summing them would count the
    // total. When the solver cannot match a breakdown, a single read tax is
    // kept and several read taxes stay empty rather than being summed into a
    // plausible but unverified number.
    final FieldValue<Money> rawTax;
    if (breakdown.tax is Present<Money>) {
      rawTax = breakdown.tax;
    } else if (taxes.length == 1) {
      rawTax = _sumReadTaxes(taxes);
    } else {
      rawTax = const Absent<Money>();
    }

    // The consensus object here is deliberately `NoConsensus`: a text-layer
    // pass is `Single` by route, but [solveBreakdown] can now receive several
    // printed candidates, so there is no single value to wrap. The amount
    // solver's output is the value; confidence is finalised from the checks.
    final grossField = _keepReadAmountIfAbsent(
      breakdown.gross,
      _uniqueAmountOrNull(grosses),
      const NoConsensus<Money>(),
      textLayerReading: true,
    );
    final baseField = _keepReadAmountIfAbsent(
      breakdown.base,
      _uniqueAmountOrNull(bases),
      const NoConsensus<Money>(),
      textLayerReading: true,
    );
    final taxField = _keepReadAmountIfAbsent(
      rawTax,
      _uniqueAmountOrNull(taxes),
      const NoConsensus<Money>(),
      textLayerReading: true,
    );

    final sumCheck = _amountCheck(grossField, baseField, taxField);
    final taxCheck = _taxIdentityCheck(
      base: baseField,
      tax: taxField,
      taxes: taxes,
      admittedRates: gate.admitted,
    );

    grossTotal = _finalizeAmount(
      grossField,
      const NoConsensus<Money>(),
      sumCheck,
      textLayerReading: true,
      taxCheck: taxCheck,
      isTaxOperand: false,
    );
    netTotal = _finalizeAmount(
      baseField,
      const NoConsensus<Money>(),
      sumCheck,
      textLayerReading: true,
      taxCheck: taxCheck,
      isTaxOperand: true,
    );
    taxTotal = _finalizeAmount(
      taxField,
      const NoConsensus<Money>(),
      sumCheck,
      textLayerReading: true,
      taxCheck: taxCheck,
      isTaxOperand: true,
    );
    taxSlots = country == null
        ? const <TaxSlot>[]
        : buildTaxSlots(
            bases: bases,
            taxes: taxes,
            grosses: grosses,
            admittedRates: gate.admitted,
            country: country,
          );
  } else {
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

    if (grossDisputed || baseDisputed || taxDisputed) {
      // A disputed operand is never handed to the solver: the disputed field
      // stays empty and the surviving operands are kept as read values only.
      grossTotal = _readAmountField(
        _consensusValue<Money>(grossConsensus),
        grossConsensus,
        textLayerReading: false,
      );
      netTotal = _readAmountField(
        _consensusValue<Money>(baseConsensus),
        baseConsensus,
        textLayerReading: false,
      );
      taxTotal = _readAmountField(
        _consensusValue<Money>(taxConsensus),
        taxConsensus,
        textLayerReading: false,
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

      final RateGateResult gate;
      if (country == null) {
        // The universal core has no legal-rate set: every printed rate is
        // admitted and none is discarded.
        gate = RateGateResult(
          admitted: rates,
          discarded: const <ReadOperand>[],
        );
      } else {
        gate = gatePrintedRates(rates, country);
      }

      final breakdown = solveBreakdown(
        bases: bases,
        taxes: taxes,
        grosses: grosses,
        admittedRates: gate.admitted,
      );

      final rawTax = taxes.isEmpty ? breakdown.tax : _sumReadTaxes(taxes);

      final grossField = _keepReadAmountIfAbsent(
        breakdown.gross,
        grossValue,
        grossConsensus,
        textLayerReading: false,
      );
      final baseField = _keepReadAmountIfAbsent(
        breakdown.base,
        baseValue,
        baseConsensus,
        textLayerReading: false,
      );
      final taxField = _keepReadAmountIfAbsent(
        rawTax,
        taxValue,
        taxConsensus,
        textLayerReading: false,
      );

      final sumCheck = _amountCheck(grossField, baseField, taxField);
      final taxCheck = _taxIdentityCheck(
        base: baseField,
        tax: taxField,
        taxes: taxes,
        admittedRates: gate.admitted,
      );

      grossTotal = _finalizeAmount(
        grossField,
        grossConsensus,
        sumCheck,
        textLayerReading: false,
        taxCheck: taxCheck,
        isTaxOperand: false,
      );
      netTotal = _finalizeAmount(
        baseField,
        baseConsensus,
        sumCheck,
        textLayerReading: false,
        taxCheck: taxCheck,
        isTaxOperand: true,
      );
      taxTotal = _finalizeAmount(
        taxField,
        taxConsensus,
        sumCheck,
        textLayerReading: false,
        taxCheck: taxCheck,
        isTaxOperand: true,
      );
      taxSlots = country == null
          ? const <TaxSlot>[]
          : buildTaxSlots(
              bases: bases,
              taxes: taxes,
              grosses: grosses,
              admittedRates: gate.admitted,
              country: country,
            );
    }
  }

  final docDate = _nonAmountField<CalendarDate>(
    dateReadings,
    FieldKind.other,
    textLayerReading: textLayerReading,
  );
  final supplierName = _nonAmountField<String>(
    supplierReadings,
    FieldKind.supplierName,
    textLayerReading: textLayerReading,
  );
  final docNumber = _nonAmountField<String>(
    docNumberReadings,
    FieldKind.docNumber,
    textLayerReading: textLayerReading,
  );
  final currency = _currencyField(
    currencyReadings,
    textLayerReading: textLayerReading,
  );

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
    needsReview: country == null || _needsReview(reviewFields),
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

CurrencyCode? _resolveUniversalCurrency(
  Iterable<TextPage> pages,
  CountryTable table,
) {
  final value = resolveCurrency(readCurrencyEvidence(pages), table);
  return value is Present<CurrencyCode> ? value.value : null;
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
  CountryRow? country,
  DateOrder? dateOrder,
  String passId,
  T? Function(LabelBinding binding) value,
) {
  final bindings = _bindingsFor(
    pages,
    labelKind,
    valueKind,
    country,
    dateOrder,
  );
  if (bindings.isEmpty) {
    return;
  }

  // One label kind can occur several times on one page (`Factura` in a title,
  // in a total row and in a note). The value that belongs to the field is the
  // one bound on the label's own line, nearest first; a below-line binding is
  // only used when no same-line label produced a value. Pages still have to
  // agree with each other, so a genuine multi-page disagreement remains empty.
  final bindingsByPage = <int, List<LabelBinding>>{};
  for (final binding in bindings) {
    bindingsByPage
        .putIfAbsent(binding.pageIndex, () => <LabelBinding>[])
        .add(binding);
  }

  final pageBindings = <LabelBinding>[];
  for (final pageList in bindingsByPage.values) {
    final sameLine = pageList
        .where((LabelBinding binding) => binding.sameLine)
        .toList();
    final best = (sameLine.isNotEmpty ? sameLine : pageList).first;
    if (value(best) != null) {
      pageBindings.add(best);
    }
  }

  if (pageBindings.isEmpty) {
    return;
  }

  final first = value(pageBindings.first);
  if (first == null) {
    return;
  }
  for (final binding in pageBindings.skip(1)) {
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
  CountryRow? country,
  DateOrder? dateOrder,
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
          dateOrder: dateOrder,
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

List<ReadOperand> _uniqueAmountOperands(List<ReadOperand> operands) {
  final seen = <Money>{};
  final unique = <ReadOperand>[];
  for (final operand in operands) {
    final amount = operand.amount;
    if (amount == null || !seen.add(amount)) {
      continue;
    }
    unique.add(operand);
  }
  return unique;
}

List<ReadOperand> _uniqueRateOperands(List<ReadOperand> operands) {
  final seen = <RateBp>{};
  final unique = <ReadOperand>[];
  for (final operand in operands) {
    final rate = operand.rate;
    if (rate == null || !seen.add(rate)) {
      continue;
    }
    unique.add(operand);
  }
  return unique;
}

Money? _uniqueAmountOrNull(List<ReadOperand> operands) {
  Money? value;
  for (final operand in operands) {
    final amount = operand.amount;
    if (amount == null) {
      continue;
    }
    if (value == null) {
      value = amount;
    } else if (value != amount) {
      return null;
    }
  }
  return value;
}

FieldValue<T> _nonAmountField<T>(
  List<Reading<T>> readings,
  FieldKind kind, {
  required bool textLayerReading,
}) {
  final consensus = resolveConsensus<T>(readings);
  return switch (consensus) {
    Agreed<T>(:final value) => Present<T>(
      value,
      Provenance.read,
      _finalizeConfidence(
        agreed: true,
        kind: kind,
        check: CheckOutcome.passed,
        textLayerReading: textLayerReading,
        provenance: Provenance.read,
      ),
    ),
    Single<T>(:final value) => Present<T>(
      value,
      Provenance.read,
      _finalizeConfidence(
        agreed: false,
        kind: kind,
        textLayerReading: textLayerReading,
        provenance: Provenance.read,
      ),
    ),
    NoConsensus<T>() => Absent<T>(),
  };
}

FieldValue<CurrencyCode> _currencyField(
  List<Reading<CurrencyCode>> readings, {
  required bool textLayerReading,
}) {
  final consensus = resolveConsensus<CurrencyCode>(readings);
  return switch (consensus) {
    Agreed<CurrencyCode>(:final value) => Present<CurrencyCode>(
      value,
      Provenance.read,
      _finalizeConfidence(
        agreed: true,
        kind: FieldKind.currency,
        check: CheckOutcome.passed,
        textLayerReading: textLayerReading,
        provenance: Provenance.read,
      ),
    ),
    Single<CurrencyCode>(:final value) => Present<CurrencyCode>(
      value,
      Provenance.read,
      _finalizeConfidence(
        agreed: false,
        kind: FieldKind.currency,
        textLayerReading: textLayerReading,
        provenance: Provenance.read,
      ),
    ),
    NoConsensus<CurrencyCode>() => const Absent<CurrencyCode>(),
  };
}

ConfidenceState _finalizeConfidence({
  required bool agreed,
  required FieldKind kind,
  CheckOutcome check = CheckOutcome.none,
  bool textLayerReading = false,
  Provenance provenance = Provenance.read,
}) {
  final state = assignConfidence(kind: kind, check: check);
  if (state == ConfidenceState.green && !agreed) {
    // A single pass is a `Single`, never an `Agreed`. It stays capped below
    // green unless the route is a PDF text layer, the value was read and the
    // field takes part in a checkable identity that passed.
    if (textLayerReading &&
        provenance == Provenance.read &&
        check == CheckOutcome.passed) {
      return ConfidenceState.green;
    }
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

/// Evaluates `tax ≈ base × rate` as a confidence identity.
///
/// A printed rate makes the identity checkable for the base and tax fields
/// when exactly one tax line and one admitted rate were read. A derived base
/// or tax is still consumed, but `checkOutcome` then refuses to confirm.
CheckOutcome _taxIdentityCheck({
  required FieldValue<Money> base,
  required FieldValue<Money> tax,
  required List<ReadOperand> taxes,
  required List<ReadOperand> admittedRates,
}) {
  if (base is! Present<Money> || tax is! Present<Money>) {
    return CheckOutcome.none;
  }
  if (taxes.length != 1 || admittedRates.length != 1) {
    return CheckOutcome.none;
  }
  return checkOutcome(
    arithmeticPassed: taxWithinTolerance(
      tax.value,
      base.value,
      admittedRates.single.rate!,
    ),
    operands: <Provenance>[base.provenance, tax.provenance, Provenance.read],
  );
}

/// Chooses the confidence check for one amount field.
///
/// An `Agreed` field keeps the existing sum identity exactly as before. A
/// `Single` on a text-layer reading may instead stand on the tax identity when
/// the sum identity is not checkable (for example a derived gross), but a
/// failed sum identity still lowers confidence and is never overridden.
CheckOutcome _effectiveAmountCheck({
  required bool agreed,
  required bool textLayerReading,
  required bool isTaxOperand,
  required CheckOutcome sumCheck,
  required CheckOutcome taxCheck,
}) {
  if (agreed || !textLayerReading || !isTaxOperand) {
    return sumCheck;
  }
  if (sumCheck == CheckOutcome.failed || taxCheck == CheckOutcome.failed) {
    return CheckOutcome.failed;
  }
  if (taxCheck == CheckOutcome.passed) {
    return CheckOutcome.passed;
  }
  return sumCheck;
}

FieldValue<Money> _finalizeAmount(
  FieldValue<Money> value,
  ConsensusResult<Money> consensus,
  CheckOutcome sumCheck, {
  required bool textLayerReading,
  required CheckOutcome taxCheck,
  required bool isTaxOperand,
}) {
  if (value is! Present<Money>) {
    return value;
  }
  final agreed = consensus is Agreed<Money>;
  final check = _effectiveAmountCheck(
    agreed: agreed,
    textLayerReading: textLayerReading,
    isTaxOperand: isTaxOperand,
    sumCheck: sumCheck,
    taxCheck: taxCheck,
  );
  return Present<Money>(
    value.value,
    value.provenance,
    _finalizeConfidence(
      agreed: agreed,
      kind: FieldKind.amount,
      check: check,
      textLayerReading: textLayerReading,
      provenance: value.provenance,
    ),
    source: value.source,
  );
}

FieldValue<Money> _keepReadAmountIfAbsent(
  FieldValue<Money> solved,
  Money? readValue,
  ConsensusResult<Money> consensus, {
  required bool textLayerReading,
}) {
  if (solved is Present<Money> || !textLayerReading) {
    return solved;
  }
  return _readAmountField(
    readValue,
    consensus,
    textLayerReading: textLayerReading,
  );
}

FieldValue<Money> _readAmountField(
  Money? value,
  ConsensusResult<Money> consensus, {
  required bool textLayerReading,
}) {
  if (value == null) {
    return const Absent<Money>();
  }
  return Present<Money>(
    value,
    Provenance.read,
    _finalizeConfidence(
      agreed: consensus is Agreed<Money>,
      kind: FieldKind.amount,
      textLayerReading: textLayerReading,
      provenance: Provenance.read,
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
