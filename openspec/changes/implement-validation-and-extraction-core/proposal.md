# Change: implement-validation-and-extraction-core

## Why

The product's claim is that a reading is established rather than trusted, and every rule that
makes that true is unbuilt. Not one of them is a convenience. Consensus by majority is what fails
when a pipeline takes the maximum across passes — the 16-document test let one noisy pass overrule
three that agreed, and turned `96.76` into `9.676,00`. The read-before-derive boundary is what fails
when a solver computes backwards from a total it misread: nine of the ten records the test reported
as arithmetically verified had derived base and tax from the gross and then confirmed the parts add
up, which is a tautology that passes at `19,98` as easily as at `19,99`. The invented rates — 9 %,
30 % and a 4,5 % conversion mark-up — are what fails when a rate the document never printed is
admitted. And the label–value binding is what failed on `PRO1013-26`, where a text layer gave the
label on one line and its value on another and a last-resort fallback bound a commercial-registry
volume, `Tomo 8.741`, as the total instead of `742,42`.

Plan v0.2 §9 puts all of that in one W2 change because it is one thing: the deterministic layer that
reads a document and decides what the values are, in the order `pipeline-order-is-fixed` fixes. It
is also the change the critical path runs through (plan §9.3): its layout reasoning is what the
PDF adapter of `close-adr-011-pdf-text-route` is measured against and what T1.16's OCR adapter
feeds, and its solver is what the photo route's accuracy is measured after. Nothing downstream can
be integrated without it.

Two things that are not code sit inside that, and both are decided here rather than rediscovered
later. **The positioned-word types are this change's first deliverable**, because two lanes need the
same shape at the same time and a rule that decides a value may not live in `app/`
(plan §7.2's shared-contract rule; `close-adr-011-pdf-text-route` design §3, which the Mobile lane
has already written against). Core publishes `PositionedWord` and `TextPage` as the first commit of
this change, before any layout logic, exactly as T1.1–T1.2 were published first, and Mobile's
adapter and the OCR adapter fill them. And **the five documents of the 16-document test that failed
never enter the repository**: the corpus is outside the tree by design, and what ships is synthetic
reproductions of the structure that failed plus numbers from private runs — no document content, no
supplier name, no printed value of a real invoice.

## What Changes

An **implementation-only change** (`skip_specs: true`, plan §8.2). No requirement is added,
modified, removed or renamed, and no living spec is touched. All code goes in
`packages/paperdrop_core/`, continuing the package `implement-core-model-and-countries` built.

* **The positioned-word contract, first** (plan §5; `close-adr-011-pdf-text-route` design §3).
  `PositionedWord` (`text`, `x0`, `x1`, `top`, `bottom`, in PDF points with a top-left origin) and
  `TextPage` (`index`, `width`, `height`, `words`, `hasTextLayer`) published as the change's first
  commit, before any layout logic. The field names are pdfplumber's, so the reference extraction, the
  evaluation harness and the model agree without a mapping; the units and origin are what the
  ADR-011 harness already writes. `hasTextLayer` is false on a page that yields no word, which is
  what T2.1's fall-through to OCR needs — the decision to fall through is T2.1's, not this change's.
  The adapter that produces these pages is Mobile's (`close-adr-011-pdf-text-route` for PDF text,
  `implement-photo-route` for OCR); this change defines the shape and consumes it.
* **T1.5 — layout reasoning and consensus** (plan §9 M1). The rule a label binds the value nearest
  it in the document's **visual layout** — same line to the right, else the line below, in reading
  order — over pages of positioned words, with the label dictionaries T1.4 published; never binding
  by extraction order (`positional-pdf-text-extraction`'s logic half, which ADR-011 exists to make
  possible and `close-adr-011-pdf-text-route`'s adapter half exists to feed). Consensus by majority
  over candidate readings, arithmetic on agreed operands only, and a single outlier never overriding
  agreement between the others (`consensus-by-majority`).
* **T1.6 — the amount solver** (plan §9 M1). Reading **all** printed operands before deriving any,
  matching independently read candidates against each other in the approach of the prototype's
  `solve_amounts.py`; derivation by identity only, tagged `derived` and carrying no confirmatory
  effect; the legal-rate **gate** before any derivation, consuming the check `countries-languages`
  owns; negative-context suppression with the influence radius, capturing suppressed surcharge-like
  amounts as `surcharges[]`; and currency read from the document's own evidence with its own state,
  never defaulted to the table's currency
  (`read-all-printed-quantities-before-deriving`, `derive-by-identity-never-invent-a-rate`,
  `legal-rate-gate-before-derivation`, `negative-context-suppresses-non-tax-figures`,
  `currency-is-read-from-the-document`, `provenance-on-every-value`'s producing half).
* **T1.7 — confidence, repair and the honest empty** (plan §9 M1). The three strengths and what each
  means, the confirmatory rule over provenance, the redundancy checks in integer minor units with
  exact equality and the single one-minor-unit tolerance, the check-digit validators' acceptance
  against vectors, repair to the only consistent value, the never-green rules, tax slots,
  absent-not-zero as the destination's property, date coherence and ambiguity, and the empty written
  by default rather than as a fallback (`three-confidence-strengths` … `empty-over-false`).
* **Annex D.1–D.5 as acceptance tests**, and the five failed documents as **private** regressions.
  Each worked example of Annex D is a runnable test, negative variants included: D.1's two EAN-13
  candidates, D.2's `123456795 → 12345679S`, D.3's `1652 + 347 = 1999` with its negative variant,
  D.4's 4,5 % mark-up suppressed and captured as `dcc_markup`, D.5's derived-base tautology
  confirming nothing. The five documents the 16-document test failed are regressions **outside the
  repository**: synthetic reproductions of the structure that failed, plus private runs over the
  private corpus whose **numbers only** are reported.

## Requirements implemented

Identifiers as the functional spells them; the requirement name is the one that owns the behaviour
in `openspec/specs/`. Each item states the part this change satisfies, because most of these
requirements have a half that belongs to a later change.

* **FR-EXT-004** — `extraction-pipeline` · `positional-pdf-text-extraction`: **the logic half** —
  the binding rule itself, that a label binds the value nearest it in the visual layout and never
  the nearest in extraction order, and the `PositionedWord` / `TextPage` contract it is written
  against. The adapter half is `close-adr-011-pdf-text-route`'s (Mobile, T1.15), which returns pages
  of positioned words from the library ADR-011 selects; the route selection that stops at positional
  text or falls through to OCR is T2.1's. The requirement's acceptance note still says *blocked by
  ADR-011*: the adapter is decided Tue 6 Oct and this change's binding rule runs against whatever it
  produces, which is why the contract is published first.
* **FR-EXT-006** — `extraction-pipeline` · `consensus-by-majority`: in full. The majority wins, a
  single outlier never overrides agreement, and arithmetic runs only on operands that passed
  consensus. The multi-pass *strategy* that produces the candidates is the OCR adapter's (T1.16).
* **FR-EXT-007** — `extraction-pipeline` · `read-all-printed-quantities-before-deriving`: in full.
  All operands are read as printed before any is computed; what cannot be read stays empty.
* **FR-EXT-008** — `extraction-pipeline` · `derive-by-identity-never-invent-a-rate`: in full.
  Identity derivation is permitted, tagged `derived` and carries no confirmatory effect; a rate the
  document does not state is never assumed, and without a printed rate the breakdown stays empty.
* **FR-EXT-009** — `extraction-pipeline` · `legal-rate-gate-before-derivation`: **the gate** — a rate
  is not used for any derivation until it has been admitted against the detected country's legal
  set, and a rejected rate is discarded. The legal-rate **check** and the rate sets themselves are
  `countries-languages`' (`legal-tax-rate-check` is listed again below because this change makes the
  validation layer that runs it).
* **FR-EXT-010** — `extraction-pipeline` · `negative-context-suppresses-non-tax-figures`: **the
  application rule** — the influence radius, what is suppressed inside it, and the capture of a
  suppressed surcharge-like amount as `surcharges[]` with the label the dictionary hints at. The
  dictionary's **content** is `countries-languages`' (T1.4 published it).
* **FR-EXT-011** — `extraction-pipeline` · `provenance-on-every-value`: **the producing half** —
  every value this change reads, derives or repairs is tagged `read`, `derived`, `repaired` or
  `from_xml` as it is produced, and a consuming check may not raise a state on a `derived` operand.
  That provenance never reaches Ninox is proven when the send pipeline builds its payload (T1.11);
  the model that holds the tag is `implement-core-model-and-countries`'.
* **FR-EXT-012** — `extraction-pipeline` · `multi-page-consolidation`: the reading half — every page
  is read and consolidated into one canonical model with one value per field. The **wiring** of the
  routes that produces the pages, and of `invoice-route-priority` end to end, is T2.1's; this change
  consolidates whatever pages it is given.
* **FR-EXT-013** — `extraction-pipeline` · `currency-is-read-from-the-document`: in full. Currency is
  read from the printed ISO code, the symbol or the issuer country, never defaulted to the table's
  currency, and an unreadable currency is left unsustained. **The consequence** — that an unsustained
  currency suppresses the amounts — is `validation-confidence`'s `currency-carries-its-own-confidence-state`,
  implemented in this same change (FR-VAL-009 below), because the two halves are one decision and
  splitting them across changes would let a wrong-currency figure be written in between.
* **FR-EXT-014** — `extraction-pipeline` · `multilingual-label-dictionaries`: **the application
  half** — the label the document prints is looked up in the dictionary of the document's language
  and then bound to the value nearest it in the visual layout, whatever the interface language. The
  dictionaries themselves, and that they are separate from the interface language, are
  `countries-languages`' (T1.4); the interface languages are R1's cut anyway.
* **FR-VAL-001** — `validation-confidence` · `three-confidence-strengths`: in full. Redundancy is
  green with a lock, a check digit and a repair are amber, and an amount with nothing to cross
  against is never green. **How a state is drawn** is `review-screen`'s (T2.2).
* **FR-VAL-002** — `validation-confidence` · `a-check-confirms-only-if-every-operand-was-read`: in
  full, and it is the rule the rest of this change is built around. A check raises a state only if
  every operand feeding it is `read` or `from_xml`; a check built from a `derived` operand is
  recorded as non-confirmatory rather than as passed, which is what D.5's tautology demonstrates.
* **FR-VAL-004** — `validation-confidence` · `the-numeric-score-is-never-shown`: the storage half —
  the score is held locally and is never part of any state computation, so no colour is assigned
  from it. The screen half is `review-screen`'s, and the "written to Ninox only if mapped" half is
  the send pipeline's, proven when the payload is built (T1.11).
* **FR-VAL-005** — `validation-confidence` · `check-digit-validators`: **the layer** — the validators
  are accepted only when each reproduces the standard valid and invalid vectors of its identifier
  type, and `DE_STNR` is left unchecked without that raising a doubtful state. The algorithms and
  the country rows are `countries-languages`' (T1.3 published them; `DE_USTID` is unvalidated in the
  MVP by the product owner's decision of 2026-09-30, GAP-030, so no vector applies to it here).
* **FR-VAL-006** — `validation-confidence` · `redundancy-checks-on-amounts`: in full, in integer
  minor units on the `Money` of T1.1 — exact integer equality on the printed sums, no tolerance, and
  the single tolerance of at most one minor unit per tax line where `base × rate` is compared with
  the printed tax. The `ExactAmount` T1.1 published carries the comparison without a rounding
  function; which rounding applies where is this change's to state, and it is stated exactly once.
* **FR-VAL-007** — `validation-confidence` · `legal-tax-rate-check`: in full. A rate is checked
  against the detected country's legal set and rejected when it is not legal — the check FR-EXT-009's
  gate consumes, run by the validation layer this change is. The rate sets are
  `countries-languages`' data.
* **FR-VAL-008** — `validation-confidence` · `repair-to-the-only-consistent-value`: in full, and
  Annex D.2 is its acceptance test. Exactly one admissible single-character repair is applied, the
  value is tagged `repaired` and presented amber with the repair visible; two admissible repairs
  means no repair. The visibility half is `review-screen`'s (T2.2).
* **FR-VAL-009** — `validation-confidence` · `currency-carries-its-own-confidence-state`: in full.
  A currency that cannot be sustained from evidence suppresses the amounts rather than allowing a
  wrong-currency figure to be written. Its state is independent of any amount's, and the two
  mis-detections of the test — a euro receipt tagged USD and a dollar invoice tagged MAD — are the
  acceptance cases (synthetically reproduced; the documents are private).
* **FR-VAL-010** — `validation-confidence` · `what-never-reaches-green`: the `doc_number` half in
  full — no document number is ever green, because such numbers carry no check digit and each pass
  produces a different variant. The `supplier_name` half is stated and is not satisfied: a name is
  presentable as confirmed **only** when the supplier memory supplies it from an identifier that
  passed its check digit, and the memory is R1 (UC-15, plan §4.9: in the MVP a supplier name is
  never green, which is the specified behaviour when the memory is empty, not a deviation).
* **FR-VAL-011** — `validation-confidence` · `tax-slots`: in full. One slot per printed rate, the
  count declared by the country table, empty slots staying empty, and `tax_total` as the sum of
  printed tax amounts never computed from the gross and an assumed rate. **Mapping** a slot
  individually is R1 (plan §4.3); the MVP maps `net_total` and `tax_total` only.
* **FR-VAL-012** — `validation-confidence` · `absent-is-not-zero`: **the principle** — a value not
  printed is never a zero, and the app never hardcodes either outcome. **Which** of the two applies
  is the destination's per-field setting, which is `destinations-mapping`'s (`per-field-absent-setting`,
  named below); this change holds the absent value distinctly from zero and consults the setting
  when it decides what a field carries.
* **FR-VAL-013** — `validation-confidence` · `date-coherence-and-ambiguity`: in full. Dates are
  checked for coherence and flagged ambiguous where the document's own evidence does not decide
  between two readings, never silently assumed. Format inference is `countries-languages`' (T1.4).
* **FR-VAL-014** — `validation-confidence` · `determinism-over-coverage`: in full. Its acceptance is
  the conjunction of `three-confidence-strengths`,
  `a-check-confirms-only-if-every-operand-was-read` and `derive-by-identity-never-invent-a-rate`,
  all three implemented by this change, and doubt is preferred to a convincing guess throughout.
* **FR-DST-006** — `destinations-mapping` · `per-field-absent-setting`: **the consuming half** — the
  solver and the validation layer read the setting to turn an absent value into an empty field or a
  contractual zero, and the default is empty. The setting's **storage** and its presence in the
  destination tuple are the wizard's (T1.10, `implement-setup-wizard`); that nothing is hardcoded is
  proven by this change never deciding on its own.
* **FR-CFG-004** — `local-config-privacy` · `token-storage-in-the-platform-keystore`: not this
  change. It is listed only to record the negative: **no value this change produces is written
  anywhere but the canonical model**, and no token, credential or network call exists in
  `packages/paperdrop_core/` — the package is pure Dart with no I/O, which is what keeps a score, a
  provenance tag and a document content out of anywhere but the model and the local store. The
  keystore half is T1.10's.

## Gaps and decisions this change acts on

* **GAP-001** (open, `BLOQUEANTE`) — ADR-010, the recognition engine, blocks the acceptance of
  `render-and-ocr-fallback` and `photo-route-recognition-quality`. This change implements neither:
  no OCR adapter, no screening, no threshold. It does implement the consensus layer the screening's
  accuracy is measured **after** (`photo-route-recognition-quality`'s scenario *accuracy is measured
  on the right population* counts only `read` / `from_xml` values after validation — provenance is
  this change's). The gap stays open until the T2.5 screening report.
* **GAP-002** (open, `BLOQUEANTE`) — ADR-011 blocks the acceptance of
  `positional-pdf-text-extraction`. This change implements the **rule** the ADR's closure criterion
  measures, and publishes the contract the adapter fills, but the acceptance test cannot run until
  the library is chosen on Tue 6 Oct; the change is written so it does not wait for the choice
  (the contract is library-neutral, and the binding rule is tested on synthetic pages of positioned
  words). **This change does not close the gap**, and nothing here touches the register.
* **GAP-003** (open, `NO BLOQUEANTE`) — the acceptance thresholds are deferred to the first corpus
  screening. **No threshold is stated by this change.** The tolerance of FR-VAL-006 is not a
  threshold but a rule the functional states exactly (one minor unit per tax line, nowhere else),
  and it is implemented as stated.
* **GAP-009** (open, `NO BLOQUEANTE`) — the formula-field contrast's blind spot. It is recorded here
  because stage 7 of the pipeline order is where that contrast sits, and the gap says the protection
  against a misread total used to derive its own components is `read-all-printed-quantities-before-deriving`
  and `derive-by-identity-never-invent-a-rate` — both implemented here — rather than the contrast.
  The contrast itself is R1 (`formula-totals-used-as-post-write-contrast`, plan §4.5).
* **GAP-020** (closed) — `surcharges[]` is `{ label, amount_minor }` as Funcional §6.1.2 defines it;
  the entry shape was implemented in `implement-core-model-and-countries`, and this change is what
  fills it when a negative-context suppression captures a surcharge-like amount.
* **GAP-028** (closed 2026-09-28) — the four provenance tags plus a separate record of a value's
  source (document, memory, user). This change produces the four tags; the "memory" source is R1,
  so no value it builds carries it in the MVP.
* **GAP-030** (open) — `DE_USTID`'s published algorithm is not the one the functional and the spec
  name, and the product owner decided on 2026-09-30 to leave it unvalidated in the MVP. This change
  therefore runs no check digit on it and — as with `DE_STNR` — the absence of validation raises no
  doubtful state.
* **ADR-019 / ADR-016 / ADR-005** (approved) — consensus, provenance and the derive/invent boundary;
  integer minor units and the single tolerance; the universal core plus the country table whose rate
  sets the gate consumes. These are what the change implements, rather than choices re-taken in code.
* **D-10** not applicable — no step of this change calls Ninox. There is no token, no network call
  and no test base anywhere in `packages/paperdrop_core/`.

## Deferred

Design and tasks are the orchestrator's; the boundary below is stated so the changes around this
one do not have to renegotiate it.

* **The PDF positional adapter** (`close-adr-011-pdf-text-route`, Mobile, W2) — the library ADR-011
  selects, behind `PdfTextSource`, producing `TextPage`s. This change defines the shape; it reads no
  PDF and links no dependency.
* **The OCR adapter and the multi-pass strategy** (`implement-photo-route`, Mobile, W2–W3) — ML Kit
  text recognition behind the same kind of port, the passes whose candidates this change's consensus
  consumes, and the ADR-010 screening.
* **T2.1 — route selection and multi-page wiring** (`invoice-route-priority`, plan §9 M2) — stopping
  at positional text, falling through to OCR when a page reports no text layer, and consolidating
  across pages of mixed origin. This change consolidates the pages it is given; which route produced
  them and whether to stop is T2.1's, and so is the route's record in `recognitionEngine`.
* **The review and history surfaces** (`implement-review-history-duplicates`, Mobile, W3) — how a
  state is drawn, the lock affordance, the amounts block of DEC-007, the collapse rules, the
  read-region box and operand highlighting. This change determines what each state **means** and
  what may be shown as confirmed; nothing here renders one.
* **The send pipeline** (`implement-send-pipeline`, Ninox, W2) — stages 5 to 7 of
  `pipeline-order-is-fixed`, the payload that proves provenance never leaves the device, the
  retry matrix, the reconciliation and the deep link.
* **R1** — the XML step of `structured-xml-extraction` (which is what produces `from_xml` values;
  in the MVP nothing this change runs produces that tag, and the tag is implemented so the route can
  fill it), the formula-total contrast of `formula-totals-used-as-post-write-contrast`, the supplier
  memory that is the only route a supplier name reaches green, per-slot tax mapping, the further
  Annex C languages beyond EN/DE/ES, and the `doc_subtype` / double-currency fields of DEC-013.
* **The numeric score's two other halves** — never displaying it (T2.2) and writing it only when the
  user mapped it (T1.11).

## Impact

`packages/paperdrop_core/` only — the positioned-word contract, the layout reasoning, the solver,
the consensus and confidence rules, and their tests, including the synthetic public reproductions of
the five failed documents' structure. `packages/` changes: nothing; this change adds no dependency to
the core and the core stays pure Dart with no I/O. `app/` changes: nothing, and Mobile's two adapters
consume the contract this change publishes without this change touching `app/`. No living spec
changes; no functional change; no new decision is taken, so nothing is recorded in
`openspec/product-decisions.md`. `openspec validate implement-validation-and-extraction-core --strict`
passes with zero deltas.

**The private corpus never enters the repository.** The five failed documents of the 16-document test
— `PRO1013-26.pdf`, `sc.jpg`, the Magnus invoice, `FRA 632/2025` and the Bank A card-terminal slip
of record 1414 — are named here by the identifiers the public record already uses and are otherwise
untouched: no content, no supplier name, no tax identifier and no printed value of any of them is
reproduced. What ships is **synthetic reproductions of the structure that failed** — a label and its
value on different lines with a registry volume nearer the label in extraction order; a slip with no
printed breakdown; a document whose only number near a total label is a registry volume; a
foreign-currency document; a document printing no rate — plus **private runs** over the private
corpus whose **numbers only** are reported. The CI privacy job enforces this rather than hoping for
it, and the abstention rate of plan §10.5 — deliberately non-zero by design — is the metric that says
the empty field was chosen over the invented number.

**Three approvals this change does not need, stated plainly.** No step of it calls Ninox or holds a
credential: the core has no network, and the demo target of plan §9's M1 — the wizard reading the
user's real teams, databases, tables and fields — is T1.10's, not this change's. ADR-011 is decided
by the product owner on Tue 6 Oct on evidence `close-adr-011-pdf-text-route` produces; this change's
binding rule is written against the contract, not against a library, so it does not wait for it.
And no row of `openspec/gaps-register.md` or `openspec/product-decisions.md` is changed by this
change: GAP-001 and GAP-002 close with the screenings and the decision, GAP-003 with the
measurements, and the register's own convention is that a closed entry names who closed it and when.
