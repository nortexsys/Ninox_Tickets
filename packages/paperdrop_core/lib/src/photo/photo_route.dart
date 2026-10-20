/// Helpers that turn the two double-based photo readers into canonical Core
/// values.
///
/// These functions live beside the readers rather than in
/// `extract_document.dart` because they are the only place the canonical
/// pipeline touches the readers' `double` values; the rest of the canonical
/// model stays integer minor units.
library;

import '../consensus/consensus.dart';
import '../countries/country_table.dart';
import '../model/canonical_document.dart';
import '../model/confidence.dart';
import '../model/field_value.dart';
import '../model/provenance.dart';
import '../money/currency.dart';
import '../money/money.dart';
import '../money/rate.dart';
import 'amount_coherence.dart';
import 'labelled_reader.dart';

/// Adds the combined labelled/arithmetic amount for one pass to [readings].
void addPhotoAmountReading(
  List<Reading<Money>> readings,
  ReceiptValue labelled,
  ReceiptValue arithmetic,
  String passId,
  CurrencyCode currency,
) {
  final ReceiptValue chosen;
  final bool fromLabelled;
  if (labelled.has) {
    chosen = labelled;
    fromLabelled = true;
  } else if (arithmetic.has) {
    chosen = arithmetic;
    fromLabelled = false;
  } else {
    return;
  }

  final money = moneyFromDouble(chosen.value!, currency);
  if (money == null) {
    return;
  }
  final provenance = fromLabelled
      ? provenanceForOrigin(chosen.origin)
      : Provenance.derived;
  readings.add(Reading<Money>(money, passId, provenance));
}

/// Adds the coherent photo amounts for one pass to the three [readings].
///
/// A labelled value keeps its origin-derived provenance; an arithmetic value
/// stays `derived`, even when rule 4 preferred the arithmetic triple.
void addCoherentPhotoAmountReadings({
  required List<Reading<Money>> netReadings,
  required List<Reading<Money>> vatReadings,
  required List<Reading<Money>> grossReadings,
  required CoherentPhotoAmounts amounts,
  required String passId,
  required CurrencyCode currency,
}) {
  _addCoherentAmount(netReadings, amounts.net, passId, currency);
  _addCoherentAmount(vatReadings, amounts.vat, passId, currency);
  _addCoherentAmount(grossReadings, amounts.gross, passId, currency);
}

void _addCoherentAmount(
  List<Reading<Money>> readings,
  CoherentPhotoAmount amount,
  String passId,
  CurrencyCode currency,
) {
  if (!amount.has) {
    return;
  }
  final money = moneyFromDouble(amount.amount!, currency);
  if (money == null) {
    return;
  }
  final provenance = amount.source == PhotoAmountSource.labelled
      ? provenanceForOrigin(amount.value.origin)
      : Provenance.derived;
  readings.add(Reading<Money>(money, passId, provenance));
}

/// Adds the combined labelled/arithmetic rate for one pass to [readings].
void addPhotoRateReading(
  List<Reading<RateBp>> readings,
  double? labelledRate,
  double? arithmeticRate,
  String passId,
) {
  final double? rate;
  final Provenance provenance;
  if (labelledRate != null) {
    rate = labelledRate;
    provenance = Provenance.read;
  } else if (arithmeticRate != null) {
    rate = arithmeticRate;
    provenance = Provenance.derived;
  } else {
    return;
  }
  readings.add(
    Reading<RateBp>(RateBp((rate * 100).round()), passId, provenance),
  );
}

/// Maps a prototype origin string to a canonical provenance tag.
Provenance provenanceForOrigin(String origin) =>
    origin == 'read' ? Provenance.read : Provenance.derived;

/// Chooses the provenance of the consensus [value] from its readings.
///
/// A `read` reading wins; otherwise the value stays `derived`, so a value the
/// arithmetic reader produced never confirms anything.
Provenance photoProvenanceFor<T>(List<Reading<T>> readings, T? value) {
  if (value == null) {
    return Provenance.derived;
  }
  for (final reading in readings) {
    if (reading.value == value && reading.provenance == Provenance.read) {
      return Provenance.read;
    }
  }
  return Provenance.derived;
}

/// Wraps a photo amount in an amber field; [Provenance] is preserved.
FieldValue<Money> photoAmountField(Money? value, Provenance provenance) {
  if (value == null) {
    return const Absent<Money>();
  }
  return Present<Money>(value, provenance, ConfidenceState.amber);
}

/// The photo route's currency: the country row's, green with the country
/// setting as its source (DEC-023).
FieldValue<CurrencyCode> countryCurrencyField(CountryRow country) {
  return Present<CurrencyCode>(
    country.currency,
    Provenance.derived,
    ConfidenceState.green,
    source: ValueSource.countrySetting,
  );
}

/// Builds the photo route's tax slots from the single reader rate.
List<TaxSlot> photoTaxSlots({
  required CountryRow country,
  required RateBp? rateValue,
  required Provenance rateProvenance,
  required Money? baseValue,
  required Provenance baseProvenance,
  required Money? taxValue,
  required Provenance taxProvenance,
}) {
  final slots = <TaxSlot>[];
  for (var i = 0; i < country.slotCount; i++) {
    if (i == 0 && rateValue != null) {
      slots.add(
        TaxSlot(
          rate: Present<RateBp>(
            rateValue,
            rateProvenance,
            ConfidenceState.amber,
          ),
          base: baseValue != null && baseProvenance == Provenance.read
              ? Present<Money>(baseValue, baseProvenance, ConfidenceState.amber)
              : const Absent<Money>(),
          amount: taxValue != null && taxProvenance == Provenance.read
              ? Present<Money>(taxValue, taxProvenance, ConfidenceState.amber)
              : const Absent<Money>(),
        ),
      );
    } else {
      slots.add(
        const TaxSlot(
          rate: Absent<RateBp>(),
          base: Absent<Money>(),
          amount: Absent<Money>(),
        ),
      );
    }
  }
  return slots;
}

/// Turns a reader `double` amount into [Money] in [currency]'s minor units.
///
/// The prototype keeps three decimals for Spanish tickets; the canonical model
/// is integer minor units, so the value is rounded to the currency's exponent.
Money? moneyFromDouble(double value, CurrencyCode currency) {
  final exponent = currency.exponent;
  var factor = 1;
  for (var i = 0; i < exponent; i++) {
    factor *= 10;
  }
  final minor = (value * factor).round();
  return Money(minor, currency);
}
