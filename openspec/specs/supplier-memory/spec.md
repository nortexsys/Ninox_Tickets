# supplier-memory Specification

## Purpose
A supplier name is the one core field the product cannot confirm by arithmetic. A total
can be corroborated by two independently read values agreeing through an identity; a name
has no identity to check against. So the app has exactly one honest route to certainty
about a supplier, and it is remembering it: a store of identifier–name pairs learned from
documents the user has accepted, which turns a second sighting into a confirmed name.

The whole value of that store rests on one structural safeguard. Indexed by whatever the
recognition produced, a misread identifier would enter it and later be shown to the user as
**confirmed** — the app would have laundered an uncertain reading into a certainty, which
is the failure this product exists to prevent. So the store is indexed only by identifiers
that passed their check digit, and an identifier that fails neither creates nor matches an
entry, however plausible the name beside it.

The store also holds supplier data the user may not want kept, so its deletion has to be
real rather than a flag.

---
## Requirements
### Requirement: the-memory-learns-supplier-pairs

The app SHALL maintain a local store of supplier identifier–name pairs learned only from supplier names the user typed or corrected on review, and the store SHALL contain no entry the user did not accept.
A name the app read and the user left untouched SHALL NOT be learned, because saving is never blocked and an untouched name may have been saved without being read.
[Origen: Funcional §4.9 FR-MEM-001; PDR §11; ADR-009; DEC-008]

#### Scenario: a corrected name is learned

- GIVEN a document whose supplier identifier passed its check digit and whose supplier name the user corrected on review
- WHEN the send completes
- THEN the memory holds that identifier with the corrected name

#### Scenario: a typed name is learned

- GIVEN a document whose supplier identifier passed its check digit and whose supplier name was empty and typed by the user
- WHEN the send completes
- THEN the memory holds that identifier with the typed name

#### Scenario: an untouched name is not learned

- GIVEN a document whose supplier name the app read and the user did not touch
- WHEN the send completes
- THEN no pair is learned from it

#### Scenario: nothing the user did not accept enters the store

- GIVEN a document the user never accepted
- WHEN the store is inspected
- THEN it holds no pair from it

#### Scenario: the store is local and survives the send

- GIVEN a completed send
- WHEN the store is inspected on the device
- THEN the pair is present locally
- AND it was never written to Ninox

### Requirement: indexed-only-by-identifiers-that-passed-their-check-digit

The supplier memory SHALL be indexed only by identifiers that passed their check digit, and indexing on an uncertain reading SHALL never occur.
[Origen: Funcional §4.9 FR-MEM-002; Funcional §5 BR-11; PDR §11; ADR-009]

#### Scenario: a failing identifier neither creates nor matches

- GIVEN an identifier that fails its check digit, beside a plausible name
- WHEN the memory is consulted
- THEN no entry is created
- AND no entry is matched

#### Scenario: a wrong name cannot become confirmed

- GIVEN a misread identifier and a plausible-looking name
- WHEN the document is accepted
- THEN neither enters the store
- AND neither can later be presented as confirmed

#### Scenario: the safeguard is what stops the laundering

- GIVEN an uncertain reading that would otherwise have been stored and reused
- WHEN the safeguard applies
- THEN the reading stays uncertain on every future sighting of the same supplier
- AND it is never upgraded by having been kept

#### Scenario: the safeguard applies a validator it does not define

- GIVEN the check-digit algorithm for an identifier type
- WHEN the safeguard applies it
- THEN the algorithm is `countries-languages`' requirement
- AND this capability is responsible only for applying it as its indexing condition

---

### Requirement: presentation-in-review

On review, the app SHALL offer the name the supplier memory holds for a recognised supplier.
[Origen: Funcional §4.9 FR-MEM-003; PDR §6.2, §11]

#### Scenario: a recognised supplier's name is offered

- GIVEN a document whose supplier identifier the memory holds
- WHEN the review screen opens
- THEN the stored name is offered for `supplier_name`

#### Scenario: an unrecognised supplier offers nothing from memory

- GIVEN a supplier the memory does not hold
- WHEN the review screen opens
- THEN no name is offered from memory
- AND the name read from the document is presented as read

#### Scenario: the confirmation rule belongs elsewhere

- GIVEN a name the memory supplied
- WHEN it is presented as confirmed
- THEN the rule permitting that is `validation-confidence`'s `what-never-reaches-green`
- AND this requirement is the store that rule depends on, not a second statement of it

---

### Requirement: real-deletion

The app SHALL provide a data-clearing action that genuinely empties the supplier memory.
[Origen: Funcional §4.9 FR-MEM-004; ADR-009]

#### Scenario: after the action nothing can be matched

- GIVEN a populated memory
- WHEN the clearing action runs
- THEN no identifier–name pair can be matched

#### Scenario: a previously recognised supplier is not offered

- GIVEN a supplier that was recognised before the clearing action
- WHEN a document from that supplier is reviewed afterwards
- THEN the memory offers no name for it

#### Scenario: the deletion is real rather than a flag

- GIVEN a cleared memory
- WHEN the store is inspected on the device
- THEN the pairs are absent
- AND they are not merely marked as deleted

---

## Out of Scope

- **Whether a supplier name may be presented as confirmed.** `validation-confidence` owns
  that rule (BR-11, FR-VAL-010): presentable as confirmed only when this store supplies it
  from an identifier that passed its check digit. This capability owns the store that makes
  it possible and references the rule rather than restating it.
- **The check-digit algorithms and the identifier types.** `countries-languages` owns
  them, including that the three Spanish formats never share code. The safeguard applies a
  validator; it does not define one.
- **Exporting the store and clearing it as part of a wider action.**
  `local-config-privacy` owns the configuration export, which includes this store, and the
  local data clearing (FR-CFG-003) which includes it too. This capability owns that the
  memory's own clearing is genuine.
- **Where the name appears.** `review-screen` owns the field, its order and its colour;
  this capability supplies the candidate.
- **The document's provenance and confidence.** `extraction-pipeline` and
  `validation-confidence` own those; this capability stores a pair, not a judgement.

---

## Cross-Capability References

- `validation-confidence` — owns that a supplier name is presentable as confirmed only via
  this store and only from a check-digit-passing identifier (FR-VAL-010, BR-11). That rule
  is the reason this capability matters, and it is not restated here.
- `countries-languages` — owns the check-digit algorithm the indexing safeguard applies,
  and the identifier types it applies to.
- `local-config-privacy` — owns the configuration export that carries this store to
  another device and the local data clearing that empties it along with history and
  destinations.
- `review-screen` — displays the name this capability offers, and owns the field's
  presentation.
- `document-history` — owns the record of the document the pair was learned from, and the
  retention rules for local data.
- `extraction-pipeline` — reads the identifier and the name that become a pair.

---

## Open Questions

- **None blocking.** GAP-001 and GAP-002 (the extraction routes), GAP-004 (upload limits),
  GAP-005 (a choice field outside its options) and GAP-009 (the formula contrast's blind
  spot) all concern other capabilities and none bears on this one.
- **Settled on 2026-09-25 (GAP-018, DEC-008).** A pair is learned only from a supplier name the
  user typed or corrected on review; a name the app read and the user left untouched is never
  learned. This is neither of the two readings this entry used to describe. Carried into
  `the-memory-learns-supplier-pairs` by the change archived at `openspec/changes/archive/2026-09-25-resolve-mvp-planning-gaps`.
- **The safeguard's failure mode is worth stating plainly.** Without
  `indexed-only-by-identifiers-that-passed-their-check-digit`, this store would be a
  mechanism for promoting an uncertain reading into a confirmed one on its second sighting
  — the opposite of the product's claim. That is what its third scenario tests.
