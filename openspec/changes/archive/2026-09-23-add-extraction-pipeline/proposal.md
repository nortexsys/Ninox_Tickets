# Proposal — extraction-pipeline

## Why

This is where the project's central failure was born, and the specification exists
to make it impossible to repeat.

The 16-document test reported ten records as arithmetically verified. Nine of them
had computed the base and the tax **from the total** and then checked that
base + tax = total. That check passes by construction: it is a tautology, and it
confirmed nothing. The one record that was genuinely confirmed had read all three
quantities where they were printed. The test's own example is the clearest case —
with a total misread as 19,98 the breakdown comes out 16,51 + 3,47, and with the
real 19,99 it comes out 16,52 + 3,47. Both add up. The arithmetic cannot tell them
apart, and only reading the printed quantities can.

The pipeline also had two other defects the test exposed, both structural rather
than statistical: it took the **maximum** across recognition passes, so one noisy
pass overruled three that agreed; and it **invented tax rates** the document never
stated — 9 %, 30 % and a 4.5 % currency-conversion mark-up, none of them legal in
Spain and one of them legal nowhere in the EU.

Every one of those is a rule about **where a value may come from**. That is what
this capability owns, and it is why it is a Full spec: getting it wrong does not
produce an error, it produces a confident wrong number.

## What Changes

- Add one capability spec, `extraction-pipeline`, with **16 requirements**:
  FR-EXT-001…015 plus BR-20, the reading-source rule for `doc_date` that no `FR-`
  module carries.
- Fixes four boundaries the functional states more than once, now recorded in
  `project.md` §3.3 before either side is written: the legal-rate check versus the
  gate that consumes it, currency reading versus currency confidence, format
  inference versus date coherence versus the `doc_date` source rule, and producing
  `not_in_xml` versus knowing what it means.
- **No behaviour changes.** Every requirement traces to FR-EXT or BR-20.

## Capabilities

### New Capabilities

- `extraction-pipeline`: the fixed pipeline order, the invoice route priority
  (XML, then positional text, then OCR), consensus by majority, read-all-operands
  before deriving, the derive-by-identity boundary, provenance on every value,
  multi-page consolidation, multilingual label dictionaries, and the recognition
  quality of the photo route.

### Modified Capabilities

- None. No approved specification's requirements change.

## Impact

- `openspec/specs/extraction-pipeline/spec.md` — new.
- No application code, dependency, schema or API is touched by this proposal.
- `validation-confidence` consumes what this capability produces — values with
  provenance — and must not re-derive them. `capture-intake` produces the input.
  `countries-languages` supplies the rate sets, the dictionaries and the algorithms.

---

## Spec type

**Full.** Three reasons, none of them about size. The failure is **silent**: a
tautological check and a misread total produce a record that looks correct. The
boundary is **exact and easy to get wrong in either direction**: `base = total − tax`
is required when both are printed and forbidden when the rate is assumed. And the
pipeline **order is load-bearing**: a stage that consumes a later stage's output
reintroduces the defect without any test noticing.

## Problem statement

A recognition pass produces candidates, not values. Turning candidates into values
requires a rule for which candidate wins, a rule for where a value may legitimately
come from, and a record of which of those rules produced it — because a check that
consumes a value must be able to tell whether that value was read or computed.
Without that record, every arithmetic check confirms itself.

## Scope

### In scope

| Group | What it covers |
| --- | --- |
| Pipeline order (FR-EXT-001) | Seven stages, fixed: consensus → read all printed quantities → derive by identity → validation → write → read back → compare with the destination's formula fields. No stage consumes a later stage's output |
| Invoice route priority (FR-EXT-002) | XML (ZUGFeRD/Factur-X embedded, or standalone XRechnung), then the PDF text layer with word-level positions, then render + OCR. Stop at the first that succeeds, and record which route was taken |
| Structured XML (FR-EXT-003) | Deterministic field-by-field extraction; UBL and CII syntaxes; ZUGFeRD/Factur-X profile levels; a field the profile omits is `not_in_xml`, never absent; the carrying PDF is read-only |
| Positional text (FR-EXT-004) | A label binds to the value nearest it in the **visual layout**, using word coordinates. Extraction order alone is not an accepted implementation |
| Render + OCR fallback (FR-EXT-005) | A PDF with no text layer and no XML renders to images and goes through the OCR pipeline exactly like the photo route |
| Consensus (FR-EXT-006, BR-06) | Majority wins. A single outlier never overrides agreement, whatever its apparent confidence. Arithmetic runs only on operands that passed consensus |
| Read before derive (FR-EXT-007) | Every printed operand is read first, matching independently read candidates against each other. An unreadable quantity stays empty |
| Derive by identity (FR-EXT-008, BR-07) | `base = total − tax` when both were read, tagged `derived`, with no confirmatory effect. Assuming a rate the document does not state is never permitted |
| Rate gate (FR-EXT-009) | No rate is used for a derivation until the validation layer has admitted it against the detected country's legal set |
| Negative context (FR-EXT-010, BR-08) | Candidates that are percentages or numbers but not tax figures are suppressed, and surcharge-like amounts are captured as `surcharges[]` where the document supports it |
| Provenance (FR-EXT-011) | `read`, `derived`, `repaired` or `from_xml` on every value, held internally, never written to Ninox, and decisive for whether a consuming check may confirm |
| Multi-page (FR-EXT-012) | Every page read, one consolidated canonical model, one value per field, provenance per value |
| Currency (FR-EXT-013) | Read from the document's own evidence — printed ISO code, symbol, issuer country. Never defaulted to the table's currency |
| Dictionaries (FR-EXT-014) | Label dictionaries cover the document languages the product expects, independent of the interface language |
| Photo-route quality (FR-EXT-015) | Per-field accuracy after consensus and validation meets the threshold fixed in §10.5 |
| `doc_date` source (BR-20) | Never derived from a filename or a received-email timestamp |

### Out of scope

- **Deciding whether a value may be trusted.** The three confidence strengths, the
  confirmatory rule, the repair rule, the green/amber/red state and what "absent"
  means at the destination are `validation-confidence`.
- **Which rates are legal, and each check-digit algorithm.** `countries-languages`
  owns the data and the algorithms. This capability owns the gate that consumes the
  legal-rate check and the `not_in_xml` status it produces, not the check or the
  meaning of the status.
- **Currency's confidence state.** This capability reads the currency; whether it
  can be sustained, and what happens to the amounts when it cannot, is
  `validation-confidence` (FR-VAL-009).
- **Date coherence and the ambiguity outcome.** `validation-confidence` (FR-VAL-013)
  owns those; `countries-languages` owns the format-inference algorithm. This
  capability owns only that the date is never taken from a filename or an email.
- **Getting the document in.** `capture-intake` owns intake and byte integrity.
- **Writing anything.** `ninox-send` owns the payload, the retry matrix and the
  read-back; the pipeline's stages 5 to 7 are performed there.

## Source documents

- `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` §4.2 (FR-EXT-001…015), §5
  BR-06, BR-07, BR-08, BR-20, §1.5 (the provenance tags), Annex C (the
  dictionaries), Annex D (the worked examples, including the tautology as a
  negative test).
- `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` §6.1 (provenance and the
  tautology), §7.4 (formula fields), §13 (screening).
- `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` — ADR-010, ADR-011 (both still
  proposed), ADR-014 (route priority), ADR-019 (consensus and the pipeline fixes).
- The 16-document test: `metodo_base` in `corpus_test/out/ninox_log.json` is the
  evidence for `derived_from_gross` on nine records.

## Key design constraints

1. **Provenance is not metadata, it is the mechanism.** FR-VAL-002 can only work if
   every value carries where it came from. A pipeline that loses provenance cannot
   implement the confidence model at all, and its arithmetic checks silently become
   tautologies.
2. **The order is normative, not stylistic.** Stage 2 before stage 3 is what makes
   the difference between reading three printed quantities and computing one of
   them. Reversing them produces the same numbers in the common case and the wrong
   numbers in the cases that matter.
3. **`not_in_xml` is a third state, not a synonym for absent.** A low-profile XML
   omits fields the printed PDF carries; calling that "absent" would suppress values
   the document actually shows.
4. **Two routes are blocked, and the spec says so without blocking.** FR-EXT-004,
   FR-EXT-005 and FR-EXT-015 cannot be *accepted* until ADR-010 and ADR-011 close
   (GAP-001, GAP-002). Their behaviour is nonetheless fixed and written; the
   blocked status is carried in each requirement and in `Open Questions` rather than
   leaving those requirements unwritten.
5. **The negative-context list is not owned here.** This capability owns the
   application rule and the influence radius; `countries-languages` owns the terms
   (`project.md` §3.3).
6. **No invented content.** The functional names `solve_amounts.py`'s approach as
   the reference for matching independently read candidates. That is a design
   pointer, reproduced as such, not a specification of an algorithm.

## Open questions at proposal stage

- **None blocking, two bearing on the capability.**
  - **GAP-001** (ADR-010, recognition engine) blocks the acceptance of FR-EXT-005
    and FR-EXT-015 and is why the photo route's quality threshold is not stated
    numerically here: §10.5 defers it to the first corpus screening (GAP-003).
  - **GAP-002** (ADR-011, PDF text-extraction library) blocks the acceptance of
    FR-EXT-004. The requirement fixes the criterion — word-level positions and
    binding in the visual layout — which is what the library choice must satisfy.
- **To confirm while reviewing:** whether the `surcharges[]` capture required by
  FR-EXT-010 belongs in this capability's spec or in the canonical data model.
  This proposal reads it as this capability's, because it is the negative-context
  rule's fallback behaviour and happens during extraction; the data model's shape is
  §6.1 of the functional and would be a separate concern if the product owner wants
  it specified independently.
