# Proposal — validation-confidence

## Why

This is the product's central claim written as behaviour, and the place where a
wrong rule confirms a wrong value without saying so.

The claim is that Paperdrop does not trust a reading — it establishes one
deterministically from other things it read. That is only true if two conditions
hold, and the 16-document test showed that neither holds by accident. First, a check
must know where its operands came from: nine of the ten records reported as
arithmetically verified had derived the base from the total and then checked that
the parts add up, which is true by construction. Second, a value with nothing to
cross against must not be presented as certain, however cleanly it was read — and
the test's other failure patterns were all cases where a plausible number appeared
where the honest answer was an empty field.

There is a third condition the test sharpened rather than revealed. Confidence needs
**provenance from the extraction layer** to work at all: a validation layer that
cannot tell a read value from a computed one cannot implement this specification.
That is why the pipeline and this capability are two specs and not one.

## What Changes

- Add one capability spec, `validation-confidence`, with **15 requirements**:
  FR-VAL-001…014 plus BR-03, empty over false, whose abstention behaviour no `FR-`
  module carries as a requirement.
- Consumes four boundaries fixed in `project.md` §3.3 rather than restating them:
  the check-digit **algorithms** are `countries-languages`' (this capability owns
  that the validators exist and are accepted against test vectors); the legal rate
  **sets** are `countries-languages`' (this capability owns that the check runs);
  the **application** of the negative-context dictionary is `extraction-pipeline`'s;
  and reading the currency is `extraction-pipeline`'s (this capability owns its
  confidence state).
- **No behaviour changes.** Every requirement traces to FR-VAL or a business rule.

## Capabilities

### New Capabilities

- `validation-confidence`: the three confidence strengths and which of them is
  green, the rule that a check confirms only if every operand was read, the
  redundancy checks over integer minor units, repair to the only consistent value,
  currency's own confidence state, what never reaches green, tax slots, absent
  versus zero, date coherence, determinism over coverage, and abstention.

### Modified Capabilities

- None. No approved specification's requirements change.

## Impact

- `openspec/specs/validation-confidence/spec.md` — new.
- No application code, dependency, schema or API is touched by this proposal.
- `extraction-pipeline` produces the values and the provenance this capability
  consumes. `review-screen` renders the resulting state. `destinations-mapping`
  owns the per-field absent-versus-zero setting and the write path that consumes the
  final decision.

---

## Spec type

**Full.** The failure is silent and the ambiguity is expensive. A tautological
check reports success; a value shown as green that should be amber is believed by
the user and travels into their accounts. And the three strengths, the confirmatory
rule, the single tolerance, the repair rule and the abstention default are one
interlocking contract: getting any one of them wrong in isolation makes the others
report confidently about something they should not.

## Problem statement

Reading a document yields values with degrees of support, and the product must
distinguish those degrees honestly — in the model, in the interface, and in what
reaches the user's accounts. The distinction has to be mechanical rather than
judgemental: a deterministic constraint establishes a value from values that were
themselves read, or the value is not confirmed. Everything else about a value's
presentation follows from that, including the cases where the honest presentation
is an empty field.

## Scope

### In scope

| Group | What it covers |
| --- | --- |
| The three strengths (FR-VAL-001, BR-04) | Confirmed by redundancy (strong, green, locked); consistent with a check digit (medium, amber); repaired to the only consistent value (weak, amber). No independent figure to cross against means never green |
| The confirmatory rule (FR-VAL-002, BR-02, BR-05) | A check raises confidence only if every operand is `read` or `from_xml`. A derived operand makes the check true by construction, so it confirms nothing — and a derived value never raises anything, including what it was computed from |
| Editing (FR-VAL-003) | Green is editable only after its lock is tapped; amber and red are directly editable |
| The numeric score (FR-VAL-004) | Never displayed. Stored locally; written to Ninox only if the user mapped it |
| Validators (FR-VAL-005) | A check-digit validator for every identifier type the country table declares, each accepted only against the standard valid and invalid test vectors. `DE_STNR` explicitly not validated |
| Amount redundancy (FR-VAL-006, BR-09 tolerance) | Sum of printed bases = net; sum of printed tax = tax total; net + tax + printed rounding = gross, **exact integer equality with no tolerance**; and `base × rate ≈ tax` with at most one minor unit per line — the only tolerance in the product |
| Legal rate (FR-VAL-007) | Any rate used is checked against the detected country's legal set and rejected when it is not legal |
| Repair (FR-VAL-008) | Where a reading fails a check digit and exactly one replacement makes it pass, the repair may be applied, tagged `repaired`, and shown amber with the repair visible. Two admissible repairs means no repair |
| Currency (FR-VAL-009, BR-12) | Its own confidence state, separate from amounts. An unsustained currency suppresses the amounts rather than permitting a wrong-currency figure |
| What never reaches green (FR-VAL-010, BR-10, BR-11) | `doc_number`, because receipt and invoice numbers carry no check digit and every pass produces a different variant. `supplier_name`, except from the supplier memory and from an identifier that passed its check digit |
| Slots (FR-VAL-011) | One `tax_rate` / `tax_base` / `tax_amount` triplet per printed rate, the count declared by the country table; empty slots stay empty; each maps independently and all are optional. `tax_total` is the sum of printed amounts, never a value computed from the gross total and an assumed rate |
| Absent versus zero (FR-VAL-012, BR-13) | A value not printed is not a zero. Which of the two applies is a per-field property of the destination mapping, chosen by the user; the app never hardcodes either and defaults to empty |
| Dates (FR-VAL-013) | Coherence checked, and an undecidable date flagged ambiguous rather than silently assumed |
| Determinism over coverage (FR-VAL-014, BR-01) | The normative form of the fourth contract line: confirmed only when a deterministic constraint establishes it from values themselves read. Preferring admitted doubt to a convincing guess |
| Abstention (BR-03) | When the app cannot sustain a value it writes nothing, as the default rather than a fallback |

### Out of scope

- **Every check-digit algorithm and every legal rate set.** `countries-languages`
  owns the algorithms, including that the three Spanish formats never share code
  (FR-CTR-004 and FR-VAL-005 state that separation twice; it is owned once, there).
  This capability owns that the validators exist and are accepted against vectors.
- **Where a value came from.** Reading, consensus, derivation and the provenance tags
  are `extraction-pipeline`'s. This capability consumes provenance; it does not
  produce it.
- **Reading the currency.** `extraction-pipeline` (FR-EXT-013) reads it from the
  printed ISO code, the symbol and the issuer country. This capability owns whether
  it can be sustained and what happens to the amounts when it cannot.
- **Applying the negative-context dictionary.** The terms are `countries-languages`';
  the application rule and the influence radius are `extraction-pipeline`'s.
- **The write path.** `destinations-mapping` owns the per-field absent-versus-zero
  setting and the payload; `ninox-send` owns writing it and reading it back.
- **How the state is drawn.** The confidence colour, the lock icon and the field
  order on screen are `review-screen`'s. This capability fixes what each state
  *means* and what may be shown as confirmed.
- **The threshold for the photo route's quality.** §10.5 defers it to the first
  corpus screening (GAP-003).

## Source documents

- `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` §4.3 (FR-VAL-001…014), §5
  BR-01, BR-02, BR-03, BR-04, BR-05, BR-09, BR-10, BR-11, BR-12, BR-13, §1.5 (the
  provenance tags and the confidence states), §6.2 (the confidence model), Annex B
  (the rate sets and the check digits this layer consumes), Annex D (the worked
  examples).
- `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` §4 (product principles), §6 (the
  confidence model), §6.1 (the tautology), §6.2 (what is never confirmed), §7.3
  (absent versus zero), §10 (countries).
- `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` — ADR-005 (the country table),
  ADR-009 (supplier memory and the check-digit safeguard), ADR-016 (integer minor
  units and the single tolerance), ADR-019 (the confirmatory rule).
- `corpus_test/REPORT_after_review.md` — record 1414 is where "absent is not zero,
  and the destination decides" came from, with the product owner's verdict that the
  card-terminal slip's `0,00` was correct.

## Key design constraints

1. **The strengths are ordered and only the first is green.** Redundancy is strong
   because two independently read values agree; a check digit is medium because the
   check digit itself may have been misread; repair is weak because it is correct
   only if every other character was. Nothing else reaches green.
2. **A check over a derived operand is a tautology, and the spec says why.** This is
   the one rule whose absence produced the project's central defect, and it is
   stated with its evidence — nine of ten records — rather than as a preference.
3. **Exactly one tolerance exists in the entire product.** `base × rate ≈ tax` with
   at most one minor unit per line. Printed-value sums are exact. The prototype's
   ±0.02 let 16,51 + 3,47 pass against 19,98 and that is the failure this forbids.
4. **Abstention is the default, not a fallback.** An empty mapped field is a
   deliberate outcome. That inverts the usual instinct — a form that refuses to be
   saved looks broken — and it is why it is a requirement rather than a setting.
5. **The distinction between this capability and the two it consumes must hold.**
   It consumes provenance from `extraction-pipeline` and rate sets and algorithms
   from `countries-languages`. If a requirement here needs to know an algorithm or
   to read a value, it has crossed a boundary recorded in `project.md` §3.3.
6. **No invented thresholds.** The numeric score is never shown; the photo route's
   accuracy threshold is deferred to §10.5 (GAP-003). Where the functional fixes a
   value it is reproduced; where it defers one, the spec defers it too.

## Open questions at proposal stage

- **None blocking, one bearing on the capability.** **GAP-003** — the acceptance
  thresholds for product metrics are deferred to the first corpus screening, and
  **GAP-001** (ADR-010) is what the screening waits on. No requirement in this
  capability states a numeric threshold, so neither gap prevents it being written.
- **To confirm while reviewing:** whether the supplier-memory half of
  `what-never-reaches-green` — that a name is confirmable only via memory — should
  live here or in `supplier-memory`. This proposal reads it as this capability's,
  because it is a statement about what may be shown as confirmed; `supplier-memory`
  owns the store, its indexing safeguard and its deletion. The boundary is recorded
  in `project.md` §3.3 so that `supplier-memory` references it instead of restating
  it.
