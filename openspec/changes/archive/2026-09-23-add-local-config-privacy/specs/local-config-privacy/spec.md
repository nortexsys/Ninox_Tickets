# Local Configuration and Privacy Specification

## Purpose

The product's privacy claim is the one statement that can be **falsified by a store
listing**. Google's and Apple's own components — the document scanner and, if ADR-010
selects it, the recognition engine — send operational diagnostics to their vendors: device
model, OS version, API latency, error codes. Not document content, not the image, not the
recognised text, but enough that an unqualified *"nothing leaves your device"* would be
contradicted by the Data Safety form the publisher must file.

So the claim is stated **precisely** rather than strongly, and the two local stores holding
third-party data — supplier identifiers and names in the memory, and the exportable
configuration file that carries the same pairs — are declared rather than left unexamined.

This capability also owns what makes privacy real rather than promised: the token in the
platform keystore and never in a backup or a log line, an export that carries no credential,
a clearing action that genuinely empties everything, and no telemetry in a public build —
with supervised measurement before each release as the replacement, because a metric that is
never gathered is a metric that is never known.

---

## ADDED Requirements

---

### Requirement: configuration-export-and-import

Configuration — destinations, mappings and supplier memory — SHALL be exportable to and importable from a file the user keeps wherever they like, and the API token SHALL never be included in the export.
[Origen: Funcional §4.10 FR-CFG-001; Funcional §8 NFR-PRV-004; ADR-009; PDR §3.2, §11]

#### Scenario: the export carries the three things and no credential

- GIVEN a configured app
- WHEN an export is produced
- THEN it contains the destinations, the mappings and the supplier memory
- AND it contains no credential of any kind

#### Scenario: importing on another device restores all three

- GIVEN an export file
- WHEN it is imported on a second device
- THEN destinations, mappings and supplier memory are all restored there

#### Scenario: the user chooses where the file lives

- GIVEN the export action
- WHEN the file is written
- THEN its location is the user's choice
- AND the app does not confine it to a location of its own

---

### Requirement: device-migration

A device change SHALL be a configuration file plus a re-entered token, with no backend and no synchronisation service.
[Origen: Funcional §4.10 FR-CFG-002; ADR-009]

#### Scenario: the token is re-entered rather than carried

- GIVEN a user moving to a new device
- WHEN they restore their configuration
- THEN the destinations, mappings and memory come from the file
- AND the token is entered again, because it never left the old device

#### Scenario: no synchronisation service is involved

- GIVEN the migration of any device
- WHEN the flow is inspected
- THEN no Paperdrop service was contacted
- AND the file and the re-entered token are the whole mechanism

---

### Requirement: local-data-clearing

The app SHALL provide an action that clears local data — history, supplier memory, destinations and retained document files — genuinely and irreversibly, returning the app to its first-run state.
[Origen: Funcional §4.10 FR-CFG-003; Funcional §8 NFR-PRV-005; ADR-009; PDR §11]

#### Scenario: everything named is emptied

- GIVEN a populated app
- WHEN the clearing action runs
- THEN history is empty
- AND the supplier memory is empty
- AND destinations are gone
- AND no retained document file remains

#### Scenario: the app returns to first run

- GIVEN the clearing action having run
- WHEN the app is reopened
- THEN it presents the first-run state

#### Scenario: the clearing is genuine rather than a flag

- GIVEN a cleared app
- WHEN the local stores are inspected
- THEN the data is absent
- AND it is not merely marked as deleted

---

### Requirement: token-storage-in-the-platform-keystore

The API token SHALL be stored in the Android Keystore or the iOS Keychain, and SHALL never appear in an export, a backup snapshot or a log line.
[Origen: Funcional §4.10 FR-CFG-004; Funcional §8 NFR-SEC-001; PDR §11; ADR-009, ADR-018; Funcional §2.4 contract line 3]

#### Scenario: the token is outside the writable data containers

- GIVEN a configured app
- WHEN its writable data containers are inspected
- THEN the token is not present in them

#### Scenario: a backup extraction does not yield it in plaintext

- GIVEN a device backup taken while the app is configured
- WHEN it is extracted
- THEN the token is not recoverable in plaintext

#### Scenario: the token does not reach a log

- GIVEN any code path that handles the token
- WHEN the app's logs are inspected
- THEN the token appears in none of them

#### Scenario: biometric protection is deferred, not required

- GIVEN version 1
- WHEN token protection is considered
- THEN keystore or keychain storage is required
- AND biometric gating is an optional setting deferred to a later version

---

### Requirement: the-precise-privacy-claim

The store listing SHALL lead with the claim stated precisely — that the user's documents never leave the device — with the platform-component caveat disclosed, and SHALL NOT state an unqualified claim that the Data Safety form would contradict.
[Origen: Funcional §8 NFR-PRV-002; PDR §11; Finding 9]

#### Scenario: the listing and the in-app notice agree

- GIVEN the store listing text and the in-app privacy notice
- WHEN they are compared
- THEN they state the same claim in the same terms

#### Scenario: the caveat is disclosed rather than omitted

- GIVEN the claim as published
- WHEN it is read
- THEN it discloses that platform components emit their own diagnostics
- AND it does not claim that nothing whatsoever leaves the device

#### Scenario: the Data Safety form matches

- GIVEN the published claim
- WHEN the Data Safety form is completed
- THEN the two do not contradict each other

---

### Requirement: platform-diagnostics-are-distinguished-from-document-content

The privacy notice SHALL state the distinction exactly — that the platform's scanner and recognition components send operational diagnostics such as device model, OS version, API latency and error codes, encrypted, while the image and the recognised text are not sent — and document content SHALL never form part of any diagnostic.
[Origen: Funcional §8 NFR-PRV-003; PDR §11; Finding 9; Google's ML Kit data disclosure]

#### Scenario: the notice distinguishes the two categories

- GIVEN the privacy notice
- WHEN it is read
- THEN operational diagnostics are named as sent to the platform vendor
- AND the image and the recognised text are named as not sent

#### Scenario: no document content appears in a diagnostic

- GIVEN any platform diagnostic the app causes
- WHEN its content is inspected
- THEN no field of a document and no amount read from one appears in it

---

### Requirement: both-local-stores-are-declared

The privacy notice SHALL declare both local stores that hold data: the supplier memory, holding tax identifiers and names of third-party businesses, and the exportable configuration file, which carries those same pairs.
[Origen: Funcional §8 NFR-PRV-004; PDR §11; ADR-009]

#### Scenario: the notice names both

- GIVEN the privacy notice
- WHEN it is read
- THEN the supplier memory is named with its contents
- AND the exportable configuration file is named with its contents

#### Scenario: neither store is left unmentioned

- GIVEN a store holding third-party data
- WHEN the notice is audited against the app's stores
- THEN every such store appears in the notice

---

### Requirement: supervised-measurement-instead-of-telemetry

No telemetry SHALL be collected in a public build, and product metrics SHALL instead be gathered by supervised measurement before each release.
[Origen: Funcional §8 NFR-PRV-006; ADR-012; Funcional §2.4 contract line 7; Funcional §10.4]

#### Scenario: a public build carries no analytics call

- GIVEN a build published to either store
- WHEN its code and its network traffic are inspected
- THEN no analytics call exists

#### Scenario: the release process includes the protocol

- GIVEN a release being prepared
- WHEN its process is followed
- THEN the supervised measurement protocol of §10.4 is part of it
- AND the metrics it produces are what substitutes for telemetry

---

### Requirement: time-per-document

The median time from opening capture to a confirmed save SHALL be low enough that the flow feels light, and its threshold SHALL be the one fixed after the first corpus screening rather than a figure invented in advance.
[Origen: Funcional §8 NFR-PRF-001; PDR §12; ADR-012; Funcional §10.4]

*The threshold is deferred by §10.5 and tracked as GAP-003. The behaviour is defined; the number is not stated here because §10.5 defers it and a threshold written today would be invented.*

#### Scenario: the metric is measured by the supervised protocol

- GIVEN a document flow
- WHEN its time is measured
- THEN the measurement follows §10.4's protocol
- AND it is compared against the threshold fixed after the first screening

#### Scenario: no invented threshold is used

- GIVEN the first screening has not yet run
- WHEN the flow's time is reported
- THEN it is reported as a measurement
- AND it is not compared against a figure this specification invented

---

### Requirement: tap-count

A document that validates cleanly SHALL be capturable, reviewable and saved in three taps plus one destination confirmation on the first capture of the day, and a typical document SHALL cost five to six taps, both measured by the supervised protocol.
[Origen: Funcional §8 NFR-PRF-003; PDR §6.2, §7.2; Funcional §10.4]

#### Scenario: a clean document takes three taps and one confirmation

- GIVEN a document that validates cleanly on the first capture of a day
- WHEN the flow is counted
- THEN it completes in three taps plus the one destination confirmation

#### Scenario: a typical document costs five to six

- GIVEN a typical document
- WHEN the flow is counted
- THEN it costs between five and six taps

#### Scenario: the count is a release criterion

- GIVEN a release being prepared
- WHEN the criteria are checked
- THEN the tap count is among them, measured rather than asserted

---

### Requirement: accessibility

The interface SHALL meet the platform accessibility standards: every control labelled, colour states paired with a non-colour cue, large-type fields by default, and the read region and the confidence state exposed to assistive technology.
[Origen: Funcional §8 NFR-ACC-001; PDR §4]

#### Scenario: confidence is never conveyed by colour alone

- GIVEN a value in any confidence state
- WHEN it is presented
- THEN a non-colour cue accompanies the colour

#### Scenario: the auditor passes the review and history screens

- GIVEN the platform accessibility auditor
- WHEN it is run over review and history
- THEN it passes

#### Scenario: the read region reaches assistive technology

- GIVEN a value with a region it was read from
- WHEN assistive technology reads the field
- THEN the region and the confidence state are exposed to it

---

### Requirement: all-user-facing-strings-are-externalised

Every user-facing string SHALL be externalised, including error messages, and no hardcoded user-facing string SHALL exist.
[Origen: Funcional §8 NFR-I18N-001; PDR §3.1, §10]

#### Scenario: switching the device language switches every string

- GIVEN the device language changed
- WHEN the app is used
- THEN every string changes with it
- AND error messages are included

#### Scenario: no string is hardcoded

- GIVEN the application's sources
- WHEN they are inspected for user-facing text
- THEN no such text is found outside the string resources

---

### Requirement: no-agpl-component-ships

No AGPL-licensed component SHALL ship inside the application, so that the test harness's own tooling never reaches a release build.
[Origen: Funcional §8 NFR-LIC-001; ADR-011; Funcional §2.4 contract line 5]

#### Scenario: the harness-only tool stays out of the build

- GIVEN the AGPL-licensed component used by the 16-document test harness
- WHEN a release build is inspected
- THEN the component is not linked into it

#### Scenario: an excluded library stays excluded

- GIVEN a commercial PDF library ruled out on licence grounds
- WHEN dependencies are reviewed
- THEN it is absent from the build
- AND its exclusion is not reversed by a later convenience

---

### Requirement: application-size

The contribution of the PDF library to application size SHALL be acceptable, as part of ADR-011's closure criterion, and SHALL be measured rather than assumed.
[Origen: Funcional §8 NFR-SIZ-001; ADR-011]

*Blocked by ADR-011, the library selection (GAP-002). The criterion is stated; the measurement cannot be made until a library is chosen.*

#### Scenario: the size delta is reported with the decision

- GIVEN a candidate PDF library
- WHEN ADR-011 is closed
- THEN the size delta it introduces is reported alongside the decision

#### Scenario: no library is adopted without its size measured

- GIVEN a library under consideration
- WHEN it is accepted
- THEN its contribution to application size has been measured
- AND it was not assumed to be acceptable

---

## Out of Scope

- **The credential invariants themselves.** `product-invariants` owns
  `token-is-the-only-credential` — no password ever requested, stored or transmitted, and
  the sign-in rendered only by the system browser — and `no-telemetry-in-public-builds`.
  This capability owns where the token is stored and how the claim about it is worded.
- **What the export contains.** `destinations-mapping` owns destinations and mappings;
  `supplier-memory` owns the identifier–name pairs. This capability owns that the file
  carries them to another device and never carries a credential.
- **The existence of the interface languages.** `countries-languages` owns
  `interface-languages`. This capability owns that every string is externalised so that
  switching language actually switches everything.
- **The dependency declaration.** `product-invariants` owns
  `proprietary-dependencies-declared`. This capability owns the AGPL exclusion, which is
  stricter than declaring: a component may be known and still not ship.
- **Offline behaviour.** `capture-intake` and `document-history` own it; NFR-PRF-002 and
  NFR-OFL-001 are accounted for there in `project.md` §3.5.
- **The metrics' thresholds.** §10.5's release criteria are the functional's. This capability
  states the outcomes it can test and defers the numbers it cannot.
- **Platform versions.** NFR-PLT-001 is `product-invariants`' `no-desktop-application` and
  fixes Android and iOS as the surfaces; minimum OS versions are fixed in the SDD.

---

## Cross-Capability References

- `product-invariants` — owns the credential invariants, `no-telemetry-in-public-builds`,
  `proprietary-dependencies-declared` and `no-desktop-application`. This capability owns
  the storage, the wording and the exclusions that implement them.
- `destinations-mapping` and `supplier-memory` — own what the export file carries, and
  `supplier-memory` owns that its own clearing is genuine.
- `countries-languages` — owns that the interface ships in English and German, and the
  document dictionaries that are independent of it.
- `review-screen` — owns the presentation whose colour states this capability requires to
  carry a non-colour cue, and the read region exposed to assistive technology.
- `capture-intake` and `document-history` — own offline behaviour and the state machine,
  which is where NFR-PRF-002 and NFR-OFL-001 are discharged.
- `extraction-pipeline` — shares the ADR-011 dependency behind `application-size`, and owns
  the accuracy threshold that is deferred alongside `time-per-document`.

---

## Open Questions

- **GAP-003** — the acceptance thresholds for product metrics are deferred to the first
  corpus screening. It is why `time-per-document` states an outcome rather than a number,
  while `tap-count` can state figures because the functional gives them.
- **GAP-002** — ADR-011 has not closed, so `application-size` cannot be measured and the
  exclusion in `no-agpl-component-ships` is stated as a rule whose verification waits on
  the library choice.
- **GAP-011** — the name "Paperdrop" is unchecked in both stores and at the EUIPO. It
  matters to this capability more than to any other, because the store listing is its
  deliverable, and a name that cannot be used would change the listing rather than the
  product.
- **A note on why the claim is worded the way it is.** An unqualified "nothing leaves your
  device" is the stronger sentence and the wrong one: the platform components the app
  depends on send their own operational diagnostics, so the broad claim would be
  contradicted by the Data Safety form the publisher has to file. `the-precise-privacy-claim`
  therefore requires the precise version and its caveat, and its third scenario checks the
  one thing that would expose the contradiction — that the listing and the form agree.
