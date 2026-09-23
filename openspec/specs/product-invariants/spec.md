# product-invariants Specification

## Purpose

Paperdrop writes records into a third party's business system — the user's own
Ninox database — from a device the publisher does not control, with no backend and
no account of its own. That shape makes a small set of statements non-negotiable,
and every one of them is a statement about **restraint** rather than capability:
what the app will not store, will not send, will not read and will not touch.

This capability is the single home for those statements. It is not a description
of a screen or a pipeline step: it is the boundary that the rest of the product is
built inside, expressed so that crossing it fails a test rather than merely
disagreeing with an intention. The functional declares the set normative and
commits the acceptance corpus to one negative check per statement (§1.2, §10);
this is where each check has a requirement to attach to.

No other capability may restate these requirements. It references them.

---

## Requirements
### Requirement: no-desktop-application

The app SHALL NOT provide a desktop application. Android and iOS are the only
surfaces published for version 1.
[Origen: Funcional §1.2 (negative requirements); PDR §3.2 (non-goals); Funcional §8 NFR-PLT-001]

#### Scenario: only mobile builds are published

- GIVEN a person who wants to record an expense with Paperdrop
- WHEN they look for a build to install
- THEN Android and iOS builds are the only ones offered
- AND no desktop or browser-based build exists to install

---

### Requirement: no-backend-and-no-account

The app SHALL operate with no backend service, in any version, and SHALL NOT
create a Paperdrop user account. Reading and validation SHALL run entirely on the
device.
[Origen: Funcional §1.2; Funcional §2.4 contract line 1; PDR §3.2; ADR-002]

#### Scenario: capture without connectivity

- GIVEN a device with no network connection
- WHEN a document is captured
- THEN it is read and validated on the device
- AND no request leaves the device

#### Scenario: there is no account to create

- GIVEN a first run of the app
- WHEN the user configures it
- THEN no Paperdrop account is created
- AND no email address is requested on Paperdrop's behalf
- AND the only credential the user supplies is the Ninox API token

---

### Requirement: header-level-records-only

The app SHALL write exactly one record per document, at header level, and SHALL
NOT write line-item detail.
[Origen: Funcional §1.2 (negative requirements); PDR §3.2]

#### Scenario: a document with many lines produces one record

- GIVEN a document printing twelve line items
- WHEN it is sent
- THEN exactly one record is created
- AND no line-item structure is written to the destination

---

### Requirement: never-touch-schema-or-foreign-records

The app SHALL NOT create, rename or delete fields or tables in the user's Ninox
database, and SHALL NOT delete or modify a record it did not create.
[Origen: Funcional §1.2; Funcional §5 BR-16; Funcional §2.4 contract line 6]

#### Scenario: no request targets the schema

- GIVEN the complete set of operations the app can perform
- WHEN the requests it issues are inspected
- THEN none of them targets a schema endpoint

#### Scenario: a correction touches only the app's own record

- GIVEN a correction of a document the app sent earlier
- WHEN the update is issued
- THEN it targets the record identifier the app itself received from its own create
- AND no record the app did not create is read, updated or deleted

---

### Requirement: token-is-the-only-credential

The app SHALL NOT request, store or transmit a Ninox username or password. The
Ninox API token SHALL be the only credential, and it SHALL be obtained through the
platform's system browser.
[Origen: Funcional §1.2; Funcional §5 BR-19; Funcional §2.4 contract line 3; ADR-018]

#### Scenario: there is no surface for a password

- GIVEN the app in any state
- WHEN its user-facing surfaces and its outgoing requests are inspected
- THEN no field, screen or request exists in which a Ninox password could be entered

#### Scenario: sign-in is rendered by the system browser

- GIVEN the step in which the user obtains a token
- WHEN the sign-in page is displayed
- THEN it is rendered by the platform's system browser
- AND it is never rendered by a WebView the app controls

---

### Requirement: no-user-facing-reporting-or-export

The app SHALL NOT offer the user reporting, reconciliation, or data export beyond
the configuration file.

This prohibition constrains the **features the app offers to the user**. It does
not prohibit reading back the record the app has just created: the send pipeline
requires that read, and it is the only visibility the app has into the user's
defaults, formulas and automations. Recording the boundary here, as a requirement
rather than as a remark, is deliberate — the two statements would otherwise read
as a contradiction.
[Origen: Funcional §1.2; Funcional FR-SND-001; Funcional §5 BR-18]

#### Scenario: the only export is the configuration file

- GIVEN the app's surfaces
- WHEN the user looks for reporting, reconciliation or an export
- THEN the only export offered is the configuration file
- AND no report and no reconciliation view exists

#### Scenario: read-back after a send is not an export

- GIVEN a document that has just been sent
- WHEN the app reads the created record back in order to show what was stored
- THEN that read is a step of the send pipeline, not a user-facing export
- AND the values it displays are not offered as a downloadable or shareable dataset

---

### Requirement: no-multi-user-or-team-features

The app SHALL NOT offer multi-user or team features.
[Origen: Funcional §1.2 (negative requirements)]

#### Scenario: the app is single-operator

- GIVEN the app installed and configured by one person
- WHEN every surface is inspected
- THEN no invitation, no role assignment and no shared workspace exists inside the app

---

### Requirement: no-cross-device-synchronisation

The app SHALL NOT synchronise between devices. Configuration SHALL move between
devices only through the exportable configuration file.
[Origen: Funcional §1.2; Funcional FR-CFG-002]

#### Scenario: two devices are independent

- GIVEN the same destination configured on two devices
- WHEN a document is sent from one of them
- THEN nothing about that document appears on the other
- AND the configuration file is the only way to carry a destination across

---

### Requirement: no-telemetry-in-public-builds

The app SHALL NOT collect telemetry in a public build.
[Origen: Funcional §1.2; Funcional §2.4 contract line 7; Funcional §8 NFR-PRV-006]

#### Scenario: a published build emits nothing to the publisher

- GIVEN a build published to either store
- WHEN its network traffic is observed
- THEN no request reaches an analytics or crash-reporting endpoint operated by the publisher

---

### Requirement: never-read-message-body

The app SHALL NOT read the body of a `.msg` or `.eml` container. Only the document
attachment the container carries SHALL be used.
[Origen: Funcional §1.2; Funcional FR-CAP-006]

#### Scenario: only the attachment is used

- GIVEN a mail container holding a message body and one document attachment
- WHEN it is captured
- THEN the record is created from the attachment
- AND the message body is neither stored nor sent

---

### Requirement: no-data-leaves-the-device-except-to-ninox

No user data SHALL leave the device except toward the user's own Ninox database.
Platform components may emit their own operational diagnostics, and document
content SHALL never appear in them.
[Origen: Funcional §2.4 contract line 2; Funcional §8 NFR-PRV-002, NFR-PRV-003]

#### Scenario: reading survives the loss of the network

- GIVEN a device in aeroplane mode
- WHEN a document is captured
- THEN the reading and the validation complete
- AND only the send itself remains queued

#### Scenario: platform diagnostics carry no document content

- GIVEN a platform component that emits operational diagnostics of its own
- WHEN those diagnostics are inspected
- THEN no field of the document and no amount read from it appears in them

---

### Requirement: proprietary-dependencies-declared

Every proprietary dependency the app links SHALL be declared in the repository
README, together with the role it plays.
[Origen: Funcional §2.4 contract line 5; Funcional §8 NFR-LIC-001]

#### Scenario: the README accounts for each proprietary dependency

- GIVEN the set of dependencies the app links
- WHEN the README is read
- THEN every proprietary dependency appears
- AND each one is stated with what it is used for

---

### Requirement: money-as-integer-minor-units

Every monetary amount SHALL be an integer in the currency's minor unit, and every
tax rate an integer in basis points, in the canonical model, in the local store
**and** in the Ninox payload.
[Origen: Funcional §5 BR-09; ADR-016]

#### Scenario: no float crosses a boundary

- GIVEN a document whose total is 19,99 EUR and whose printed rate is 21 %
- WHEN the value is carried from extraction, through the local store, into the payload
- THEN it is the integer `1999` in the minor unit and the integer `2100` in basis points at every step
- AND no step introduces a floating-point representation

#### Scenario: the payload does not serialize money as a decimal

- GIVEN a destination with an amount field mapped
- WHEN the Ninox payload is built
- THEN the amount is serialized as an integer
- AND it is not serialized as a formatted string or a decimal

---

## Out of Scope

- **The mechanism behind any invariant here.** This capability states the boundary
  and names who implements it; it does not describe the implementation. Byte
  integrity of a received file is BR-17 and belongs to `capture-intake`. The
  token's storage belongs to `local-config-privacy` (FR-CFG-004) and its
  acquisition to `setup-wizard` (FR-WIZ-003). The confidence principle of contract
  line 4 belongs to `validation-confidence`.
- **Everything the app does.** Positive behaviour belongs to the capability that
  owns the module: capture, extraction, validation, review, destinations, send,
  history, supplier memory, wizard, configuration.
- **The per-field tolerance rule.** BR-09 carries a representation invariant and a
  tolerance. The invariant is here; the tolerance — `base × rate ≈ tax`, at most
  one minor unit per tax line — is FR-VAL-006 in `validation-confidence`.
- **Legal or licensing advice.** The README obligation is a requirement on the
  repository, not an assessment of any particular licence's terms.

---

## Cross-Capability References

- `capture-intake` — owns the intake side of the message-body prohibition
  (FR-CAP-006, FR-CAP-007) and byte integrity (BR-17). This capability states that
  a body is never read; that capability owns how a container is handled.
- `local-config-privacy` — owns where the token is stored (FR-CFG-004) and what
  clearing local data means (FR-CFG-003). This capability states only that the
  token is the only credential.
- `setup-wizard` — owns how the token is obtained (FR-WIZ-003) and that the
  sign-in is rendered by the system browser.
- `validation-confidence` — owns contract line 4 (BR-01, BR-02, BR-05) and the
  tolerance half of BR-09 (FR-VAL-006).
- `destinations-mapping` — owns BR-15, never write an unmapped field, which is the
  other half of contract line 6.
- `ninox-send` — owns BR-18 (the record is always read back) and BR-21 (never
  blindly retry a create), the two rules that make the read-back in
  `no-user-facing-reporting-or-export` a pipeline step.
- `review-screen` — owns BR-14, never block a save.

---

## Open Questions

- **None blocking.** Two existing gaps in `openspec/gaps-register.md` bear on this
  capability and neither prevents it from being written:
  - **GAP-011** — the name "Paperdrop" is unchecked in both stores and at the
    EUIPO. No requirement here depends on the name.
  - **GAP-012** — `NINOX_DB_ID` pointed at a production database in the test
    environment. This capability is where the credential invariant lives, so the
    operating rule that forbids that variable belongs alongside it rather than
    only in `AGENTS.md`.
- **Resolved while writing this spec.** Whether the prohibition on export also
  forbids the read-back that FR-SND-001 and BR-18 require: it does not. The
  prohibition constrains user-facing features, and the read-back is a pipeline
  step whose displayed values are not offered as a dataset. Carried as a
  requirement plus its own scenario rather than as a remark, so that a later
  reader cannot read the two statements as contradicting each other. Recorded as
  DEC-003.

