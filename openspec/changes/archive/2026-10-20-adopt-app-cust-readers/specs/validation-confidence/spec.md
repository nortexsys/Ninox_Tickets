## MODIFIED Requirements

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

## Out of Scope

- **Reading the currency and the currency a row declares.** `extraction-pipeline`
  (FR-EXT-013) owns both: which currency the photo route takes, that it is recorded
  with the country setting as its origin, and that the other routes still read it from
  the document. This capability owns the state it is shown in.
- **How a green state is drawn, locked and unlocked.** `review-screen` owns the colour,
  the lock icon and the field order; `green-is-editable-only-after-unlocking` is
  unchanged by this decision.
- **Which country is in force and what its row supplies.** `countries-languages` owns
  the country input, the table and the row (`country-is-an-input`). This capability
  consumes the currency the row declares.
- **The amounts' own states under a green currency.** Unchanged: an amount still
  reaches green only through redundancy it can show, and the exception above names the
  currency field and nothing else.

---

## Cross-Capability References

- `extraction-pipeline` — owns reading the currency, the photo route's currency from
  the country row, and the provenance and origin recorded with every value
  (`currency-is-read-from-the-document`).
- `countries-languages` — owns the country table, the country input and the row that
  declares the currency (`country-is-an-input`, `launch-rows`).
- `review-screen` — renders the state this capability determines, and shows the source
  of the country's currency so that it is not mistaken for a reading
  (`country-shown-and-editable-per-ticket`).

---

## Open Questions

- **None added by this change.** GAP-037 is closed by DEC-023 and carried into the two
  requirements above; no other question of this capability is touched here.
