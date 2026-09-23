# extraction-pipeline Specification

## Purpose
A recognition pass produces **candidates**, not values. Turning candidates into
values requires three rules and a memory: which candidate wins, where a value may
legitimately come from, and which of those rules produced it â€” because a check that
consumes a value must be able to tell whether that value was read or computed.
Without that memory, every arithmetic check confirms itself.

That is not a hypothetical. In the 16-document test, nine of the ten records
reported as arithmetically verified had computed the base and the tax from the
total and then checked that the parts add up. The check passes by construction. With
a total misread as 19,98 the breakdown comes out 16,51 + 3,47; with the real 19,99 it
comes out 16,52 + 3,47. Both add up, and no amount of arithmetic can tell them
apart. Only reading the printed quantities can.

The same test produced two other structural defects: the pipeline took the
**maximum** across recognition passes, so one noisy pass overruled three that
agreed; and it **invented tax rates** the document never stated â€” 9 %, 30 % and a
4.5 % currency-conversion mark-up, none legal in Spain and one legal nowhere in the
EU.

Every rule in this capability is therefore a rule about **where a value may come
from**, and every one of them exists because its absence produced a confident wrong
number rather than an error.

---
## Requirements
### Requirement: pipeline-order-is-fixed

The extraction pipeline SHALL run in this order and no other: (1) consensus between
candidate readings; (2) read all printed quantities, matching independently read
candidates against each other; (3) derive by identity only, from read values;
(4) validation; (5) write; (6) read back; (7) compare with the destination's formula
fields. No stage SHALL consume the output of a stage that runs after it.
[Origen: Funcional Â§4.2 FR-EXT-001; PDR Â§6.1, Â§7.4; ADR-019]

#### Scenario: the seven stages appear in order

- GIVEN the implemented pipeline
- WHEN its stages are inspected
- THEN the seven stages appear in the order given above
- AND no stage consumes the output of a stage that runs after it

#### Scenario: derivation never precedes reading

- GIVEN a document printing base, tax and total
- WHEN the pipeline runs
- THEN all three quantities are read at stage 2
- AND no quantity is computed from the others at stage 2

---

### Requirement: invoice-route-priority

The invoice route SHALL try extraction methods in a fixed order and stop at the
first that succeeds: (1) embedded or attached XML â€” ZUGFeRD or Factur-X inside the
PDF, or a standalone XRechnung â€” read deterministically with provenance `from_xml`;
(2) the PDF's text layer, extracted with word-level positions; (3) page render and
OCR, exactly like the photo route. The route taken SHALL be recorded in the
recognition-engine metadata.
[Origen: Funcional Â§4.2 FR-EXT-002; ADR-014; Finding 12]

#### Scenario: a hybrid e-invoice takes the XML route and stops

- GIVEN a Factur-X PDF carrying embedded XML
- WHEN it is extracted
- THEN the XML route is taken
- AND no OCR pass runs on it

#### Scenario: a plain text-layer PDF takes the text route

- GIVEN a PDF with a text layer and no embedded XML
- WHEN it is extracted
- THEN the positional text route is taken

#### Scenario: a scanned PDF falls through to OCR

- GIVEN a PDF with neither a text layer nor embedded XML
- WHEN it is extracted
- THEN its pages are rendered and go through the OCR route

#### Scenario: the route taken is recorded

- GIVEN any extracted document
- WHEN its recognition-engine metadata is inspected
- THEN it names the route that produced the values

---

### Requirement: structured-xml-extraction

XML extraction SHALL be deterministic, field by field, and SHALL distinguish
XRechnung's syntaxes (UBL and CII) and the ZUGFeRD and Factur-X profile levels. A
field the profile does not carry SHALL be reported as `not_in_xml` and never as
absent. Extraction SHALL be a read-only operation on the PDF that carries the XML.
[Origen: Funcional Â§4.2 FR-EXT-003; ADR-014, ADR-015]

#### Scenario: a full-profile sample is read deterministically

- GIVEN an `EN16931` sample
- WHEN it is extracted
- THEN every field the profile carries is read
- AND each carries provenance `from_xml`

#### Scenario: a low-profile sample keeps the third state

- GIVEN a `MINIMUM` sample whose profile omits a field
- WHEN it is extracted
- THEN that field is reported as `not_in_xml`
- AND it is never reported as absent and never as zero

#### Scenario: the carrying PDF is not modified

- GIVEN a PDF carrying embedded XML
- WHEN the XML is extracted from it
- THEN the PDF is unmodified afterwards

---

### Requirement: positional-pdf-text-extraction

Text-layer extraction SHALL associate a label with the value nearest it in the
document's **visual layout**, using word-level coordinates. Plain-text extraction â€”
associating by extraction order alone â€” SHALL NOT be accepted as an implementation.
[Origen: Funcional Â§4.2 FR-EXT-004; ADR-011; 16-document test, PRO1013-26]

*Acceptance is blocked by ADR-011, the library selection (GAP-002). The behaviour
above is fixed; the test cannot run until the library is chosen.*

#### Scenario: a label on another line still binds its value

- GIVEN an invoice where a label and its value are printed on different text lines
- WHEN the value is bound
- THEN the binding follows the visual layout, not the extraction order

#### Scenario: a registry volume is not bound to a total label

- GIVEN a document printing a commercial-register volume reference such as
  `Tomo 8.741` near a total label
- WHEN values are bound
- THEN the volume reference is not bound as the total
- AND the failure this rule exists to prevent does not occur

---

### Requirement: render-and-ocr-fallback

A PDF with no text layer and no XML SHALL have its pages rendered and sent through
the OCR pipeline exactly like the photo route, with consensus and validation
applying. Rendering SHALL be read-only and the source file SHALL never be re-saved.
[Origen: Funcional Â§4.2 FR-EXT-005; ADR-010, ADR-014, ADR-015]

*Acceptance is blocked by ADR-010, the recognition engine (GAP-001).*

#### Scenario: a scanned PDF is read through the render route

- GIVEN a scanned PDF with no text layer
- WHEN it is extracted
- THEN its pages are rendered and read through the OCR pipeline
- AND consensus and validation apply as they do on the photo route

#### Scenario: the source file survives rendering

- GIVEN a scanned PDF
- WHEN it has been rendered for OCR
- THEN the source file is unmodified
- AND it is attached exactly as received

---

### Requirement: consensus-by-majority

Where a value has several candidate readings, the value a **majority** of passes agree on SHALL win, and a single outlier SHALL never override agreement between the others however extreme its apparent confidence. Arithmetic SHALL be applied only to operands that passed consensus.
[Origen: Funcional Â§4.2 FR-EXT-006; Funcional Â§5 BR-06; ADR-019; 16-document test]

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

---

### Requirement: read-all-printed-quantities-before-deriving

The pipeline SHALL attempt to read **all** operands of an amount breakdown as they
are printed, matching independently read candidates against each other, before
computing any of them from the others. Where a quantity cannot be read, the pipeline
SHALL leave it empty rather than reconstruct it.
[Origen: Funcional Â§4.2 FR-EXT-007; PDR Â§6.1; ADR-019; 16-document test]

#### Scenario: three printed quantities are read, none derived

- GIVEN a document printing base, tax and total
- WHEN the breakdown is assembled
- THEN all three are read
- AND none is tagged `derived`

#### Scenario: two printed quantities permit one derivation by identity

- GIVEN a document printing only the total and the tax
- WHEN the breakdown is assembled
- THEN the base may be derived by identity
- AND it is tagged `derived`

#### Scenario: one printed quantity leaves the breakdown empty

- GIVEN a document printing only the total
- WHEN the breakdown is assembled
- THEN no base, no tax and no rate is written
- AND the breakdown stays empty

---

### Requirement: derive-by-identity-never-invent-a-rate

Deriving a value by **identity from read values** SHALL be permitted, SHALL be
tagged `derived`, and SHALL carry **no confirmatory effect** on the confidence
state. Deriving a value by assuming a rate the document does not state SHALL never
be permitted, and where the rate is not printed the breakdown SHALL stay empty.
[Origen: Funcional Â§4.2 FR-EXT-008; Funcional Â§5 BR-07; ADR-019; 16-document test]

#### Scenario: a total with no printed rate yields no breakdown

- GIVEN a document printing a total and no tax rate
- WHEN the pipeline runs
- THEN no base and no tax are computed
- AND no rate is assumed in order to produce them

#### Scenario: a derived base confers nothing

- GIVEN a document printing the total and the tax
- WHEN the base is derived as `total âˆ’ tax`
- THEN it is tagged `derived`
- AND a later `base + tax = total` check does not raise the total's confidence

#### Scenario: the invented rates of the test are impossible

- GIVEN the three rates the 16-document test produced â€” 9 %, 30 % and a 4.5 %
  currency-conversion mark-up
- WHEN each is considered for a derivation
- THEN none is used, because none was printed as a tax rate

---

### Requirement: legal-rate-gate-before-derivation

The pipeline SHALL NOT use a tax rate for any derivation until the validation layer
has admitted it against the detected country's legal set, and a rate the check
rejects SHALL be discarded rather than used.
[Origen: Funcional Â§4.2 FR-EXT-009; Funcional Â§5 BR-08 (first half); ADR-005, ADR-019; 16-document test]

#### Scenario: a rejected rate cannot drive a derivation

- GIVEN a Spanish document printing a 30 % rate
- WHEN the rate is gated
- THEN it is rejected as not legal for Spain
- AND it is not used to derive any breakdown

#### Scenario: the gate runs before the derivation, not after

- GIVEN a rate that has not yet been gated
- WHEN a derivation is attempted
- THEN the derivation does not proceed

---

### Requirement: negative-context-suppresses-non-tax-figures

The pipeline SHALL apply the negative-context dictionary to suppress candidates
that are percentages or numbers in the document but are not tax figures, and
candidates suppressed this way SHALL NOT be bound to a tax label. Suppressed
surcharge-like amounts SHALL be captured as `surcharges[]` with an appropriate
label where the document supports it.
[Origen: Funcional Â§4.2 FR-EXT-010; Funcional Â§5 BR-08 (second half); ADR-019; 16-document test, PRO1013-26 and record 1428; Annex C]

#### Scenario: a conversion mark-up is not a tax rate

- GIVEN a document printing a DCC mark-up percentage
- WHEN tax candidates are considered
- THEN the mark-up is not read as a tax rate
- AND a surcharge entry is recorded instead

#### Scenario: registry boilerplate is not a total

- GIVEN a document whose only number near a total label is a registry volume
  reference
- WHEN the total is bound
- THEN that number is not used as the total

#### Scenario: the suppression covers the printed languages of the market

- GIVEN the dictionary's terms in Spanish, German, French and English
- WHEN a candidate falls within the influence radius of any one of them
- THEN it is suppressed as a tax candidate

---

### Requirement: provenance-on-every-value

Every extracted value SHALL carry a provenance tag â€” `read`, `derived`, `repaired`
or `from_xml` â€” held internally alongside the confidence state. Provenance SHALL
never be written to Ninox, and SHALL determine whether a consuming check may raise
the confidence state.
[Origen: Funcional Â§4.2 FR-EXT-011; PDR Â§6.1; ADR-019; Funcional Â§1.5]

#### Scenario: every value is tagged

- GIVEN a document that has been extracted
- WHEN the review model is inspected
- THEN every value carries one of the four provenance tags

#### Scenario: provenance does not leave the device

- GIVEN a destination with every field mapped
- WHEN the payload is built
- THEN it contains no provenance field

#### Scenario: a derived operand cannot confirm

- GIVEN a check whose operands include at least one `derived` value
- WHEN the check succeeds
- THEN the confidence state is not raised

---

### Requirement: multi-page-consolidation

For a multi-page document the pipeline SHALL read every page and consolidate into a
single canonical model, with one value per field and provenance per value.
[Origen: Funcional Â§4.2 FR-EXT-012; PDR Â§7.1]

#### Scenario: totals continuing on a second page produce one model

- GIVEN a two-page invoice whose totals appear on the second page
- WHEN it is extracted
- THEN one consolidated canonical model is produced, not two
- AND the page that contributed each value is recorded internally

---

### Requirement: currency-is-read-from-the-document

Currency SHALL be extracted from the document's own evidence â€” the printed ISO code,
the symbol, the issuer country â€” and SHALL never be defaulted to the table's
currency.
[Origen: Funcional Â§4.2 FR-EXT-013; PDR Â§6 (v0.2); Finding 3]

#### Scenario: a euro receipt is tagged EUR

- GIVEN a receipt paid in euros in Madrid
- WHEN the currency is read
- THEN it is EUR

#### Scenario: a dollar invoice is not turned into euros

- GIVEN an invoice issued in the United States and printed in dollars
- WHEN the currency is read
- THEN it is USD
- AND the table's currency is not substituted for it

#### Scenario: an unreadable currency is not defaulted

- GIVEN a document whose currency cannot be read from any of its evidence
- WHEN extraction completes
- THEN the currency is left unsustained rather than defaulted
- AND the consequence for the amounts is the validation layer's, not invented here

---

### Requirement: multilingual-label-dictionaries

Label dictionaries SHALL cover the document languages the product expects,
independently of the interface language, since a German user may well scan a French
invoice.
[Origen: Funcional Â§4.2 FR-EXT-014; PDR Â§10; ADR-005; Annex C]

#### Scenario: labels bind regardless of interface language

- GIVEN the interface set to English
- WHEN a French invoice labelled `Total Ã  payer` and a German invoice labelled
  `Zu zahlen` are extracted
- THEN each binds its total correctly

#### Scenario: the label language does not follow the interface

- GIVEN an interface language the document does not use
- WHEN values are bound
- THEN the dictionary consulted is the document's, not the interface's

---

### Requirement: photo-route-recognition-quality

The photo route SHALL produce candidate readings of sufficient quality that, after
consensus and validation, per-field accuracy over the screening corpus meets the
threshold fixed in Â§10.5.
[Origen: Funcional Â§4.2 FR-EXT-015; ADR-010; PDR Â§12, Â§13]

*Acceptance is blocked by ADR-010, the engine selection, and by the corpus
extension its closure criterion requires (GAP-001). The threshold itself is
deferred to the first corpus screening (GAP-003), so no number is stated here.*

#### Scenario: accuracy is measured on the right population

- GIVEN the photographed-paper screening corpus
- WHEN per-field accuracy is measured
- THEN only values with provenance `read` or `from_xml` are counted
- AND the measurement runs after validation, not before it

#### Scenario: the threshold is the one Â§10.5 fixes

- GIVEN the screening has been run
- WHEN the result is compared against the release criterion
- THEN it is compared against the threshold fixed in Â§10.5
- AND no threshold invented outside that section is used

---

### Requirement: dates-come-only-from-the-document

`doc_date` SHALL never be derived from a filename or from a received-email
timestamp, and SHALL be read from the document itself.
[Origen: Funcional Â§5 BR-20; PDR Â§5.1, Â§10]

#### Scenario: a dated filename does not supply the date

- GIVEN a file named `2026-08-27_invoice.pdf` whose document prints no date
- WHEN the record is assembled
- THEN the date is empty
- AND the filename's date is not used

#### Scenario: a mail container does not supply the date

- GIVEN a document received as a mail attachment
- WHEN the record is assembled
- THEN the received-email timestamp is not used as `doc_date`

---

## Out of Scope

- **Deciding whether a value may be trusted.** The three confidence strengths, the
  confirmatory rule, the repair-to-the-only-consistent-value rule, the
  green/amber/red state and the meaning of absent at the destination are
  `validation-confidence`.
- **Which tax rates are legal, and every check-digit algorithm.** `countries-languages`
  owns the data and the algorithms. This capability owns the **gate** that consumes
  the legal-rate check and the `not_in_xml` status it produces â€” not the check
  itself, nor what `not_in_xml` means for absent-versus-zero, which is FR-VAL-012's.
- **Currency's confidence state.** This capability reads the currency from the
  document's evidence; whether it can be sustained, and that an unsustained currency
  suppresses the amounts, are FR-VAL-009's.
- **Date coherence, the ambiguity outcome and the format-inference algorithm.**
  Format inference is `countries-languages` (FR-CTR-005) and date coherence is
  FR-VAL-013. This capability owns only that the date is never taken from a filename
  or an email.
- **Getting the document in and keeping its bytes intact.** `capture-intake` owns
  intake and byte integrity.
- **Writing, attaching and reading back.** Stages 5 to 7 of the pipeline order are
  performed by `ninox-send`, which owns the payload, the retry matrix and the
  read-back. This capability fixes the order they occupy.
- **The shape of the canonical data model.** Â§6.1 of the functional specifies it;
  this capability specifies which values may populate it and with what provenance.

---

## Cross-Capability References

- `validation-confidence` â€” owns everything that decides whether a value is
  trustworthy: the three strengths (FR-VAL-001), the confirmatory rule that consumes
  this capability's provenance tags (FR-VAL-002), the check-digit validators
  (FR-VAL-005), the redundancy checks and their single tolerance (FR-VAL-006), the
  legal-rate check (FR-VAL-007), repair (FR-VAL-008), currency's confidence state
  (FR-VAL-009), what never reaches green (FR-VAL-010), tax slots (FR-VAL-011),
  absent-versus-zero (FR-VAL-012) and date coherence (FR-VAL-013).
- `countries-languages` â€” owns the legal rate sets, the check-digit algorithms and
  the format-inference algorithm, and supplies the label and negative-context
  dictionaries whose **content** it owns while this capability owns their
  application.
- `capture-intake` â€” produces the file or PDF this capability reads, and owns byte
  integrity, which is what keeps the XML route available at all (FR-CAP-005).
- `ninox-send` â€” performs pipeline stages 5 to 7 and owns the read-back.
- `destinations-mapping` â€” owns the formula fields that stage 7 compares against,
  and the per-field absent-versus-zero setting.

---

## Open Questions

- **GAP-001** (ADR-010, recognition engine) blocks the acceptance of
  `render-and-ocr-fallback` and `photo-route-recognition-quality`, and is the reason
  the latter states no numeric threshold: Â§10.5 defers it to the first corpus
  screening, tracked as **GAP-003**.
- **GAP-002** (ADR-011, PDF text-extraction library) blocks the acceptance of
  `positional-pdf-text-extraction`. The requirement fixes the criterion the library
  must satisfy â€” word-level coordinates, binding in the visual layout â€” which is
  exactly what ADR-011's closure criterion asks it to confirm.
- **GAP-009** (the formula-field contrast's blind spot) is a `destinations-mapping`
  and `ninox-send` concern, but it is recorded here too because stage 7 of the
  pipeline order is where that contrast sits: it does **not** catch a total misread
  and then used to derive its own components. Only
  `read-all-printed-quantities-before-deriving` and
  `derive-by-identity-never-invent-a-rate` protect against that, which is why they
  are written as requirements rather than left to the check.
- **Settled before writing.** Four boundaries that the functional states more than
  once are recorded in `openspec/project.md` Â§3.3: the legal-rate check versus the
  gate that consumes it, currency reading versus currency confidence, format
  inference versus date coherence versus the `doc_date` source rule, and producing
  `not_in_xml` versus knowing what it means. Without those rows, three of these
  requirements would have restated a rule owned elsewhere.
- **The `surcharges[]` shape is not specified here.** `negative-context-suppresses-non-tax-figures`
  requires that a suppressed surcharge-like amount is captured with an appropriate
  label where the document supports it; the entry's field structure belongs to the
  canonical data model in Â§6.1 of the functional, not to this capability.
