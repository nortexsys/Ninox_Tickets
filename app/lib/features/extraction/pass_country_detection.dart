/// The country of one extraction, decided over all of its passes and not over one of them.
///
/// Requirement served: `countries-languages` · `deterministic-country-detection` (FR-CTR-001)
/// — the country is the document's own evidence and never a setting — and
/// `extraction-pipeline` · `consensus-by-majority` (FR-EXT-006), which design §3 applies to
/// the country as well: one document read in several passes is one answer, and a pass that
/// disagrees about the country is not a vote.
///
/// **Why this is not in Core.** `detectCountry` answers for one page set. How many page
/// sets an extraction has, and whether their answers agree, is the orchestration's question:
/// Core is handed the passes it must read and never the group (design §3, dispatch B). The
/// rule is the design's: every pass that holds words is asked, and all of them must name the
/// same country row, or the same reason for having none. Anything else is
/// `conflictingEvidence`.
///
/// **What it does not do.** It reads no locale, no destination and no preference, and it
/// decides no value: the answer is Core's own [CountryDetection], so a caller stores a reason
/// Core named and never a word invented here.
library;

import 'package:paperdrop_core/paperdrop_core.dart';

/// The country detection of an extraction, agreed by the passes that carry evidence.
///
/// The passes are asked in the order they arrived, each over its own pages. The answer of the
/// first pass that holds words is returned once every such pass agrees with it about the
/// country row or about the reason no row applies; [Undetected] with
/// [UndetectedReason.conflictingEvidence] when they do not agree; and [Undetected] with
/// [UndetectedReason.noEvidence] when no pass holds a word at all.
///
/// A pass with no word is not asked: it carries no evidence, and design §3 says the page set
/// this decision uses is the first pass with words. A pass the recognition dropped some words
/// from answers for the words it did read, which is exactly the disagreement this function
/// reports rather than averages away.
///
/// The [Detected.evidence] kinds of the pass that answered are the ones returned, and they
/// are never text from the document (design §5): the kinds of earlier passes are not merged,
/// because the row — or the reason — is what governs the reading.
CountryDetection detectCountryAcrossPasses({
  required Iterable<ExtractionPass> passes,
  required CountryTable table,
}) {
  CountryDetection? agreed;
  for (final ExtractionPass pass in passes) {
    if (!_holdsWords(pass)) {
      continue;
    }
    final CountryDetection answer = detectCountry(
      pages: pass.pages,
      table: table,
    );
    if (agreed == null) {
      agreed = answer;
    } else if (!_sameCountry(agreed, answer)) {
      return const Undetected(reason: UndetectedReason.conflictingEvidence);
    }
  }
  return agreed ?? const Undetected(reason: UndetectedReason.noEvidence);
}

/// Whether [pass] read a word at all, which is what makes it an opinion about the country.
bool _holdsWords(ExtractionPass pass) =>
    pass.pages.any((TextPage page) => page.hasTextLayer);

/// Whether two answers name the same country row, or the same reason for having none.
///
/// The evidence kinds are deliberately not compared: two passes that both name ES — one from
/// the issuer's tax identifier, the other from a country name next to an address — agree
/// about the country, and the row is what governs the reading. Two different reasons for
/// having no row are a disagreement and not a detail: the reason is what the entry then
/// records (design §4).
bool _sameCountry(CountryDetection left, CountryDetection right) =>
    switch ((left, right)) {
      (final Detected a, final Detected b) => a.row == b.row,
      (final Undetected a, final Undetected b) => a.reason == b.reason,
      _ => false,
    };
