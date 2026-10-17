## MODIFIED Requirements

### Requirement: consensus-by-majority

Where a value has several candidate readings, the value a **majority** of passes agree on SHALL win, and a single outlier SHALL never override agreement between the others however extreme its apparent confidence. Arithmetic SHALL be applied only to operands that passed consensus.

A value read once from a PDF's **text layer** SHALL pass consensus on its own,
without a second pass. The text layer is a deterministic read of the document's
encoded content, not a recognition estimate: re-extracting the same layer returns
the same candidate, so there is no variation between passes for a majority to
arbitrate, and the pipeline SHALL NOT withhold such a value from consensus for
lack of a second reading. This SHALL NOT extend to an OCR-recognition reading — a
photograph, a rendered page of a scanned PDF, or a mixed page with no text layer —
which remains a recognition estimate and SHALL continue to need agreement between
several passes exactly as before.
[Origen: Funcional §4.2 FR-EXT-006; Funcional §5 BR-06; ADR-019; 16-document test; DEC-018]

#### Scenario: three agreeing passes beat one outlier

- GIVEN four recognition passes, three reading `19.99` and one reading `19.98`
- WHEN the value is chosen
- THEN `19.99` is used
- AND the arithmetic consumes `19.99`, not `19.98`

#### Scenario: a maximum-across-passes implementation fails

- GIVEN an implementation that takes the highest candidate across passes
- WHEN it is tested on the case above
- THEN it fails, because one noisy pass overruled three that agreed

#### Scenario: arithmetic sees only agreed operands

- GIVEN a document whose base passed consensus and whose tax did not
- WHEN any arithmetic runs
- THEN it does not consume the disputed tax value

#### Scenario: a text-layer reading passes consensus alone

- GIVEN a PDF page with a text layer, read once through the positional text route
- WHEN consensus is evaluated for a value read from that layer
- THEN the single reading passes consensus
- AND no second pass is required or awaited

#### Scenario: an OCR reading still needs agreement between passes

- GIVEN a photographed receipt or a rendered page of a scanned PDF, read through
  the OCR pipeline
- WHEN consensus is evaluated for a value read from it
- THEN the value must still be agreed by a majority of passes
- AND a single OCR pass does not pass consensus alone
