/// The extraction stage trace.
///
/// A trace records, per canonical field, the stage that left the field absent
/// or lowered it. It never carries a document value: the only two arguments
/// are a field name owned by Core and one [ExtractionStage] enum value.
library;

/// One stage at which an extraction candidate or field can be lost or lowered.
///
/// The list is closed: the orchestrator reports counts per stage, so a new
/// stage is a deliberate enum addition and never a free-form string.
enum ExtractionStage {
  /// No label of the field's kind was found on the page.
  noLabelOfKind,

  /// A label of the field's kind was found but no value was bound to it.
  labelFoundNoValue,

  /// A candidate value was found next to the label but did not parse in the
  /// field's format (amount or date).
  valueNotParsed,

  /// A printed figure was rejected by the negative-context radius.
  negativeContextRejected,

  /// Candidates were kept but no arithmetic identity matched them.
  noArithmeticIdentity,

  /// Several arithmetic identities matched the printed candidates, so none was
  /// chosen.
  multipleArithmeticIdentities,

  /// A derivation would have been possible only through a printed rate that the
  /// legal-rate gate discarded.
  legalRateGateFailed,

  /// A field was read by several passes but no value had a majority.
  noMajority,

  /// The pages of one pass disagreed on a field, so that pass contributed no
  /// reading.
  pagesDisagreed,

  /// A value was kept but its confidence was capped below green.
  confidenceCapped,

  /// The document's currency could not be read from its printed evidence.
  noCurrencyEvidence,

  /// The document printed conflicting currency evidence.
  conflictingCurrencyEvidence,

  /// A country row was detected for the document.
  countryDetected,

  /// No country row was detected for the document.
  countryUndetected,

  /// The extraction used one pass.
  onePass,

  /// The extraction used two passes.
  twoPasses,

  /// The extraction used three passes.
  threePasses,

  /// The extraction used four passes.
  fourPasses,

  /// The extraction used more than four passes.
  moreThanFourPasses,
}

/// Records extraction stages per canonical field.
///
/// Implementations must never be given a document value, word, coordinate or
/// amount. The [record] arguments are a Core-owned field name and an
/// [ExtractionStage] enum value, nothing else.
abstract interface class ExtractionTrace {
  /// Records that [field] reached [stage].
  void record(String field, ExtractionStage stage);
}

/// An [ExtractionTrace] that collects stages in memory, one list per field.
class CollectingTrace implements ExtractionTrace {
  final Map<String, List<ExtractionStage>> _stages =
      <String, List<ExtractionStage>>{};

  /// Creates an empty collecting trace.
  CollectingTrace();

  /// The recorded stages, keyed by field and kept in recording order.
  ///
  /// The map and its lists are unmodifiable; the stage values are enum names,
  /// never document text.
  Map<String, List<ExtractionStage>> get stages =>
      Map<String, List<ExtractionStage>>.unmodifiable(
        _stages.map(
          (String field, List<ExtractionStage> stages) =>
              MapEntry<String, List<ExtractionStage>>(
                field,
                List<ExtractionStage>.unmodifiable(stages),
              ),
        ),
      );

  @override
  void record(String field, ExtractionStage stage) {
    _stages.putIfAbsent(field, () => <ExtractionStage>[]).add(stage);
  }

  /// A value-only string form naming the recorded counts.
  @override
  String toString() =>
      'CollectingTrace(${_stages.map((field, stages) => MapEntry(field, stages.length))})';
}
