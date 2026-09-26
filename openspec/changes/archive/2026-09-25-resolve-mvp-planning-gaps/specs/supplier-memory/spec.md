## MODIFIED Requirements

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
