## MODIFIED Requirements

### Requirement: three-confidence-strengths

A value's confidence SHALL be one of three strengths: **confirmed by redundancy**,
where two values each read independently agree through an identity (strong);
**consistent with a check digit** (medium); or **repaired to the only consistent
value** (weak). Only the first SHALL be shown green with a lock, the other two SHALL
be amber, and an amount with no independent figure to cross against SHALL never be
green however cleanly it was read.

**Confirmed by redundancy** also covers a value read once from a PDF's **text
layer**, with no second reading and no breakdown to cross against, when all three
of the following hold: every operand the value depends on was itself read from
that text layer, never derived; where an arithmetic identity over those operands
is checkable (every operand needed for it was read), the identity SHALL hold; and
where no identity is checkable because only one operand was printed, the
text-layer reading alone SHALL stand as confirmed. The text layer is itself the
independent evidence this requirement asks for: it is a deterministic read of the
document's encoded content, not an estimate that a second pass could contradict.
This exception SHALL NOT extend to a value read by optical recognition — a
photograph, a rendered page of a scanned PDF, or a mixed page with no text layer —
which SHALL remain amber with no independent figure to cross against, exactly as
before. A derived operand SHALL still never raise a check to green (PRE-008,
BR-05), and an arithmetic check that fails SHALL still lower confidence rather than
being overridden by the route, on a text-layer reading exactly as on any other.
[Origen: Funcional §4.3 FR-VAL-001; Funcional §5 BR-04; PDR §6; Finding 5; DEC-018]

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

#### Scenario: a text-layer reading with nothing to cross against is green

- GIVEN a total read once from a PDF's text layer, with no breakdown printed to
  cross against and no derived operand feeding it
- WHEN its state is shown
- THEN it is green and locked

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
