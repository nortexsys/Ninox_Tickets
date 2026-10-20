# validation-confidence Specification

## Purpose
This is the product's central claim written as behaviour. Paperdrop does not trust a
reading — it establishes one deterministically from other things it read. That claim
is only true if three conditions hold, and the 16-document test showed that none of
them holds by accident.

First, a check must know **where its operands came from**. Nine of the ten records
the test reported as arithmetically verified had derived the base from the total and
then checked that the parts add up; with a total misread as 19,98 the breakdown comes
out 16,51 + 3,47 and with the real 19,99 it comes out 16,52 + 3,47. Both add up. So
provenance — produced by `extraction-pipeline` and consumed here — is not metadata:
it is the mechanism that decides whether a check confirms anything.

Second, a value with **nothing to cross against** must not be presented as certain,
however cleanly it was read.

Third, when the app cannot sustain a value it must write **nothing**, by default
rather than as a fallback. Every other failure pattern the test produced was a
plausible-looking number standing where an empty field belonged.

This capability owns what a state *means* and what may be shown as confirmed. How it
is drawn belongs to `review-screen`; where it is written belongs to
`destinations-mapping` and `ninox-send`.

---
## Requirements
### Requirement: three-confidence-strengths

A value's confidence SHALL be one of three strengths: **confirmed by redundancy**,
where two values each read independently agree through an identity (strong);
**consistent with a check digit** (medium); or **repaired to the only consistent
value** (weak). Only the first SHALL be shown green with a lock, the other two SHALL
be amber, and an amount with no independent figure to cross against SHALL never be
green however cleanly it was read.

**One value is green without redundancy and without being a reading: the currency
the ticket's country setting supplies.** That exception, its origin and its limits
are stated in `currency-carries-its-own-confidence-state` (DEC-023); it is the only
one, it covers that source and no other value, and every rule in this requirement
holds unchanged for everything else.

**Confirmed by redundancy** also covers a value read once from a PDF's **text
layer**, with no second reading, when both of the following hold: every operand
the value depends on was itself read from that text layer, never derived; **and**
at least one arithmetic identity over those operands is checkable — every operand
it needs was read — and that identity holds. A text-layer reading with **no**
checkable identity, because only one operand was printed and nothing else is
printed alongside it to cross against, SHALL stay at the single-reading cap and
remain amber: the text layer removes the need for a second *pass*, since
re-extracting it produces no variation to arbitrate, but it does not remove the
need for a second printed *figure* to confirm the first — a lone reading with
nothing to check it against is still not confirmed, however deterministic its
route. This exception SHALL NOT extend to a value read by optical recognition — a
photograph, a rendered page of a scanned PDF, or a mixed page with no text layer —
which SHALL remain amber with no independent figure to cross against, exactly as
before. A derived operand SHALL still never raise a check to green (PRE-008,
BR-05), and an arithmetic check that fails SHALL still lower confidence rather than
being overridden by the route, on a text-layer reading exactly as on any other.
[Origen: Funcional §4.3 FR-VAL-001; Funcional §5 BR-04; PDR §6; Finding 5; DEC-018; DEC-023]

#### Scenario: redundancy makes a total green

- GIVEN a total confirmed by `base + tax = total` with every operand read
- WHEN its state is shown
- THEN it is green and locked

#### Scenario: a clean reading with nothing to cross against is amber

- GIVEN a total that passed no check and has no breakdown to cross against
- WHEN its state is shown
- THEN it is amber, not green

#### Scenario: the same reading stays amber when it came from optical recognition

- GIVEN a total read by optical recognition — a photograph or a rendered page of
  a scanned PDF — that passed no check and has no breakdown to cross against
- WHEN its state is shown
- THEN it is amber, not green
- AND no second OCR pass changes that, because the route is not a PDF text layer

#### Scenario: a text-layer reading with no checkable identity stays amber

- GIVEN a total read once from a PDF's text layer
- WHEN the total is the only operand read, with no base, no tax and nothing else
  printed alongside it to form a checkable identity
- THEN it stays amber, not green
- AND the absence of a checkable identity, not the text-layer route, is why it
  is not green

#### Scenario: a text-layer reading with a holding identity is green

- GIVEN a total read once from a PDF's text layer, with its base and its tax
  also read from that layer and none of the three derived
- WHEN `base + tax = total` is checked and holds
- THEN the total is green and locked

#### Scenario: a check digit is amber, not green

- GIVEN an EAN-13 that passes its checksum
- WHEN its state is shown
- THEN it is amber
- AND no numeric score has been used to assign any colour

#### Scenario: a derived operand still blocks green on a text-layer reading

- GIVEN a total read from a PDF's text layer whose base or tax was derived from
  the other operands rather than read
- WHEN its state is shown
- THEN it stays amber, not green
- AND the derivation, not the text-layer route, is the reason it is not green

#### Scenario: a failed arithmetic check still lowers a text-layer reading

- GIVEN a total read from a PDF's text layer whose read base plus read tax does
  not equal the read total
- WHEN its state is shown
- THEN it is not green
- AND the failed check lowers its confidence rather than being ignored because
  the reading came from the text layer

---

### Requirement: a-check-confirms-only-if-every-operand-was-read

A check that consumes a value SHALL raise the confidence state only if **every**
operand feeding it has provenance `read` or `from_xml`, and a check built from a
derived operand SHALL confirm nothing.
[Origen: Funcional §4.3 FR-VAL-002; Funcional §5 BR-02, BR-05; PDR §6.1; ADR-019; 16-document test]

#### Scenario: a derived breakdown leaves the total amber

- GIVEN a document whose base and tax were both derived from the total
- WHEN the identity `base + tax = total` is evaluated
- THEN the total stays amber
- AND the check is recorded as non-confirmatory rather than as passed

#### Scenario: the nine records of the test fail this criterion

- GIVEN the records of the 16-document test whose `metodo_base` is `derived_from_gross`
- WHEN their confidence is evaluated under this rule
- THEN none of them is confirmed
- AND the criterion that reported them as verified is rejected

#### Scenario: a derived value raises nothing

- GIVEN a value tagged `derived`
- WHEN any check consumes it
- THEN no confidence state is raised, including that of the values it was computed from

---

### Requirement: green-is-editable-only-after-unlocking

A green value SHALL be editable only after the user taps its lock icon, and amber and
red values SHALL be directly editable.
[Origen: Funcional §4.3 FR-VAL-003; PDR §6]

#### Scenario: a locked value does not open its editor

- GIVEN a green field
- WHEN the user taps its value
- THEN the editor does not open

#### Scenario: the lock is the way in

- GIVEN the same green field
- WHEN the user taps its lock icon
- THEN the value becomes editable

#### Scenario: amber and red need no unlocking

- GIVEN an amber field and a red field
- WHEN the user taps either value
- THEN it is directly editable

---

### Requirement: the-numeric-score-is-never-shown

The numeric recognition score SHALL never be displayed to the user. It SHALL be
stored locally, and written to Ninox only if the user explicitly mapped it.
[Origen: Funcional §4.3 FR-VAL-004; PDR §6]

#### Scenario: no decimal score appears on any screen

- GIVEN any screen in any state
- WHEN it is inspected
- THEN no numeric recognition score is displayed

#### Scenario: the score reaches Ninox only when mapped

- GIVEN a destination whose mapping excludes the recognition score
- WHEN a record is written
- THEN the score is not written

---

### Requirement: check-digit-validators

The validation layer SHALL implement a check-digit validator for every identifier
type the country table declares, and each validator SHALL be accepted only when it
reproduces the standard valid and invalid test vectors for its identifier type.
[Origen: Funcional §4.3 FR-VAL-005; PDR §10; ADR-005; Annex B]

#### Scenario: each validator is accepted against vectors

- GIVEN a validator and its identifier type's known-valid and known-invalid vectors
- WHEN the validator is run over them
- THEN it accepts every valid vector and rejects every invalid one

#### Scenario: the German Steuernummer is not validated

- GIVEN a document printing a `DE_STNR`
- WHEN validation runs
- THEN no check-digit validation is applied to it
- AND its absence of validation does not itself raise a doubtful state

#### Scenario: the Spanish formats are three separate implementations

- GIVEN a valid `ES_CIF`
- WHEN it is validated
- THEN it is never checked by the `ES_NIF` algorithm
- AND the separation of the three algorithms is `countries-languages`' requirement, referenced here and not restated

---

### Requirement: redundancy-checks-on-amounts

The validation layer SHALL evaluate, in integer minor units, that the sum of printed
bases equals the net total, that the sum of printed tax amounts equals the tax total,
and that net plus tax plus any printed rounding equals the gross total — with
**exact integer equality and no tolerance** — while `base × rate ≈ tax` SHALL carry a
tolerance of at most one minor unit per tax line.
[Origen: Funcional §4.3 FR-VAL-006; Funcional §5 BR-09 (the tolerance half); ADR-016; PDR §6; Annex D]

#### Scenario: printed values must be exactly equal

- GIVEN a document printing `16.52` and `3.47` against `19.99`
- WHEN the redundancy checks run
- THEN the total is confirmed

#### Scenario: no tolerance absorbs a misread total

- GIVEN the same figures against `19.98`
- WHEN the redundancy checks run
- THEN the total is not confirmed
- AND no tolerance absorbs the one-unit difference

#### Scenario: the single tolerance is where it is allowed to be

- GIVEN a line where `base × rate` differs from the printed tax
- WHEN it is evaluated
- THEN a difference of at most one minor unit is admitted
- AND no other check in the product admits any tolerance at all

---

### Requirement: legal-tax-rate-check

Any tax rate used by the pipeline SHALL be checked against the detected country's
legal rate set and SHALL be rejected when it is not legal for that country.
[Origen: Funcional §4.3 FR-VAL-007; Funcional §5 BR-08 (first half); ADR-005, ADR-019; Annex B]

#### Scenario: an illegal rate is rejected

- GIVEN a 30 % rate on any launch country
- WHEN it is checked
- THEN it is rejected as not legal

#### Scenario: a conversion mark-up is not a rate

- GIVEN a 4.5 % currency-conversion mark-up
- WHEN it is checked as a tax rate
- THEN it is rejected

---

### Requirement: repair-to-the-only-consistent-value

Where a reading fails a check digit and exactly one replacement of the offending character makes it pass, the app SHALL apply that repair, tag the value `repaired`, and present it amber with the repair visible, because the repair is correct only if every other character was read correctly. A reading with two admissible repairs SHALL not be repaired.
[Origen: Funcional §4.3 FR-VAL-008; PDR §6, §1.1; Annex D]

#### Scenario: the unique repair is applied and shown

- GIVEN a tax identifier read as `123456795` from a document whose issuer is `12345679S`
- WHEN validation runs
- THEN the value is repaired to `12345679S`
- AND it is tagged `repaired`
- AND it is shown amber with the repair visible to the user

#### Scenario: two admissible repairs means no repair

- GIVEN a reading for which two different single-character replacements each make the check digit pass
- WHEN validation runs
- THEN no repair is applied
- AND the value remains as read

---

### Requirement: currency-carries-its-own-confidence-state

Currency SHALL hold a confidence state separate from that of any amount, and a
currency that cannot be sustained from evidence SHALL suppress the writing of amounts
rather than allow a wrong-currency figure to be written. A currency that the country
row in force for a ticket declares — the photo route's currency
(`extraction-pipeline` · `currency-is-read-from-the-document`, DEC-022) — SHALL be
presented as green, with the country setting shown as its source, although no reading
and no redundancy sustains it. That green is an exception to BR-04 and to
`three-confidence-strengths`, decided for this source only (DEC-023): it SHALL NOT
extend to any amount, to any other value, or to a currency read from a document, and
the rules above on a currency that cannot be sustained still apply to every other
source of a currency.
[Origen: Funcional §4.3 FR-VAL-009; Funcional §5 BR-12; Funcional §4.3 FR-VAL-001; Funcional §5 BR-04; PDR §6 (v0.2); Finding 3; 16-document test; DEC-023]

#### Scenario: an unsustained currency suppresses the amounts

- GIVEN a document whose currency cannot be determined from its evidence
- WHEN the record is assembled
- THEN it carries no amounts
- AND it does not carry amounts in the destination table's currency

#### Scenario: the currency's state is its own

- GIVEN an amount whose reading is clean and a currency whose reading is doubtful
- WHEN their states are shown
- THEN the amount's state is not raised by the currency's or the reverse

#### Scenario: the two mis-detections of the test are caught

- GIVEN a euro receipt tagged USD and a dollar invoice tagged MAD, as the test produced
- WHEN their currencies are assessed
- THEN neither is sustained
- AND the amounts are suppressed rather than written against the wrong currency

#### Scenario: a currency from the country setting is green

- GIVEN a photographed ticket whose country in force is Spain
- WHEN the currency field's state is shown
- THEN it is green
- AND its source is shown as the country setting, not as a reading of the image

#### Scenario: the green given to the country's currency does not reach the amounts

- GIVEN a photographed ticket whose currency comes from the country setting and whose
  total passed no check
- WHEN their states are shown
- THEN the currency is green
- AND the total is amber, because nothing sustained it

---

### Requirement: what-never-reaches-green

`doc_number` SHALL never be presented as green, because receipt and invoice numbers
carry no check digit and each recognition pass produces a different variant, and
`supplier_name` SHALL be presentable as confirmed only when the supplier memory
supplies it from an identifier that passed its check digit.
[Origen: Funcional §4.3 FR-VAL-010; Funcional §5 BR-10, BR-11; PDR §6.2, §11; ADR-009]

#### Scenario: no document number is ever green

- GIVEN any document on any screen in any state
- WHEN the document number's state is inspected
- THEN it is not green
- AND each recognition pass having produced a different variant is the reason

#### Scenario: a supplier name is confirmed only from memory

- GIVEN the first sighting of a supplier
- WHEN its name is presented
- THEN it is amber

#### Scenario: memory confirms what a check digit admitted

- GIVEN a second document from a supplier whose identifier passed its check digit and is in memory
- WHEN the name is presented
- THEN it is green

#### Scenario: an identifier failing its check digit offers no memory match

- GIVEN an identifier that fails its check digit
- WHEN the supplier memory is consulted
- THEN it supplies no match

---

### Requirement: tax-slots

The model SHALL carry one slot per printed tax rate — a `tax_rate` / `tax_base` /
`tax_amount` triplet — with the number of slots declared by the country table, and
slots that do not apply SHALL stay empty. Each slot SHALL map independently, all
SHALL be optional, and `tax_total` SHALL be the sum of the printed tax amounts and
never a value computed from the gross total and an assumed rate.
[Origen: Funcional §4.3 FR-VAL-011; PDR §5.3; ADR-005; Annex B]

#### Scenario: two printed rates occupy two slots and leave a third empty

- GIVEN a German receipt printing 19 % and 7 %
- WHEN the model is populated
- THEN two slots carry values
- AND the remaining declared slot is empty
- AND the pair is not collapsed into one figure

#### Scenario: the tax total is a sum of printed amounts

- GIVEN a document printing several tax amounts
- WHEN `tax_total` is populated
- THEN it is the sum of those printed amounts
- AND it is never computed from the gross total and an assumed rate

---

### Requirement: absent-is-not-zero

A value not printed SHALL NOT be treated as a zero, and whether "not printed" means an
empty field or a contractual zero SHALL be a per-field property of the destination
mapping chosen by the user. The app SHALL never hardcode either behaviour, and the
default SHALL be to write empty.
[Origen: Funcional §4.3 FR-VAL-012; Funcional §5 BR-13; PDR §7.3, §6; 16-document test, record 1414]

#### Scenario: the destination setting decides and nothing else changes

- GIVEN a card-terminal slip with no printed VAT
- WHEN the record is written
- THEN the VAT column receives empty or zero strictly according to that field's setting
- AND changing the setting changes the written value and nothing else

#### Scenario: the default is empty, not zero

- GIVEN a field with no per-field setting made
- WHEN a value is not printed
- THEN an empty value is written
- AND zero is not substituted for it

#### Scenario: a correct zero is not an absence

- GIVEN a card-terminal slip whose VAT column legitimately receives zero deductibly
- WHEN the record is written under a setting that writes zero
- THEN the zero is the correct accounting value
- AND it is not reported as an error

---

### Requirement: date-coherence-and-ambiguity

The validation layer SHALL check dates for coherence, and where the document's own
evidence does not decide between two readings of a date SHALL flag it as ambiguous
rather than silently assume one.
[Origen: Funcional §4.3 FR-VAL-013; PDR §10, §5.1; ADR-005]

#### Scenario: an unambiguous date is read

- GIVEN a document printing `27.08.2026`
- WHEN the date is read
- THEN it is 27 August 2026

#### Scenario: an undecidable date is flagged, not assumed

- GIVEN a document printing `03/04/2026` with no disambiguating evidence
- WHEN the date is read
- THEN it is flagged as ambiguous
- AND neither the third of April nor the fourth of March is assumed silently

#### Scenario: coherence is checked

- GIVEN a date that parses to a value the document cannot support
- WHEN it is validated
- THEN it is not presented as confirmed

---

### Requirement: determinism-over-coverage

A value SHALL be presented as confirmed only when a deterministic constraint
establishes it from values that were themselves read and not derived by assumption,
and the app SHALL prefer admitting doubt to guessing convincingly.
[Origen: Funcional §4.3 FR-VAL-014; Funcional §5 BR-01; PDR §4; Funcional §2.4 contract line 4]

#### Scenario: this requirement holds when its three parts hold

- GIVEN `three-confidence-strengths`, `a-check-confirms-only-if-every-operand-was-read` and `extraction-pipeline`'s `derive-by-identity-never-invent-a-rate`
- WHEN all three are satisfied
- THEN this requirement is satisfied, because its acceptance is their conjunction

#### Scenario: doubt is preferred to a convincing guess

- GIVEN a value the app cannot establish deterministically
- WHEN a plausible alternative exists
- THEN the doubt is admitted rather than the plausible value presented as confirmed

---

### Requirement: empty-over-false

When the app cannot sustain a value it SHALL write nothing rather than a
plausible-looking number, and this SHALL be the default behaviour rather than a
fallback.
[Origen: Funcional §5 BR-03; PDR §4; 16-document test]

#### Scenario: an unsustained amount is written as nothing

- GIVEN a document whose currency cannot be sustained
- WHEN the record is written
- THEN no amounts are written

#### Scenario: an unprinted rate yields no breakdown

- GIVEN a document whose rate is not printed
- WHEN the record is written
- THEN no breakdown is written

#### Scenario: the empty field is the deliberate outcome

- GIVEN an abstention on a mapped field
- WHEN the outcome is reviewed
- THEN it is presented as a deliberate empty value
- AND it is not presented as an omission or a failure to be retried

---

## Out of Scope

- **Every check-digit algorithm and every legal rate set.** `countries-languages` owns
  the algorithms, including that the three Spanish formats never share code. FR-CTR-004
  and FR-VAL-005 state that separation twice and it is owned once; this capability
  owns that the validators exist and are accepted against vectors.
- **Where a value came from.** Reading, the route priority, consensus, derivation and
  the provenance tags are `extraction-pipeline`'s. This capability consumes provenance
  and would be unimplementable without it.
- **Reading the currency.** `extraction-pipeline` (FR-EXT-013) reads it from the
  printed ISO code, the symbol and the issuer country. This capability owns whether it
  can be sustained, and what happens to the amounts when it cannot.
- **Applying the negative-context dictionary.** The terms are `countries-languages`';
  the application rule and the influence radius are `extraction-pipeline`'s.
- **The write path and the mapping.** `destinations-mapping` owns the per-field
  absent-versus-zero setting, the payload and the formula-field contrast;
  `ninox-send` owns writing and reading back.
- **How a state is drawn.** The colour, the lock icon, the field order and the collapse
  rules are `review-screen`'s. This capability fixes what each state means and what may
  be shown as confirmed.
- **The numeric threshold for the photo route's accuracy.** §10.5 defers it to the
  first corpus screening (GAP-003), and neither this spec nor
  `extraction-pipeline` states one.
- **Storing the supplier memory.** `supplier-memory` owns the store, its indexing
  safeguard and its deletion. This capability owns only that a name may be presented
  as confirmed exclusively from it.

---

## Cross-Capability References

- `extraction-pipeline` — produces every value and its provenance tag, and owns the
  read-before-derive rule and the derive-by-identity boundary whose consequences this
  capability evaluates. Provenance is this capability's input and cannot be produced
  here.
- `countries-languages` — owns the check-digit algorithms, the legal rate sets per
  country, the declared slot count and the format-inference algorithm. This capability
  owns that the checks run and what their outcome means.
- `review-screen` — renders the state this capability determines, and owns the lock
  affordance, the field order and the collapse rules.
- `destinations-mapping` — owns the per-field absent-versus-zero setting and the write
  path that consumes the final decision, plus the formula-field contrast.
- `supplier-memory` — owns the store whose contents are the only way a supplier name
  may reach green.
- `ninox-send` — owns writing the values and reading them back.

---

## Open Questions

- **GAP-003** — the acceptance thresholds for product metrics are deferred to the first
  corpus screening, and **GAP-001** (ADR-010, the recognition engine) is what the
  screening waits on. No requirement in this capability states a numeric threshold, so
  neither gap blocks it.
- **GAP-009** — the formula-field contrast has a known blind spot and does not catch a
  total misread and then used to derive its own components. That is why
  `a-check-confirms-only-if-every-operand-was-read` is written as a rule about
  provenance rather than as a rule about contrasts: the contrast is a second-line check
  in `destinations-mapping`, and this requirement is the first line.
- **Settled before writing.** Whether the supplier-memory half of
  `what-never-reaches-green` belongs here or in `supplier-memory`: it is here, because
  it is a statement about what may be shown as confirmed, while `supplier-memory` owns
  the store and its safeguard. Recorded in `openspec/project.md` §3.3 so that
  `supplier-memory` references it rather than restating it.
- **A note on record 1414.** The product owner overruled both the consultant and an
  earlier internal reading on that record: a card-terminal slip whose VAT column
  received `0,00` was correct, because the column is *deductible VAT* and a slip that
  prints no breakdown justifies deducting nothing. That verdict is the origin of
  `absent-is-not-zero`'s third scenario, and the general principle it overrides — that
  an unknown value is never a zero — survives as the default in the second scenario.
